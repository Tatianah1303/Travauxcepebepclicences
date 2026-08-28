import 'dart:convert';

/// Modèle générique pour un élément d'une liste de référence :
/// établissement, école d'origine, CEG d'accueil, lycée d'accueil, langue,
/// sport collectif, sport individuel...
///
/// Plutôt que de créer une table + un modèle séparé pour chacune de ces
/// listes (qui ont presque toutes la même forme : un code + un libellé, +
/// parfois un secteur), on utilise UNE table générique avec un champ
/// [typeListe] qui indique de quelle liste il s'agit, et [champs] qui
/// contient les données propres à cet élément (stockées en JSON).
///
/// Exemples de [typeListe] : 'etablissement', 'ecoleOrigineCepe',
/// 'ecoleOrigineBepc', 'cegAccueil', 'lyceeAccueil', 'langue',
/// 'sportCollectif', 'sportIndividuel'.
class ItemListe {
  final String id;
  final String typeListe;

  /// Ex : {'code': 'F02/01', 'libelle': 'CEG Mahaditra', 'secteur': 'Public'}
  final Map<String, String> champs;

  const ItemListe({
    required this.id,
    required this.typeListe,
    required this.champs,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'typeListe': typeListe,
      'champs': jsonEncode(champs),
    };
  }

  factory ItemListe.fromMap(Map<String, Object?> map) {
    return ItemListe(
      id: map['id'] as String,
      typeListe: map['typeListe'] as String,
      champs: Map<String, String>.from(
        jsonDecode(map['champs'] as String) as Map,
      ),
    );
  }
}
