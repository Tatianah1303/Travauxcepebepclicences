/// Valide un numéro de téléphone malgache : doit commencer par 032, 033,
/// 034, 035 ou 038, suivi de 7 chiffres (10 chiffres au total).
/// Retourne un message d'erreur si invalide, null si valide.
String? validerTelephone(String? valeur) {
  if (valeur == null || valeur.trim().isEmpty) {
    return 'Le numéro de téléphone est obligatoire';
  }
  final v = valeur.trim();
  final regex = RegExp(r'^(032|033|034|035|038)\d{7}$');
  if (!regex.hasMatch(v)) {
    return 'Numéro invalide (ex: 034 12 345 67, 10 chiffres)';
  }
  return null;
}