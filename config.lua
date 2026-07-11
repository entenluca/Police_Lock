Config = {}

--- Debug-Ausgaben in Server- und Client-Konsole
Config.Debug = false

--- Sprache: 'de' oder 'en'
Config.Locale = 'de'

-- =============================================================================
-- FAHRZEUG
-- =============================================================================
Config.Vehicle = {
    --- Optional: Zielpunkt nur an bestimmten Bones (leer = ganzes Fahrzeug)
    targetBones = nil,
    --- Kofferraum muss offen sein zum Öffnen (false = deaktivieren)
    requireTrunkOpen = true,
    --- true = ox_target nur bei offenem Kofferraum; false = Ziel sichtbar, Kofferraum wird beim Benutzen geprüft
    requireTrunkOpenForTarget = false,
    trunkDoorIndices = { 5, 4, 6, 3, 2 },
    trunkOpenThreshold = 0.01,
    defaultDistance = 2.5,
    maxTargetDistance = 5.0,
}

-- =============================================================================
-- SICHERHEIT
-- =============================================================================
Config.Security = {
    maxDistance = 3.5,
    sessionTTL = 300,
    rateLimit = 8,
    pinMaxAttempts = 5,
    pinLockoutTime = 300,
    pinAlarm = true,
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
    --- Optional: ACE-Permission für den Befehl (zusätzlich zu Config.Admin.groups)
    permission = 'lockers.admin',
    useAcePermission = false,
    groups = { 'admin', 'superadmin' },
}

-- =============================================================================
-- UI (ox_lib)
-- =============================================================================
Config.UI = {
    confirmTakeThreshold = 10,
}

-- =============================================================================
-- BEISPIEL-SCHLIESSFÄCHER (optional, standardmäßig deaktiviert)
-- Setze Config.SeedExamples = true und trage Einträge in ExampleLockers ein.
-- =============================================================================
Config.SeedExamples = false

Config.ExampleLockers = {
    {
        name = 'Polizei-Dienstfahrzeug',
        description = 'Ausrüstungsschließfach im Streifenwagen',
        vehicle_match_type = 'model',
        vehicle_key = 'police',
        target_distance = 2.5,
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
        name = 'Einsatzfahrzeug SEK',
        description = 'Spezielles Schließfach nur per Schlüsselkarte',
        vehicle_match_type = 'model',
        vehicle_key = 'police2',
        target_distance = 2.5,
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
