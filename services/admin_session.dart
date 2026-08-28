/// Session de l'Administration CISCO. Rôle purement consultatif (lecture
/// seule) : regroupe les listes et consulte les statistiques, n'intervient
/// jamais dans les opérations métier des établissements.
class AdminSession {
  AdminSession._internal();
  static final AdminSession instance = AdminSession._internal();

  String? codeAdmin;
  String? nomAgent;

  bool get estConnecte => codeAdmin != null;

  void connecter({required String codeAdmin, required String nomAgent}) {
    this.codeAdmin = codeAdmin;
    this.nomAgent = nomAgent;
  }

  void deconnecter() {
    codeAdmin = null;
    nomAgent = null;
  }
}
