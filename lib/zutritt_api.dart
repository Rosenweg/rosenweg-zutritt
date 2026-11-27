// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'daten.dart';

/// Alle Aufrufe der App, gegen die Haupt-API (www.rosenweg4303.ch).
///
/// Der Weg kommt aus der Sitzung: eigenes Handy, Computer, Station direkt mit
/// dem Zugang der Anmeldung (Karte, QR, Konto, Kerberos); geteiltes Telefon
/// ueber Rosenweg Geraet (`portal_anfrage`, Anlage-Token der Telefonanlage).
/// Die Haupt-API prueft Technik/Praesident, protokolliert jede Aenderung und
/// verlangt mit der Karte fuer heikle Aktionen eine Bestaetigung per E-Mail
/// (202 → [BestaetigungPerEmail]).
class ZutrittApi {
  ZutrittApi(this.api);
  final RosenwegApi api;

  static String _p(String s) => Uri.encodeComponent(s);

  static List<Map<String, dynamic>> _liste(Object? l) =>
      [for (final e in l is List ? l : const []) if (e is Map<String, dynamic>) e];

  static Map<String, dynamic> _objekt(Object? j) => j is Map<String, dynamic> ? j : const {};

  // ── Rosenweg-Karten (POST /api/karten/*) ──
  Future<Karte> nachschlagen(String uid) async => Karte.aus(uid, _objekt(await api.post('/api/karten/info', {'uid': uid})));

  Future<List<Person>> personen() async {
    final j = await api.objekt('/api/karten/personen');
    return [for (final p in _liste(j['personen'])) Person.aus(p)]..removeWhere((p) => p.email.isEmpty);
  }

  /// {ok, schon?, importiert?, display_id, name}
  Future<Map<String, dynamic>> zuordnen(String uid, String email) async =>
      _objekt(await api.post('/api/karten/zuordnen', {'uid': uid, 'email': email}));

  Future<Map<String, dynamic>> entziehen(String uid) async => _objekt(await api.post('/api/karten/entziehen', {'uid': uid}));

  Future<Map<String, dynamic>> loeschen(String uid) async => _objekt(await api.post('/api/karten/loeschen', {'uid': uid}));

  Future<List<ProtokollEintrag>> kartenprotokoll({int tage = 30}) async {
    final j = await api.objekt('/api/karten/protokoll?tage=$tage');
    return [for (final e in _liste(j['eintraege'])) ProtokollEintrag.aus(e)];
  }

  // ── Anmeldungen der Apps ──
  Future<List<AppSitzung>> sitzungen() async {
    final j = await api.objekt('/api/apps/sitzungen?alle=1');
    return [for (final e in _liste(j['sitzungen'])) AppSitzung.aus(e)];
  }

  Future<void> sitzungBeenden(String id) => api.delete('/api/apps/sitzungen/${_p(id)}');

  Future<void> alleAbmelden(String email) => api.post('/api/apps/sitzungen/alle-abmelden', {'email': email});

  Future<List<OffeneBestaetigung>> offeneBestaetigungen() async {
    final j = await api.objekt('/api/me/bestaetigungen');
    return [for (final e in _liste(j['offen'])) OffeneBestaetigung.aus(e)];
  }

  // ── UniFi Access: Benutzer ──
  Future<List<AccessBenutzer>> benutzer() async {
    final j = await api.objekt('/api/access/users');
    final l = [for (final u in _liste(j['users'])) AccessBenutzer.aus(u)];
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  /// Neu (ohne [id]) oder aendern. PIN nur senden, wenn eingegeben.
  Future<void> benutzerSpeichern({String? id, required String vorname, required String nachname, required String email, String? pin}) async {
    final k = <String, Object?>{
      'first_name': vorname,
      'last_name': nachname,
      'email': email,
      if (pin != null && pin.isNotEmpty) 'pin_code': pin,
    };
    if (id == null) {
      await api.post('/api/access/users', k);
    } else {
      await api.put('/api/access/users/${_p(id)}', k);
    }
  }

  Future<void> benutzerLoeschen(String id) => api.delete('/api/access/users/${_p(id)}');

  Future<void> karteEntfernen(String benutzerId, String token) =>
      api.delete('/api/access/users/${_p(benutzerId)}/nfc/${_p(token)}');

  Future<void> karteZuweisen(String benutzerId, String token) =>
      api.post('/api/access/users/${_p(benutzerId)}/nfc', {'token': token});

  Future<List<Zugangsregel>> zugangsregeln() async {
    final j = await api.objekt('/api/access/policies');
    return [for (final p in _liste(j['policies'])) Zugangsregel.aus(p)];
  }

  Future<Set<String>> regelnVon(String benutzerId) async {
    final j = await api.objekt('/api/access/users/${_p(benutzerId)}/policies');
    return {for (final p in _liste(j['policies'])) '${p['id']}'};
  }

  Future<void> regelnSetzen(String benutzerId, Set<String> ids) =>
      api.put('/api/access/users/${_p(benutzerId)}/policies', {'access_policy_ids': ids.toList()});

  // ── Karte am UniFi-Leser anlernen ──
  Future<List<AccessLeser>> leser() async {
    final j = await api.objekt('/api/access/nfc/devices');
    return [for (final d in _liste(j['devices'])) AccessLeser.aus(d)];
  }

  Future<String> anlernenStarten(String? leserId) async {
    final j = _objekt(await api.post('/api/access/nfc/session', {'device_id': ?leserId}));
    final id = j['session_id'];
    if (id == null || '$id'.isEmpty) throw ApiFehler(200, 'UniFi Access hat das Anlernen nicht gestartet.', j);
    return '$id';
  }

  /// Token der aufgelegten Karte oder null (noch keine).
  Future<String?> anlernenStand(String sitzung) async {
    final j = await api.objekt('/api/access/nfc/session/${_p(sitzung)}');
    final d = j['data'];
    if (d is! Map) return null;
    Object? t = d['token'] ?? d['card_id'];
    if (t == null && d['card'] is Map) t = (d['card'] as Map)['token'];
    if (t == null && d['nfc_card'] is Map) t = (d['nfc_card'] as Map)['token'];
    if (t == null && d['cards'] is List && (d['cards'] as List).isNotEmpty && (d['cards'] as List).first is Map) {
      t = ((d['cards'] as List).first as Map)['token'];
    }
    return t == null || '$t'.isEmpty ? null : '$t';
  }

  Future<void> anlernenAbbrechen(String sitzung) => api.delete('/api/access/nfc/session/${_p(sitzung)}');

  // ── Tueren, Besucher, Protokoll ──
  Future<List<Tuer>> tueren() async {
    final j = await api.objekt('/api/access/doors');
    return [for (final d in _liste(j['doors'])) Tuer.aus(d)];
  }

  Future<void> tuerOeffnen(String id) => api.post('/api/access/doors/${_p(id)}/unlock');

  Future<List<BesucherPass>> besucher() async {
    final j = await api.objekt('/api/access/visitors');
    final l = [for (final v in _liste(j['visitors'])) BesucherPass.aus(v)];
    l.sort((a, b) => (b.von ?? DateTime(0)).compareTo(a.von ?? DateTime(0)));
    return l;
  }

  Future<void> besucherAnlegen({
    required String vorname,
    required String nachname,
    required DateTime von,
    required DateTime bis,
    String? bemerkung,
    Set<String> tueren = const {},
  }) =>
      api.post('/api/access/visitors', {
        'first_name': vorname,
        'last_name': nachname,
        'start_time': von.millisecondsSinceEpoch ~/ 1000,
        'end_time': bis.millisecondsSinceEpoch ~/ 1000,
        if (bemerkung != null && bemerkung.isNotEmpty) 'remarks': bemerkung,
        if (tueren.isNotEmpty) 'resources': [for (final t in tueren) {'id': t, 'type': 'door'}],
      });

  Future<void> besucherLoeschen(String id) => api.delete('/api/access/visitors/${_p(id)}');

  /// Zutrittsprotokoll der letzten [tage] Tage. [thema]: door_openings,
  /// critical, admin_activity, visitor.
  Future<List<ZutrittsEreignis>> zutritte({String thema = 'door_openings', int tage = 7}) async {
    final bis = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final j = await api.objekt('/api/access/logs?topic=${_p(thema)}&since=${bis - tage * 86400}&until=$bis');
    final l = _liste(j['logs']);
    return [for (var i = 0; i < l.length; i++) ZutrittsEreignis.aus(l[i], i)];
  }
}
