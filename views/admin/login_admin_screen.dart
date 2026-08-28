import 'package:flutter/material.dart';

import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';
import '../../services/admin_session.dart';
import 'admin_dashboard_screen.dart';

/// Connexion de l'Administration CISCO. Deux champs : nom de l'agent et
/// code admin. S'il n'existe encore aucun compte admin en base, la
/// première connexion crée automatiquement ce compte (bootstrap) — sinon
/// le code doit correspondre exactement à un compte déjà enregistré.
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
    final nom = _nomController.text.trim();
    final code = _codeController.text.trim();

    if (nom.isEmpty || code.isEmpty) {
      setState(
        () => _erreur = 'Renseignez le nom de l\'agent et le code admin',
      );
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final admins = await SqliteService.instance.listerItems('admin');

    if (admins.isEmpty) {
      // Bootstrap : premier compte admin créé automatiquement
      await SqliteService.instance.insererItemListe(
        ItemListe(
          id: 'admin_$code',
          typeListe: 'admin',
          champs: {'code': code, 'nom': nom},
        ),
      );
      AdminSession.instance.connecter(codeAdmin: code, nomAgent: nom);
    } else {
      final trouve = admins.where((a) => a.champs['code'] == code).toList();
      if (trouve.isEmpty) {
        setState(() {
          _chargement = false;
          _erreur = 'Code admin incorrect';
        });
        return;
      }
      AdminSession.instance.connecter(
        codeAdmin: code,
        nomAgent: trouve.first.champs['nom'] ?? nom,
      );
    }

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
                      'Administration CISCO',
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
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'agent',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: 'Code admin',
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
