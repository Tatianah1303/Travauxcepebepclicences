import 'package:flutter/material.dart';

import '../../widgets/signature_auteur.dart';

import '../../services/firestore_listes_service.dart';
import '../../services/listes_locales.dart';
import '../../services/app_session.dart';
import '../../services/firebase_auth_service.dart';
import '../dashboard/home_dashboard_screen.dart';
import '../admin/login_admin_screen.dart';

/// Écran de connexion. Un seul champ : le code établissement (le long
/// code, ex: 326020302). Pas de mot de passe séparé, pas de rôle — c'est
/// l'établissement qui se connecte, un seul compte pour tous.
///
/// L'établissement s'authentifie d'abord avec son compte Firebase, puis le
/// code est vérifié dans le référentiel Firestore administré.
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

    try {
      await FirebaseAuthService.connecterEtablissement(code);
      final etablissements = await ListesLocales.charger('etablissement');
      final correspondants = etablissements
          .where((e) => e.champs['code'] == code)
          .toList();
      if (correspondants.isEmpty) {
        await FirebaseAuthService.deconnecter();
        if (mounted) {
          setState(
            () => _erreur =
                'Ce code n’est pas présent dans le référentiel Firestore. Contactez l’administration.',
          );
        }
        return;
      }
      final etablissement = correspondants.first;
      if (!mounted) return;
      AppSession.instance.connecter(
        codeEtab: code,
        nomEtab: etablissement.champs['nom'] ?? code,
      );
    } catch (e) {
      await FirebaseAuthService.deconnecter();
      if (!mounted) return;
      setState(() => _erreur = 'Erreur Firebase : $e');
      return;
    } finally {
      if (mounted) setState(() => _chargement = false);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: SignatureAuteur()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.jpg',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school, size: 64, color: Colors.blue),
                ),
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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginAdminScreen()),
                  ),
                  child: const Text('Administration CISCO Vohibato'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// sig:QU5UU0FOSUxBSU5BIExBTEFIIFRhdGlhbmFoIEFsc29uICgwMzQ2OTYzNTExKSBMMyBtw6ltb2lyZQ==
