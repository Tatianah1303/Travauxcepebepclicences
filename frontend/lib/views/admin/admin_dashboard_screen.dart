import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/quota_membre.dart';
import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';
import '../../services/admin_session.dart';
import '../../services/archive_service.dart';
import '../../utils/csv_export.dart';
import '../../widgets/searchable_dropdown.dart';
import 'login_admin_screen.dart';
import '../chat/liste_conversation_admin_screen.dart';
import 'listes_admin_screen.dart';
import '../admin/peridode_saisie_screen.dart';

/// Dashboard de l'Administration CISCO : rôle purement consultatif.
/// - 3 catégories (Candidats CEPE, Candidats BEPC, Membres prévisionnels)
///   avec export Excel national.
/// - Tableau des membres par rôle et par établissement.
/// - Statistiques en bâtonnets (candidats par examen, membres par rôle,
///   candidats par sexe), filtrables par établissement (réservé à l'admin).
/// - Archivage et clôture de session : exporte tout en .zip puis vide
///   la base pour l'année suivante.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _totalCepe = 0;
  int _totalBepc = 0;
  int _totalMembres = 0;
  int _cepeNonAttribues = 0;
  int _bepcNonAttribues = 0;
  Map<String, String> _nomsEtab = {};
  List<ItemListe> _listeEtablissements = [];
  List<_LigneRoleEtab> _tableauRolesCepe = [];
  List<_LigneRoleEtab> _tableauRolesBepc = [];

  // Données brutes pour les statistiques (non filtrées) — le filtre
  // s'applique au moment de l'affichage des graphiques.
  List<Map<String, dynamic>> _candidatsCepeRaw = [];
  List<Map<String, dynamic>> _candidatsBepcRaw = [];
  List<Map<String, dynamic>> _membresRaw = [];

  String? _etabFiltre; // null = tous les établissements
  bool _chargement = true;
  bool _archivageEnCours = false;

  int get _anneeSession => DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);

    final cepe = await SqliteService.instance.listerCandidatsCepe();
    final bepc = await SqliteService.instance.listerCandidatsBepc();
    final membres = await SqliteService.instance.listerMembres();
    final enseignants = await SqliteService.instance.listerTousEnseignants();
    final etablissements = await SqliteService.instance.listerItems(
      'etablissement',
    );

    final nomsEtab = {
      for (final e in etablissements)
        (e.champs['code'] ?? ''): (e.champs['nom'] ?? ''),
    };
    final etabDeMatricule = {
      for (final e in enseignants) e.matricule: e.codeEtab,
    };
    final sexeDeMatricule = {for (final e in enseignants) e.matricule: e.sexe};

    final Map<String, Map<String, int>> compteCepe = {};
    final Map<String, Map<String, int>> compteBepc = {};
    for (final m in membres) {
      final codeEtab = etabDeMatricule[m.matriculeEnseignant];
      if (codeEtab == null) continue;
      final compte = m.typeExamen == 'BEPC' ? compteBepc : compteCepe;
      compte.putIfAbsent(codeEtab, () => {for (final r in rolesMembre) r: 0});
      compte[codeEtab]![m.role] = (compte[codeEtab]![m.role] ?? 0) + 1;
    }

    List<_LigneRoleEtab> construireTableau(Map<String, Map<String, int>> c) =>
        c.entries
            .map(
              (entry) => _LigneRoleEtab(
                codeEtab: entry.key,
                nomEtab: nomsEtab[entry.key] ?? entry.key,
                parRole: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.nomEtab.compareTo(b.nomEtab));

    final tableauCepe = construireTableau(compteCepe);
    final tableauBepc = construireTableau(compteBepc);

    setState(() {
      _totalCepe = cepe.length;
      _totalBepc = bepc.length;
      _cepeNonAttribues = cepe.where((c) => c.codeCentreEcrit == null).length;
      _bepcNonAttribues = bepc.where((c) => c.codeCentreEcrit == null).length;
      _totalMembres = membres.length;
      _nomsEtab = nomsEtab;
      _listeEtablissements = etablissements;
      _tableauRolesCepe = tableauCepe;
      _tableauRolesBepc = tableauBepc;
      _candidatsCepeRaw = cepe
          .map((c) => {'codeEtab': c.codeEtab, 'sexe': c.sexe})
          .toList();
      _candidatsBepcRaw = bepc
          .map((c) => {'codeEtab': c.codeEtab, 'sexe': c.sexe})
          .toList();
      _membresRaw = membres
          .map(
            (m) => {
              'codeEtab': etabDeMatricule[m.matriculeEnseignant],
              'role': m.role,
              'sexe': sexeDeMatricule[m.matriculeEnseignant],
              'typeExamen': m.typeExamen,
            },
          )
          .toList();
      _chargement = false;
    });
  }

  // --------------------------------------------------------------------
  //  Exports Excel — filtrés sur l'établissement sélectionné uniquement
  //  (jamais la liste globale/nationale affichée dans le dashboard)
  // --------------------------------------------------------------------

  Future<void> _exporterCepe() async {
    if (_etabFiltre == null) {
      _confirmer('Choisissez d\'abord un établissement à exporter');
      return;
    }
    final cepe = (await SqliteService.instance.listerCandidatsCepe())
        .where((c) => c.codeEtab == _etabFiltre)
        .toList();
    final nomEtab = _nomsEtab[_etabFiltre] ?? _etabFiltre!;
    final chemin = await exporterEnCsv(
      nomFichier: 'candidats_cepe_$nomEtab',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'État',
      ],
      lignes: cepe
          .map(
            (c) => [
              _nomsEtab[c.codeEtab] ?? c.codeEtab,
              c.nom,
              c.prenom,
              c.sexe,
              c.groupe,
              c.etatCandidat,
            ],
          )
          .toList(),
    );
    _confirmer('Exporté : $chemin');
  }

  Future<void> _exporterBepc() async {
    if (_etabFiltre == null) {
      _confirmer('Choisissez d\'abord un établissement à exporter');
      return;
    }
    final bepc = (await SqliteService.instance.listerCandidatsBepc())
        .where((c) => c.codeEtab == _etabFiltre)
        .toList();
    final nomEtab = _nomsEtab[_etabFiltre] ?? _etabFiltre!;
    final chemin = await exporterEnCsv(
      nomFichier: 'candidats_bepc_$nomEtab',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'Langue',
        'Née vers',
        'État',
      ],
      lignes: bepc
          .map(
            (c) => [
              _nomsEtab[c.codeEtab] ?? c.codeEtab,
              c.nom,
              c.prenom,
              c.sexe,
              c.groupe,
              c.langue ?? '-',
              '${c.neeVert}',
              c.etatCandidat,
            ],
          )
          .toList(),
    );
    _confirmer('Exporté : $chemin');
  }

  Future<void> _exporterMembres(String typeExamen) async {
    if (_etabFiltre == null) {
      _confirmer('Choisissez d\'abord un établissement à exporter');
      return;
    }
    final enseignants = await SqliteService.instance.listerTousEnseignants();
    final parMatricule = {for (final e in enseignants) e.matricule: e};
    final membres =
        (await SqliteService.instance.listerMembres(typeExamen: typeExamen))
            .where(
              (m) =>
                  parMatricule[m.matriculeEnseignant]?.codeEtab == _etabFiltre,
            )
            .toList();

    // Seulement les centres du type d'examen concerné (pas de mélange
    // CEPE/BEPC dans les noms de centres retrouvés).
    final tousCentresEcrit = await SqliteService.instance.listerItems(
      typeExamen == 'CEPE' ? 'centreEcritCepe' : 'centreEcritBepc',
    );
    final tousCentresCorrection = await SqliteService.instance.listerItems(
      typeExamen == 'CEPE' ? 'centreCorrectionCepe' : 'centreCorrectionBepc',
    );

    String libelleDe(String? code, List<ItemListe> centres) {
      if (code == null) return 'Non attribué';
      try {
        return centres
                .firstWhere((c) => c.champs['code'] == code)
                .champs['libelle'] ??
            code;
      } catch (_) {
        return code;
      }
    }

    final nomEtab = _nomsEtab[_etabFiltre] ?? _etabFiltre!;
    final chemin = await exporterEnCsv(
      nomFichier: 'membres_${typeExamen.toLowerCase()}_$nomEtab',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Fonction',
        'Rôle',
        'État',
        'Centre d\'écrit',
        'Centre de correction',
      ],
      lignes: membres.map((m) {
        final e = parMatricule[m.matriculeEnseignant];
        return [
          e != null ? (_nomsEtab[e.codeEtab] ?? e.codeEtab) : '-',
          e?.nom ?? '-',
          e?.prenom ?? '-',
          e?.sexe ?? '-',
          e?.fonction ?? '-',
          libelleRole(m.role),
          m.etat,
          libelleDe(m.codeCentreEcrit, tousCentresEcrit),
          libelleDe(m.codeCentreCorrection, tousCentresCorrection),
        ];
      }).toList(),
    );
    _confirmer('Exporté : $chemin');
  }

  void _confirmer(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------------
  //  Archivage et clôture de session
  // --------------------------------------------------------------------

  Future<void> _archiverEtCloturer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver et clôturer la session ?'),
        content: Text(
          'Toutes les données de la session $_anneeSession (candidats CEPE, '
          'BEPC et membres prévisionnels) vont être exportées dans un fichier '
          '.zip, PUIS SUPPRIMÉES de la base pour préparer la session suivante.\n\n'
          'Cette action est irréversible localement. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _archivageEnCours = true);
    final cheminZip = await ArchiveService.archiverEtCloturerSession(
      _anneeSession,
    );
    setState(() => _archivageEnCours = false);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Session archivée : $cheminZip')));
    await _charger();
  }

  // --------------------------------------------------------------------
  //  Statistiques filtrées par établissement
  // --------------------------------------------------------------------

  List<Map<String, dynamic>> _filtrer(List<Map<String, dynamic>> liste) {
    if (_etabFiltre == null) return [];
    return liste.where((e) => e['codeEtab'] == _etabFiltre).toList();
  }

  void _deconnexion() {
    AdminSession.instance.deconnecter();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginAdminScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cepeF = _filtrer(_candidatsCepeRaw);
    final bepcF = _filtrer(_candidatsBepcRaw);
    final membresF = _filtrer(_membresRaw);
    final membresCepeF = membresF
        .where((m) => m['typeExamen'] == 'CEPE')
        .toList();
    final membresBepcF = membresF
        .where((m) => m['typeExamen'] == 'BEPC')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: _deconnexion,
        ),
        title: Text(
          'CISCO — ${AdminSession.instance.nomAgent ?? "Administration"}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Messages',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ListeConversationsAdminScreen(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Plus d\'options',
            onSelected: (valeur) {
              if (valeur == 'periode') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PeriodeSaisieScreen(),
                  ),
                );
              } else if (valeur == 'listes') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ListesAdminScreen()),
                );
              } else if (valeur == 'deconnexion') {
                _deconnexion();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'periode',
                child: ListTile(
                  leading: Icon(Icons.campaign_outlined),
                  title: Text('Période de saisie'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'listes',
                child: ListTile(
                  leading: Icon(Icons.list_alt),
                  title: Text('Voir les listes'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'deconnexion',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Déconnexion',
                    style: TextStyle(color: Colors.red),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Sélection de l'établissement : obligatoire avant de voir
            // les statistiques (point 4 de la demande). ---
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SearchableDropdown<ItemListe>(
                  label: 'Établissement',
                  icone: Icons.filter_alt,
                  items: _listeEtablissements,
                  libelleDe: (e) => e.champs['nom'] ?? e.champs['code'] ?? '',
                  valeurDe: (e) => e.champs['code'],
                  valeurSelectionnee: _etabFiltre,
                  onSelectionner: (e) =>
                      setState(() => _etabFiltre = e?.champs['code']),
                ),
              ),
            ),

            // --- Répartition des établissements par secteur (statistique
            // globale, indépendante de l'établissement sélectionné). ---
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final publics = _listeEtablissements
                    .where((e) => e.champs['secteur']?.trim() == '0')
                    .length;
                final prives = _listeEtablissements
                    .where((e) => e.champs['secteur']?.trim() == '1')
                    .length;
                final libres = _listeEtablissements
                    .where((e) => e.champs['secteur']?.trim() == '2')
                    .length;
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Établissements par secteur (${_listeEtablissements.length} au total)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _pastilleSecteur('Public', publics, Colors.blue),
                            const SizedBox(width: 10),
                            _pastilleSecteur('Privé', prives, Colors.orange),
                            const SizedBox(width: 10),
                            _pastilleSecteur('Libre', libres, Colors.teal),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            if (_etabFiltre == null) ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choisissez un établissement ci-dessus\npour afficher ses statistiques',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'Statistiques de l’établissement sélectionné',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _carteStat(
                      titre: 'Candidats CEPE',
                      valeur: cepeF.length,
                      couleur: Colors.blue,
                      icone: Icons.school,
                      onExporter: _exporterCepe,
                      garcons: cepeF.where((c) => c['sexe'] == 'G').length,
                      filles: cepeF.where((c) => c['sexe'] == 'F').length,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _carteStat(
                      titre: 'Candidats BEPC',
                      valeur: bepcF.length,
                      couleur: Colors.teal,
                      icone: Icons.menu_book,
                      onExporter: _exporterBepc,
                      garcons: bepcF.where((c) => c['sexe'] == 'G').length,
                      filles: bepcF.where((c) => c['sexe'] == 'F').length,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _carteStat(
                      titre: 'Membres CEPE',
                      valeur: membresCepeF.length,
                      couleur: Colors.purple,
                      icone: Icons.badge,
                      onExporter: () => _exporterMembres('CEPE'),
                      garcons: membresCepeF
                          .where((m) => m['sexe'] == 'G')
                          .length,
                      filles: membresCepeF
                          .where((m) => m['sexe'] == 'F')
                          .length,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _carteStat(
                      titre: 'Membres BEPC',
                      valeur: membresBepcF.length,
                      couleur: Colors.deepPurple,
                      icone: Icons.badge,
                      onExporter: () => _exporterMembres('BEPC'),
                      garcons: membresBepcF
                          .where((m) => m['sexe'] == 'G')
                          .length,
                      filles: membresBepcF
                          .where((m) => m['sexe'] == 'F')
                          .length,
                    ),
                  ),
                ],
              ),

              if (_cepeNonAttribues > 0 || _bepcNonAttribues > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Candidats pas encore attribués à un centre d\'écrit : '
                            '$_cepeNonAttribues (CEPE), $_bepcNonAttribues (BEPC).',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              const Text(
                'Membres CEPE par rôle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _tableauParRole(_tableauRolesCepe),

              const SizedBox(height: 24),
              const Text(
                'Membres BEPC par rôle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _tableauParRole(_tableauRolesBepc),

              const SizedBox(height: 28),
              const Text(
                'Statistiques (graphiques)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _graphiqueCandidatsParExamen(cepeF.length, bepcF.length),
              const SizedBox(height: 20),
              _graphiqueCandidatsParSexe(cepeF, bepcF),
            ],

            const SizedBox(height: 32),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zone dangereuse',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Archive toutes les données de la session $_anneeSession en .zip, '
                      'puis les supprime pour préparer la session suivante (CEPE et BEPC).',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _archivageEnCours
                            ? null
                            : _archiverEtCloturer,
                        icon: _archivageEnCours
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.archive),
                        label: Text(
                          _archivageEnCours
                              ? 'Archivage en cours...'
                              : 'Archiver et clôturer la session',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastilleSecteur(String label, int valeur, Color couleur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$valeur',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: couleur)),
          ],
        ),
      ),
    );
  }

  Widget _tableauParRole(List<_LigneRoleEtab> lignes) {
    final filtrees = lignes.where((l) => l.codeEtab == _etabFiltre).toList();
    return Card(
      child: filtrees.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucun membre désigné pour le moment'),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('ÉTABLISSEMENT')),
                  ...rolesMembre.map(
                    (r) =>
                        DataColumn(label: Text(libelleRole(r).toUpperCase())),
                  ),
                  const DataColumn(label: Text('TOTAL')),
                ],
                rows: filtrees
                    .map(
                      (ligne) => DataRow(
                        cells: [
                          DataCell(Text(ligne.nomEtab)),
                          ...rolesMembre.map(
                            (r) => DataCell(Text('${ligne.parRole[r] ?? 0}')),
                          ),
                          DataCell(
                            Text(
                              '${ligne.parRole.values.fold(0, (a, b) => a + b)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _carteStat({
    required String titre,
    required int valeur,
    required Color couleur,
    required IconData icone,
    required VoidCallback onExporter,
    bool pleineLargeur = false,
    int? garcons,
    int? filles,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: couleur,
                  child: Icon(icone, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$valeur',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
            if (garcons != null && filles != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text(
                    'Garçons : $garcons',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Filles : $filles',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onExporter,
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('Exporter Excel'),
                style: OutlinedButton.styleFrom(foregroundColor: couleur),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bâtonnets : nombre de candidats inscrits, CEPE vs BEPC.
  Widget _graphiqueCandidatsParExamen(int cepe, int bepc) {
    final total = (cepe + bepc) == 0 ? 1 : (cepe + bepc);
    return _carteGraphique(
      titre: 'Candidats inscrits (CEPE vs BEPC)',
      barGroups: [
        _barre(0, cepe.toDouble(), Colors.blue),
        _barre(1, bepc.toDouble(), Colors.teal),
      ],
      labels: [
        'CEPE\n${(cepe / total * 100).toStringAsFixed(0)}%',
        'BEPC\n${(bepc / total * 100).toStringAsFixed(0)}%',
      ],
      maxY: [cepe, bepc].reduce((a, b) => a > b ? a : b).toDouble() + 2,
    );
  }

  /// Bâtonnets : candidats (CEPE+BEPC) par sexe.
  Widget _graphiqueCandidatsParSexe(
    List<Map<String, dynamic>> cepe,
    List<Map<String, dynamic>> bepc,
  ) {
    final tous = [...cepe, ...bepc];
    final garcons = tous.where((c) => c['sexe'] == 'G').length;
    final filles = tous.where((c) => c['sexe'] == 'F').length;
    final total = tous.isEmpty ? 1 : tous.length;
    return _carteGraphique(
      titre: 'Candidats par sexe',
      barGroups: [
        _barre(0, garcons.toDouble(), Colors.indigo),
        _barre(1, filles.toDouble(), Colors.pink),
      ],
      labels: [
        'Garçons\n${(garcons / total * 100).toStringAsFixed(0)}%',
        'Filles\n${(filles / total * 100).toStringAsFixed(0)}%',
      ],
      maxY: [garcons, filles].reduce((a, b) => a > b ? a : b).toDouble() + 2,
    );
  }

  BarChartGroupData _barre(int x, double valeur, Color couleur) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: valeur,
          color: couleur,
          width: 28,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _carteGraphique({
    required String titre,
    required List<BarChartGroupData> barGroups,
    required List<String> labels,
    required double maxY,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: barGroups,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneRoleEtab {
  final String codeEtab;
  final String nomEtab;
  final Map<String, int> parRole;
  _LigneRoleEtab({
    required this.codeEtab,
    required this.nomEtab,
    required this.parRole,
  });
}
