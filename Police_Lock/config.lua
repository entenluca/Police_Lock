Config = {}

--- Debug-Ausgaben in der Server-Konsole aktivieren
Config.Debug = false

-- =============================================================================
-- AUTO-MODUS
-- =============================================================================
Config.Auto = {
    Framework = true,
    Inventory = true,
}

-- Manuelle Einstellung nur bei Auto = false:
-- Config.Auto.Framework = false
-- Config.Framework = 'qb'
-- Config.Auto.Inventory = false
-- Config.Inventory = 'ox_inventory'

--- Standard-Verhalten für alle Fahrzeug-Loadouts
--- 'once'   = Items werden nur einmal pro Kennzeichen hinzugefügt
--- 'always' = Items werden bei jedem Spawn erneut hinzugefügt
Config.AddMode = 'once'

--- Ambiente-/NPC-Fahrzeuge ignorieren (empfohlen: true)
Config.IgnoreNPCVehicles = true

--- Verzögerung in ms nach Entity-Erstellung, bevor Kennzeichen/Modell gelesen werden
Config.SpawnDelay = 1000

--- Anzahl Versuche, Items ins Handschuhfach zu legen
Config.EquipRetries = 4

--- Wartezeit zwischen Versuchen in ms
Config.EquipRetryDelay = 750

--- Maximale Distanz zum Fahrzeug, damit ein Client den Spawn melden darf (Anti-Cheat)
Config.MaxReportDistance = 50.0

-- =============================================================================
-- ADMIN-PANEL
-- =============================================================================
-- Fahrzeug-Loadouts werden in der Datenbank verwaltet.
-- Im Spiel mit /gloveboxadmin öffnen (ACE-Berechtigung erforderlich).
Config.AdminPanel = {
    enabled = true,
    command = 'gloveboxadmin',
    permission = 'autoglovebox.admin',
    --- Maximale Distanz in Metern für „Fahrzeug jetzt befüllen“
    fillDistance = 50.0,
}

--- Ingame-Befehle
Config.IngameConfig = {
    enabled = true,
    equipPermission = 'autoglovebox.equip',
}
