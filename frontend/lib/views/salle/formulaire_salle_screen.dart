import 'package:flutter/material.dart';

import '../../models/salle.dart';
import '../../models/item_liste.dart';
import '../../models/attribution_salle.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../widgets/searchable_dropdown.dart';

/// Formulaire de création/consultation des salles d'un centre d'écrit.
/// [typeExamen] = 'CEPE' ou 'BEPC'.
///
/// Une salle est une ressource PARTAGÉE entre plusieurs établissements :
/// sa "capacité" est fixée une seule fois (à sa création), mais chaque
/// établissement y attribue ensuite séparément son propre nombre de
/// candidats. Les places libres affichées = capacité − somme de toutes
/// les attributions déjà faites (par tous les établissements).
class FormulaireSalleScreen extends StatefulWidget {
  final String typeExamen;

  const FormulaireSalleScreen({super.key, required this.typeExamen});

  @override
  State<FormulaireSalleScreen> createState() => _FormulaireSalleScreenState();
}

class _FormulaireSalleScreenState extends State<FormulaireSalleScreen> {
  final _numeroSalleController = TextEditingController();
  final _capaciteController = TextEditingController();

  String? _codeCentre;
  List<ItemListe> _centres = [];
  List<Salle> _salles = [];

  /// Pour chaque salle, la somme de TOUTES les attributions (tous
  /// établissements confondus) — sert à calculer les places libres.
  final Map<String, int> _totalAttribueParSalle = {};

  /// Pour chaque salle, CE QUE CET établissement y a attribué.
  final Map<String, int> _monAttributionParSalle = {};

  String get _codeEtab => AppSession.instance.codeEtab ?? '';

  String get _typeListeCentre =>
      widget.typeExamen == 'CEPE' ? 'centreEcritCepe' : 'centreEcritBepc';

  @override
  void initState() {
    super.initState();
    _rafraichir();
    _chargerCentres();
  }

  Future<void> _chargerCentres() async {
    final centres = await SqliteService.instance.listerItems(_typeListeCentre);
    setState(() => _centres = centres);
  }

  String _libelleCentre(String code) {
    try {
      final c = _centres.firstWhere((c) => c.champs['code'] == code);
      return c.champs['libelle'] ?? c.champs['nom'] ?? code;
    } catch (_) {
      return code;
    }
  }

  Future<void> _rafraichir() async {
    final salles = await SqliteService.instance.listerSalles(
      typeExamen: widget.typeExamen,
    );
    _totalAttribueParSalle.clear();
    _monAttributionParSalle.clear();
    for (final s in salles) {
      final attributions = await SqliteService.instance.listerAttributionsSalle(
        s.id,
      );
      _totalAttribueParSalle[s.id] = attributions.fold(
        0,
        (a, b) => a + b.nombreCandidats,
      );
      final mien = attributions.where((a) => a.codeEtab == _codeEtab);
      _monAttributionParSalle[s.id] = mien.isEmpty
          ? 0
          : mien.first.nombreCandidats;
    }
    setState(() => _salles = salles);
  }

  int _placesLibres(Salle s) =>
      s.capacite - (_totalAttribueParSalle[s.id] ?? 0);

  Future<void> _ajouter() async {
    final codeCentre = _codeCentre;
    final numero = int.tryParse(_numeroSalleController.text.trim());
    final capacite = int.tryParse(_capaciteController.text.trim());

    if (codeCentre == null || numero == null || capacite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remplissez tous les champs correctement'),
        ),
      );
      return;
    }

    final id = '${widget.typeExamen}_${codeCentre}_$numero';
    if (_salles.any((s) => s.id == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cette salle existe déjà — utilisez "Attribuer mes candidats" '
            'sur la ligne correspondante au lieu de la recréer.',
          ),
        ),
      );
      return;
    }

    final salle = Salle(
      id: id,
      codeCentre: codeCentre,
      numeroSalle: numero,
      capacite: capacite,
      placesLibres: capacite,
      typeExamen: widget.typeExamen,
      anneeSession: DateTime.now().year,
    );

    await SqliteService.instance.insererSalle(salle);
    _numeroSalleController.clear();
    _capaciteController.clear();
    setState(() => _codeCentre = null);
    await _rafraichir();
  }

  Future<void> _attribuer(Salle salle) async {
    final dejaAttribue = _totalAttribueParSalle[salle.id] ?? 0;
    final monAttribution = _monAttributionParSalle[salle.id] ?? 0;
    // Places disponibles pour MOI = places libres + ce que j'ai déjà pris
    // (puisque je peux modifier ma propre valeur à la hausse ou à la baisse).
    final maxPourMoi = salle.capacite - dejaAttribue + monAttribution;

    final controleur = TextEditingController(
      text: monAttribution == 0 ? '' : '$monAttribution',
    );

    final valeur = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Attribuer mes candidats — Salle ${salle.numeroSalle}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Places disponibles pour votre établissement dans cette '
              'salle : $maxPourMoi (sur ${salle.capacite} au total).',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controleur,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nombre de candidats',
                prefixIcon: Icon(Icons.groups),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controleur.text.trim());
              if (n == null || n < 0) return;
              if (n > maxPourMoi) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Maximum $maxPourMoi places disponibles pour vous ici',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop(n);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (valeur == null) return;
    await SqliteService.instance.definirAttributionSalle(
      AttributionSalle(
        id: '${salle.id}_$_codeEtab',
        codeSalle: salle.id,
        codeEtab: _codeEtab,
        nombreCandidats: valeur,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$valeur candidat(s) attribué(s) à cette salle')),
    );
    await _rafraichir();
  }

  Future<void> _supprimer(Salle salle) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette salle ?'),
        content: Text(
          '${_libelleCentre(salle.codeCentre)} — Salle ${salle.numeroSalle}\n\n'
          'Toutes les attributions faites par les établissements dans cette '
          'salle seront perdues.',
        ),
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
    await SqliteService.instance.supprimerSalle(salle.id);
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: Text('Salles — ${widget.typeExamen}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.meeting_room, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Créer une nouvelle salle',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Une salle est partagée entre établissements. Créez-la '
                      'seulement si elle n\'existe pas déjà pour ce centre.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  SearchableDropdown<ItemListe>(
                    label: 'Centre',
                    icone: Icons.apartment,
                    obligatoire: true,
                    items: _centres,
                    libelleDe: (c) =>
                        c.champs['libelle'] ??
                        c.champs['nom'] ??
                        c.champs['code'] ??
                        '',
                    valeurDe: (c) => c.champs['code'],
                    valeurSelectionnee: _codeCentre,
                    onSelectionner: (c) =>
                        setState(() => _codeCentre = c?.champs['code']),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numeroSalleController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'N° salle',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _capaciteController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Capacité totale',
                            prefixIcon: Icon(Icons.groups),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _ajouter,
                      icon: const Icon(Icons.add),
                      label: const Text('Créer la salle'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Salles du centre',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),

          if (_salles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucune salle enregistrée')),
            )
          else
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Colors.green.shade50,
                  ),
                  columns: const [
                    DataColumn(label: Text('CENTRE')),
                    DataColumn(label: Text('N° SALLE')),
                    DataColumn(label: Text('CAPACITÉ')),
                    DataColumn(label: Text('MON QUOTA')),
                    DataColumn(label: Text('PLACES LIBRES')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: _salles
                      .map(
                        (s) => DataRow(
                          cells: [
                            DataCell(Text(_libelleCentre(s.codeCentre))),
                            DataCell(Text('${s.numeroSalle}')),
                            DataCell(Text('${s.capacite}')),
                            DataCell(
                              Text(
                                '${_monAttributionParSalle[s.id] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${_placesLibres(s)}',
                                style: TextStyle(
                                  color: _placesLibres(s) == 0
                                      ? Colors.red
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.person_add,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    tooltip: 'Attribuer mes candidats',
                                    onPressed: () => _attribuer(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _supprimer(s),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
