// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_zutritt/app.dart';
import 'package:rosenweg_zutritt/attrappe.dart';
import 'package:rosenweg_zutritt/seiten/haupt.dart';

void main() {
  setUpAll(() => Protokoll.nurKonsole = true);

  Future<Attrappe> zeigen(WidgetTester t, Size groesse) async {
    t.view.physicalSize = groesse;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final a = Attrappe();
    final s = RosenwegSitzung(appAngaben, transport: a);
    await s.starten();
    await t.pumpWidget(RosenwegRahmen(sitzung: s, inhalt: (_) => Haupt(sitzung: s)));
    await t.pumpAndSettle();
    return a;
  }

  testWidgets('Handy: Navigation unten, Konto laedt /api/auth/me', (t) async {
    final a = await zeigen(t, const Size(412, 860));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.textContaining('Willkommen'), findsOneWidget);
    await t.tap(find.text('Mein Konto'));
    await t.pumpAndSettle();
    expect(find.text('erika.muster@example.org'), findsOneWidget);
    expect(a.anfragen.any((r) => r.pfad == '/api/auth/me'), isTrue);
  });

  testWidgets('Einträge: Liste mit Suche, Neu nur mit Schreibrecht, Fehler der API am Feld', (t) async {
    final a = await zeigen(t, const Size(412, 860));
    await t.tap(find.text('Einträge'));
    await t.pumpAndSettle();
    expect(find.text('Velokeller aufräumen'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Lampe');
    await t.pumpAndSettle();
    expect(find.text('Velokeller aufräumen'), findsNothing);
    expect(find.text('Lampe im Treppenhaus ersetzen'), findsOneWidget);

    await t.tap(find.text('Neu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(find.text('Bitte die markierten Felder prüfen.'), findsWidgets);
    await t.enterText(find.byType(TextFormField), 'Velokeller aufräumen');
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(find.text('Diesen Eintrag gibt es schon.'), findsOneWidget);
    await t.enterText(find.byType(TextFormField), 'Neue Glühbirne');
    await t.pump();
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(find.text('Neuer Eintrag'), findsNothing);
    expect(a.anfragen.where((r) => r.methode == 'POST').length, 2);
    // neu geladen; die Suche "Lampe" gilt noch
    await t.enterText(find.byType(TextField).first, 'Glüh');
    await t.pumpAndSettle();
    expect(find.text('Neue Glühbirne'), findsOneWidget);
  });

  testWidgets('Desktop (Station): Leiste links', (t) async {
    await zeigen(t, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Fehler zeigt Nochmals und laedt neu', (t) async {
    final a = await zeigen(t, const Size(412, 860));
    a.erzwungen['GET /api/auth/me'] = (status: 503, json: {'error': 'Wartung'});
    await t.tap(find.text('Mein Konto'));
    await t.pumpAndSettle();
    expect(find.text('Nochmals'), findsOneWidget);
    await t.tap(find.text('Nochmals'));
    await t.pumpAndSettle();
    expect(find.text('erika.muster@example.org'), findsOneWidget);
  });

  test('Kennung, Ordner und Logo passen zusammen', () {
    expect(appAngaben.kennung, matches(RegExp(r'^ch\.rosenweg4303\.[a-z][a-z0-9]*$')));
    expect(appAngaben.ordner, startsWith('rosenweg-'));
    expect(File('assets/logo/${appAngaben.ordner}-512.png').existsSync(), isTrue);
    expect(File('assets/logo/${appAngaben.ordner}-klein.png').existsSync(), isTrue);
  });
}
