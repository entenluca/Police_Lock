# Police_Lock – FiveM Schließfachsystem

Performantes und sicheres Schließfachsystem für **ESX** und **QBCore** mit PIN-Zugang, Schlüssel-Items, Admin-Dashboard und moderner NUI.

![Version](https://img.shields.io/badge/version-1.0.0-orange)
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
- [Framework-Anleitungen](#framework-anleitungen)
- [Discord-Logging](#discord-logging)
- [Sicherheit](#sicherheit)
- [Exports](#exports)
- [Support & Lizenz](#support--lizenz)

---

## Features

| Bereich | Details |
|---------|---------|
| **Framework** | ESX, QBCore/Qbox, Standalone – Auto-Erkennung |
| **Target** | ox_target (bevorzugt) oder qb-target |
| **Inventar** | ox_inventory (bevorzugt) oder qb-inventory |
| **Zugang** | PIN, Schlüssel, PIN+Schlüssel, Job/Rang, Identifier |
| **PIN** | Serverseitige Prüfung, SHA-512-Hash, Sperrzeit bei Fehlversuchen |
| **NUI** | Dunkles Design, orange Akzente, PIN-Pad, Item-Karten |
| **Admin** | Ingame-Dashboard zur vollständigen Verwaltung |
| **Logging** | Datenbank + optional Discord-Webhooks |
| **Sprachen** | Deutsch (`de`) und Englisch (`en`) |

---

## Voraussetzungen

**Pflicht:**
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

**Empfohlen:**
- [ox_target](https://github.com/overextended/ox_target)
- [ox_inventory](https://github.com/overextended/ox_inventory)

**Optional:**
- qb-target, qb-inventory, es_extended, qb-core, qbx_core

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
ensure ox_target
ensure ox_inventory
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

### Auto-Erkennung (Standard)

```lua
Config.Auto = {
    Framework = true,   -- ESX oder QBCore
    Target = true,      -- ox_target oder qb-target
    Inventory = true,   -- ox_inventory oder qb-inventory
}
```

### Manuell festlegen

```lua
Config.Auto.Framework = false
Config.Framework = 'esx'          -- 'esx' | 'qb' | 'standalone'

Config.Auto.Target = false
Config.Target = 'ox_target'       -- 'ox_target' | 'qb-target'

Config.Auto.Inventory = false
Config.Inventory = 'ox_inventory' -- 'ox_inventory' | 'qb-inventory'
```

### Sprache

```lua
Config.Locale = 'de'  -- 'de' oder 'en'
```

### Debug-Modus

```lua
Config.Debug = true
```

Aktiviert Konsolen-Ausgaben und Target-Debug-Polygone.

---

## Nutzung im Spiel

1. Spieler nähert sich einem Schließfach
2. Über **Alt-Auge / Target** die Option **„Schließfach öffnen"** wählen
3. Je nach Konfiguration:
   - **PIN** über Nummernblock eingeben
   - **Schlüssel-Item** im Inventar verwenden
   - Oder beides (je nach Zugangsmodus)
4. Nach erfolgreicher Authentifizierung öffnet sich die Item-Oberfläche
5. Items **entnehmen** oder **zurücklegen** (sofern erlaubt)

### Zugangsmodi

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
- **Position** über aktuelle Spielerposition setzen
- **PIN** setzen oder ändern (wird serverseitig gehasht)
- **Schlüssel-Item** und Zugangsmodus konfigurieren
- **Jobs**, Ränge und freigegebene Spieler verwalten
- **Items** mit Bestand, Maximalmenge, Rang-Beschränkung hinzufügen
- **Live-Bestand** und **Transaktionsverlauf** einsehen
- Zum Schließfach **teleportieren**

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

### Polizei-Waffenschrank

| Einstellung | Wert |
|-------------|------|
| Zugang | `pin_or_key` |
| PIN | `1234` |
| Schlüssel | `police_locker_key` |
| Job | `police` ab Rang 0 |
| Items | Dienstpistole (Rang 2+), 9mm Munition, Schutzweste |

### Beweismittel-Tresor

| Einstellung | Wert |
|-------------|------|
| Zugang | `key_only` |
| Schlüssel | `evidence_keycard` |
| Job | `police` ab Rang 3 |
| Items | Beweismitteltüten (unbegrenzt) |

> **Hinweis:** Die PIN `1234` wird nur beim ersten Anlegen verwendet und danach als Hash in der Datenbank gespeichert. Sie wird niemals an Clients gesendet.

---

## Framework-Anleitungen

### ESX

1. `es_extended` + `ox_inventory` starten
2. `Config.Auto.Framework = true` (Standard)
3. Job-Ränge = `job.grade` in ESX
4. Admin-Gruppen in `Config.Admin.groups.esx` anpassen (`admin`, `superadmin`)

### QBCore / Qbox

1. `qb-core` oder `qbx_core` starten
2. `ox_inventory` oder `qb-inventory` nutzen
3. Job-Ränge = `job.grade.level`
4. Admin-Gruppen in `Config.Admin.groups.qb` anpassen (`god`, `admin`)

### ox_inventory

- Item-Bilder: `nui://ox_inventory/web/images/`
- Waffen-Seriennummern bei `metadata.registered = true`
- Tragbarkeit wird vor jeder Entnahme mit `CanCarryItem` geprüft

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

**Version:** 1.0.0

Bei Problemen `Config.Debug = true` aktivieren und die Server-Konsole prüfen.

Frei verwendbar – Anpassungen für euren Server sind erwünscht.
