// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';

/// Karten-, QR- und Handy-Anmeldungen der Rosenweg-Apps aller Personen
/// (GET /api/apps/sitzungen?alle=1, wie unter „Profil“ im Portal). Eine
/// abmelden oder alle Apps einer Person (Karte verloren).
///
/// Karte = Schluessel (Stefan, 27.11.2026): das geht auch mit der Karte; die
/// Haupt-API protokolliert es dann (admin-mit-karte) und schickt eine Quittung.
class AnmeldungenSeite extends StatefulWidget {
  const AnmeldungenSeite({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<AnmeldungenSeite> createState() => _AnmeldungenSeiteState();
}

class _AnmeldungenSeiteState extends State<AnmeldungenSeite> {
  late final _liste = ListenSteuerung<AppSitzung>.lokal(
    alle: () => widget.api.sitzungen(),
    suchText: (s) => s.suchText,
    schluessel: (s) => s.id,
    filter: [
      ListenFilter(id: 'karte', titel: 'Karte', passt: (s) => s.art == 'karte'),
      ListenFilter(id: 'qr', titel: 'QR-Code', passt: (s) => s.art == 'qr'),
      ListenFilter(id: 'handy', titel: 'Mit dem Handy', passt: (s) => s.art == 'handy'),
    ],
    sortierer: {'name': (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())},
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  Future<void> _abmelden(AppSitzung s) async {
    final ja = await frage(context, 'Abmelden?', '${s.app} auf „${s.geraet}“ von ${s.name} wird abgemeldet. '
        'Dort muss die Person die Karte wieder hinhalten oder sich mit dem Konto anmelden.',
        ja: 'Abmelden', gefaehrlich: true);
    if (!ja || !mounted) return;
    await _tun(() => widget.api.sitzungBeenden(s.id), 'Abgemeldet.');
  }

  Future<void> _alleAbmelden(AppSitzung s) async {
    final ja = await frage(context, 'Alle Apps abmelden?',
        'Alle Karten-, QR- und Handy-Anmeldungen von ${s.name} (${s.email}) werden beendet – auf allen Geräten. '
            'Zum Beispiel, wenn die Karte verloren ist.',
        ja: 'Alle abmelden', gefaehrlich: true);
    if (!ja || !mounted) return;
    await _tun(() => widget.api.alleAbmelden(s.email), 'Alle Apps von ${s.name} abgemeldet.');
  }

  Future<void> _tun(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (!mounted) return;
      zeigeMeldung(context, ok);
      await _liste.neuLaden();
    } on BestaetigungPerEmail catch (e) {
      if (mounted) await zeigeEmailBestaetigung(context, e);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    }
  }

  void _details(AppSitzung s) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            Text(s.name, style: Theme.of(c).textTheme.titleLarge),
            Text(s.email),
            const SizedBox(height: 8),
            ListTile(dense: true, leading: const Icon(Icons.apps), title: Text(s.app), subtitle: Text(s.geraet)),
            ListTile(dense: true, leading: const Icon(Icons.contactless_outlined), title: Text('Angemeldet ${s.artText}')),
            ListTile(dense: true, leading: const Icon(Icons.schedule), title: Text('Zuletzt ${wannText(s.zuletzt ?? s.erstellt)}'),
                subtitle: Text('Gilt bis ${wannText(s.ablauf)}')),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                _abmelden(s);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Diese Anmeldung beenden'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(c);
                _alleAbmelden(s);
              },
              icon: const Icon(Icons.phonelink_erase),
              label: const Text('Alle Apps dieser Person abmelden'),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => RosenwegListe<AppSitzung>(
        steuerung: _liste,
        suchHinweis: 'Person, App oder Gerät suchen',
        leerText: 'Keine Karten-, QR- oder Handy-Anmeldungen.',
        leerSymbol: Icons.devices_other,
        spalten: [
          ListenSpalte(id: 'name', titel: 'Person', text: (s) => s.name, flex: 3, sortierbar: true),
          ListenSpalte(id: 'app', titel: 'App', text: (s) => s.app, flex: 2),
          ListenSpalte(id: 'geraet', titel: 'Gerät', text: (s) => s.geraet, flex: 2),
          ListenSpalte(id: 'art', titel: 'Mit', text: (s) => s.artText, flex: 2),
          ListenSpalte(id: 'zuletzt', titel: 'Zuletzt', text: (s) => wannText(s.zuletzt ?? s.erstellt), flex: 2),
        ],
        kachel: (_, s) => ListTile(
          leading: Icon(switch (s.art) { 'qr' => Icons.qr_code, 'handy' => Icons.smartphone, _ => Icons.contactless }),
          title: Text(s.name),
          subtitle: Text('${s.app} · ${s.geraet}\n${s.artText} · zuletzt ${wannText(s.zuletzt ?? s.erstellt)}'),
          isThreeLine: true,
        ),
        antippen: _details,
      );
}
