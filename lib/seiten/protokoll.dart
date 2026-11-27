// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';
import 'kartenprotokoll.dart';

/// Was ist passiert, und wie stehen die Tueren? Drei Ansichten, oben
/// umzuschalten:
///
///  * Zutritte: Ereignisse von UniFi Access (wer, welche Tuer, wann);
///    Kategorie Tueroeffnungen, Kritisch, Besucher, Admin
///  * Tueren: Live-Stand (verriegelt, offen, offline); Oeffnen mit Rueckfrage
///  * Karten: Kartenprotokoll der Haupt-API (zuordnen, entziehen, loeschen,
///    Anmeldungen, Admin mit Karte, Bestaetigungen)
class ProtokollSeite extends StatefulWidget {
  const ProtokollSeite({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<ProtokollSeite> createState() => _ProtokollSeiteState();
}

enum _Ansicht { zutritte, tueren, karten }

class _ProtokollSeiteState extends State<ProtokollSeite> {
  var _ansicht = _Ansicht.zutritte;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<_Ansicht>(
            segments: const [
              ButtonSegment(value: _Ansicht.zutritte, label: Text('Zutritte'), icon: Icon(Icons.login)),
              ButtonSegment(value: _Ansicht.tueren, label: Text('Türen'), icon: Icon(Icons.door_front_door_outlined)),
              ButtonSegment(value: _Ansicht.karten, label: Text('Karten'), icon: Icon(Icons.contactless_outlined)),
            ],
            selected: {_ansicht},
            showSelectedIcon: false,
            onSelectionChanged: (w) => setState(() => _ansicht = w.first),
          ),
        ),
        Expanded(
          child: switch (_ansicht) {
            _Ansicht.zutritte => ZutritteListe(key: const ValueKey('zutritte'), api: widget.api),
            _Ansicht.tueren => TuerenListe(key: const ValueKey('tueren'), api: widget.api),
            _Ansicht.karten => KartenprotokollListe(key: const ValueKey('karten'), api: widget.api),
          },
        ),
      ]);
}

/// Zutrittsprotokoll der letzten 7 Tage (GET /api/access/logs).
class ZutritteListe extends StatefulWidget {
  const ZutritteListe({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<ZutritteListe> createState() => _ZutritteListeState();
}

class _ZutritteListeState extends State<ZutritteListe> {
  static const themen = {
    'door_openings': 'Türöffnungen',
    'critical': 'Kritisch',
    'visitor': 'Besucher',
    'admin_activity': 'Admin',
  };
  var _thema = 'door_openings';

  late final _liste = ListenSteuerung<ZutrittsEreignis>.lokal(
    alle: () => widget.api.zutritte(thema: _thema),
    suchText: (e) => e.suchText,
    schluessel: (e) => e.schluessel,
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RosenwegListe<ZutrittsEreignis>(
        steuerung: _liste,
        suchHinweis: 'Person, Tür oder Ereignis suchen',
        leerText: 'In den letzten 7 Tagen nichts in dieser Kategorie.',
        leerSymbol: Icons.login,
        kopf: Wrap(spacing: 8, runSpacing: 4, children: [
          for (final t in themen.entries)
            ChoiceChip(
              label: Text(t.value),
              selected: _thema == t.key,
              onSelected: (_) {
                setState(() => _thema = t.key);
                _liste.neuLaden();
              },
            ),
        ]),
        spalten: [
          ListenSpalte(id: 'zeit', titel: 'Zeit', text: (e) => wannText(e.zeit), flex: 2),
          ListenSpalte(id: 'person', titel: 'Person', text: (e) => e.person ?? '', flex: 3),
          ListenSpalte(id: 'ereignis', titel: 'Ereignis', text: (e) => e.ereignis, flex: 3),
          ListenSpalte(id: 'tuer', titel: 'Tür', text: (e) => e.tuer ?? '', flex: 2),
        ],
        kachel: (_, e) => ListTile(
          leading: const Icon(Icons.login),
          title: Text([e.person ?? 'Unbekannt', if (e.tuer != null && e.tuer!.isNotEmpty) e.tuer!].join(' · ')),
          subtitle: Text('${e.ereignis}\n${wannText(e.zeit)}'),
          isThreeLine: true,
        ),
      );
}

/// Tueren mit Live-Stand (GET /api/access/doors), Oeffnen mit Rueckfrage.
class TuerenListe extends StatefulWidget {
  const TuerenListe({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<TuerenListe> createState() => _TuerenListeState();
}

class _TuerenListeState extends State<TuerenListe> {
  late final _liste = ListenSteuerung<Tuer>.lokal(
    alle: () => widget.api.tueren(),
    suchText: (t) => '${t.name} ${t.ganzerName ?? ''}',
    schluessel: (t) => t.id,
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  Future<void> _oeffnen(Tuer t) async {
    final ja = await frage(context, '${t.name} öffnen?', 'Die Tür wird für kurze Zeit entriegelt. Das steht im Zutrittsprotokoll.',
        ja: 'Öffnen');
    if (!ja || !mounted) return;
    try {
      await widget.api.tuerOeffnen(t.id);
      if (mounted) zeigeMeldung(context, '${t.name} ist entriegelt.');
    } on BestaetigungPerEmail catch (e) {
      if (mounted) await zeigeEmailBestaetigung(context, e);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    }
    await _liste.neuLaden();
  }

  Widget _symbol(BuildContext context, Tuer t) {
    final f = Theme.of(context).colorScheme;
    if (t.online == false) return Icon(Icons.cloud_off, color: f.outline, semanticLabel: 'offline');
    if (t.offen == true) return Icon(Icons.door_front_door, color: f.error, semanticLabel: 'steht offen');
    if (t.verriegelt == false) return const Icon(Icons.lock_open, color: RosenwegFarben.warnung, semanticLabel: 'entriegelt');
    return const Icon(Icons.lock, color: RosenwegFarben.gut, semanticLabel: 'verriegelt');
  }

  @override
  Widget build(BuildContext context) => RosenwegListe<Tuer>(
        steuerung: _liste,
        suchHinweis: 'Tür suchen',
        leerText: 'UniFi Access meldet keine Türen.',
        leerSymbol: Icons.door_front_door_outlined,
        kachel: (c, t) => ListTile(
          leading: _symbol(c, t),
          title: Text(t.name),
          subtitle: Text([if (t.ganzerName != null && t.ganzerName != t.name) t.ganzerName!, t.zustandText].where((x) => x.isNotEmpty).join('\n')),
          trailing: OutlinedButton(
            key: Key('oeffnen-${t.id}'),
            onPressed: t.online == false ? null : () => _oeffnen(t),
            child: const Text('Öffnen'),
          ),
        ),
      );
}
