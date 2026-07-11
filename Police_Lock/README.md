# FiveM Schließfachsystem (`fivem_lockers`)

Performantes, sicheres Schließfachsystem für **ESX** und **QBCore** mit PIN-Zugang, Schlüssel-Items, Admin-Dashboard und moderner NUI.

## Features

- **Framework**: ESX, QBCore/Qbox oder Standalone (Auto-Erkennung)
- **Target**: ox_target (bevorzugt) oder qb-target
- **Inventar**: ox_inventory (bevorzugt) oder qb-inventory
- **Zugangsmodi**: PIN, Schlüssel, PIN+Schlüssel, Job/Rang, Identifier
- **Sicherheit**: Serverseitige Validierung, gehashte PINs, Session-Tokens, Rate-Limits
- **Admin-Dashboard**: Schließfächer & Items ingame verwalten
- **Logging**: Datenbank + optional Discord-Webhooks
- **Sprachen**: Deutsch und Englisch

## Abhängigkeiten

**Pflicht:**
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

**Empfohlen:**
- [ox_target](https://github.com/overextended/ox_target)
- [ox_inventory](https://github.com/overextended/ox_inventory)

**Optional:**
- qb-target, qb-inventory, es_extended, qb-core

## Installation

1. Ordner `Police_Lock` in `resources/[custom]/` legen
2. SQL importieren (optional – Tabellen werden auch automatisch erstellt):

   ```bash
   mysql -u user -p database < Police_Lock/install.sql
   ```

3. In `server.cfg` einbinden:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure ox_target
   ensure ox_inventory
   ensure Police_Lock
   ```

4. ACE-Berechtigungen setzen:

   ```cfg
   add_ace group.admin lockers.admin allow
   add_principal identifier.license:DEINELIZENZ group.admin
   ```

## Konfiguration (`config.lua`)

### Framework / Adapter

```lua
Config.Auto = {
    Framework = true,   -- erkennt ESX oder QBCore
    Target = true,      -- erkennt ox_target oder qb-target
    Inventory = true,   -- erkennt ox_inventory oder qb-inventory
}

-- Manuell:
-- Config.Auto.Framework = false
-- Config.Framework = 'esx'
```

### Debug-Modus

```lua
Config.Debug = true
```

### Discord-Webhook

```lua
Config.Discord = {
    enabled = true,
    webhook = 'https://discord.com/api/webhooks/ID/TOKEN',
    botName = 'Schließfach-System',
    logActions = {
        opened = true,
        wrong_pin = true,
        key_used = true,
        item_taken = true,
        suspicious = true,
    },
}
```

## Beispiel: Polizei-Schließfach (PIN)

Beim ersten Start werden Beispiel-Schließfächer aus `Config.ExampleLockers` angelegt.

- **Name**: Polizei-Waffenschrank
- **PIN**: `1234` (wird gehasht gespeichert – niemals im Klartext an Clients)
- **Zugang**: `pin_or_key`
- **Job**: `police` ab Rang 0
- **Items**: Dienstpistole (ab Rang 2), Munition, Schutzweste

## Beispiel: Schlüssel-Item mit Metadaten

### ox_inventory (`data/items.lua`)

```lua
['evidence_keycard'] = {
    label = 'Beweismittel-Schlüsselkarte',
    weight = 30,
    stack = false,
    close = true,
    description = 'Zugang zum Beweismittel-Tresor',
},
['police_locker_key'] = {
    label = 'Polizei-Schließfachschlüssel',
    weight = 50,
    stack = false,
    close = true,
    description = 'Öffnet autorisierte Polizei-Schließfächer',
},
```

### Schlüssel mit fester Schließfach-ID vergeben

```lua
-- Server-seitig / Admin-Befehl
exports.ox_inventory:AddItem(source, 'police_locker_key', 1, {
    locker_id = 1,
    description = 'Waffenschrank MRPD',
})
```

### Universalschlüssel

Im Admin-Dashboard `key_metadata` setzen:

```json
{ "universal": true }
```

### Schlüssel nur für bestimmte Jobs

```lua
key_job_restrict = { police = 0, sheriff = 0 }
```

## Anleitung ESX

1. `es_extended` und `ox_inventory` starten
2. `Config.Auto.Framework = true` (Standard)
3. Job-Ränge entsprechen `job.grade` in ESX
4. Admin-Gruppen in `Config.Admin.groups.esx` anpassen

## Anleitung QBCore

1. `qb-core` oder `qbx_core` starten
2. `ox_inventory` oder `qb-inventory` nutzen
3. Job-Ränge entsprechen `job.grade.level`
4. Admin-Gruppen in `Config.Admin.groups.qb` anpassen

## Anleitung ox_inventory

- Item-Bilder werden aus `nui://ox_inventory/web/images/` geladen
- Waffen erhalten automatisch Seriennummern bei `registered`/`auto_serial`
- `CanCarryItem` wird vor jeder Entnahme geprüft

## Admin-Befehle

| Befehl | Berechtigung | Beschreibung |
|--------|--------------|--------------|
| `/lockeradmin` | `lockers.admin` | Admin-Dashboard öffnen |

### Admin-Dashboard Funktionen

- Schließfach erstellen, bearbeiten, löschen, duplizieren
- Position über aktuelle Spielerposition setzen
- PIN ändern (wird serverseitig gehasht)
- Schlüssel-Item und Zugangsmodus konfigurieren
- Items mit Rang-Beschränkung verwalten
- Live-Bestand und Transaktionsverlauf
- Teleport zum Schließfach

## Berechtigungsbeispiele (`server.cfg`)

```cfg
# ACE
add_ace group.admin lockers.admin allow
add_ace group.police lockers.admin deny

# ESX-Gruppe admin/superadmin wird automatisch erkannt
# QBCore god/admin wird automatisch erkannt
```

## Sicherheit

- PIN wird mit SHA-512 + Salt gehasht (`pin_hash` in DB)
- Session-Tokens sind kurzlebig und an Spieler + Distanz gebunden
- Alle Item-Transaktionen werden serverseitig validiert
- Rate-Limiting und Request-ID-Duplikatschutz
- Verdächtige Events werden geloggt

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

## Dateistruktur

```
Police_Lock/
├── fxmanifest.lua
├── config.lua
├── install.sql
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
├── locales/
│   ├── de.lua
│   └── en.lua
└── README.md
```

## Version

**1.0.0** – Initiales Release

## Lizenz

Frei verwendbar – Anpassungen für euren Server sind erwünscht.
