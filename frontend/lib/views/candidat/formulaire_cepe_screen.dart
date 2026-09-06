import 'package:flutter/material.dart';

import '../../models/candidat_cepe.dart';
import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../data/liste_reference.dart';
import '../../utils/photo_helper.dart';
import '../../widgets/erreur_banniere.dart';

/// Formulaire d'inscription d'un candidat CEPE.
///
/// Règles appliquées (voir modèle CandidatCepe pour le détail) :
/// - groupe A/B/C obligatoire
/// - CEG d'accueil actif seulement si groupe = A ou B
/// - handicap = Oui -> type de handicap actif
/// - nomPere facultatif, tout le reste obligatoire
class FormulaireCepeScreen extends StatefulWidget {
  const FormulaireCepeScreen({super.key});

  @override
  State<FormulaireCepeScreen> createState() => _FormulaireCepeScreenState();
}

class _FormulaireCepeScreenState extends State<FormulaireCepeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  String? _messageErreur;

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _lieuNaissanceController = TextEditingController();
  final _adresseController = TextEditingController();
  final _nomPereController = TextEditingController();
  final _nomMereController = TextEditingController();

  DateTime? _dateNaissance;
  final _dateNaissanceController = TextEditingController();
  String _sexe = 'G'; // 'G' = Garçon (Masculin), 'F' = Fille (Féminin)
  int _neeVert = 0;
  bool _handicap = false;
  String? _typeHandicap;

  String _groupe = 'A';
  String? _codeEcoleOrigine;
  String? _codeCegAccueil;
  String? _codeCentreEcrit;
  String? _codeCentreCorrection;

  String? _photoPath;

  List<ItemListe> _ecolesOrigine = [];
  List<ItemListe> _cegAccueils = [];
  List<ItemListe> _centresEcrit = [];
  List<ItemListe> _centresCorrection = [];

  bool _enregistrement = false;

  bool get _cegAccueilActif => _groupe == 'A' || _groupe == 'B';

  @override
  void initState() {
    super.initState();
    _chargerListes();
  }

  Future<void> _chargerListes() async {
    final ecoles = await SqliteService.instance.listerItems('ecoleOrigineCepe');
    final ceg = await SqliteService.instance.listerItems('cegAccueil');
    final centresEcrit = await SqliteService.instance.listerItems(
      'centreEcritCepe',
    );
    final centresCorrection = await SqliteService.instance.listerItems(
      'centreCorrectionCepe',
    );
    setState(() {
      _ecolesOrigine = ecoles;
      _cegAccueils = ceg;
      _centresEcrit = centresEcrit;
      _centresCorrection = centresCorrection;
    });
  }

  Future<void> _prendrePhoto() async {
    final path = await prendrePhotoOuChoisirFichier();
    if (path != null) {
      setState(() => _photoPath = path);
    }
  }

  void _lireDateNaissance(String v) {
    final p = v.trim().split('/');
    if (p.length == 3) {
      final d = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final y = int.tryParse(p[2]);
      if (d != null && m != null && y != null)
        _dateNaissance = DateTime(y, m, d);
    }
  }

  Future<void> _enregistrer() async {
    setState(() => _messageErreur = null);
    if (!_formKey.currentState!.validate()) {
      _erreur('Vérifiez les champs en rouge ci-dessous');
      return;
    }
    _lireDateNaissance(_dateNaissanceController.text);
    if (_dateNaissance == null) {
      _erreur('Saisissez la date au format jj/mm/aaaa');
      return;
    }
    if (_codeCentreEcrit == null || _codeCentreCorrection == null) {
      _erreur('Les centres d’écrit et de correction sont obligatoires');
      return;
    }
    if (_codeEcoleOrigine == null) {
      _erreur('Choisissez l\'école d\'origine');
      return;
    }
    if (_handicap && _typeHandicap == null) {
      _erreur('Choisissez le type de handicap');
      return;
    }
    if (_photoPath == null) {
      _erreur('Prenez une photo du candidat');
      return;
    }
    if (_nomMereController.text.trim().isEmpty) {
      _erreur('Le nom de la mère est obligatoire');
      return;
    }
    if (_lieuNaissanceController.text.trim().isEmpty) {
      _erreur('Le lieu de naissance est obligatoire');
      return;
    }

    setState(() => _enregistrement = true);

    final now = DateTime.now();
    final candidats = await SqliteService.instance.listerCandidatsCepe(
      anneeSession: now.year,
    );

    final candidat = CandidatCepe(
      codeCandidat: 'CEPE_${now.millisecondsSinceEpoch}',
      numero: candidats.length + 1,
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      lieuNaissance: _lieuNaissanceController.text.trim(),
      adresseActuelle: _adresseController.text.trim(),
      dateNaissance: _dateNaissance!,
      sexe: _sexe,
      handicap: _handicap,
      typeHandicap: _handicap ? _typeHandicap : null,
      nomPere: _nomPereController.text.trim().isEmpty
          ? null
          : _nomPereController.text.trim(),
      nomMere: _nomMereController.text.trim(),
      groupe: _groupe,
      langue: null,
      neeVert: _neeVert,
      codeEcoleOrigine: _codeEcoleOrigine!,
      codeCegAccueil: _cegAccueilActif ? _codeCegAccueil : null,
      codeEtab: AppSession.instance.codeEtab ?? '',
      codeCentreEcrit: _codeCentreEcrit,
      codeCentreCorrection: _codeCentreCorrection,
      eps: false,
      photo: _photoPath!,
      etatCandidat: 'Inscrit',
      anneeSession: now.year,
    );

    await SqliteService.instance.insererCandidatCepe(candidat);

    setState(() => _enregistrement = false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Candidat CEPE enregistré')));
    Navigator.of(context).pop();
  }

  void _erreur(String message) {
    setState(() => _messageErreur = message);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscrire un candidat — CEPE')),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            ErreurBanniere(
              message: _messageErreur,
              onFermer: () => setState(() => _messageErreur = null),
            ),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey[300],
                    child: _photoPath == null
                        ? const Icon(Icons.person, size: 45)
                        : const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 40,
                          ),
                  ),
                  TextButton.icon(
                    onPressed: _prendrePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _photoPath == null
                          ? 'Prendre une photo *'
                          : 'Reprendre la photo',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _codeCentreEcrit,
                    decoration: const InputDecoration(
                      labelText: 'Centre d’écrit *',
                    ),
                    items: _centresEcrit
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.champs['code'],
                            child: Text(
                              c.champs['libelle'] ??
                                  c.champs['nom'] ??
                                  c.champs['code'] ??
                                  '',
                            ),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? 'Obligatoire' : null,
                    onChanged: (v) => setState(() => _codeCentreEcrit = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _codeCentreCorrection,
                    decoration: const InputDecoration(
                      labelText: 'Centre de correction *',
                    ),
                    items: _centresCorrection
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.champs['code'],
                            child: Text(
                              c.champs['libelle'] ??
                                  c.champs['nom'] ??
                                  c.champs['code'] ??
                                  '',
                            ),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? 'Obligatoire' : null,
                    onChanged: (v) => setState(() => _codeCentreCorrection = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(labelText: 'Nom *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prenomController,
                    decoration: const InputDecoration(labelText: 'Prénom *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _lieuNaissanceController,
              decoration: const InputDecoration(
                labelText: 'Lieu de naissance *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            TextFormField(
              controller: _adresseController,
              decoration: const InputDecoration(
                labelText: 'Adresse actuelle *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            TextFormField(
              controller: _nomPereController,
              decoration: const InputDecoration(
                labelText: 'Nom du père (facultatif)',
              ),
            ),
            TextFormField(
              controller: _nomMereController,
              decoration: const InputDecoration(labelText: 'Nom de la mère *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateNaissanceController,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance *',
                      hintText: 'jj/mm/aaaa',
                    ),
                    validator: (v) =>
                        (v == null ||
                            !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v.trim()))
                        ? 'Format attendu jj/mm/aaaa'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _neeVert,
                    decoration: const InputDecoration(labelText: 'Née vert *'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('0')),
                      DropdownMenuItem(value: -1, child: Text('-1')),
                    ],
                    validator: (v) => v == null ? 'Obligatoire' : null,
                    onChanged: (v) => setState(() => _neeVert = v ?? 0),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Text('Sexe *'),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Garçon'),
                    value: 'G',
                    groupValue: _sexe,
                    onChanged: (v) => setState(() => _sexe = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Fille'),
                    value: 'F',
                    groupValue: _sexe,
                    onChanged: (v) => setState(() => _sexe = v!),
                  ),
                ),
              ],
            ),

            SwitchListTile(
              title: const Text('Candidat en situation de handicap'),
              value: _handicap,
              onChanged: (v) => setState(() {
                _handicap = v;
                if (!v) _typeHandicap = null;
              }),
            ),
            if (_handicap)
              DropdownButtonFormField<String>(
                value: _typeHandicap,
                decoration: const InputDecoration(
                  labelText: 'Type de handicap *',
                ),
                items: typesHandicap
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _typeHandicap = v),
              ),

            const Divider(),
            const Text('Examen', style: TextStyle(fontWeight: FontWeight.bold)),

            DropdownButtonFormField<String>(
              value: _groupe,
              decoration: const InputDecoration(labelText: 'Groupe *'),
              items: const ['A', 'B', 'C']
                  .map(
                    (g) => DropdownMenuItem(value: g, child: Text('Groupe $g')),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _groupe = v!;
                if (!_cegAccueilActif) _codeCegAccueil = null;
              }),
            ),

            DropdownButtonFormField<String>(
              value: _codeEcoleOrigine,
              decoration: const InputDecoration(
                labelText: 'École d\'origine *',
              ),
              items: _ecolesOrigine
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.champs['code'],
                      child: Text(e.champs['nom'] ?? e.champs['code'] ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _codeEcoleOrigine = v),
            ),

            DropdownButtonFormField<String>(
              value: _codeCegAccueil,
              decoration: InputDecoration(
                labelText: _cegAccueilActif
                    ? 'CEG d\'accueil *'
                    : 'CEG d\'accueil',
              ),
              items: _cegAccueils
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.champs['code'],
                      child: Text(
                        c.champs['libelle'] ?? c.champs['code'] ?? '',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _cegAccueilActif
                  ? (v) => setState(() => _codeCegAccueil = v)
                  : null,
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enregistrement ? null : _enregistrer,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _enregistrement
                  ? const CircularProgressIndicator()
                  : const Text('Enregistrer le candidat'),
            ),
          ],
        ),
      ),
    );
  }
}
