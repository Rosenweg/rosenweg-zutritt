// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Antwortet wie die Haupt-API, mit erfundenen Daten (keine echten Personen).
/// Fuer Tests, Bildschirmfotos und Entwicklung ohne Server
/// (--dart-define=RW_ATTRAPPE=1). Neue Endpunkte der App hier nachbilden.
class Attrappe implements Transport {
  /// Alle Anfragen in der Reihenfolge (fuer Tests).
  final anfragen = <({String methode, String pfad, Object? koerper})>[];

  /// Naechste Antwort fuer einen Pfad erzwingen (Tests), z. B. einen Fehler:
  /// `erzwungen['GET /api/auth/me'] = (status: 503, json: null);`
  final erzwungen = <String, ApiAntwort>{};

  final _ich = <String, dynamic>{
    'id': 7,
    'username': 'erika.muster',
    'name': 'Erika Muster',
    'email': 'erika.muster@example.org',
    'role': 'user',
    'groups': ['stweg3-eigentuemer', 'waschkueche'],
    'permissions': {'dashboard': 'read', 'beispiel': 'write'},
  };

  final _eintraege = <Map<String, dynamic>>[
    {'id': 1, 'titel': 'Velokeller aufräumen', 'erledigt': false},
    {'id': 2, 'titel': 'Lampe im Treppenhaus ersetzen', 'erledigt': true},
    {'id': 3, 'titel': 'Briefkasten-Schild Haus 9', 'erledigt': false},
  ];

  @override
  Future<ApiAntwort> senden(String methode, String pfad, {Object? koerper}) async {
    anfragen.add((methode: methode, pfad: pfad, koerper: koerper));
    final z = erzwungen.remove('$methode $pfad');
    if (z != null) return z;
    switch ('$methode $pfad') {
      case 'GET /api/auth/me':
        return (status: 200, json: {'user': _ich});
      case 'GET /api/beispiel/eintraege':
        return (status: 200, json: _eintraege);
      case 'POST /api/beispiel/eintraege':
        final titel = koerper is Map ? '${koerper['titel'] ?? ''}' : '';
        // wie die Haupt-API: Fehler am Feld ({error, feld})
        if (_eintraege.any((e) => e['titel'] == titel)) {
          return (status: 400, json: {'error': 'Diesen Eintrag gibt es schon.', 'feld': 'titel'});
        }
        _eintraege.add({'id': _eintraege.length + 1, 'titel': titel, 'erledigt': false});
        return (status: 201, json: {'ok': true});
    }
    return (status: 404, json: {'error': 'Nicht gefunden: $methode $pfad'});
  }
}
