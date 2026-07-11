local function hasAdminPermission(source)
    if source == 0 then
        return true
    end

    return IsPlayerAceAllowed(source, Config.AdminPanel.permission)
end

local function notify(source, message, type)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'AutoGlovebox',
        description = message,
        type = type or 'inform',
    })
end

lib.callback.register('autoglovebox:admin:canOpen', function(source)
    return hasAdminPermission(source)
end)

lib.callback.register('autoglovebox:admin:getLoadouts', function(source)
    if not hasAdminPermission(source) then
        return nil
    end

    return {
        loadouts = AutoGlovebox.Loadouts.GetAll(),
        defaultAddMode = Config.AddMode,
    }
end)

lib.callback.register('autoglovebox:admin:saveLoadout', function(source, data)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung' }
    end

    local loadoutId, errorMessage = AutoGlovebox.Loadouts.SaveLoadout(data)

    if not loadoutId then
        return { success = false, error = errorMessage }
    end

    return { success = true, loadoutId = loadoutId }
end)

lib.callback.register('autoglovebox:admin:deleteLoadout', function(source, loadoutId)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung' }
    end

    local success, errorMessage = AutoGlovebox.Loadouts.DeleteLoadout(loadoutId)
    return { success = success, error = errorMessage }
end)

lib.callback.register('autoglovebox:admin:addItem', function(source, data)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung' }
    end

    local itemId, errorMessage = AutoGlovebox.Loadouts.AddItem(
        data.loadout_id,
        data.item,
        data.amount,
        data.metadata
    )

    if not itemId then
        return { success = false, error = errorMessage }
    end

    return { success = true, itemId = itemId }
end)

lib.callback.register('autoglovebox:admin:removeItem', function(source, itemId)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung' }
    end

    local success, errorMessage = AutoGlovebox.Loadouts.RemoveItem(itemId)
    return { success = success, error = errorMessage }
end)

lib.callback.register('autoglovebox:admin:refresh', function(source)
    if not hasAdminPermission(source) then
        return { success = false }
    end

    AutoGlovebox.Loadouts.Refresh()
    TriggerClientEvent('autoglovebox:client:syncCache', -1, AutoGlovebox.Loadouts.GetClientCache())

    return {
        success = true,
        loadouts = AutoGlovebox.Loadouts.GetAll(),
        defaultAddMode = Config.AddMode,
    }
end)

lib.callback.register('autoglovebox:admin:resetEquipped', function(source, data)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung' }
    end

    local plate = type(data) == 'table' and data.plate or data
    local storageType = type(data) == 'table' and data.storage_type or nil

    if not plate or plate == '' then
        return { success = false, error = 'Kennzeichen fehlt' }
    end

    exports[GetCurrentResourceName()]:ResetEquipped(plate, storageType)
    return { success = true }
end)

lib.callback.register('autoglovebox:admin:fillVehicle', function(source, data)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung', type = 'error' }
    end

    if not data or type(data.netId) ~= 'number' or type(data.plate) ~= 'string' or type(data.modelHash) ~= 'number' then
        return {
            success = false,
            title = 'Fehler',
            error = 'Fahrzeugdaten unvollständig',
            type = 'error',
        }
    end

    if not data.loadoutId then
        return {
            success = false,
            title = 'Fehler',
            error = 'Kein Loadout ausgewählt',
            type = 'error',
        }
    end

    local entity = NetworkGetEntityFromNetworkId(data.netId)

    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then
        return {
            success = false,
            title = 'Fehler',
            error = 'Fahrzeug nicht gefunden',
            type = 'error',
        }
    end

    local playerPed = GetPlayerPed(source)
    local maxDistance = Config.AdminPanel.fillDistance or Config.MaxReportDistance or 50.0
    local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(entity))

    if distance > maxDistance then
        return {
            success = false,
            title = 'Zu weit entfernt',
            error = ('Fahrzeug ist %.0fm entfernt (max. %.0fm).'):format(distance, maxDistance),
            type = 'error',
        }
    end

    local success, reason = AutoGlovebox.ForceEquipVehicle(
        source,
        data.netId,
        data.plate,
        data.modelHash,
        data.vehicleClass,
        data.loadoutId
    )

    if success then
        local _, _, storageType = AutoGlovebox.Loadouts.GetLoadoutById(data.loadoutId)
        local storageLabel = AutoGlovebox.GetStorageLabel(storageType)

        return {
            success = true,
            title = 'Erfolg',
            message = ('%s von %s wurde befüllt.'):format(storageLabel, AutoGlovebox.NormalizePlate(data.plate)),
            type = 'success',
        }
    end

    return {
        success = false,
        title = 'Fehler',
        error = reason or 'Befüllung fehlgeschlagen',
        type = 'error',
    }
end)

lib.callback.register('autoglovebox:admin:copyLoadout', function(source, data)
    if not hasAdminPermission(source) then
        return { success = false, error = 'Keine Berechtigung' }
    end

    local loadoutId, errorMessage = AutoGlovebox.Loadouts.CopyLoadout(data.loadoutId, data.newSpawnName)

    if not loadoutId then
        return { success = false, error = errorMessage }
    end

    return { success = true, loadoutId = loadoutId }
end)

if Config.AdminPanel.enabled then
    lib.addCommand(Config.AdminPanel.command, {
        help = 'Öffnet das AutoGlovebox Admin-Panel',
        restricted = Config.AdminPanel.permission,
    }, function(source)
        TriggerClientEvent('autoglovebox:client:openAdmin', source)
    end)
end
