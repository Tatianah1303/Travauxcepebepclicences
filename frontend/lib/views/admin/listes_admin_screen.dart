import 'package:flutter/material.dart';
import '../../models/candidat_cepe.dart';
import '../../models/candidat_bepc.dart';
import '../../models/enseignant.dart';
import '../../models/membre_previsionnel.dart';
import '../../services/sqlite_service.dart';

class ListesAdminScreen extends StatefulWidget {
  const ListesAdminScreen({super.key});
  @override
  State<ListesAdminScreen> createState() => _ListesAdminScreenState();
}

class _ListesAdminScreenState extends State<ListesAdminScreen> {
  bool loading = true;
  List<CandidatCepe> cepe = [];
  List<CandidatBepc> bepc = [];
  List<MembrePrevisionnel> membres = [];
  List<Enseignant> enseignants = [];
  Map<String, String> etablissements = {}, centres = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = SqliteService.instance;
    final ce = await db.listerCandidatsCepe();
    final be = await db.listerCandidatsBepc();
    final ms = await db.listerMembres();
    final es = await db.listerTousEnseignants();
    final ets = await db.listerItems('etablissement');
    final items = [
      ...await db.listerItems('centreEcritCepe'),
      ...await db.listerItems('centreCorrectionCepe'),
      ...await db.listerItems('centreEcritBepc'),
      ...await db.listerItems('centreCorrectionBepc'),
    ];
    if (!mounted) return;
    setState(() {
      cepe = ce;
      bepc = be;
      membres = ms;
      enseignants = es;
      etablissements = {
        for (final x in ets)
          (x.champs['code'] ?? ''): (x.champs['nom'] ?? x.champs['code'] ?? ''),
      };
      centres = {
        for (final x in items)
          (x.champs['code'] ?? ''):
              (x.champs['libelle'] ??
              x.champs['nom'] ??
              x.champs['code'] ??
              ''),
      };
      loading = false;
    });
  }

  String etab(String c) => etablissements[c] ?? c;
  String centre(String? c) => c == null || c.isEmpty ? '-' : (centres[c] ?? c);

  /// Regroupe une liste d'éléments par établissement (via [codeEtabDe]) et
  /// trie les groupes par nom d'établissement, pour afficher un petit
  /// titre par établissement au-dessus de sa liste (point 4 de la demande).
  Map<String, List<T>> _grouperParEtab<T>(
    List<T> items,
    String Function(T) codeEtabDe,
  ) {
    final Map<String, List<T>> groupes = {};
    for (final item in items) {
      final code = codeEtabDe(item);
      groupes.putIfAbsent(code, () => []).add(item);
    }
    final entriesTriees = groupes.entries.toList()
      ..sort((a, b) => etab(a.key).compareTo(etab(b.key)));
    return {for (final e in entriesTriees) e.key: e.value};
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('Listes complètes'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'CEPE'),
              Tab(text: 'BEPC'),
              Tab(text: 'Membres CEPE'),
              Tab(text: 'Membres BEPC'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _candidatsCepe(),
            _candidatsBepc(),
            _membres('CEPE'),
            _membres('BEPC'),
          ],
        ),
      ),
    );
  }

  /// En-tête compact affichant le nom de l'établissement au-dessus de sa
  /// liste, avec le nombre d'éléments qu'il contient.
  Widget _titreGroupe(String nom, int nombre, {required Color couleur}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nom,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$nombre',
              style: TextStyle(
                color: couleur,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteVide(String message) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
    ),
  );

  Widget _candidatsCepe() {
    if (cepe.isEmpty) return _carteVide('Aucun candidat CEPE');
    final groupes = _grouperParEtab<CandidatCepe>(cepe, (c) => c.codeEtab);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        for (final entry in groupes.entries) ...[
          _titreGroupe(
            etab(entry.key),
            entry.value.length,
            couleur: Colors.blue,
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++) ...[
                  if (i != 0) const Divider(height: 1),
                  _ligneCandidat(entry.value[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _candidatsBepc() {
    if (bepc.isEmpty) return _carteVide('Aucun candidat BEPC');
    final groupes = _grouperParEtab<CandidatBepc>(bepc, (c) => c.codeEtab);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        for (final entry in groupes.entries) ...[
          _titreGroupe(
            etab(entry.key),
            entry.value.length,
            couleur: Colors.teal,
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++) ...[
                  if (i != 0) const Divider(height: 1),
                  _ligneCandidat(entry.value[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  /// Une ligne fonctionne pour CandidatCepe et CandidatBepc (mêmes champs
  /// nom, prenom, sexe, codeCentreEcrit, codeCentreCorrection).
  Widget _ligneCandidat(dynamic c) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: c.sexe == 'F'
            ? Colors.pink.shade100
            : Colors.blue.shade100,
        child: Text(
          c.sexe == 'F' ? 'F' : 'G',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text('${c.nom} ${c.prenom}'),
      subtitle: Text(
        'Centre écrit : ${centre(c.codeCentreEcrit)} — Correction : ${centre(c.codeCentreCorrection)}',
      ),
    );
  }

  Widget _membres(String typeExamen) {
    final membresType = membres
        .where((m) => m.typeExamen == typeExamen)
        .toList();
    if (membresType.isEmpty) {
      return _carteVide('Aucun membre prévisionnel $typeExamen');
    }
    String codeEtabDe(MembrePrevisionnel m) {
      final matches = enseignants.where(
        (x) => x.matricule == m.matriculeEnseignant,
      );
      return matches.isEmpty ? '' : matches.first.codeEtab;
    }

    final groupes = _grouperParEtab<MembrePrevisionnel>(
      membresType,
      codeEtabDe,
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        for (final entry in groupes.entries) ...[
          _titreGroupe(
            etab(entry.key),
            entry.value.length,
            couleur: Colors.purple,
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++) ...[
                  if (i != 0) const Divider(height: 1),
                  _ligneMembre(entry.value[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _ligneMembre(MembrePrevisionnel m) {
    final matches = enseignants.where(
      (x) => x.matricule == m.matriculeEnseignant,
    );
    final e = matches.isEmpty ? null : matches.first;
    return ListTile(
      dense: true,
      leading: const CircleAvatar(
        radius: 16,
        child: Icon(Icons.person, size: 16),
      ),
      title: Text(e == null ? 'Enseignant inconnu' : '${e.nom} ${e.prenom}'),
      subtitle: Text(
        'Rôle : ${m.role} — CIN : ${e?.cin ?? '-'} — Poste : ${e?.fonction ?? '-'}\n'
        'Centre : ${centre(m.codeCentreEcrit ?? m.codeCentreCorrection)}',
      ),
    );
  }
}
