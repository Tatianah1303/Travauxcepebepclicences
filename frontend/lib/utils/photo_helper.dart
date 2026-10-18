import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';

/// Ouvre soit la caméra (mobile), soit la galerie de fichiers (desktop/web).
///
/// La photo est réduite directement à la prise (480 px max, qualité 60) :
/// elle pèse ainsi quelques dizaines de Ko et peut être enregistrée dans
/// Firestore (limite 1 Mo par document) sans passer par Firebase Storage.
Future<String?> prendrePhotoOuChoisirFichier() async {
  final picker = ImagePicker();

  final bool surDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  final XFile? image = await picker.pickImage(
    source: surDesktop ? ImageSource.gallery : ImageSource.camera,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 60,
  );

  return image?.path;
}

/// Vrai si [valeur] est une photo exploitable (lien http(s) ou photo
/// enregistrée directement dans Firestore au format data:image/...;base64,).
bool estPhotoValide(String? valeur) {
  if (valeur == null) return false;
  return valeur.startsWith('https://') ||
      valeur.startsWith('http://') ||
      valeur.startsWith('data:image/');
}

/// Retourne l'image à afficher pour [valeur], ou null si elle est invalide.
ImageProvider? imageDepuisPhoto(String? valeur) {
  if (valeur == null) return null;
  if (valeur.startsWith('data:image/')) {
    final virgule = valeur.indexOf(',');
    if (virgule < 0) return null;
    try {
      final Uint8List octets = base64Decode(valeur.substring(virgule + 1));
      return MemoryImage(octets);
    } catch (_) {
      return null;
    }
  }
  if (valeur.startsWith('https://') || valeur.startsWith('http://')) {
    return NetworkImage(valeur);
  }
  return null;
}
