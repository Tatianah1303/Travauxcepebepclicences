import 'package:flutter/material.dart';

import 'cepe_dashboard_screen.dart';
import 'bepc_dashboard_screen.dart';
import '../../services/app_session.dart';
import '../auth/login_etablissement_screen.dart';

/// Écran d'accueil : le point d'entrée après connexion. Affiche le nom de
/// l'établissement connecté en haut. Deux gros boutons : CEPE et BEPC.
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nomEtab = AppSession.instance.nomEtab ?? 'Établissement';

    return Scaffold(
      appBar: AppBar(
        title: Text(nomEtab),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () {
              AppSession.instance.deconnecter();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const LoginEtablissementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choisissez l\'examen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _BoutonExamen(
                titre: 'CEPE',
                sousTitre: 'Certificat d\'Études Primaires Élémentaires',
                couleur: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CepeDashboardScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _BoutonExamen(
                titre: 'BEPC',
                sousTitre: 'Brevet d\'Études du Premier Cycle',
                couleur: Colors.teal,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BepcDashboardScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonExamen extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final Color couleur;
  final VoidCallback onTap;

  const _BoutonExamen({
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: couleur,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sousTitre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
