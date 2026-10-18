import 'dart:convert';
import 'dart:typed_data';

import 'enregistrer_fichier.dart';

export 'enregistrer_fichier.dart' show EnregistrementAnnule;

/// Exporte des données en fichier .csv (compatible Excel — s'ouvre
/// directement avec double-clic). Les photos ne sont PAS incluses dans
/// l'export (seuls les champs texte/numériques le sont).
///
/// Utilise le POINT-VIRGULE comme séparateur (et non la virgule) : Excel
/// en version française/malgache utilise la virgule comme séparateur
/// décimal, donc un CSV séparé par virgules fait "coller" toutes les
/// colonnes ensemble à l'ouverture. Le point-virgule est le standard
/// attendu par Excel dans ces régions.
///
/// Ouvre « Enregistrer sous » et retourne l'emplacement choisi par l'utilisateur
/// (lève EnregistrementAnnule s'il annule).
Future<String> exporterEnCsv({
  required String nomFichier,
  required List<String> entetes,
  required List<List<String>> lignes,
}) async {
  const separateur = ';';

  String echapper(String valeur) {
    if (valeur.contains(separateur) ||
        valeur.contains('"') ||
        valeur.contains('\n')) {
      return '"${valeur.replaceAll('"', '""')}"';
    }
    return valeur;
  }

  final buffer = StringBuffer();
  buffer.writeln(entetes.map(echapper).join(separateur));
  for (final ligne in lignes) {
    buffer.writeln(ligne.map(echapper).join(separateur));
  }

  // BOM UTF-8 pour qu'Excel affiche correctement les accents français
  final octets = Uint8List.fromList(utf8.encode('\uFEFF${buffer.toString()}'));

  // L'utilisateur choisit lui-même l'emplacement du fichier.
  return enregistrerFichier(
    nomFichier: '${nomFichier}_${horodatageFichier()}.csv',
    octets: octets,
  );
}
