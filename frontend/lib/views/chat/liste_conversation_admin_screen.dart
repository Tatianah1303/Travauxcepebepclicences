import 'package:flutter/material.dart';

import '../../services/local_chat_service.dart';
import '../../services/sqlite_service.dart';
import 'chat_thread_screen.dart';

/// Écran admin : liste de toutes les conversations avec les
/// établissements, triée par activité la plus récente.
class ListeConversationsAdminScreen extends StatefulWidget {
  const ListeConversationsAdminScreen({super.key});

  @override
  State<ListeConversationsAdminScreen> createState() =>
      _ListeConversationsAdminScreenState();
}

class _ListeConversationsAdminScreenState
    extends State<ListeConversationsAdminScreen> {
  Map<String, String> _nomsEtab = {};
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerNoms();
  }

  Future<void> _chargerNoms() async {
    final etablissements = await SqliteService.instance.listerItems(
      'etablissement',
    );
    setState(() {
      _nomsEtab = {
        for (final e in etablissements)
          (e.champs['code'] ?? ''): (e.champs['nom'] ?? ''),
      };
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages des établissements')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: LocalChatService.ecouterConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
            return const Center(
              child: Text('Aucune conversation pour le moment'),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (ctx, i) {
              final c = conversations[i];
              final codeEtab = c['codeEtab'] as String;
              final nomEtab = _nomsEtab[codeEtab] ?? codeEtab;
              final dernierMessage = c['dernierMessage'] as String;
              final dernierExpediteur = c['dernierExpediteur'] as String;

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.school)),
                title: Text(nomEtab),
                subtitle: Text(
                  '${dernierExpediteur == 'admin' ? 'Vous : ' : ''}$dernierMessage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      codeEtab: codeEtab,
                      expediteurActuel: 'admin',
                      titre: nomEtab,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
