import 'dart:io';
import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/local_chat_service.dart';
import '../../utils/photo_helper.dart';

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
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    // On marque la conversation comme lue dès qu'on l'ouvre (fait partie
    // du système de notification : la pastille "non lus" disparaît).
    LocalChatService.marquerLus(widget.codeEtab, moi: widget.expediteurActuel);
  }

  void _descendreEnBas() {
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

  Future<void> _envoyer() async {
    final texte = _controller.text.trim();
    if (texte.isEmpty) return;
    _controller.clear();

    await LocalChatService.envoyerMessage(
      codeEtab: widget.codeEtab,
      expediteur: widget.expediteurActuel,
      texte: texte,
    );
    _descendreEnBas();
  }

  Future<void> _envoyerPhoto() async {
    if (_envoiEnCours) return;
    setState(() => _envoiEnCours = true);
    try {
      final chemin = await prendrePhotoOuChoisirFichier();
      if (chemin == null) return;
      await LocalChatService.envoyerMessage(
        codeEtab: widget.codeEtab,
        expediteur: widget.expediteurActuel,
        texte: '',
        photoPath: chemin,
      );
      _descendreEnBas();
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  Future<void> _modifier(ChatMessage m) async {
    final controleur = TextEditingController(text: m.texte);
    final nouveauTexte = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controleur,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controleur.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (nouveauTexte == null || nouveauTexte.isEmpty) return;
    await LocalChatService.modifierMessage(widget.codeEtab, m.id, nouveauTexte);
  }

  Future<void> _supprimer(ChatMessage m) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await LocalChatService.supprimerMessage(widget.codeEtab, m.id);
  }

  void _ouvrirOptions(ChatMessage m) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.photoPath == null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _modifier(m);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () {
                Navigator.of(ctx).pop();
                _supprimer(m);
              },
            ),
          ],
        ),
      ),
    );
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
                  return const Center(
                    child: Text('Aucun message pour le moment'),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final m = messages[i];
                    final estMoi = m.expediteur == widget.expediteurActuel;

                    final bulle = GestureDetector(
                      onLongPress: estMoi ? () => _ouvrirOptions(m) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.all(m.photoPath != null ? 6 : 0),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.68,
                        ),
                        decoration: BoxDecoration(
                          color: estMoi
                              ? Colors.blue.shade600
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: m.photoPath != null ? 0 : 14,
                            vertical: m.photoPath != null ? 0 : 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.photoPath != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(m.photoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 160,
                                      height: 120,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              if (m.texte.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: m.photoPath != null ? 6 : 0,
                                    left: m.photoPath != null ? 8 : 0,
                                    right: m.photoPath != null ? 8 : 0,
                                  ),
                                  child: Text(
                                    m.texte,
                                    style: TextStyle(
                                      color: estMoi
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.only(
                                  top: 4,
                                  left: m.photoPath != null ? 8 : 0,
                                  right: m.photoPath != null ? 8 : 0,
                                  bottom: m.photoPath != null ? 6 : 0,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (m.modifie)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: Text(
                                          'modifié',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: estMoi
                                                ? Colors.white70
                                                : Colors.black45,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '${m.horodatage.hour.toString().padLeft(2, '0')}:${m.horodatage.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: estMoi
                                            ? Colors.white70
                                            : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    // Pour mes propres messages : un bouton "⋮" toujours
                    // visible et cliquable à la souris (utile sur PC, où
                    // l'appui long ne fonctionne pas bien). L'appui long
                    // reste disponible en plus, pour mobile.
                    if (!estMoi) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: bulle,
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(child: bulle),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 20),
                          color: Colors.grey.shade600,
                          tooltip: 'Modifier / supprimer',
                          onPressed: () => _ouvrirOptions(m),
                        ),
                      ],
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
                  IconButton(
                    onPressed: _envoiEnCours ? null : _envoyerPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
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
