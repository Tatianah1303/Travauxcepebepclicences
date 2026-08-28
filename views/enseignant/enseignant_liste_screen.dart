import 'package:flutter/material.dart';

import '../../models/enseignant.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../utils/validators.dart';

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

  Future<void> _ouvrirFormulaire() async {
    final formKey = GlobalKey<FormState>();
    final matriculeController = TextEditingController();
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final phoneController = TextEditingController();
    final adresseController = TextEditingController();
    String fonction = 'Enseignant';

    final resultat = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un enseignant'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: matriculeController,
                    decoration: const InputDecoration(labelText: 'Matricule'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: nomController,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: prenomController,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      hintText: '034 12 345 67',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: validerTelephone,
                  ),
                  TextFormField(
                    controller: adresseController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: fonction,
                    decoration: const InputDecoration(labelText: 'Fonction'),
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
                    onChanged: (v) => setDialogState(() => fonction = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (resultat != true) return;

    final enseignant = Enseignant(
      matricule: matriculeController.text.trim(),
      nom: nomController.text.trim(),
      prenom: prenomController.text.trim(),
      phone: phoneController.text.trim(),
      adresse: adresseController.text.trim(),
      codeEtab: AppSession.instance.codeEtab ?? '',
      fonction: fonction,
    );

    await SqliteService.instance.insererEnseignant(enseignant);
    await _rafraichir();
  }

  Future<void> _supprimer(Enseignant e) async {
    await SqliteService.instance.supprimerEnseignant(e.matricule);
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enseignants de l\'établissement')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _ouvrirFormulaire,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _enseignants.isEmpty
          ? const Center(child: Text('Aucun enseignant enregistré'))
          : ListView.builder(
              itemCount: _enseignants.length,
              itemBuilder: (ctx, i) {
                final e = _enseignants[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: e.fonction == 'Directeur'
                        ? Colors.purple
                        : Colors.blue,
                    child: Text(
                      e.nom.isNotEmpty ? e.nom[0] : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text('${e.nom} ${e.prenom}'),
                  subtitle: Text('${e.fonction} — ${e.phone}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _supprimer(e),
                  ),
                );
              },
            ),
    );
  }
}
