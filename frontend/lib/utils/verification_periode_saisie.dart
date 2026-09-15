import 'package:flutter/material.dart';

import '../models/periode_saisie.dart';
import '../services/sqlite_service.dart';

/// Vérifie si la saisie est actuellement autorisée (période définie par
/// l'admin). Si elle est bloquée (pas encore commencée ou déjà clôturée),
/// affiche un grand message flottant rouge et retourne false — l'appelant
/// doit alors annuler l'enregistrement.
///
/// Si aucune période n'a été définie par l'admin, la saisie reste
/// toujours autorisée (comportement historique, pas de blocage par
/// défaut).
Future<bool> saisieAutorisee(BuildContext context) async {
  final periode = await SqliteService.instance.lirePeriodeSaisie();
  if (periode == null) return true;
  if (periode.statut == StatutSaisie.enCours) return true;

  if (!context.mounted) return false;

  String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  final message = periode.statut == StatutSaisie.pasEncoreCommence
      ? 'Vous ne pouvez pas encore saisir d\'informations. '
            'La saisie ouvre le ${formatDate(periode.dateDebut)}.'
      : 'La saisie est clôturée depuis le ${formatDate(periode.dateFin)}. '
            'Vous ne pouvez plus ajouter ou modifier de données.';

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.block, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return false;
}
