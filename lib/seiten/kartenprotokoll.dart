// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';

/// Kartenprotokoll der letzten 30 Tage (GET /api/karten/protokoll):
/// Zuordnen, Entziehen, Loeschen, Anmeldungen, Admin-Aktionen mit der Karte
/// und Bestaetigungen per E-Mail. Suche nach Person, Karte, Aktion.
class KartenprotokollListe extends StatefulWidget {
  const KartenprotokollListe({super.key, required this.api});
  final ZutrittApi api;

  @override
  State<KartenprotokollListe> createState() => _KartenprotokollListeState();
}

class _KartenprotokollListeState extends State<KartenprotokollListe> {
  late final _liste = ListenSteuerung<ProtokollEintrag>.lokal(
    alle: () => widget.api.kartenprotokoll(),
    suchText: (e) => e.suchText,
    schluessel: (e) => e.id,
    filter: [
      ListenFilter(id: 'karten', titel: 'Karten', passt: (e) => const {'zuordnen', 'entziehen', 'loeschen'}.contains(e.aktion)),
      ListenFilter(id: 'admin', titel: 'Admin mit Karte', passt: (e) => e.aktion == 'admin-mit-karte'),
      ListenFilter(
        id: 'bestaetigung',
        titel: 'Bestätigungen',
        passt: (e) => const {'bestaetigung-angefragt', 'bestaetigt', 'abgelehnt'}.contains(e.aktion),
      ),
      ListenFilter(id: 'anmeldung', titel: 'An- und Abmeldungen', passt: (e) => e.aktion.contains('anmeld')),
      ListenFilter(id: 'fehler', titel: 'Fehlgeschlagen', passt: (e) => !e.erfolg),
    ],
  );

  @override
  void dispose() {
    _liste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RosenwegListe<ProtokollEintrag>(
        steuerung: _liste,
        suchHinweis: 'Person, Karte oder Aktion suchen',
        leerText: 'In den letzten 30 Tagen ist nichts protokolliert.',
        leerSymbol: Icons.history,
        spalten: [
          ListenSpalte(id: 'zeit', titel: 'Zeit', text: (e) => wannText(e.zeit), flex: 2),
          ListenSpalte(id: 'aktion', titel: 'Aktion', text: (e) => e.aktionText, flex: 2),
          ListenSpalte(id: 'karte', titel: 'Karte', text: (e) => e.inventarnummer ?? e.nfcId ?? '', flex: 2),
          ListenSpalte(id: 'wen', titel: 'Person', text: (e) => e.wen, flex: 3),
          ListenSpalte(id: 'durch', titel: 'Durch', text: (e) => e.durch ?? '', flex: 3),
          ListenSpalte(
            id: 'erfolg',
            titel: 'Ergebnis',
            zelle: (_, e) => Icon(e.erfolg ? Icons.check : Icons.error_outline,
                color: e.erfolg ? RosenwegFarben.gut : Theme.of(context).colorScheme.error, semanticLabel: e.erfolg ? 'ok' : 'Fehler'),
            breite: 80,
          ),
        ],
        kachel: (_, e) => ListTile(
          leading: Icon(e.erfolg ? Icons.check_circle_outline : Icons.error_outline,
              color: e.erfolg ? RosenwegFarben.gut : Theme.of(context).colorScheme.error),
          title: Text([e.aktionText, if (e.inventarnummer != null) 'Karte ${e.inventarnummer}'].join(' · ')),
          subtitle: Text([wannText(e.zeit), if (e.wen.isNotEmpty) e.wen, if (e.durch != null) 'durch ${e.durch}'].join('\n')),
          isThreeLine: e.durch != null,
        ),
        antippen: (e) => _details(context, e),
      );

  void _details(BuildContext context, ProtokollEintrag e) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(e.aktionText),
          content: SelectableText([
            'Zeit: ${wannText(e.zeit)}',
            'Ergebnis: ${e.erfolg ? 'ok' : 'fehlgeschlagen'}',
            if (e.inventarnummer != null) 'Karte: ${e.inventarnummer}',
            if (e.nfcId != null) 'UID: ${e.nfcId}',
            if (e.wen.isNotEmpty) 'Person: ${e.wen}${e.zielEmail != null && e.zielName != null ? ' <${e.zielEmail}>' : ''}',
            if (e.durch != null) 'Durch: ${e.durch}',
            if (e.detail != null) 'Einzelheiten: ${e.detail}',
          ].join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Schliessen'))],
        ),
      );
}
