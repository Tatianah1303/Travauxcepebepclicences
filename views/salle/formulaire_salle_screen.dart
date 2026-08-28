import 'package:flutter/material.dart';

import '../../models/salle.dart';
import '../../services/sqlite_service.dart';

/// Formulaire de création/consultation des salles, saisies manuellement
/// par centre. [typeExamen] = 'CEPE' ou 'BEPC'.
class FormulaireSalleScreen extends StatefulWidget {
  final String typeExamen;

  const FormulaireSalleScreen({super.key, required this.typeExamen});

  @override
  State<FormulaireSalleScreen> createState() => _FormulaireSalleScreenState();
}

class _FormulaireSalleScreenState extends State<FormulaireSalleScreen> {
  final _codeCentreController = TextEditingController();
  final _numeroSalleController = TextEditingController();
  final _capaciteController = TextEditingController();

  List<Salle> _salles = [];

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final salles = await SqliteService.instance.listerSalles(
      typeExamen: widget.typeExamen,
    );
    setState(() => _salles = salles);
  }

  Future<void> _ajouter() async {
    final codeCentre = _codeCentreController.text.trim();
    final numero = int.tryParse(_numeroSalleController.text.trim());
    final capacite = int.tryParse(_capaciteController.text.trim());

    if (codeCentre.isEmpty || numero == null || capacite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remplissez tous les champs correctement'),
        ),
      );
      return;
    }

    final salle = Salle(
      id: '${widget.typeExamen}_${codeCentre}_$numero',
      codeCentre: codeCentre,
      numeroSalle: numero,
      capacite: capacite,
      placesLibres: capacite,
      typeExamen: widget.typeExamen,
      anneeSession: DateTime.now().year,
    );

    await SqliteService.instance.insererSalle(salle);
    _codeCentreController.clear();
    _numeroSalleController.clear();
    _capaciteController.clear();
    await _rafraichir();
  }

  Future<void> _supprimer(Salle salle) async {
    await SqliteService.instance.supprimerSalle(salle.id);
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Salles — ${widget.typeExamen}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _codeCentreController,
                  decoration: const InputDecoration(
                    labelText: 'Code du centre',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _numeroSalleController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'N° salle',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _capaciteController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Capacité',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _ajouter,
                    child: const Text('Ajouter la salle'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _salles.isEmpty
                ? const Center(child: Text('Aucune salle enregistrée'))
                : ListView.builder(
                    itemCount: _salles.length,
                    itemBuilder: (ctx, i) {
                      final s = _salles[i];
                      return ListTile(
                        title: Text(
                          'Centre ${s.codeCentre} — Salle ${s.numeroSalle}',
                        ),
                        subtitle: Text(
                          'Capacité : ${s.capacite} — Libres : ${s.placesLibres}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _supprimer(s),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
