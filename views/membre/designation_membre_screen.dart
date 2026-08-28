import 'package:flutter/material.dart';

import '../../models/enseignant.dart';
import '../../models/membre_previsionnel.dart';
import '../../models/quota_membre.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../utils/photo_helper.dart';

/// Écran principal de désignation des membres prévisionnels.
///
/// Pour chaque rôle (Jury, Correcteur, Chef de centre, Sécurité), affiche
/// le quota fixé et le nombre déjà désigné. L'établissement choisit un
/// enseignant parmi sa liste (filtré : Chef de centre réservé aux
/// Directeurs, et un enseignant déjà membre cette année n'est plus
/// proposé — un seul rôle à la fois). La désignation capture immédiatement
/// la photo CIN recto/verso, et le membre passe à l'état "Identifié".
class DesignationMembreScreen extends StatefulWidget {
  const DesignationMembreScreen({super.key});

  @override
  State<DesignationMembreScreen> createState() =>
      _DesignationMembreScreenState();
}

class _DesignationMembreScreenState extends State<DesignationMembreScreen> {
  List<Enseignant> _enseignants = [];
  List<QuotaMembre> _quotas = [];
  List<MembrePrevisionnel> _membres = [];
  bool _chargement = true;

  int get _anneeSession => DateTime.now().year;
  String get _codeEtab => AppSession.instance.codeEtab ?? '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final enseignants = await SqliteService.instance.listerEnseignants(
      _codeEtab,
    );
    final quotas = await SqliteService.instance.listerQuotas(
      codeEtab: _codeEtab,
      anneeSession: _anneeSession,
    );
    final tousMembres = await SqliteService.instance.listerMembres(
      anneeSession: _anneeSession,
    );

    // Ne garder que les membres dont l'enseignant appartient à cet établissement
    final matriculesEtab = enseignants.map((e) => e.matricule).toSet();
    final membresEtab = tousMembres
        .where((m) => matriculesEtab.contains(m.matriculeEnseignant))
        .toList();

    setState(() {
      _enseignants = enseignants;
      _quotas = quotas;
      _membres = membresEtab;
      _chargement = false;
    });
  }

  int _quotaPourRole(String role) {
    final q = _quotas.where((q) => q.role == role).toList();
    return q.isEmpty ? 0 : q.first.quantite;
  }

  int _designesPourRole(String role) {
    return _membres.where((m) => m.role == role).length;
  }

  /// Enseignants encore disponibles pour ce rôle : pas déjà membre cette
  /// année, et fonction compatible (Directeur uniquement pour ChefDeCentre).
  List<Enseignant> _enseignantsEligibles(String role) {
    final matriculesDejaMembres = _membres
        .map((m) => m.matriculeEnseignant)
        .toSet();
    return _enseignants.where((e) {
      if (matriculesDejaMembres.contains(e.matricule)) return false;
      if (role == 'ChefDeCentre') return e.fonction == 'Directeur';
      return true;
    }).toList();
  }

  Future<void> _designer(String role) async {
    final eligibles = _enseignantsEligibles(role);
    if (eligibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            role == 'ChefDeCentre'
                ? 'Aucun directeur disponible pour ce rôle'
                : 'Aucun enseignant disponible (tous déjà désignés)',
          ),
        ),
      );
      return;
    }

    final choisi = await showDialog<Enseignant>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Choisir un enseignant — ${libelleRole(role)}'),
        children: eligibles
            .map(
              (e) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(e),
                child: Text('${e.nom} ${e.prenom} (${e.fonction})'),
              ),
            )
            .toList(),
      ),
    );

    if (choisi == null) return;
    if (!mounted) return;
    await _capturerCinEtEnregistrer(choisi, role);
  }

  Future<void> _capturerCinEtEnregistrer(
    Enseignant enseignant,
    String role,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Photo CIN recto de ${enseignant.nom} ${enseignant.prenom}',
        ),
      ),
    );
    final recto = await prendrePhotoOuChoisirFichier();
    if (recto == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maintenant la photo CIN verso')),
    );
    final verso = await prendrePhotoOuChoisirFichier();
    if (verso == null) return;

    final membre = MembrePrevisionnel(
      codeMembre:
          '${enseignant.matricule}_${DateTime.now().millisecondsSinceEpoch}',
      matriculeEnseignant: enseignant.matricule,
      role: role,
      etat: 'Identifié',
      photoCinRecto: recto,
      photoCinVerso: verso,
      anneeSession: _anneeSession,
    );

    await SqliteService.instance.insererMembre(membre);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${enseignant.nom} désigné(e) ${libelleRole(role)}'),
      ),
    );
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Désignation des membres prévisionnels'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final role in rolesMembre) ...[
            Card(
              child: ListTile(
                title: Text(
                  libelleRole(role),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${_designesPourRole(role)} / ${_quotaPourRole(role)} désigné(s)',
                ),
                trailing: ElevatedButton.icon(
                  onPressed:
                      _designesPourRole(role) >= _quotaPourRole(role) &&
                          _quotaPourRole(role) > 0
                      ? null
                      : () => _designer(role),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Désigner'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_quotas.isEmpty || _quotas.every((q) => q.quantite == 0))
            const Card(
              color: Colors.amber,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '⚠️ Aucun quota défini. Définissez d\'abord les quotas avant de désigner.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
