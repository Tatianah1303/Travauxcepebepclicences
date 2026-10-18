import 'package:flutter/material.dart';

import '../../models/quota_membre.dart';
import '../../models/item_liste.dart';
import '../../services/firestore_service.dart';
import '../../services/admin_session.dart';
import '../../services/archive_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_listes_service.dart';
import '../../services/listes_locales.dart';
import '../../models/periode_saisie.dart';
import '../../services/seed_service.dart';
import '../../utils/enregistrer_fichier.dart';
import 'login_admin_screen.dart';
import '../chat/liste_conversation_admin_screen.dart';
import 'listes_admin_screen.dart';
import '../listes/listes_menu_screen.dart';
import '../admin/peridode_saisie_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<ItemListe> _listeEtablissements = [];

  List<Map<String, dynamic>> _candidatsCepeRaw = [];
  List<Map<String, dynamic>> _candidatsBepcRaw = [];
  List<Map<String, dynamic>> _membresRaw = [];

  String? _zapFiltre;
  bool _chargement = true;
  bool _archivageEnCours = false;

  void _message(String titre, String texte) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(texte),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    SeedService.semerSiVide().catchError((_) {});
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);

    final cepe = await FirestoreService.instance.listerTousCandidatsCepe();
    final bepc = await FirestoreService.instance.listerTousCandidatsBepc();
    final membres = await FirestoreService.instance.listerTousMembres();
    final enseignants = await FirestoreService.instance.listerTousEnseignants();
    final listeItems = await ListesLocales.charger('etablissement');

    final etabDeMatricule = {
      for (final e in enseignants) e.matricule: e.codeEtab,
    };
    final sexeDeMatricule = {for (final e in enseignants) e.matricule: e.sexe};

    if (!mounted) return;
    setState(() {
      _listeEtablissements = listeItems;
      _candidatsCepeRaw = cepe
          .map((c) => {'codeEtab': c.codeEtab, 'sexe': c.sexe})
          .toList();
      _candidatsBepcRaw = bepc
          .map((c) => {'codeEtab': c.codeEtab, 'sexe': c.sexe})
          .toList();
      _membresRaw = membres
          .map(
            (m) => {
              'codeEtab': m.codeEtab ?? etabDeMatricule[m.matriculeEnseignant],
              'role': m.role,
              'sexe': sexeDeMatricule[m.matriculeEnseignant],
              'typeExamen': m.typeExamen,
            },
          )
          .toList();
      _chargement = false;
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _confirmer(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _archiverEtCloturer() async {
    // La clôture n'est possible qu'APRÈS la date de fin de la période de saisie.
    PeriodeSaisie? periode;
    try {
      periode = await FirestoreService.instance.lirePeriodeSaisie();
    } catch (e) {
      _message(
        'Clôture impossible',
        'Impossible de lire la période de saisie : $e',
      );
      return;
    }
    if (!mounted) return;
    if (periode == null) {
      _message(
        'Clôture impossible',
        'Aucune période de saisie n’est définie. Définissez-la d’abord (menu ⋮ → '
            'Période de saisie) : la clôture n’est possible qu’après sa date de fin.',
      );
      return;
    }
    if (periode.statut != StatutSaisie.termine) {
      _message(
        'Clôture impossible pour le moment',
        'La clôture de la session ne sera possible qu’après la date de fin de la '
            'période de saisie : ${_fmtDate(periode.dateFin)}.',
      );
      return;
    }
    final annee = periode.dateFin.year;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver et clôturer la session ?'),
        content: Text(
          'Un ZIP sera d’abord enregistré à l’emplacement que vous choisirez, puis les données '
          'actives de la session $annee (candidats, membres, salles, quotas et attributions de salles) seront supprimées de Firestore, '
          'pour l’administration comme pour tous les établissements. '
          'Cette action est irréversible. Continuer ?',
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
    try {
      final urlArchive = await ArchiveService.archiverEtCloturerSession(annee);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archive enregistrée : $urlArchive')),
      );
      await _charger();
    } on EnregistrementAnnule catch (e) {
      _confirmer('$e');
    } catch (e) {
      _confirmer(
        'Échec de l’archivage : $e. Vérifiez l’archive et l’état des données dans Firebase avant de recommencer.',
      );
    } finally {
      if (mounted) setState(() => _archivageEnCours = false);
    }
  }

  void _deconnexion() {
    AdminSession.instance.deconnecter();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginAdminScreen()),
    );
  }

  Future<void> _changerMotDePasse() async {
    final controleur = TextEditingController();
    final confirmation = TextEditingController();
    final nouveauMdp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le mot de passe admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controleur,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (controleur.text.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Minimum 6 caractères')),
                );
                return;
              }
              if (controleur.text != confirmation.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Les deux mots de passe ne correspondent pas',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop(controleur.text);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (nouveauMdp == null) return;
    try {
      await FirebaseAuthService.changerMotDePasseAdmin(nouveauMdp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe modifié avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              } else if (valeur == 'references_cepe') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ListesMenuScreen(pourCepe: true),
                  ),
                );
              } else if (valeur == 'references_bepc') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ListesMenuScreen(pourCepe: false),
                  ),
                );
              } else if (valeur == 'listes') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ListesAdminScreen()),
                );
              } else if (valeur == 'deconnexion') {
                _deconnexion();
              } else if (valeur == 'motdepasse') {
                _changerMotDePasse();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'references_cepe',
                child: ListTile(
                  leading: Icon(Icons.dataset),
                  title: Text('Référentiels CEPE'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'references_bepc',
                child: ListTile(
                  leading: Icon(Icons.dataset),
                  title: Text('Référentiels BEPC'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
                value: 'motdepasse',
                child: ListTile(
                  leading: Icon(Icons.lock_reset),
                  title: Text('Changer le mot de passe'),
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
            DropdownButtonFormField<String>(
              value: _zapFiltre,
              decoration: const InputDecoration(
                labelText: 'Filtrer par ZAP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Toutes les ZAP'),
                ),
                ...(_listeEtablissements
                        .map((e) => e.champs['zap'])
                        .whereType<String>()
                        .where((z) => z.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort())
                    .map(
                      (z) => DropdownMenuItem<String>(value: z, child: Text(z)),
                    ),
              ],
              onChanged: (z) => setState(() => _zapFiltre = z),
            ),
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
            const SizedBox(height: 16),
            if (_zapFiltre == null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Choisissez une ZAP ci-dessus\npour afficher les statistiques de ses établissements',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(
                'ZAP $_zapFiltre — ${_etablissementsDeLaZap.length} établissement(s)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (final etab in _etablissementsDeLaZap)
                _blocEtablissement(etab),
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
                      'Disponible seulement après la date de fin de la période de saisie. '
                      'Archive les données de la session en .zip, puis les supprime '
                      '(listes de l’administration et des établissements) pour préparer la session suivante.',
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

  List<ItemListe> get _etablissementsDeLaZap {
    final liste = _listeEtablissements
        .where((e) => e.champs['zap'] == _zapFiltre)
        .toList();
    liste.sort(
      (a, b) => (a.champs['nom'] ?? '').compareTo(b.champs['nom'] ?? ''),
    );
    return liste;
  }

  /// Carte d'un établissement : son nom, puis le nombre de candidats
  /// (garçons / filles) CEPE et BEPC, puis les membres par rôle.
  Widget _blocEtablissement(ItemListe etab) {
    final code = etab.champs['code'];
    final nom = etab.champs['nom'] ?? code ?? '';
    final cepe = _candidatsCepeRaw.where((c) => c['codeEtab'] == code).toList();
    final bepc = _candidatsBepcRaw.where((c) => c['codeEtab'] == code).toList();
    final membres = _membresRaw.where((m) => m['codeEtab'] == code).toList();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nom,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _ligneCandidats('Candidats CEPE', cepe, Colors.blue),
            const SizedBox(height: 10),
            _ligneCandidats('Candidats BEPC', bepc, Colors.teal),
            _blocRoles(
              'Membres CEPE',
              membres.where((m) => m['typeExamen'] == 'CEPE').toList(),
              Colors.purple,
            ),
            _blocRoles(
              'Membres BEPC',
              membres.where((m) => m['typeExamen'] == 'BEPC').toList(),
              Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneCandidats(
    String titre,
    List<Map<String, dynamic>> candidats,
    Color couleur,
  ) {
    final garcons = candidats.where((c) => c['sexe'] == 'G').length;
    final filles = candidats.where((c) => c['sexe'] == 'F').length;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$titre (${candidats.length})',
            style: TextStyle(fontWeight: FontWeight.w600, color: couleur),
          ),
        ),
        Text('Garçons : $garcons'),
        const SizedBox(width: 14),
        Text('Filles : $filles'),
      ],
    );
  }

  /// Membres par rôle : seuls les rôles qui ont au moins un membre sont
  /// affichés ; si aucun membre, la section n'apparaît pas.
  Widget _blocRoles(
    String titre,
    List<Map<String, dynamic>> membres,
    Color couleur,
  ) {
    final Map<String, int> parRole = {};
    for (final m in membres) {
      final role = '${m['role']}';
      parRole[role] = (parRole[role] ?? 0) + 1;
    }
    if (parRole.isEmpty) return const SizedBox.shrink();

    final roles = [
      ...rolesMembre.where(parRole.containsKey),
      ...parRole.keys.where((r) => !rolesMembre.contains(r)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$titre (${membres.length})',
            style: TextStyle(fontWeight: FontWeight.w600, color: couleur),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final r in roles)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${libelleRole(r)} : ${parRole[r]}',
                    style: TextStyle(fontSize: 12, color: couleur),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
