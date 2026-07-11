Lockers = Lockers or {}
Lockers.Client = Lockers.Client or {}

local lockers = {}
local globalTargetRegistered = false
local hasReceivedSync = false

function Lockers.Client.GetLockers()
    return lockers
end

---@param entity number
---@return number|nil
function Lockers.Client.GetLockerForVehicle(entity)
    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then
        return nil
    end

    return Lockers.FindLockerForVehicle(lockers, GetEntityModel(entity), GetVehicleNumberPlateText(entity))
end

---@param entity number
---@return boolean
function Lockers.Client.HasLocker(entity)
    return Lockers.Client.GetLockerForVehicle(entity) ~= nil
end

---@param entity number
---@param distance number|nil
---@return boolean
function Lockers.Client.CanInteractWithLocker(entity, distance)
    if not Lockers.Client.HasLocker(entity) then
        return false
    end

    local lockerId = Lockers.Client.GetLockerForVehicle(entity)
    local locker = lockerId and lockers[lockerId]
    local maxDistance = (locker and locker.target_distance) or Config.Vehicle.defaultDistance or 2.5

    if distance and distance > maxDistance then
        return false
    end

    if Config.Vehicle.requireTrunkOpenForTarget then
        return Lockers.IsTrunkOpen(entity)
    end

    return true
end

local function openVehicleLocker(entity)
    local lockerId = Lockers.Client.GetLockerForVehicle(entity)

    if not lockerId then
        lib.notify({ title = Lockers.L('locker_title'), description = Lockers.L('no_vehicle'), type = 'error' })
        return
    end

    if not Lockers.IsTrunkOpen(entity) then
        lib.notify({ title = Lockers.L('locker_title'), description = Lockers.L('trunk_closed'), type = 'error' })
        return
    end

    TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(entity))
end

local function buildTargetOption()
    local option = {
        name = 'police_lock_locker',
        icon = 'fa-solid fa-box-open',
        label = Lockers.L('open_locker'),
        distance = Config.Vehicle.maxTargetDistance or 5.0,
        canInteract = function(entity, distance)
            return Lockers.Client.CanInteractWithLocker(entity, distance)
        end,
        onSelect = function(data)
            openVehicleLocker(data.entity)
        end,
    }

    local bones = Config.Vehicle.targetBones

    if type(bones) == 'table' and #bones > 0 then
        option.bones = bones
    elseif type(bones) == 'string' and bones ~= '' then
        option.bones = { bones }
    end

    return option
end

local function clearTargets()
    if globalTargetRegistered and GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeGlobalVehicle('police_lock_locker')
        globalTargetRegistered = false
    end
end

local function registerTargets()
    if GetResourceState('ox_target') ~= 'started' then
        Lockers.Debug('ox_target noch nicht gestartet')
        return
    end

    clearTargets()
    exports.ox_target:addGlobalVehicle({ buildTargetOption() })
    globalTargetRegistered = true

    local count = 0

    for _ in pairs(lockers) do
        count = count + 1
    end

    Lockers.Debug(('ox_target registriert (%s Schließfächer)'):format(count))
end

local function applyLockerSync(data)
    lockers = {}

    for i = 1, #(data or {}) do
        lockers[data[i].id] = data[i]
    end

    hasReceivedSync = true
    registerTargets()
end

RegisterNetEvent('lockers:client:syncLockers', function(data)
    applyLockerSync(data)
end)

local function requestLockerSync()
    TriggerServerEvent('lockers:server:requestSync')
end

CreateThread(function()
    local delays = { 500, 1500, 3000, 6000, 10000 }

    for i = 1, #delays do
        Wait(delays[i])

        if GetResourceState('ox_target') == 'started' then
            registerTargets()
        end

        if not hasReceivedSync then
            requestLockerSync()
        else
            break
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'ox_target' then
        SetTimeout(500, function()
            requestLockerSync()
            registerTargets()
        end)
    end
end)

RegisterNetEvent('esx:playerLoaded', function()
    SetTimeout(1000, requestLockerSync)
end)

RegisterNetEvent('esx:onPlayerSpawn', function()
    SetTimeout(1000, requestLockerSync)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        clearTargets()
    end
end)

if Config.Debug then
    RegisterCommand('lockertarget', function()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local vehicle = lib.getClosestVehicle(coords, 8.0, false)
        local count = 0

        for _ in pairs(lockers) do
            count = count + 1
        end

        print('^3[Police_Lock]^7 Sync:', hasReceivedSync, '| Schließfächer:', count, '| ox_target:', GetResourceState('ox_target'))

        if not vehicle or vehicle == 0 then
            print('^3[Police_Lock]^7 Kein Fahrzeug in der Nähe')
            return
        end

        local model = GetEntityModel(vehicle)
        local plate = GetVehicleNumberPlateText(vehicle)
        local lockerId = Lockers.Client.GetLockerForVehicle(vehicle)

        print(('^3[Police_Lock]^7 Fahrzeug hash=%s plate=%s locker=%s trunk=%s canInteract=%s'):format(
            model,
            plate,
            lockerId or 'keins',
            Lockers.IsTrunkOpen(vehicle),
            Lockers.Client.CanInteractWithLocker(vehicle, 2.0)
        ))

        for id, locker in pairs(lockers) do
            print(('  #%s %s | %s=%s'):format(
                id,
                locker.name,
                locker.vehicle_match_type,
                locker.vehicle_key or '-'
            ))
        end
    end, false)
end
