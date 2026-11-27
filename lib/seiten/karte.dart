// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';

/// Karte hinhalten (Handy), auflegen (Station mit USB-Leser) oder Nummer
/// eintippen → wem gehoert sie; zuordnen, entziehen, aus dem Bestand
/// loeschen. Aus Rosenweg Karten uebernommen (Java-App und Karten 2.0).
class KarteSeite extends StatefulWidget {
  const KarteSeite({super.key, required this.karten, this.leser});
  final ZutrittApi karten;
  final Kartenleser? leser;

  @override
  State<KarteSeite> createState() => _KarteSeiteState();
}

class _KarteSeiteState extends State<KarteSeite> {
  Karte? _karte;
  String? _uid;
  bool _laeuft = false;
  String? _was; // „Wird nachgeschlagen …“
  Object? _fehler;
  ({String text, bool gut})? _meldung;
  List<Person>? _personen;
  List<OffeneBestaetigung> _offen = const [];

  @override
  void initState() {
    super.initState();
    _offeneLaden();
  }

  Future<void> _offeneLaden() async {
    try {
      final l = await widget.karten.offeneBestaetigungen();
      if (!mounted) return;
      setState(() => _offen = l);
    } catch (_) {
      // nur ein Hinweis – ohne ihn geht alles weiter
    }
  }

  Future<T?> _arbeit<T>(String was, Future<T> Function() f) async {
    setState(() {
      _laeuft = true;
      _was = was;
      _fehler = null;
      _meldung = null;
    });
    try {
      return await f();
    } on BestaetigungPerEmail catch (e) {
      if (mounted) {
        setState(() {
          _meldung = (text: e.text, gut: false);
          _laeuft = false;
          _was = null;
        });
        await zeigeEmailBestaetigung(context, e);
        _offeneLaden();
      }
      return null;
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _laeuft = false;
          _was = null;
        });
      }
    }
  }

  Future<void> _nachschlagen(String uid, {bool meldungBehalten = false}) async {
    final m = _meldung;
    setState(() {
      _uid = uid;
      _karte = null;
    });
    final k = await _arbeit('Karte wird nachgeschlagen …', () => widget.karten.nachschlagen(uid));
    if (!mounted) return;
    setState(() {
      _karte = k;
      if (meldungBehalten) _meldung = m;
    });
  }

  Future<void> _eintippen() async {
    final u = await uidEintippen(context);
    if (u != null && mounted) await _nachschlagen(u);
  }

  Future<void> _zuordnen() async {
    final k = _karte;
    if (k == null) return;
    var p = _personen;
    if (p == null) {
      p = await _arbeit('Personen werden geladen …', widget.karten.personen);
      if (p == null || !mounted) return;
      _personen = p;
    }
    final liste = p;
    final wahl = await auswahlSuchen<Person>(
      context,
      titel: 'Einer Person zuordnen',
      suchHinweis: 'Name oder E-Mail suchen',
      suchen: (q) async => liste.where((x) => x.passt(q)).toList(),
      text: (x) => x.name,
      untertitel: (x) => x.email,
    );
    if (wahl == null || !mounted) return;
    final ja = await frage(
      context,
      'Karte zuordnen?',
      'Karte ${k.kurzName} ${wahl.name} zuordnen?\n\n'
          'Sie öffnet danach die Türen dieser Person und meldet sie an den geteilten Telefonen und in den Apps an.',
      ja: 'Zuordnen',
    );
    if (!ja || !mounted) return;
    final r = await _arbeit('Wird zugeordnet …', () => widget.karten.zuordnen(k.uid, wahl.email));
    if (r == null || !mounted) return;
    _meldung = (
      text: r['schon'] == true ? 'War schon so zugeordnet.' : 'Zugeordnet. Die Türleser übernehmen das in etwa 30 Sekunden.',
      gut: true,
    );
    await _nachschlagen(k.uid, meldungBehalten: true);
  }

  Future<void> _entziehen() async {
    final k = _karte;
    if (k == null) return;
    final ja = await frage(
      context,
      'Karte entziehen?',
      'Karte ${k.kurzName} wird ${k.inhaber} entzogen. Sie öffnet danach keine Türen mehr und meldet niemanden mehr an. '
          'Sie bleibt im Bestand und lässt sich wieder zuordnen.',
      ja: 'Entziehen',
      gefaehrlich: true,
    );
    if (!ja || !mounted) return;
    final r = await _arbeit('Wird entzogen …', () => widget.karten.entziehen(k.uid));
    if (r == null || !mounted) return;
    _meldung = (text: r['schon'] == true ? 'War schon keiner Person zugeordnet.' : 'Entzogen.', gut: true);
    await _nachschlagen(k.uid, meldungBehalten: true);
  }

  Future<void> _loeschen() async {
    final k = _karte;
    if (k == null) return;
    final ja = await frage(
      context,
      'Karte aus dem Bestand löschen?',
      'Karte ${k.kurzName} wird aus UniFi Access gelöscht (defekt oder verloren). '
          'Sie lässt sich danach nur als neue Karte wieder zuordnen, mit neuer Inventarnummer.',
      ja: 'Löschen',
      gefaehrlich: true,
    );
    if (!ja || !mounted) return;
    final r = await _arbeit('Wird gelöscht …', () => widget.karten.loeschen(k.uid));
    if (r == null || !mounted) return;
    _meldung = (text: 'Aus dem Bestand gelöscht.', gut: true);
    await _nachschlagen(k.uid, meldungBehalten: true);
  }

  @override
  Widget build(BuildContext context) {
    final stufe = RechteBereich.vielleicht(context)?.stand?.stufe;
    final mitKarte = stufe == Anmeldestufe.karte;
    final hinweise = <Widget>[
      if (_offen.isNotEmpty)
        Hinweis(
          _offen.length == 1
              ? 'Wartet auf deine Bestätigung per E-Mail: ${_offen.first.text}.'
              : '${_offen.length} Aktionen warten auf deine Bestätigung per E-Mail.',
          art: HinweisArt.warnung,
        ),
      if (mitKarte)
        const Hinweis('Mit der Karte angemeldet: Jede Änderung wird protokolliert, und du bekommst eine Quittung per E-Mail. '
            'Heikle Aktionen laufen erst, wenn du sie in der E-Mail bestätigst.'),
    ];
    final leser = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      KartenleserBereich(
        key: const Key('leser'),
        leser: widget.leser,
        aktiv: !_laeuft,
        beiKarte: _nachschlagen,
      ),
      const SizedBox(height: 16),
      Center(
        child: TextButton.icon(
          onPressed: _laeuft ? null : _eintippen,
          icon: const Icon(Icons.keyboard),
          label: const Text('Nummer eintippen'),
        ),
      ),
    ]);
    final ergebnis = _Ergebnis(
      karte: _karte,
      uid: _uid,
      was: _was,
      fehler: _fehler,
      meldung: _meldung,
      laeuft: _laeuft,
      zuordnen: _zuordnen,
      entziehen: _entziehen,
      loeschen: _loeschen,
      nochmals: _uid == null ? null : () => _nachschlagen(_uid!),
    );
    final abstand = [for (final h in hinweise) Padding(padding: const EdgeInsets.only(bottom: 12), child: h)];
    return RosenwegSpalten(
      linksBreite: 400,
      links: ListView(padding: const EdgeInsets.all(16), children: [...abstand, leser]),
      rechts: ListView(padding: const EdgeInsets.all(16), children: [ergebnis]),
      schmal: ListView(padding: const EdgeInsets.all(16), children: [...abstand, leser, const SizedBox(height: 16), ergebnis]),
    );
  }
}

class _Ergebnis extends StatelessWidget {
  const _Ergebnis({
    required this.karte,
    required this.uid,
    required this.was,
    required this.fehler,
    required this.meldung,
    required this.laeuft,
    required this.zuordnen,
    required this.entziehen,
    required this.loeschen,
    required this.nochmals,
  });
  final Karte? karte;
  final String? uid;
  final String? was;
  final Object? fehler;
  final ({String text, bool gut})? meldung;
  final bool laeuft;
  final VoidCallback zuordnen;
  final VoidCallback entziehen;
  final VoidCallback loeschen;
  final VoidCallback? nochmals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final k = karte;
    final teile = <Widget>[
      if (meldung != null) ...[
        Hinweis(meldung!.text, art: meldung!.gut ? HinweisArt.gut : HinweisArt.warnung),
        const SizedBox(height: 12),
      ],
      if (fehler != null) ...[
        FehlerAnzeige.aus(fehler!, nochmals: nochmals),
        const SizedBox(height: 12),
      ],
      if (was != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(was!, style: t.titleMedium),
          ]),
        ),
      if (k == null && uid == null && was == null && fehler == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Noch keine Karte gelesen.', textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: f.outline)),
        ),
      if (k != null)
        Abschnitt(
          titel: k.inhaber,
          symbol: k.hatInhaber ? Icons.person : Icons.credit_card_off_outlined,
          kind: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (k.personEmail != null && k.personName != null)
              ListTile(dense: true, leading: const Icon(Icons.mail_outline), title: Text(k.personEmail!)),
            ListTile(dense: true, leading: const Icon(Icons.tag), title: Text(k.nummerText)),
            ListTile(
              dense: true,
              leading: Icon(k.zugeordnet ? Icons.lock_open : Icons.info_outline),
              title: Text(k.zustandText, key: const Key('zustand')),
            ),
            ListTile(dense: true, leading: const Icon(Icons.contactless_outlined), title: SelectableText('UID ${k.uid}')),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, children: [
              // Gehoert sie jemandem, zuerst entziehen (sonst lehnt die Haupt-API ab)
              if (!k.hatInhaber)
                FilledButton.icon(
                  key: const Key('zuordnen'),
                  onPressed: laeuft ? null : zuordnen,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Einer Person zuordnen'),
                ),
              if (k.bekannt && k.hatInhaber)
                OutlinedButton.icon(
                  key: const Key('entziehen'),
                  onPressed: laeuft ? null : entziehen,
                  icon: const Icon(Icons.person_remove_alt_1),
                  label: const Text('Entziehen'),
                ),
              if (k.loeschbar)
                OutlinedButton.icon(
                  key: const Key('loeschen'),
                  style: OutlinedButton.styleFrom(foregroundColor: f.error),
                  onPressed: laeuft ? null : loeschen,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Aus dem Bestand löschen'),
                ),
            ]),
          ]),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: teile);
  }
}
