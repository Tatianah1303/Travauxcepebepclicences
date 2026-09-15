import 'package:flutter/material.dart';

import '../../models/periode_saisie.dart';
import '../../services/sqlite_service.dart';

/// Permet à l'admin de définir UNE SEULE FOIS la fenêtre de saisie
/// autorisée (date de début + date de clôture + description), visible
/// aussitôt par les 45 établissements via la petite cloche de
/// notification sur leur écran d'accueil — plus besoin d'envoyer un
/// message individuel à chacun.
class PeriodeSaisieScreen extends StatefulWidget {
  const PeriodeSaisieScreen({super.key});

  @override
  State<PeriodeSaisieScreen> createState() => _PeriodeSaisieScreenState();
}

class _PeriodeSaisieScreenState extends State<PeriodeSaisieScreen> {
  final _descriptionController = TextEditingController();
  DateTime? _dateDebut;
  DateTime? _dateFin;
  PeriodeSaisie? _periodeActuelle;
  bool _chargement = true;
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final periode = await SqliteService.instance.lirePeriodeSaisie();
    setState(() {
      _periodeActuelle = periode;
      if (periode != null) {
        _dateDebut = periode.dateDebut;
        _dateFin = periode.dateFin;
        _descriptionController.text = periode.description;
      }
      _chargement = false;
    });
  }

  Future<void> _choisirDate({required bool debut}) async {
    final initiale = (debut ? _dateDebut : _dateFin) ?? DateTime.now();
    final choix = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (choix == null) return;
    setState(() {
      if (debut) {
        _dateDebut = choix;
      } else {
        _dateFin = choix;
      }
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Choisir une date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _enregistrer() async {
    if (_dateDebut == null || _dateFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez les deux dates')),
      );
      return;
    }
    if (_dateFin!.isBefore(_dateDebut!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de clôture doit être après la date de début'),
        ),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez une courte description')),
      );
      return;
    }

    setState(() => _enregistrement = true);
    await SqliteService.instance.definirPeriodeSaisie(
      PeriodeSaisie(
        dateDebut: _dateDebut!,
        // On inclut toute la journée de fin (jusqu'à 23:59:59).
        dateFin: DateTime(
          _dateFin!.year,
          _dateFin!.month,
          _dateFin!.day,
          23,
          59,
          59,
        ),
        description: _descriptionController.text.trim(),
        definiLe: DateTime.now(),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Période enregistrée — visible par tous les établissements',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: const Text('Période de saisie')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Définissez ici la fenêtre pendant laquelle les 45 '
                      'établissements ont le droit de saisir leurs '
                      'candidats. Ils seront prévenus automatiquement '
                      '(petite cloche sur leur écran d\'accueil) — pas '
                      'besoin de leur écrire un par un.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_periodeActuelle != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _periodeActuelle!.statut == StatutSaisie.enCours
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      _periodeActuelle!.statut == StatutSaisie.enCours
                          ? Icons.check_circle
                          : Icons.schedule,
                      color: _periodeActuelle!.statut == StatutSaisie.enCours
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(switch (_periodeActuelle!.statut) {
                        StatutSaisie.pasEncoreCommence =>
                          'Période actuelle : pas encore commencée',
                        StatutSaisie.enCours => 'Période actuelle : en cours',
                        StatutSaisie.termine =>
                          'Période actuelle : terminée (clôturée)',
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Nouvelle période',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _choisirDate(debut: true),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_formatDate(_dateDebut)),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _choisirDate(debut: false),
                  icon: const Icon(Icons.event_busy, size: 18),
                  label: Text(_formatDate(_dateFin)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (visible par les établissements)',
              hintText:
                  'Ex : Saisie des candidats CEPE et BEPC pour la session 2026',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _enregistrement ? null : _enregistrer,
            icon: const Icon(Icons.campaign),
            label: Text(
              _periodeActuelle == null
                  ? 'Publier la période'
                  : 'Mettre à jour la période',
            ),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),
        ],
      ),
    );
  }
}
