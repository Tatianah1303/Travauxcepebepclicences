import 'dart:async';

import '../models/chat_message.dart';
import 'sqlite_service.dart';

/// Chat en version LOCALE (SQLite), pour tester toute la fonctionnalité
/// sur Windows sans Firebase ni build APK.
///
/// Même signature de méthodes que la future version Firestore
/// (firebase_chat_service.dart) — le jour où tu veux vraiment déployer,
/// il suffira de changer l'import `LocalChatService` en
/// `FirebaseChatService` dans les écrans de chat, rien d'autre à modifier.
///
/// ⚠️ Limite connue : comme il n'y a pas de vrai serveur, la mise à jour
/// "temps réel" ne se déclenche que lorsque CETTE instance de l'app
/// envoie un message (on ne peut pas recevoir de messages d'un autre
/// appareil en vrai temps réel en local — c'est normal, ça viendra avec
/// Firebase).
class LocalChatService {
  static final Map<String, StreamController<List<ChatMessage>>> _controleurs =
      {};
  static final _controleurConversations =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static Stream<List<ChatMessage>> ecouterMessages(String codeEtab) {
    _controleurs.putIfAbsent(codeEtab, () {
      final controleur = StreamController<List<ChatMessage>>.broadcast();
      _rafraichirMessages(codeEtab, controleur);
      return controleur;
    });
    return _controleurs[codeEtab]!.stream;
  }

  static Future<void> _rafraichirMessages(
    String codeEtab,
    StreamController<List<ChatMessage>> controleur,
  ) async {
    final messages = await SqliteService.instance.listerMessagesChat(codeEtab);
    if (!controleur.isClosed) controleur.add(messages);
  }

  static Future<void> envoyerMessage({
    required String codeEtab,
    required String expediteur,
    required String texte,
  }) async {
    final message = ChatMessage(
      id: '${codeEtab}_${DateTime.now().millisecondsSinceEpoch}',
      expediteur: expediteur,
      texte: texte,
      horodatage: DateTime.now(),
      lu: false,
    );

    await SqliteService.instance.insererMessageChat(message, codeEtab);

    // Notifie les écrans ouverts sur cette conversation
    if (_controleurs.containsKey(codeEtab)) {
      await _rafraichirMessages(codeEtab, _controleurs[codeEtab]!);
    }
    await _rafraichirConversations();
  }

  static Stream<List<Map<String, dynamic>>> ecouterConversations() {
    _rafraichirConversations();
    return _controleurConversations.stream;
  }

  static Future<void> _rafraichirConversations() async {
    final conversations = await SqliteService.instance
        .listerConversationsChat();
    if (!_controleurConversations.isClosed) {
      _controleurConversations.add(conversations);
    }
  }
}
