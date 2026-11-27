// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Antwortet wie die Haupt-API (Karten, Anmeldungen, UniFi Access), mit
/// erfundenen Daten (keine echten Personen, keine echten Karten oder Tueren).
/// Fuer Tests, Bildschirmfotos und Entwicklung ohne Server
/// (--dart-define=RW_ATTRAPPE=1).
///
/// Karten zum Ausprobieren (Nummer eintippen):
///   04A1B2C3D4E5F6  zugeordnet (Erika Muster), Inventarnummer 0042
///   04112233445566  frei, Inventarnummer 0107
///   0A0B0C0D        unbekannt (nicht in UniFi Access)
class Attrappe implements Transport {
  Attrappe({this.gruppen = const ['technik']});

  /// Gruppen der angemeldeten Person (Tests: ohne Technik = keine Berechtigung).
  final List<String> gruppen;

  /// Alle Anfragen in der Reihenfolge (fuer Tests).
  final anfragen = <({String methode, String pfad, Object? koerper})>[];

  /// Naechste Antwort fuer einen Pfad erzwingen (Tests), z. B. einen Fehler:
  /// `erzwungen['POST /api/karten/entziehen'] = (status: 503, json: null);`
  final erzwungen = <String, ApiAntwort>{};

  final _karten = <String, Map<String, dynamic>>{
    '04A1B2C3D4E5F6': {'display_id': '0042', 'besitzer': 'erika.muster@example.org'},
    '04112233445566': {'display_id': '0107', 'besitzer': null},
  };

  static const _personen = [
    {'name': 'Erika Muster', 'email': 'erika.muster@example.org'},
    {'name': 'Max Beispiel', 'email': 'max.beispiel@example.org'},
    {'name': 'Lea Probe', 'email': 'lea.probe@example.org'},
  ];

  final _protokoll = <Map<String, dynamic>>[
    {'id': 3, 'aktion': 'admin-mit-karte', 'display_id': '0042', 'ziel_email': 'erika.muster@example.org', 'ziel_name': 'Erika Muster',
     'durch': 'karte:as_beispiel', 'erfolg': true, 'detail': 'Türen und Zutritt: geändert · App Rosenweg Zutritt', 'created_at': '2026-11-27T09:12:00Z'},
    {'id': 2, 'aktion': 'zuordnen', 'display_id': '0042', 'nfc_id': '04A1B2C3D4E5F6', 'ziel_email': 'erika.muster@example.org',
     'ziel_name': 'Erika Muster', 'durch': 'Rosenweg Zutritt (Max Beispiel)', 'erfolg': true, 'created_at': '2026-11-26T16:40:00Z'},
    {'id': 1, 'aktion': 'entziehen', 'display_id': '0099', 'ziel_name': 'Lea Probe', 'durch': 'Telefon 2098 (Max Beispiel)',
     'erfolg': false, 'detail': '502 UniFi Access nicht erreichbar', 'created_at': '2026-11-25T08:03:00Z'},
  ];

  final _sitzungen = <Map<String, dynamic>>[
    {'id': 'as_aaaaaaaaaaaaaaaa', 'email': 'erika.muster@example.org', 'name': 'Erika Muster', 'app_name': 'Rosenweg Salz',
     'geraet_name': 'Pixel 8', 'plattform': 'android', 'art': 'karte', 'karte_anzeige': '0042',
     'created_at': '2026-11-20T10:00:00Z', 'last_used_at': '2026-11-27T07:30:00Z', 'expires_at': '2026-12-20T10:00:00Z'},
    {'id': 'as_bbbbbbbbbbbbbbbb', 'email': 'max.beispiel@example.org', 'name': 'Max Beispiel', 'app_name': 'Rosenweg Profil',
     'geraet_name': 'Laptop', 'plattform': 'windows', 'art': 'handy',
     'created_at': '2026-11-22T18:00:00Z', 'last_used_at': '2026-11-26T21:15:00Z', 'expires_at': '2026-12-22T18:00:00Z'},
  ];

  final _benutzer = <Map<String, dynamic>>[
    {'id': 'u-erika', 'first_name': 'Erika', 'last_name': 'Muster', 'email': 'erika.muster@example.org', 'status': 'ACTIVE',
     'pin_code': '••••', 'nfc_cards': [{'id': '0042', 'display_id': '0042', 'token': 'tok-0042'}]},
    {'id': 'u-max', 'first_name': 'Max', 'last_name': 'Beispiel', 'email': 'max.beispiel@example.org', 'status': 'ACTIVE', 'nfc_cards': <Object>[]},
    {'id': 'u-lea', 'first_name': 'Lea', 'last_name': 'Probe', 'email': 'lea.probe@example.org', 'status': 'DEACTIVATED', 'nfc_cards': <Object>[]},
  ];

  final _regelnJe = <String, Set<String>>{
    'u-erika': {'p-haus', 'p-keller'},
    'u-max': {'p-haus'},
  };

  static const _regeln = [
    {'id': 'p-haus', 'name': 'Haus 9 – Haupteingang'},
    {'id': 'p-keller', 'name': 'Velokeller'},
    {'id': 'p-technik', 'name': 'Technikraum (nur Technik)'},
  ];

  static const _tueren = [
    {'id': 'd-eingang', 'name': 'Haupteingang', 'full_name': 'Haus 9 / Haupteingang', 'lock_state': 'lock', 'position': 'close', 'online': true},
    {'id': 'd-velo', 'name': 'Velokeller', 'full_name': 'Haus 9 / UG / Velokeller', 'lock_state': 'lock', 'position': 'open', 'online': true},
    {'id': 'd-technik', 'name': 'Technikraum', 'full_name': 'Haus 9 / UG / Technikraum', 'lock_state': 'unlock', 'position': 'close', 'online': false},
  ];

  // relativ zu heute: morgen 8–12 Uhr (kommt noch), vor einer Woche (abgelaufen)
  late final _besucher = () {
    final h = DateTime.now();
    int s(int tage, int stunde) => DateTime(h.year, h.month, h.day + tage, stunde).millisecondsSinceEpoch ~/ 1000;
    return <Map<String, dynamic>>[
      {'id': 'v-1', 'first_name': 'Paul', 'last_name': 'Handwerk', 'start_time': s(1, 8), 'end_time': s(1, 12), 'status': 'UPCOMING',
       'remarks': 'Heizungsservice'},
      {'id': 'v-2', 'first_name': 'Nora', 'last_name': 'Gast', 'start_time': s(-7, 14), 'end_time': s(-7, 18), 'status': 'VISITED'},
    ];
  }();

  static const _logs = [
    {'@timestamp': '2026-11-27T07:58:00Z', '_source': {'actor': {'display_name': 'Erika Muster'},
     'event': {'display_message': 'Zutritt gewährt (Karte)'}, 'target': [{'display_name': 'Haupteingang'}]}},
    {'@timestamp': '2026-11-27T07:41:00Z', '_source': {'actor': {'display_name': 'Max Beispiel'},
     'event': {'display_message': 'Zutritt gewährt (PIN)'}, 'target': [{'display_name': 'Velokeller'}]}},
    {'@timestamp': '2026-11-26T22:13:00Z', '_source': {'actor': {'display_name': 'Unbekannte Karte'},
     'event': {'display_message': 'Zutritt verweigert'}, 'target': [{'display_name': 'Haupteingang'}]}},
  ];

  int _anlernAbfragen = 0;

  Map<String, dynamic> _info(String uid) {
    final k = _karten[uid];
    if (k == null) return {'found': false, 'assigned': false, 'uid': uid};
    final b = k['besitzer'] as String?;
    final p = b == null ? null : _personen.firstWhere((x) => x['email'] == b);
    return {
      'found': true,
      'assigned': b != null,
      'status': b == null ? 'UNASSIGNED' : 'ASSIGNED',
      'display_id': k['display_id'],
      'access_name': p?['name'],
      'person': p,
      'uid': uid,
    };
  }

  @override
  Future<ApiAntwort> senden(String methode, String pfad, {Object? koerper}) async {
    anfragen.add((methode: methode, pfad: pfad, koerper: koerper));
    final weg = pfad.split('?').first;
    final z = erzwungen.remove('$methode $weg') ?? erzwungen.remove('$methode $pfad');
    if (z != null) return z;
    final k = koerper is Map ? koerper : const {};
    final uid = '${k['uid'] ?? ''}'.toUpperCase();
    switch ('$methode $weg') {
      case 'GET /api/auth/me':
        return (status: 200, json: {
          'user': {'id': 7, 'name': 'Max Beispiel', 'email': 'max.beispiel@example.org', 'groups': gruppen, 'permissions': <String, String>{}},
        });
      case 'GET /api/me/bestaetigungen':
        return (status: 200, json: {'offen': <Object>[]});
      case 'GET /api/karten/protokoll':
        return (status: 200, json: {'tage': 30, 'eintraege': _protokoll});
      case 'GET /api/apps/sitzungen':
        return (status: 200, json: {'sitzungen': _sitzungen, 'alle': true});
      case 'POST /api/apps/sitzungen/alle-abmelden':
        final n = _sitzungen.where((s) => s['email'] == k['email']).length;
        _sitzungen.removeWhere((s) => s['email'] == k['email']);
        return (status: 200, json: {'ok': true, 'abgemeldet': n});
      case 'GET /api/karten/personen':
        return (status: 200, json: {'personen': _personen});
      case 'POST /api/karten/info':
        return (status: 200, json: _info(uid));
      case 'POST /api/karten/zuordnen':
        final email = '${k['email']}';
        final karte = _karten.putIfAbsent(uid, () => {'display_id': '0${200 + _karten.length}', 'besitzer': null});
        if (karte['besitzer'] == email) return (status: 200, json: {'ok': true, 'schon': true});
        if (karte['besitzer'] != null) return (status: 409, json: {'error': 'Die Karte gehört bereits jemand anderem. Zuerst entziehen.'});
        karte['besitzer'] = email;
        final u = _benutzer.where((b) => b['email'] == email).firstOrNull;
        (u?['nfc_cards'] as List?)?.add({'id': karte['display_id'], 'display_id': karte['display_id'], 'token': 'tok-$uid'});
        return (status: 200, json: {'ok': true, 'display_id': karte['display_id']});
      case 'POST /api/karten/entziehen':
        final karte = _karten[uid];
        if (karte == null) return (status: 404, json: {'error': 'Karte nicht bekannt'});
        karte['besitzer'] = null;
        return (status: 200, json: {'ok': true});
      case 'POST /api/karten/loeschen':
        if (_karten.remove(uid) == null) return (status: 404, json: {'error': 'Karte nicht bekannt'});
        return (status: 200, json: {'ok': true});
      case 'GET /api/access/users':
        return (status: 200, json: {'users': _benutzer});
      case 'POST /api/access/users':
        if ('${k['first_name'] ?? ''}'.isEmpty) return (status: 400, json: {'error': 'Vorname erforderlich'});
        _benutzer.add({'id': 'u-${_benutzer.length + 1}', ...k, 'status': 'ACTIVE', 'nfc_cards': <Object>[]});
        return (status: 200, json: {'code': 'SUCCESS'});
      case 'GET /api/access/policies':
        return (status: 200, json: {'policies': _regeln});
      case 'GET /api/access/doors':
        return (status: 200, json: {'doors': _tueren});
      case 'GET /api/access/visitors':
        return (status: 200, json: {'visitors': _besucher});
      case 'POST /api/access/visitors':
        _besucher.add({'id': 'v-${_besucher.length + 1}', ...k, 'status': 'UPCOMING'});
        return (status: 200, json: {'code': 'SUCCESS'});
      case 'GET /api/access/logs':
        return (status: 200, json: {'logs': _logs});
      case 'GET /api/access/nfc/devices':
        return (status: 200, json: {
          'devices': [
            {'id': 'r-ug', 'name': 'Schlüsselkasten UG', 'model': 'UA Ultra', 'online': true},
            {'id': 'r-eingang', 'name': 'Leser Haupteingang', 'model': 'UA G2', 'online': true},
          ],
        });
      case 'POST /api/access/nfc/session':
        _anlernAbfragen = 0;
        return (status: 200, json: {'session_id': 'ns-1'});
    }
    // Pfade mit Kennung: ['', 'api', 'access', bereich, id, ...]
    final teile = weg.split('/').map(Uri.decodeComponent).toList();
    if (teile.length >= 4 && teile[1] == 'api' && teile[2] == 'access') {
      final bereich = teile[3];
      final id = teile.length > 4 ? teile[4] : '';
      final u = _benutzer.where((b) => b['id'] == id).firstOrNull;
      if (bereich == 'users' && teile.length == 5 && u != null) {
        if (methode == 'PUT') {
          u.addAll({...k}..remove('pin_code'));
          if (k['pin_code'] != null) u['pin_code'] = '••••';
          return (status: 200, json: {'code': 'SUCCESS'});
        }
        if (methode == 'DELETE') {
          _benutzer.remove(u);
          return (status: 200, json: {'code': 'SUCCESS'});
        }
      }
      if (bereich == 'users' && teile.length == 6 && teile[5] == 'policies') {
        if (methode == 'GET') {
          final ids = _regelnJe[id] ?? const {};
          return (status: 200, json: {'policies': _regeln.where((r) => ids.contains(r['id'])).toList()});
        }
        _regelnJe[id] = {for (final x in (k['access_policy_ids'] as List? ?? const [])) '$x'};
        return (status: 200, json: {'code': 'SUCCESS'});
      }
      if (bereich == 'users' && teile.length >= 6 && teile[5] == 'nfc' && u != null) {
        final karten = u['nfc_cards'] as List;
        if (methode == 'POST') {
          karten.add({'id': '0310', 'display_id': '0310', 'token': '${k['token']}'});
          return (status: 200, json: {'code': 'SUCCESS'});
        }
        if (methode == 'DELETE' && teile.length == 7) {
          karten.removeWhere((c) => c is Map && c['token'] == teile[6]);
          return (status: 200, json: {'code': 'SUCCESS'});
        }
      }
      if (bereich == 'visitors' && methode == 'DELETE') {
        _besucher.removeWhere((v) => v['id'] == id);
        return (status: 200, json: {'code': 'SUCCESS'});
      }
      if (bereich == 'doors' && methode == 'POST' && teile.length == 6 && teile[5] == 'unlock') {
        return (status: 200, json: {'success': true, 'message': 'Tür entsperrt'});
      }
      if (bereich == 'nfc' && teile.length == 6 && teile[4] == 'session') {
        if (methode == 'DELETE') return (status: 200, json: {'success': true});
        // erst beim zweiten Nachfragen liegt eine Karte auf
        _anlernAbfragen++;
        return (status: 200, json: {'data': _anlernAbfragen < 2 ? <String, Object>{} : {'token': 'tok-neu-0310', 'nfc_id': '04FFEE0310'}});
      }
    }
    if (methode == 'DELETE' && weg.startsWith('/api/apps/sitzungen/')) {
      final id = Uri.decodeComponent(weg.split('/').last);
      _sitzungen.removeWhere((s) => s['id'] == id);
      return (status: 200, json: {'ok': true});
    }
    return (status: 404, json: {'error': 'Nicht gefunden: $methode $pfad'});
  }
}
