Config = {}

--- Debug-Ausgaben in Server- und Client-Konsole
Config.Debug = false

--- Sprache: 'de' oder 'en'
Config.Locale = 'de'

-- =============================================================================
-- FRAMEWORK & ADAPTER
-- =============================================================================
Config.Auto = {
    Framework = true,
    Target = true,
    Inventory = true,
}

-- Manuelle Einstellung nur bei Auto = false:
-- Config.Auto.Framework = false
-- Config.Framework = 'esx' -- 'esx' | 'qb' | 'standalone'
-- Config.Auto.Target = false
-- Config.Target = 'ox_target' -- 'ox_target' | 'qb-target'
-- Config.Auto.Inventory = false
-- Config.Inventory = 'ox_inventory' -- 'ox_inventory' | 'qb-inventory'

-- =============================================================================
-- SICHERHEIT
-- =============================================================================
Config.Security = {
  --- Maximale Distanz zum Schließfach für alle Aktionen (Meter)
  maxDistance = 3.0,
  --- Session-Token Gültigkeit in Sekunden
  sessionTTL = 300,
  --- Rate-Limit: maximale Events pro Spieler pro Sekunde
  rateLimit = 8,
  --- PIN-Fehlversuche bevor Sperre
  pinMaxAttempts = 5,
  --- Sperrzeit nach zu vielen Fehlversuchen (Sekunden)
  pinLockoutTime = 300,
  --- Alarm bei PIN-Sperre (Server-Log + optional Discord)
  pinAlarm = true,
  --- Request-ID Cache für Duplikat-Schutz (Sekunden)
  requestIdTTL = 30,
}

-- =============================================================================
-- DISCORD WEBHOOK
-- =============================================================================
Config.Discord = {
  enabled = false,
  webhook = 'https://discord.com/api/webhooks/DEINE_WEBHOOK_ID/DEIN_TOKEN',
  botName = 'Schließfach-System',
  avatar = '',
  --- Welche Aktionen geloggt werden
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

-- =============================================================================
-- ADMIN
-- =============================================================================
Config.Admin = {
  enabled = true,
  command = 'lockeradmin',
  --- ACE-Permission für Admin-Dashboard
  permission = 'lockers.admin',
  --- Zusätzliche erlaubte Gruppen (Framework-abhängig)
  groups = {
    esx = { 'admin', 'superadmin' },
    qb = { 'god', 'admin' },
  },
}

-- =============================================================================
-- NUI
-- =============================================================================
Config.NUI = {
  --- Bestätigungsdialog ab dieser Menge
  confirmTakeThreshold = 10,
  --- Item-Bilder Basis-URL (ox_inventory Standard)
  imageBase = 'nui://ox_inventory/web/images/',
  --- Fallback wenn kein Bild vorhanden
  fallbackImage = 'nui://ox_inventory/web/images/placeholder.png',
}

-- =============================================================================
-- BEISPIEL: POLIZEI-SCHLIESSFACH (wird bei Erstinstallation angelegt)
-- =============================================================================
Config.ExampleLockers = {
  {
    name = 'Polizei-Waffenschrank',
    description = 'Zentraler Waffenschrank der Polizei',
    coordinates = { x = 452.3, y = -980.1, z = 30.7, h = 90.0 },
    target_distance = 2.0,
    access_mode = 'pin_or_key',
    pin = '1234',
    key_item = 'police_locker_key',
    key_metadata = { locker_id = 1, universal = false },
    key_consume = false,
    key_job_restrict = { police = 0 },
    allowed_jobs = { police = 0 },
    minimum_grade = 0,
    allowed_identifiers = {},
    slots = 50,
    max_weight = 100000,
    enabled = true,
    items = {
      {
        item_name = 'weapon_pistol',
        display_name = 'Dienstpistole',
        description = 'Standard-Dienstwaffe der Polizei',
        amount = 5,
        maximum_amount = 10,
        maximum_take_amount = 1,
        minimum_grade = 2,
        allowed_jobs = { police = 2 },
        returnable = true,
        unlimited = false,
        metadata = { registered = true },
        auto_serial = true,
      },
      {
        item_name = 'ammo-9',
        display_name = '9mm Munition',
        description = 'Munition für Dienstwaffen',
        amount = 200,
        maximum_amount = 500,
        maximum_take_amount = 50,
        minimum_grade = 1,
        allowed_jobs = { police = 1 },
        returnable = true,
        unlimited = false,
      },
      {
        item_name = 'armor',
        display_name = 'Schutzweste',
        description = 'Ballistische Schutzweste',
        amount = 10,
        maximum_amount = 20,
        maximum_take_amount = 2,
        minimum_grade = 0,
        returnable = true,
        unlimited = false,
      },
    },
  },
  {
    name = 'Beweismittel-Tresor',
    description = 'Nur mit Schlüssel-Item zugänglich',
    coordinates = { x = 461.8, y = -989.5, z = 24.9, h = 180.0 },
    target_distance = 2.0,
    access_mode = 'key_only',
    pin = nil,
    key_item = 'evidence_keycard',
    key_metadata = { locker_id = 2 },
    key_consume = false,
    allowed_jobs = { police = 3 },
    minimum_grade = 3,
    slots = 30,
    max_weight = 50000,
    enabled = true,
    items = {
      {
        item_name = 'evidence_bag',
        display_name = 'Beweismitteltüte',
        amount = 50,
        returnable = true,
        unlimited = true,
      },
    },
  },
}

-- =============================================================================
-- BEISPIEL: SCHLÜSSEL-ITEMS (Dokumentation – in ox_inventory items.lua)
-- =============================================================================
--[[
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
]]
