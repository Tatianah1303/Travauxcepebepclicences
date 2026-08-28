/// Un enseignant appartenant à un établissement. Peut être désigné comme
/// membre prévisionnel (0..1) pour une session donnée.
///
/// [fonction] détermine les rôles accessibles : seul un enseignant avec
/// fonction = 'Directeur' peut être désigné Chef de centre. Les autres
/// fonctions ('Enseignant') peuvent être Jury, Correcteur ou Sécurité.
class Enseignant {
  final String matricule;
  final String nom;
  final String prenom;
  final String phone;
  final String adresse;
  final String codeEtab;

  /// 'Directeur' ou 'Enseignant'
  final String fonction;

  const Enseignant({
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.phone,
    required this.adresse,
    required this.codeEtab,
    required this.fonction,
  });

  String get nomComplet => '$nom $prenom';

  Map<String, Object?> toMap() => {
    'matricule': matricule,
    'nom': nom,
    'prenom': prenom,
    'phone': phone,
    'adresse': adresse,
    'codeEtab': codeEtab,
    'fonction': fonction,
  };

  factory Enseignant.fromMap(Map<String, Object?> map) => Enseignant(
    matricule: map['matricule'] as String,
    nom: map['nom'] as String,
    prenom: map['prenom'] as String,
    phone: map['phone'] as String,
    adresse: map['adresse'] as String,
    codeEtab: map['codeEtab'] as String,
    fonction: map['fonction'] as String,
  );
}
