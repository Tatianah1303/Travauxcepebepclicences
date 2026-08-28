import 'package:flutter/material.dart';

import '../listes/listes_menu_screen.dart';
import '../candidat/formulaire_cepe_screen.dart';
import '../salle/formulaire_salle_screen.dart';
import '../membre/membre_hub_screen.dart';
import '../candidat/liste_candidats_screen.dart';

/// Dashboard spécifique au CEPE : regroupe tous les boutons d'action liés
/// à cet examen (formulaire candidat, salles, membres, listes de
/// référence CEPE : établissement, école d'origine, CEG d'accueil...).
class CepeDashboardScreen extends StatelessWidget {
  const CepeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard CEPE')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ListesMenuScreen(pourCepe: true),
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
            couleur: Colors.blue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FormulaireCepeScreen()),
            ),
          ),
          _CarteAction(
            titre: 'Liste des candidats',
            icone: Icons.list_alt,
            couleur: Colors.indigo,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ListeCandidatsScreen(pourCepe: true),
              ),
            ),
          ),
          _CarteAction(
            titre: 'Gérer les salles',
            icone: Icons.meeting_room,
            couleur: Colors.orange,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FormulaireSalleScreen(typeExamen: 'CEPE'),
              ),
            ),
          ),
          _CarteAction(
            titre: 'Désigner un membre prévisionnel',
            icone: Icons.badge,
            couleur: Colors.purple,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MembreHubScreen(typeExamen: 'CEPE'),
              ),
            ),
          ),
          _CarteAction(
            titre: 'Statistiques CEPE',
            icone: Icons.bar_chart,
            couleur: Colors.teal,
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
