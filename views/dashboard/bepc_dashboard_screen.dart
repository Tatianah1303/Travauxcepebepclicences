import 'package:flutter/material.dart';

import '../listes/listes_menu_screen.dart';
import '../candidat/formulaire_bepc_screen.dart';
import '../candidat/liste_candidats_screen.dart';
import '../salle/formulaire_salle_screen.dart';
import '../membre/membre_hub_screen.dart';

/// Dashboard spécifique au BEPC : mêmes actions que le CEPE mais avec les
/// listes propres au BEPC (lycée d'accueil au lieu de CEG d'accueil,
/// groupes I/II/III au lieu de A/B/C).
class BepcDashboardScreen extends StatelessWidget {
  const BepcDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard BEPC')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ListesMenuScreen(pourCepe: false),
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CarteAction(
            titre: 'Inscrire un candidat',
            icone: Icons.person_add,
            couleur: Colors.teal,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FormulaireBepcScreen()),
            ),
          ),
          _CarteAction(
            titre: 'Liste des candidats',
            icone: Icons.list_alt,
            couleur: Colors.indigo,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ListeCandidatsScreen(pourCepe: false),
              ),
            ),
          ),
          _CarteAction(
            titre: 'Gérer les salles',
            icone: Icons.meeting_room,
            couleur: Colors.orange,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FormulaireSalleScreen(typeExamen: 'BEPC'),
              ),
            ),
          ),
          _CarteAction(
            titre: 'Désigner un membre prévisionnel',
            icone: Icons.badge,
            couleur: Colors.purple,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MembreHubScreen(typeExamen: 'BEPC'),
              ),
            ),
          ),
          _CarteAction(
            titre: 'Statistiques BEPC',
            icone: Icons.bar_chart,
            couleur: Colors.brown,
            onTap: () {
              // TODO : écran de statistiques
            },
          ),
        ],
      ),
    );
  }
}

class _CarteAction extends StatelessWidget {
  final String titre;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  const _CarteAction({
    required this.titre,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: couleur,
          child: Icon(icone, color: Colors.white),
        ),
        title: Text(titre),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
