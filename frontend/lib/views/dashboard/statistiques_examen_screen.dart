import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/sqlite_service.dart';

class StatistiquesExamenScreen extends StatefulWidget {
  final bool pourCepe;

  const StatistiquesExamenScreen({super.key, required this.pourCepe});

  @override
  State<StatistiquesExamenScreen> createState() =>
      _StatistiquesExamenScreenState();
}

class _StatistiquesExamenScreenState extends State<StatistiquesExamenScreen> {
  bool _chargement = true;
  List<Map<String, dynamic>> _candidats = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final String? codeEtab = AppSession.instance.codeEtab;
    final List<Map<String, dynamic>> tous;
    if (widget.pourCepe) {
      final candidats = await SqliteService.instance.listerCandidatsCepe();
      tous = candidats
          .map(
            (c) => <String, dynamic>{
              'codeEtab': c.codeEtab,
              'sexe': c.sexe,
              'handicap': c.handicap,
            },
          )
          .toList();
    } else {
      final candidats = await SqliteService.instance.listerCandidatsBepc();
      tous = candidats
          .map(
            (c) => <String, dynamic>{
              'codeEtab': c.codeEtab,
              'sexe': c.sexe,
              'handicap': c.handicap,
            },
          )
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _candidats = tous.where((c) => c['codeEtab'] == codeEtab).toList();
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _candidats.length;
    final garcons = _candidats.where((c) => c['sexe'] == 'G').length;
    final filles = _candidats.where((c) => c['sexe'] == 'F').length;
    final handicapes = _candidats.where((c) => c['handicap'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistiques ${widget.pourCepe ? 'CEPE' : 'BEPC'}'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Établissement : ${AppSession.instance.nomEtab ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _carte('Total candidats', total, Colors.indigo),
                  _carte('Garçons', garcons, Colors.blue),
                  _carte('Filles', filles, Colors.pink),
                  _carte('Candidats handicapés', handicapes, Colors.orange),
                ],
              ),
            ),
    );
  }

  Widget _carte(String titre, int valeur, Color couleur) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: couleur,
          child: const Icon(Icons.bar_chart, color: Colors.white),
        ),
        title: Text(titre),
        trailing: Text(
          '$valeur',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
