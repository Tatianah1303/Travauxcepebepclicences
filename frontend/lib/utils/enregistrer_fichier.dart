import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Levée quand l'utilisateur ferme la fenêtre « Enregistrer sous » sans choisir.
class EnregistrementAnnule implements Exception {
  final String message;
  const EnregistrementAnnule([this.message = 'Enregistrement annulé.']);
  @override
  String toString() => message;
}

// Canal vers MainActivity.kt (fenêtre « Enregistrer sous » native d'Android).
// Aucun paquet externe : rien à télécharger au moment du build.
const MethodChannel _canal = MethodChannel('cisco/enregistrer_fichier');

String _typeMime(String nom) {
  final n = nom.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.zip')) return 'application/zip';
  if (n.endsWith('.csv')) return 'text/csv';
  return 'application/octet-stream';
}

/// Rend lisible l'adresse renvoyée par Android
/// (content://…/document/primary%3ADownload%2Ffichier.csv).
String _lisible(String uri) {
  final decode = Uri.decodeComponent(uri);
  final i = decode.lastIndexOf('/document/');
  if (i < 0) return 'emplacement choisi';
  return decode.substring(i + 10).replaceFirst('primary:', 'Stockage interne/');
}

/// Ouvre la fenêtre « Enregistrer sous » : l'utilisateur choisit lui-même le
/// dossier et le nom du fichier. Retourne l'emplacement choisi.
/// Lève [EnregistrementAnnule] s'il ferme la fenêtre sans choisir.
Future<String> enregistrerFichier({
  required String nomFichier,
  required Uint8List octets,
}) async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final resultat = await _canal.invokeMethod<String>('enregistrer', {
        'nom': nomFichier,
        'mime': _typeMime(nomFichier),
        'octets': octets,
      });
      if (resultat == null) throw const EnregistrementAnnule();
      return _lisible(resultat);
    } on MissingPluginException {
      // MainActivity.kt n'a pas été mis à jour : on range le fichier dans le
      // dossier de l'application (voir android_a_copier/LISEZMOI.txt).
    }
  }
  return _dansDossierApplication(nomFichier, octets);
}

Future<String> _dansDossierApplication(
  String nomFichier,
  Uint8List octets,
) async {
  Directory? base;
  try {
    base = await getExternalStorageDirectory();
  } catch (_) {}
  base ??= await getApplicationDocumentsDirectory();
  final dossier = Directory(p.join(base.path, 'exports'));
  await dossier.create(recursive: true);
  final fichier = File(p.join(dossier.path, nomFichier));
  await fichier.writeAsBytes(octets, flush: true);
  return fichier.path;
}

/// Date/heure lisible pour nommer un fichier (ex : 20261009_1530).
String horodatageFichier() {
  final n = DateTime.now();
  String d(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${d(n.month)}${d(n.day)}_${d(n.hour)}${d(n.minute)}';
}
