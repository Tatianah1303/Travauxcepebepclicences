import 'package:flutter/material.dart';

import '../../models/candidat_bepc.dart';
import '../../models/item_liste.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../data/liste_reference.dart';
import '../../utils/photo_helper.dart';
import '../../widgets/erreur_banniere.dart';
import '../../widgets/section_card.dart';
import '../../widgets/date_input_formatter.dart';
import '../../utils/verification_periode_saisie.dart';

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
  final _dateNaissanceController = TextEditingController();
  String _sexe = 'G'; // 'G' = Garçon (Masculin), 'F' = Fille (Féminin)
  bool _handicap = false;
  String? _typeHandicap;

  String _groupe = 'I';
  String? _langue;
  String? _codeEcoleOrigine;
  String? _codeLyceeAccueil;
  String? _codeCentreEcrit;
  String? _codeCentreCorrection;
  int _neeVert = 0;

  bool _eps = false;
  String? _epreuveAuChoix;
  String? _epreuveCollective;

  String? _photoPath;

  List<ItemListe> _ecolesOrigine = [];
  List<ItemListe> _lyceesAccueil = [];
  List<ItemListe> _centresEcrit = [];
  List<ItemListe> _centresCorrection = [];

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
    final centresEcrit = await SqliteService.instance.listerItems(
      'centreEcritBepc',
    );
    final centresCorrection = await SqliteService.instance.listerItems(
      'centreCorrectionBepc',
    );
    setState(() {
      _ecolesOrigine = ecoles;
      _lyceesAccueil = lycees;
      _centresEcrit = centresEcrit;
      _centresCorrection = centresCorrection;
    });
  }

  Future<void> _prendrePhoto() async {
    final path = await prendrePhotoOuChoisirFichier();
    if (path != null) setState(() => _photoPath = path);
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
    if (!await saisieAutorisee(context)) return;
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

    // "Née vers" : si -1, l'année de naissance saisie est décalée d'un an
    // en arrière dans la base (ex: saisi 2024 + "-1" => 2023 enregistré).
    final dateNaissanceAjustee = DateTime(
      _dateNaissance!.year + _neeVert,
      _dateNaissance!.month,
      _dateNaissance!.day,
    );

    final candidat = CandidatBepc(
      codeCandidat: 'BEPC_${now.millisecondsSinceEpoch}',
      numero: candidats.length + 1,
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      lieuNaissance: _lieuNaissanceController.text.trim(),
      adresseActuelle: _adresseController.text.trim(),
      dateNaissance: dateNaissanceAjustee,
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
      codeCentreEcrit: _codeCentreEcrit,
      codeCentreCorrection: _codeCentreCorrection,
      eps: _eps,
      epreuveObligatoire: _eps ? epreuveObligatoireSelonSexe(_sexe) : null,
      epreuveAuChoix: _eps ? _epreuveAuChoix : null,
      epreuveCollective: _eps ? _epreuveCollective : null,
      photo: _photoPath!,
      etatCandidat: 'Inscrit',
      anneeSession: now.year,
    );

    await SqliteService.instance.insererCandidatBepc(candidat);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Candidat "${candidat.nom} ${candidat.prenom}" enregistré'),
        backgroundColor: Colors.green,
      ),
    );

    // Le formulaire reste ouvert et les centres (écrit/correction) restent
    // sélectionnés car on inscrit en général plusieurs candidats du même
    // centre à la suite. Seuls les champs propres au candidat sont vidés.
    _formKey.currentState!.reset();
    _nomController.clear();
    _prenomController.clear();
    _lieuNaissanceController.clear();
    _adresseController.clear();
    _nomPereController.clear();
    _nomMereController.clear();
    _numeroAnneePrecedenteController.clear();
    _dateNaissanceController.clear();
    setState(() {
      _dateNaissance = null;
      _sexe = 'G';
      _handicap = false;
      _typeHandicap = null;
      _neeVert = 0;
      _eps = false;
      _epreuveAuChoix = null;
      _epreuveCollective = null;
      _photoPath = null;
      _enregistrement = false;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
            const SizedBox(height: 8),

            SectionCard(
              titre: 'Centres',
              icone: Icons.apartment,
              enfants: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _codeCentreEcrit,
                        decoration: const InputDecoration(
                          labelText: 'Centre d’écrit *',
                          border: OutlineInputBorder(),
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (v) => v == null ? 'Obligatoire' : null,
                        onChanged: (v) =>
                            setState(() => _codeCentreEcrit = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _codeCentreCorrection,
                        decoration: const InputDecoration(
                          labelText: 'Centre de correction *',
                          border: OutlineInputBorder(),
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (v) => v == null ? 'Obligatoire' : null,
                        onChanged: (v) =>
                            setState(() => _codeCentreCorrection = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SectionCard(
              titre: 'Identité du candidat',
              icone: Icons.badge,
              enfants: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _prenomController,
                        decoration: const InputDecoration(
                          labelText: 'Prénom *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateNaissanceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [DateInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Date de naissance *',
                          hintText: 'jj/mm/aaaa',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null ||
                                !RegExp(
                                  r'^\d{2}/\d{2}/\d{4}$',
                                ).hasMatch(v.trim()))
                            ? 'Format jj/mm/aaaa'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Née vers *',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('0')),
                              ButtonSegment(value: -1, label: Text('-1')),
                            ],
                            selected: {_neeVert},
                            onSelectionChanged: (v) =>
                                setState(() => _neeVert = v.first),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _lieuNaissanceController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu de naissance *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                TextFormField(
                  controller: _adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse actuelle *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                Text('Sexe *', style: TextStyle(color: Colors.grey.shade700)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Garçon'),
                        value: 'G',
                        groupValue: _sexe,
                        onChanged: (v) => setState(() => _sexe = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fille'),
                        value: 'F',
                        groupValue: _sexe,
                        onChanged: (v) => setState(() => _sexe = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SectionCard(
              titre: 'Filiation',
              icone: Icons.family_restroom,
              enfants: [
                TextFormField(
                  controller: _nomPereController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du père (facultatif)',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _nomMereController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la mère *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
              ],
            ),

            SectionCard(
              titre: 'Handicap',
              icone: Icons.accessible,
              enfants: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
                      border: OutlineInputBorder(),
                    ),
                    items: typesHandicap
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _typeHandicap = v),
                  ),
              ],
            ),

            SectionCard(
              titre: 'Examen',
              icone: Icons.school,
              enfants: [
                DropdownButtonFormField<String>(
                  value: _groupe,
                  decoration: const InputDecoration(
                    labelText: 'Groupe *',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['I', 'II', 'III']
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('Groupe $g'),
                        ),
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
                      border: OutlineInputBorder(),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  value: _langue,
                  decoration: InputDecoration(
                    labelText: _langueActive ? 'Langue *' : 'Langue',
                    border: const OutlineInputBorder(),
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
                    border: OutlineInputBorder(),
                  ),
                  items: _ecolesOrigine
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.champs['code'],
                          child: Text(
                            e.champs['nom'] ?? e.champs['code'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                    border: const OutlineInputBorder(),
                  ),
                  items: _lyceesAccueil
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.champs['code'],
                          child: Text(
                            l.champs['libelle'] ?? l.champs['code'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _lyceeAccueilActif
                      ? (v) => setState(() => _codeLyceeAccueil = v)
                      : null,
                ),
              ],
            ),

            SectionCard(
              titre: 'EPS (Éducation Physique et Sportive)',
              icone: Icons.sports_soccer,
              enfants: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Candidat inscrit en EPS'),
                  subtitle: _handicap
                      ? const Text('Verrouillé (candidat handicapé)')
                      : null,
                  value: _eps,
                  onChanged: _handicap
                      ? null
                      : (v) => setState(() => _eps = v),
                ),
                if (_eps) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Épreuve obligatoire (auto)'),
                    subtitle: Text(epreuveObligatoireSelonSexe(_sexe)),
                  ),
                  DropdownButtonFormField<String>(
                    value: _epreuveAuChoix,
                    decoration: const InputDecoration(
                      labelText: 'Épreuve au choix *',
                      border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
                    ),
                    items: sportsCollectifsEps
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _epreuveCollective = v),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _enregistrement ? null : _enregistrer,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _enregistrement
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enregistrer le candidat'),
            ),
          ],
        ),
      ),
    );
  }
}
