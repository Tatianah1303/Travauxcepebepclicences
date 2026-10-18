/// Modèle représentant un membre prévisionnel : un enseignant désigné pour
/// une session d'examen, avec un rôle précis.
///
/// Rappel des règles métier validées :
/// - Un membre prévisionnel est TOUJOURS un enseignant (matricule requis).
/// - Il n'occupe qu'UN SEUL rôle à la fois pour la session
///   (role ∈ {Jury, Correcteur, ChefDeCentre, Securite}).
/// - Les photos CIN recto/verso sont prises seulement au moment où
///   l'enseignant s'identifie comme membre (pas avant, pas sur Enseignant).
/// - etat suit le cycle : Désigné → Identifié → En activité → Présent / Absent
/// - anneeSession permet de distinguer les sessions d'une année à l'autre
///   (et de les archiver/supprimer indépendamment, cf. diagramme d'archivage)
class MembrePrevisionnel {
  final String codeMembre;

  /// Matricule de l'enseignant désigné (lien vers Enseignant)
  final String matriculeEnseignant;

  /// 'Jury', 'Correcteur', 'ChefDeCentre' ou 'Securite'
  final String role;

  /// 'Désigné', 'Identifié', 'En activité', 'Présent' ou 'Absent'
  final String etat;

  /// État affiché à l'utilisateur : « En poste » (ancien libellé) devient
  /// « En activité ».
  String get etatAffiche => etat == 'En poste' ? 'En activité' : etat;

  /// Renseignées seulement au moment de l'identification (vérification
  /// d'identité), pas avant.
  final String? photoCinRecto;
  final String? photoCinVerso;

  /// Centre auquel le membre est rattaché :
  /// - codeCentreEcrit si role ∈ {Jury, ChefDeCentre, Securite}
  /// - codeCentreCorrection si role = Correcteur
  final String? codeCentreEcrit;
  final String? codeCentreCorrection;

  final int anneeSession;

  /// 'CEPE' ou 'BEPC' — indispensable pour bien séparer les membres des
  /// deux examens, même au sein d'un même établissement (avant même
  /// l'attribution à un centre, on doit déjà savoir pour quel examen ce
  /// membre est désigné).
  final String typeExamen;

  /// Établissement qui a saisi ce membre (lu depuis Firestore ; absent des
  /// anciennes données locales).
  final String? codeEtab;

  /// Identité de l'enseignant COPIÉE au moment de la désignation : le nom
  /// reste affichable même si la fiche enseignant est modifiée ou supprimée.
  final String? nom;
  final String? prenom;
  final String? localite;

  const MembrePrevisionnel({
    required this.codeMembre,
    required this.matriculeEnseignant,
    required this.role,
    required this.etat,
    this.photoCinRecto,
    this.photoCinVerso,
    this.codeCentreEcrit,
    this.codeCentreCorrection,
    required this.anneeSession,
    required this.typeExamen,
    this.codeEtab,
    this.nom,
    this.prenom,
    this.localite,
  });

  Map<String, Object?> toMap() {
    return {
      'codeMembre': codeMembre,
      'matriculeEnseignant': matriculeEnseignant,
      'role': role,
      'etat': etat,
      'photoCinRecto': photoCinRecto,
      'photoCinVerso': photoCinVerso,
      'codeCentreEcrit': codeCentreEcrit,
      'codeCentreCorrection': codeCentreCorrection,
      'anneeSession': anneeSession,
      'typeExamen': typeExamen,
      if (nom != null) 'nom': nom,
      if (prenom != null) 'prenom': prenom,
      if (localite != null) 'localite': localite,
    };
  }

  factory MembrePrevisionnel.fromMap(Map<String, Object?> map) {
    return MembrePrevisionnel(
      codeMembre: map['codeMembre'] as String,
      matriculeEnseignant: map['matriculeEnseignant'] as String,
      role: map['role'] as String,
      etat: map['etat'] as String,
      photoCinRecto: map['photoCinRecto'] as String?,
      photoCinVerso: map['photoCinVerso'] as String?,
      codeCentreEcrit: map['codeCentreEcrit'] as String?,
      codeCentreCorrection: map['codeCentreCorrection'] as String?,
      anneeSession: map['anneeSession'] as int,
      // Anciennes lignes créées avant l'ajout du champ : on suppose CEPE
      // par défaut (valeur la plus fréquente), à corriger manuellement si
      // besoin.
      typeExamen: (map['typeExamen'] as String?) ?? 'CEPE',
      codeEtab: map['codeEtab'] as String?,
      nom: map['nom'] as String?,
      prenom: map['prenom'] as String?,
      localite: map['localite'] as String?,
    );
  }

  /// Copie l'objet en changeant seulement certains champs — pratique pour
  /// faire évoluer l'état (ex: Désigné → Identifié) sans tout réécrire.
  MembrePrevisionnel copyWith({
    String? role,
    String? etat,
    String? photoCinRecto,
    String? photoCinVerso,
    String? codeCentreEcrit,
    String? codeCentreCorrection,
  }) {
    return MembrePrevisionnel(
      codeMembre: codeMembre,
      matriculeEnseignant: matriculeEnseignant,
      role: role ?? this.role,
      etat: etat ?? this.etat,
      photoCinRecto: photoCinRecto ?? this.photoCinRecto,
      photoCinVerso: photoCinVerso ?? this.photoCinVerso,
      codeCentreEcrit: codeCentreEcrit ?? this.codeCentreEcrit,
      codeCentreCorrection: codeCentreCorrection ?? this.codeCentreCorrection,
      anneeSession: anneeSession,
      typeExamen: typeExamen,
      codeEtab: codeEtab,
      nom: nom,
      prenom: prenom,
      localite: localite,
    );
  }
}
