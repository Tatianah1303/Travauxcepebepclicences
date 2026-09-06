import 'package:flutter/material.dart';

/// Palette professionnelle à 2 couleurs principales, appliquée dans toute
/// l'application (connexion, dashboards, formulaires, listes...).
///
/// - [bleuNuit] : couleur principale — AppBars, boutons principaux, textes
///   d'accentuation. Sérieux, institutionnel (adapté à un contexte
///   administratif/scolaire).
/// - [orAccent] : couleur secondaire — boutons d'action (+ ajouter, envoyer,
///   valider), petits accents visuels. Apporte de la chaleur sans
///   surcharger.
///
/// Exception volontaire : les graphiques de la page Statistiques (admin)
/// gardent plusieurs couleurs distinctes, nécessaires pour différencier
/// les catégories d'un diagramme en bâtonnets.
class AppTheme {
  static const Color bleuNuit = Color(0xFF0D1B2A);
  static const Color bleuNuitClair = Color(0xFF1B3A5C);
  static const Color orAccent = Color(0xFFC9962C);
  static const Color fond = Color(0xFFF4F6F9);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: fond,
      colorScheme: ColorScheme.fromSeed(
        seedColor: bleuNuit,
        primary: bleuNuit,
        secondary: orAccent,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bleuNuit,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bleuNuit,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: bleuNuit,
          side: const BorderSide(color: bleuNuit),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: orAccent,
        foregroundColor: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: bleuNuit),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      inputDecorationTheme: OutlineInputBorder().let((border) => InputDecorationTheme(
            border: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: orAccent, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          )),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? orAccent : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? orAccent.withValues(alpha: 0.5) : Colors.grey.shade300,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(bleuNuit.withValues(alpha: 0.06)),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: bleuNuit),
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}