import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/quota_membre.dart';
import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';
import '../../services/admin_session.dart';
import '../../services/archive_service.dart';
import '../../utils/csv_export.dart';
import 'login_admin_screen.dart';

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
  Map<String, String> _nomsEtab = {};
  List<ItemListe> _listeEtablissements = [];
  List<_LigneRoleEtab> _tableauRoles = [];

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

    final Map<String, Map<String, int>> compte = {};
    for (final m in membres) {
      final codeEtab = etabDeMatricule[m.matriculeEnseignant];
      if (codeEtab == null) continue;
      compte.putIfAbsent(codeEtab, () => {for (final r in rolesMembre) r: 0});
      compte[codeEtab]![m.role] = (compte[codeEtab]![m.role] ?? 0) + 1;
    }

    final tableau =
        compte.entries
            .map(
              (entry) => _LigneRoleEtab(
                codeEtab: entry.key,
                nomEtab: nomsEtab[entry.key] ?? entry.key,
                parRole: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.nomEtab.compareTo(b.nomEtab));

    setState(() {
      _totalCepe = cepe.length;
      _totalBepc = bepc.length;
      _totalMembres = membres.length;
      _nomsEtab = nomsEtab;
      _listeEtablissements = etablissements;
      _tableauRoles = tableau;
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
            },
          )
          .toList();
      _chargement = false;
    });
  }

  // --------------------------------------------------------------------
  //  Exports Excel (national, toutes établissements)
  // --------------------------------------------------------------------

  Future<void> _exporterCepe() async {
    final cepe = await SqliteService.instance.listerCandidatsCepe();
    final chemin = await exporterEnCsv(
      nomFichier: 'candidats_cepe_national',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'Langue',
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
              c.langue ?? '-',
              c.etatCandidat,
            ],
          )
          .toList(),
    );
    _confirmer('Exporté : $chemin');
  }

  Future<void> _exporterBepc() async {
    final bepc = await SqliteService.instance.listerCandidatsBepc();
    final chemin = await exporterEnCsv(
      nomFichier: 'candidats_bepc_national',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'Langue',
        'Née vert',
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

  Future<void> _exporterMembres() async {
    final membres = await SqliteService.instance.listerMembres();
    final enseignants = await SqliteService.instance.listerTousEnseignants();
    final parMatricule = {for (final e in enseignants) e.matricule: e};

    final chemin = await exporterEnCsv(
      nomFichier: 'membres_previsionnels_national',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Fonction',
        'Rôle',
        'État',
      ],
      lignes: membres.map((m) {
        final e = parMatricule[m.matriculeEnseignant];
        return [
          e != null ? (_nomsEtab[e.codeEtab] ?? e.codeEtab) : '-',
          e?.nom ?? '-',
          e?.prenom ?? '-',
          e?.fonction ?? '-',
          libelleRole(m.role),
          m.etat,
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
    if (_etabFiltre == null) return liste;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: Text(
          'CISCO — ${AdminSession.instance.nomAgent ?? "Administration"}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _deconnexion,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Statistiques globales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _carteStat(
                    titre: 'Candidats CEPE',
                    valeur: _totalCepe,
                    couleur: Colors.blue,
                    icone: Icons.school,
                    onExporter: _exporterCepe,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _carteStat(
                    titre: 'Candidats BEPC',
                    valeur: _totalBepc,
                    couleur: Colors.teal,
                    icone: Icons.menu_book,
                    onExporter: _exporterBepc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _carteStat(
              titre: 'Membres prévisionnels',
              valeur: _totalMembres,
              couleur: Colors.purple,
              icone: Icons.badge,
              onExporter: _exporterMembres,
              pleineLargeur: true,
            ),

            const SizedBox(height: 28),
            const Text(
              'Membres par rôle et par établissement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: _tableauRoles.isEmpty
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
                            (r) => DataColumn(
                              label: Text(libelleRole(r).toUpperCase()),
                            ),
                          ),
                          const DataColumn(label: Text('TOTAL')),
                        ],
                        rows: _tableauRoles
                            .map(
                              (ligne) => DataRow(
                                cells: [
                                  DataCell(Text(ligne.nomEtab)),
                                  ...rolesMembre.map(
                                    (r) => DataCell(
                                      Text('${ligne.parRole[r] ?? 0}'),
                                    ),
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
            ),

            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Statistiques (graphiques)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String?>(
                  initialValue: _etabFiltre,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Filtrer par établissement (réservé admin)',
                    prefixIcon: Icon(Icons.filter_alt),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous les établissements'),
                    ),
                    ..._listeEtablissements.map(
                      (e) => DropdownMenuItem(
                        value: e.champs['code'],
                        child: Text(
                          e.champs['nom'] ?? e.champs['code'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _etabFiltre = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _graphiqueCandidatsParExamen(cepeF.length, bepcF.length),
            const SizedBox(height: 20),
            _graphiqueMembresParRole(membresF),
            const SizedBox(height: 20),
            _graphiqueCandidatsParSexe(cepeF, bepcF),

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

  Widget _carteStat({
    required String titre,
    required int valeur,
    required Color couleur,
    required IconData icone,
    required VoidCallback onExporter,
    bool pleineLargeur = false,
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

  /// Bâtonnets : membres par rôle.
  Widget _graphiqueMembresParRole(List<Map<String, dynamic>> membres) {
    final counts = {for (final r in rolesMembre) r: 0};
    for (final m in membres) {
      counts[m['role']] = (counts[m['role']] ?? 0) + 1;
    }
    final total = membres.isEmpty ? 1 : membres.length;
    return _carteGraphique(
      titre: 'Membres prévisionnels par rôle',
      barGroups: List.generate(
        rolesMembre.length,
        (i) => _barre(i, counts[rolesMembre[i]]!.toDouble(), Colors.purple),
      ),
      labels: rolesMembre
          .map(
            (r) =>
                '${libelleRole(r)}\n${(counts[r]! / total * 100).toStringAsFixed(0)}%',
          )
          .toList(),
      maxY:
          (counts.values.isEmpty
                  ? 1
                  : counts.values.reduce((a, b) => a > b ? a : b))
              .toDouble() +
          2,
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
