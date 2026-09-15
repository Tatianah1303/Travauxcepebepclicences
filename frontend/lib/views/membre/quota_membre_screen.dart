import 'package:flutter/material.dart';

import '../../models/quota_membre.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';

/// L'établissement fixe ici combien de membres il prévoit de fournir pour
/// chaque rôle (Jury, Correcteur, Chef de centre, Sécurité), avant de
/// désigner les enseignants un par un (voir DesignationMembreScreen).
class QuotaMembreScreen extends StatefulWidget {
  final String typeExamen;
  const QuotaMembreScreen({super.key, required this.typeExamen});

  @override
  State<QuotaMembreScreen> createState() => _QuotaMembreScreenState();
}

class _QuotaMembreScreenState extends State<QuotaMembreScreen> {
  final Map<String, int> _valeurs = {for (final role in rolesMembre) role: 0};

  bool _chargement = true;
  bool _enregistrement = false;

  int get _anneeSession => DateTime.now().year;
  String get _codeEtab => AppSession.instance.codeEtab ?? '';
  int get _total => _valeurs.values.fold(0, (a, b) => a + b);

  static const Map<String, IconData> _icones = {
    'Jury': Icons.groups,
    'Correcteur': Icons.edit_note,
    'ChefDeCentre': Icons.supervisor_account,
    'Securite': Icons.security,
  };

  static const Map<String, Color> _couleurs = {
    'Jury': Colors.indigo,
    'Correcteur': Colors.teal,
    'ChefDeCentre': Colors.deepOrange,
    'Securite': Colors.blueGrey,
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final quotas = await SqliteService.instance.listerQuotas(
      codeEtab: _codeEtab,
      anneeSession: _anneeSession,
      typeExamen: widget.typeExamen,
    );
    for (final q in quotas) {
      _valeurs[q.role] = q.quantite;
    }
    setState(() => _chargement = false);
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrement = true);
    for (final role in rolesMembre) {
      await SqliteService.instance.definirQuota(
        QuotaMembre(
          codeEtab: _codeEtab,
          anneeSession: _anneeSession,
          typeExamen: widget.typeExamen,
          role: role,
          quantite: _valeurs[role] ?? 0,
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: Text('Quotas de membres — ${widget.typeExamen}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.indigo.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.indigo.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Combien de membres prévoyez-vous de fournir pour '
                      'chaque rôle cette année ?',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          for (final role in rolesMembre) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (_couleurs[role] ?? Colors.grey)
                          .withValues(alpha: 0.12),
                      child: Icon(
                        _icones[role] ?? Icons.person,
                        color: _couleurs[role] ?? Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        libelleRole(role),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.grey.shade700,
                      onPressed: (_valeurs[role] ?? 0) <= 0
                          ? null
                          : () => setState(
                              () => _valeurs[role] = (_valeurs[role] ?? 0) - 1,
                            ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${_valeurs[role] ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: _couleurs[role] ?? Colors.grey,
                      ),
                      onPressed: () => setState(
                        () => _valeurs[role] = (_valeurs[role] ?? 0) + 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Total prévu',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '$_total',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _enregistrement ? null : _enregistrer,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
            child: _enregistrement
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enregistrer les quotas'),
          ),
        ],
      ),
    );
  }
}
