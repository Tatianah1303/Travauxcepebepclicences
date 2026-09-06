import 'package:flutter/material.dart';

import 'services/seed_service.dart';
import 'views/auth/login_etablissement_screen.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charge les listes réelles (établissements, écoles d'origine, CEG/lycée
  // d'accueil, centres, groupes, langues, sports...) dans la base locale,
  // une seule fois. Les fois suivantes, ne fait rien (déjà semé).
  await SeedService.semerSiVide();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginEtablissementScreen(),
    );
  }
}