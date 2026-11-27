// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';
import 'anlernen.dart';

/// Benutzer in UniFi Access: suchen, antippen = alles zu dieser Person
/// (Angaben und PIN, Karten, Zugangsregeln); „Neue Person“ unten rechts.
class PersonenSeite extends StatefulWidget {
  const PersonenSeite({super.key, required this.api, this.leser});
  final ZutrittApi api;
  final Kartenleser? leser;

  @override
  State<PersonenSeite> createState() => _PersonenSeiteState();
}

class _PersonenSeiteState extends State<PersonenSeite> {
  late final _liste = ListenSteuerung<AccessBenutzer>.lokal(
    alle: () => widget.api.benutzer(),
    suchText: (b) => b.suchText,
    schluessel: (b) => b.id,
    filter: [
      ListenFilter(id: 'ohne', titel: 'Ohne Karte', passt: (b) => b.karten.isEmpty),
      ListenFilter(id: 'gesperrt', titel: 'Gesperrt', passt: (b) => !b.aktiv),
    ],
    sortierer: {'name': (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())},
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  Future<void> _oeffnen(AccessBenutzer? b) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonSeite(api: widget.api, id: b?.id, leser: widget.leser),
    ));
    await _liste.neuLaden();
  }

  static String _kurz(AccessBenutzer b) => [
        b.karten.isEmpty ? 'keine Karte' : (b.karten.length == 1 ? '1 Karte' : '${b.karten.length} Karten'),
        if (b.pinGesetzt) 'PIN',
        if (!b.aktiv) b.statusText,
      ].join(' · ');

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('neue-person'),
          onPressed: () => _oeffnen(null),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Neue Person'),
        ),
        body: RosenwegListe<AccessBenutzer>(
          steuerung: _liste,
          suchHinweis: 'Name oder E-Mail suchen',
          leerText: 'UniFi Access kennt noch keine Personen.',
          leerSymbol: Icons.people_outline,
          spalten: [
            ListenSpalte(id: 'name', titel: 'Name', text: (b) => b.name, flex: 3, sortierbar: true),
            ListenSpalte(id: 'email', titel: 'E-Mail', text: (b) => b.email, flex: 3),
            ListenSpalte(id: 'karten', titel: 'Karten und PIN', text: _kurz, flex: 2),
          ],
          kachel: (c, b) => ListTile(
            leading: Icon(b.aktiv ? Icons.person : Icons.person_off_outlined),
            title: Text(b.name),
            subtitle: Text([if (b.email.isNotEmpty) b.email, _kurz(b)].join('\n')),
            isThreeLine: b.email.isNotEmpty,
          ),
          antippen: _oeffnen,
        ),
      );
}

/// Eine Person in UniFi Access. Ohne [id]: neue Person (nur Angaben; Karten
/// und Zugang danach).
class PersonSeite extends StatefulWidget {
  const PersonSeite({super.key, required this.api, this.id, this.leser});
  final ZutrittApi api;
  final String? id;
  final Kartenleser? leser;

  @override
  State<PersonSeite> createState() => _PersonSeiteState();
}

class _PersonSeiteState extends State<PersonSeite> {
  AccessBenutzer? _b;
  List<Zugangsregel>? _regeln;
  Set<String> _meine = {};
  Object? _fehler;
  bool _laedt = false;
  bool _arbeitet = false;

  final _vorname = TextEditingController();
  final _nachname = TextEditingController();
  final _email = TextEditingController();
  final _pin = TextEditingController();

  bool get _neu => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (!_neu) _laden();
  }

  @override
  void dispose() {
    for (final c in [_vorname, _nachname, _email, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final alle = await widget.api.benutzer();
      final b = alle.firstWhere((x) => x.id == widget.id, orElse: () => throw ApiFehler(404, 'Diese Person gibt es in UniFi Access nicht mehr.'));
      final regeln = await widget.api.zugangsregeln();
      final meine = await widget.api.regelnVon(b.id);
      if (!mounted) return;
      setState(() {
        _b = b;
        _regeln = regeln;
        _meine = meine;
        _vorname.text = b.vorname;
        _nachname.text = b.nachname;
        _email.text = b.email;
        _pin.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  Future<void> _speichern() async {
    await widget.api.benutzerSpeichern(
      id: widget.id,
      vorname: _vorname.text.trim(),
      nachname: _nachname.text.trim(),
      email: _email.text.trim().toLowerCase(),
      pin: _pin.text.trim(),
    );
  }

  /// Aktion mit Rueckmeldung; 202 = Bestaetigung per E-Mail.
  Future<void> _tun(Future<void> Function() f, String ok) async {
    setState(() => _arbeitet = true);
    try {
      await f();
      if (mounted) zeigeMeldung(context, ok);
    } on BestaetigungPerEmail catch (e) {
      if (mounted) await zeigeEmailBestaetigung(context, e);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    } finally {
      if (mounted) setState(() => _arbeitet = false);
    }
    if (mounted) await _laden();
  }

  Future<void> _karteEntfernen(AccessKarte k) async {
    final b = _b!;
    final ja = await frage(context, '${k.bezeichnung} entfernen?',
        '${b.name} kann mit dieser Karte danach keine Türen mehr öffnen und sich nicht mehr damit anmelden. '
            'Die Karte bleibt im Bestand und lässt sich wieder zuordnen.',
        ja: 'Entfernen', gefaehrlich: true);
    if (!ja || !mounted) return;
    await _tun(() => widget.api.karteEntfernen(b.id, k.token), 'Karte entfernt.');
  }

  Future<void> _anlernen() async {
    if (await karteAmLeserAnlernen(context, widget.api, _b!) && mounted) await _laden();
  }

  /// Karte mit dem Handy (NFC) bzw. dem USB-Leser der Station lesen und
  /// ueber /api/karten/zuordnen geben (legt unbekannte Karten in Access an).
  Future<void> _lesenUndGeben() async {
    final b = _b!;
    final uid = await karteLesen(context,
        titel: 'Karte für ${b.name}', hinweis: 'Die neue Karte hinhalten bzw. auflegen.', eintippen: true, leser: widget.leser);
    if (uid == null || !mounted) return;
    await _tun(() async {
      final r = await widget.api.zuordnen(uid, b.email);
      if (r['schon'] == true) throw ApiFehler(200, 'Diese Karte gehört schon ${b.name}.');
    }, 'Karte ${b.name} gegeben.');
  }

  Future<void> _regelUmschalten(Zugangsregel r, bool an) async {
    final b = _b!;
    final neu = {..._meine};
    an ? neu.add(r.id) : neu.remove(r.id);
    setState(() => _meine = neu);
    await _tun(() => widget.api.regelnSetzen(b.id, neu), an ? '${r.name} erlaubt.' : '${r.name} entzogen.');
  }

  Future<void> _loeschen() async {
    final b = _b!;
    if (!await loeschenBestaetigen(context, b.name,
        text: '${b.name} wird aus UniFi Access gelöscht – mit allen Karten-Zuordnungen und der PIN. Die Türen öffnen danach nicht mehr.')) {
      return;
    }
    try {
      await widget.api.benutzerLoeschen(b.id);
      if (mounted) {
        zeigeMeldung(context, '${b.name} gelöscht.');
        Navigator.pop(context);
      }
    } on BestaetigungPerEmail catch (e) {
      if (mounted) await zeigeEmailBestaetigung(context, e);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final Widget inhalt;
    if (_fehler != null && b == null) {
      inhalt = FehlerAnzeige.aus(_fehler!, nochmals: _laden);
    } else if (!_neu && b == null) {
      inhalt = const LadeAnzeige();
    } else {
      inhalt = ListView(padding: const EdgeInsets.all(16), children: [
        Abschnitt(
          titel: 'Angaben',
          symbol: Icons.badge_outlined,
          kind: RosenwegFormular(
            scrollen: false,
            gespeichertText: _neu ? 'Person angelegt.' : 'Gespeichert.',
            speichern: _speichern,
            gespeichert: () => _neu ? Navigator.pop(context) : _laden(),
            felder: [
              TextFeld(name: 'first_name', titel: 'Vorname', controller: _vorname, pflicht: true),
              TextFeld(name: 'last_name', titel: 'Nachname', controller: _nachname),
              TextFeld(
                name: 'email',
                titel: 'E-Mail',
                controller: _email,
                tastatur: TextInputType.emailAddress,
                hinweis: 'Wie im Rosenweg-Konto – darüber findet die Karte die Person.',
                pruefen: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(v!.trim()) ? null : 'Keine gültige E-Mail.',
              ),
              TextFeld(
                name: 'pin_code',
                titel: 'PIN für die Türen',
                controller: _pin,
                verdeckt: true,
                tastatur: TextInputType.number,
                hinweis: _neu ? 'Nur Ziffern; leer = ohne PIN' : (b!.pinGesetzt ? 'Gesetzt. Leer lassen = unverändert.' : 'Keine PIN. Nur Ziffern.'),
                pruefen: (v) => (v ?? '').isEmpty || RegExp(r'^\d{4,8}$').hasMatch(v!) ? null : '4 bis 8 Ziffern.',
              ),
            ],
          ),
        ),
        if (b != null) ...[
          const SizedBox(height: 16),
          Abschnitt(
            titel: 'Karten',
            symbol: Icons.contactless_outlined,
            kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (b.karten.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Noch keine Karte.')),
              for (final k in b.karten)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.credit_card),
                  title: Text(k.bezeichnung),
                  trailing: IconButton(
                    tooltip: 'Karte entfernen',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _arbeitet ? null : () => _karteEntfernen(k),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton.icon(
                  key: const Key('anlernen'),
                  onPressed: _arbeitet ? null : _anlernen,
                  icon: const Icon(Icons.nfc),
                  label: const Text('Am UniFi-Leser anlernen'),
                ),
                OutlinedButton.icon(
                  key: const Key('lesen'),
                  onPressed: _arbeitet || b.email.isEmpty ? null : _lesenUndGeben,
                  icon: const Icon(Icons.contactless),
                  label: const Text('Mit diesem Gerät lesen'),
                ),
              ]),
              if (b.email.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Hinweis('Ohne E-Mail lässt sich keine Karte mit diesem Gerät zuordnen – am UniFi-Leser geht es.'),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Abschnitt(
            titel: 'Zugang',
            symbol: Icons.door_front_door_outlined,
            erklaerung: 'Welche Türen zu welchen Zeiten (Zugangsregeln in UniFi Access).',
            kind: Column(children: [
              if ((_regeln ?? const []).isEmpty) const Text('In UniFi Access sind keine Zugangsregeln angelegt.'),
              for (final r in _regeln ?? const <Zugangsregel>[])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _meine.contains(r.id),
                  title: Text(r.name),
                  onChanged: _arbeitet ? null : (v) => _regelUmschalten(r, v ?? false),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: _arbeitet ? null : _loeschen,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Person aus UniFi Access löschen'),
            ),
          ),
        ],
      ]);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_neu ? 'Neue Person' : (b?.name ?? 'Person')),
        bottom: _laedt || _arbeitet ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: inhalt)),
    );
  }
}
