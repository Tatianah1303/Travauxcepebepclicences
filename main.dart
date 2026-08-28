import 'package:flutter/material.dart';

import 'services/seed_service.dart';
import 'services/sqlite_service.dart';
import 'views/auth/login_etablissement_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ LIGNE TEMPORAIRE — à supprimer après le premier lancement réussi.
  // Efface la base locale existante pour forcer la recréation des tables
  // avec la nouvelle structure (ex: ajout du champ codecorrection).
  await SqliteService.instance.reinitialiserBase();

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginEtablissementScreen(),
    );
  }
}
