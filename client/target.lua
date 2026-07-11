Lockers = Lockers or {}
Lockers.Client = Lockers.Client or {}

local lockers = {}
local registeredModels = {}
local globalTargetRegistered = false

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
---@return boolean
function Lockers.Client.CanInteractWithLocker(entity)
    if not Lockers.Client.HasLocker(entity) then
        return false
    end

    return Lockers.IsTrunkOpen(entity)
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
    return {
        name = 'police_lock_locker',
        icon = 'fa-solid fa-box-open',
        label = Lockers.L('open_locker'),
        bones = Config.Vehicle.targetBones or { 'boot' },
        distance = Config.Vehicle.defaultDistance or 2.5,
        canInteract = function(entity)
            return Lockers.Client.CanInteractWithLocker(entity)
        end,
        onSelect = function(data)
            openVehicleLocker(data.entity)
        end,
    }
end

local function clearTargets()
    for hash in pairs(registeredModels) do
        exports.ox_target:removeModel(hash)
    end

    registeredModels = {}

    if globalTargetRegistered then
        exports.ox_target:removeGlobalVehicle('police_lock_locker')
        globalTargetRegistered = false
    end
end

local function registerTargets()
    if GetResourceState('ox_target') ~= 'started' then
        return
    end

    clearTargets()

    local option = buildTargetOption()
    local modelHashes = {}
    local hasPlateLocker = false

    for _, locker in pairs(lockers) do
        if locker.enabled then
            if locker.vehicle_match_type == 'model' and locker.vehicle_key and locker.vehicle_key ~= '' then
                local hash = Lockers.ResolveVehicleHash(locker.vehicle_key)

                if hash and not modelHashes[hash] then
                    modelHashes[hash] = true
                    exports.ox_target:addModel(hash, { option })
                    registeredModels[hash] = true
                    Lockers.Debug(('ox_target Modell registriert: %s (%s)'):format(locker.vehicle_key, hash))
                end
            elseif locker.vehicle_match_type == 'plate' then
                hasPlateLocker = true
            end
        end
    end

    if hasPlateLocker or not next(modelHashes) then
        exports.ox_target:addGlobalVehicle({ option })
        globalTargetRegistered = true
        Lockers.Debug('ox_target GlobalVehicle registriert')
    end
end

RegisterNetEvent('lockers:client:syncLockers', function(data)
    lockers = {}

    for i = 1, #(data or {}) do
        lockers[data[i].id] = data[i]
    end

    registerTargets()
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('lockers:server:requestSync')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'ox_target' then
        SetTimeout(1000, function()
            TriggerServerEvent('lockers:server:requestSync')
            registerTargets()
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        clearTargets()
    end
end)
