import 'package:flutter/material.dart';

import '../../models/quota_membre.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';

/// L'établissement fixe ici combien de membres il prévoit de fournir pour
/// chaque rôle (Jury, Correcteur, Chef de centre, Sécurité), avant de
/// désigner les enseignants un par un (voir DesignationMembreScreen).
class QuotaMembreScreen extends StatefulWidget {
  const QuotaMembreScreen({super.key});

  @override
  State<QuotaMembreScreen> createState() => _QuotaMembreScreenState();
}

class _QuotaMembreScreenState extends State<QuotaMembreScreen> {
  final Map<String, TextEditingController> _controllers = {
    for (final role in rolesMembre) role: TextEditingController(text: '0'),
  };

  bool _chargement = true;

  int get _anneeSession => DateTime.now().year;
  String get _codeEtab => AppSession.instance.codeEtab ?? '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final quotas = await SqliteService.instance.listerQuotas(
      codeEtab: _codeEtab,
      anneeSession: _anneeSession,
    );
    for (final q in quotas) {
      _controllers[q.role]?.text = q.quantite.toString();
    }
    setState(() => _chargement = false);
  }

  Future<void> _enregistrer() async {
    for (final role in rolesMembre) {
      final quantite = int.tryParse(_controllers[role]!.text.trim()) ?? 0;
      await SqliteService.instance.definirQuota(
        QuotaMembre(
          codeEtab: _codeEtab,
          anneeSession: _anneeSession,
          role: role,
          quantite: quantite,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Quotas enregistrés')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Définir les quotas de membres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Combien de membres prévoyez-vous de fournir pour chaque rôle cette année ?',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          for (final role in rolesMembre)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[role],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: libelleRole(role),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _enregistrer,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
            child: const Text('Enregistrer les quotas'),
          ),
        ],
      ),
    );
  }
}
