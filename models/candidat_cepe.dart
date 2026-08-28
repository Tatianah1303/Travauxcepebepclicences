/// Modèle représentant un candidat au CEPE.
///
/// Règles métier à respecter dans le formulaire (voir sqlite_service et
/// formulaire) :
/// - groupe ∈ {A, B, C}
/// - ecoleOrigine (établissement dont vient le candidat) : toujours renseigné
/// - Si groupe = A ou B → cegAccueil (liste 'cegAceuil') est ACTIF
/// - Si groupe = C       → cegAccueil est VERROUILLÉ (candidat libre)
/// - Si groupe = A       → langue est ACTIVE, sinon verrouillée
/// - Si handicap = true  → sportCollectif et sportIndividuel VERROUILLÉS
/// - nomPere est le SEUL champ facultatif, tout le reste est obligatoire
/// (nomMere, contrairement à nomPere, est obligatoire)
class CandidatCepe {
  final String codeCandidat;
  final int numero;
  final String nom;
  final String prenom;
  final String lieuNaissance;
  final String adresseActuelle;
  final DateTime dateNaissance;

  /// 'G' = Garçon (Masculin), 'F' = Fille (Féminin)
  final String sexe;

  /// true si le candidat est en situation de handicap
  final bool handicap;

  /// Uniquement rempli si handicap = true.
  /// Valeurs possibles : 'visuelle', 'auditive', 'motrice', 'intellectuelle'
  final String? typeHandicap;

  /// Facultatif — seul champ non obligatoire du formulaire
  final String? nomPere;

  /// Obligatoire (contrairement à nomPere)
  final String nomMere;

  /// 'A', 'B' ou 'C'
  final String groupe;

  /// Rempli uniquement si groupe = A. Sinon null.
  final String? langue;

  /// Code de l'école d'origine (liste ecoleOrigineCepe) : d'où vient le
  /// candidat. Toujours renseigné, indépendant du groupe.
  final String codeEcoleOrigine;

  /// Code du CEG d'accueil (liste 'cegAceuil'), propre au CEPE.
  /// Actif seulement si groupe = A ou B. Null si groupe = C (candidat libre).
  final String? codeCegAccueil;

  final String codeEtab;

  /// Saisi manuellement par l'établissement (pas une liste fixe)
  final String? codeCentreEcrit;
  final String? numeroSalle;

  // --- EPS (facultatif globalement, mais si activé, règles ci-dessous) ---
  final bool eps;

  /// Rempli automatiquement selon le sexe si eps = true :
  /// '600m' si sexe = Féminin, '800m' si sexe = Masculin
  final String? epreuveObligatoire;

  /// Un seul choix parmi : 'course_vitesse', 'javelot', 'poids'
  /// (retenu uniquement si eps = true)
  final String? epreuveAuChoix;

  /// Un seul choix parmi : 'basket', 'foot'
  final String? epreuveCollective;

  final String photo;
  final String etatCandidat;
  final int anneeSession;

  const CandidatCepe({
    required this.codeCandidat,
    required this.numero,
    required this.nom,
    required this.prenom,
    required this.lieuNaissance,
    required this.adresseActuelle,
    required this.dateNaissance,
    required this.sexe,
    required this.handicap,
    this.typeHandicap,
    this.nomPere,
    required this.nomMere,
    required this.groupe,
    this.langue,
    required this.codeEcoleOrigine,
    this.codeCegAccueil,
    required this.codeEtab,
    this.codeCentreEcrit,
    this.numeroSalle,
    this.eps = false,
    this.epreuveObligatoire,
    this.epreuveAuChoix,
    this.epreuveCollective,
    required this.photo,
    required this.etatCandidat,
    required this.anneeSession,
  });

  Map<String, Object?> toMap() {
    return {
      'codeCandidat': codeCandidat,
      'numero': numero,
      'nom': nom,
      'prenom': prenom,
      'lieuNaissance': lieuNaissance,
      'adresseActuelle': adresseActuelle,
      'dateNaissance': dateNaissance.toIso8601String(),
      'sexe': sexe,
      'handicap': handicap ? 1 : 0,
      'typeHandicap': typeHandicap,
      'nomPere': nomPere,
      'nomMere': nomMere,
      'groupe': groupe,
      'langue': langue,
      'codeEcoleOrigine': codeEcoleOrigine,
      'codeCegAccueil': codeCegAccueil,
      'codeEtab': codeEtab,
      'codeCentreEcrit': codeCentreEcrit,
      'numeroSalle': numeroSalle,
      'eps': eps ? 1 : 0,
      'epreuveObligatoire': epreuveObligatoire,
      'epreuveAuChoix': epreuveAuChoix,
      'epreuveCollective': epreuveCollective,
      'photo': photo,
      'etatCandidat': etatCandidat,
      'anneeSession': anneeSession,
    };
  }

  factory CandidatCepe.fromMap(Map<String, Object?> map) {
    return CandidatCepe(
      codeCandidat: map['codeCandidat'] as String,
      numero: map['numero'] as int,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      lieuNaissance: map['lieuNaissance'] as String,
      adresseActuelle: map['adresseActuelle'] as String,
      dateNaissance: DateTime.parse(map['dateNaissance'] as String),
      sexe: map['sexe'] as String,
      handicap: (map['handicap'] as int) == 1,
      typeHandicap: map['typeHandicap'] as String?,
      nomPere: map['nomPere'] as String?,
      nomMere: map['nomMere'] as String,
      groupe: map['groupe'] as String,
      langue: map['langue'] as String?,
      codeEcoleOrigine: map['codeEcoleOrigine'] as String,
      codeCegAccueil: map['codeCegAccueil'] as String?,
      codeEtab: map['codeEtab'] as String,
      codeCentreEcrit: map['codeCentreEcrit'] as String?,
      numeroSalle: map['numeroSalle'] as String?,
      eps: (map['eps'] as int) == 1,
      epreuveObligatoire: map['epreuveObligatoire'] as String?,
      epreuveAuChoix: map['epreuveAuChoix'] as String?,
      epreuveCollective: map['epreuveCollective'] as String?,
      photo: map['photo'] as String,
      etatCandidat: map['etatCandidat'] as String,
      anneeSession: map['anneeSession'] as int,
    );
  }
}
