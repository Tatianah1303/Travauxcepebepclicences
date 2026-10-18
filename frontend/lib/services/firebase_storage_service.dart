import 'dart:convert';
import 'dart:io';

/// Préparation des photos sélectionnées par image_picker.
///
/// Firebase Storage (formule Blaze) n'est plus utilisé : la photo, déjà
/// réduite par image_picker, est convertie en texte (data:image/jpeg;base64)
/// et enregistrée directement dans le document Firestore (champ `photo`).
/// Le nom de la classe et de la méthode est conservé pour ne pas modifier les
/// écrans qui l'appellent.
class FirebaseStorageService {
  /// Taille maximale de la photo encodée (Firestore limite un document à 1 Mo).
  static const int _tailleMaxOctets = 600 * 1024;

  static Future<String> envoyerPhoto({
    required String cheminLocal,
    String? cheminCloudSansExtension, // ignoré : plus de Storage
  }) async {
    final fichier = File(cheminLocal);
    try {
      if (!await fichier.exists()) {
        throw StateError('Le fichier temporaire de la photo est introuvable.');
      }
      final octets = await fichier.readAsBytes();
      if (octets.length > _tailleMaxOctets) {
        throw StateError(
          'La photo est trop lourde (${octets.length ~/ 1024} Ko). '
          'Reprenez-la.',
        );
      }
      return 'data:image/jpeg;base64,${base64Encode(octets)}';
    } finally {
      // On ne conserve jamais la copie temporaire du cache de l'application.
      try {
        if (await fichier.exists()) await fichier.delete();
      } catch (_) {}
    }
  }

  static Future<void> supprimerPhotoTemporaire(String cheminLocal) async {
    try {
      final fichier = File(cheminLocal);
      if (await fichier.exists()) await fichier.delete();
    } catch (_) {}
  }
}
