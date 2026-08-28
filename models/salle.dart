/// Modèle représentant une salle d'examen.
///
/// Règle métier : la salle est saisie manuellement (par centre), ce n'est
/// pas une liste fixe préremplie — chaque centre déclare ses propres salles
/// et leur capacité au moment voulu.
class Salle {
  /// Identifiant unique généré (ex: 'F02/01_1' = centre F02/01, salle n°1)
  final String id;

  /// Code du centre auquel appartient la salle (CEPE ou BEPC)
  final String codeCentre;

  final int numeroSalle;
  final int capacite;

  /// Nombre de places encore libres dans la salle
  final int placesLibres;

  /// 'CEPE' ou 'BEPC' — pour savoir dans quel dashboard elle apparaît
  final String typeExamen;

  final int anneeSession;

  const Salle({
    required this.id,
    required this.codeCentre,
    required this.numeroSalle,
    required this.capacite,
    required this.placesLibres,
    required this.typeExamen,
    required this.anneeSession,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'codeCentre': codeCentre,
      'numeroSalle': numeroSalle,
      'capacite': capacite,
      'placesLibres': placesLibres,
      'typeExamen': typeExamen,
      'anneeSession': anneeSession,
    };
  }

  factory Salle.fromMap(Map<String, Object?> map) {
    return Salle(
      id: map['id'] as String,
      codeCentre: map['codeCentre'] as String,
      numeroSalle: map['numeroSalle'] as int,
      capacite: map['capacite'] as int,
      placesLibres: map['placesLibres'] as int,
      typeExamen: map['typeExamen'] as String,
      anneeSession: map['anneeSession'] as int,
    );
  }

  Salle copyWith({int? capacite, int? placesLibres}) {
    return Salle(
      id: id,
      codeCentre: codeCentre,
      numeroSalle: numeroSalle,
      capacite: capacite ?? this.capacite,
      placesLibres: placesLibres ?? this.placesLibres,
      typeExamen: typeExamen,
      anneeSession: anneeSession,
    );
  }
}
