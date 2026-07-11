# AutoGlovebox

FiveM-Resource, die Fahrzeugen beim Spawnen automatisch konfigurierte Items ins Handschuhfach legt.

## Features

- Fahrzeuge nach **Modell** oder **Kennzeichen** konfigurierbar
- **Admin-Panel** zur Verwaltung aller Loadouts in der Datenbank
- Items werden beim ersten Spawn/Ausparken automatisch ins Handschuhfach gelegt
- Modus **einmal pro Fahrzeug** (`once`) oder **bei jedem Spawn** (`always`)
- Unterstützung für **QBCore**, **ESX** und **ox_inventory**
- Automatische Erkennung von Framework und Inventarsystem

## Unterstützte Setups

| Framework | Inventarsystem | Status |
|-----------|----------------|--------|
| QBCore / Qbox | qb-inventory | Unterstützt |
| QBCore / Qbox | ox_inventory | Unterstützt |
| ESX | ox_inventory | Unterstützt (empfohlen) |
| ESX | owned_vehicles.glovebox | Unterstützt (ohne ox_inventory) |
| Standalone | ox_inventory | Unterstützt |

## Abhängigkeiten

**Pflicht:**

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

**Mindestens eines davon:**

- [ox_inventory](https://github.com/overextended/ox_inventory)
- [qb-inventory](https://github.com/qbcore-framework/qb-inventory)
- [es_extended](https://github.com/esx-framework/esx_core)

## Installation

1. Resource in den `resources`-Ordner legen
2. In `server.cfg` einbinden (Datenbank-Tabellen werden beim Start automatisch erstellt)
3. ACE-Berechtigungen setzen:

   ```cfg
   add_ace group.admin autoglovebox.admin allow
   add_ace group.admin autoglovebox.equip allow
   add_principal identifier.license:DEINELIZENZ group.admin
   ```

## Konfiguration (`config.lua`)

```lua
Config.Auto = {
    Framework = true,
    Inventory = true,
}

Config.AddMode = 'once'

Config.AdminPanel = {
    enabled = true,
    command = 'gloveboxadmin',
    permission = 'autoglovebox.admin',
    fillDistance = 50.0,
}
```

Fahrzeug-Loadouts werden **nicht mehr in der Config** gepflegt, sondern über das Admin-Panel in der Datenbank.

Beim ersten Start werden Standard-Loadouts angelegt:

- `sektranser` → Zugführerweste, Einsatzmappe, Taschenlampe
- `hlf` → Atemschutzmasken, Feuerwehraxt

## Admin-Panel

| Befehl | Berechtigung | Beschreibung |
|--------|--------------|--------------|
| `/gloveboxadmin` | `autoglovebox.admin` | Admin-Panel öffnen |
| `/gloveboxequip` | `autoglovebox.equip` | Aktuelles Fahrzeug manuell ausrüsten |

Im Panel kannst du:

- Loadouts nach **Modell** oder **Kennzeichen** erstellen
- Items mit Anzahl hinzufügen und entfernen
- Add-Modus pro Loadout setzen (`once` / `always`)
- Loadouts kopieren (Modell → neues Fahrzeug)
- **Fahrzeug jetzt befüllen** – Handschuhfach aus bis zu 50 m Entfernung befüllen
- Once-Status für Kennzeichen-Loadouts zurücksetzen
- Loadouts löschen und live aktualisieren

## Version

Aktuelle Version: **1.6.3**

Changelog und Downloads: [GitHub Releases](https://github.com/pfuschbyluis/AutoGlovebox/releases)

## Exports

### Server

```lua
exports['AutoGlovebox']:EquipVehicle(netId, plate, modelHash, force, vehicleClass)
exports['AutoGlovebox']:IsEquipped(plate)
exports['AutoGlovebox']:ResetEquipped(plate)
```

### Client

```lua
exports['AutoGlovebox']:OnVehicleSpawned(vehicle)
exports['AutoGlovebox']:OpenAdminPanel()
```

## Garagen-Integration

```lua
local vehicle = CreateVehicle(...)
exports['AutoGlovebox']:OnVehicleSpawned(vehicle)
```

## Lizenz

Frei verwendbar – Anpassungen für euren Server sind erwünscht.
