import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Exporte des données en fichier .csv (compatible Excel — s'ouvre
/// directement avec double-clic). Les photos ne sont PAS incluses dans
/// l'export (seuls les champs texte/numériques le sont).
///
/// Retourne le chemin complet du fichier créé.
Future<String> exporterEnCsv({
  required String nomFichier,
  required List<String> entetes,
  required List<List<String>> lignes,
}) async {
  String echapper(String valeur) {
    if (valeur.contains(',') || valeur.contains('"') || valeur.contains('\n')) {
      return '"${valeur.replaceAll('"', '""')}"';
    }
    return valeur;
  }

  final buffer = StringBuffer();
  buffer.writeln(entetes.map(echapper).join(','));
  for (final ligne in lignes) {
    buffer.writeln(ligne.map(echapper).join(','));
  }

  final dossier = await getApplicationDocumentsDirectory();
  final horodatage = DateTime.now().millisecondsSinceEpoch;
  final fichier = File('${dossier.path}/${nomFichier}_$horodatage.csv');

  // BOM UTF-8 pour qu'Excel affiche correctement les accents français
  await fichier.writeAsString('\uFEFF${buffer.toString()}', encoding: SystemEncoding());

  return fichier.path;
}