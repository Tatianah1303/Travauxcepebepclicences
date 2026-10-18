import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/candidat_cepe.dart';
import '../models/candidat_bepc.dart';
import '../models/salle.dart';
import '../models/membre_previsionnel.dart';
import '../models/enseignant.dart';
import '../models/periode_saisie.dart';
import '../models/quota_membre.dart';
import '../models/attribution_salle.dart';

/// Service Firestore — structure alignée sur firestore.rules :
///
///   /candidats_cepe/{codeCandidat}
///   /candidats_bepc/{codeCandidat}
///   /enseignants/{matricule}
///   /membres_previsionnels/{codeMembre}
///   /salles/{id}
///   /periode_saisie/global
///   /etablissements_auth/{uid}   → {codeEtab: "..."}  (auth mapping)
///   /admins/{uid}                → présence = admin
class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();
  final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // ÉTABLISSEMENTS AUTH (mapping uid → codeEtab)
  // Créé automatiquement à la première connexion d'un établissement
  // ═══════════════════════════════════════════════════════════════

  Future<void> enregistrerEtablissementAuth(String uid, String codeEtab) async {
    final ref = _db.collection('etablissements_auth').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({'codeEtab': codeEtab});
    }
  }

  Future<String?> lireCodeEtab(String uid) async {
    final doc = await _db.collection('etablissements_auth').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['codeEtab'] as String?;
  }

  // ═══════════════════════════════════════════════════════════════
  // PÉRIODE DE SAISIE
  // ═══════════════════════════════════════════════════════════════

  Future<void> definirPeriodeSaisie(PeriodeSaisie p) async {
    await _db
        .collection('periode_saisie')
        .doc(PeriodeSaisie.idGlobal)
        .set(p.toMap());
  }

  Future<PeriodeSaisie?> lirePeriodeSaisie() async {
    final doc = await _db
        .collection('periode_saisie')
        .doc(PeriodeSaisie.idGlobal)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return PeriodeSaisie.fromMap(
      doc.data()!.map((k, v) => MapEntry(k, v as Object?)),
    );
  }

  Future<void> supprimerPeriodeSaisie() async {
    await _db.collection('periode_saisie').doc(PeriodeSaisie.idGlobal).delete();
  }

  // ═══════════════════════════════════════════════════════════════
  // CANDIDATS CEPE
  // ═══════════════════════════════════════════════════════════════

  Future<void> ajouterCandidatCepe(CandidatCepe c) async {
    await _db.collection('candidats_cepe').doc(c.codeCandidat).set(c.toMap());
  }

  Future<void> modifierCandidatCepe(CandidatCepe c) => ajouterCandidatCepe(c);

  Future<void> supprimerCandidatCepe(String codeCandidat) async {
    await _db.collection('candidats_cepe').doc(codeCandidat).delete();
  }

  Future<List<CandidatCepe>> listerCandidatsCepe({
    String? codeEtab,
    int? anneeSession,
  }) async {
    Query q = _db.collection('candidats_cepe');
    if (codeEtab != null) q = q.where('codeEtab', isEqualTo: codeEtab);
    if (anneeSession != null)
      q = q.where('anneeSession', isEqualTo: anneeSession);
    final snap = await q.get();
    return snap.docs
        .map(
          (d) => CandidatCepe.fromMap(
            (d.data() as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v as Object?),
            ),
          ),
        )
        .toList();
  }

  // Admin voit tout
  Future<List<CandidatCepe>> listerTousCandidatsCepe({int? anneeSession}) =>
      listerCandidatsCepe(anneeSession: anneeSession);

  // ═══════════════════════════════════════════════════════════════
  // CANDIDATS BEPC
  // ═══════════════════════════════════════════════════════════════

  Future<void> ajouterCandidatBepc(CandidatBepc c) async {
    await _db.collection('candidats_bepc').doc(c.codeCandidat).set(c.toMap());
  }

  Future<void> modifierCandidatBepc(CandidatBepc c) => ajouterCandidatBepc(c);

  Future<void> supprimerCandidatBepc(String codeCandidat) async {
    await _db.collection('candidats_bepc').doc(codeCandidat).delete();
  }

  Future<List<CandidatBepc>> listerCandidatsBepc({
    String? codeEtab,
    int? anneeSession,
  }) async {
    Query q = _db.collection('candidats_bepc');
    if (codeEtab != null) q = q.where('codeEtab', isEqualTo: codeEtab);
    if (anneeSession != null)
      q = q.where('anneeSession', isEqualTo: anneeSession);
    final snap = await q.get();
    return snap.docs
        .map(
          (d) => CandidatBepc.fromMap(
            (d.data() as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v as Object?),
            ),
          ),
        )
        .toList();
  }

  Future<List<CandidatBepc>> listerTousCandidatsBepc({int? anneeSession}) =>
      listerCandidatsBepc(anneeSession: anneeSession);

  // ═══════════════════════════════════════════════════════════════
  // SALLES
  // ═══════════════════════════════════════════════════════════════

  Future<void> ajouterSalle(Salle s) async {
    await _db.collection('salles').doc(s.id).set(s.toMap());
  }

  Future<void> modifierSalle(Salle s) => ajouterSalle(s);

  Future<void> supprimerSalle(String id) async {
    await _db.collection('salles').doc(id).delete();
  }

  Future<List<Salle>> listerSalles({
    int? anneeSession,
    String? typeExamen,
  }) async {
    Query q = _db.collection('salles');
    if (typeExamen != null) q = q.where('typeExamen', isEqualTo: typeExamen);
    final snap = await q.get();
    return snap.docs
        .map(
          (d) => Salle.fromMap(
            (d.data() as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v as Object?),
            ),
          ),
        )
        .where((s) => anneeSession == null || s.anneeSession == anneeSession)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // ENSEIGNANTS
  // ═══════════════════════════════════════════════════════════════

  Future<void> ajouterEnseignant(Enseignant e) async {
    await _db.collection('enseignants').doc(e.matricule).set(e.toMap());
  }

  Future<void> modifierEnseignant(Enseignant e) => ajouterEnseignant(e);

  /// Vrai si l'enseignant est déjà désigné membre prévisionnel (son
  /// identifiant ne doit alors plus changer).
  Future<bool> enseignantEstMembre(String codeEtab, String matricule) async {
    final snap = await _db
        .collection('membres_previsionnels')
        .where('codeEtab', isEqualTo: codeEtab)
        .where('matriculeEnseignant', isEqualTo: matricule)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> supprimerEnseignant(String codeEtab, String matricule) async {
    await _db.collection('enseignants').doc(matricule).delete();
  }

  Future<List<Enseignant>> listerEnseignants(String codeEtab) async {
    final snap = await _db
        .collection('enseignants')
        .where('codeEtab', isEqualTo: codeEtab)
        .get();
    return snap.docs
        .map(
          (d) => Enseignant.fromMap(
            (d.data()).map((k, v) => MapEntry(k, v as Object?)),
          ),
        )
        .toList();
  }

  Future<List<Enseignant>> listerTousEnseignants() async {
    final snap = await _db.collection('enseignants').get();
    return snap.docs
        .map(
          (d) => Enseignant.fromMap(
            (d.data()).map((k, v) => MapEntry(k, v as Object?)),
          ),
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // MEMBRES PRÉVISIONNELS
  // ═══════════════════════════════════════════════════════════════

  /// codeEtab est passé séparément car MembrePrevisionnel ne l'a pas
  /// dans son modèle — on l'ajoute au document Firestore pour les règles.
  Future<void> ajouterMembre(String codeEtab, MembrePrevisionnel m) async {
    final data = m.toMap()..['codeEtab'] = codeEtab;
    await _db.collection('membres_previsionnels').doc(m.codeMembre).set(data);
  }

  Future<void> modifierMembre(String codeEtab, MembrePrevisionnel m) =>
      ajouterMembre(codeEtab, m);

  Future<void> supprimerMembre(String codeMembre) async {
    await _db.collection('membres_previsionnels').doc(codeMembre).delete();
  }

  Future<List<MembrePrevisionnel>> listerMembres({
    String? codeEtab,
    int? anneeSession,
    String? typeExamen,
  }) async {
    Query q = _db.collection('membres_previsionnels');
    if (codeEtab != null) q = q.where('codeEtab', isEqualTo: codeEtab);
    final snap = await q.get();
    return snap.docs
        .map(
          (d) => MembrePrevisionnel.fromMap(
            (d.data() as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v as Object?),
            ),
          ),
        )
        .where((m) => anneeSession == null || m.anneeSession == anneeSession)
        .where((m) => typeExamen == null || m.typeExamen == typeExamen)
        .toList();
  }

  Future<List<MembrePrevisionnel>> listerTousMembres({int? anneeSession}) =>
      listerMembres(anneeSession: anneeSession);

  /// Affecte le centre d'écrit et/ou de correction d'un membre déjà créé.
  /// La mise à jour conserve tous les autres champs Firestore du document.
  Future<void> attribuerCentresMembre({
    required String codeMembre,
    String? codeCentreEcrit,
    String? codeCentreCorrection,
  }) async {
    final changements = <String, Object?>{
      'etat': 'En activité',
      'codeCentreEcrit': codeCentreEcrit,
      'codeCentreCorrection': codeCentreCorrection,
    };
    await _db
        .collection('membres_previsionnels')
        .doc(codeMembre)
        .update(changements);
  }

  Future<void> definirAttributionSalle(AttributionSalle attribution) async {
    await _db
        .collection('attributions_salle')
        .doc(attribution.id)
        .set(attribution.toMap());
  }

  Future<List<AttributionSalle>> listerAttributionsSalle(
    String codeSalle,
  ) async {
    final snap = await _db
        .collection('attributions_salle')
        .where('codeSalle', isEqualTo: codeSalle)
        .get();
    return snap.docs
        .map(
          (d) => AttributionSalle.fromMap(
            d.data().map((k, v) => MapEntry(k, v as Object?)),
          ),
        )
        .toList();
  }

  Future<void> definirQuota(QuotaMembre quota) async {
    await _db.collection('quotas_membres').doc(quota.id).set(quota.toMap());
  }

  Future<List<QuotaMembre>> listerQuotas({
    required String codeEtab,
    required int anneeSession,
    required String typeExamen,
  }) async {
    final snap = await _db
        .collection('quotas_membres')
        .where('codeEtab', isEqualTo: codeEtab)
        .get();
    return snap.docs
        .map(
          (d) => QuotaMembre.fromMap(
            d.data().map((k, v) => MapEntry(k, v as Object?)),
          ),
        )
        .where(
          (q) => q.anneeSession == anneeSession && q.typeExamen == typeExamen,
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // CLÔTURE — supprime les données d'une session dans Firestore
  // ═══════════════════════════════════════════════════════════════

  Future<void> supprimerSessionFirestore(int anneeSession) async {
    // Firestore limite un lot à 500 opérations : on supprime par paquets.
    Future<void> supprimer(List<DocumentSnapshot> docs) async {
      for (var debut = 0; debut < docs.length; debut += 450) {
        final fin = (debut + 450 < docs.length) ? debut + 450 : docs.length;
        final batch = _db.batch();
        for (final doc in docs.sublist(debut, fin)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // Salles de la session : leurs attributions par établissement partent avec.
    final salles = await _db
        .collection('salles')
        .where('anneeSession', isEqualTo: anneeSession)
        .get();
    final idsSalles = salles.docs.map((d) => d.id).toSet();
    if (idsSalles.isNotEmpty) {
      final attributions = await _db.collection('attributions_salle').get();
      await supprimer(
        attributions.docs
            .where((d) => idsSalles.contains(d.data()['codeSalle']))
            .toList(),
      );
    }

    for (final col in [
      'candidats_cepe',
      'candidats_bepc',
      'membres_previsionnels',
      'quotas_membres',
    ]) {
      final snap = await _db
          .collection(col)
          .where('anneeSession', isEqualTo: anneeSession)
          .get();
      await supprimer(snap.docs);
    }
    await supprimer(salles.docs);
    await supprimerPeriodeSaisie();
  }
}
