import 'dart:io';
import 'package:flutter/material.dart';

import '../../models/candidat_cepe.dart';
import '../../models/candidat_bepc.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../utils/csv_export.dart';

/// Liste des candidats inscrits par l'établissement connecté, pour un
/// examen donné (CEPE ou BEPC). Tableau avec photo, recherche, et export
/// Excel (CSV) — les photos ne sont pas incluses dans l'export.
class ListeCandidatsScreen extends StatefulWidget {
  final bool pourCepe;

  const ListeCandidatsScreen({super.key, required this.pourCepe});

  @override
  State<ListeCandidatsScreen> createState() => _ListeCandidatsScreenState();
}

class _ListeCandidatsScreenState extends State<ListeCandidatsScreen> {
  List<CandidatCepe> _cepe = [];
  List<CandidatBepc> _bepc = [];
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final codeEtab = AppSession.instance.codeEtab;
    if (widget.pourCepe) {
      final tous = await SqliteService.instance.listerCandidatsCepe();
      setState(
        () => _cepe = tous.where((c) => c.codeEtab == codeEtab).toList(),
      );
    } else {
      final tous = await SqliteService.instance.listerCandidatsBepc();
      setState(
        () => _bepc = tous.where((c) => c.codeEtab == codeEtab).toList(),
      );
    }
  }

  Future<void> _exporter() async {
    try {
      String chemin;
      if (widget.pourCepe) {
        chemin = await exporterEnCsv(
          nomFichier: 'candidats_cepe',
          entetes: const [
            'Nom',
            'Prénom',
            'Sexe',
            'Groupe',
            'Langue',
            'École origine',
            'Handicap',
            'État',
          ],
          lignes: _cepe
              .map(
                (c) => [
                  c.nom,
                  c.prenom,
                  c.sexe,
                  c.groupe,
                  c.langue ?? '-',
                  c.codeEcoleOrigine,
                  c.handicap ? 'Oui' : 'Non',
                  c.etatCandidat,
                ],
              )
              .toList(),
        );
      } else {
        chemin = await exporterEnCsv(
          nomFichier: 'candidats_bepc',
          entetes: const [
            'Nom',
            'Prénom',
            'Sexe',
            'Groupe',
            'Langue',
            'École origine',
            'Née vert',
            'État',
          ],
          lignes: _bepc
              .map(
                (c) => [
                  c.nom,
                  c.prenom,
                  c.sexe,
                  c.groupe,
                  c.langue ?? '-',
                  c.codeEcoleOrigine,
                  '${c.neeVert}',
                  c.etatCandidat,
                ],
              )
              .toList(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exporté : $chemin')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur export : $e')));
    }
  }

  Widget _photoMiniature(String cheminPhoto) {
    final fichier = File(cheminPhoto);
    if (!fichier.existsSync()) {
      return const CircleAvatar(
        radius: 18,
        child: Icon(Icons.person, size: 18),
      );
    }
    return CircleAvatar(radius: 18, backgroundImage: FileImage(fichier));
  }

  @override
  Widget build(BuildContext context) {
    final nomsCepe = _cepe
        .where(
          (c) => '${c.nom} ${c.prenom}'.toLowerCase().contains(
            _recherche.toLowerCase(),
          ),
        )
        .toList();
    final nomsBepc = _bepc
        .where(
          (c) => '${c.nom} ${c.prenom}'.toLowerCase().contains(
            _recherche.toLowerCase(),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Candidats ${widget.pourCepe ? 'CEPE' : 'BEPC'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exporter en Excel (.csv)',
            onPressed: _exporter,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un nom...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _recherche = v),
            ),
          ),
          Expanded(
            child: widget.pourCepe
                ? _tableCepe(nomsCepe)
                : _tableBepc(nomsBepc),
          ),
        ],
      ),
    );
  }

  Widget _tableCepe(List<CandidatCepe> liste) {
    if (liste.isEmpty)
      return const Center(child: Text('Aucun candidat inscrit'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('PHOTO')),
            DataColumn(label: Text('NOM')),
            DataColumn(label: Text('GROUPE')),
            DataColumn(label: Text('LANGUE')),
            DataColumn(label: Text('HANDICAP')),
            DataColumn(label: Text('ÉTAT')),
          ],
          rows: liste
              .map(
                (c) => DataRow(
                  cells: [
                    DataCell(_photoMiniature(c.photo)),
                    DataCell(Text('${c.nom} ${c.prenom}')),
                    DataCell(Text(c.groupe)),
                    DataCell(Text(c.langue ?? '-')),
                    DataCell(Text(c.handicap ? 'Oui' : 'Non')),
                    DataCell(Text(c.etatCandidat)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _tableBepc(List<CandidatBepc> liste) {
    if (liste.isEmpty)
      return const Center(child: Text('Aucun candidat inscrit'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('PHOTO')),
            DataColumn(label: Text('NOM')),
            DataColumn(label: Text('GROUPE')),
            DataColumn(label: Text('LANGUE')),
            DataColumn(label: Text('NÉE VERT')),
            DataColumn(label: Text('ÉTAT')),
          ],
          rows: liste
              .map(
                (c) => DataRow(
                  cells: [
                    DataCell(_photoMiniature(c.photo)),
                    DataCell(Text('${c.nom} ${c.prenom}')),
                    DataCell(Text(c.groupe)),
                    DataCell(Text(c.langue ?? '-')),
                    DataCell(Text('${c.neeVert}')),
                    DataCell(Text(c.etatCandidat)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
