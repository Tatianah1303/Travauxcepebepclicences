import 'package:flutter/material.dart';

import '../../models/candidat_bepc.dart';
import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../data/liste_reference.dart';
import '../../utils/photo_helper.dart';
import '../../widgets/erreur_banniere.dart';

/// Formulaire d'inscription d'un candidat BEPC.
///
/// Différences avec le CEPE :
/// - groupe I/II/III (au lieu de A/B/C)
/// - Lycée d'accueil (au lieu de CEG d'accueil), actif si groupe = I ou II
/// - langue active seulement si groupe = I
/// - groupe = III -> numéro d'inscription BEPC de l'année précédente requis
/// - champ neeVert (0 = pas de copie, 1 = a une copie), toujours affiché
class FormulaireBepcScreen extends StatefulWidget {
  const FormulaireBepcScreen({super.key});

  @override
  State<FormulaireBepcScreen> createState() => _FormulaireBepcScreenState();
}

class _FormulaireBepcScreenState extends State<FormulaireBepcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  String? _messageErreur;

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _lieuNaissanceController = TextEditingController();
  final _adresseController = TextEditingController();
  final _nomPereController = TextEditingController();
  final _nomMereController = TextEditingController();
  final _numeroAnneePrecedenteController = TextEditingController();

  DateTime? _dateNaissance;
  String _sexe = 'G'; // 'G' = Garçon (Masculin), 'F' = Fille (Féminin)
  bool _handicap = false;
  String? _typeHandicap;

  String _groupe = 'I';
  String? _langue;
  String? _codeEcoleOrigine;
  String? _codeLyceeAccueil;
  int _neeVert = 0;

  bool _eps = false;
  String? _epreuveAuChoix;
  String? _epreuveCollective;

  String? _photoPath;

  List<ItemListe> _ecolesOrigine = [];
  List<ItemListe> _lyceesAccueil = [];

  bool _enregistrement = false;

  bool get _langueActive => _groupe == 'I';
  bool get _lyceeAccueilActif => _groupe == 'I' || _groupe == 'II';
  bool get _groupeIII => _groupe == 'III';

  @override
  void initState() {
    super.initState();
    _chargerListes();
  }

  Future<void> _chargerListes() async {
    final ecoles = await SqliteService.instance.listerItems('ecoleOrigineBepc');
    final lycees = await SqliteService.instance.listerItems('lyceeAccueil');
    setState(() {
      _ecolesOrigine = ecoles;
      _lyceesAccueil = lycees;
    });
  }

  Future<void> _prendrePhoto() async {
    final path = await prendrePhotoOuChoisirFichier();
    if (path != null) setState(() => _photoPath = path);
  }

  Future<void> _choisirDateNaissance() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2011, 1, 1),
      firstDate: DateTime(1998),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _dateNaissance = date);
  }

  Future<void> _enregistrer() async {
    setState(() => _messageErreur = null);
    if (!_formKey.currentState!.validate()) {
      _erreur('Vérifiez les champs en rouge ci-dessous');
      return;
    }
    if (_dateNaissance == null) {
      _erreur('Choisissez la date de naissance');
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
    if (_langueActive && _langue == null) {
      _erreur('Choisissez la langue (obligatoire pour le groupe I)');
      return;
    }
    if (_groupeIII && _numeroAnneePrecedenteController.text.trim().isEmpty) {
      _erreur(
        'Numéro d\'inscription BEPC de l\'année précédente obligatoire (groupe III)',
      );
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
    final candidats = await SqliteService.instance.listerCandidatsBepc(
      anneeSession: now.year,
    );

    final candidat = CandidatBepc(
      codeCandidat: 'BEPC_${now.millisecondsSinceEpoch}',
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
      langue: _langueActive ? _langue : null,
      numeroInscriptionAnneePrecedente: _groupeIII
          ? _numeroAnneePrecedenteController.text.trim()
          : null,
      neeVert: _neeVert,
      codeEcoleOrigine: _codeEcoleOrigine!,
      codeLyceeAccueil: _lyceeAccueilActif ? _codeLyceeAccueil : null,
      codeEtab: AppSession.instance.codeEtab ?? '',
      eps: _eps,
      epreuveObligatoire: _eps ? epreuveObligatoireSelonSexe(_sexe) : null,
      epreuveAuChoix: _eps ? _epreuveAuChoix : null,
      epreuveCollective: _eps ? _epreuveCollective : null,
      photo: _photoPath!,
      etatCandidat: 'Inscrit',
      anneeSession: now.year,
    );

    await SqliteService.instance.insererCandidatBepc(candidat);

    setState(() => _enregistrement = false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Candidat BEPC enregistré')));
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
      appBar: AppBar(title: const Text('Inscrire un candidat — BEPC')),
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

            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(labelText: 'Nom *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            TextFormField(
              controller: _prenomController,
              decoration: const InputDecoration(labelText: 'Prénom *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
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

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dateNaissance == null
                    ? 'Date de naissance *'
                    : 'Naissance : ${_dateNaissance!.day}/${_dateNaissance!.month}/${_dateNaissance!.year}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: _choisirDateNaissance,
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
              title: const Text('Le candidat a une copie (neeVert)'),
              subtitle: Text(_neeVert == 1 ? 'Oui (1)' : 'Non (0)'),
              value: _neeVert == 1,
              onChanged: (v) => setState(() => _neeVert = v ? 1 : 0),
            ),

            SwitchListTile(
              title: const Text('Candidat en situation de handicap'),
              value: _handicap,
              onChanged: (v) => setState(() {
                _handicap = v;
                if (v) {
                  _eps = false;
                  _epreuveAuChoix = null;
                  _epreuveCollective = null;
                } else {
                  _typeHandicap = null;
                }
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
              items: const ['I', 'II', 'III']
                  .map(
                    (g) => DropdownMenuItem(value: g, child: Text('Groupe $g')),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _groupe = v!;
                if (!_langueActive) _langue = null;
                if (!_lyceeAccueilActif) _codeLyceeAccueil = null;
                if (!_groupeIII) _numeroAnneePrecedenteController.clear();
              }),
            ),

            if (_groupeIII)
              TextFormField(
                controller: _numeroAnneePrecedenteController,
                decoration: const InputDecoration(
                  labelText: 'N° inscription BEPC année précédente *',
                ),
              ),

            DropdownButtonFormField<String>(
              value: _langue,
              decoration: InputDecoration(
                labelText: _langueActive ? 'Langue *' : 'Langue',
              ),
              items: langues
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: _langueActive
                  ? (v) => setState(() => _langue = v)
                  : null,
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
              value: _codeLyceeAccueil,
              decoration: InputDecoration(
                labelText: _lyceeAccueilActif
                    ? 'Lycée d\'accueil *'
                    : 'Lycée d\'accueil',
              ),
              items: _lyceesAccueil
                  .map(
                    (l) => DropdownMenuItem(
                      value: l.champs['code'],
                      child: Text(
                        l.champs['libelle'] ?? l.champs['code'] ?? '',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _lyceeAccueilActif
                  ? (v) => setState(() => _codeLyceeAccueil = v)
                  : null,
            ),

            const Divider(),
            SwitchListTile(
              title: const Text('EPS (Éducation Physique et Sportive)'),
              subtitle: _handicap
                  ? const Text('Verrouillé (candidat handicapé)')
                  : null,
              value: _eps,
              onChanged: _handicap ? null : (v) => setState(() => _eps = v),
            ),
            if (_eps) ...[
              ListTile(
                title: const Text('Épreuve obligatoire (auto)'),
                subtitle: Text(epreuveObligatoireSelonSexe(_sexe)),
              ),
              DropdownButtonFormField<String>(
                value: _epreuveAuChoix,
                decoration: const InputDecoration(
                  labelText: 'Épreuve au choix *',
                ),
                items: epreuvesAuChoixEps
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _epreuveAuChoix = v),
              ),
              DropdownButtonFormField<String>(
                value: _epreuveCollective,
                decoration: const InputDecoration(
                  labelText: 'Épreuve collective *',
                ),
                items: sportsCollectifsEps
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _epreuveCollective = v),
              ),
            ],

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
