import 'package:flutter/material.dart';

import '../enseignant/enseignant_liste_screen.dart';
import 'quota_membre_screen.dart';
import 'designation_membre_screen.dart';
import 'attribution_centre_membre_screen.dart';
import 'liste_membre_screen.dart';

/// Point d'entrée pour tout ce qui concerne les membres prévisionnels.
/// Ordre logique : 1) enseignants, 2) quotas, 3) désignation, 4) attribution
/// par centre (le centre de correction étant déduit automatiquement du
/// centre d'écrit pour les rôles autres que Correcteur).
class MembreHubScreen extends StatelessWidget {
  final String typeExamen;

  const MembreHubScreen({super.key, required this.typeExamen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Membres prévisionnels — $typeExamen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('1')),
              title: const Text('Gérer les enseignants'),
              subtitle: const Text(
                'Ajouter les enseignants de l\'établissement',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EnseignantListeScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('2')),
              title: const Text('Définir les quotas'),
              subtitle: const Text('Nombre de membres voulu par rôle'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuotaMembreScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('3')),
              title: const Text('Désigner les membres'),
              subtitle: const Text(
                'Choisir les enseignants et capturer leur CIN',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DesignationMembreScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('4')),
              title: const Text('Attribuer par centre'),
              subtitle: const Text(
                'Centre d\'écrit (jury) ou centre de correction (correcteur)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AttributionCentreMembreScreen(typeExamen: typeExamen),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.list, size: 18)),
              title: const Text('Voir la liste des membres'),
              subtitle: const Text('Filtrer par rôle, voir les CIN, exporter'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ListeMembresScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
