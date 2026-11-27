// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/painting.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Angaben der App fuer rosenweg_basis.
///
/// kennung = applicationId (Android) = Bundle-ID (iOS/macOS) = GTK-ID (Linux)
/// = Schema des Ruecksprungs (ch.rosenweg4303.zutritt:/anmeldung, in Authentik
/// bei rosenweg-apps eintragen) = Paket im App-Katalog (/apps, Updater).
const appAngaben = RosenwegApp(
  kennung: 'ch.rosenweg4303.zutritt',
  name: 'Rosenweg Zutritt',
  ordner: 'rosenweg-zutritt',
  beschreibung: 'Türen, Access-Benutzer, Besucher-Pässe und Rosenweg-Karten verwalten; Zutritts- und Kartenprotokoll.',
  quelle: 'https://github.com/Rosenweg/rosenweg-zutritt',
  logo: AssetImage('assets/logo/rosenweg-zutritt-512.png'),
  // Anmeldeschirm in Technik-Gruen: `gruppe: RosenwegGruppe.technik`, sobald
  // rosenweg_basis v0.6.1 getaggt ist (basis#22); bis dahin blau.
);

/// --dart-define=RW_ATTRAPPE=1: ohne Anmeldung und ohne Server, mit
/// erfundenen Vorfuehrdaten (Entwicklung, Bildschirmfotos, Tests).
const attrappe = bool.fromEnvironment('RW_ATTRAPPE');
