import 'package:flutter/material.dart';

import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';

/// Traduit un code de secteur brut (venant du fichier Excel) en libellé
/// lisible par l'utilisateur. Règle : 0 = Public, 1 = Privé, 2 = Libre.
/// Si la valeur n'est pas un code connu, on l'affiche telle quelle
/// (cas où l'utilisateur aurait déjà tapé "Public" directement, par ex.).
String libelleSecteur(String valeurBrute) {
  switch (valeurBrute.trim()) {
    case '0':
      return 'Public';
    case '1':
      return 'Privé';
    case '2':
      return 'Libre';
    default:
      return valeurBrute;
  }
}

/// Écran générique de gestion d'une liste de référence, affichée en
/// TABLEAU (DataTable) avec une barre de recherche.
///
/// Réutilisé pour : établissements, écoles d'origine (CEPE/BEPC), CEG
/// d'accueil, lycée d'accueil, langues, sports collectifs/individuels.
class GestionListeScreen extends StatefulWidget {
  final String titre;
  final String typeListe;
  final List<String> nomsChamps;

  const GestionListeScreen({
    super.key,
    required this.titre,
    required this.typeListe,
    required this.nomsChamps,
  });

  @override
  State<GestionListeScreen> createState() => _GestionListeScreenState();
}

class _GestionListeScreenState extends State<GestionListeScreen> {
  List<ItemListe> _items = [];
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final items = await SqliteService.instance.listerItems(widget.typeListe);
    setState(() => _items = items);
  }

  List<ItemListe> get _itemsFiltres {
    if (_recherche.trim().isEmpty) return _items;
    final q = _recherche.toLowerCase();
    return _items.where((item) {
      return item.champs.values.any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  /// Valeur affichée dans le tableau : applique la traduction secteur si
  /// le champ s'appelle 'secteur', sinon affiche la valeur brute.
  String _valeurAffichee(String champ, String valeurBrute) {
    if (champ == 'secteur') return libelleSecteur(valeurBrute);
    return valeurBrute;
  }

  Future<void> _ouvrirFormulaire({ItemListe? existant}) async {
    final controllers = {
      for (final champ in widget.nomsChamps)
        champ: TextEditingController(text: existant?.champs[champ] ?? ''),
    };

    final resultat = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existant == null ? 'Ajouter' : 'Modifier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final champ in widget.nomsChamps)
                if (champ == 'secteur')
                  DropdownButtonFormField<String>(
                    value: controllers[champ]!.text.isEmpty
                        ? null
                        : controllers[champ]!.text,
                    decoration: const InputDecoration(labelText: 'Secteur'),
                    items: const [
                      DropdownMenuItem(value: '0', child: Text('Public')),
                      DropdownMenuItem(value: '1', child: Text('Privé')),
                      DropdownMenuItem(value: '2', child: Text('Libre')),
                    ],
                    onChanged: (val) => controllers[champ]!.text = val ?? '',
                  )
                else
                  TextField(
                    controller: controllers[champ],
                    decoration: InputDecoration(labelText: champ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (resultat != true) return;

    final champsSaisis = {
      for (final champ in widget.nomsChamps) champ: controllers[champ]!.text,
    };

    final item = ItemListe(
      id:
          existant?.id ??
          '${widget.typeListe}_${DateTime.now().millisecondsSinceEpoch}',
      typeListe: widget.typeListe,
      champs: champsSaisis,
    );

    if (existant == null) {
      await SqliteService.instance.insererItemListe(item);
    } else {
      await SqliteService.instance.modifierItemListe(item);
    }
    await _rafraichir();
  }

  Future<void> _supprimer(ItemListe item) async {
    await SqliteService.instance.supprimerItemListe(item.id);
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsFiltres;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => _ouvrirFormulaire(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _recherche = val),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Aucun résultat'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          for (final champ in widget.nomsChamps)
                            DataColumn(label: Text(champ.toUpperCase())),
                          const DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: [
                          for (final item in items)
                            DataRow(
                              cells: [
                                for (final champ in widget.nomsChamps)
                                  DataCell(
                                    Text(
                                      _valeurAffichee(
                                        champ,
                                        item.champs[champ] ?? '',
                                      ),
                                    ),
                                  ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () =>
                                            _ouvrirFormulaire(existant: item),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _supprimer(item),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
