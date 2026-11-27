// SPDX-License-Identifier: GPL-3.0-or-later
// Was die Haupt-API zu Karten, Personen, Protokoll, Anmeldungen und UniFi Access liefert.

String? _text(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

/// Antwort von „Karte nachschlagen“ (Haupt-API POST /api/karten/info,
/// dahinter karteNachschlagen und UniFi Access).
class Karte {
  const Karte({
    required this.uid,
    required this.bekannt,
    required this.zugeordnet,
    this.status,
    this.inventarnummer,
    this.accessName,
    this.personName,
    this.personEmail,
  });

  final String uid;

  /// In UniFi Access vorhanden.
  final bool bekannt;

  /// Einer Person zugeordnet (meldet an, oeffnet Tueren).
  final bool zugeordnet;
  final String? status;

  /// `display_id` in UniFi Access (aufgedruckte Nummer).
  final String? inventarnummer;
  final String? accessName;
  final String? personName;
  final String? personEmail;

  factory Karte.aus(String uid, Map<String, dynamic> j) {
    final p = j['person'];
    return Karte(
      uid: _text(j['uid']) ?? uid,
      bekannt: j['found'] == true,
      zugeordnet: j['assigned'] == true,
      status: _text(j['status']),
      inventarnummer: _text(j['display_id']),
      accessName: _text(j['access_name']),
      personName: p is Map ? _text(p['name']) : null,
      personEmail: p is Map ? _text(p['email']) : null,
    );
  }

  /// Hat einen Inhaber (Person im Portal oder Name in UniFi Access).
  bool get hatInhaber => zugeordnet || personEmail != null || personName != null || accessName != null;

  /// Wem sie gehoert, als Satz.
  String get inhaber {
    if (!bekannt) return 'Unbekannte Karte';
    return personName ?? accessName ?? personEmail ?? 'Freie Karte';
  }

  String get nummerText {
    if (!bekannt) return 'Nicht in UniFi Access';
    return inventarnummer == null ? 'Ohne Inventarnummer' : 'Inventarnummer $inventarnummer';
  }

  String get zustandText {
    if (!bekannt) return 'Beim Zuordnen wird sie in UniFi Access angelegt.';
    if (zugeordnet) return 'Zugeordnet – meldet an und öffnet Türen';
    final s = status;
    if (s == null || s.toLowerCase() == 'unassigned') return 'Frei – keiner Person zugeordnet';
    return 'Status: $s';
  }

  /// Name fuer Rueckfragen („Karte 0042“ bzw. die UID).
  String get kurzName => inventarnummer ?? uid;

  /// Aus dem Bestand loeschen geht nur bei bekannten Karten ohne Inhaber.
  bool get loeschbar => bekannt && !hatInhaber;
}

/// Person fuer „Einer Person zuordnen“.
class Person {
  const Person({required this.name, required this.email});
  final String name;
  final String email;

  factory Person.aus(Map<String, dynamic> j) =>
      Person(name: _text(j['name']) ?? _text(j['email']) ?? '', email: (_text(j['email']) ?? '').toLowerCase());

  bool passt(String suche) {
    final q = suche.trim().toLowerCase();
    return q.isEmpty || name.toLowerCase().contains(q) || email.contains(q);
  }
}

/// Eintrag im Kartenprotokoll (GET /api/karten/protokoll).
class ProtokollEintrag {
  const ProtokollEintrag({
    required this.id,
    required this.aktion,
    required this.zeit,
    required this.erfolg,
    this.inventarnummer,
    this.nfcId,
    this.zielName,
    this.zielEmail,
    this.durch,
    this.detail,
  });

  final String id;
  final String aktion;
  final DateTime? zeit;
  final bool erfolg;
  final String? inventarnummer;
  final String? nfcId;
  final String? zielName;
  final String? zielEmail;
  final String? durch;
  final String? detail;

  factory ProtokollEintrag.aus(Map<String, dynamic> j) => ProtokollEintrag(
        id: '${j['id']}',
        aktion: _text(j['aktion']) ?? '',
        zeit: DateTime.tryParse('${j['created_at']}')?.toLocal(),
        erfolg: j['erfolg'] != false,
        inventarnummer: _text(j['display_id']),
        nfcId: _text(j['nfc_id']),
        zielName: _text(j['ziel_name']),
        zielEmail: _text(j['ziel_email']),
        durch: _text(j['durch']),
        detail: _text(j['detail']),
      );

  /// Aktion als deutsches Wort.
  String get aktionText => aktionTexte[aktion] ?? aktion;

  String get wen => zielName ?? zielEmail ?? '';

  String get suchText => [aktionText, inventarnummer, nfcId, zielName, zielEmail, durch, detail].whereType<String>().join(' ');

  static const aktionTexte = {
    'zuordnen': 'Zugeordnet',
    'entziehen': 'Entzogen',
    'loeschen': 'Gelöscht',
    'info': 'Nachgeschlagen',
    'anmelden': 'Anmeldung (Telefon)',
    'app-anmeldung': 'Anmeldung (App)',
    'app-abmeldung': 'Abmeldung (App)',
    'admin-mit-karte': 'Admin mit Karte',
    'bestaetigung-angefragt': 'Bestätigung angefragt',
    'bestaetigt': 'Bestätigt',
    'abgelehnt': 'Abgelehnt',
  };
}

/// Karten-, QR- oder Handy-Anmeldung einer App (GET /api/apps/sitzungen).
class AppSitzung {
  const AppSitzung({
    required this.id,
    required this.email,
    required this.name,
    required this.app,
    required this.geraet,
    required this.art,
    this.plattform,
    this.karte,
    this.erstellt,
    this.zuletzt,
    this.ablauf,
    this.widerrufen,
  });

  final String id;
  final String email;
  final String name;
  final String app;
  final String geraet;

  /// karte, qr oder handy.
  final String art;
  final String? plattform;
  final String? karte;
  final DateTime? erstellt;
  final DateTime? zuletzt;
  final DateTime? ablauf;
  final DateTime? widerrufen;

  factory AppSitzung.aus(Map<String, dynamic> j) {
    DateTime? zeit(String f) => DateTime.tryParse('${j[f]}')?.toLocal();
    return AppSitzung(
      id: '${j['id']}',
      email: (_text(j['email']) ?? '').toLowerCase(),
      name: _text(j['name']) ?? _text(j['email']) ?? '',
      app: _text(j['app_name']) ?? _text(j['app']) ?? 'App',
      geraet: _text(j['geraet_name']) ?? 'Gerät',
      art: _text(j['art']) ?? 'karte',
      plattform: _text(j['plattform']),
      karte: _text(j['karte_anzeige']),
      erstellt: zeit('created_at'),
      zuletzt: zeit('last_used_at'),
      ablauf: zeit('expires_at'),
      widerrufen: zeit('revoked_at'),
    );
  }

  String get artText => switch (art) {
        'qr' => 'QR-Code',
        'handy' => 'mit dem Handy',
        'anlage' => 'geteiltes Telefon',
        _ => karte == null ? 'Karte' : 'Karte $karte',
      };

  String get suchText => '$name $email $app $geraet ${karte ?? ''}';
}

/// Offene Bestaetigung per E-Mail (GET /api/me/bestaetigungen).
class OffeneBestaetigung {
  const OffeneBestaetigung({required this.id, required this.text, this.ablauf});
  final String id;
  final String text;
  final DateTime? ablauf;

  factory OffeneBestaetigung.aus(Map<String, dynamic> j) => OffeneBestaetigung(
        id: '${j['id']}',
        text: _text(j['text']) ?? 'Aktion',
        ablauf: DateTime.tryParse('${j['ablauf']}')?.toLocal(),
      );
}

/// 27.11.2026 14:05
String wannText(DateTime? z) {
  if (z == null) return '–';
  String zwei(int n) => n.toString().padLeft(2, '0');
  return '${zwei(z.day)}.${zwei(z.month)}.${z.year} ${zwei(z.hour)}:${zwei(z.minute)}';
}

// ─── UniFi Access (Haupt-API /api/access/*) ─────────────────────────────────

/// Zeitpunkt aus Sekunden, Millisekunden oder ISO-Text.
DateTime? zeitAus(Object? v) {
  if (v == null) return null;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch((v < 1e12 ? v * 1000 : v).round()).toLocal();
  final n = num.tryParse('$v');
  if (n != null) return zeitAus(n);
  return DateTime.tryParse('$v')?.toLocal();
}

/// Karte eines Access-Benutzers (`nfc_cards` im Benutzer).
class AccessKarte {
  const AccessKarte({required this.token, required this.bezeichnung});
  final String token;
  final String bezeichnung;

  factory AccessKarte.aus(Map<String, dynamic> j) {
    final token = _text(j['token']) ?? _text(j['id']) ?? _text(j['card_id']) ?? '';
    final nummer = _text(j['display_id']);
    final kurz = (_text(j['id']) ?? token);
    return AccessKarte(
      token: token,
      bezeichnung: nummer != null ? 'Karte $nummer' : 'Karte ····${kurz.length > 4 ? kurz.substring(kurz.length - 4) : kurz}',
    );
  }
}

/// Benutzer in UniFi Access (Person mit PIN, Karten und Zugangsregeln).
class AccessBenutzer {
  const AccessBenutzer({
    required this.id,
    required this.vorname,
    required this.nachname,
    required this.email,
    required this.status,
    required this.pinGesetzt,
    required this.karten,
    this.personalNummer,
  });

  final String id;
  final String vorname;
  final String nachname;
  final String email;
  final String status;
  final bool pinGesetzt;
  final List<AccessKarte> karten;
  final String? personalNummer;

  factory AccessBenutzer.aus(Map<String, dynamic> j) {
    final k = j['nfc_cards'];
    return AccessBenutzer(
      id: '${j['id']}',
      vorname: _text(j['first_name']) ?? '',
      nachname: _text(j['last_name']) ?? '',
      email: (_text(j['email']) ?? _text(j['user_email']) ?? '').toLowerCase(),
      status: _text(j['status']) ?? '',
      pinGesetzt: _text(j['pin_code']) != null,
      karten: [for (final c in k is List ? k : const []) if (c is Map<String, dynamic>) AccessKarte.aus(c)],
      personalNummer: _text(j['employee_number']),
    );
  }

  String get name {
    final n = '$vorname $nachname'.trim();
    return n.isEmpty ? (email.isEmpty ? id : email) : n;
  }

  bool get aktiv => status.toUpperCase() == 'ACTIVE';

  String get statusText => switch (status.toUpperCase()) {
        'ACTIVE' => 'Aktiv',
        'PENDING' => 'Eingeladen',
        'DEACTIVATED' || 'INACTIVE' => 'Gesperrt',
        '' => '–',
        _ => status,
      };

  String get suchText => '$name $email ${personalNummer ?? ''}';
}

/// Zugangsregel (Access Policy: Türen und Zeitplan).
class Zugangsregel {
  const Zugangsregel({required this.id, required this.name});
  final String id;
  final String name;
  factory Zugangsregel.aus(Map<String, dynamic> j) => Zugangsregel(id: '${j['id']}', name: _text(j['name']) ?? '${j['id']}');
}

/// Tuer mit Live-Stand (GET /api/access/doors).
class Tuer {
  const Tuer({required this.id, required this.name, this.ganzerName, this.verriegelt, this.offen, this.online});
  final String id;
  final String name;
  final String? ganzerName;
  final bool? verriegelt;
  final bool? offen;
  final bool? online;

  factory Tuer.aus(Map<String, dynamic> j) {
    final lock = _text(j['lock_state']);
    final pos = _text(j['position']);
    final on = j['online'];
    return Tuer(
      id: '${j['id']}',
      name: _text(j['name']) ?? _text(j['full_name']) ?? 'Tür',
      ganzerName: _text(j['full_name']),
      verriegelt: lock == null ? null : lock == 'lock',
      offen: pos == null ? null : pos == 'open',
      online: on == null ? null : (on == true || on == 'true'),
    );
  }

  String get zustandText => [
        if (online == false) 'offline',
        if (verriegelt != null) verriegelt! ? 'verriegelt' : 'entriegelt',
        if (offen == true) 'steht offen',
      ].join(' · ');
}

/// Besucher-Pass (temporaerer Zutritt).
class BesucherPass {
  const BesucherPass({required this.id, required this.name, this.von, this.bis, this.status, this.bemerkung});
  final String id;
  final String name;
  final DateTime? von;
  final DateTime? bis;
  final String? status;
  final String? bemerkung;

  factory BesucherPass.aus(Map<String, dynamic> j) => BesucherPass(
        id: '${j['id']}',
        name: _text(j['full_name']) ?? '${_text(j['first_name']) ?? ''} ${_text(j['last_name']) ?? ''}'.trim(),
        von: zeitAus(j['start_time']),
        bis: zeitAus(j['end_time']),
        status: _text(j['status']),
        bemerkung: _text(j['remarks']),
      );

  String get zeitraum {
    final a = von, b = bis;
    if (a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day) {
      return '${wannText(a)}–${wannText(b).split(' ').last}';
    }
    return '${wannText(a)} – ${wannText(b)}';
  }

  String get statusText => switch ((status ?? '').toUpperCase()) {
        'ACTIVE' || 'VISITING' => 'Gültig',
        'UPCOMING' => 'Kommt noch',
        'VISITED' || 'EXPIRED' => 'Abgelaufen',
        'CANCELLED' => 'Abgesagt',
        '' => '',
        _ => status!,
      };
}

/// Karten-Leser in UniFi Access (zum Anlernen).
class AccessLeser {
  const AccessLeser({required this.id, required this.name, this.modell, this.online = true});
  final String id;
  final String name;
  final String? modell;
  final bool online;
  factory AccessLeser.aus(Map<String, dynamic> j) =>
      AccessLeser(id: '${j['id']}', name: _text(j['name']) ?? '${j['id']}', modell: _text(j['model']), online: j['online'] != false);
}

/// Ereignis im Zutrittsprotokoll (UniFi Access system/logs).
class ZutrittsEreignis {
  const ZutrittsEreignis({required this.schluessel, this.zeit, this.person, required this.ereignis, this.tuer});
  final String schluessel;
  final DateTime? zeit;
  final String? person;
  final String ereignis;
  final String? tuer;

  factory ZutrittsEreignis.aus(Map<String, dynamic> h, int nr) {
    final s = h['_source'] is Map<String, dynamic> ? h['_source'] as Map<String, dynamic> : h;
    final ev = s['event'] is Map ? s['event'] as Map : const {};
    final actor = s['actor'] is Map ? s['actor'] as Map : const {};
    final ziel = s['target'];
    final zeit = h['@timestamp'] ?? s['@timestamp'] ?? s['timestamp'] ?? ev['published'] ?? s['published'];
    return ZutrittsEreignis(
      schluessel: _text(h['_id']) ?? _text(ev['log_key']) ?? '$nr',
      zeit: zeitAus(zeit),
      person: _text(actor['display_name']) ?? _text(actor['name']) ?? _text(s['actor_name']),
      ereignis: _text(ev['display_message']) ?? _text(ev['type']) ?? _text(s['display_message']) ?? _text(s['message']) ?? 'Ereignis',
      tuer: ziel is List
          ? ziel.whereType<Map>().map((t) => _text(t['display_name']) ?? _text(t['name'])).whereType<String>().join(', ')
          : null,
    );
  }

  String get suchText => '${person ?? ''} $ereignis ${tuer ?? ''}';
}
