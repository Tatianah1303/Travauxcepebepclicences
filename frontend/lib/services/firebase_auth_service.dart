import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gère la connexion Firebase pour les deux profils de l'app :
///
/// - Établissement : l'utilisateur ne tape QUE son code établissement,
///   rien d'autre (demande explicite du projet). En coulisses, ce code
///   sert à la fois d'identifiant et de mot de passe Firebase — c'est
///   moins fort qu'un vrai mot de passe séparé, mais ça garde
///   l'expérience "un seul champ" voulue, tout en empêchant un
///   établissement de modifier les données d'un autre (voir
///   firestore.rules).
///
/// - Admin : un compte unique, pré-créé une seule fois à la main dans la
///   console Firebase (voir instructions), avec un vrai mot de passe.
class FirebaseAuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static const _domaineEtab = 'etab.srbhm-cisco.com';

  /// Correspondance nom d'admin → email technique. Firebase exige un
  /// format d'email "valide" (les domaines comme .local sont refusés à
  /// la création dans la console), donc on utilise ici un format email
  /// classique — jamais vu ni tapé par ATI/EDGS dans l'app, uniquement
  /// utilisé en coulisses par ce code.
  static const Map<String, String> _emailsAdmins = {
    'ATI': 'atiadmin@gmail.com',
    'EDGS': 'edgsadmin@gmail.com',
  };

  /// Les deux seuls noms d'admin reconnus, tels que demandés par
  /// l'encadreur — comparaison exacte (majuscules incluses).
  static List<String> get nomsAdminsValides => _emailsAdmins.keys.toList();

  /// Connexion établissement : uniquement le code.
  /// Les 366 comptes sont pré-créés via le script Node.js.
  /// Après la connexion, on s'assure que la correspondance
  /// uid → codeEtab existe dans Firestore (requise par les règles).
  static Future<void> connecterEtablissement(String codeEtab) async {
    final email = '$codeEtab@$_domaineEtab';

    // 1. Connexion Firebase Auth
    final credentiel = await _auth.signInWithEmailAndPassword(
      email: email,
      password: codeEtab,
    );

    // 2. Créer la correspondance uid → codeEtab si elle n'existe pas encore
    //    (nécessaire pour que les règles Firestore fonctionnent)
    final uid = credentiel.user!.uid;
    final ref = _db.collection('etablissements_auth').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({'codeEtab': codeEtab});
    }
  }

  /// Connexion admin : nom (ATI ou EDGS, doit déjà être un des deux noms
  /// valides — vérifié par l'écran avant l'appel) + son propre mot de
  /// passe. Le compte correspondant doit déjà exister (créé une fois à la
  /// main dans la console Firebase — voir instructions de mise en route).
  static Future<void> connecterAdmin({
    required String nomAdmin,
    required String motDePasse,
  }) async {
    final email = _emailsAdmins[nomAdmin];
    if (email == null) {
      throw Exception('Nom d\'admin inconnu');
    }
    await _auth.signInWithEmailAndPassword(email: email, password: motDePasse);
  }

  /// Change le mot de passe de l'admin ACTUELLEMENT connecté (il ne peut
  /// changer que le sien, jamais celui de l'autre admin).
  static Future<void> changerMotDePasseAdmin(String nouveauMotDePasse) async {
    final utilisateur = _auth.currentUser;
    if (utilisateur == null) {
      throw Exception('Vous devez être connecté pour changer le mot de passe');
    }
    await utilisateur.updatePassword(nouveauMotDePasse);
  }

  static Future<void> deconnecter() => _auth.signOut();

  static User? get utilisateurActuel => _auth.currentUser;

  static bool get estConnecte => _auth.currentUser != null;
}
