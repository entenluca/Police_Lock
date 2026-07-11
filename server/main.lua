local function notify(source, message, ntype)
    TriggerClientEvent('ox_lib:notify', source, {
        title = Lockers.L('locker_title'),
        description = message,
        type = ntype or 'inform',
    })
end

local function buildLockerPayload(source, locker, token)
    local player = Lockers.Framework.GetPlayer(source)
    local items = Lockers.DB.GetItems(locker.id)
    local payloadItems = {}

    for i = 1, #items do
        if player.grade >= items[i].minimum_grade then
            payloadItems[#payloadItems + 1] = Lockers.Inventory.BuildClientItem(source, items[i], player)
        end
    end

    return {
        token = token,
        locker = {
            id = locker.id,
            name = locker.name,
            description = locker.description,
        },
        items = payloadItems,
        locale = Config.Locale,
        strings = {
            take = Lockers.L('take'),
            return_item = Lockers.L('return_item'),
            amount = Lockers.L('amount'),
            stock = Lockers.L('stock'),
            inventory = Lockers.L('inventory'),
            weight = Lockers.L('weight'),
            close = Lockers.L('close'),
            not_allowed = Lockers.L('not_allowed'),
            unlimited = Lockers.L('unlimited'),
            confirm_take = Lockers.L('confirm_take'),
            confirm_yes = Lockers.L('confirm_yes'),
            confirm_no = Lockers.L('confirm_no'),
            loading = Lockers.L('loading'),
        },
        confirm_threshold = Config.UI.confirmTakeThreshold,
    }
end

RegisterNetEvent('lockers:server:requestOpen', function(lockerId, vehicleNetId)
    local source = source

    if not Lockers.Security.CheckRateLimit(source) then
        Lockers.Security.LogSuspicious(source, 'rate_limit', { locker_id = lockerId })
        return
    end

    if not Lockers.DB.IsReady() then
        return
    end

    if type(lockerId) ~= 'number' or type(vehicleNetId) ~= 'number' then
        Lockers.Security.LogSuspicious(source, 'invalid_open', { locker_id = lockerId })
        return
    end

    local locker = Lockers.DB.GetLocker(lockerId)

    if not locker or not locker.enabled then
        notify(source, Lockers.L('locker_disabled'), 'error')
        return
    end

    if not Lockers.Security.IsPlayerNearVehicle(source, vehicleNetId) then
        notify(source, Lockers.L('too_far'), 'error')
        return
    end

    if not Lockers.Security.VehicleMatchesLocker(source, locker, vehicleNetId) then
        Lockers.Security.LogSuspicious(source, 'vehicle_mismatch', { locker_id = lockerId })
        notify(source, Lockers.L('no_vehicle'), 'error')
        return
    end

    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not Lockers.IsTrunkOpen(entity) then
        notify(source, Lockers.L('trunk_closed'), 'error')
        return
    end

    local player = Lockers.Framework.GetPlayer(source)

    if not player or not Lockers.Security.CanAccessLocker(player, locker) then
        notify(source, Lockers.L('no_permission'), 'error')
        return
    end

    local locked, remaining = Lockers.Security.GetPinLockout(source, lockerId)

    if locked then
        notify(source, Lockers.L('pin_locked', remaining), 'error')
        return
    end

    local session = Lockers.Security.CreateSession(source, lockerId, vehicleNetId)

    if not session then
        return
    end

    if locker.access_mode == 'job_only' or locker.access_mode == 'identifier_only' then
        local token = session.token
        local authSession = Lockers.Security.GetSession(source, token)

        if authSession then
            authSession.authenticated = true
        end

        Lockers.DB.Log(lockerId, player.identifier, player.name, 'opened', nil, nil, nil)
        TriggerClientEvent('lockers:client:openLocker', source, buildLockerPayload(source, locker, token))
        return
    end

    TriggerClientEvent('lockers:client:openAuth', source, session)
end)

RegisterNetEvent('lockers:server:submitPin', function(token, pin, requestId)
    local source = source

    if not Lockers.Security.CheckRateLimit(source)
        or not Lockers.Security.CheckRequestId(source, requestId)
        or type(pin) ~= 'string'
        or #pin > 12 then
        Lockers.Security.LogSuspicious(source, 'invalid_pin_submit', { token = token })
        return
    end

    local session, locker = Lockers.Security.GetSession(source, token)

    if not session or not locker then
        TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('session_expired'))
        return
    end

    local locked, remaining = Lockers.Security.GetPinLockout(source, locker.id)

    if locked then
        TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('pin_locked', remaining))
        return
    end

    local valid = Lockers.DB.VerifyPin(pin, locker.pin_hash)
    local pinLocked, lockRemaining, attemptsLeft = Lockers.Security.RegisterPinAttempt(source, locker.id, valid)
    local player = Lockers.Framework.GetPlayer(source)

    if not valid then
        Lockers.DB.Log(locker.id, player.identifier, player.name, 'wrong_pin', nil, nil, nil)

        if pinLocked then
            TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('pin_locked', lockRemaining))
            return
        end

        TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('pin_wrong', attemptsLeft or 0), {
            retryPin = true,
        })
        return
    end

    session.pinVerified = true
    session.authenticated = Lockers.Security.IsSessionAuthenticated(source, token)

    if session.authenticated then
        Lockers.DB.Log(locker.id, player.identifier, player.name, 'opened', nil, nil, nil)
        TriggerClientEvent('lockers:client:openLocker', source, buildLockerPayload(source, locker, token))
        return
    end

    TriggerClientEvent('lockers:client:authResult', source, true, Lockers.L('key_missing'), {
        pinVerified = true,
        needsKey = locker.access_mode == 'pin_and_key',
    })
end)

RegisterNetEvent('lockers:server:useKey', function(token, requestId)
    local source = source

    if not Lockers.Security.CheckRateLimit(source)
        or not Lockers.Security.CheckRequestId(source, requestId) then
        return
    end

    local session, locker = Lockers.Security.GetSession(source, token)

    if not session or not locker then
        TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('session_expired'))
        return
    end

    local player = Lockers.Framework.GetPlayer(source)

    if locker.key_job_restrict and not Lockers.HasJobAccess(locker.key_job_restrict, player.job, player.grade) then
        TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('no_permission'))
        return
    end

    local hasKey = Lockers.Inventory.HasKey(source, locker.key_item, locker.key_metadata, locker.id)

    if not hasKey then
        TriggerClientEvent('lockers:client:authResult', source, false, Lockers.L('key_missing'), {
            fallbackPin = locker.access_mode == 'pin_or_key',
        })
        return
    end

    if locker.key_consume then
        Lockers.Inventory.RemoveItem(source, locker.key_item, 1, locker.key_metadata)
    end

    session.keyVerified = true
    session.authenticated = Lockers.Security.IsSessionAuthenticated(source, token)
    local playerData = Lockers.Framework.GetPlayer(source)
    Lockers.DB.Log(locker.id, playerData.identifier, playerData.name, 'key_used', locker.key_item, 1, nil)

    if session.authenticated then
        Lockers.DB.Log(locker.id, playerData.identifier, playerData.name, 'opened', nil, nil, nil)
        TriggerClientEvent('lockers:client:openLocker', source, buildLockerPayload(source, locker, token))
        return
    end

    TriggerClientEvent('lockers:client:authResult', source, true, Lockers.L('key_used'), {
        keyVerified = true,
        needsPin = locker.access_mode == 'pin_and_key',
    })
end)

RegisterNetEvent('lockers:server:takeItem', function(token, itemId, amount, requestId)
    local source = source

    if not Lockers.Security.CheckRateLimit(source)
        or not Lockers.Security.CheckRequestId(source, requestId)
        or type(itemId) ~= 'number'
        or type(amount) ~= 'number'
        or amount < 1
        or amount > 9999 then
        Lockers.Security.LogSuspicious(source, 'invalid_take', { item_id = itemId, amount = amount })
        return
    end

    if not Lockers.Security.IsSessionAuthenticated(source, token) then
        notify(source, Lockers.L('session_expired'), 'error')
        return
    end

    local session, locker = Lockers.Security.GetSession(source, token)

    if not session or not locker then
        notify(source, Lockers.L('session_expired'), 'error')
        return
    end

    local item = Lockers.DB.GetItem(locker.id, itemId)

    if not item then
        Lockers.Security.LogSuspicious(source, 'invalid_item', { locker_id = locker.id, item_id = itemId })
        return
    end

    local player = Lockers.Framework.GetPlayer(source)

    if player.grade < item.minimum_grade or not Lockers.HasJobAccess(item.allowed_jobs, player.job, player.grade) then
        notify(source, Lockers.L('not_allowed'), 'error')
        return
    end

    if Lockers.DB.IsOnCooldown(locker.id, item.id, player.identifier) then
        notify(source, Lockers.L('error_generic'), 'error')
        return
    end

    if amount > item.maximum_take_amount then
        notify(source, Lockers.L('error_amount'), 'error')
        return
    end

    if not item.unlimited and item.amount < amount then
        notify(source, Lockers.L('error_stock'), 'error')
        return
    end

    local metadata = item.metadata and json.decode(json.encode(item.metadata)) or {}

    if metadata.registered or item.auto_serial then
        metadata.serial = Lockers.Inventory.GenerateSerial()
    end

    if item.personal_bind then
        metadata.owner = player.citizenid
    end

    if not Lockers.Inventory.CanCarry(source, item.item_name, amount, metadata) then
        notify(source, Lockers.L('error_inventory'), 'error')
        return
    end

    if not Lockers.Inventory.AddItem(source, item.item_name, amount, metadata) then
        notify(source, Lockers.L('error_inventory'), 'error')
        return
    end

    if not item.unlimited then
        Lockers.DB.UpdateItemAmount(item.id, item.amount - amount)
    end

    if item.cooldown > 0 then
        Lockers.DB.SetCooldown(locker.id, item.id, player.identifier, item.cooldown)
    end

    Lockers.DB.Log(locker.id, player.identifier, player.name, 'item_taken', item.item_name, amount, metadata)
    notify(source, Lockers.L('success_take', amount, item.display_name or item.item_name), 'success')
    TriggerClientEvent('lockers:client:openLocker', source, buildLockerPayload(source, locker, token))
end)

RegisterNetEvent('lockers:server:returnItem', function(token, itemId, amount, requestId)
    local source = source

    if not Lockers.Security.CheckRateLimit(source)
        or not Lockers.Security.CheckRequestId(source, requestId)
        or type(itemId) ~= 'number'
        or type(amount) ~= 'number'
        or amount < 1
        or amount > 9999 then
        return
    end

    if not Lockers.Security.IsSessionAuthenticated(source, token) then
        notify(source, Lockers.L('session_expired'), 'error')
        return
    end

    local session, locker = Lockers.Security.GetSession(source, token)

    if not session or not locker then
        return
    end

    local item = Lockers.DB.GetItem(locker.id, itemId)

    if not item or not item.returnable then
        notify(source, Lockers.L('error_return'), 'error')
        return
    end

    local player = Lockers.Framework.GetPlayer(source)
    local playerCount = Lockers.Inventory.GetCount(source, item.item_name)

    if playerCount < amount then
        notify(source, Lockers.L('error_amount'), 'error')
        return
    end

    if not item.unlimited and item.maximum_amount > 0 and (item.amount + amount) > item.maximum_amount then
        notify(source, Lockers.L('error_stock'), 'error')
        return
    end

    if not Lockers.Inventory.RemoveItem(source, item.item_name, amount) then
        notify(source, Lockers.L('error_generic'), 'error')
        return
    end

    if not item.unlimited then
        Lockers.DB.UpdateItemAmount(item.id, item.amount + amount)
    end

    Lockers.DB.Log(locker.id, player.identifier, player.name, 'item_returned', item.item_name, amount, nil)
    notify(source, Lockers.L('success_return', amount, item.display_name or item.item_name), 'success')
    TriggerClientEvent('lockers:client:openLocker', source, buildLockerPayload(source, locker, token))
end)

RegisterNetEvent('lockers:server:closeSession', function(token)
    Lockers.Security.DestroySession(source, token)
end)

local function startup()
    Lockers.Framework.Init()
    Lockers.Inventory.Init()
    print('^2[Police_Lock]^7 Server gestartet | ESX + ox_inventory + ox_target')
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(500, startup)
        return
    end

    if Lockers.Framework.IsDependencyResource(resourceName) then
        SetTimeout(500, startup)
    end
end)

exports('GetLocker', function(lockerId)
    return Lockers.DB.GetLocker(lockerId)
end)

exports('ReloadLockers', function()
    Lockers.DB.Reload()
end)

RegisterNetEvent('lockers:server:requestSync', function()
    local source = source

    local function sendSync()
        TriggerClientEvent('lockers:client:syncLockers', source, Lockers.DB.GetClientCache())
    end

    if Lockers.DB.IsReady() then
        sendSync()
        return
    end

    CreateThread(function()
        local attempts = 0

        while not Lockers.DB.IsReady() and attempts < 40 do
            Wait(500)
            attempts += 1
        end

        if Lockers.DB.IsReady() then
            sendSync()
        end
    end)
end)
