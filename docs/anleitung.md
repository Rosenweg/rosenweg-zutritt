# Rosenweg Zutritt – Anleitung

Türen, Access-Benutzer, Besucher-Pässe und Rosenweg-Karten verwalten; Zutritts- und Kartenprotokoll.

## Installieren

Auf [www.rosenweg4303.ch/apps](https://www.rosenweg4303.ch/apps) die Datei für das
eigene Gerät laden. An den Rosenweg-Stationen ist die App schon da (Startmenü,
Bereich „Rosenweg“).

## Anmelden

Beim ersten Start „Mit Rosenweg-Konto anmelden“, die Rosenweg-Karte an den Leser
halten oder den QR-Code mit dem Handy bestätigen. An den Stationen geht es ohne
Eingabe (Domänenanmeldung). Auf den geteilten Telefonen meldet die Karte am
Telefon an – in der App gibt es dann kein „Abmelden“.

## Bedienung

Rosenweg Zutritt ist für die Technik und den Präsidenten. Andere sehen nach der
Anmeldung nur den Satz „Rosenweg Zutritt ist nur für Technik und Präsident.“

### Karte – wem gehört diese Karte?

Karte an die Rückseite des Handys halten bzw. auf den Kartenleser der Station
legen (oder „Nummer eintippen“). Die App zeigt Inhaber, Inventarnummer und Stand.

- **Einer Person zuordnen** (nur freie oder unbekannte Karten): Person suchen,
  bestätigen. Unbekannte Karten legt die App dabei in UniFi Access an. Die
  Türleser übernehmen das in etwa 30 Sekunden.
- **Entziehen**: Die Karte öffnet keine Türen mehr und meldet niemanden mehr an;
  sie bleibt im Bestand.
- **Aus dem Bestand löschen** (nur freie Karten): defekt oder verloren.

### Personen

Alle Benutzer in UniFi Access, mit Suche und den Filtern „Ohne Karte“ und
„Gesperrt“. Antippen zeigt:

- **Angaben**: Vorname, Nachname, E-Mail (wie im Rosenweg-Konto), PIN für die
  Türen (leer lassen = unverändert). „Speichern“.
- **Karten**: entfernen (−), **Am UniFi-Leser anlernen** (Leser wählen, neue Karte
  hinhalten; die App wartet bis 60 Sekunden) oder **Mit diesem Gerät lesen**
  (Handy oder Station; braucht die E-Mail der Person).
- **Zugang**: Zugangsregeln an- und abhaken, wird sofort gespeichert.
- **Person aus UniFi Access löschen** (ganz unten, mit Rückfrage).

„Neue Person“ (unten rechts) legt einen Benutzer an; Karten und Zugang danach.

### Besucher

Besucher-Pässe, standardmässig nur aktuelle und kommende. „Neuer Pass“: Name,
von – bis, Türen (keine gewählt = wie in UniFi Access für Besucher
voreingestellt), Bemerkung. Löschen mit dem Papierkorb.

### Protokoll

Oben umschalten:

- **Zutritte**: Ereignisse der letzten 7 Tage aus UniFi Access, wählbar
  Türöffnungen, Kritisch, Besucher, Admin.
- **Türen**: Stand jeder Tür (verriegelt, entriegelt, steht offen, offline);
  „Öffnen“ entriegelt nach Rückfrage kurz.
- **Karten**: Kartenprotokoll der letzten 30 Tage (zugeordnet, entzogen,
  gelöscht, Anmeldungen, Admin mit Karte, Bestätigungen).

### Anmeldungen

Karten-, QR- und Handy-Anmeldungen der Rosenweg-Apps aller Personen. Antippen:
„Diese Anmeldung beenden“ oder „Alle Apps dieser Person abmelden“ (z. B. Karte
verloren).

### Mit der Karte angemeldet

Die Karte gilt wie ein Schlüssel: alles geht. Jede Änderung steht im
Kartenprotokoll und kommt als Quittung per E-Mail. Heikle Aktionen laufen erst,
wenn du sie in der E-Mail bestätigst – die App sagt dann „Bestätigung per E-Mail
nötig“.

### Rosenweg Karten

Rosenweg Zutritt ersetzt Rosenweg Karten. Wo Karten noch installiert ist: Zutritt
installieren, Karten deinstallieren.

## Aktualisieren

Die App meldet neue Fassungen selbst („Neue Fassung verfügbar“). Auf den
Stationen und mit Rosenweg Gerät aktualisiert die Technik, dort kommt kein
Hinweis.
