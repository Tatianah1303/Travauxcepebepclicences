import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/local_chat_service.dart';

/// Écran de discussion, réutilisé côté établissement et côté admin.
///
/// [codeEtab] : la conversation concernée.
/// [expediteurActuel] : 'etablissement' si c'est l'établissement qui
/// consulte l'écran, 'admin' si c'est l'Administration CISCO — détermine
/// de quel côté les bulles de messages s'affichent.
/// [titre] : ce qui s'affiche dans l'AppBar (nom de l'établissement pour
/// l'admin, ou simplement "Administration CISCO" pour l'établissement).
class ChatThreadScreen extends StatefulWidget {
  final String codeEtab;
  final String expediteurActuel;
  final String titre;

  const ChatThreadScreen({
    super.key,
    required this.codeEtab,
    required this.expediteurActuel,
    required this.titre,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Future<void> _envoyer() async {
    final texte = _controller.text.trim();
    if (texte.isEmpty) return;
    _controller.clear();

    await LocalChatService.envoyerMessage(
      codeEtab: widget.codeEtab,
      expediteur: widget.expediteurActuel,
      texte: texte,
    );

    // Descend en bas après l'envoi
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: LocalChatService.ecouterMessages(widget.codeEtab),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur : ${snapshot.error}'));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Aucun message pour le moment'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final m = messages[i];
                    final estMoi = m.expediteur == widget.expediteurActuel;
                    return Align(
                      alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: estMoi ? Colors.blue.shade600 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.texte,
                              style: TextStyle(color: estMoi ? Colors.white : Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${m.horodatage.hour.toString().padLeft(2, '0')}:${m.horodatage.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: estMoi ? Colors.white70 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _envoyer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _envoyer,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}