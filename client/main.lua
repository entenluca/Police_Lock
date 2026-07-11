local currentToken

local function makeRequestId()
    return ('%s-%s'):format(GetGameTimer(), math.random(100000, 999999))
end

local function closeSession()
    if currentToken then
        TriggerServerEvent('lockers:server:closeSession', currentToken)
        currentToken = nil
    end
end

local function promptPinDialog()
    if not currentToken then
        return
    end

    local input = lib.inputDialog(Lockers.L('pin_title'), {
        {
            type = 'input',
            label = Lockers.L('pin_placeholder'),
            password = true,
            required = true,
        },
    })

    if input and input[1] and input[1] ~= '' then
        TriggerServerEvent('lockers:server:submitPin', currentToken, input[1], makeRequestId())
        return
    end

    closeSession()
end

local function startAuthFlow(session)
    currentToken = session.token
    local mode = session.access_mode

    if mode == 'pin_only' or mode == 'pin_and_key' then
        promptPinDialog()
        return
    end

    if mode == 'key_only' then
        TriggerServerEvent('lockers:server:useKey', currentToken, makeRequestId())
        return
    end

    if mode == 'pin_or_key' then
        TriggerServerEvent('lockers:server:useKey', currentToken, makeRequestId())
        return
    end

    promptPinDialog()
end

RegisterNetEvent('lockers:client:openAuth', function(session)
    startAuthFlow(session)
end)

RegisterNetEvent('lockers:client:authResult', function(success, message, extra)
    extra = extra or {}

    if success and extra.needsKey and currentToken then
        TriggerServerEvent('lockers:server:useKey', currentToken, makeRequestId())
        return
    end

    if success and extra.needsPin then
        promptPinDialog()
        return
    end

    if not success and extra.fallbackPin then
        promptPinDialog()
        return
    end

    if not success and extra.retryPin then
        lib.notify({ title = Lockers.L('locker_title'), description = message or Lockers.L('error_generic'), type = 'error' })
        promptPinDialog()
        return
    end

    if success then
        if not extra.needsKey and not extra.needsPin and not extra.pinVerified and not extra.keyVerified then
            lib.notify({ title = Lockers.L('locker_title'), description = message or 'OK', type = 'success' })
        end
        return
    end

    lib.notify({ title = Lockers.L('locker_title'), description = message or Lockers.L('error_generic'), type = 'error' })
    closeSession()
end)

exports('OpenLocker', function(lockerId, vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(vehicle))
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local closest = lib.getClosestVehicle(coords, Config.Security.maxDistance or 3.5, false)

    if closest and closest ~= 0 then
        TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(closest))
    end
end)

exports('CloseLocker', closeSession)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        closeSession()
    end
end)
