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
import 'firestore_listes_service.dart';

/// Listes de référence livrées avec l'application (générées depuis
/// stageCisco.xlsx). Elles servent :
///  - à initialiser Firestore (SeedService) ;
///  - de SECOURS dans les formulaires : si la liste n'a pas encore été
///    initialisée dans Firestore (ou si sa lecture échoue), les menus
///    déroulants ne restent plus vides.
class ListesLocales {
  /// Tous les types de listes, dans l'ordre d'initialisation.
  static const List<String> types = [
    'etablissement',
    'ecoleOrigineCepe',
    'ecoleOrigineBepc',
    'cegAccueil',
    'lyceeAccueil',
    'centreEcritCepe',
    'centreCorrectionCepe',
    'centreEcritBepc',
    'centreCorrectionBepc',
    'groupeCepe',
    'groupeBepc',
    'langue',
    'typeHandicap',
    'sportCollectif',
    'sportIndividuel',
  ];

  static String _t(Object? v) => '${v ?? ''}'.trim();

  static List<ItemListe> items(String typeListe) {
    late final List<Map<String, dynamic>> lignes;
    late final Map<String, String> Function(Map<String, dynamic> r) champs;

    switch (typeListe) {
      case 'etablissement':
        lignes = listeEtablissements;
        champs = (r) => {
          'code': _t(r['codeEtab']),
          'nom': _t(r['nomEtab']),
          'secteur': _t(r['codeSecteur']),
          'zap': _t(r['zap']),
          'centreEcrit': '',
          'centreCorrection': '',
        };
      case 'ecoleOrigineCepe':
        // Relation Excel : l'école dépend du centre d'écrit (centre_examen).
        lignes = ecoleOrigineCepe;
        champs = (r) => {
          'code': _t(r['codeEcoleOrigine']),
          'nom': _t(r['ecoleOrigine']),
          'secteur': _t(r['secteur']),
          'codeCentre': _t(r['centreExamen']),
          'codecorrection': _t(r['centreExamen']),
        };
      case 'ecoleOrigineBepc':
        // Relation Excel : l'école dépend du centre d'écrit (code_centre),
        // lui-même rattaché à un centre de correction.
        lignes = ecoleOrigineBepc;
        champs = (r) => {
          'code': _t(r['etab']),
          'nom': _t(r['etab']),
          'secteur': _t(r['secteur']),
          'codeCentre': _t(r['codeCentre']),
          'codecorrection': _t(r['codecorrection']),
        };
      case 'cegAccueil':
        lignes = cegAccueil;
        champs = (r) => {
          'code': _t(r['codeCegAccueil']),
          'libelle': _t(r['libelleCegAccueil']),
          'codecorrection': _t(r['codecorrection']),
        };
      case 'lyceeAccueil':
        lignes = lyceeDemandeBepc;
        champs = (r) => {
          'code': _t(r['codeEcole']),
          'libelle': _t(r['ecoleDemande']),
        };
      case 'centreEcritCepe':
        lignes = centreEcritCepe;
        champs = (r) => {
          'code': _t(r['codeCentre']),
          'libelle': _t(r['libelle']),
          'codecorrection': _t(r['codecorrection']),
        };
      case 'centreCorrectionCepe':
        lignes = centreCorrectionCepe;
        champs = (r) => {
          'code': _t(r['codecorrection']),
          'libelle': _t(r['libelle']),
        };
      case 'centreEcritBepc':
        lignes = centreEcritBepc;
        champs = (r) => {
          'code': _t(r['codeCentre']),
          'libelle': _t(r['libelle']),
          'codecorrection': _t(r['codecorrection']),
        };
      case 'centreCorrectionBepc':
        lignes = centreCorrectionBepc;
        champs = (r) => {
          'code': _t(r['codecorrection']),
          'libelle': _t(r['libelle']),
        };
      case 'groupeCepe':
        lignes = groupesCepe;
        champs = (r) => {'code': _t(r['option']), 'libelle': _t(r['libelle'])};
      case 'groupeBepc':
        lignes = groupesBepc;
        champs = (r) => {'code': _t(r['groupe']), 'libelle': _t(r['libelle'])};
      case 'langue':
        lignes = langues.map<Map<String, dynamic>>((l) => {'libelle': l}).toList();
        champs = (r) => {'libelle': _t(r['libelle'])};
      case 'typeHandicap':
        lignes = typesHandicap.map<Map<String, dynamic>>((l) => {'libelle': l}).toList();
        champs = (r) => {'libelle': _t(r['libelle'])};
      case 'sportCollectif':
        lignes = sportsCollectifsComplet.map<Map<String, dynamic>>((l) => {'libelle': l}).toList();
        champs = (r) => {'libelle': _t(r['libelle'])};
      case 'sportIndividuel':
        lignes = sportsIndividuelsComplet.map<Map<String, dynamic>>((l) => {'libelle': l}).toList();
        champs = (r) => {'libelle': _t(r['libelle'])};
      default:
        return [];
    }

    return [
      for (var i = 0; i < lignes.length; i++)
        ItemListe(
          id: '${typeListe}_$i',
          typeListe: typeListe,
          champs: champs(lignes[i]),
        ),
    ];
  }

  /// Charge une liste pour les formulaires.
  ///  - Une fois la liste initialisée côté admin, Firestore fait foi : tout
  ///    ajout, modification ou suppression de l'admin est pris en compte.
  ///  - Avant cela, les éléments livrés avec l'application complètent ceux de
  ///    Firestore, pour que les menus ne soient jamais vides.
  static Future<List<ItemListe>> charger(String typeListe) async {
    List<ItemListe> distant;
    try {
      distant = await FirestoreListesService.listerItems(typeListe);
    } catch (_) {
      return items(typeListe);
    }
    final initialises = await FirestoreListesService.typesInitialises();
    if (initialises.contains(typeListe) && distant.isNotEmpty) return distant;
    final ids = distant.map((e) => e.id).toSet();
    return [...distant, ...items(typeListe).where((e) => !ids.contains(e.id))];
  }

  /// Retire les entrées dont le « code » est déjà présent : un menu
  /// déroulant Flutter plante si deux entrées ont la même valeur.
  static List<ItemListe> sansDoublons(List<ItemListe> liste) {
    final vus = <String>{};
    final resultat = <ItemListe>[];
    for (final e in liste) {
      final code = e.champs['code'];
      if (code == null || !vus.add(code)) continue;
      resultat.add(e);
    }
    return resultat;
  }
}
