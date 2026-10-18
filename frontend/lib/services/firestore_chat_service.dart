import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

/// Service de conversation partagé entre l'administration et les établissements.
class FirestoreChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<List<ChatMessage>> ecouterMessages(String codeEtab) => _db
      .collection('chat_messages')
      .where('codeEtab', isEqualTo: codeEtab)
      .snapshots()
      .map(
        (s) =>
            (s.docs.toList()..sort(
                  (a, b) => (a.data()['horodatage'] as Timestamp).compareTo(
                    b.data()['horodatage'] as Timestamp,
                  ),
                ))
                .map((d) {
                  final data = d.data();
                  data['id'] = d.id;
                  return ChatMessage.fromMap(
                    data.map((k, v) => MapEntry(k, v as Object?)),
                  );
                })
                .toList(),
      );

  static Future<void> envoyerMessage({
    required String codeEtab,
    required String expediteur,
    required String texte,
    String? photoPath,
  }) async {
    final id = '${codeEtab}_${DateTime.now().microsecondsSinceEpoch}';
    final stamp = Timestamp.now();
    await _db.collection('chat_messages').doc(id).set({
      'codeEtab': codeEtab,
      'expediteur': expediteur,
      'texte': texte,
      'horodatage': stamp,
      'lu': false,
      'photoPath': photoPath,
      'modifie': false,
    });
    await _db.collection('chat_conversations').doc(codeEtab).set({
      'codeEtab': codeEtab,
      'dernierMessage': texte.isEmpty ? 'Photo' : texte,
      'dernierExpediteur': expediteur,
      'horodatage': stamp,
    }, SetOptions(merge: true));
  }

  static Future<void> modifierMessage(
    String codeEtab,
    String id,
    String texte,
  ) async {
    await _db.collection('chat_messages').doc(id).update({
      'texte': texte,
      'modifie': true,
    });
    await _majResume(codeEtab);
  }

  static Future<void> supprimerMessage(String codeEtab, String id) async {
    await _db.collection('chat_messages').doc(id).delete();
    await _majResume(codeEtab);
  }

  static Future<void> _majResume(String codeEtab) async {
    final q = await _db
        .collection('chat_messages')
        .where('codeEtab', isEqualTo: codeEtab)
        .get();
    if (q.docs.isEmpty) {
      await _db.collection('chat_conversations').doc(codeEtab).delete();
    } else {
      final docs = q.docs.toList()
        ..sort(
          (a, b) => (b.data()['horodatage'] as Timestamp).compareTo(
            a.data()['horodatage'] as Timestamp,
          ),
        );
      final m = docs.first.data();
      await _db.collection('chat_conversations').doc(codeEtab).set({
        'codeEtab': codeEtab,
        'dernierMessage': (m['texte'] as String).isEmpty ? 'Photo' : m['texte'],
        'dernierExpediteur': m['expediteur'],
        'horodatage': m['horodatage'],
      }, SetOptions(merge: true));
    }
  }

  static Future<void> marquerLus(String codeEtab, {required String moi}) async {
    final q = await _db
        .collection('chat_messages')
        .where('codeEtab', isEqualTo: codeEtab)
        .get();
    final batch = _db.batch();
    for (final d in q.docs) {
      if (d.data()['expediteur'] != moi && d.data()['lu'] != true)
        batch.update(d.reference, {'lu': true});
    }
    if (q.docs.isNotEmpty) await batch.commit();
  }

  static Future<int> compterNonLus(
    String codeEtab, {
    required String moi,
  }) async {
    final q = await _db
        .collection('chat_messages')
        .where('codeEtab', isEqualTo: codeEtab)
        .get();
    return q.docs
        .where((d) => d.data()['expediteur'] != moi && d.data()['lu'] != true)
        .length;
  }

  static Stream<List<Map<String, dynamic>>> ecouterConversations() => _db
      .collection('chat_conversations')
      .orderBy('horodatage', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
}
