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
  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Listes complètes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'CEPE'),
              Tab(text: 'BEPC'),
              Tab(text: 'Membres'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_candidatsCepe(), _candidatsBepc(), _membres()],
        ),
      ),
    );
  }

  Widget _candidatsCepe() => ListView.builder(
    itemCount: cepe.length,
    itemBuilder: (_, i) {
      final c = cepe[i];
      return ListTile(
        title: Text('${c.nom} ${c.prenom}'),
        subtitle: Text(
          'Établissement: ${etab(c.codeEtab)}\nSexe: ${c.sexe} — Centre écrit: ${centre(c.codeCentreEcrit)} — Correction: ${centre(c.codeCentreCorrection)}',
        ),
      );
    },
  );
  Widget _candidatsBepc() => ListView.builder(
    itemCount: bepc.length,
    itemBuilder: (_, i) {
      final c = bepc[i];
      return ListTile(
        title: Text('${c.nom} ${c.prenom}'),
        subtitle: Text(
          'Établissement: ${etab(c.codeEtab)}\nSexe: ${c.sexe} — Centre écrit: ${centre(c.codeCentreEcrit)} — Correction: ${centre(c.codeCentreCorrection)}',
        ),
      );
    },
  );
  Widget _membres() => ListView.builder(
    itemCount: membres.length,
    itemBuilder: (_, i) {
      final m = membres[i];
      final matches = enseignants
          .where((x) => x.matricule == m.matriculeEnseignant)
          .toList();
      final e = matches.isEmpty ? null : matches.first;
      return ListTile(
        title: Text(e == null ? 'Enseignant inconnu' : '${e.nom} ${e.prenom}'),
        subtitle: Text(
          'Rôle: ${m.role}\nCIN: ${e?.cin ?? '-'} — Poste: ${e?.fonction ?? '-'}\nCentre: ${centre(m.codeCentreEcrit ?? m.codeCentreCorrection)}',
        ),
      );
    },
  );
}
