import 'gestion_liste_screen.dart';

/// Chaque classe ci-dessous est le "formulaire" d'une liste de référence
/// précise (ajout / modification / suppression), toutes basées sur
/// GestionListeScreen. Un fichier = toutes les listes, pour rester simple
/// à naviguer, mais chaque écran reste bien indépendant et réutilisable.

class EtablissementListeScreen extends GestionListeScreen {
  const EtablissementListeScreen({super.key})
      : super(
          titre: 'Établissements',
          typeListe: 'etablissement',
          nomsChamps: const ['code', 'nom', 'secteur'],
        );
}

class EcoleOrigineCepeListeScreen extends GestionListeScreen {
  const EcoleOrigineCepeListeScreen({super.key})
      : super(
          titre: 'Écoles d\'origine — CEPE',
          typeListe: 'ecoleOrigineCepe',
          nomsChamps: const ['code', 'nom', 'secteur'],
        );
}

class EcoleOrigineBepcListeScreen extends GestionListeScreen {
  const EcoleOrigineBepcListeScreen({super.key})
      : super(
          titre: 'Écoles d\'origine — BEPC',
          typeListe: 'ecoleOrigineBepc',
          nomsChamps: const ['code', 'nom', 'secteur'],
        );
}

class CegAccueilListeScreen extends GestionListeScreen {
  const CegAccueilListeScreen({super.key})
      : super(
          titre: 'CEG d\'accueil (CEPE)',
          typeListe: 'cegAccueil',
          nomsChamps: const ['code', 'libelle'],
        );
}

class LyceeAccueilListeScreen extends GestionListeScreen {
  const LyceeAccueilListeScreen({super.key})
      : super(
          titre: 'Lycée d\'accueil (BEPC)',
          typeListe: 'lyceeAccueil',
          nomsChamps: const ['code', 'libelle'],
        );
}

class CentreEcritCepeListeScreen extends GestionListeScreen {
  const CentreEcritCepeListeScreen({super.key})
      : super(
          titre: 'Centres d\'écrit — CEPE',
          typeListe: 'centreEcritCepe',
          nomsChamps: const ['code', 'libelle'],
        );
}

class CentreCorrectionCepeListeScreen extends GestionListeScreen {
  const CentreCorrectionCepeListeScreen({super.key})
      : super(
          titre: 'Centres de correction — CEPE',
          typeListe: 'centreCorrectionCepe',
          nomsChamps: const ['code', 'libelle'],
        );
}

class CentreEcritBepcListeScreen extends GestionListeScreen {
  const CentreEcritBepcListeScreen({super.key})
      : super(
          titre: 'Centres d\'écrit — BEPC',
          typeListe: 'centreEcritBepc',
          nomsChamps: const ['code', 'libelle'],
        );
}

class CentreCorrectionBepcListeScreen extends GestionListeScreen {
  const CentreCorrectionBepcListeScreen({super.key})
      : super(
          titre: 'Centres de correction — BEPC',
          typeListe: 'centreCorrectionBepc',
          nomsChamps: const ['code', 'libelle'],
        );
}

class GroupeCepeListeScreen extends GestionListeScreen {
  const GroupeCepeListeScreen({super.key})
      : super(
          titre: 'Groupes CEPE (A, B, C)',
          typeListe: 'groupeCepe',
          nomsChamps: const ['code', 'libelle'],
        );
}

class GroupeBepcListeScreen extends GestionListeScreen {
  const GroupeBepcListeScreen({super.key})
      : super(
          titre: 'Groupes BEPC (I, II, III)',
          typeListe: 'groupeBepc',
          nomsChamps: const ['code', 'libelle'],
        );
}

class LangueListeScreen extends GestionListeScreen {
  const LangueListeScreen({super.key})
      : super(
          titre: 'Langues',
          typeListe: 'langue',
          nomsChamps: const ['libelle'],
        );
}

class TypeHandicapListeScreen extends GestionListeScreen {
  const TypeHandicapListeScreen({super.key})
      : super(
          titre: 'Types de handicap',
          typeListe: 'typeHandicap',
          nomsChamps: const ['libelle'],
        );
}

class SportCollectifListeScreen extends GestionListeScreen {
  const SportCollectifListeScreen({super.key})
      : super(
          titre: 'Sports collectifs',
          typeListe: 'sportCollectif',
          nomsChamps: const ['libelle'],
        );
}

class SportIndividuelListeScreen extends GestionListeScreen {
  const SportIndividuelListeScreen({super.key})
      : super(
          titre: 'Sports individuels',
          typeListe: 'sportIndividuel',
          nomsChamps: const ['libelle'],
        );
}
