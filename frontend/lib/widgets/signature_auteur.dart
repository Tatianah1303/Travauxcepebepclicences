import 'dart:convert';

import 'package:flutter/material.dart';

/// Signature de l'auteur du projet (mémoire de licence L3).
///
/// Texte discret en bas de la page de connexion. Les informations complètes
/// de l'auteur sont conservées sous forme encodée dans le code et ne
/// s'affichent qu'après 7 appuis rapides sur la signature.
class SignatureAuteur extends StatefulWidget {
  const SignatureAuteur({super.key, this.couleur});

  final Color? couleur;

  @override
  State<SignatureAuteur> createState() => _SignatureAuteurState();
}

class _SignatureAuteurState extends State<SignatureAuteur> {
  static const List<String> _p = [
    'QU5UU0FOSUxB',
    'SU5BIExBTEFI',
    'IFRhdGlhbmFo',
    'IEFsc29uICgw',
    'MzQ2OTYzNTEx',
    'KSBMMyBtw6lt',
    'b2lyZQ==',
  ];

  int _appuis = 0;
  DateTime? _dernier;

  String get _auteur => utf8.decode(base64Decode(_p.join()));

  void _toucher() {
    final maintenant = DateTime.now();
    if (_dernier == null ||
        maintenant.difference(_dernier!) > const Duration(seconds: 2)) {
      _appuis = 0;
    }
    _dernier = maintenant;
    _appuis++;
    if (_appuis >= 7) {
      _appuis = 0;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Auteur'),
          content: Text(_auteur),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toucher,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          "Alta'sAlson",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: widget.couleur ?? Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
