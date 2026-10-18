import 'firestore_listes_service.dart';
import 'listes_locales.dart';

/// Copie dans Firestore les listes livrées avec l'application (issues de
/// stageCisco.xlsx) pour qu'elles apparaissent dans « Listes de référence »
/// et que l'admin puisse les modifier. Les éléments ajoutés par l'admin
/// sont toujours conservés. Seul un compte admin peut écrire (firestore.rules).
class SeedService {
  static Future<void> assurerType(String typeListe) async {
    final existants = await FirestoreListesService.listerItems(typeListe);
    final initialises = await FirestoreListesService.typesInitialises();
    // Déjà initialisée et non vide : l'admin garde la main (suppressions comprises).
    if (initialises.contains(typeListe) && existants.isNotEmpty) return;

    final ids = existants.map((e) => e.id).toSet();
    final aAjouter = ListesLocales.items(
      typeListe,
    ).where((e) => !ids.contains(e.id)).toList();
    await FirestoreListesService.ajouterEnLot(aAjouter);
    await FirestoreListesService.marquerInitialise(typeListe);
  }

  static Future<void> semerSiVide() async {
    for (final type in ListesLocales.types) {
      await assurerType(type);
    }
  }
}
