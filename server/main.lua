local function notify(source, message, ntype)
    TriggerClientEvent('ox_lib:notify', source, {
        title = Lockers.L('locker_title'),
        description = message,
        type = ntype or 'inform',
    })
end

local function openLockerInventory(source, locker, token)
    if Lockers.Inventory.OpenForPlayer(source, locker, token) then
        return true
    end

    notify(source, Lockers.L('session_expired'), 'error')
    return false
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
        openLockerInventory(source, locker, token)
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
        openLockerInventory(source, locker, token)
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
        openLockerInventory(source, locker, token)
        return
    end

    TriggerClientEvent('lockers:client:authResult', source, true, Lockers.L('key_used'), {
        keyVerified = true,
        needsPin = locker.access_mode == 'pin_and_key',
    })
end)

RegisterNetEvent('lockers:server:closeSession', function(token)
    Lockers.Security.DestroySession(source, token)
    Lockers.Inventory.ClearActiveOpen(source)
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
