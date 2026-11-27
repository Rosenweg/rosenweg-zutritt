// SPDX-License-Identifier: GPL-3.0-or-later
//
// Bildschirmfotos mit den Vorfuehrdaten (Attrappe), nur auf Wunsch:
//   RW_FOTO=$HOME/Downloads flutter test test/bildschirmfoto_test.dart
// Laedt Roboto und die Material-Symbole aus dem Flutter-SDK, sonst zeigen
// Widget-Tests nur Kaesten. Muster: rosenweg-profil.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_zutritt/app.dart';
import 'package:rosenweg_zutritt/attrappe.dart';
import 'package:rosenweg_zutritt/seiten/haupt.dart';

final ziel = Platform.environment['RW_FOTO'];

Future<void> schriften() async {
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final ordner = ['$sdk/artifacts/material_fonts', '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts']
      .map(Directory.new)
      .firstWhere((d) => d.existsSync(), orElse: () => Directory('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts'));
  Future<void> laden(String familie, List<String> dateien) async {
    final l = FontLoader(familie);
    for (final d in dateien) {
      l.addFont(Future.value(ByteData.sublistView(File('${ordner.path}/$d').readAsBytesSync())));
    }
    await l.load();
  }

  await laden('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> foto(WidgetTester t, String datei) async {
  final rb = t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final bild = await t.runAsync(() => rb.toImage(pixelRatio: 2));
  final png = await t.runAsync(() => bild!.toByteData(format: ui.ImageByteFormat.png));
  File('$ziel/$datei').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    Protokoll.nurKonsole = true;
    if (ziel != null) await schriften();
  });

  Future<void> zeigen(WidgetTester t, Size groesse, {Phase? phase}) async {
    t.view.physicalSize = groesse * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final s = RosenwegSitzung(appAngaben, transport: Attrappe());
    await s.starten();
    if (phase != null) s.phase = phase;
    await t.pumpWidget(RepaintBoundary(child: RosenwegRahmen(sitzung: s, inhalt: (_) => Haupt(sitzung: s))));
    await t.runAsync(() => precacheImage(appAngaben.logo!, t.element(find.byType(MaterialApp))));
    await t.runAsync(() => precacheImage(const AssetImage('assets/logo/rosenweg-zutritt-klein.png'), t.element(find.byType(MaterialApp))));
    await t.pumpAndSettle();
  }

  testWidgets('Fotos', (t) async {
    await zeigen(t, const Size(412, 860));
    await foto(t, 'rosenweg-zutritt-handy.png');
    await zeigen(t, const Size(1200, 800));
    await foto(t, 'rosenweg-zutritt-station.png');
    await zeigen(t, const Size(412, 860), phase: Phase.abgemeldet);
    await foto(t, 'rosenweg-zutritt-anmelden.png');
  }, skip: ziel == null);
}
