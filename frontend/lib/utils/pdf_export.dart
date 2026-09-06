import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

/// Exporte des données en fichier .pdf, sous forme de tableau simple.
/// Alternative à l'export Excel (.csv) — utile si Excel pose problème
/// d'affichage sur certains postes. Les photos ne sont pas incluses.
///
/// Retourne le chemin complet du fichier créé.
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

  final dossier = await getApplicationDocumentsDirectory();
  final horodatage = DateTime.now().millisecondsSinceEpoch;
  final nomFichierSur = titre.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final fichier = File('${dossier.path}/${nomFichierSur}_$horodatage.pdf');
  await fichier.writeAsBytes(await document.save());

  return fichier.path;
}
