import '../data/liste_etablissement.dart';
import '../data/ecole_origine_cepe.dart';
import '../data/ecole_origine_bepc.dart';
import '../data/ceg_acceuil.dart';
import '../data/lycee_demande_bepc.dart';
import '../data/centre_ecrit_cepe.dart';
import '../data/centre_correction_cepe.dart';
import '../data/centre_ecrit_bepc.dart';
import '../data/centre_correction_bepc.dart';
import '../data/groupes_cepe.dart';
import '../data/groupes_bepc.dart';
import '../data/liste_reference.dart';

import '../models/item_liste.dart';
import 'sqlite_service.dart';

/// Charge les listes réelles (extraites du fichier stageCisco.xlsx) dans la
/// table générique item_liste, UNE SEULE FOIS (au tout premier lancement de
/// l'app). Ensuite, l'utilisateur peut ajouter/modifier/supprimer via les
/// écrans de gestion de liste — ces modifications restent en base et ne
/// sont pas écrasées par un ré-appel de cette fonction.
class SeedService {
  /// Chaque liste à semer : son typeListe + la fonction qui construit les
  /// champs de chaque entrée à partir d'une ligne brute.
  static Future<void> semerSiVide() async {
    await _semer(
      'etablissement',
      listeEtablissements,
      (r) => {
        'code': '${r['codeEtab']}',
        'nom': '${r['nomEtab']}',
        'secteur': '${r['codeSecteur']}',
      },
    );

    await _semer(
      'ecoleOrigineCepe',
      ecoleOrigineCepe,
      (r) => {
        'code': '${r['codeEcoleOrigine']}',
        'nom': '${r['ecoleOrigine']}',
        'secteur': '${r['secteur']}',
      },
    );

    await _semer(
      'ecoleOrigineBepc',
      ecoleOrigineBepc,
      (r) => {
        'code': '${r['codeEtab']}',
        'nom': '${r['etab']}',
        'secteur': '${r['secteur']}',
      },
    );

    await _semer(
      'cegAccueil',
      cegAccueil,
      (r) => {
        'code': '${r['codeCegAccueil']}',
        'libelle': '${r['libelleCegAccueil']}',
      },
    );

    await _semer(
      'lyceeAccueil',
      lyceeDemandeBepc,
      (r) => {'code': '${r['codeEcole']}', 'libelle': '${r['ecoleDemande']}'},
    );

    await _semer(
      'centreEcritCepe',
      centreEcritCepe,
      (r) => {
        'code': '${r['codeCentre']}',
        'libelle': '${r['libelle']}',
        'codecorrection': '${r['codecorrection']}',
      },
    );

    await _semer(
      'centreCorrectionCepe',
      centreCorrectionCepe,
      (r) => {'code': '${r['codecorrection']}', 'libelle': '${r['libelle']}'},
    );

    await _semer(
      'centreEcritBepc',
      centreEcritBepc,
      (r) => {
        'code': '${r['codeCentre']}',
        'libelle': '${r['libelle']}',
        'codecorrection': '${r['codecorrection']}',
      },
    );

    await _semer(
      'centreCorrectionBepc',
      centreCorrectionBepc,
      (r) => {'code': '${r['codecorrection']}', 'libelle': '${r['libelle']}'},
    );

    await _semer(
      'groupeCepe',
      groupesCepe,
      (r) => {'code': '${r['option']}', 'libelle': '${r['libelle']}'},
    );

    await _semer(
      'groupeBepc',
      groupesBepc,
      (r) => {'code': '${r['groupe']}', 'libelle': '${r['libelle']}'},
    );

    await _semer(
      'langue',
      langues.map((l) => {'libelle': l}).toList(),
      (r) => {'libelle': '${r['libelle']}'},
    );

    await _semer(
      'typeHandicap',
      typesHandicap.map((l) => {'libelle': l}).toList(),
      (r) => {'libelle': '${r['libelle']}'},
    );

    await _semer(
      'sportCollectif',
      sportsCollectifsComplet.map((l) => {'libelle': l}).toList(),
      (r) => {'libelle': '${r['libelle']}'},
    );

    await _semer(
      'sportIndividuel',
      sportsIndividuelsComplet.map((l) => {'libelle': l}).toList(),
      (r) => {'libelle': '${r['libelle']}'},
    );
  }

  static Future<void> _semer(
    String typeListe,
    List<Map<String, dynamic>> lignesBrutes,
    Map<String, String> Function(Map<String, dynamic> ligne) construireChamps,
  ) async {
    final existants = await SqliteService.instance.listerItems(typeListe);
    if (existants.isNotEmpty) return; // déjà semé, on ne touche à rien

    int i = 0;
    for (final ligne in lignesBrutes) {
      final item = ItemListe(
        id: '${typeListe}_$i',
        typeListe: typeListe,
        champs: construireChamps(ligne),
      );
      await SqliteService.instance.insererItemListe(item);
      i++;
    }
  }
}
