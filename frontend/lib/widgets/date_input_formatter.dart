import 'package:flutter/services.dart';

/// Insère automatiquement les barres obliques "/" pendant la saisie d'une
/// date, pour que l'utilisateur voie tout de suite le format attendu
/// (jj/mm/aaaa) sans avoir à taper lui-même les "/".
///
/// Exemple : l'utilisateur tape "15032010" et le champ affiche
/// progressivement "15/03/2010".
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // On ne garde que les chiffres tapés, on limite à 8 (jjmmaaaa).
    final chiffres = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final tronque = chiffres.length > 8 ? chiffres.substring(0, 8) : chiffres;

    final buffer = StringBuffer();
    for (int i = 0; i < tronque.length; i++) {
      buffer.write(tronque[i]);
      if (i == 1 || i == 3) {
        if (i != tronque.length - 1) buffer.write('/');
      }
    }

    final texte = buffer.toString();
    return TextEditingValue(
      text: texte,
      selection: TextSelection.collapsed(offset: texte.length),
    );
  }
}
