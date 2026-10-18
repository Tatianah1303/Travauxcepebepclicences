import 'package:flutter/material.dart';

import '../../services/seed_service.dart';
import '../../services/firestore_listes_service.dart';

/// Types de listes que l'administration initialise dans Firestore à partir
/// des références fournies avec le projet. Les données utilisateurs ne sont
/// ni importées ni déplacées par cette opération.
const _typesListes = [
  'etablissement',
  'ecoleOrigineCepe',
  'ecoleOrigineBepc',
  'cegAccueil',
  'lyceeAccueil',
  'centreEcritCepe',
  'centreCorrectionCepe',
  'centreEcritBepc',
  'centreCorrectionBepc',
  'groupeCepe',
  'groupeBepc',
  'langue',
  'typeHandicap',
  'sportCollectif',
  'sportIndividuel',
];

class MigrationCloudScreen extends StatefulWidget {
  const MigrationCloudScreen({super.key});

  @override
  State<MigrationCloudScreen> createState() => _MigrationCloudScreenState();
}

class _MigrationCloudScreenState extends State<MigrationCloudScreen> {
  bool _enCours = false;
  final Map<String, int> _resultats = {};
  String? _erreur;

  Future<void> _migrer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
      _resultats.clear();
    });

    try {
      // État avant : permet de distinguer les listes déjà en ligne des listes
      // nouvellement initialisées. Les éléments déjà présents sont conservés.
      final avant = <String, int>{};
      for (final type in _typesListes) {
        avant[type] = (await FirestoreListesService.listerItems(type)).length;
      }
      await SeedService.semerSiVide();
      for (final type in _typesListes) {
        final apres = (await FirestoreListesService.listerItems(type)).length;
        setState(() => _resultats[type] = apres - (avant[type] ?? 0));
      }
    } catch (e) {
      setState(() => _erreur = 'Erreur : $e');
    } finally {
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _resultats.values.fold(0, (a, b) => a + b);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: const Text('Listes de référence Firestore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Initialise les référentiels (établissements, écoles, centres, CEG/lycées) '
                      'dans Firestore depuis les données de référence du projet. '
                      'Cette action ne copie pas de candidats, de membres ou de '
                      'données SQLite. Les listes déjà présentes en ligne ne '
                      'sont pas remplacées.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_erreur != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _erreur!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),

          ElevatedButton.icon(
            onPressed: _enCours ? null : _migrer,
            icon: _enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(
              _enCours
                  ? 'Initialisation en cours...'
                  : 'Initialiser / vérifier Firestore',
            ),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),

          if (_resultats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Résultat : $total élément(s) initialisé(s)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: _resultats.entries
                    .map(
                      (e) => ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text(
                          e.value == 0 ? 'déjà présent' : '${e.value} ajoutés',
                          style: TextStyle(
                            color: e.value == 0
                                ? Colors.grey
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
