import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// Ouvre soit la caméra (mobile), soit la galerie de fichiers (desktop/web).
///
/// Pourquoi : `ImageSource.camera` ne fonctionne pas sur Windows/Linux/macOS
/// desktop avec image_picker (pas d'accès caméra natif géré par le plugin).
/// Sur Android/iOS en revanche, la caméra fonctionne normalement.
///
/// Donc en développement/test sur Windows, ce helper ouvre automatiquement
/// le sélecteur de fichiers à la place — pratique pour simuler une photo
/// sans bloquer les tests. Une fois sur un vrai téléphone, la vraie caméra
/// s'ouvre automatiquement (aucun changement de code nécessaire).
Future<String?> prendrePhotoOuChoisirFichier() async {
  final picker = ImagePicker();

  final bool surDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  final XFile? image = await picker.pickImage(
    source: surDesktop ? ImageSource.gallery : ImageSource.camera,
  );

  return image?.path;
}
