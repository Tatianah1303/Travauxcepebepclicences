import 'package:flutter/material.dart';
import '../../models/candidat_cepe.dart';
import '../../models/candidat_bepc.dart';
import '../../models/enseignant.dart';
import '../../models/membre_previsionnel.dart';
import '../../models/quota_membre.dart';
import '../../services/firestore_service.dart';
import '../../services/listes_locales.dart';
import '../../utils/photo_helper.dart';

/// « Voir les listes » (administrateur) : candidats CEPE/BEPC et membres,
/// présentés en TABLEAUX avec des filtres.
///  - Candidats : filtre par centre d'écrit.
///  - Membres  : filtre par rôle, puis par centre d'écrit.
class ListesAdminScreen extends StatefulWidget {
  const ListesAdminScreen({super.key});
  @override
  State<ListesAdminScreen> createState() => _ListesAdminScreenState();
}

class _ListesAdminScreenState extends State<ListesAdminScreen> {
  static const _tous = '__tous__';
  static const _sans = '__sans__';

  bool loading = true;
  List<CandidatCepe> cepe = [];
  List<CandidatBepc> bepc = [];
  List<MembrePrevisionnel> membres = [];
  List<Enseignant> enseignants = [];
  Map<String, String> etablissements = {};
  Map<String, String> centres = {};

  // Filtres (par onglet)
  String _centreCepe = _tous;
  String _centreBepc = _tous;
  final Map<String, String> _roleMembre = {'CEPE': _tous, 'BEPC': _tous};
  final Map<String, String> _centreMembre = {'CEPE': _tous, 'BEPC': _tous};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = FirestoreService.instance;
    final ce = await fs.listerTousCandidatsCepe();
    final be = await fs.listerTousCandidatsBepc();
    final ms = await fs.listerTousMembres();
    final es = await fs.listerTousEnseignants();

    final refs = await Future.wait([
      ListesLocales.charger('etablissement'),
      ListesLocales.charger('centreEcritCepe'),
      ListesLocales.charger('centreCorrectionCepe'),
      ListesLocales.charger('centreEcritBepc'),
      ListesLocales.charger('centreCorrectionBepc'),
    ]);
    final etabMap = {
      for (final e in refs[0])
        if (e.champs['code'] != null)
          e.champs['code']!: e.champs['nom'] ?? e.champs['code']!,
    };
    final centresMap = <String, String>{};
    for (final liste in refs.skip(1)) {
      for (final c in liste) {
        final code = c.champs['code'];
        if (code != null) {
          centresMap[code] = c.champs['libelle'] ?? c.champs['nom'] ?? code;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      cepe = ce;
      bepc = be;
      membres = ms;
      enseignants = es;
      etablissements = etabMap;
      centres = centresMap;
      // Par défaut : le premier centre (un tableau plus léger à afficher).
      final cc = _codesCentres(ce.map((c) => c.codeCentreEcrit));
      final cb = _codesCentres(be.map((c) => c.codeCentreEcrit));
      if (cc.isNotEmpty) _centreCepe = cc.first;
      if (cb.isNotEmpty) _centreBepc = cb.first;
      loading = false;
    });
  }

  String etab(String c) => etablissements[c] ?? c;
  String centre(String? c) => c == null || c.isEmpty ? '-' : (centres[c] ?? c);

  /// Codes de centres distincts, triés par libellé.
  List<String> _codesCentres(Iterable<String?> codes) {
    final liste = codes
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    liste.sort((a, b) => centre(a).compareTo(centre(b)));
    return liste;
  }

  bool _correspondCentre(String filtre, String? code) {
    if (filtre == _tous) return true;
    if (filtre == _sans) return code == null || code.isEmpty;
    return code == filtre;
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Enseignant? _enseignantDe(String matricule) {
    String n(String v) => v.trim().replaceFirst(RegExp(r'^0+'), '');
    for (final e in enseignants) {
      if (e.matricule == matricule) return e;
    }
    for (final e in enseignants) {
      if (n(e.matricule) == n(matricule)) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('Listes complètes'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'CEPE'),
              Tab(text: 'BEPC'),
              Tab(text: 'Membres CEPE'),
              Tab(text: 'Membres BEPC'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _candidatsCepe(),
            _candidatsBepc(),
            _membres('CEPE'),
            _membres('BEPC'),
          ],
        ),
      ),
    );
  }

  // ── Briques communes ──────────────────────────────────────────────────

  Widget _filtre({
    required String label,
    required IconData icone,
    required String valeur,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label|$valeur'),
        isExpanded: true,
        value: valeur,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icone),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
        items: items,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  List<DropdownMenuItem<String>> _itemsCentres(
    Iterable<String?> codes, {
    required String libelleTous,
  }) {
    return [
      DropdownMenuItem(value: _tous, child: Text(libelleTous)),
      const DropdownMenuItem(value: _sans, child: Text('Sans centre')),
      for (final c in _codesCentres(codes))
        DropdownMenuItem(
          value: c,
          child: Text(centre(c), overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  Widget _compteur(int n, String singulier) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$n $singulier${n > 1 ? 's' : ''}',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _carteVide(String message) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
    ),
  );

  DataCell _c(String texte) => DataCell(Text(texte));

  /// Tableau défilant horizontalement et verticalement.
  Widget _tableau({
    required List<String> entetes,
    required List<DataRow> lignes,
    required Color couleurEntete,
  }) {
    if (lignes.isEmpty) return _carteVide('Aucun résultat pour ce filtre');
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(couleurEntete),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
              columnSpacing: 22,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 52,
              columns: [for (final e in entetes) DataColumn(label: Text(e))],
              rows: lignes,
            ),
          ),
        ),
      ),
    );
  }

  // ── Candidats ─────────────────────────────────────────────────────────

  Widget _candidatsCepe() {
    if (cepe.isEmpty) return _carteVide('Aucun candidat CEPE');
    final filtres =
        cepe
            .where((c) => _correspondCentre(_centreCepe, c.codeCentreEcrit))
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));
    return Column(
      children: [
        _filtre(
          label: 'Filtrer par centre d\'écrit',
          icone: Icons.location_city,
          valeur: _centreCepe,
          items: _itemsCentres(
            cepe.map((c) => c.codeCentreEcrit),
            libelleTous: 'Tous les centres',
          ),
          onChanged: (v) => setState(() => _centreCepe = v),
        ),
        _compteur(filtres.length, 'candidat'),
        _tableau(
          couleurEntete: Colors.blue.shade50,
          entetes: const [
            'N°',
            'NOM',
            'PRÉNOM',
            'SEXE',
            'NÉ(E) LE',
            'LIEU DE NAISSANCE',
            'ÉTABLISSEMENT',
            'ÉCOLE D\'ORIGINE',
            'GROUPE',
            'CENTRE D\'ÉCRIT',
            'CENTRE DE CORRECTION',
          ],
          lignes: [
            for (final c in filtres)
              DataRow(
                cells: [
                  _c('${c.numero}'),
                  _c(c.nom),
                  _c(c.prenom),
                  _c(c.sexe == 'F' ? 'F' : 'G'),
                  _c(_date(c.dateNaissance)),
                  _c(c.lieuNaissance),
                  _c(etab(c.codeEtab)),
                  _c(c.codeEcoleOrigine),
                  _c(c.groupe),
                  _c(centre(c.codeCentreEcrit)),
                  _c(centre(c.codeCentreCorrection)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _candidatsBepc() {
    if (bepc.isEmpty) return _carteVide('Aucun candidat BEPC');
    final filtres =
        bepc
            .where((c) => _correspondCentre(_centreBepc, c.codeCentreEcrit))
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));
    return Column(
      children: [
        _filtre(
          label: 'Filtrer par centre d\'écrit',
          icone: Icons.location_city,
          valeur: _centreBepc,
          items: _itemsCentres(
            bepc.map((c) => c.codeCentreEcrit),
            libelleTous: 'Tous les centres',
          ),
          onChanged: (v) => setState(() => _centreBepc = v),
        ),
        _compteur(filtres.length, 'candidat'),
        _tableau(
          couleurEntete: Colors.teal.shade50,
          entetes: const [
            'N°',
            'NOM',
            'PRÉNOM',
            'SEXE',
            'NÉ(E) LE',
            'LIEU DE NAISSANCE',
            'ÉTABLISSEMENT',
            'ÉCOLE D\'ORIGINE',
            'GROUPE',
            'LANGUE',
            'CENTRE D\'ÉCRIT',
            'CENTRE DE CORRECTION',
          ],
          lignes: [
            for (final c in filtres)
              DataRow(
                cells: [
                  _c('${c.numero}'),
                  _c(c.nom),
                  _c(c.prenom),
                  _c(c.sexe == 'F' ? 'F' : 'G'),
                  _c(_date(c.dateNaissance)),
                  _c(c.lieuNaissance),
                  _c(etab(c.codeEtab)),
                  _c(c.codeEcoleOrigine),
                  _c(c.groupe),
                  _c(c.langue ?? '-'),
                  _c(centre(c.codeCentreEcrit)),
                  _c(centre(c.codeCentreCorrection)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ── Membres ───────────────────────────────────────────────────────────

  Widget _miniatureCin(String? photo) {
    final image = imageDepuisPhoto(photo);
    return Container(
      width: 52,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: image == null
          ? const Icon(Icons.badge_outlined, size: 18, color: Colors.grey)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 18),
              ),
            ),
    );
  }

  Widget _grandeCin(String label, String? photo) {
    final image = imageDepuisPhoto(photo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        if (image == null)
          Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Aucune photo'),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image(
              image: image,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image)),
            ),
          ),
      ],
    );
  }

  void _voirCin(String nom, MembrePrevisionnel m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _grandeCin('CIN — recto', m.photoCinRecto),
              const SizedBox(height: 12),
              _grandeCin('CIN — verso', m.photoCinVerso),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Attribution = rôle + centre d'écrit (+ centre de correction s'il existe).
  String _attribution(MembrePrevisionnel m) {
    final ecrit = (m.codeCentreEcrit == null || m.codeCentreEcrit!.isEmpty)
        ? null
        : centre(m.codeCentreEcrit);
    final corr =
        (m.codeCentreCorrection == null || m.codeCentreCorrection!.isEmpty)
        ? null
        : centre(m.codeCentreCorrection);
    final parties = <String>[libelleRole(m.role)];
    if (ecrit != null) parties.add('Écrit : $ecrit');
    if (corr != null) parties.add('Correction : $corr');
    return parties.join(' — ');
  }

  Widget _membres(String typeExamen) {
    final membresType = membres
        .where((m) => m.typeExamen == typeExamen)
        .toList();
    if (membresType.isEmpty) {
      return _carteVide('Aucun membre prévisionnel $typeExamen');
    }

    final role = _roleMembre[typeExamen]!;
    final centreChoisi = _centreMembre[typeExamen]!;

    final rolesPresents = membresType.map((m) => m.role).toSet();
    final rolesTries = [
      ...rolesMembre.where(rolesPresents.contains),
      ...rolesPresents.where((r) => !rolesMembre.contains(r)),
    ];

    final filtres = membresType.where((m) {
      final roleOk = role == _tous || m.role == role;
      return roleOk && _correspondCentre(centreChoisi, m.codeCentreEcrit);
    }).toList();

    String nomDe(MembrePrevisionnel m) =>
        m.nom ?? _enseignantDe(m.matriculeEnseignant)?.nom ?? '';
    filtres.sort((a, b) => nomDe(a).compareTo(nomDe(b)));

    return Column(
      children: [
        _filtre(
          label: 'Filtrer par rôle',
          icone: Icons.badge,
          valeur: role,
          items: [
            const DropdownMenuItem(value: _tous, child: Text('Tous les rôles')),
            for (final r in rolesTries)
              DropdownMenuItem(value: r, child: Text(libelleRole(r))),
          ],
          onChanged: (v) => setState(() => _roleMembre[typeExamen] = v),
        ),
        _filtre(
          label: 'Filtrer par centre d\'écrit',
          icone: Icons.location_city,
          valeur: centreChoisi,
          items: _itemsCentres(
            membresType.map((m) => m.codeCentreEcrit),
            libelleTous: 'Tous les centres',
          ),
          onChanged: (v) => setState(() => _centreMembre[typeExamen] = v),
        ),
        _compteur(filtres.length, 'membre'),
        _tableau(
          couleurEntete: Colors.purple.shade50,
          entetes: const [
            'NOM',
            'PRÉNOM',
            'ÉTABLISSEMENT',
            'LOCALITÉ DE TRAVAIL',
            'ATTRIBUTION',
            'CIN',
          ],
          lignes: [
            for (final m in filtres)
              () {
                final e = _enseignantDe(m.matriculeEnseignant);
                final nom = m.nom ?? e?.nom ?? '-';
                final prenom = m.prenom ?? e?.prenom ?? '-';
                final localite = m.localite ?? e?.adresse ?? '-';
                final codeEtab = m.codeEtab ?? e?.codeEtab;
                return DataRow(
                  cells: [
                    _c(nom),
                    _c(prenom),
                    _c(codeEtab == null ? '-' : etab(codeEtab)),
                    _c(localite),
                    _c(_attribution(m)),
                    DataCell(
                      _miniatureCin(m.photoCinRecto),
                      onTap: () =>
                          _voirCin(nom == '-' ? 'Membre' : '$nom $prenom', m),
                    ),
                  ],
                );
              }(),
          ],
        ),
      ],
    );
  }
}
