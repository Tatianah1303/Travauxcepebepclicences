import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'sqlite_service.dart';
import '../utils/csv_export.dart';
import '../models/quota_membre.dart';

/// Archivage et clôture de session (déclenché uniquement par
/// l'Administration CISCO — voir diagramme de séquence "Archivage").
///
/// Étapes : 1) exporte candidats CEPE, candidats BEPC et membres
/// prévisionnels de l'année en .csv, 2) compresse le tout en un seul
/// .zip, 3) supprime les données de cette année de la base (les tables
/// redeviennent prêtes pour la session suivante).
///
/// ⚠️ Action irréversible localement — le .zip est la seule copie
/// restante des données de cette session après exécution.
class ArchiveService {
  static Future<String> archiverEtCloturerSession(int anneeSession) async {
    final cepe = await SqliteService.instance.listerCandidatsCepe(
      anneeSession: anneeSession,
    );
    final bepc = await SqliteService.instance.listerCandidatsBepc(
      anneeSession: anneeSession,
    );
    final membres = await SqliteService.instance.listerMembres(
      anneeSession: anneeSession,
    );
    final enseignants = await SqliteService.instance.listerTousEnseignants();
    final etablissements = await SqliteService.instance.listerItems(
      'etablissement',
    );

    final nomsEtab = {
      for (final e in etablissements)
        (e.champs['code'] ?? ''): (e.champs['nom'] ?? ''),
    };
    final parMatricule = {for (final e in enseignants) e.matricule: e};

    final cheminCepe = await exporterEnCsv(
      nomFichier: 'archive_${anneeSession}_candidats_cepe',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'Langue',
        'État',
      ],
      lignes: cepe
          .map(
            (c) => [
              nomsEtab[c.codeEtab] ?? c.codeEtab,
              c.nom,
              c.prenom,
              c.sexe,
              c.groupe,
              c.langue ?? '-',
              c.etatCandidat,
            ],
          )
          .toList(),
    );

    final cheminBepc = await exporterEnCsv(
      nomFichier: 'archive_${anneeSession}_candidats_bepc',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'Langue',
        'Née vert',
        'État',
      ],
      lignes: bepc
          .map(
            (c) => [
              nomsEtab[c.codeEtab] ?? c.codeEtab,
              c.nom,
              c.prenom,
              c.sexe,
              c.groupe,
              c.langue ?? '-',
              '${c.neeVert}',
              c.etatCandidat,
            ],
          )
          .toList(),
    );

    final cheminMembres = await exporterEnCsv(
      nomFichier: 'archive_${anneeSession}_membres',
      entetes: const [
        'Établissement',
        'Nom',
        'Prénom',
        'Fonction',
        'Rôle',
        'État',
      ],
      lignes: membres.map((m) {
        final e = parMatricule[m.matriculeEnseignant];
        return [
          e != null ? (nomsEtab[e.codeEtab] ?? e.codeEtab) : '-',
          e?.nom ?? '-',
          e?.prenom ?? '-',
          e?.fonction ?? '-',
          libelleRole(m.role),
          m.etat,
        ];
      }).toList(),
    );

    // Compression en .zip
    final archive = Archive();
    for (final chemin in [cheminCepe, cheminBepc, cheminMembres]) {
      final fichier = File(chemin);
      final octets = await fichier.readAsBytes();
      final nom = chemin.split(Platform.pathSeparator).last;
      archive.addFile(ArchiveFile(nom, octets.length, octets));
    }

    final octetsZip = ZipEncoder().encode(archive);
    final dossier = await getApplicationDocumentsDirectory();
    final cheminZip = '${dossier.path}/session_${anneeSession}_archive.zip';
    await File(cheminZip).writeAsBytes(octetsZip!);

    // Nettoyage des .csv temporaires (déjà dans le zip)
    for (final chemin in [cheminCepe, cheminBepc, cheminMembres]) {
      final f = File(chemin);
      if (await f.exists()) await f.delete();
    }

    // Réinitialisation : les 3 tables redeviennent vides pour l'année suivante
    await SqliteService.instance.supprimerSession(anneeSession);

    return cheminZip;
  }
}
