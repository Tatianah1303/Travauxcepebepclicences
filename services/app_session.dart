/// Session courante : un SEUL compte par établissement (pas de notion de
/// rôle). Le "login" se fait juste avec le code établissement — c'est
/// l'établissement qui gère tout lui-même (candidats, salles, membres...).
///
/// Singleton simple : accessible partout via AppSession.instance, sans
/// avoir besoin de passer par Riverpod pour une donnée aussi globale et
/// stable pendant toute la durée de l'app.
class AppSession {
  AppSession._internal();
  static final AppSession instance = AppSession._internal();

  String? codeEtab;
  String? nomEtab;

  bool get estConnecte => codeEtab != null;

  void connecter({required String codeEtab, required String nomEtab}) {
    this.codeEtab = codeEtab;
    this.nomEtab = nomEtab;
  }

  void deconnecter() {
    codeEtab = null;
    nomEtab = null;
  }
}
