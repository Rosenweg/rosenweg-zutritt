// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';

/// Besucher-Paesse (temporaerer Zutritt in UniFi Access): Liste, neuer Pass
/// mit Zeitraum und Tueren, loeschen.
class BesucherSeite extends StatefulWidget {
  const BesucherSeite({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<BesucherSeite> createState() => _BesucherSeiteState();
}

class _BesucherSeiteState extends State<BesucherSeite> {
  late final _liste = ListenSteuerung<BesucherPass>.lokal(
    alle: () => widget.api.besucher(),
    suchText: (v) => '${v.name} ${v.bemerkung ?? ''}',
    schluessel: (v) => v.id,
    filter: [
      ListenFilter(id: 'aktuell', titel: 'Aktuell und kommend', passt: (v) => v.bis == null || v.bis!.isAfter(DateTime.now())),
    ],
    filterAn: const {'aktuell'},
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  Future<void> _neu() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NeuerPassSeite(api: widget.api)));
    await _liste.neuLaden();
  }

  Future<void> _loeschen(BesucherPass v) async {
    if (!await loeschenBestaetigen(context, 'den Pass von ${v.name}', text: 'Der Pass gilt danach nicht mehr.')) return;
    try {
      await widget.api.besucherLoeschen(v.id);
      if (mounted) zeigeMeldung(context, 'Pass gelöscht.');
    } on BestaetigungPerEmail catch (e) {
      if (mounted) await zeigeEmailBestaetigung(context, e);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    }
    await _liste.neuLaden();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('neuer-pass'),
          onPressed: _neu,
          icon: const Icon(Icons.add),
          label: const Text('Neuer Pass'),
        ),
        body: RosenwegListe<BesucherPass>(
          steuerung: _liste,
          suchHinweis: 'Name suchen',
          leerText: 'Keine Besucher-Pässe.',
          leerSymbol: Icons.badge_outlined,
          spalten: [
            ListenSpalte(id: 'name', titel: 'Name', text: (v) => v.name, flex: 3),
            ListenSpalte(id: 'zeit', titel: 'Zeitraum', text: (v) => v.zeitraum, flex: 4),
            ListenSpalte(id: 'status', titel: 'Stand', text: (v) => v.statusText, flex: 2),
            ListenSpalte(
              id: 'weg',
              titel: '',
              breite: 64,
              zelle: (_, v) => IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: () => _loeschen(v)),
            ),
          ],
          kachel: (_, v) => ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(v.name),
            subtitle: Text([v.zeitraum, if (v.statusText.isNotEmpty) v.statusText, if (v.bemerkung != null) v.bemerkung!].join('\n')),
            isThreeLine: true,
            trailing: IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: () => _loeschen(v)),
          ),
        ),
      );
}

/// Neuer Besucher-Pass: Name, von – bis, Tueren (leer = wie in UniFi Access
/// fuer Besucher voreingestellt), Bemerkung.
class NeuerPassSeite extends StatefulWidget {
  const NeuerPassSeite({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<NeuerPassSeite> createState() => _NeuerPassSeiteState();
}

class _NeuerPassSeiteState extends State<NeuerPassSeite> {
  final _vorname = TextEditingController();
  final _nachname = TextEditingController();
  final _bemerkung = TextEditingController();
  late DateTime _vonTag;
  late TimeOfDay _vonZeit;
  late DateTime _bisTag;
  late TimeOfDay _bisZeit;
  List<Tuer>? _tueren;
  final _gewaehlt = <String>{};

  @override
  void initState() {
    super.initState();
    final jetzt = DateTime.now();
    final von = DateTime(jetzt.year, jetzt.month, jetzt.day, jetzt.hour);
    final bis = von.add(const Duration(hours: 4));
    _vonTag = DateTime(von.year, von.month, von.day);
    _vonZeit = TimeOfDay.fromDateTime(von);
    _bisTag = DateTime(bis.year, bis.month, bis.day);
    _bisZeit = TimeOfDay.fromDateTime(bis);
    widget.api.tueren().then((t) {
      if (mounted) setState(() => _tueren = t);
    }, onError: (_) {
      if (mounted) setState(() => _tueren = const []);
    });
  }

  @override
  void dispose() {
    for (final c in [_vorname, _nachname, _bemerkung]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _zusammen(DateTime tag, TimeOfDay z) => DateTime(tag.year, tag.month, tag.day, z.hour, z.minute);

  Future<void> _speichern() async {
    final von = _zusammen(_vonTag, _vonZeit);
    final bis = _zusammen(_bisTag, _bisZeit);
    if (!bis.isAfter(von)) throw ApiFehler(400, '„Bis“ muss nach „Von“ liegen.');
    await widget.api.besucherAnlegen(
      vorname: _vorname.text.trim(),
      nachname: _nachname.text.trim(),
      von: von,
      bis: bis,
      bemerkung: _bemerkung.text.trim(),
      tueren: _gewaehlt,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Neuer Besucher-Pass')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RosenwegFormular(
              speichernText: 'Pass anlegen',
              gespeichertText: 'Besucher-Pass angelegt.',
              speichern: _speichern,
              gespeichert: () => Navigator.pop(context),
              felder: [
                TextFeld(name: 'first_name', titel: 'Vorname', controller: _vorname, pflicht: true, autofokus: true),
                TextFeld(name: 'last_name', titel: 'Nachname', controller: _nachname),
                Row(children: [
                  Expanded(child: DatumFeld(titel: 'Von (Tag)', wert: _vonTag, pflicht: true, geaendert: (d) => setState(() => _vonTag = d ?? _vonTag))),
                  const SizedBox(width: 12),
                  Expanded(child: ZeitFeld(titel: 'Uhrzeit', wert: _vonZeit, pflicht: true, geaendert: (z) => setState(() => _vonZeit = z ?? _vonZeit))),
                ]),
                Row(children: [
                  Expanded(child: DatumFeld(titel: 'Bis (Tag)', wert: _bisTag, pflicht: true, geaendert: (d) => setState(() => _bisTag = d ?? _bisTag))),
                  const SizedBox(width: 12),
                  Expanded(child: ZeitFeld(titel: 'Uhrzeit', wert: _bisZeit, pflicht: true, geaendert: (z) => setState(() => _bisZeit = z ?? _bisZeit))),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Türen', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Keine gewählt: wie in UniFi Access für Besucher voreingestellt.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  if (_tueren == null)
                    const LinearProgressIndicator()
                  else
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final t in _tueren!)
                        FilterChip(
                          label: Text(t.name),
                          selected: _gewaehlt.contains(t.id),
                          onSelected: (an) => setState(() => an ? _gewaehlt.add(t.id) : _gewaehlt.remove(t.id)),
                        ),
                    ]),
                ]),
                TextFeld(name: 'remarks', titel: 'Bemerkung', controller: _bemerkung, zeilen: 2, hinweis: 'z. B. wofür der Besuch kommt'),
              ],
            ),
          ),
        ),
      );
}
