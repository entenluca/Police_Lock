RegisterNetEvent('lockers:client:requestAdmin', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)

RegisterNetEvent('lockers:client:openAdmin', function(payload)
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openAdmin',
        data = payload,
        strings = {
            admin_title = Lockers.L('admin_title'),
            admin_new = Lockers.L('admin_new'),
            admin_save = Lockers.L('admin_save'),
            admin_delete = Lockers.L('admin_delete'),
            admin_duplicate = Lockers.L('admin_duplicate'),
            admin_teleport = Lockers.L('admin_teleport'),
            admin_set_position = Lockers.L('admin_set_position'),
            admin_logs = Lockers.L('admin_logs'),
            admin_items = Lockers.L('admin_items'),
            admin_add_item = Lockers.L('admin_add_item'),
            close = Lockers.L('close'),
        },
    })
end)

RegisterNetEvent('lockers:client:adminLogs', function(logs)
    SendNUIMessage({
        action = 'adminLogs',
        data = logs,
    })
end)

RegisterNetEvent('lockers:client:adminPosition', function(coords)
    SendNUIMessage({
        action = 'adminPosition',
        data = coords,
    })
end)

RegisterNUICallback('adminClose', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    cb('ok')
end)

RegisterNUICallback('adminSaveLocker', function(data, cb)
    TriggerServerEvent('lockers:server:adminSaveLocker', data)
    cb('ok')
end)

RegisterNUICallback('adminDeleteLocker', function(data, cb)
    TriggerServerEvent('lockers:server:adminDeleteLocker', data.lockerId)
    cb('ok')
end)

RegisterNUICallback('adminDuplicateLocker', function(data, cb)
    TriggerServerEvent('lockers:server:adminDuplicateLocker', data.lockerId)
    cb('ok')
end)

RegisterNUICallback('adminSaveItem', function(data, cb)
    TriggerServerEvent('lockers:server:adminSaveItem', data.lockerId, data.item)
    cb('ok')
end)

RegisterNUICallback('adminDeleteItem', function(data, cb)
    TriggerServerEvent('lockers:server:adminDeleteItem', data.lockerId, data.itemId)
    cb('ok')
end)

RegisterNUICallback('adminGetLogs', function(data, cb)
    TriggerServerEvent('lockers:server:adminGetLogs', data.lockerId)
    cb('ok')
end)

RegisterNUICallback('adminGetPosition', function(_, cb)
    TriggerServerEvent('lockers:server:adminGetPosition')
    cb('ok')
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    local coords = data.coords

    if coords and coords.x then
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)

        if coords.h then
            SetEntityHeading(PlayerPedId(), coords.h)
        end
    end

    cb('ok')
end)

exports('OpenAdminPanel', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)
