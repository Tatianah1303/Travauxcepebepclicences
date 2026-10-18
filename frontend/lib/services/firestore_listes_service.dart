import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_liste.dart';

/// Version en ligne (Firestore) de la gestion des listes de référence
/// (établissements, écoles d'origine, CEG/lycée d'accueil, langues,
/// centres, sports...). Remplace les méthodes équivalentes de
/// stockage SQLite. Les écrans chargent les valeurs depuis Firestore et
/// seuls les comptes admin peuvent les modifier.
class FirestoreListesService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'listes_reference';

  /// Toutes les entrées d'un type de liste donné (ex: 'etablissement').
  static Future<List<ItemListe>> listerItems(String typeListe) async {
    final snap = await _db
        .collection(_collection)
        .where('typeListe', isEqualTo: typeListe)
        .get();
    return snap.docs.map(_depuisDocument).toList();
  }

  /// Écoute en direct les changements d'un type de liste (utile pour que
  /// tous les établissements voient les ajouts des autres en temps réel).
  static Stream<List<ItemListe>> ecouterItems(String typeListe) {
    return _db
        .collection(_collection)
        .where('typeListe', isEqualTo: typeListe)
        .snapshots()
        .map((snap) => snap.docs.map(_depuisDocument).toList());
  }

  static Future<void> insererItemListe(ItemListe item) async {
    await _db.collection(_collection).doc(item.id).set({
      'id': item.id,
      'typeListe': item.typeListe,
      'champs': item.champs,
    });
  }

  static Future<void> modifierItemListe(ItemListe item) =>
      insererItemListe(item); // set() écrase déjà proprement

  static Future<void> supprimerItemListe(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  // Document spécial (sans champ typeListe, donc jamais renvoyé par les
  // requêtes ci-dessus) qui mémorise les listes déjà initialisées.
  static const _metaId = '_initialisees_v2';

  /// Types de listes déjà initialisés dans Firestore (pas de retour automatique
  /// des éléments que l'admin aurait supprimés ensuite).
  static Future<Set<String>> typesInitialises() async {
    try {
      final d = await _db.collection(_collection).doc(_metaId).get();
      final t = d.data()?['types'];
      return t is List ? t.map((e) => '$e').toSet() : <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> marquerInitialise(String typeListe) {
    return _db.collection(_collection).doc(_metaId).set({
      'types': FieldValue.arrayUnion([typeListe]),
    }, SetOptions(merge: true));
  }

  static Future<void> ajouterEnLot(List<ItemListe> items) async {
    for (var debut = 0; debut < items.length; debut += 450) {
      final batch = _db.batch();
      final fin = (debut + 450 < items.length) ? debut + 450 : items.length;
      for (final item in items.sublist(debut, fin)) {
        batch.set(_db.collection(_collection).doc(item.id), {
          'id': item.id,
          'typeListe': item.typeListe,
          'champs': item.champs,
        });
      }
      await batch.commit();
    }
  }

  static ItemListe _depuisDocument(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemListe(
      id: data['id'] as String,
      typeListe: data['typeListe'] as String,
      champs: Map<String, String>.from(data['champs'] as Map),
    );
  }

  /// Initialise un type de liste dans Firestore si aucun document de ce
  /// type n'existe déjà. Utilisé par le seed administrateur initial.
  static Future<int> migrerDepuisListe(List<ItemListe> items) async {
    if (items.isEmpty) return 0;
    final dejaLa = await listerItems(items.first.typeListe);
    if (dejaLa.isNotEmpty) return 0; // déjà migré pour ce type

    for (var debut = 0; debut < items.length; debut += 450) {
      final batch = _db.batch();
      final fin = (debut + 450 < items.length) ? debut + 450 : items.length;
      for (final item in items.sublist(debut, fin)) {
        batch.set(_db.collection(_collection).doc(item.id), {
          'id': item.id,
          'typeListe': item.typeListe,
          'champs': item.champs,
        });
      }
      await batch.commit();
    }
    return items.length;
  }
}
