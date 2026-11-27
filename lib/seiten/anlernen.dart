// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../zutritt_api.dart';

/// Neue Karte am Leser von UniFi Access anlernen und [benutzer] geben:
/// Leser waehlen (bei mehreren), Karte hinhalten, fertig. UniFi Access legt
/// die Karte dabei selbst im Bestand an. Liefert true, wenn eine Karte
/// zugewiesen wurde.
Future<bool> karteAmLeserAnlernen(BuildContext context, ZutrittApi api, AccessBenutzer benutzer) async {
  final List<AccessLeser> leser;
  try {
    leser = await api.leser();
  } catch (e) {
    if (context.mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    return false;
  }
  if (!context.mounted) return false;
  if (leser.isEmpty) {
    zeigeMeldung(context, 'UniFi Access meldet keinen Leser, der Karten anlernen kann.', fehler: true);
    return false;
  }
  var gewaehlt = leser.length == 1 ? leser.first : null;
  gewaehlt ??= await showDialog<AccessLeser>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('An welchem Leser?'),
      children: [
        for (final l in leser)
          SimpleDialogOption(
            onPressed: l.online ? () => Navigator.pop(c, l) : null,
            child: ListTile(
              leading: Icon(l.online ? Icons.nfc : Icons.cloud_off),
              title: Text(l.name),
              subtitle: Text([if (l.modell != null) l.modell!, if (!l.online) 'offline'].join(' · ')),
            ),
          ),
      ],
    ),
  );
  if (gewaehlt == null || !context.mounted) return false;
  final token = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AnlernDialog(api: api, leser: gewaehlt!, fuer: benutzer.name),
  );
  if (token == null || !context.mounted) return false;
  try {
    await api.karteZuweisen(benutzer.id, token);
    if (context.mounted) zeigeMeldung(context, 'Karte angelernt und ${benutzer.name} gegeben.');
    return true;
  } on BestaetigungPerEmail catch (e) {
    if (context.mounted) await zeigeEmailBestaetigung(context, e);
  } catch (e) {
    if (context.mounted) zeigeMeldung(context, 'Zuweisen fehlgeschlagen: ${fehlerText(e)}', fehler: true);
  }
  return false;
}

/// „Karte an den Leser halten“: startet das Anlernen in UniFi Access, fragt
/// alle [takt] nach, ob eine Karte aufliegt, und gibt deren Token zurueck.
/// Abbrechen oder nach [dauer] ohne Karte: Anlernen beenden, null.
class AnlernDialog extends StatefulWidget {
  const AnlernDialog({super.key, required this.api, required this.leser, required this.fuer});
  final ZutrittApi api;
  final AccessLeser leser;
  final String fuer;

  static Duration takt = const Duration(seconds: 2);
  static Duration dauer = const Duration(seconds: 60);

  @override
  State<AnlernDialog> createState() => _AnlernDialogState();
}

class _AnlernDialogState extends State<AnlernDialog> {
  String? _sitzung;
  String? _fehler;
  bool _fertig = false;

  @override
  void initState() {
    super.initState();
    _laufen();
  }

  Future<void> _laufen() async {
    try {
      _sitzung = await widget.api.anlernenStarten(widget.leser.id);
    } catch (e) {
      if (mounted) setState(() => _fehler = fehlerText(e));
      return;
    }
    var runden = AnlernDialog.dauer.inMilliseconds ~/ AnlernDialog.takt.inMilliseconds;
    while (!_fertig && runden-- > 0) {
      await Future<void>.delayed(AnlernDialog.takt);
      if (_fertig || !mounted) return;
      String? token;
      try {
        token = await widget.api.anlernenStand(_sitzung!);
      } catch (_) {
        continue; // kurz weg: weiter fragen
      }
      if (token != null && !_fertig && mounted) {
        _fertig = true;
        Navigator.pop(context, token);
        return;
      }
    }
    if (!_fertig && mounted) {
      await _beenden();
      if (mounted) setState(() => _fehler = 'Keine Karte erkannt. Nochmals versuchen und die Karte ruhig an den Leser halten.');
    }
  }

  Future<void> _beenden() async {
    final s = _sitzung;
    if (s != null) await widget.api.anlernenAbbrechen(s).catchError((_) {});
  }

  Future<void> _abbrechen() async {
    _fertig = true;
    Navigator.pop(context);
    await _beenden();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Karte für ${widget.fuer}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_fehler == null) ...[
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text('Neue Karte an den Leser „${widget.leser.name}“ halten.', textAlign: TextAlign.center),
          ] else
            Hinweis(_fehler!, art: HinweisArt.warnung),
        ]),
        actions: [TextButton(onPressed: _abbrechen, child: Text(_fehler == null ? 'Abbrechen' : 'Schliessen'))],
      );
}
