# Police_Lock – Fahrzeug-Schließfachsystem (ESX + ox_lib)

Fahrzeug-Schließfächer für **ESX** mit **ox_inventory**, **ox_target** und **ox_lib** (keine HTML-NUI).

![Version](https://img.shields.io/badge/version-1.1.0-orange)
![FiveM](https://img.shields.io/badge/FiveM-ready-green)
![Lua](https://img.shields.io/badge/Lua-5.4-blue)

---

## Inhalt

- [Features](#features)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Konfiguration](#konfiguration)
- [Nutzung im Spiel](#nutzung-im-spiel)
- [Admin-Dashboard](#admin-dashboard)
- [Schlüssel-Items](#schlüssel-items)
- [Beispiel-Schließfächer](#beispiel-schließfächer)
- [ESX & ox_inventory](#esx--ox_inventory)
- [Discord-Logging](#discord-logging)
- [Sicherheit](#sicherheit)
- [Exports](#exports)
- [Support & Lizenz](#support--lizenz)

---

## Features

| Bereich | Details |
|---------|---------|
| **Framework** | ESX (`es_extended`) |
| **Target** | ox_target |
| **Inventar** | ox_inventory |
| **Zuordnung** | Fahrzeugmodell oder Kennzeichen |
| **PIN** | Serverseitige Prüfung, SHA-512-Hash, Sperrzeit bei Fehlversuchen |
| **NUI** | Dunkles Design, orange Akzente, PIN-Pad, Item-Karten |
| **Admin** | Ingame-Dashboard zur vollständigen Verwaltung |
| **Logging** | Datenbank + optional Discord-Webhooks |
| **Sprachen** | Deutsch (`de`) und Englisch (`en`) |

---

## Voraussetzungen

**Pflicht:**
- [es_extended](https://github.com/esx-framework/esx_core) (ESX)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)

---

## Installation

### 1. Resource herunterladen

Repository klonen oder als ZIP laden und in euren `resources`-Ordner legen:

```
resources/[custom]/Police_Lock/
```

### 2. Datenbank

Tabellen werden beim ersten Start **automatisch** erstellt. Alternativ manuell importieren:

```bash
mysql -u USER -p DATENBANK < install.sql
```

### 3. server.cfg

```cfg
ensure ox_lib
ensure oxmysql
ensure es_extended
ensure ox_inventory
ensure ox_target
ensure Police_Lock
```

### 4. Berechtigungen

```cfg
add_ace group.admin lockers.admin allow
add_principal identifier.license:DEINELIZENZ group.admin
```

---

## Konfiguration

Alle Einstellungen in `config.lua`.

### Sprache

```lua
Config.Locale = 'de'  -- 'de' oder 'en'
```

### Debug-Modus

```lua
Config.Debug = true
```

Aktiviert Konsolen-Ausgaben und Target-Debug-Polygone.

### Admin-Gruppen (ESX)

```lua
Config.Admin.groups = { 'admin', 'superadmin' }
```

---

## Nutzung im Spiel

1. Spieler nähert sich einem **Fahrzeug** mit konfiguriertem Schließfach (Kofferraum/Heck)
2. Über **Alt-Auge / Target** die Option **„Schließfach öffnen"** wählen
3. PIN eingeben und/oder Schlüssel-Item verwenden
4. Items entnehmen oder zurücklegen

### Fahrzeug-Zuordnung

| Typ | Beispiel | Beschreibung |
|-----|----------|--------------|
| `model` | `police` | Gilt für alle Fahrzeuge dieses Modells |
| `plate` | `LSPD001` | Gilt nur für dieses Kennzeichen |

### Zugangsmodi (im Admin-Panel mit Label)

| Modus | Beschreibung |
|-------|--------------|
| `pin_only` | Nur PIN |
| `key_only` | Nur Schlüssel-Item |
| `pin_or_key` | PIN oder Schlüssel reicht |
| `pin_and_key` | PIN und Schlüssel erforderlich |
| `job_only` | Nur Job/Rang-Berechtigung |
| `identifier_only` | Nur freigegebene Citizen-IDs |

---

## Admin-Dashboard

| Befehl | Berechtigung | Funktion |
|--------|--------------|----------|
| `/lockeradmin` | `lockers.admin` | Admin-Panel öffnen |

### Funktionen im Dashboard

- Schließfach **erstellen**, **bearbeiten**, **löschen**, **duplizieren**
- **Fahrzeugmodell oder Kennzeichen** zuweisen („Vom aktuellen Fahrzeug übernehmen")
- **Zugangsmodus** mit lesbaren Labels wählen (z. B. „PIN oder Schlüssel")
- PIN setzen, Schlüssel-Item konfigurieren, Items verwalten
- Live-Bestand und Transaktionsverlauf

---

## Schlüssel-Items

### Item in ox_inventory anlegen (`data/items.lua`)

```lua
['police_locker_key'] = {
    label = 'Polizei-Schließfachschlüssel',
    weight = 50,
    stack = false,
    close = true,
    description = 'Öffnet autorisierte Polizei-Schließfächer',
},

['evidence_keycard'] = {
    label = 'Beweismittel-Schlüsselkarte',
    weight = 30,
    stack = false,
    close = true,
    description = 'Zugang zum Beweismittel-Tresor',
},
```

### Schlüssel mit fester Schließfach-ID vergeben

```lua
exports.ox_inventory:AddItem(source, 'police_locker_key', 1, {
    locker_id = 1,
    description = 'Waffenschrank MRPD',
})
```

### Universalschlüssel

```json
{ "universal": true }
```

### Schlüssel nur für bestimmte Jobs

```lua
key_job_restrict = { police = 0, sheriff = 0 }
```

### Schlüssel verbrauchen beim Öffnen

Im Admin-Dashboard: **„Schlüssel verbrauchen"** aktivieren oder in der Config:

```lua
key_consume = true
```

---

## Beispiel-Schließfächer

Beim **ersten Start** werden automatisch zwei Beispiel-Schließfächer angelegt (`Config.ExampleLockers`):

### Polizei-Dienstfahrzeug (`police`)

| Einstellung | Wert |
|-------------|------|
| Zuordnung | Fahrzeugmodell `police` |
| Zugang | PIN oder Schlüssel |
| PIN | `1234` |
| Items | Dienstpistole, Munition, Schutzweste |

### Einsatzfahrzeug SEK (`police2`)

| Zuordnung | Fahrzeugmodell `police2` |
| Zugang | Nur Schlüssel |
| Schlüssel | `evidence_keycard` |

> **Hinweis:** Die PIN `1234` wird nur beim ersten Anlegen verwendet und danach als Hash in der Datenbank gespeichert. Sie wird niemals an Clients gesendet.

---

## ESX & ox_inventory

1. `es_extended`, `ox_inventory` und `ox_target` in der richtigen Reihenfolge starten
2. Job-Ränge entsprechen `job.grade` in ESX
3. Admin-Gruppen in `Config.Admin.groups` anpassen (`admin`, `superadmin`)
4. Item-Bilder: `nui://ox_inventory/web/images/`
5. Waffen-Seriennummern bei `metadata.registered = true`
6. Tragbarkeit wird vor jeder Entnahme mit `CanCarryItem` geprüft

### Schlüssel-Items in ox_inventory (`data/items.lua`)

Siehe Abschnitt [Schlüssel-Items](#schlüssel-items).

---

## Discord-Logging

```lua
Config.Discord = {
    enabled = true,
    webhook = 'https://discord.com/api/webhooks/ID/TOKEN',
    botName = 'Schließfach-System',
    avatar = '',
    logActions = {
        opened = true,
        wrong_pin = true,
        key_used = true,
        item_taken = true,
        item_returned = true,
        admin_change = true,
        suspicious = true,
    },
}
```

Geloggte Informationen: Spielername, Identifier, Schließfach, Aktion, Item, Menge, Uhrzeit.

---

## Sicherheit

- PIN wird mit **SHA-512 + Salt** gehasht – niemals Klartext in DB oder an Client
- **Session-Tokens** sind kurzlebig und an Spieler + Entfernung gebunden
- Alle Transaktionen werden **serverseitig** validiert
- **Rate-Limiting** gegen Event-Spam
- **Request-ID-Duplikatschutz** gegen Item-Duplizierung
- Verdächtige Events werden geloggt und optional an Discord gemeldet

---

## Exports

### Server

```lua
exports['Police_Lock']:GetLocker(lockerId)
exports['Police_Lock']:ReloadLockers()
```

### Client

```lua
exports['Police_Lock']:OpenLocker(lockerId)
exports['Police_Lock']:CloseLocker()
exports['Police_Lock']:OpenAdminPanel()
```

---

## Dateistruktur

```
Police_Lock/
├── fxmanifest.lua
├── config.lua
├── install.sql
├── README.md
├── shared/
│   ├── framework.lua
│   └── utils.lua
├── client/
│   ├── main.lua
│   ├── target.lua
│   └── admin.lua
├── server/
│   ├── database.lua
│   ├── security.lua
│   ├── inventory.lua
│   ├── admin.lua
│   └── main.lua
├── web/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── locales/
    ├── de.lua
    └── en.lua
```

---

## Support & Lizenz

**Version:** 1.1.0

Bei Problemen `Config.Debug = true` aktivieren und die Server-Konsole prüfen.

Frei verwendbar – Anpassungen für euren Server sind erwünscht.
