import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_options.dart';

/// Initialise la connexion Firebase (Firestore) au démarrage de l'app.
/// Doit être appelé une seule fois, avant `runApp()`, dans `main.dart`.
class FirebaseService {
  static bool _initialise = false;

  static Future<void> initialiser() async {
    if (_initialise) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // L'application est explicitement en ligne : aucune persistance locale
    // Firestore sur l'appareil (les écrans nécessitent une connexion réseau).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    _initialise = true;
  }
}
