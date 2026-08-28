/// Modèle représentant un candidat au BEPC.
///
/// Différences avec CandidatCepe :
/// - groupe ∈ {I, II, III} (au lieu de A, B, C)
/// - Le champ d'accueil s'appelle lyceeAccueil (liste 'lyceeDemandeBepc'),
///   pas cegAccueil (qui est propre au CEPE)
/// - Si groupe = III → numeroInscriptionAnneePrecedente devient obligatoire
///   ET codeLyceeAccueil est VERROUILLÉ (candidat libre)
/// - Champ "neeVert" propre au BEPC : 0 = pas de copie, 1 = a une copie
///
/// Règles communes avec le CEPE (mêmes contraintes de formulaire) :
/// - ecoleOrigine (établissement dont vient le candidat) toujours renseigné
/// - Si groupe = I ou II → lyceeAccueil est ACTIF
/// - Si groupe = III     → lyceeAccueil est VERROUILLÉ
/// - Si groupe = I       → langue est ACTIVE, sinon verrouillée
/// - Si handicap = true  → sportCollectif et sportIndividuel VERROUILLÉS
/// - nomPere est le SEUL champ facultatif, tout le reste est obligatoire
/// (nomMere, contrairement à nomPere, est obligatoire)
class CandidatBepc {
  final String codeCandidat;
  final int numero;
  final String nom;
  final String prenom;
  final String lieuNaissance;
  final String adresseActuelle;
  final DateTime dateNaissance;

  /// 'G' = Garçon (Masculin), 'F' = Fille (Féminin)
  final String sexe;

  final bool handicap;

  /// Uniquement rempli si handicap = true.
  /// Valeurs possibles : 'visuelle', 'auditive', 'motrice', 'intellectuelle'
  final String? typeHandicap;

  /// Facultatif — seul champ non obligatoire du formulaire
  final String? nomPere;

  /// Obligatoire (contrairement à nomPere)
  final String nomMere;

  /// 'I', 'II' ou 'III'
  final String groupe;

  /// Rempli uniquement si groupe = I. Sinon null.
  final String? langue;

  /// Uniquement si groupe = III : numéro d'inscription BEPC de l'année
  /// précédente.
  final String? numeroInscriptionAnneePrecedente;

  /// Champ spécifique BEPC : 0 = candidat n'a pas de copie, 1 = en a une
  final int neeVert;

  /// École d'origine du candidat (liste ecoleOrigineBepc). Toujours
  /// renseignée, indépendant du groupe.
  final String codeEcoleOrigine;

  /// Code du lycée d'accueil (liste 'lyceeDemandeBepc'), propre au BEPC.
  /// Actif seulement si groupe = I ou II. Null si groupe = III.
  final String? codeLyceeAccueil;

  final String codeEtab;

  final String? codeCentreEcrit;
  final String? numeroSalle;

  final bool eps;
  final String? epreuveObligatoire;
  final String? epreuveAuChoix;
  final String? epreuveCollective;

  final String photo;
  final String etatCandidat;
  final int anneeSession;

  const CandidatBepc({
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
    this.numeroInscriptionAnneePrecedente,
    required this.neeVert,
    required this.codeEcoleOrigine,
    this.codeLyceeAccueil,
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
      'numeroInscriptionAnneePrecedente': numeroInscriptionAnneePrecedente,
      'neeVert': neeVert,
      'codeEcoleOrigine': codeEcoleOrigine,
      'codeLyceeAccueil': codeLyceeAccueil,
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

  factory CandidatBepc.fromMap(Map<String, Object?> map) {
    return CandidatBepc(
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
      numeroInscriptionAnneePrecedente:
          map['numeroInscriptionAnneePrecedente'] as String?,
      neeVert: map['neeVert'] as int,
      codeEcoleOrigine: map['codeEcoleOrigine'] as String,
      codeLyceeAccueil: map['codeLyceeAccueil'] as String?,
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
