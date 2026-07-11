local reportedVehicles = {}

local function debugPrint(...)
    if Config.Debug then
        print('^3[AutoGlovebox:Client]^7', ...)
    end
end

---@param vehicle number
---@return boolean
local function isConfiguredVehicle(vehicle)
    return AutoGlovebox.IsConfiguredVehicle(vehicle)
end

---@param vehicle number
---@return boolean
local function shouldIgnoreVehicle(vehicle)
    if not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return true
    end

    if not isConfiguredVehicle(vehicle) then
        return true
    end

    local playerVehicle = GetVehiclePedIsIn(cache.ped, false)

    if playerVehicle == vehicle then
        return false
    end

    if Config.IgnoreNPCVehicles then
        local populationType = GetEntityPopulationType(vehicle)

        if populationType == 5 or populationType == 7 then
            return true
        end
    end

    return false
end

---@param vehicle number
local function reportVehicleSpawn(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if reportedVehicles[netId] then
        return
    end

    reportedVehicles[netId] = true

    local plate = GetVehicleNumberPlateText(vehicle)
    local modelHash = GetEntityModel(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)

    debugPrint(('Fahrzeug gemeldet: %s (Modell: %s, netId: %s)'):format(plate, modelHash, netId))
    TriggerServerEvent('autoglovebox:server:vehicleSpawned', netId, plate, modelHash, vehicleClass)
end

---@param vehicle number
local function handleVehicleEntity(vehicle)
    if shouldIgnoreVehicle(vehicle) then
        return
    end

    local delay = Config.SpawnDelay or 500

    SetTimeout(delay, function()
        if not DoesEntityExist(vehicle) then
            return
        end

        reportVehicleSpawn(vehicle)
    end)
end

AddEventHandler('entityCreated', function(entity)
    handleVehicleEntity(entity)
end)

lib.onCache('vehicle', function(vehicle)
    if vehicle then
        reportedVehicles[NetworkGetNetworkIdFromEntity(vehicle)] = nil
        handleVehicleEntity(vehicle)
    end
end)

exports('OnVehicleSpawned', function(vehicle)
    if not vehicle or vehicle == 0 then
        return
    end

    reportedVehicles[NetworkGetNetworkIdFromEntity(vehicle)] = nil
    handleVehicleEntity(vehicle)
end)

RegisterNetEvent('autoglovebox:client:manualEquip', function(force)
    local vehicle = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, false)

    if not vehicle or vehicle == 0 then
        lib.notify({
            title = 'AutoGlovebox',
            description = 'Kein Fahrzeug in der Nähe gefunden.',
            type = 'error',
        })
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    reportedVehicles[netId] = nil

    TriggerServerEvent(
        'autoglovebox:server:forceEquip',
        netId,
        GetVehicleNumberPlateText(vehicle),
        GetEntityModel(vehicle),
        GetVehicleClass(vehicle)
    )

    if not force then
        lib.notify({
            title = 'AutoGlovebox',
            description = 'Fahrzeug-Ausrüstung wurde angefordert.',
            type = 'inform',
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    reportedVehicles = {}
end)
