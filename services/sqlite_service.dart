import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/candidat_cepe.dart';
import '../models/candidat_bepc.dart';
import '../models/membre_previsionnel.dart';
import '../models/salle.dart';
import '../models/item_liste.dart';
import '../models/enseignant.dart';
import '../models/quota_membre.dart';

/// Service d'accès à la base de données locale (SQLite).
///
/// Contient DEUX tables séparées, comme demandé, car CEPE et BEPC sont deux
/// examens différents avec des attributs propres à chacun :
///   - candidat_cepe  (groupe A/B/C, codeCegAccueil)
///   - candidat_bepc  (groupe I/II/III, codeLyceeAccueil, neeVert,
///                     numeroInscriptionAnneePrecedente)
///
/// Ce service sert de base "offline" : les données restent disponibles même
/// sans connexion. La synchronisation vers Firebase se fait séparément
/// (voir sync_service.dart, à faire dans une prochaine étape).
class SqliteService {
  SqliteService._internal();
  static final SqliteService instance = SqliteService._internal();

  static Database? _db;

  static const String tableCandidatCepe = 'candidat_cepe';
  static const String tableCandidatBepc = 'candidat_bepc';
  static const String tableMembrePrevisionnel = 'membre_previsionnel';
  static const String tableSalle = 'salle';
  static const String tableItemListe = 'item_liste';
  static const String tableEnseignant = 'enseignant';
  static const String tableQuotaMembre = 'quota_membre';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  /// Supprime complètement la base locale et la recrée vide (les tables
  /// sont recréées automatiquement via onCreate). Utile en développement
  /// quand on modifie la structure des tables (ex: ajout d'une colonne) :
  /// sans ça, SQLite garde l'ancienne structure et le nouveau champ
  /// n'apparaît jamais tant qu'on ne supprime pas manuellement le fichier.
  ///
  /// ⚠️ Supprime TOUTES les données locales (candidats, membres, listes...).
  /// À utiliser seulement en phase de développement/test, jamais en prod.
  Future<void> reinitialiserBase() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final String path = join(await getDatabasesPath(), 'gestion_examens.db');
    await databaseFactory.deleteDatabase(path);

    // Force la recréation immédiate (sinon elle ne se recrée qu'au
    // prochain accès à `database`).
    _db = await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    // Sur Windows/Linux/macOS (bureau), sqflite standard ne fonctionne pas :
    // il faut basculer sur le moteur FFI, qui simule SQLite en natif.
    // Sur Android/iOS, on garde le moteur sqflite normal (ne rien changer).
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path = join(await getDatabasesPath(), 'gestion_examens.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // --- Table CEPE ---
    await db.execute('''
      CREATE TABLE $tableCandidatCepe (
        codeCandidat TEXT PRIMARY KEY,
        numero INTEGER NOT NULL,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        lieuNaissance TEXT NOT NULL,
        adresseActuelle TEXT NOT NULL,
        dateNaissance TEXT NOT NULL,
        sexe TEXT NOT NULL,
        handicap INTEGER NOT NULL DEFAULT 0,
        typeHandicap TEXT,
        nomPere TEXT,
        nomMere TEXT NOT NULL,
        groupe TEXT NOT NULL,
        langue TEXT,
        codeEcoleOrigine TEXT NOT NULL,
        codeCegAccueil TEXT,
        codeEtab TEXT NOT NULL,
        codeCentreEcrit TEXT,
        numeroSalle TEXT,
        eps INTEGER NOT NULL DEFAULT 0,
        epreuveObligatoire TEXT,
        epreuveAuChoix TEXT,
        epreuveCollective TEXT,
        photo TEXT NOT NULL,
        etatCandidat TEXT NOT NULL,
        anneeSession INTEGER NOT NULL
      )
    ''');

    // --- Table BEPC ---
    await db.execute('''
      CREATE TABLE $tableCandidatBepc (
        codeCandidat TEXT PRIMARY KEY,
        numero INTEGER NOT NULL,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        lieuNaissance TEXT NOT NULL,
        adresseActuelle TEXT NOT NULL,
        dateNaissance TEXT NOT NULL,
        sexe TEXT NOT NULL,
        handicap INTEGER NOT NULL DEFAULT 0,
        typeHandicap TEXT,
        nomPere TEXT,
        nomMere TEXT NOT NULL,
        groupe TEXT NOT NULL,
        langue TEXT,
        numeroInscriptionAnneePrecedente TEXT,
        neeVert INTEGER NOT NULL DEFAULT 0,
        codeEcoleOrigine TEXT NOT NULL,
        codeLyceeAccueil TEXT,
        codeEtab TEXT NOT NULL,
        codeCentreEcrit TEXT,
        numeroSalle TEXT,
        eps INTEGER NOT NULL DEFAULT 0,
        epreuveObligatoire TEXT,
        epreuveAuChoix TEXT,
        epreuveCollective TEXT,
        photo TEXT NOT NULL,
        etatCandidat TEXT NOT NULL,
        anneeSession INTEGER NOT NULL
      )
    ''');

    // --- Table Membre prévisionnel (jury, correcteur, chef de centre, sécurité) ---
    await db.execute('''
      CREATE TABLE $tableMembrePrevisionnel (
        codeMembre TEXT PRIMARY KEY,
        matriculeEnseignant TEXT NOT NULL,
        role TEXT NOT NULL,
        etat TEXT NOT NULL,
        photoCinRecto TEXT,
        photoCinVerso TEXT,
        codeCentreEcrit TEXT,
        codeCentreCorrection TEXT,
        anneeSession INTEGER NOT NULL
      )
    ''');

    // --- Table Salle (saisie manuelle par centre) ---
    await db.execute('''
      CREATE TABLE $tableSalle (
        id TEXT PRIMARY KEY,
        codeCentre TEXT NOT NULL,
        numeroSalle INTEGER NOT NULL,
        capacite INTEGER NOT NULL,
        placesLibres INTEGER NOT NULL,
        typeExamen TEXT NOT NULL,
        anneeSession INTEGER NOT NULL
      )
    ''');

    // --- Table générique pour toutes les listes de référence modifiables ---
    await db.execute('''
      CREATE TABLE $tableItemListe (
        id TEXT PRIMARY KEY,
        typeListe TEXT NOT NULL,
        champs TEXT NOT NULL
      )
    ''');

    // --- Table Enseignant (par établissement) ---
    await db.execute('''
      CREATE TABLE $tableEnseignant (
        matricule TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        phone TEXT NOT NULL,
        adresse TEXT NOT NULL,
        codeEtab TEXT NOT NULL,
        fonction TEXT NOT NULL
      )
    ''');

    // --- Table Quota (nombre voulu par rôle, par établissement/année) ---
    await db.execute('''
      CREATE TABLE $tableQuotaMembre (
        id TEXT PRIMARY KEY,
        codeEtab TEXT NOT NULL,
        anneeSession INTEGER NOT NULL,
        role TEXT NOT NULL,
        quantite INTEGER NOT NULL
      )
    ''');
  }

  // ======================================================================
  //  CEPE
  // ======================================================================

  Future<void> insererCandidatCepe(CandidatCepe candidat) async {
    final db = await database;
    await db.insert(
      tableCandidatCepe,
      candidat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CandidatCepe>> listerCandidatsCepe({int? anneeSession}) async {
    final db = await database;
    final List<Map<String, Object?>> rows = anneeSession == null
        ? await db.query(tableCandidatCepe)
        : await db.query(
            tableCandidatCepe,
            where: 'anneeSession = ?',
            whereArgs: [anneeSession],
          );
    return rows.map(CandidatCepe.fromMap).toList();
  }

  Future<CandidatCepe?> lireCandidatCepe(String codeCandidat) async {
    final db = await database;
    final rows = await db.query(
      tableCandidatCepe,
      where: 'codeCandidat = ?',
      whereArgs: [codeCandidat],
    );
    if (rows.isEmpty) return null;
    return CandidatCepe.fromMap(rows.first);
  }

  Future<void> modifierCandidatCepe(CandidatCepe candidat) async {
    final db = await database;
    await db.update(
      tableCandidatCepe,
      candidat.toMap(),
      where: 'codeCandidat = ?',
      whereArgs: [candidat.codeCandidat],
    );
  }

  Future<void> supprimerCandidatCepe(String codeCandidat) async {
    final db = await database;
    await db.delete(
      tableCandidatCepe,
      where: 'codeCandidat = ?',
      whereArgs: [codeCandidat],
    );
  }

  // ======================================================================
  //  BEPC
  // ======================================================================

  Future<void> insererCandidatBepc(CandidatBepc candidat) async {
    final db = await database;
    await db.insert(
      tableCandidatBepc,
      candidat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CandidatBepc>> listerCandidatsBepc({int? anneeSession}) async {
    final db = await database;
    final List<Map<String, Object?>> rows = anneeSession == null
        ? await db.query(tableCandidatBepc)
        : await db.query(
            tableCandidatBepc,
            where: 'anneeSession = ?',
            whereArgs: [anneeSession],
          );
    return rows.map(CandidatBepc.fromMap).toList();
  }

  Future<CandidatBepc?> lireCandidatBepc(String codeCandidat) async {
    final db = await database;
    final rows = await db.query(
      tableCandidatBepc,
      where: 'codeCandidat = ?',
      whereArgs: [codeCandidat],
    );
    if (rows.isEmpty) return null;
    return CandidatBepc.fromMap(rows.first);
  }

  Future<void> modifierCandidatBepc(CandidatBepc candidat) async {
    final db = await database;
    await db.update(
      tableCandidatBepc,
      candidat.toMap(),
      where: 'codeCandidat = ?',
      whereArgs: [candidat.codeCandidat],
    );
  }

  Future<void> supprimerCandidatBepc(String codeCandidat) async {
    final db = await database;
    await db.delete(
      tableCandidatBepc,
      where: 'codeCandidat = ?',
      whereArgs: [codeCandidat],
    );
  }

  // ======================================================================
  //  MembrePrevisionnel (jury, correcteur, chef de centre, sécurité)
  // ======================================================================

  Future<void> insererMembre(MembrePrevisionnel membre) async {
    final db = await database;
    await db.insert(
      tableMembrePrevisionnel,
      membre.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MembrePrevisionnel>> listerMembres({
    int? anneeSession,
    String? role,
  }) async {
    final db = await database;
    final List<String> conditions = [];
    final List<Object?> args = [];
    if (anneeSession != null) {
      conditions.add('anneeSession = ?');
      args.add(anneeSession);
    }
    if (role != null) {
      conditions.add('role = ?');
      args.add(role);
    }
    final rows = await db.query(
      tableMembrePrevisionnel,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
    );
    return rows.map(MembrePrevisionnel.fromMap).toList();
  }

  Future<MembrePrevisionnel?> lireMembre(String codeMembre) async {
    final db = await database;
    final rows = await db.query(
      tableMembrePrevisionnel,
      where: 'codeMembre = ?',
      whereArgs: [codeMembre],
    );
    if (rows.isEmpty) return null;
    return MembrePrevisionnel.fromMap(rows.first);
  }

  Future<void> modifierMembre(MembrePrevisionnel membre) async {
    final db = await database;
    await db.update(
      tableMembrePrevisionnel,
      membre.toMap(),
      where: 'codeMembre = ?',
      whereArgs: [membre.codeMembre],
    );
  }

  Future<void> supprimerMembre(String codeMembre) async {
    final db = await database;
    await db.delete(
      tableMembrePrevisionnel,
      where: 'codeMembre = ?',
      whereArgs: [codeMembre],
    );
  }

  /// Étape "s'identifier" : enregistre les photos CIN et fait passer
  /// l'état de Désigné → Identifié (avant vérification par le système).
  Future<void> identifierMembre({
    required String codeMembre,
    required String photoCinRecto,
    required String photoCinVerso,
  }) async {
    final membre = await lireMembre(codeMembre);
    if (membre == null) return;
    await modifierMembre(
      membre.copyWith(
        etat: 'Identifié',
        photoCinRecto: photoCinRecto,
        photoCinVerso: photoCinVerso,
      ),
    );
  }

  /// Étape "placer le membre par centre" : appelée seulement si
  /// l'identité est validée (voir diagramme de séquence — alt [identité valide]).
  Future<void> placerMembreEnPoste({
    required String codeMembre,
    String? codeCentreEcrit,
    String? codeCentreCorrection,
  }) async {
    final membre = await lireMembre(codeMembre);
    if (membre == null) return;
    await modifierMembre(
      membre.copyWith(
        etat: 'En poste',
        codeCentreEcrit: codeCentreEcrit,
        codeCentreCorrection: codeCentreCorrection,
      ),
    );
  }

  /// Étape "confirmer présent/absent" le jour de l'examen.
  Future<void> confirmerPresenceMembre({
    required String codeMembre,
    required bool present,
  }) async {
    final membre = await lireMembre(codeMembre);
    if (membre == null) return;
    await modifierMembre(membre.copyWith(etat: present ? 'Présent' : 'Absent'));
  }

  // ======================================================================
  //  Salle (saisie manuelle par centre)
  // ======================================================================

  Future<void> insererSalle(Salle salle) async {
    final db = await database;
    await db.insert(
      tableSalle,
      salle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Salle>> listerSalles({
    required String typeExamen,
    String? codeCentre,
    int? anneeSession,
  }) async {
    final db = await database;
    final List<String> conditions = ['typeExamen = ?'];
    final List<Object?> args = [typeExamen];
    if (codeCentre != null) {
      conditions.add('codeCentre = ?');
      args.add(codeCentre);
    }
    if (anneeSession != null) {
      conditions.add('anneeSession = ?');
      args.add(anneeSession);
    }
    final rows = await db.query(
      tableSalle,
      where: conditions.join(' AND '),
      whereArgs: args,
    );
    return rows.map(Salle.fromMap).toList();
  }

  Future<void> modifierSalle(Salle salle) async {
    final db = await database;
    await db.update(
      tableSalle,
      salle.toMap(),
      where: 'id = ?',
      whereArgs: [salle.id],
    );
  }

  Future<void> supprimerSalle(String id) async {
    final db = await database;
    await db.delete(tableSalle, where: 'id = ?', whereArgs: [id]);
  }

  // ======================================================================
  //  ItemListe (générique : établissement, école d'origine, CEG/lycée
  //  d'accueil, langue, sport... — tout ce qui est ajoutable via le "+")
  // ======================================================================

  Future<void> insererItemListe(ItemListe item) async {
    final db = await database;
    await db.insert(
      tableItemListe,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ItemListe>> listerItems(String typeListe) async {
    final db = await database;
    final rows = await db.query(
      tableItemListe,
      where: 'typeListe = ?',
      whereArgs: [typeListe],
    );
    return rows.map(ItemListe.fromMap).toList();
  }

  Future<void> modifierItemListe(ItemListe item) async {
    final db = await database;
    await db.update(
      tableItemListe,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> supprimerItemListe(String id) async {
    final db = await database;
    await db.delete(tableItemListe, where: 'id = ?', whereArgs: [id]);
  }

  // ======================================================================
  //  Enseignant (par établissement)
  // ======================================================================

  Future<void> insererEnseignant(Enseignant enseignant) async {
    final db = await database;
    await db.insert(
      tableEnseignant,
      enseignant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Enseignant>> listerEnseignants(String codeEtab) async {
    final db = await database;
    final rows = await db.query(
      tableEnseignant,
      where: 'codeEtab = ?',
      whereArgs: [codeEtab],
    );
    return rows.map(Enseignant.fromMap).toList();
  }

  /// Tous les enseignants, tous établissements confondus — utilisé côté
  /// Administration CISCO pour les statistiques globales.
  Future<List<Enseignant>> listerTousEnseignants() async {
    final db = await database;
    final rows = await db.query(tableEnseignant);
    return rows.map(Enseignant.fromMap).toList();
  }

  Future<void> supprimerEnseignant(String matricule) async {
    final db = await database;
    await db.delete(
      tableEnseignant,
      where: 'matricule = ?',
      whereArgs: [matricule],
    );
  }

  // ======================================================================
  //  QuotaMembre (nombre voulu par rôle, par établissement + année)
  // ======================================================================

  Future<void> definirQuota(QuotaMembre quota) async {
    final db = await database;
    await db.insert(
      tableQuotaMembre,
      quota.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<QuotaMembre>> listerQuotas({
    required String codeEtab,
    required int anneeSession,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableQuotaMembre,
      where: 'codeEtab = ? AND anneeSession = ?',
      whereArgs: [codeEtab, anneeSession],
    );
    return rows.map(QuotaMembre.fromMap).toList();
  }

  // ======================================================================
  //  Utilitaires communs (utile pour l'archivage / clôture de session)
  // ======================================================================

  /// Supprime toutes les données d'une année de session donnée, dans les
  /// deux tables. Utilisé par archive_service.dart après export en .zip.
  Future<void> supprimerSession(int anneeSession) async {
    final db = await database;
    await db.delete(
      tableCandidatCepe,
      where: 'anneeSession = ?',
      whereArgs: [anneeSession],
    );
    await db.delete(
      tableCandidatBepc,
      where: 'anneeSession = ?',
      whereArgs: [anneeSession],
    );
    await db.delete(
      tableMembrePrevisionnel,
      where: 'anneeSession = ?',
      whereArgs: [anneeSession],
    );
    await db.delete(
      tableSalle,
      where: 'anneeSession = ?',
      whereArgs: [anneeSession],
    );
  }
}
