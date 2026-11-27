// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Kartenleser fuer Tests und Bildschirmfotos: Karten kommen ueber [auflegen].
class TestLeser implements Kartenleser {
  final _karten = StreamController<String>.broadcast();

  void auflegen(String uid) => _karten.add(uid);

  @override
  bool get aufKnopfdruck => false;

  @override
  Future<bool> verfuegbar() async => true;

  @override
  Stream<String> lauschen() => _karten.stream;

  @override
  Future<String?> einmalLesen() => _karten.stream.first;
}
