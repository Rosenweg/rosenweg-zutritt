// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_zutritt/app.dart';
import 'package:rosenweg_zutritt/attrappe.dart';
import 'package:rosenweg_zutritt/daten.dart';
import 'package:rosenweg_zutritt/seiten/anlernen.dart';
import 'package:rosenweg_zutritt/zutritt_api.dart';
import 'package:rosenweg_zutritt/seiten/haupt.dart';

import 'test_leser.dart';

void main() {
  setUpAll(() => Protokoll.nurKonsole = true);

  Future<({Attrappe a, TestLeser l})> zeigen(WidgetTester t, Size groesse, {List<String> gruppen = const ['technik']}) async {
    t.view.physicalSize = groesse;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final a = Attrappe(gruppen: gruppen);
    final l = TestLeser();
    final s = RosenwegSitzung(appAngaben, transport: a);
    await s.starten();
    await t.pumpWidget(RosenwegRahmen(sitzung: s, inhalt: (_) => Haupt(sitzung: s, leser: l)));
    await t.pumpAndSettle();
    return (a: a, l: l);
  }

  Future<void> auflegen(WidgetTester t, TestLeser l, String uid) async {
    l.auflegen(uid);
    await t.pump();
    await t.pumpAndSettle();
  }

  testWidgets('Karte auflegen: zugeordnet, Inhaber und Nummer, nur „Entziehen“', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    expect(find.text('Karte an die Rückseite des Handys halten.'), findsOneWidget);
    await auflegen(t, x.l, '04A1B2C3D4E5F6');
    expect(find.text('Erika Muster'), findsOneWidget);
    expect(find.text('Inventarnummer 0042'), findsOneWidget);
    expect(find.byKey(const Key('entziehen')), findsOneWidget);
    expect(find.byKey(const Key('zuordnen')), findsNothing);
    expect(find.byKey(const Key('loeschen')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Unbekannte Karte einer Person zuordnen, dann entziehen und löschen', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    await auflegen(t, x.l, '0a:0b:0c:0d');
    expect(find.text('Unbekannte Karte'), findsOneWidget);
    expect(find.text('Nicht in UniFi Access'), findsOneWidget);

    await t.tap(find.byKey(const Key('zuordnen')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'lea');
    await t.pumpAndSettle();
    await t.tap(find.text('Lea Probe'));
    await t.pumpAndSettle();
    expect(find.text('Karte zuordnen?'), findsOneWidget);
    await t.tap(find.text('Zuordnen'));
    await t.pumpAndSettle();
    expect(find.textContaining('Zugeordnet. Die Türleser'), findsOneWidget);
    expect(find.text('Lea Probe'), findsOneWidget);
    final z = x.a.anfragen.firstWhere((r) => r.pfad == '/api/karten/zuordnen');
    expect(z.koerper, {'uid': '0A0B0C0D', 'email': 'lea.probe@example.org'});

    await t.tap(find.byKey(const Key('entziehen')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Entziehen'));
    await t.pumpAndSettle();
    expect(find.text('Entzogen.'), findsOneWidget);
    expect(find.text('Frei – keiner Person zugeordnet'), findsOneWidget);

    await t.tap(find.byKey(const Key('loeschen')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await t.pumpAndSettle();
    expect(find.text('Aus dem Bestand gelöscht.'), findsOneWidget);
    expect(find.text('Unbekannte Karte'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Mit der Karte heikle Aktion: 202 zeigt „Bestätigung per E-Mail nötig“', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    await auflegen(t, x.l, '04A1B2C3D4E5F6');
    x.a.erzwungen['POST /api/karten/entziehen'] = (
      status: 202,
      json: {
        'bestaetigung': 'email',
        'id': 'kb_1',
        'email': 'm…@example.org',
        'ablauf': '2026-11-27T18:15:00Z',
        'hinweis': 'Bitte bestätige in der E-Mail, die wir dir an m…@example.org geschickt haben. Der Link gilt 15 Minuten.',
      },
    );
    await t.tap(find.byKey(const Key('entziehen')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Entziehen'));
    await t.pumpAndSettle();
    expect(find.text('Bestätigung per E-Mail nötig'), findsOneWidget);
    await t.tap(find.text('Verstanden'));
    await t.pumpAndSettle();
    expect(find.textContaining('m…@example.org'), findsOneWidget);
    // nichts passiert: Karte gehoert weiter Erika
    expect(find.text('Erika Muster'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Ohne Technik/Präsident: klare Meldung statt Kartenleser', (t) async {
    await zeigen(t, const Size(412, 900), gruppen: const ['stweg3-eigentuemer']);
    expect(find.text('Rosenweg Zutritt ist nur für Technik und Präsident.'), findsOneWidget);
    expect(find.byKey(const Key('leser')), findsNothing);
  });

  testWidgets('Station: Leiste links, Leser und Ergebnis nebeneinander', (t) async {
    final x = await zeigen(t, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    await auflegen(t, x.l, '04112233445566');
    expect(find.text('Inventarnummer 0107'), findsOneWidget);
    expect(find.byKey(const Key('loeschen')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Protokoll und Anmeldungen: Liste, Filter, alle Apps einer Person abmelden', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    await t.tap(find.text('Protokoll'));
    await t.pumpAndSettle();
    await t.tap(find.text('Karten').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Admin mit Karte'), findsWidgets);
    await t.tap(find.widgetWithText(FilterChip, 'Fehlgeschlagen'));
    await t.pumpAndSettle();
    expect(find.textContaining('Entzogen'), findsOneWidget);
    expect(find.textContaining('Zugeordnet'), findsNothing);

    await t.tap(find.text('Anmeldungen'));
    await t.pumpAndSettle();
    expect(find.text('Erika Muster'), findsOneWidget);
    await t.tap(find.text('Erika Muster'));
    await t.pumpAndSettle();
    await t.tap(find.text('Alle Apps dieser Person abmelden'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Alle abmelden'));
    await t.pumpAndSettle();
    expect(find.text('Erika Muster'), findsNothing);
    expect(x.a.anfragen.any((r) => r.pfad == '/api/apps/sitzungen/alle-abmelden'), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  test('Karte aus der Antwort der Haupt-API', () {
    final k = Karte.aus('04AA', {'found': true, 'assigned': false, 'status': 'UNASSIGNED', 'display_id': null, 'access_name': null});
    expect(k.zustandText, 'Frei – keiner Person zugeordnet');
    expect(k.nummerText, 'Ohne Inventarnummer');
    expect(k.loeschbar, isTrue);
    expect(Karte.aus('04AA', {'found': false}).loeschbar, isFalse);
  });

  test('Kennung, Ordner und Logo passen zusammen', () {
    expect(appAngaben.kennung, 'ch.rosenweg4303.zutritt');
    expect(File('assets/logo/${appAngaben.ordner}-512.png').existsSync(), isTrue);
    expect(File('assets/logo/${appAngaben.ordner}-klein.png').existsSync(), isTrue);
  });

  testWidgets('Personen: suchen, Zugangsregel setzen, Karte am UniFi-Leser anlernen, Karte entfernen', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    AnlernDialog.takt = const Duration(milliseconds: 100);
    await t.tap(find.text('Personen'));
    await t.pumpAndSettle();
    expect(find.text('Lea Probe'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'max');
    await t.pumpAndSettle();
    expect(find.text('Lea Probe'), findsNothing);
    await t.tap(find.text('Max Beispiel'));
    await t.pumpAndSettle();
    expect(find.text('Noch keine Karte.'), findsOneWidget);

    // Zugangsregel Velokeller dazu
    await t.ensureVisible(find.widgetWithText(CheckboxListTile, 'Velokeller'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CheckboxListTile, 'Velokeller'));
    await t.pumpAndSettle();
    final p = x.a.anfragen.lastWhere((r) => r.methode == 'PUT' && r.pfad == '/api/access/users/u-max/policies');
    expect((p.koerper as Map)['access_policy_ids'], unorderedEquals(['p-haus', 'p-keller']));

    // am UniFi-Leser anlernen: zwei Leser -> waehlen, Karte liegt beim zweiten Nachfragen auf
    await t.ensureVisible(find.byKey(const Key('anlernen')));
    await t.tap(find.byKey(const Key('anlernen')));
    await t.pumpAndSettle();
    await t.tap(find.text('Schlüsselkasten UG'));
    await t.pump();
    expect(find.textContaining('an den Leser „Schlüsselkasten UG“ halten'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
    await t.pumpAndSettle();
    final z = x.a.anfragen.lastWhere((r) => r.pfad == '/api/access/users/u-max/nfc');
    expect(z.koerper, {'token': 'tok-neu-0310'});
    expect(find.text('Karte 0310'), findsOneWidget);

    // wieder entfernen
    await t.tap(find.byTooltip('Karte entfernen'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Entfernen'));
    await t.pumpAndSettle();
    expect(find.text('Noch keine Karte.'), findsOneWidget);
    expect(x.a.anfragen.any((r) => r.methode == 'DELETE' && r.pfad == '/api/access/users/u-max/nfc/tok-neu-0310'), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Personen: Karte mit diesem Gerät lesen geht über /api/karten/zuordnen', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    await t.tap(find.text('Personen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Lea Probe'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('lesen')));
    await t.tap(find.byKey(const Key('lesen')));
    await t.pumpAndSettle();
    x.l.auflegen('04112233445566');
    await t.pump();
    await t.pumpAndSettle();
    final z = x.a.anfragen.lastWhere((r) => r.pfad == '/api/karten/zuordnen');
    expect(z.koerper, {'uid': '04112233445566', 'email': 'lea.probe@example.org'});
    expect(find.text('Karte 0107'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Neue Person anlegen', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    await t.tap(find.text('Personen'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('neue-person')));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Vorname *'), 'Tim');
    await t.enterText(find.widgetWithText(TextFormField, 'Nachname'), 'Test');
    await t.enterText(find.widgetWithText(TextFormField, 'E-Mail'), 'tim.test@example.org');
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(find.text('Tim Test'), findsOneWidget);
    final n = x.a.anfragen.lastWhere((r) => r.methode == 'POST' && r.pfad == '/api/access/users');
    expect(n.koerper, {'first_name': 'Tim', 'last_name': 'Test', 'email': 'tim.test@example.org'});
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Besucher: neuen Pass mit Tür anlegen, löschen', (t) async {
    final x = await zeigen(t, const Size(1280, 900));
    await t.tap(find.text('Besucher'));
    await t.pumpAndSettle();
    expect(find.text('Paul Handwerk'), findsOneWidget);
    await t.tap(find.byKey(const Key('neuer-pass')));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Vorname *'), 'Ida');
    await t.enterText(find.widgetWithText(TextFormField, 'Nachname'), 'Besuch');
    await t.tap(find.widgetWithText(FilterChip, 'Velokeller'));
    await t.pumpAndSettle();
    await t.tap(find.text('Pass anlegen'));
    await t.pumpAndSettle();
    final p = x.a.anfragen.lastWhere((r) => r.methode == 'POST' && r.pfad == '/api/access/visitors');
    final k = p.koerper as Map;
    expect(k['first_name'], 'Ida');
    expect(k['resources'], [{'id': 'd-velo', 'type': 'door'}]);
    expect((k['end_time'] as int) - (k['start_time'] as int), 4 * 3600);
    expect(find.text('Ida Besuch'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Protokoll: Zutritte nach Kategorie, Tür öffnen mit Rückfrage', (t) async {
    final x = await zeigen(t, const Size(412, 900));
    await t.tap(find.text('Protokoll'));
    await t.pumpAndSettle();
    expect(find.textContaining('Zutritt verweigert'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Kritisch'));
    await t.pumpAndSettle();
    expect(x.a.anfragen.last.pfad, contains('topic=critical'));
    await t.tap(find.text('Türen'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('oeffnen-d-eingang')));
    await t.pumpAndSettle();
    expect(find.text('Haupteingang öffnen?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Öffnen'));
    await t.pumpAndSettle();
    expect(x.a.anfragen.any((r) => r.methode == 'POST' && r.pfad == '/api/access/doors/d-eingang/unlock'), isTrue);
    // offline: Knopf aus
    final aus = t.widget<OutlinedButton>(find.byKey(const Key('oeffnen-d-technik')));
    expect(aus.onPressed, isNull);
    await t.pumpWidget(const SizedBox());
  });

  test('Haupt-API: Karten-Pfade, keine Telefonanlage', () async {
    final a = Attrappe();
    final api = ZutrittApi(RosenwegApi(a));
    await api.nachschlagen('04112233445566');
    await api.personen();
    await api.kartenprotokoll();
    expect(a.anfragen.map((r) => '${r.methode} ${r.pfad}'), [
      'POST /api/karten/info',
      'GET /api/karten/personen',
      'GET /api/karten/protokoll?tage=30',
    ]);
  });

  test('Access-Daten lesen', () {
    final b = AccessBenutzer.aus({'id': 'x', 'first_name': 'A', 'last_name': 'B', 'status': 'DEACTIVATED',
      'nfc_cards': [{'id': 'abcdef123', 'token': 't1'}]});
    expect(b.name, 'A B');
    expect(b.aktiv, isFalse);
    expect(b.karten.single.bezeichnung, 'Karte ····f123');
    expect(zeitAus(1795770000)!.isUtc, isFalse);
    final e = ZutrittsEreignis.aus({'@timestamp': '2026-11-27T07:58:00Z', '_source': {'actor': {'display_name': 'P'},
      'event': {'display_message': 'ok'}, 'target': [{'display_name': 'T1'}, {'name': 'T2'}]}}, 0);
    expect(e.tuer, 'T1, T2');
    expect(e.person, 'P');
  });
}
