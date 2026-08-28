/// Listes de référence fixes, communes CEPE et BEPC.
/// Utilisées pour peupler les dropdowns du formulaire.

/// Langues disponibles (actif seulement si groupe = A / I)
const List<String> langues = ['Allemand', 'Anglais', 'Espagnol'];

/// Types de handicap (actif seulement si handicap = true)
const List<String> typesHandicap = [
  'Déficience visuelle',
  'Déficience auditive',
  'Déficience motrice',
  'Déficience intellectuelle',
];

/// Sports collectifs proposés pour l'épreuve EPS collective.
/// Règle métier : seuls basket et foot sont proposés au choix pour l'EPS,
/// même si la table complète des sports collectifs contient plus d'options.
const List<String> sportsCollectifsEps = ['Basket-ball', 'Foot-ball'];

/// Table complète des sports collectifs (référence, ex: pour d'autres usages
/// futurs hors EPS obligatoire).
const List<String> sportsCollectifsComplet = [
  'Basket-ball',
  'Volley-ball',
  'Hand-ball',
  'Foot-ball',
  'Rugby',
];

/// Épreuves individuelles au choix pour l'EPS (sous-ensemble retenu).
const List<String> epreuvesAuChoixEps = [
  'Course de vitesse',
  'Lancer de javelot',
  'Lancer de poids',
];

/// Table complète des sports individuels (référence).
const List<String> sportsIndividuelsComplet = [
  'Course de vitesse',
  'Lancer de poids',
  'Lancer de javelot',
  'Saut en hauteur',
  'Saut en longueur',
  'Triple saut',
  'Gymnastique',
  'Natation',
  'Grimper (corde)',
];

/// Retourne l'épreuve obligatoire EPS selon le sexe.
/// sexe : G = Masculin, F = Féminin
String epreuveObligatoireSelonSexe(String sexe) {
  return sexe == 'F' ? '600m' : '800m';
}
