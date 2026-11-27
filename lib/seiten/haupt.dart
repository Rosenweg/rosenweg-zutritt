// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'eintraege.dart';

/// Die App nach der Anmeldung. Das Geruest aus rosenweg_basis legt die
/// Bereiche ([GeruestZiel]) auf dem Handy unten und am Desktop (ab 840 px,
/// Stationen, Laptops) links als Leiste ab; der Inhalt bleibt am Desktop
/// mittig begrenzt.
///
/// Hier die eigenen Bereiche eintragen. Die Vorlage zeigt drei: eine
/// Uebersicht, "Einträge" (Bausteine Liste, Formular, Rechte – siehe
/// eintraege.dart) und "Mein Konto" (GET /api/auth/me, als Beispiel fuer
/// einen API-Aufruf mit Laden, Fehler und Nochmals).
class Haupt extends StatelessWidget {
  const Haupt({super.key, required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  Widget build(BuildContext context) {
    final app = sitzung.app;
    return RosenwegGeruest(
      titel: Text(app.name),
      logo: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset('assets/logo/rosenweg-zutritt-klein.png', semanticLabel: 'Logo'),
      ),
      aktionen: [_Menue(sitzung: sitzung)],
      ziele: [
        GeruestZiel(
          titel: 'Übersicht',
          symbol: Icons.home_outlined,
          gewaehltSymbol: Icons.home,
          seite: (_) => UebersichtSeite(sitzung: sitzung),
        ),
        GeruestZiel(
          titel: 'Einträge',
          symbol: Icons.list_alt_outlined,
          gewaehltSymbol: Icons.list_alt,
          seite: (_) => EintraegeSeite(sitzung: sitzung),
        ),
        GeruestZiel(
          titel: 'Mein Konto',
          symbol: Icons.person_outline,
          gewaehltSymbol: Icons.person,
          seite: (_) => KontoSeite(api: sitzung.api),
        ),
      ],
    );
  }
}

/// Menue oben rechts: Anmeldung (echter Stand aus der Basis), Ueber, Abmelden.
/// Auf geteilten Telefonen meldet Rosenweg Geraet ab, dann gibt es den Punkt nicht.
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

class UebersichtSeite extends StatelessWidget {
  const UebersichtSeite({super.key, required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Willkommen${sitzung.name != null ? ', ${sitzung.name}' : ''}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(sitzung.app.beschreibung),
          const SizedBox(height: 16),
          const Hinweis('Hier kommt der Inhalt der App hin. Seiten in lib/seiten/, '
              'API-Aufrufe über sitzung.api, Vorführdaten in lib/attrappe.dart.'),
        ],
      );
}

/// Beispiel fuer einen API-Aufruf: laden, Fehler mit "Nochmals", Inhalt.
class KontoSeite extends StatefulWidget {
  const KontoSeite({super.key, required this.api});
  final RosenwegApi api;

  @override
  State<KontoSeite> createState() => _KontoSeiteState();
}

class _KontoSeiteState extends State<KontoSeite> {
  Map<String, dynamic>? _ich;
  Object? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _fehler = null;
      _ich = null;
    });
    try {
      final j = await widget.api.objekt('/api/auth/me');
      final u = j['user'];
      if (mounted) setState(() => _ich = u is Map<String, dynamic> ? u : j);
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fehler != null) return FehlerAnzeige(text: '$_fehler', nochmals: _laden);
    final ich = _ich;
    if (ich == null) return const LadeAnzeige();
    final gruppen = (ich['groups'] as List?)?.join(', ') ?? '';
    return RefreshIndicator(
      onRefresh: _laden,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Abschnitt(
            titel: 'Angemeldet als',
            symbol: Icons.badge_outlined,
            kind: Column(
              children: [
                ListTile(title: const Text('Name'), subtitle: Text('${ich['name'] ?? '–'}')),
                ListTile(title: const Text('E-Mail'), subtitle: Text('${ich['email'] ?? '–'}')),
                if (gruppen.isNotEmpty) ListTile(title: const Text('Gruppen'), subtitle: Text(gruppen)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
