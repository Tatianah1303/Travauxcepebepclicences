import 'package:flutter/material.dart';

import '../../models/candidat_cepe.dart';
import '../../models/candidat_bepc.dart';
import '../../services/firestore_service.dart';
import '../../services/app_session.dart';
import '../../utils/csv_export.dart';
import '../../utils/pdf_export.dart';
import '../../utils/photo_helper.dart';

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
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    setState(() => _chargement = true);
    final codeEtab = AppSession.instance.codeEtab ?? '';
    try {
      if (widget.pourCepe) {
        final liste = await FirestoreService.instance.listerCandidatsCepe(
          codeEtab: codeEtab,
        );
        if (mounted) setState(() => _cepe = liste);
      } else {
        final liste = await FirestoreService.instance.listerCandidatsBepc(
          codeEtab: codeEtab,
        );
        if (mounted) setState(() => _bepc = liste);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur chargement : $e')));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  // ── Supprimer un candidat ───────────────────────────────────────────────
  Future<void> _supprimerCepe(CandidatCepe c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer ${c.nom} ${c.prenom} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirestoreService.instance.supprimerCandidatCepe(c.codeCandidat);
    _rafraichir();
  }

  Future<void> _supprimerBepc(CandidatBepc c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer ${c.nom} ${c.prenom} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirestoreService.instance.supprimerCandidatBepc(c.codeCandidat);
    _rafraichir();
  }

  // ── Voir le détail complet d'un candidat CEPE ──────────────────────────
  void _voirDetailCepe(CandidatCepe c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.nom} ${c.prenom}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _info('Sexe', c.sexe == 'G' ? 'Garçon' : 'Fille'),
              _info('Date de naissance', _date(c.dateNaissance)),
              _info('Lieu de naissance', c.lieuNaissance),
              _info('Adresse', c.adresseActuelle),
              _info('Nom du père', c.nomPere ?? 'Néant'),
              _info('Nom de la mère', c.nomMere),
              const Divider(),
              _info('Groupe', c.groupe),
              _info('École d\'origine', c.codeEcoleOrigine),
              if (c.codeCegAccueil != null)
                _info('CEG d\'accueil', c.codeCegAccueil!),
              if (c.codeCentreEcrit != null)
                _info('Centre écrit', c.codeCentreEcrit!),
              if (c.codeCentreCorrection != null)
                _info('Centre correction', c.codeCentreCorrection!),
              const Divider(),
              _info('Handicap', c.handicap ? 'Oui' : 'Non'),
              if (c.handicap && c.typeHandicap != null)
                _info('Type de handicap', c.typeHandicap!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ── Voir le détail complet d'un candidat BEPC ──────────────────────────
  void _voirDetailBepc(CandidatBepc c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.nom} ${c.prenom}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _info('Sexe', c.sexe == 'G' ? 'Garçon' : 'Fille'),
              _info('Date de naissance', _date(c.dateNaissance)),
              _info('Lieu de naissance', c.lieuNaissance),
              _info('Adresse', c.adresseActuelle),
              _info('Nom du père', c.nomPere ?? 'Néant'),
              _info('Nom de la mère', c.nomMere),
              const Divider(),
              _info('Groupe', c.groupe),
              if (c.langue != null) _info('Langue', c.langue!),
              _info('École d\'origine', c.codeEcoleOrigine),
              if (c.codeLyceeAccueil != null)
                _info('Lycée d\'accueil', c.codeLyceeAccueil!),
              if (c.codeCentreEcrit != null)
                _info('Centre écrit', c.codeCentreEcrit!),
              if (c.codeCentreCorrection != null)
                _info('Centre correction', c.codeCentreCorrection!),
              const Divider(),
              _info('Handicap', c.handicap ? 'Oui' : 'Non'),
              if (c.handicap && c.typeHandicap != null)
                _info('Type de handicap', c.typeHandicap!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(valeur, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ── Export CSV ──────────────────────────────────────────────────────────
  Future<void> _exporter() async {
    try {
      String chemin;
      if (widget.pourCepe) {
        chemin = await exporterEnCsv(
          nomFichier: 'candidats_cepe',
          entetes: const [
            'N°',
            'Nom',
            'Prénom',
            'Sexe',
            'Date naissance',
            'Lieu naissance',
            'Adresse',
            'Nom père',
            'Nom mère',
            'Groupe',
            'École origine',
            'CEG accueil',
            'Centre écrit',
            'Handicap',
            'Type handicap',
          ],
          lignes: _cepe
              .map(
                (c) => [
                  '${c.numero}',
                  c.nom,
                  c.prenom,
                  c.sexe == 'G' ? 'Garçon' : 'Fille',
                  _date(c.dateNaissance),
                  c.lieuNaissance,
                  c.adresseActuelle,
                  c.nomPere ?? 'Néant',
                  c.nomMere,
                  c.groupe,
                  c.codeEcoleOrigine,
                  c.codeCegAccueil ?? '-',
                  c.codeCentreEcrit ?? '-',
                  c.handicap ? 'Oui' : 'Non',
                  c.typeHandicap ?? '-',
                ],
              )
              .toList(),
        );
      } else {
        chemin = await exporterEnCsv(
          nomFichier: 'candidats_bepc',
          entetes: const [
            'N°',
            'Nom',
            'Prénom',
            'Sexe',
            'Date naissance',
            'Lieu naissance',
            'Adresse',
            'Nom père',
            'Nom mère',
            'Groupe',
            'Langue',
            'École origine',
            'Lycée accueil',
            'Centre écrit',
            'Née vers',
            'Handicap',
            'Type handicap',
          ],
          lignes: _bepc
              .map(
                (c) => [
                  '${c.numero}',
                  c.nom,
                  c.prenom,
                  c.sexe == 'G' ? 'Garçon' : 'Fille',
                  _date(c.dateNaissance),
                  c.lieuNaissance,
                  c.adresseActuelle,
                  c.nomPere ?? 'Néant',
                  c.nomMere,
                  c.groupe,
                  c.langue ?? '-',
                  c.codeEcoleOrigine,
                  c.codeLyceeAccueil ?? '-',
                  c.codeCentreEcrit ?? '-',
                  c.neeVert != 0 ? 'Oui' : 'Non',
                  c.handicap ? 'Oui' : 'Non',
                  c.typeHandicap ?? '-',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is EnregistrementAnnule ? '$e' : 'Erreur export : $e',
          ),
        ),
      );
    }
  }

  // ── Export PDF ──────────────────────────────────────────────────────────
  Future<void> _exporterPdf() async {
    try {
      String chemin;
      if (widget.pourCepe) {
        chemin = await exporterEnPdf(
          titre: 'Candidats CEPE',
          entetes: const [
            'N°',
            'Nom',
            'Prénom',
            'Sexe',
            'Date naiss.',
            'Lieu naiss.',
            'Adresse',
            'Nom père',
            'Nom mère',
            'Groupe',
            'École origine',
            'CEG',
            'Handicap',
          ],
          lignes: _cepe
              .map(
                (c) => [
                  '${c.numero}',
                  c.nom,
                  c.prenom,
                  c.sexe == 'G' ? 'G' : 'F',
                  _date(c.dateNaissance),
                  c.lieuNaissance,
                  c.adresseActuelle,
                  c.nomPere ?? 'Néant',
                  c.nomMere,
                  c.groupe,
                  c.codeEcoleOrigine,
                  c.codeCegAccueil ?? '-',
                  c.handicap ? 'Oui' : 'Non',
                ],
              )
              .toList(),
        );
      } else {
        chemin = await exporterEnPdf(
          titre: 'Candidats BEPC',
          entetes: const [
            'N°',
            'Nom',
            'Prénom',
            'Sexe',
            'Date naiss.',
            'Lieu naiss.',
            'Adresse',
            'Nom père',
            'Nom mère',
            'Groupe',
            'Langue',
            'École origine',
            'Lycée',
            'Handicap',
          ],
          lignes: _bepc
              .map(
                (c) => [
                  '${c.numero}',
                  c.nom,
                  c.prenom,
                  c.sexe == 'G' ? 'G' : 'F',
                  _date(c.dateNaissance),
                  c.lieuNaissance,
                  c.adresseActuelle,
                  c.nomPere ?? 'Néant',
                  c.nomMere,
                  c.groupe,
                  c.langue ?? '-',
                  c.codeEcoleOrigine,
                  c.codeLyceeAccueil ?? '-',
                  c.handicap ? 'Oui' : 'Non',
                ],
              )
              .toList(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF exporté : $chemin')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is EnregistrementAnnule ? '$e' : 'Erreur PDF : $e'),
        ),
      );
    }
  }

  Widget _photoMiniature(String url) {
    final image = imageDepuisPhoto(url);
    if (image == null) {
      return const CircleAvatar(
        radius: 18,
        child: Icon(Icons.person, size: 18),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundImage: image,
      onBackgroundImageError: (_, __) {},
    );
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _rafraichir,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Excel (.csv)',
            onPressed: _exporter,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF',
            onPressed: _exporterPdf,
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
          if (_chargement)
            const LinearProgressIndicator()
          else
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
    if (liste.isEmpty) {
      return const Center(child: Text('Aucun candidat inscrit'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: liste.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = liste[i];
        return ListTile(
          leading: _photoMiniature(c.photo),
          title: Text(
            '${c.nom} ${c.prenom}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Groupe ${c.groupe}  •  ${c.codeEcoleOrigine}\n'
            'Né(e) le ${_date(c.dateNaissance)} à ${c.lieuNaissance}',
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.blue),
                tooltip: 'Voir détail',
                onPressed: () => _voirDetailCepe(c),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Supprimer',
                onPressed: () => _supprimerCepe(c),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableBepc(List<CandidatBepc> liste) {
    if (liste.isEmpty) {
      return const Center(child: Text('Aucun candidat inscrit'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: liste.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = liste[i];
        return ListTile(
          leading: _photoMiniature(c.photo),
          title: Text(
            '${c.nom} ${c.prenom}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Groupe ${c.groupe}${c.langue != null ? "  •  ${c.langue}" : ""}  •  ${c.codeEcoleOrigine}\n'
            'Né(e) le ${_date(c.dateNaissance)} à ${c.lieuNaissance}',
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.blue),
                tooltip: 'Voir détail',
                onPressed: () => _voirDetailBepc(c),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Supprimer',
                onPressed: () => _supprimerBepc(c),
              ),
            ],
          ),
        );
      },
    );
  }
}
