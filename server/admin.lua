local function notify(source, message, ntype)
    TriggerClientEvent('ox_lib:notify', source, {
        title = Lockers.L('admin_title'),
        description = message,
        type = ntype or 'inform',
    })
end

local function sanitizeLockerData(data)
    if type(data) ~= 'table' then
        return nil
    end

    local accessMode = data.access_mode or 'pin_or_key'

    if not Lockers.IsValidAccessMode(accessMode) then
        accessMode = 'pin_or_key'
    end

    return {
        id = data.id,
        name = tostring(data.name or ''):sub(1, 100),
        description = tostring(data.description or ''):sub(1, 2000),
        vehicle_match_type = Lockers.IsValidVehicleMatchType(data.vehicle_match_type) and data.vehicle_match_type or 'model',
        vehicle_key = tostring(data.vehicle_key or ''):sub(1, 50),
        target_distance = math.min(math.max(tonumber(data.target_distance) or Config.Vehicle.defaultDistance or 2.5, 0.5), 10.0),
        access_mode = accessMode,
        pin = data.pin,
        key_item = data.key_item ~= '' and data.key_item or nil,
        key_metadata = Lockers.DecodeJSON(data.key_metadata),
        key_consume = data.key_consume == true,
        key_job_restrict = Lockers.DecodeJSON(data.key_job_restrict),
        allowed_jobs = Lockers.DecodeJSON(data.allowed_jobs),
        minimum_grade = math.max(tonumber(data.minimum_grade) or 0, 0),
        allowed_identifiers = type(data.allowed_identifiers) == 'table' and data.allowed_identifiers or {},
        slots = math.min(math.max(tonumber(data.slots) or 50, 1), 500),
        max_weight = math.min(math.max(tonumber(data.max_weight) or 100000, 1000), 10000000),
        auto_restock = data.auto_restock == true,
        restock_interval = math.max(tonumber(data.restock_interval) or 3600, 60),
        enabled = data.enabled ~= false,
    }
end

local function sanitizeItemData(data, lockerId)
    if type(data) ~= 'table' or not data.item_name or data.item_name == '' then
        return nil
    end

    return {
        id = data.id,
        locker_id = lockerId,
        item_name = tostring(data.item_name):sub(1, 64),
        display_name = data.display_name and tostring(data.display_name):sub(1, 100) or nil,
        description = data.description and tostring(data.description):sub(1, 2000) or nil,
        image = data.image and tostring(data.image):sub(1, 255) or nil,
        amount = math.max(tonumber(data.amount) or 0, 0),
        maximum_amount = math.max(tonumber(data.maximum_amount) or 0, 0),
        maximum_take_amount = math.min(math.max(tonumber(data.maximum_take_amount) or 1, 1), 9999),
        minimum_grade = math.max(tonumber(data.minimum_grade) or 0, 0),
        allowed_jobs = Lockers.DecodeJSON(data.allowed_jobs),
        metadata = Lockers.DecodeJSON(data.metadata),
        returnable = data.returnable ~= false,
        unlimited = data.unlimited == true,
        cooldown = math.max(tonumber(data.cooldown) or 0, 0),
        locker_cooldown = math.max(tonumber(data.locker_cooldown) or 0, 0),
        price = math.max(tonumber(data.price) or 0, 0),
        deposit = math.max(tonumber(data.deposit) or 0, 0),
        personal_bind = data.personal_bind == true,
        sort_order = tonumber(data.sort_order) or 0,
    }
end

local function buildAdminPayload(source)
    local lockers = {}
    local all = Lockers.DB.GetLockers()

    for id, locker in pairs(all) do
        local items = Lockers.DB.GetItems(id)
        local safeLocker = {}

        for key, value in pairs(locker) do
            if key ~= 'pin_hash' then
                safeLocker[key] = value
            end
        end

        safeLocker.has_pin = locker.pin_hash ~= nil and locker.pin_hash ~= ''
        lockers[#lockers + 1] = {
            locker = safeLocker,
            items = items,
        }
    end

    table.sort(lockers, function(a, b)
        return a.locker.id < b.locker.id
    end)

    return {
        lockers = lockers,
        access_modes = Lockers.GetAccessModes(),
        vehicle_match_types = Lockers.GetVehicleMatchTypes(),
        locale = Config.Locale,
    }
end

RegisterNetEvent('lockers:server:adminOpenRequest', function()
    local source = source

    if not Config.Admin.enabled then
        return
    end

    Lockers.Framework.Init()

    if not Lockers.Framework.IsAdmin(source) then
        notify(source, Lockers.L('admin_no_permission'), 'error')
        return
    end

    if not Lockers.DB.IsReady() then
        notify(source, Lockers.L('admin_loading'), 'error')
        return
    end

    TriggerClientEvent('lockers:client:openAdmin', source, buildAdminPayload(source))
end)

RegisterNetEvent('lockers:server:adminSaveLocker', function(data)
    local source = source

    if not Lockers.Framework.IsAdmin(source) then
        return
    end

    local locker = sanitizeLockerData(data)

    if not locker then
        return
    end

    if locker.name == '' or not locker.name:match('%S') then
        notify(source, Lockers.L('admin_name_required'), 'error')
        return
    end

    if locker.enabled and (locker.vehicle_key == '' or not locker.vehicle_key:match('%S')) then
        notify(source, Lockers.L('admin_vehicle_key_required'), 'error')
        return
    end

    local player = Lockers.Framework.GetPlayer(source)
    local pinHash

    if locker.pin and locker.pin ~= '' then
        pinHash = Lockers.DB.HashPin(locker.pin)
    elseif data.keep_pin then
        local existing = locker.id and Lockers.DB.GetLocker(locker.id)
        pinHash = existing and existing.pin_hash or nil
    end

    local isNew = not locker.id

    if locker.id then
        MySQL.update.await([[
            UPDATE lockers SET name = ?, description = ?, vehicle_match_type = ?, vehicle_key = ?, target_distance = ?, access_mode = ?,
            pin_hash = ?, key_item = ?, key_metadata = ?, key_consume = ?, key_job_restrict = ?, allowed_jobs = ?,
            minimum_grade = ?, allowed_identifiers = ?, slots = ?, max_weight = ?, auto_restock = ?,
            restock_interval = ?, enabled = ? WHERE id = ?
        ]], {
            locker.name,
            locker.description,
            locker.vehicle_match_type,
            locker.vehicle_key,
            locker.target_distance,
            locker.access_mode,
            pinHash,
            locker.key_item,
            Lockers.EncodeJSON(locker.key_metadata),
            locker.key_consume and 1 or 0,
            Lockers.EncodeJSON(locker.key_job_restrict),
            Lockers.EncodeJSON(locker.allowed_jobs),
            locker.minimum_grade,
            Lockers.EncodeJSON(locker.allowed_identifiers),
            locker.slots,
            locker.max_weight,
            locker.auto_restock and 1 or 0,
            locker.restock_interval,
            locker.enabled and 1 or 0,
            locker.id,
        })

        Lockers.DB.Log(locker.id, player.identifier, player.name, 'admin_change', 'locker_update', nil, nil)
    else
        locker.id = MySQL.insert.await([[
            INSERT INTO lockers (name, description, vehicle_match_type, vehicle_key, target_distance, access_mode, pin_hash, key_item, key_metadata, key_consume, key_job_restrict, allowed_jobs, minimum_grade, allowed_identifiers, slots, max_weight, auto_restock, restock_interval, enabled, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            locker.name,
            locker.description,
            locker.vehicle_match_type,
            locker.vehicle_key,
            locker.target_distance,
            locker.access_mode,
            pinHash,
            locker.key_item,
            Lockers.EncodeJSON(locker.key_metadata),
            locker.key_consume and 1 or 0,
            Lockers.EncodeJSON(locker.key_job_restrict),
            Lockers.EncodeJSON(locker.allowed_jobs),
            locker.minimum_grade,
            Lockers.EncodeJSON(locker.allowed_identifiers),
            locker.slots,
            locker.max_weight,
            locker.auto_restock and 1 or 0,
            locker.restock_interval,
            locker.enabled and 1 or 0,
            player.identifier,
        })
    end

    Lockers.DB.Reload()
    notify(source, Lockers.L('admin_saved'), 'success')

    local payload = buildAdminPayload(source)

    if isNew and locker.id then
        payload.selected_locker_id = locker.id
    end

    TriggerClientEvent('lockers:client:openAdmin', source, payload)
end)

RegisterNetEvent('lockers:server:adminDeleteLocker', function(lockerId)
    local source = source

    if not Lockers.Framework.IsAdmin(source) or type(lockerId) ~= 'number' then
        return
    end

    local player = Lockers.Framework.GetPlayer(source)
    local locker = Lockers.DB.GetLocker(lockerId)

    if not locker then
        return
    end

    Lockers.DB.Log(lockerId, player.identifier, player.name, 'admin_change', 'locker_delete', nil, {
        locker_id = lockerId,
        locker_name = locker.name,
        vehicle_match_type = locker.vehicle_match_type,
        vehicle_key = locker.vehicle_key,
    })
    MySQL.update.await('DELETE FROM lockers WHERE id = ?', { lockerId })
    Lockers.DB.Reload()
    notify(source, Lockers.L('admin_deleted'), 'success')
    TriggerClientEvent('lockers:client:openAdmin', source, buildAdminPayload(source))
end)

RegisterNetEvent('lockers:server:adminDuplicateLocker', function(lockerId)
    local source = source

    if not Lockers.Framework.IsAdmin(source) or type(lockerId) ~= 'number' then
        return
    end

    local locker = Lockers.DB.GetLocker(lockerId)

    if not locker then
        return
    end

    local player = Lockers.Framework.GetPlayer(source)
    local newId = MySQL.insert.await([[
        INSERT INTO lockers (name, description, vehicle_match_type, vehicle_key, target_distance, access_mode, pin_hash, key_item, key_metadata, key_consume, key_job_restrict, allowed_jobs, minimum_grade, allowed_identifiers, slots, max_weight, auto_restock, restock_interval, enabled, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        locker.name .. ' (Kopie)',
        locker.description,
        locker.vehicle_match_type,
        locker.vehicle_key,
        locker.target_distance,
        locker.access_mode,
        locker.pin_hash,
        locker.key_item,
        Lockers.EncodeJSON(locker.key_metadata),
        locker.key_consume and 1 or 0,
        Lockers.EncodeJSON(locker.key_job_restrict),
        Lockers.EncodeJSON(locker.allowed_jobs),
        locker.minimum_grade,
        Lockers.EncodeJSON(locker.allowed_identifiers),
        locker.slots,
        locker.max_weight,
        locker.auto_restock and 1 or 0,
        locker.restock_interval,
        locker.enabled and 1 or 0,
        player.identifier,
    })

    local items = Lockers.DB.GetItems(lockerId)

    for i = 1, #items do
        local item = items[i]

        MySQL.insert.await([[
            INSERT INTO locker_items (locker_id, item_name, display_name, description, image, amount, maximum_amount, maximum_take_amount, minimum_grade, allowed_jobs, metadata, returnable, unlimited, cooldown, locker_cooldown, price, deposit, personal_bind, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            newId,
            item.item_name,
            item.display_name,
            item.description,
            item.image,
            item.amount,
            item.maximum_amount,
            item.maximum_take_amount,
            item.minimum_grade,
            Lockers.EncodeJSON(item.allowed_jobs),
            Lockers.EncodeJSON(item.metadata),
            item.returnable and 1 or 0,
            item.unlimited and 1 or 0,
            item.cooldown,
            item.locker_cooldown,
            item.price,
            item.deposit,
            item.personal_bind and 1 or 0,
            item.sort_order,
        })
    end

    Lockers.DB.Reload()
    TriggerClientEvent('lockers:client:openAdmin', source, buildAdminPayload(source))
end)

RegisterNetEvent('lockers:server:adminSaveItem', function(lockerId, data)
    local source = source

    if not Lockers.Framework.IsAdmin(source) or type(lockerId) ~= 'number' then
        return
    end

    local item = sanitizeItemData(data, lockerId)

    if not item then
        return
    end

    local player = Lockers.Framework.GetPlayer(source)

    if item.id then
        MySQL.update.await([[
            UPDATE locker_items SET item_name = ?, display_name = ?, description = ?, image = ?, amount = ?,
            maximum_amount = ?, maximum_take_amount = ?, minimum_grade = ?, allowed_jobs = ?, metadata = ?,
            returnable = ?, unlimited = ?, cooldown = ?, locker_cooldown = ?, price = ?, deposit = ?,
            personal_bind = ?, sort_order = ? WHERE id = ? AND locker_id = ?
        ]], {
            item.item_name,
            item.display_name,
            item.description,
            item.image,
            item.amount,
            item.maximum_amount,
            item.maximum_take_amount,
            item.minimum_grade,
            Lockers.EncodeJSON(item.allowed_jobs),
            Lockers.EncodeJSON(item.metadata),
            item.returnable and 1 or 0,
            item.unlimited and 1 or 0,
            item.cooldown,
            item.locker_cooldown,
            item.price,
            item.deposit,
            item.personal_bind and 1 or 0,
            item.sort_order,
            item.id,
            lockerId,
        })
    else
        MySQL.insert.await([[
            INSERT INTO locker_items (locker_id, item_name, display_name, description, image, amount, maximum_amount, maximum_take_amount, minimum_grade, allowed_jobs, metadata, returnable, unlimited, cooldown, locker_cooldown, price, deposit, personal_bind, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            lockerId,
            item.item_name,
            item.display_name,
            item.description,
            item.image,
            item.amount,
            item.maximum_amount,
            item.maximum_take_amount,
            item.minimum_grade,
            Lockers.EncodeJSON(item.allowed_jobs),
            Lockers.EncodeJSON(item.metadata),
            item.returnable and 1 or 0,
            item.unlimited and 1 or 0,
            item.cooldown,
            item.locker_cooldown,
            item.price,
            item.deposit,
            item.personal_bind and 1 or 0,
            item.sort_order,
        })
    end

    Lockers.DB.Log(lockerId, player.identifier, player.name, 'admin_change', item.item_name, item.amount, nil)
    Lockers.DB.Reload()
    TriggerClientEvent('lockers:client:openAdmin', source, buildAdminPayload(source))
end)

RegisterNetEvent('lockers:server:adminDeleteItem', function(lockerId, itemId)
    local source = source

    if not Lockers.Framework.IsAdmin(source) then
        return
    end

    MySQL.update.await('DELETE FROM locker_items WHERE id = ? AND locker_id = ?', { itemId, lockerId })
    Lockers.DB.Reload()
    TriggerClientEvent('lockers:client:openAdmin', source, buildAdminPayload(source))
end)

RegisterNetEvent('lockers:server:adminGetLogs', function(lockerId)
    local source = source

    if not Lockers.Framework.IsAdmin(source) then
        return
    end

    local logs = MySQL.query.await(
        'SELECT * FROM locker_logs WHERE locker_id = ? ORDER BY id DESC LIMIT 100',
        { lockerId }
    ) or {}

    TriggerClientEvent('lockers:client:adminLogs', source, logs)
end)

RegisterNetEvent('lockers:server:adminGetVehicle', function()
    local source = source

    if not Lockers.Framework.IsAdmin(source) then
        return
    end

    TriggerClientEvent('lockers:client:adminVehicle', source)
end)

if Config.Admin.enabled then
    lib.addCommand(Config.Admin.command, {
        help = 'Schließfach Admin-Dashboard öffnen',
    }, function(source)
        if source > 0 then
            TriggerClientEvent('lockers:client:openAdminRequest', source)
        end
    end)
end
