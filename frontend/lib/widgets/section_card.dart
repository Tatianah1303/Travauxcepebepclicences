import 'package:flutter/material.dart';

/// Regroupe une section d'un formulaire dans un "cadre" bien délimité
/// (carte avec titre + icône), avec un espacement automatique et régulier
/// entre les champs qu'elle contient.
///
/// Utilisé pour éviter le rendu "en vrac" d'un long formulaire où tous les
/// champs sont juste empilés les uns après les autres sans séparation
/// visuelle claire (ex: "Identité", "Filiation", "Examen"...).
class SectionCard extends StatelessWidget {
  final String titre;
  final IconData icone;
  final List<Widget> enfants;
  final Color? couleur;

  const SectionCard({
    super.key,
    required this.titre,
    required this.icone,
    required this.enfants,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final couleurTitre = couleur ?? Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: couleurTitre),
                const SizedBox(width: 8),
                Text(
                  titre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: couleurTitre,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            for (int i = 0; i < enfants.length; i++) ...[
              enfants[i],
              if (i != enfants.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
