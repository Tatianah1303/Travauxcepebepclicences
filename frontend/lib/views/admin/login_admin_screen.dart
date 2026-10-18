import 'package:flutter/material.dart';

import '../../services/admin_session.dart';
import '../../services/firebase_auth_service.dart';
import '../../widgets/signature_auteur.dart';
import 'admin_dashboard_screen.dart';

/// Connexion de l'Administration CISCO. Il y a exactement DEUX admins,
/// identifiés par leur nom (ATI ou EDGS, en majuscules) — chacun a son
/// propre mot de passe qu'il peut changer lui-même.
class LoginAdminScreen extends StatefulWidget {
  const LoginAdminScreen({super.key});

  @override
  State<LoginAdminScreen> createState() => _LoginAdminScreenState();
}

class _LoginAdminScreenState extends State<LoginAdminScreen> {
  final _nomController = TextEditingController();
  final _codeController = TextEditingController();
  String? _erreur;
  bool _chargement = false;

  Future<void> _seConnecter() async {
    // Le nom doit correspondre EXACTEMENT (majuscules incluses) à un des
    // deux admins reconnus — demande explicite de l'encadreur.
    final nom = _nomController.text.trim();
    final code = _codeController.text.trim();

    if (nom.isEmpty || code.isEmpty) {
      setState(
        () => _erreur = 'Renseignez le nom de l\'agent et le mot de passe',
      );
      return;
    }

    if (!FirebaseAuthService.nomsAdminsValides.contains(nom)) {
      setState(
        () => _erreur = 'Nom inconnu. Entrez ATI ou EDGS, en majuscules.',
      );
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      await FirebaseAuthService.connecterAdmin(nomAdmin: nom, motDePasse: code);
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = 'Mot de passe incorrect ou connexion internet impossible';
      });
      return;
    }

    AdminSession.instance.connecter(codeAdmin: nom, nomAgent: nom);

    setState(() => _chargement = false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      bottomNavigationBar: const SafeArea(
        child: SignatureAuteur(couleur: Colors.white38),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Administration CISCO Vohibato',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Accès consultation et statistiques',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nomController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'agent (ATI ou EDGS)',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.key),
                        border: const OutlineInputBorder(),
                        errorText: _erreur,
                      ),
                      obscureText: true,
                      onSubmitted: (_) => _seConnecter(),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _chargement ? null : _seConnecter,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          backgroundColor: const Color(0xFF0D1B2A),
                          foregroundColor: Colors.white,
                        ),
                        child: _chargement
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Se connecter'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
