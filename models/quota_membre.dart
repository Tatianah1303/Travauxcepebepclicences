/// Quota fixé par l'établissement : combien de membres prévisionnels il
/// prévoit de fournir pour chaque rôle, pour une session donnée.
///
/// Exemple : Jury = 5, Correcteur = 2, ChefDeCentre = 1, Securite = 1.
/// La désignation individuelle des enseignants se fait ensuite jusqu'à
/// atteindre ce nombre pour chaque rôle (voir DesignationMembreScreen).
class QuotaMembre {
  final String codeEtab;
  final int anneeSession;

  /// 'Jury', 'Correcteur', 'ChefDeCentre' ou 'Securite'
  final String role;

  final int quantite;

  const QuotaMembre({
    required this.codeEtab,
    required this.anneeSession,
    required this.role,
    required this.quantite,
  });

  /// Identifiant unique : un seul quota par établissement + année + rôle
  String get id => '${codeEtab}_${anneeSession}_$role';

  Map<String, Object?> toMap() => {
    'id': id,
    'codeEtab': codeEtab,
    'anneeSession': anneeSession,
    'role': role,
    'quantite': quantite,
  };

  factory QuotaMembre.fromMap(Map<String, Object?> map) => QuotaMembre(
    codeEtab: map['codeEtab'] as String,
    anneeSession: map['anneeSession'] as int,
    role: map['role'] as String,
    quantite: map['quantite'] as int,
  );
}

/// Les 4 rôles possibles pour un membre prévisionnel.
const List<String> rolesMembre = [
  'Jury',
  'Correcteur',
  'ChefDeCentre',
  'Securite',
];

/// Libellé lisible pour chaque rôle (affichage utilisateur).
String libelleRole(String role) {
  switch (role) {
    case 'Jury':
      return 'Jury';
    case 'Correcteur':
      return 'Correcteur';
    case 'ChefDeCentre':
      return 'Chef de centre';
    case 'Securite':
      return 'Sécurité';
    default:
      return role;
  }
}
