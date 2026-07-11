Lockers = Lockers or {}
Lockers.DB = Lockers.DB or {}

local cache = {
    lockers = {},
    items = {},
    ready = false,
}

local function rowToLocker(row)
    return {
        id = row.id,
        name = row.name,
        description = row.description,
        vehicle_match_type = row.vehicle_match_type or 'model',
        vehicle_key = row.vehicle_key or '',
        target_distance = row.target_distance,
        access_mode = row.access_mode,
        pin_hash = row.pin_hash,
        key_item = row.key_item,
        key_metadata = Lockers.DecodeJSON(row.key_metadata),
        key_consume = row.key_consume == 1,
        key_job_restrict = Lockers.DecodeJSON(row.key_job_restrict),
        allowed_jobs = Lockers.DecodeJSON(row.allowed_jobs),
        minimum_grade = row.minimum_grade,
        allowed_identifiers = Lockers.DecodeJSON(row.allowed_identifiers),
        slots = row.slots,
        max_weight = row.max_weight,
        auto_restock = row.auto_restock == 1,
        restock_interval = row.restock_interval,
        enabled = row.enabled == 1,
        created_by = row.created_by,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function rowToItem(row)
    return {
        id = row.id,
        locker_id = row.locker_id,
        item_name = row.item_name,
        display_name = row.display_name,
        description = row.description,
        image = row.image,
        amount = row.amount,
        maximum_amount = row.maximum_amount,
        maximum_take_amount = row.maximum_take_amount,
        minimum_grade = row.minimum_grade,
        allowed_jobs = Lockers.DecodeJSON(row.allowed_jobs),
        metadata = Lockers.DecodeJSON(row.metadata),
        returnable = row.returnable == 1,
        unlimited = row.unlimited == 1,
        cooldown = row.cooldown,
        locker_cooldown = row.locker_cooldown,
        price = row.price,
        deposit = row.deposit,
        personal_bind = row.personal_bind == 1,
        sort_order = row.sort_order,
    }
end

function Lockers.DB.IsReady()
    return cache.ready
end

function Lockers.DB.GetLockers()
    return cache.lockers
end

function Lockers.DB.GetLocker(lockerId)
    return cache.lockers[lockerId]
end

function Lockers.DB.GetItems(lockerId)
    return cache.items[lockerId] or {}
end

function Lockers.DB.GetItem(lockerId, itemId)
    local items = cache.items[lockerId] or {}

    for i = 1, #items do
        if items[i].id == itemId then
            return items[i]
        end
    end

    return nil
end

function Lockers.DB.Reload()
    local rows = MySQL.query.await('SELECT * FROM lockers ORDER BY id ASC') or {}
    cache.lockers = {}
    cache.items = {}

    for i = 1, #rows do
        local locker = rowToLocker(rows[i])
        cache.lockers[locker.id] = locker
    end

    local itemRows = MySQL.query.await('SELECT * FROM locker_items ORDER BY sort_order ASC, id ASC') or {}

    for i = 1, #itemRows do
        local item = rowToItem(itemRows[i])
        cache.items[item.locker_id] = cache.items[item.locker_id] or {}
        cache.items[item.locker_id][#cache.items[item.locker_id] + 1] = item
    end

    cache.ready = true
    TriggerClientEvent('lockers:client:syncLockers', -1, Lockers.DB.GetClientCache())
end

function Lockers.DB.GetClientCache()
    local clientLockers = {}

    for id, locker in pairs(cache.lockers) do
        if locker.enabled then
            clientLockers[#clientLockers + 1] = {
                id = id,
                name = locker.name,
                description = locker.description,
                vehicle_match_type = locker.vehicle_match_type,
                vehicle_key = locker.vehicle_key,
                target_distance = locker.target_distance,
                access_mode = locker.access_mode,
            }
        end
    end

    return clientLockers
end

---@param pin string
---@return string
function Lockers.DB.HashPin(pin)
    local salt = Lockers.Security.RandomString(32)
    local hash = MySQL.scalar.await('SELECT SHA2(?, 512)', { salt .. pin })
    return ('%s:%s'):format(salt, hash)
end

---@param pin string
---@param stored string|nil
---@return boolean
function Lockers.DB.VerifyPin(pin, stored)
    if not stored or stored == '' then
        return false
    end

    local salt, expected = stored:match('^([^:]+):(.+)$')

    if not salt or not expected then
        return false
    end

    local hash = MySQL.scalar.await('SELECT SHA2(?, 512)', { salt .. pin })
    return hash == expected
end

function Lockers.DB.Log(lockerId, identifier, playerName, action, itemName, amount, metadata)
    MySQL.insert('INSERT INTO locker_logs (locker_id, player_identifier, player_name, action, item_name, amount, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        lockerId,
        identifier,
        playerName,
        action,
        itemName,
        amount,
        Lockers.EncodeJSON(metadata),
    })

    Lockers.Security.SendDiscordLog({
        locker_id = lockerId,
        player_identifier = identifier,
        player_name = playerName,
        action = action,
        item_name = itemName,
        amount = amount,
    })
end

function Lockers.DB.UpdateItemAmount(itemId, amount)
    MySQL.update.await('UPDATE locker_items SET amount = ? WHERE id = ?', { amount, itemId })

    for lockerId, items in pairs(cache.items) do
        for i = 1, #items do
            if items[i].id == itemId then
                items[i].amount = amount
                break
            end
        end
    end
end

function Lockers.DB.SetCooldown(lockerId, itemId, identifier, seconds)
    if seconds <= 0 then
        return
    end

    MySQL.insert.await([[
        INSERT INTO locker_cooldowns (locker_id, item_id, player_identifier, expires_at)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))
        ON DUPLICATE KEY UPDATE expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND)
    ]], { lockerId, itemId, identifier, seconds, seconds })
end

function Lockers.DB.IsOnCooldown(lockerId, itemId, identifier)
    local row = MySQL.single.await([[
        SELECT expires_at > NOW() AS active FROM locker_cooldowns
        WHERE locker_id = ? AND item_id = ? AND player_identifier = ?
    ]], { lockerId, itemId, identifier })

    return row and row.active == 1
end

local function seedExamples()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM lockers')

    if tonumber(count) > 0 or not Config.ExampleLockers then
        return
    end

    for i = 1, #Config.ExampleLockers do
        local example = Config.ExampleLockers[i]
        local pinHash = example.pin and Lockers.DB.HashPin(example.pin) or nil

        local lockerId = MySQL.insert.await([[
            INSERT INTO lockers (name, description, vehicle_match_type, vehicle_key, target_distance, access_mode, pin_hash, key_item, key_metadata, key_consume, key_job_restrict, allowed_jobs, minimum_grade, allowed_identifiers, slots, max_weight, enabled, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            example.name,
            example.description,
            example.vehicle_match_type or 'model',
            example.vehicle_key or '',
            example.target_distance or Config.Vehicle.defaultDistance or 2.5,
            example.access_mode or 'pin_or_key',
            pinHash,
            example.key_item,
            Lockers.EncodeJSON(example.key_metadata),
            example.key_consume and 1 or 0,
            Lockers.EncodeJSON(example.key_job_restrict),
            Lockers.EncodeJSON(example.allowed_jobs),
            example.minimum_grade or 0,
            Lockers.EncodeJSON(example.allowed_identifiers or {}),
            example.slots or 50,
            example.max_weight or 100000,
            example.enabled ~= false and 1 or 0,
            'system',
        })

        if example.items then
            for j = 1, #example.items do
                local item = example.items[j]

                MySQL.insert.await([[
                    INSERT INTO locker_items (locker_id, item_name, display_name, description, amount, maximum_amount, maximum_take_amount, minimum_grade, allowed_jobs, metadata, returnable, unlimited, sort_order)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]], {
                    lockerId,
                    item.item_name,
                    item.display_name,
                    item.description,
                    item.amount or 0,
                    item.maximum_amount or 0,
                    item.maximum_take_amount or 1,
                    item.minimum_grade or 0,
                    Lockers.EncodeJSON(item.allowed_jobs),
                    Lockers.EncodeJSON(item.metadata),
                    item.returnable ~= false and 1 or 0,
                    item.unlimited and 1 or 0,
                    j,
                })
            end
        end
    end

    Lockers.Debug('Beispiel-Schließfächer angelegt')
end

local function runMigrations()
    local vehicleTypeColumn = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'lockers'
          AND COLUMN_NAME = 'vehicle_match_type'
    ]])

    if not vehicleTypeColumn or tonumber(vehicleTypeColumn) == 0 then
        MySQL.query.await([[
            ALTER TABLE `lockers`
            ADD COLUMN `vehicle_match_type` ENUM('model', 'plate') NOT NULL DEFAULT 'model' AFTER `description`,
            ADD COLUMN `vehicle_key` VARCHAR(50) NOT NULL DEFAULT '' AFTER `vehicle_match_type`
        ]])
        Lockers.Debug('Migration: Fahrzeug-Felder zu lockers hinzugefügt')
    end
end

MySQL.ready(function()
    local ok, err = pcall(function()
        local sql = LoadResourceFile(GetCurrentResourceName(), 'install.sql')

        if sql then
            for statement in sql:gmatch('[^;]+;') do
                local trimmed = statement:match('^%s*(.-)%s*$')

                if trimmed and trimmed ~= '' and not trimmed:match('^%-%-') then
                    MySQL.query.await(trimmed)
                end
            end
        end

        runMigrations()
        seedExamples()
        Lockers.DB.Reload()
    end)

    if not ok then
        print(('^1[Police_Lock]^7 Datenbank-Fehler: %s'):format(err))
        return
    end

    print('^2[Police_Lock]^7 Datenbank bereit')
end)

AddEventHandler('playerJoining', function()
    local source = source

    SetTimeout(1500, function()
        if cache.ready then
            TriggerClientEvent('lockers:client:syncLockers', source, Lockers.DB.GetClientCache())
        end
    end)
end)
