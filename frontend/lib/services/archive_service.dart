import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/quota_membre.dart';
import 'firestore_listes_service.dart';
import 'listes_locales.dart';
import '../utils/enregistrer_fichier.dart';
import 'firestore_service.dart';

/// Archive la session en ZIP à l'emplacement choisi par l'admin (Firebase Storage n'est plus
/// utilisé) puis supprime les données actives de Firestore uniquement après
/// l'écriture réussie et la vérification du fichier. Retourne le chemin du ZIP.
class ArchiveService {
  static String _csv(List<String> entetes, List<List<String>> lignes) {
    const separateur = ';';
    String echapper(String valeur) {
      const guillemet = '"';
      if (valeur.contains(separateur) ||
          valeur.contains(guillemet) ||
          valeur.contains('\n')) {
        return '"${valeur.replaceAll(guillemet, guillemet + guillemet)}"';
      }
      return valeur;
    }

    final b = StringBuffer();
    b.writeln(entetes.map(echapper).join(separateur));
    for (final ligne in lignes) {
      b.writeln(ligne.map(echapper).join(separateur));
    }
    return '\uFEFF${b.toString()}';
  }

  static Future<String> archiverEtCloturerSession(int anneeSession) async {
    final cepe = await FirestoreService.instance.listerTousCandidatsCepe(
      anneeSession: anneeSession,
    );
    final bepc = await FirestoreService.instance.listerTousCandidatsBepc(
      anneeSession: anneeSession,
    );
    final membres = await FirestoreService.instance.listerTousMembres(
      anneeSession: anneeSession,
    );
    final enseignants = await FirestoreService.instance.listerTousEnseignants();
    final etablissements = await ListesLocales.charger('etablissement');
    final nomsEtab = {
      for (final e in etablissements)
        if (e.champs['code'] != null)
          e.champs['code']!: e.champs['nom'] ?? e.champs['code']!,
    };
    final parMatricule = {for (final e in enseignants) e.matricule: e};

    final cepeCsv = _csv(
      const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Option',
        'Langue',
        'État',
      ],
      cepe
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
    final bepcCsv = _csv(
      const [
        'Établissement',
        'Nom',
        'Prénom',
        'Sexe',
        'Groupe',
        'Langue',
        'Née vers',
        'État',
      ],
      bepc
          .map(
            (c) => [
              nomsEtab[c.codeEtab] ?? c.codeEtab,
              c.nom,
              c.prenom,
              c.sexe,
              c.groupe,
              c.langue ?? '-',
              c.neeVert != 0 ? 'Oui' : 'Non',
              c.etatCandidat,
            ],
          )
          .toList(),
    );
    final membresCsv = _csv(
      const ['Établissement', 'Nom', 'Prénom', 'Fonction', 'Rôle', 'État'],
      membres.map((m) {
        final e = parMatricule[m.matriculeEnseignant];
        return [
          e != null ? (nomsEtab[e.codeEtab] ?? e.codeEtab) : '-',
          e?.nom ?? '-',
          e?.prenom ?? '-',
          e?.fonction ?? '-',
          libelleRole(m.role),
          m.etatAffiche,
        ];
      }).toList(),
    );

    final archive = Archive();
    for (final (nom, csv) in [
      ('archive_${anneeSession}_candidats_cepe.csv', cepeCsv),
      ('archive_${anneeSession}_candidats_bepc.csv', bepcCsv),
      ('archive_${anneeSession}_membres.csv', membresCsv),
    ]) {
      final bytes = Uint8List.fromList(utf8.encode(csv));
      archive.addFile(ArchiveFile(nom, bytes.length, bytes));
    }
    final zip = ZipEncoder().encode(archive);
    if (zip == null) throw StateError('Impossible de créer l’archive ZIP.');

    // L'admin choisit lui-même où enregistrer le ZIP. Si la fenêtre est
    // fermée sans choisir, on s'arrête AVANT toute suppression de données.
    final String url;
    try {
      url = await enregistrerFichier(
        nomFichier: 'session_$anneeSession.zip',
        octets: Uint8List.fromList(zip),
      );
    } on EnregistrementAnnule {
      throw const EnregistrementAnnule(
        'Enregistrement annulé : aucune donnée n’a été supprimée.',
      );
    }

    // La suppression ne démarre qu'après la création et la vérification du fichier local.
    await FirestoreService.instance.supprimerSessionFirestore(anneeSession);
    return url;
  }
}
