<p align="center"><img src="assets/logo/rosenweg-zutritt-512.png" width="96" alt="Logo"></p>
<h1 align="center">Rosenweg Zutritt</h1>
<p align="center">Türen, Access-Benutzer, Besucher-Pässe und Rosenweg-Karten verwalten; Zutritts- und Kartenprotokoll.</p>
<p align="center"><a href="docs/anleitung.md">Anleitung</a> · <a href="https://www.rosenweg4303.ch/apps">Herunterladen</a></p>

Angelegt mit `werkzeug/neue-app.sh` aus der App-Vorlage von
[rosenweg-basis](https://github.com/Rosenweg/rosenweg-basis). Anmeldung, API,
Gerüst, Updater und Logo kommen aus der Basis; hier steht nur, was diese App
eigen macht.

## Läuft auf

| Plattform | Datei | Grenzen |
|---|---|---|
| Linux (Debian 13, Stationen und eigene Rechner) | `rosenweg-zutritt_<version>_amd64.deb` | Stationen bekommen das Paket vom PXE-Server (os-stationen), dort ist der Updater aus |
| Android 8 und neuer | `rosenweg-zutritt-<version>.apk` (Rosenweg-Schlüssel) | auf geteilten Telefonen meldet Rosenweg Gerät an und ab |
| Windows 10/11 | `Rosenweg-Zutritt-<version>-Setup.exe` | unsigniert, solange kein Code-Signing-Zertifikat da ist (SmartScreen fragt einmal) |
| macOS 11 und neuer | `Rosenweg-Zutritt-<version>.dmg` | ohne Apple Developer ID ad hoc signiert (Gatekeeper fragt beim ersten Start) |
| iOS/iPadOS | – | baut in CI ohne Signatur, verteilt wird erst mit dem Apple Developer Program |

Karten lesen: Android über NFC, iOS über Core NFC (erst mit Apple Developer Program verteilt), Linux/macOS/Windows über einen USB-NFC-Leser (PC/SC, z. B. ACR122U) – an den Stationen der Leser am Arbeitsplatz. Ohne Leser: Nummer eintippen oder am UniFi-Leser anlernen.

Herunterladen: [www.rosenweg4303.ch/apps](https://www.rosenweg4303.ch/apps).

## Bedienung

Nur für Technik und Präsident. Fünf Bereiche (Handy unten, Computer links):

| Bereich | Was |
|---|---|
| Karte | Karte hinhalten (Handy, NFC) bzw. auflegen (Station, USB-Leser über PC/SC) oder Nummer eintippen → wem gehört sie; einer Person zuordnen, entziehen, aus dem Bestand löschen |
| Personen | Benutzer in UniFi Access: Angaben und PIN, Karten (am UniFi-Leser anlernen, mit diesem Gerät lesen, entfernen), Zugangsregeln, löschen; „Neue Person“ |
| Besucher | Besucher-Pässe mit Zeitraum und Türen anlegen, löschen |
| Protokoll | Zutritte (Türöffnungen, Kritisch, Besucher, Admin), Türen (Stand, öffnen mit Rückfrage), Kartenprotokoll |
| Anmeldungen | Karten-, QR- und Handy-Anmeldungen der Apps aller Personen, einzeln oder alle einer Person abmelden |

Ausführlich: [docs/anleitung.md](docs/anleitung.md).

Mit der Karte angemeldet gilt die Karte wie ein Schlüssel (volle Rechte). Jede
Änderung steht dann im Kartenprotokoll („Admin mit Karte“) und kommt als
Quittung per E-Mail; heikle Aktionen laufen erst nach der Bestätigung per E-Mail
(Antwort 202, die App zeigt den Hinweis).

## API

Alles geht an die Haupt-API (`www.rosenweg4303.ch`), auf geteilten Telefonen über
Rosenweg Gerät (`portal_anfrage`, Anlage-Token der Telefonanlage). Kein Aufruf
geht mehr an `pbx.rosenweg4303.ch`.

| Pfad | wofür |
|---|---|
| `POST /api/karten/info`, `/zuordnen`, `/entziehen`, `/loeschen`; `GET /api/karten/personen`, `/api/karten/protokoll` | Karten (vormals `/api/telefon/karten/*` der Telefonanlage) |
| `GET /api/apps/sitzungen?alle=1`, `DELETE /api/apps/sitzungen/:id`, `POST /api/apps/sitzungen/alle-abmelden` | Anmeldungen (auch mit der Karte) |
| `GET /api/me/bestaetigungen` | offene Bestätigungen per E-Mail |
| `GET/POST /api/access/users`, `PUT/DELETE /api/access/users/:id`, `GET/PUT /api/access/users/:id/policies`, `POST /api/access/users/:id/nfc`, `DELETE /api/access/users/:id/nfc/:token`, `GET /api/access/policies` | Personen in UniFi Access |
| `GET /api/access/nfc/devices`, `POST /api/access/nfc/session`, `GET/DELETE /api/access/nfc/session/:id` | Karte am UniFi-Leser anlernen |
| `GET/POST /api/access/visitors`, `DELETE /api/access/visitors/:id` | Besucher-Pässe |
| `GET /api/access/doors`, `POST /api/access/doors/:id/unlock`, `GET /api/access/logs` | Türen, Zutrittsprotokoll |

Auf geteilten Telefonen braucht die Telefonanlage dafür in `portal_pfade` für
`ch.rosenweg4303.zutritt`: `/api/karten/`, `/api/access/`, `/api/apps/sitzungen`
(GET) und `/api/apps/sitzungen/`, `GET /api/me/bestaetigungen`.

## Ablösung von Rosenweg Karten

Rosenweg Zutritt ersetzt Rosenweg Karten ganz (Entscheid Stefan 27.11.2026): die
Java-App (1.6.3) und der nie veröffentlichte Flutter-Neubau Karten 2.0
(rosenweg-karten#11, hier aufgegangen) werden aufgegeben. Zutritt hat ein eigenes
Paket (`ch.rosenweg4303.zutritt`), es gibt keinen Update-Pfad von
`ch.rosenweg4303.karten`. Karten ist nur auf zwei Telefonen installiert; dort
Zutritt installieren und Karten von Hand deinstallieren (Stefan). Über das Repo
`rosenweg-karten` (archivieren oder nicht) entscheidet Stefan.

## Noch offen

- Logo-Zeichen (Schlüssel mit Karte): aus basis#24; die Symbole hier sind damit erzeugt.

## Entwickeln

```sh
# rosenweg-basis daneben auschecken, dann lokal gegen sie bauen:
printf 'dependency_overrides:\n  rosenweg_basis:\n    path: ../rosenweg-basis\n' > pubspec_overrides.yaml
flutter pub get
flutter run -d macos                       # oder linux, windows, ein Handy
flutter run -d macos --dart-define=RW_ATTRAPPE=1   # ohne Server, mit Vorführdaten (lib/attrappe.dart)
flutter analyze && flutter test
RW_FOTO=$HOME/Downloads flutter test test/bildschirmfoto_test.dart   # Bildschirmfotos
```

Vor dem Commit `pubspec_overrides.yaml` entfernen und `flutter pub get` laufen lassen –
`pubspec.lock` darf nicht auf `../rosenweg-basis` zeigen (die CI bricht sonst ab).

| Ordner | Inhalt |
|---|---|
| `lib/app.dart` | `RosenwegApp`: Kennung `ch.rosenweg4303.zutritt`, Name, Logo |
| `lib/seiten/` | die Seiten der App (`RosenwegGeruest`: Handy unten, Desktop links) |
| `lib/attrappe.dart` | Vorführdaten statt der API (Tests, Bildschirmfotos) |
| `assets/logo/` | Logo aus dem Baukasten der Basis: `sh assets/logo/erzeugen.sh ../rosenweg-basis` |
| `linux/paket/` | Debian-Paket (`bauen.sh`, im Bau-Container `im-container.sh`), `paket.conf` = Vorlage für os-stationen |
| `macos/installer/` | DMG (`bauen.sh`) |
| `windows/installer/` | Inno-Setup-Installer |
| `.github/workflows/` | `app.yml` (Bau, Release) und `apps.yml` (an /apps) – die Arbeit macht rosenweg-basis |

## Veröffentlichen

1. Version in `pubspec.yaml` erhöhen (`version: x.y.z+n`, Baunummer immer mit).
2. Pull Request, CI grün (Linux und Android), Merge auf main.
3. Die CI baut alle fünf Plattformen, legt das Release `vx.y.z` an und schickt
   APK, `.deb`, DMG und Installer an `/apps`. Ohne neue Version passiert nach dem
   Merge nur die CI.
4. Stationen: `linux/paket/paket.conf` in os-stationen (`pakete/rosenweg-zutritt/`)
   mit Version und Prüfsumme nachführen.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE). Logo-Zeichen: siehe rosenweg-basis
`werkzeug/logo/zeichen/LIZENZEN.md`.
