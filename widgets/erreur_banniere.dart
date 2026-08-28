import 'package:flutter/material.dart';

/// Bannière d'erreur affichée en haut d'un formulaire, bien visible, pour
/// que l'utilisateur voie immédiatement qu'il y a un problème sans avoir
/// à chercher un SnackBar qui disparaît vite ou un champ en rouge caché
/// plus bas dans le formulaire.
class ErreurBanniere extends StatelessWidget {
  final String? message;
  final VoidCallback onFermer;

  const ErreurBanniere({
    super.key,
    required this.message,
    required this.onFermer,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onFermer,
            child: Icon(Icons.close, size: 18, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }
}
