local nuiOpen = false
local currentToken

local function setNui(state)
    nuiOpen = state
    SetNuiFocus(state, state)

    if state then
        SendNUIMessage({ action = 'show' })
    else
        SendNUIMessage({ action = 'hide' })
    end
end

local function closeNui()
    if currentToken then
        TriggerServerEvent('lockers:server:closeSession', currentToken)
        currentToken = nil
    end

    setNui(false)
end


RegisterNetEvent('lockers:client:openAuth', function(session)
    currentToken = session.token
    setNui(true)

    SendNUIMessage({
        action = 'openAuth',
        data = session,
        strings = {
            pin_title = Lockers.L('pin_title'),
            pin_confirm = Lockers.L('pin_confirm'),
            pin_clear = Lockers.L('pin_clear'),
            pin_cancel = Lockers.L('pin_cancel'),
            close = Lockers.L('close'),
            loading = Lockers.L('loading'),
        },
    })
end)

RegisterNetEvent('lockers:client:authResult', function(success, message, extra)
    SendNUIMessage({
        action = 'authResult',
        success = success,
        message = message,
        extra = extra,
    })
end)

RegisterNetEvent('lockers:client:openLocker', function(payload)
    currentToken = payload.token
    setNui(true)

    SendNUIMessage({
        action = 'openLocker',
        data = payload,
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb('ok')
end)

RegisterNUICallback('submitPin', function(data, cb)
    if not currentToken then
        cb('error')
        return
    end

    TriggerServerEvent('lockers:server:submitPin', currentToken, data.pin, data.requestId)
    cb('ok')
end)

RegisterNUICallback('useKey', function(data, cb)
    if not currentToken then
        cb('error')
        return
    end

    TriggerServerEvent('lockers:server:useKey', currentToken, data.requestId)
    cb('ok')
end)

RegisterNUICallback('takeItem', function(data, cb)
    if not currentToken then
        cb('error')
        return
    end

    TriggerServerEvent('lockers:server:takeItem', currentToken, data.itemId, data.amount, data.requestId)
    cb('ok')
end)

RegisterNUICallback('returnItem', function(data, cb)
    if not currentToken then
        cb('error')
        return
    end

    TriggerServerEvent('lockers:server:returnItem', currentToken, data.itemId, data.amount, data.requestId)
    cb('ok')
end)

CreateThread(function()
    while true do
        if nuiOpen and IsControlJustReleased(0, 322) then
            closeNui()
        end

        Wait(nuiOpen and 0 or 500)
    end
end)

local function startup()
    Lockers.Framework.Init()
    Lockers.Debug('Client gestartet')
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(500, startup)
    end
end)

exports('OpenLocker', function(lockerId, vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(vehicle))
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest = lib.getClosestVehicle(coords, Config.Security.maxDistance or 3.5, false)

    if closest and closest ~= 0 then
        TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(closest))
    end
end)

exports('CloseLocker', closeNui)
