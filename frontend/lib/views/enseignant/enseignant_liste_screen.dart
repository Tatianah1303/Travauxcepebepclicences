import 'package:flutter/material.dart';

import '../../models/enseignant.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../utils/validators.dart';
import '../../widgets/section_card.dart';

/// Gestion des enseignants de l'établissement connecté.
/// Nécessaire avant de pouvoir désigner un membre prévisionnel.
class EnseignantListeScreen extends StatefulWidget {
  const EnseignantListeScreen({super.key});

  @override
  State<EnseignantListeScreen> createState() => _EnseignantListeScreenState();
}

class _EnseignantListeScreenState extends State<EnseignantListeScreen> {
  List<Enseignant> _enseignants = [];

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final codeEtab = AppSession.instance.codeEtab ?? '';
    final liste = await SqliteService.instance.listerEnseignants(codeEtab);
    setState(() => _enseignants = liste);
  }

  Future<void> _ouvrirFormulaire({Enseignant? existant}) async {
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FormulaireEnseignantScreen(existant: existant),
      ),
    );
    if (modifie == true) await _rafraichir();
  }

  Future<void> _supprimer(Enseignant e) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer ${e.nom} ${e.prenom} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await SqliteService.instance.supprimerEnseignant(e.matricule);
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: const Text('Enseignants de l\'établissement')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
      body: _enseignants.isEmpty
          ? const Center(child: Text('Aucun enseignant enregistré'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.green.shade50,
                    ),
                    columns: const [
                      DataColumn(label: Text('MATRICULE')),
                      DataColumn(label: Text('NOM')),
                      DataColumn(label: Text('PRÉNOM')),
                      DataColumn(label: Text('SEXE')),
                      DataColumn(label: Text('CIN')),
                      DataColumn(label: Text('TÉLÉPHONE')),
                      DataColumn(label: Text('FONCTION')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: _enseignants
                        .map(
                          (e) => DataRow(
                            cells: [
                              DataCell(Text(e.matricule)),
                              DataCell(Text(e.nom)),
                              DataCell(Text(e.prenom)),
                              DataCell(Text(e.sexe ?? '-')),
                              DataCell(Text(e.cin ?? '-')),
                              DataCell(Text(e.phone)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: e.fonction == 'Directeur'
                                        ? Colors.purple.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    e.fonction,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: e.fonction == 'Directeur'
                                          ? Colors.purple.shade800
                                          : Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _ouvrirFormulaire(existant: e),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _supprimer(e),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Formulaire d'ajout/modification d'un enseignant, en page complète et
/// organisée en cadres (au lieu d'une petite boîte de dialogue exiguë).
class _FormulaireEnseignantScreen extends StatefulWidget {
  final Enseignant? existant;
  const _FormulaireEnseignantScreen({this.existant});

  @override
  State<_FormulaireEnseignantScreen> createState() =>
      _FormulaireEnseignantScreenState();
}

class _FormulaireEnseignantScreenState
    extends State<_FormulaireEnseignantScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _matriculeController = TextEditingController(
    text: widget.existant?.matricule ?? '',
  );
  late final _cinController = TextEditingController(
    text: widget.existant?.cin ?? '',
  );
  late final _nomController = TextEditingController(
    text: widget.existant?.nom ?? '',
  );
  late final _prenomController = TextEditingController(
    text: widget.existant?.prenom ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existant?.phone ?? '',
  );
  late final _adresseController = TextEditingController(
    text: widget.existant?.adresse ?? '',
  );
  late String _sexe = widget.existant?.sexe ?? 'G';
  late String _fonction = widget.existant?.fonction ?? 'Enseignant';
  bool _enregistrement = false;

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enregistrement = true);

    final enseignant = Enseignant(
      matricule: _matriculeController.text.trim(),
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      phone: _phoneController.text.trim(),
      adresse: _adresseController.text.trim(),
      codeEtab: AppSession.instance.codeEtab ?? '',
      fonction: _fonction,
      cin: _cinController.text.trim(),
      sexe: _sexe,
    );

    if (widget.existant == null) {
      await SqliteService.instance.insererEnseignant(enseignant);
    } else {
      await SqliteService.instance.modifierEnseignant(enseignant);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enseignant enregistré')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          widget.existant == null
              ? 'Ajouter un enseignant'
              : 'Modifier l\'enseignant',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              titre: 'Identification',
              icone: Icons.badge,
              enfants: [
                TextFormField(
                  controller: _matriculeController,
                  decoration: const InputDecoration(
                    labelText: 'Matricule (6 chiffres) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) =>
                      (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim()))
                      ? 'Le matricule doit contenir exactement 6 chiffres'
                      : null,
                ),
                TextFormField(
                  controller: _cinController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro CIN (12 chiffres) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (v) =>
                      (v == null || !RegExp(r'^\d{12}$').hasMatch(v.trim()))
                      ? 'Le CIN doit contenir exactement 12 chiffres'
                      : null,
                ),
              ],
            ),

            SectionCard(
              titre: 'Identité',
              icone: Icons.person,
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
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Homme'),
                        value: 'G',
                        groupValue: _sexe,
                        onChanged: (v) => setState(() => _sexe = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Femme'),
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
              titre: 'Contact',
              icone: Icons.contact_phone,
              enfants: [
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone *',
                    hintText: '034 12 345 67',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: validerTelephone,
                ),
                TextFormField(
                  controller: _adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
              ],
            ),

            SectionCard(
              titre: 'Fonction',
              icone: Icons.work,
              enfants: [
                DropdownButtonFormField<String>(
                  initialValue: _fonction,
                  decoration: const InputDecoration(
                    labelText: 'Fonction',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Enseignant',
                      child: Text('Enseignant'),
                    ),
                    DropdownMenuItem(
                      value: 'Directeur',
                      child: Text('Directeur'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _fonction = v!),
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
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
