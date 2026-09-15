import 'package:flutter/material.dart';

/// Ouvre une feuille de recherche modale et retourne l'élément choisi (ou
/// null si annulé). Utile pour les boutons "Attribuer un centre" etc., là
/// où on ne veut pas d'un champ de formulaire mais juste d'un choix rapide
/// avec recherche.
Future<T?> pickerRecherche<T>(
  BuildContext context, {
  required String titre,
  required List<T> items,
  required String Function(T) libelleDe,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        _FeuilleRecherche<T>(titre: titre, items: items, libelleDe: libelleDe),
  );
}

/// Un champ "liste déroulante" avec une barre de recherche en haut, pour
/// retrouver rapidement un élément dans une longue liste (établissements,
/// centres...) sans avoir à faire défiler à la main.
///
/// [items] : la liste des éléments.
/// [libelleDe] : comment extraire le texte affiché/recherché pour un item.
/// [valeurDe] : comment extraire la valeur (ex: le code) pour un item.
class SearchableDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icone;
  final List<T> items;
  final String Function(T) libelleDe;
  final Object? Function(T) valeurDe;
  final Object? valeurSelectionnee;
  final ValueChanged<T?> onSelectionner;
  final bool obligatoire;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.icone,
    required this.items,
    required this.libelleDe,
    required this.valeurDe,
    required this.valeurSelectionnee,
    required this.onSelectionner,
    this.obligatoire = false,
  });

  String get _libelleActuel {
    for (final item in items) {
      if (valeurDe(item) == valeurSelectionnee) return libelleDe(item);
    }
    return '';
  }

  Future<void> _ouvrirRecherche(BuildContext context) async {
    final resultat = await pickerRecherche<T>(
      context,
      titre: label,
      items: items,
      libelleDe: libelleDe,
    );
    if (resultat != null) onSelectionner(resultat);
  }

  @override
  Widget build(BuildContext context) {
    final libelle = _libelleActuel;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _ouvrirRecherche(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: obligatoire ? '$label *' : label,
          prefixIcon: Icon(icone),
          suffixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          libelle.isEmpty ? 'Rechercher...' : libelle,
          overflow: TextOverflow.ellipsis,
          style: libelle.isEmpty
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}

class _FeuilleRecherche<T> extends StatefulWidget {
  final String titre;
  final List<T> items;
  final String Function(T) libelleDe;

  const _FeuilleRecherche({
    required this.titre,
    required this.items,
    required this.libelleDe,
  });

  @override
  State<_FeuilleRecherche<T>> createState() => _FeuilleRechercheState<T>();
}

class _FeuilleRechercheState<T> extends State<_FeuilleRecherche<T>> {
  final _controleur = TextEditingController();
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final filtres = widget.items
        .where(
          (i) => widget
              .libelleDe(i)
              .toLowerCase()
              .contains(_recherche.toLowerCase()),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.titre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controleur,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tapez un mot-clé...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _recherche.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controleur.clear();
                            setState(() => _recherche = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _recherche = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtres.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun résultat pour « $_recherche »',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtres.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(widget.libelleDe(filtres[i])),
                        onTap: () => Navigator.of(context).pop(filtres[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
