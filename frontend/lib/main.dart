import 'package:flutter/material.dart';

import 'services/firebase_service.dart';
import 'views/auth/login_etablissement_screen.dart';
import 'config/theme.dart';

// sig:QU5UU0FOSUxBSU5BIExBTEFIIFRhdGlhbmFoIEFsc29uICgwMzQ2OTYzNTExKSBMMyBtw6ltb2lyZQ==
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connexion à Firebase (données en ligne, chat, authentification).
  await FirebaseService.initialiser();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CEPE & BEPC — CISCO Vohibato',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginEtablissementScreen(),
    );
  }
}
