// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Beispiel aus den Bausteinen der Basis: Liste (Suche, Filter, Leer- und
/// Fehlerzustand, Ziehen zum Neuladen, ab 840 px Tabelle), Formular (Pruefen,
/// deutsche Fehler, Fehler der API am Feld) und Rechte (Knopf nur mit
/// Schreibrecht). Endpunkte und Felder durch die eigenen ersetzen; die
/// Attrappe (lib/attrappe.dart) bildet `GET/POST /api/beispiel/eintraege` nach.
class Eintrag {
  const Eintrag({required this.id, required this.titel, required this.erledigt});
  final int id;
  final String titel;
  final bool erledigt;

  factory Eintrag.aus(Map<String, dynamic> j) =>
      Eintrag(id: j['id'] as int, titel: '${j['titel']}', erledigt: j['erledigt'] == true);
}

/// Recht der Seite in `permissions` (GET /api/auth/me); hier ein Beispiel.
const eintraegeRecht = 'beispiel';

class EintraegeSeite extends StatefulWidget {
  const EintraegeSeite({super.key, required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  State<EintraegeSeite> createState() => _EintraegeSeiteState();
}

class _EintraegeSeiteState extends State<EintraegeSeite> {
  late final _liste = ListenSteuerung<Eintrag>.lokal(
    alle: () async => [
      for (final j in await widget.sitzung.api.liste('/api/beispiel/eintraege'))
        if (j is Map<String, dynamic>) Eintrag.aus(j),
    ],
    suchText: (e) => e.titel,
    schluessel: (e) => e.id,
    filter: [
      ListenFilter(id: 'offen', titel: 'Offen', passt: (e) => !e.erledigt),
      ListenFilter(id: 'erledigt', titel: 'Erledigt', passt: (e) => e.erledigt),
    ],
    sortierer: {'titel': (a, b) => a.titel.compareTo(b.titel)},
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  Future<void> _neu() async {
    final gespeichert = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EintragFormular(api: widget.sitzung.api),
    ));
    if (gespeichert == true) await _liste.neuLaden();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RosenwegListe<Eintrag>(
          steuerung: _liste,
          suchHinweis: 'Eintrag suchen',
          leerText: 'Noch keine Einträge.',
          spalten: [
            ListenSpalte(id: 'titel', titel: 'Titel', text: (e) => e.titel, flex: 3, sortierbar: true),
            ListenSpalte(id: 'status', titel: 'Status', text: (e) => e.erledigt ? 'erledigt' : 'offen', flex: 1),
          ],
          kachel: (_, e) => ListTile(
            leading: Icon(e.erledigt ? Icons.check_circle_outline : Icons.radio_button_unchecked),
            title: Text(e.titel),
          ),
        ),
        // Nur mit Schreibrecht sichtbar (Technik/Praesident duerfen alles)
        floatingActionButton: NurMit(
          recht: eintraegeRecht,
          zugriff: Zugriff.schreiben,
          kind: FloatingActionButton.extended(onPressed: _neu, icon: const Icon(Icons.add), label: const Text('Neu')),
        ),
      );
}

class EintragFormular extends StatefulWidget {
  const EintragFormular({super.key, required this.api});
  final RosenwegApi api;

  @override
  State<EintragFormular> createState() => _EintragFormularState();
}

class _EintragFormularState extends State<EintragFormular> {
  final _titel = TextEditingController();

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Neuer Eintrag')),
        body: RosenwegInhalt(
          child: RosenwegFormular(
            speichern: () => widget.api.post('/api/beispiel/eintraege', {'titel': _titel.text.trim()}),
            gespeichert: () => Navigator.of(context).pop(true),
            felder: [
              TextFeld(name: 'titel', titel: 'Titel', controller: _titel, pflicht: true),
            ],
          ),
        ),
      );
}
