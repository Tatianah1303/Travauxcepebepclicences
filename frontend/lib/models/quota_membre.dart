/// Quota fixé par l'établissement : combien de membres prévisionnels il
/// prévoit de fournir pour chaque rôle, pour une session donnée.
///
/// Exemple : Jury = 5, Correcteur = 2, ChefDeCentre = 1, Securite = 1.
/// La désignation individuelle des enseignants se fait ensuite jusqu'à
/// atteindre ce nombre pour chaque rôle (voir DesignationMembreScreen).
class QuotaMembre {
  final String codeEtab;
  final int anneeSession;

  /// 'CEPE' ou 'BEPC' — un même établissement a des quotas différents et
  /// séparés pour chaque examen.
  final String typeExamen;

  /// 'Jury', 'Correcteur', 'ChefDeCentre' ou 'Securite'
  final String role;

  final int quantite;

  const QuotaMembre({
    required this.codeEtab,
    required this.anneeSession,
    required this.typeExamen,
    required this.role,
    required this.quantite,
  });

  /// Identifiant unique : un seul quota par établissement + année + examen + rôle
  String get id => '${codeEtab}_${anneeSession}_${typeExamen}_$role';

  Map<String, Object?> toMap() => {
    'id': id,
    'codeEtab': codeEtab,
    'anneeSession': anneeSession,
    'typeExamen': typeExamen,
    'role': role,
    'quantite': quantite,
  };

  factory QuotaMembre.fromMap(Map<String, Object?> map) => QuotaMembre(
    codeEtab: map['codeEtab'] as String,
    anneeSession: map['anneeSession'] as int,
    typeExamen: (map['typeExamen'] as String?) ?? 'CEPE',
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
  'ChefDeCentreAdjoint',
  'AssistantTechniqueInformatique',
  'AgentSecretariat',
  'ComiteVigilance',
  'Secretaire',
  'ResponsableSecuriteSujets',
  'SurveillantSalle',
  'SurveillantCour',
  'AgentStade',
  'Medecin',
  'Interrogateur',
  'Surveillant',
];

/// Libellé lisible pour chaque rôle (affichage utilisateur).
String libelleRole(String role) {
  switch (role) {
    case 'Jury':
      return 'Jury';
    case 'Correcteur':
      return 'Correcteur';
    case 'ChefDeCentreAdjoint':
      return 'Chef de centre adjoint';
    case 'AssistantTechniqueInformatique':
      return 'Assistant technique en informatique';
    case 'AgentSecretariat':
      return 'Agent de secrétariat';
    case 'ComiteVigilance':
      return 'Comité de vigilance';
    case 'Secretaire':
      return 'Secrétaire';
    case 'ResponsableSecuriteSujets':
      return 'Responsable de sécurité des sujets';
    case 'SurveillantSalle':
      return 'Surveillant de salle';
    case 'SurveillantCour':
      return 'Surveillant de cour';
    case 'AgentStade':
      return 'Agent de stade';
    case 'Medecin':
      return 'Médecin';
    case 'Interrogateur':
      return 'Interrogateur';
    case 'Surveillant':
      return 'Surveillant';
    case 'ChefDeCentre':
      return 'Chef de centre';
    case 'Securite':
      return 'Sécurité';
    default:
      return role;
  }
}
