import 'package:flutter/material.dart';

import '../../models/enseignant.dart';
import '../../models/item_liste.dart';
import '../../models/membre_previsionnel.dart';
import '../../models/quota_membre.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';

/// Attribution des membres prévisionnels "Identifiés" à un centre.
///
/// Règle : le Correcteur est attribué directement à un CENTRE DE
/// CORRECTION (dropdown). Les autres rôles (Jury, ChefDeCentre, Securite)
/// sont attribués à un CENTRE D'ÉCRIT — et le centre de correction en est
/// déduit AUTOMATIQUEMENT (chaque centre d'écrit a un seul centre de
/// correction rattaché, ex: Mahasoabe -> Mahazengy), sans que
/// l'utilisateur ait à le choisir séparément.
///
/// [typeExamen] = 'CEPE' ou 'BEPC', pour savoir quelles listes de centres
/// charger.
class AttributionCentreMembreScreen extends StatefulWidget {
  final String typeExamen;

  const AttributionCentreMembreScreen({super.key, required this.typeExamen});

  @override
  State<AttributionCentreMembreScreen> createState() =>
      _AttributionCentreMembreScreenState();
}

class _AttributionCentreMembreScreenState
    extends State<AttributionCentreMembreScreen> {
  List<MembrePrevisionnel> _membres = [];
  List<Enseignant> _enseignants = [];
  List<ItemListe> _centresEcrit = [];
  List<ItemListe> _centresCorrection = [];
  bool _chargement = true;

  int get _anneeSession => DateTime.now().year;
  String get _codeEtab => AppSession.instance.codeEtab ?? '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);

    final enseignants = await SqliteService.instance.listerEnseignants(
      _codeEtab,
    );
    final matriculesEtab = enseignants.map((e) => e.matricule).toSet();

    final tousMembres = await SqliteService.instance.listerMembres(
      anneeSession: _anneeSession,
    );
    final membresEtab = tousMembres
        .where((m) => matriculesEtab.contains(m.matriculeEnseignant))
        .toList();

    final typeListeEcrit = widget.typeExamen == 'CEPE'
        ? 'centreEcritCepe'
        : 'centreEcritBepc';
    final typeListeCorrection = widget.typeExamen == 'CEPE'
        ? 'centreCorrectionCepe'
        : 'centreCorrectionBepc';

    final centresEcrit = await SqliteService.instance.listerItems(
      typeListeEcrit,
    );
    final centresCorrection = await SqliteService.instance.listerItems(
      typeListeCorrection,
    );

    setState(() {
      _enseignants = enseignants;
      _membres = membresEtab;
      _centresEcrit = centresEcrit;
      _centresCorrection = centresCorrection;
      _chargement = false;
    });
  }

  Enseignant? _enseignantDe(String matricule) {
    try {
      return _enseignants.firstWhere((e) => e.matricule == matricule);
    } catch (_) {
      return null;
    }
  }

  String? _libelleCentre(String? code, List<ItemListe> centres) {
    if (code == null) return null;
    try {
      return centres
          .firstWhere((c) => c.champs['code'] == code)
          .champs['libelle'];
    } catch (_) {
      return code;
    }
  }

  /// Retrouve le centre de correction rattaché à un centre d'écrit donné,
  /// via son champ 'codecorrection' (déjà semé depuis l'Excel).
  String? _centreCorrectionDeduit(String codeCentreEcrit) {
    try {
      final centre = _centresEcrit.firstWhere(
        (c) => c.champs['code'] == codeCentreEcrit,
      );
      return centre.champs['codecorrection'];
    } catch (_) {
      return null;
    }
  }

  Future<void> _attribuerCentreEcrit(MembrePrevisionnel membre) async {
    final choix = await showDialog<ItemListe>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir le centre d\'écrit'),
        children: _centresEcrit
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c),
                child: Text(c.champs['libelle'] ?? c.champs['code'] ?? ''),
              ),
            )
            .toList(),
      ),
    );
    if (choix == null) return;

    final codeCentreEcrit = choix.champs['code']!;
    final codeCentreCorrection = _centreCorrectionDeduit(codeCentreEcrit);

    await SqliteService.instance.placerMembreEnPoste(
      codeMembre: membre.codeMembre,
      codeCentreEcrit: codeCentreEcrit,
      codeCentreCorrection: codeCentreCorrection,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Centre d\'écrit : ${choix.champs['libelle']}'
          '${codeCentreCorrection != null ? ' → centre de correction déduit automatiquement' : ''}',
        ),
      ),
    );
    await _charger();
  }

  Future<void> _attribuerCentreCorrection(MembrePrevisionnel membre) async {
    final choix = await showDialog<ItemListe>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir le centre de correction'),
        children: _centresCorrection
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c),
                child: Text(c.champs['libelle'] ?? c.champs['code'] ?? ''),
              ),
            )
            .toList(),
      ),
    );
    if (choix == null) return;

    await SqliteService.instance.placerMembreEnPoste(
      codeMembre: membre.codeMembre,
      codeCentreCorrection: choix.champs['code'],
    );

    if (!mounted) return;
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Attribution par centre — ${widget.typeExamen}'),
      ),
      body: _membres.isEmpty
          ? const Center(child: Text('Aucun membre désigné pour le moment'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _membres.length,
              itemBuilder: (ctx, i) {
                final m = _membres[i];
                final enseignant = _enseignantDe(m.matriculeEnseignant);
                final estCorrecteur = m.role == 'Correcteur';

                final centreAffiche = estCorrecteur
                    ? _libelleCentre(m.codeCentreCorrection, _centresCorrection)
                    : _libelleCentre(m.codeCentreEcrit, _centresEcrit);

                return Card(
                  child: ListTile(
                    title: Text(
                      enseignant != null
                          ? '${enseignant.nom} ${enseignant.prenom}'
                          : m.matriculeEnseignant,
                    ),
                    subtitle: Text(
                      '${libelleRole(m.role)} — ${m.etat}\n'
                      '${centreAffiche != null ? "Centre : $centreAffiche" : "Pas encore attribué"}',
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: () => estCorrecteur
                          ? _attribuerCentreCorrection(m)
                          : _attribuerCentreEcrit(m),
                      child: Text(
                        centreAffiche == null ? 'Attribuer' : 'Modifier',
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
