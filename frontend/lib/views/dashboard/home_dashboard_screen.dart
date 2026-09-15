import 'dart:async';
import 'package:flutter/material.dart';

import 'cepe_dashboard_screen.dart';
import 'bepc_dashboard_screen.dart';
import '../../services/app_session.dart';
import '../../services/local_chat_service.dart';
import '../../models/periode_saisie.dart';
import '../../services/sqlite_service.dart';
import '../auth/login_etablissement_screen.dart';
import '../chat/chat_thread_screen.dart';

/// Écran d'accueil : le point d'entrée après connexion. Affiche le nom de
/// l'établissement connecté en haut. Deux gros boutons : CEPE et BEPC.
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nomEtab = AppSession.instance.nomEtab ?? 'Établissement';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomEtab,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppSession.instance.codeEtab ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconeChatAvecBadge(codeEtab: AppSession.instance.codeEtab!),
                  const _ClochePeriodeSaisie(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Déconnexion',
                    onPressed: () {
                      AppSession.instance.deconnecter();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginEtablissementScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Choisissez l\'examen',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _BoutonExamen(
                        titre: 'CEPE',
                        sousTitre:
                            'Certificat d\'Études Primaires Élémentaires',
                        couleur: Colors.blue,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CepeDashboardScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _BoutonExamen(
                        titre: 'BEPC',
                        sousTitre: 'Brevet d\'Études du Premier Cycle',
                        couleur: Colors.teal,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BepcDashboardScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonExamen extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final Color couleur;
  final VoidCallback onTap;

  const _BoutonExamen({
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: couleur,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sousTitre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône de chat avec une pastille rouge affichant le nombre de messages
/// non lus reçus de l'administration (système de notification "in-app" —
/// se met à jour dès qu'un message arrive ou est lu).
class _IconeChatAvecBadge extends StatefulWidget {
  final String codeEtab;
  const _IconeChatAvecBadge({required this.codeEtab});

  @override
  State<_IconeChatAvecBadge> createState() => _IconeChatAvecBadgeState();
}

class _IconeChatAvecBadgeState extends State<_IconeChatAvecBadge> {
  int _nonLus = 0;
  StreamSubscription? _abonnement;

  @override
  void initState() {
    super.initState();
    _rafraichir();
    // Se réactualise dès qu'une conversation change (nouveau message...).
    _abonnement = LocalChatService.ecouterConversations().listen(
      (_) => _rafraichir(),
    );
  }

  Future<void> _rafraichir() async {
    final n = await LocalChatService.compterNonLus(
      widget.codeEtab,
      moi: 'etablissement',
    );
    if (mounted) setState(() => _nonLus = n);
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Chat avec l’administration',
      icon: Badge(
        label: Text('$_nonLus'),
        isLabelVisible: _nonLus > 0,
        child: const Icon(Icons.chat),
      ),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              codeEtab: widget.codeEtab,
              expediteurActuel: 'etablissement',
              titre: 'Administration CISCO',
            ),
          ),
        );
        _rafraichir();
      },
    );
  }
}

/// Petite cloche affichant la période de saisie définie par l'admin (date
/// de début, date de clôture, description) — évite à l'admin de devoir
/// écrire un message individuel à chacun des 45 établissements.
class _ClochePeriodeSaisie extends StatefulWidget {
  const _ClochePeriodeSaisie();

  @override
  State<_ClochePeriodeSaisie> createState() => _ClochePeriodeSaisieState();
}

class _ClochePeriodeSaisieState extends State<_ClochePeriodeSaisie> {
  PeriodeSaisie? _periode;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final p = await SqliteService.instance.lirePeriodeSaisie();
    if (mounted) setState(() => _periode = p);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _ouvrirDetails() {
    final p = _periode;
    if (p == null) return;
    final Color couleur = switch (p.statut) {
      StatutSaisie.enCours => Colors.green,
      StatutSaisie.pasEncoreCommence => Colors.orange,
      StatutSaisie.termine => Colors.red,
    };
    final String libelleStatut = switch (p.statut) {
      StatutSaisie.enCours => 'Saisie ouverte',
      StatutSaisie.pasEncoreCommence => 'Saisie pas encore ouverte',
      StatutSaisie.termine => 'Saisie clôturée',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.campaign, color: couleur),
            const SizedBox(width: 8),
            const Expanded(child: Text('Période de saisie')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                libelleStatut,
                style: TextStyle(color: couleur, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.play_arrow, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Début : ${_formatDate(p.dateDebut)}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.flag, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Clôture : ${_formatDate(p.dateFin)}'),
              ],
            ),
            const SizedBox(height: 14),
            Text(p.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_periode == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Période de saisie',
      onPressed: _ouvrirDetails,
      icon: const Badge(
        smallSize: 10,
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.campaign_outlined, color: Colors.white),
      ),
    );
  }
}
