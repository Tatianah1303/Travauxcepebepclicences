import 'package:flutter/material.dart';

import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../dashboard/home_dashboard_screen.dart';

/// Écran de connexion. Un seul champ : le code établissement (le long
/// code, ex: 326020302). Pas de mot de passe séparé, pas de rôle — c'est
/// l'établissement qui se connecte, un seul compte pour tous.
///
/// La vérification se fait contre la liste 'etablissement' déjà chargée
/// en base (via SeedService au premier lancement, ou ajoutée/modifiée
/// depuis l'écran de gestion des établissements).
class LoginEtablissementScreen extends StatefulWidget {
  const LoginEtablissementScreen({super.key});

  @override
  State<LoginEtablissementScreen> createState() =>
      _LoginEtablissementScreenState();
}

class _LoginEtablissementScreenState extends State<LoginEtablissementScreen> {
  final _codeController = TextEditingController();
  String? _erreur;
  bool _chargement = false;

  Future<void> _seConnecter() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _erreur = 'Entrez le code de votre établissement');
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final etablissements = await SqliteService.instance.listerItems(
      'etablissement',
    );
    final trouve = etablissements
        .where((e) => e.champs['code'] == code)
        .toList();

    setState(() => _chargement = false);

    if (trouve.isEmpty) {
      setState(
        () => _erreur = 'Code établissement inconnu. Vérifiez le numéro saisi.',
      );
      return;
    }

    AppSession.instance.connecter(
      codeEtab: code,
      nomEtab: trouve.first.champs['nom'] ?? code,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Connexion établissement',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Entrez le code de votre établissement pour accéder à votre espace',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Code établissement',
                    border: const OutlineInputBorder(),
                    errorText: _erreur,
                  ),
                  onSubmitted: (_) => _seConnecter(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _chargement ? null : _seConnecter,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _chargement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Se connecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
