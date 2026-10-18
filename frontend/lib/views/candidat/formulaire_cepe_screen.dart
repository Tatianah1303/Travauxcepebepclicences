import 'package:flutter/material.dart';

import '../../models/candidat_cepe.dart';
import '../../models/item_liste.dart';
import '../../services/firestore_service.dart';
import '../../services/firestore_listes_service.dart';
import '../../services/listes_locales.dart';
import '../../services/app_session.dart';
import '../../data/liste_reference.dart';
import '../../utils/photo_helper.dart';
import '../../services/firebase_storage_service.dart';
import '../../widgets/erreur_banniere.dart';
import '../../widgets/section_card.dart';
import '../../widgets/date_input_formatter.dart';
import '../../utils/verification_periode_saisie.dart';

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
  List<String> _groupes = ['A', 'B', 'C'];
  List<String> _typesHandicap = List.of(typesHandicap);

  bool _enregistrement = false;

  bool get _cegAccueilActif => _groupe == 'A' || _groupe == 'B';

  @override
  void initState() {
    super.initState();
    _chargerListes();
  }

  Future<void> _chargerListes() async {
    try {
      final remote = await Future.wait([
        ListesLocales.charger('ecoleOrigineCepe'),
        ListesLocales.charger('cegAccueil'),
        ListesLocales.charger('centreEcritCepe'),
        ListesLocales.charger('centreCorrectionCepe'),
        ListesLocales.charger('groupeCepe'),
        ListesLocales.charger('typeHandicap'),
      ]);
      if (!mounted) return;
      setState(() {
        _ecolesOrigine = remote[0];
        _cegAccueils = remote[1];
        _centresEcrit = remote[2];
        _centresCorrection = remote[3];
        final groupes = ListesLocales.sansDoublons(
          remote[4],
        ).map((e) => e.champs['code']!).toList()..sort();
        if (groupes.isNotEmpty) {
          _groupes = groupes;
          if (!groupes.contains(_groupe)) _groupe = groupes.first;
        }
        final handicaps =
            remote[5]
                .map((e) => e.champs['libelle'])
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        if (handicaps.isNotEmpty) {
          _typesHandicap = handicaps;
          if (!handicaps.contains(_typeHandicap)) _typeHandicap = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _messageErreur =
              'Impossible de charger les listes Firestore. Vérifiez la connexion et l’initialisation admin : $e',
        );
      }
    }
  }

  Future<void> _prendrePhoto() async {
    final path = await prendrePhotoOuChoisirFichier();
    if (path == null) return;
    if (!mounted) {
      await FirebaseStorageService.supprimerPhotoTemporaire(path);
      return;
    }
    final ancienne = _photoPath;
    if (ancienne != null) {
      await FirebaseStorageService.supprimerPhotoTemporaire(ancienne);
    }
    if (mounted) setState(() => _photoPath = path);
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
    final codeCandidat = 'CEPE_${now.millisecondsSinceEpoch}';
    final codeEtab = AppSession.instance.codeEtab ?? '';
    late final String photoUrl;
    try {
      photoUrl = await FirebaseStorageService.envoyerPhoto(
        cheminLocal: _photoPath!,
        cheminCloudSansExtension: 'candidats/$codeEtab/cepe/$codeCandidat',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistrement = false;
          _photoPath = null;
        });
        _erreur('Échec du traitement de la photo : $e');
      }
      return;
    }
    late final List<CandidatCepe> candidats;
    try {
      candidats = await FirestoreService.instance.listerCandidatsCepe(
        codeEtab: AppSession.instance.codeEtab ?? '',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistrement = false;
          _photoPath = null;
        });
        _erreur(
          'Impossible de lire Firestore pour le numéro du candidat : $e. Reprenez la photo avant de réessayer.',
        );
      }
      return;
    }

    // "Née vers" : si -1, l'année de naissance saisie est décalée d'un an
    // en arrière dans la base (ex: saisi 2024 + "-1" => 2023 enregistré).
    // Si 0, l'année saisie reste inchangée.
    final dateNaissanceAjustee = DateTime(
      _dateNaissance!.year + _neeVert,
      _dateNaissance!.month,
      _dateNaissance!.day,
    );

    final candidat = CandidatCepe(
      codeCandidat: codeCandidat,
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
      langue: null,
      neeVert: _neeVert,
      codeEcoleOrigine: _codeEcoleOrigine!,
      codeCegAccueil: _cegAccueilActif ? _codeCegAccueil : null,
      codeEtab: AppSession.instance.codeEtab ?? '',
      codeCentreEcrit: _codeCentreEcrit,
      codeCentreCorrection: _codeCentreCorrection,
      eps: false,
      photo: photoUrl,
      etatCandidat: 'Inscrit',
      anneeSession: now.year,
    );

    try {
      await FirestoreService.instance.ajouterCandidatCepe(candidat);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistrement = false;
          _photoPath = null;
        });
        _erreur(
          'Échec de l’enregistrement Firestore : $e. Reprenez la photo avant de réessayer.',
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Candidat "${candidat.nom} ${candidat.prenom}" enregistré',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // On garde le formulaire ouvert et on ne réinitialise PAS les centres
    // (écrit/correction) ni l'école d'origine, car on inscrit en général
    // plusieurs candidats du même centre à la suite. Seuls les champs
    // propres au candidat (identité, photo...) sont vidés.
    // reset() relance les « onChanged » des menus et efface les centres :
    // on mémorise donc les choix communs aux candidats suivants, puis on les remet.
    final gardeCorrection = _codeCentreCorrection;
    final gardeEcrit = _codeCentreEcrit;
    final gardeEcole = _codeEcoleOrigine;
    final gardeAccueil = _codeCegAccueil;
    _formKey.currentState!.reset();
    _nomController.clear();
    _prenomController.clear();
    _lieuNaissanceController.clear();
    _adresseController.clear();
    _nomPereController.clear();
    _nomMereController.clear();
    _dateNaissanceController.clear();
    setState(() {
      _codeCentreCorrection = gardeCorrection;
      _codeCentreEcrit = gardeEcrit;
      _codeEcoleOrigine = gardeEcole;
      _codeCegAccueil = gardeAccueil;
      _dateNaissance = null;
      _sexe = 'G';
      _handicap = false;
      _typeHandicap = null;
      _neeVert = 0;
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
  void dispose() {
    final chemin = _photoPath;
    if (chemin != null) FirebaseStorageService.supprimerPhotoTemporaire(chemin);
    super.dispose();
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
            const SizedBox(height: 8),

            SectionCard(
              titre: 'Centres',
              icone: Icons.apartment,
              enfants: [
                DropdownButtonFormField<String>(
                  key: ValueKey('corr_$_codeCentreCorrection'),
                  initialValue: _codeCentreCorrection,
                  decoration: const InputDecoration(
                    labelText: 'Centre de correction *',
                    border: OutlineInputBorder(),
                  ),
                  items: _centresCorrection
                      .where((c) => c.champs['code'] != null)
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.champs['code'],
                          child: Text(
                            c.champs['libelle'] ?? c.champs['code'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (v) => v == null ? 'Obligatoire' : null,
                  onChanged: (v) => setState(() {
                    _codeCentreCorrection = v;
                    _codeEcoleOrigine = null;
                    final ecrits = _centresEcrit
                        .where((c) => c.champs['codecorrection'] == v)
                        .toList();
                    _codeCentreEcrit = ecrits.length == 1
                        ? ecrits.first.champs['code']
                        : null;
                    final accueils = _cegAccueils
                        .where((c) => c.champs['codecorrection'] == v)
                        .toList();
                    _codeCegAccueil = accueils.length == 1
                        ? accueils.first.champs['code']
                        : null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'ecrit_${_codeCentreCorrection}_$_codeCentreEcrit',
                  ),
                  initialValue: _codeCentreEcrit,
                  decoration: const InputDecoration(
                    labelText: 'Centre d’écrit *',
                    border: OutlineInputBorder(),
                  ),
                  items: _centresEcrit
                      .where(
                        (c) =>
                            c.champs['code'] != null &&
                            (_codeCentreCorrection == null ||
                                c.champs['codecorrection'] ==
                                    _codeCentreCorrection),
                      )
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.champs['code'],
                          child: Text(
                            c.champs['libelle'] ?? c.champs['code'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (v) => v == null ? 'Obligatoire' : null,
                  onChanged: (v) => setState(() {
                    _codeCentreEcrit = v;
                    _codeEcoleOrigine =
                        null; // l'école dépend du centre d'écrit
                  }),
                ),
              ],
            ),

            SectionCard(
              titre: 'Identité du candidat',
              icone: Icons.badge,
              enfants: [
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                TextFormField(
                  controller: _prenomController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
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
                        validator: (v) =>
                            (v == null ||
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
                              // Non = 0 (année inchangée) ; Oui = -1 (année décalée d'un an)
                              ButtonSegment(value: 0, label: Text('Non')),
                              ButtonSegment(value: -1, label: Text('Oui')),
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
                    if (!v) _typeHandicap = null;
                  }),
                ),
                if (_handicap)
                  DropdownButtonFormField<String>(
                    value: _typeHandicap,
                    decoration: const InputDecoration(
                      labelText: 'Type de handicap *',
                      border: OutlineInputBorder(),
                    ),
                    items: _typesHandicap
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
                    labelText: 'Option *',
                    border: OutlineInputBorder(),
                  ),
                  items: _groupes
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('Option $g'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _groupe = v!;
                    if (!_cegAccueilActif) _codeCegAccueil = null;
                  }),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('ecole_$_codeCentreEcrit'),
                  value: _codeEcoleOrigine,
                  decoration: const InputDecoration(
                    labelText: 'École d\'origine *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      ListesLocales.sansDoublons(
                            _ecolesOrigine
                                .where(
                                  (e) =>
                                      e.champs['code'] != null &&
                                      (_codeCentreEcrit == null ||
                                          e.champs['codeCentre'] ==
                                              _codeCentreEcrit),
                                )
                                .toList(),
                          )
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e.champs['code'] as String,
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
                  key: ValueKey(
                    'ceg_${_codeCentreCorrection}_$_codeCegAccueil',
                  ),
                  value: _codeCegAccueil,
                  decoration: InputDecoration(
                    labelText: _cegAccueilActif
                        ? 'CEG d\'accueil *'
                        : 'CEG d\'accueil',
                    border: const OutlineInputBorder(),
                  ),
                  items: _cegAccueils
                      .where(
                        (c) =>
                            c.champs['code'] != null &&
                            (_codeCentreCorrection == null ||
                                c.champs['codecorrection'] ==
                                    _codeCentreCorrection),
                      )
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.champs['code'] as String,
                          child: Text(
                            c.champs['libelle'] ?? c.champs['code'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _cegAccueilActif
                      ? (v) => setState(() => _codeCegAccueil = v)
                      : null,
                ),
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
