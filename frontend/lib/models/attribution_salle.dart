/// Une salle de centre d'écrit est PARTAGÉE entre plusieurs établissements
/// (les candidats de plusieurs écoles peuvent composer dans la même salle).
///
/// Ce modèle représente combien de places un établissement donné réserve
/// dans une salle donnée. La somme de toutes les attributions d'une salle
/// ne doit jamais dépasser sa capacité — voir [Salle.capacite].
class AttributionSalle {
  final String id;
  final String codeSalle;
  final String codeEtab;
  final int nombreCandidats;

  const AttributionSalle({
    required this.id,
    required this.codeSalle,
    required this.codeEtab,
    required this.nombreCandidats,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'codeSalle': codeSalle,
    'codeEtab': codeEtab,
    'nombreCandidats': nombreCandidats,
  };

  factory AttributionSalle.fromMap(Map<String, Object?> map) =>
      AttributionSalle(
        id: map['id'] as String,
        codeSalle: map['codeSalle'] as String,
        codeEtab: map['codeEtab'] as String,
        nombreCandidats: map['nombreCandidats'] as int,
      );
}
