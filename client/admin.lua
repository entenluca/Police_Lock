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
            admin_set_vehicle = Lockers.L('admin_set_vehicle'),
            admin_vehicle_match = Lockers.L('admin_vehicle_match'),
            admin_vehicle_key = Lockers.L('admin_vehicle_key'),
            admin_logs = Lockers.L('admin_logs'),
            admin_items = Lockers.L('admin_items'),
            admin_add_item = Lockers.L('admin_add_item'),
            admin_access_mode = Lockers.L('admin_access_mode'),
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

RegisterNUICallback('adminGetVehicle', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, 6.0, false)

    if not vehicle or vehicle == 0 then
        lib.notify({
            title = Lockers.L('admin_title'),
            description = Lockers.L('no_vehicle'),
            type = 'error',
        })
        cb('error')
        return
    end

    local modelHash = GetEntityModel(vehicle)
    local modelName = Lockers.GetModelName(modelHash)
    local plate = GetVehicleNumberPlateText(vehicle)

    SendNUIMessage({
        action = 'adminVehicle',
        data = {
            vehicle_match_type = 'model',
            vehicle_key = modelName,
            plate = Lockers.NormalizePlate(plate),
            model_label = modelName,
        },
    })

    cb('ok')
end)

exports('OpenAdminPanel', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)
