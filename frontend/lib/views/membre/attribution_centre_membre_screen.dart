import 'package:flutter/material.dart';

import '../../models/enseignant.dart';
import '../../models/item_liste.dart';
import '../../models/membre_previsionnel.dart';
import '../../models/quota_membre.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../widgets/searchable_dropdown.dart';

/// Attribution des membres prévisionnels "Identifiés" à un centre.
///
/// Chaque membre, quel que soit son rôle, dispose de DEUX choix
/// indépendants et toujours visibles : le centre d'écrit et le centre de
/// correction. Choisir un centre d'écrit propose automatiquement le centre
/// de correction rattaché (s'il est connu), mais l'utilisateur peut aussi
/// choisir/modifier le centre de correction séparément.
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
      typeExamen: widget.typeExamen,
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

  Future<void> _choisirCentreEcrit(MembrePrevisionnel membre) async {
    final choix = await pickerRecherche<ItemListe>(
      context,
      titre: 'Choisir le centre d\'écrit',
      items: _centresEcrit,
      libelleDe: (c) => c.champs['libelle'] ?? c.champs['code'] ?? '',
    );
    if (choix == null) return;

    final codeCentreEcrit = choix.champs['code']!;
    // On propose automatiquement le centre de correction rattaché, sans
    // empêcher l'utilisateur de le changer ensuite séparément.
    final codeCentreCorrectionDeduit = _centreCorrectionDeduit(codeCentreEcrit);

    await SqliteService.instance.placerMembreEnPoste(
      codeMembre: membre.codeMembre,
      codeCentreEcrit: codeCentreEcrit,
      codeCentreCorrection: codeCentreCorrectionDeduit,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Centre d\'écrit : ${choix.champs['libelle']}'
          '${codeCentreCorrectionDeduit != null ? ' (correction rattachée proposée automatiquement)' : ''}',
        ),
      ),
    );
    await _charger();
  }

  Future<void> _choisirCentreCorrection(MembrePrevisionnel membre) async {
    final choix = await pickerRecherche<ItemListe>(
      context,
      titre: 'Choisir le centre de correction',
      items: _centresCorrection,
      libelleDe: (c) => c.champs['libelle'] ?? c.champs['code'] ?? '',
    );
    if (choix == null) return;

    await SqliteService.instance.placerMembreEnPoste(
      codeMembre: membre.codeMembre,
      codeCentreCorrection: choix.champs['code'],
    );

    if (!mounted) return;
    await _charger();
  }

  Widget _boutonCentre({
    required String label,
    required String? valeur,
    required VoidCallback onTap,
    required Color couleur,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: couleur),
      icon: Icon(
        valeur == null ? Icons.add_location_alt : Icons.edit_location_alt,
        size: 18,
      ),
      label: Text(
        valeur == null ? label : '$label : $valeur',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
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

                final libelleEcrit = _libelleCentre(
                  m.codeCentreEcrit,
                  _centresEcrit,
                );
                final libelleCorrection = _libelleCentre(
                  m.codeCentreCorrection,
                  _centresCorrection,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple.shade50,
                              child: Icon(
                                Icons.badge,
                                color: Colors.purple.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    enseignant != null
                                        ? '${enseignant.nom} ${enseignant.prenom}'
                                        : m.matriculeEnseignant,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${libelleRole(m.role)} — ${m.etat}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Toujours les deux choix, indépendants l'un de
                        // l'autre, quel que soit le rôle du membre.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _boutonCentre(
                              label: 'Centre d\'écrit',
                              valeur: libelleEcrit,
                              couleur: Colors.blue,
                              onTap: () => _choisirCentreEcrit(m),
                            ),
                            _boutonCentre(
                              label: 'Centre de correction',
                              valeur: libelleCorrection,
                              couleur: Colors.teal,
                              onTap: () => _choisirCentreCorrection(m),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
