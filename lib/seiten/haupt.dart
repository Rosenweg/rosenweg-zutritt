// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../zutritt_api.dart';
import 'anmeldungen.dart';
import 'besucher.dart';
import 'karte.dart';
import 'personen.dart';
import 'protokoll.dart';

/// Die App nach der Anmeldung: nur fuer Technik und Praesident (wie die
/// Haupt-API prueft). Fuenf Bereiche – auf dem Handy unten, am Computer links:
///
///  * Karte: Karte hinhalten bzw. auflegen → wem gehoert sie; zuordnen,
///    entziehen, aus dem Bestand loeschen (vormals Rosenweg Karten)
///  * Personen: Benutzer in UniFi Access – Angaben und PIN, Karten (am
///    UniFi-Leser anlernen oder mit diesem Geraet lesen), Zugangsregeln
///  * Besucher: Besucher-Paesse mit Zeitraum und Tueren
///  * Protokoll: Zutritte, Tueren (Stand, oeffnen), Kartenprotokoll
///  * Anmeldungen: Karten-, QR- und Handy-Anmeldungen der Apps aller
///    Personen, einzeln oder je Person abmelden
class Haupt extends StatefulWidget {
  const Haupt({super.key, required this.sitzung, this.leser});
  final RosenwegSitzung sitzung;

  /// Fuer Tests und Bildschirmfotos; sonst der Leser der Plattform (NFC, PC/SC).
  final Kartenleser? leser;

  @override
  State<Haupt> createState() => _HauptState();
}

class _HauptState extends State<Haupt> {
  late final ZutrittApi _api = ZutrittApi(widget.sitzung.api);

  @override
  void initState() {
    super.initState();
    // nach dem ersten Bau (laden meldet sofort "laedt")
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.sitzung.rechte.laden().ignore());
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sitzung;
    return ListenableBuilder(
      listenable: s.rechte,
      builder: (context, _) {
        final r = s.rechte.stand;
        final Widget? sperre = r == null
            ? (s.rechte.fehler != null
                ? FehlerAnzeige.aus(s.rechte.fehler!, nochmals: () => s.rechte.laden(neu: true))
                : const LadeAnzeige())
            : !r.alles
                ? const KeineBerechtigungAnzeige(text: 'Rosenweg Zutritt ist nur für Technik und Präsident.')
                : null;
        return RosenwegGeruest(
          titel: Text(s.app.name),
          logo: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset('assets/logo/rosenweg-zutritt-klein.png', semanticLabel: 'Logo'),
          ),
          aktionen: [_Menue(sitzung: s)],
          ziele: [
            GeruestZiel(
              titel: 'Karte',
              symbol: Icons.contactless_outlined,
              gewaehltSymbol: Icons.contactless,
              seite: (_) => sperre ?? KarteSeite(karten: _api, leser: widget.leser),
            ),
            GeruestZiel(
              titel: 'Personen',
              symbol: Icons.people_outline,
              gewaehltSymbol: Icons.people,
              seite: (_) => sperre ?? PersonenSeite(api: _api, leser: widget.leser),
            ),
            GeruestZiel(
              titel: 'Besucher',
              symbol: Icons.badge_outlined,
              gewaehltSymbol: Icons.badge,
              seite: (_) => sperre ?? BesucherSeite(api: _api),
            ),
            GeruestZiel(
              titel: 'Protokoll',
              symbol: Icons.history_outlined,
              gewaehltSymbol: Icons.history,
              seite: (_) => sperre ?? ProtokollSeite(api: _api),
            ),
            GeruestZiel(
              titel: 'Anmeldungen',
              symbol: Icons.devices_other_outlined,
              gewaehltSymbol: Icons.devices_other,
              seite: (_) => sperre ?? AnmeldungenSeite(api: _api),
            ),
          ],
        );
      },
    );
  }
}

/// Menue oben rechts: Anmeldung (echter Stand), Ueber, Abmelden (nicht auf
/// geteilten Telefonen – dort meldet Rosenweg Geraet ab).
class _Menue extends StatelessWidget {
  const _Menue({required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Mehr',
        onSelected: (w) async {
          switch (w) {
            case 'anmeldung':
              await zeigeAnmeldung(context, sitzung);
            case 'ueber':
              await zeigeUeber(context, sitzung.app);
            case 'abmelden':
              if (await frage(context, 'Abmelden?', 'Danach musst du dich neu anmelden.', ja: 'Abmelden')) {
                await sitzung.abmelden();
              }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'anmeldung', child: Text('Anmeldung: ${sitzung.name ?? 'angemeldet'}')),
          PopupMenuItem(value: 'ueber', child: Text('Über ${sitzung.app.name}')),
          if (!sitzung.geteiltesTelefon) const PopupMenuItem(value: 'abmelden', child: Text('Abmelden')),
        ],
      );
}
