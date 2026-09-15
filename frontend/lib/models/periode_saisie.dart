/// La période pendant laquelle les établissements ont le droit de saisir
/// des candidats. Définie une seule fois par l'admin (CISCO), visible par
/// tous les établissements (petite cloche de notification), et utilisée
/// pour bloquer la saisie avant la date de début ou après la date de fin.
///
/// Une seule période active à la fois (id fixe 'global').
class PeriodeSaisie {
  static const String idGlobal = 'global';

  final DateTime dateDebut;
  final DateTime dateFin;
  final String description;

  /// Date à laquelle l'admin a défini/modifié cette période — sert à
  /// savoir si un établissement a déjà "vu" cette annonce ou pas.
  final DateTime definiLe;

  const PeriodeSaisie({
    required this.dateDebut,
    required this.dateFin,
    required this.description,
    required this.definiLe,
  });

  Map<String, Object?> toMap() => {
    'id': idGlobal,
    'dateDebut': dateDebut.toIso8601String(),
    'dateFin': dateFin.toIso8601String(),
    'description': description,
    'definiLe': definiLe.toIso8601String(),
  };

  factory PeriodeSaisie.fromMap(Map<String, Object?> map) => PeriodeSaisie(
    dateDebut: DateTime.parse(map['dateDebut'] as String),
    dateFin: DateTime.parse(map['dateFin'] as String),
    description: map['description'] as String,
    definiLe: DateTime.parse(map['definiLe'] as String),
  );

  /// Statut de la saisie À L'INSTANT PRÉSENT par rapport à cette période.
  StatutSaisie get statut {
    final maintenant = DateTime.now();
    if (maintenant.isBefore(dateDebut)) return StatutSaisie.pasEncoreCommence;
    if (maintenant.isAfter(dateFin)) return StatutSaisie.termine;
    return StatutSaisie.enCours;
  }
}

enum StatutSaisie { pasEncoreCommence, enCours, termine }
