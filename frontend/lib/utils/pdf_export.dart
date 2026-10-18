import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'enregistrer_fichier.dart';

export 'enregistrer_fichier.dart' show EnregistrementAnnule;

/// Exporte des données en fichier .pdf, sous forme de tableau simple.
/// Alternative à l'export Excel (.csv) — utile si Excel pose problème
/// d'affichage sur certains postes. Les photos ne sont pas incluses.
///
/// Ouvre « Enregistrer sous » et retourne l'emplacement choisi par l'utilisateur
/// (lève EnregistrementAnnule s'il annule).
Future<String> exporterEnPdf({
  required String titre,
  required List<String> entetes,
  required List<List<String>> lignes,
}) async {
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => [
        pw.Text(
          titre,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: entetes,
          data: lignes,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
      ],
    ),
  );

  final nomFichierSur = titre.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );

  // L'utilisateur choisit lui-même l'emplacement du fichier.
  return enregistrerFichier(
    nomFichier: '${nomFichierSur}_${horodatageFichier()}.pdf',
    octets: await document.save(),
  );
}
