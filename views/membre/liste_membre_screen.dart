import 'dart:io';
import 'package:flutter/material.dart';

import '../../models/enseignant.dart';
import '../../models/membre_previsionnel.dart';
import '../../models/quota_membre.dart';
import '../../services/sqlite_service.dart';
import '../../services/app_session.dart';
import '../../utils/csv_export.dart';

/// Liste des membres prévisionnels de l'établissement, avec filtre par
/// rôle. Cliquer sur un membre ouvre un détail affichant ses informations
/// et ses photos CIN recto/verso.
class ListeMembresScreen extends StatefulWidget {
  const ListeMembresScreen({super.key});

  @override
  State<ListeMembresScreen> createState() => _ListeMembresScreenState();
}

class _ListeMembresScreenState extends State<ListeMembresScreen> {
  List<MembrePrevisionnel> _membres = [];
  List<Enseignant> _enseignants = [];
  String? _filtreRole; // null = tous les rôles

  int get _anneeSession => DateTime.now().year;
  String get _codeEtab => AppSession.instance.codeEtab ?? '';

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final enseignants = await SqliteService.instance.listerEnseignants(
      _codeEtab,
    );
    final matriculesEtab = enseignants.map((e) => e.matricule).toSet();
    final tousMembres = await SqliteService.instance.listerMembres(
      anneeSession: _anneeSession,
    );
    final membresEtab = tousMembres
        .where((m) => matriculesEtab.contains(m.matriculeEnseignant))
        .toList();

    setState(() {
      _enseignants = enseignants;
      _membres = membresEtab;
    });
  }

  Enseignant? _enseignantDe(String matricule) {
    try {
      return _enseignants.firstWhere((e) => e.matricule == matricule);
    } catch (_) {
      return null;
    }
  }

  List<MembrePrevisionnel> get _membresFiltres {
    if (_filtreRole == null) return _membres;
    return _membres.where((m) => m.role == _filtreRole).toList();
  }

  Future<void> _exporter() async {
    try {
      final chemin = await exporterEnCsv(
        nomFichier: 'membres_previsionnels',
        entetes: const [
          'Nom',
          'Prénom',
          'Fonction',
          'Rôle',
          'État',
          'Centre écrit',
          'Centre correction',
        ],
        lignes: _membresFiltres.map((m) {
          final e = _enseignantDe(m.matriculeEnseignant);
          return [
            e?.nom ?? '-',
            e?.prenom ?? '-',
            e?.fonction ?? '-',
            libelleRole(m.role),
            m.etat,
            m.codeCentreEcrit ?? '-',
            m.codeCentreCorrection ?? '-',
          ];
        }).toList(),
      );
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

  void _voirDetail(MembrePrevisionnel membre) {
    final enseignant = _enseignantDe(membre.matriculeEnseignant);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              enseignant != null
                  ? '${enseignant.nom} ${enseignant.prenom}'
                  : membre.matriculeEnseignant,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ligneInfo('Fonction', enseignant?.fonction ?? '-'),
            _ligneInfo('Rôle', libelleRole(membre.role)),
            _ligneInfo('État', membre.etat),
            _ligneInfo('Téléphone', enseignant?.phone ?? '-'),
            _ligneInfo(
              'Centre d\'écrit',
              membre.codeCentreEcrit ?? 'Non attribué',
            ),
            _ligneInfo(
              'Centre de correction',
              membre.codeCentreCorrection ?? 'Non attribué',
            ),
            const Divider(height: 32),
            const Text(
              'Carte d\'identité (CIN)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _imageCin('Recto', membre.photoCinRecto)),
                const SizedBox(width: 12),
                Expanded(child: _imageCin('Verso', membre.photoCinVerso)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneInfo(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageCin(String label, String? chemin) {
    final fichier = chemin != null ? File(chemin) : null;
    final existe = fichier != null && fichier.existsSync();
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: existe
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    fichier,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                )
              : const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des membres prévisionnels'),
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
            child: DropdownButtonFormField<String?>(
              initialValue: _filtreRole,
              decoration: const InputDecoration(
                labelText: 'Filtrer par rôle',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tous les rôles'),
                ),
                ...rolesMembre.map(
                  (r) =>
                      DropdownMenuItem(value: r, child: Text(libelleRole(r))),
                ),
              ],
              onChanged: (v) => setState(() => _filtreRole = v),
            ),
          ),
          Expanded(
            child: _membresFiltres.isEmpty
                ? const Center(child: Text('Aucun membre pour ce filtre'))
                : ListView.builder(
                    itemCount: _membresFiltres.length,
                    itemBuilder: (ctx, i) {
                      final m = _membresFiltres[i];
                      final e = _enseignantDe(m.matriculeEnseignant);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Text(
                            e?.nom.isNotEmpty == true ? e!.nom[0] : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          e != null
                              ? '${e.nom} ${e.prenom}'
                              : m.matriculeEnseignant,
                        ),
                        subtitle: Text('${libelleRole(m.role)} — ${m.etat}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _voirDetail(m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
