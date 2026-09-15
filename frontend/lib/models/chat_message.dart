/// Un message dans la conversation entre un établissement et
/// l'Administration CISCO.
///
/// Ce modèle est volontairement indépendant de Firestore (pas de
/// Timestamp) pour pouvoir être stocké aussi bien en SQLite local
/// (test sur Windows) qu'en Firestore plus tard (déploiement réel) sans
/// rien changer dans les écrans.
class ChatMessage {
  final String id;

  /// 'etablissement' ou 'admin' — qui a envoyé ce message
  final String expediteur;

  final String texte;
  final DateTime horodatage;
  final bool lu;

  /// Chemin local d'une photo jointe (optionnel).
  final String? photoPath;

  /// true si le message a été modifié après son envoi.
  final bool modifie;

  const ChatMessage({
    required this.id,
    required this.expediteur,
    required this.texte,
    required this.horodatage,
    required this.lu,
    this.photoPath,
    this.modifie = false,
  });

  ChatMessage copyWith({String? texte, bool? lu, bool? modifie}) => ChatMessage(
    id: id,
    expediteur: expediteur,
    texte: texte ?? this.texte,
    horodatage: horodatage,
    lu: lu ?? this.lu,
    photoPath: photoPath,
    modifie: modifie ?? this.modifie,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'expediteur': expediteur,
    'texte': texte,
    'horodatage': horodatage.toIso8601String(),
    'lu': lu ? 1 : 0,
    'photoPath': photoPath,
    'modifie': modifie ? 1 : 0,
  };

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
    id: map['id'] as String,
    expediteur: map['expediteur'] as String,
    texte: map['texte'] as String,
    horodatage: DateTime.parse(map['horodatage'] as String),
    lu: (map['lu'] as int) == 1,
    photoPath: map['photoPath'] as String?,
    modifie: (map['modifie'] as int?) == 1,
  );
}
