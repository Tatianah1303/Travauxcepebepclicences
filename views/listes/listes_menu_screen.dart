import 'package:flutter/material.dart';

import 'ecrans_listes.dart';

/// Menu listant toutes les listes de référence modifiables.
/// [pourCepe] filtre l'affichage : montre les listes propres au CEPE si
/// true, au BEPC sinon. Les listes communes (établissement, langue,
/// handicap, sports) apparaissent dans les deux cas.
class ListesMenuScreen extends StatelessWidget {
  final bool pourCepe;

  const ListesMenuScreen({super.key, required this.pourCepe});

  @override
  Widget build(BuildContext context) {
    final items = <_ItemMenu>[
      const _ItemMenu(
          'Établissements', Icons.school, EtablissementListeScreen()),
      if (pourCepe)
        const _ItemMenu('Écoles d\'origine (CEPE)', Icons.home_work,
            EcoleOrigineCepeListeScreen())
      else
        const _ItemMenu('Écoles d\'origine (BEPC)', Icons.home_work,
            EcoleOrigineBepcListeScreen()),
      if (pourCepe)
        const _ItemMenu(
            'CEG d\'accueil', Icons.location_city, CegAccueilListeScreen())
      else
        const _ItemMenu(
            'Lycée d\'accueil', Icons.location_city, LyceeAccueilListeScreen()),
      if (pourCepe)
        const _ItemMenu('Centres d\'écrit (CEPE)', Icons.edit_document,
            CentreEcritCepeListeScreen())
      else
        const _ItemMenu('Centres d\'écrit (BEPC)', Icons.edit_document,
            CentreEcritBepcListeScreen()),
      if (pourCepe)
        const _ItemMenu('Centres de correction (CEPE)', Icons.fact_check,
            CentreCorrectionCepeListeScreen())
      else
        const _ItemMenu('Centres de correction (BEPC)', Icons.fact_check,
            CentreCorrectionBepcListeScreen()),
      if (pourCepe)
        const _ItemMenu(
            'Groupes (A, B, C)', Icons.groups, GroupeCepeListeScreen())
      else
        const _ItemMenu(
            'Groupes (I, II, III)', Icons.groups, GroupeBepcListeScreen()),
      const _ItemMenu('Langues', Icons.language, LangueListeScreen()),
      const _ItemMenu(
          'Types de handicap', Icons.accessible, TypeHandicapListeScreen()),
      const _ItemMenu('Sports collectifs', Icons.sports_soccer,
          SportCollectifListeScreen()),
      const _ItemMenu('Sports individuels', Icons.directions_run,
          SportIndividuelListeScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Listes — ${pourCepe ? 'CEPE' : 'BEPC'}')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          return ListTile(
            leading: Icon(item.icone, color: Colors.green),
            title: Text(item.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => item.ecran),
            ),
          );
        },
      ),
    );
  }
}

class _ItemMenu {
  final String label;
  final IconData icone;
  final Widget ecran;
  const _ItemMenu(this.label, this.icone, this.ecran);
}
