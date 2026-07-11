Lockers = Lockers or {}
Lockers.Client = Lockers.Client or {}

local lockers = {}
local targetRegistered = false

function Lockers.Client.GetLockers()
    return lockers
end

---@param entity number
---@return number|nil
function Lockers.Client.GetLockerForVehicle(entity)
    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then
        return nil
    end

    local modelHash = GetEntityModel(entity)
    local plate = GetVehicleNumberPlateText(entity)

    return Lockers.FindLockerForVehicle(lockers, modelHash, plate)
end

local function openVehicleLocker(entity)
    local lockerId = Lockers.Client.GetLockerForVehicle(entity)

    if not lockerId then
        return
    end

    TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(entity))
end

local function registerVehicleTarget()
    if targetRegistered then
        return
    end

    local label = Lockers.L('open_locker')
    local bones = Config.Vehicle.targetBones or { 'boot', 'platelight', 'bumper_r' }
    local distance = Config.Vehicle.defaultDistance or 2.5

    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicle_locker',
            icon = 'fa-solid fa-box-open',
            label = label,
            bones = bones,
            distance = distance,
            canInteract = function(entity)
                return Lockers.Client.GetLockerForVehicle(entity) ~= nil
            end,
            onSelect = function(data)
                openVehicleLocker(data.entity)
            end,
        },
    })

    targetRegistered = true
    Lockers.Debug('ox_target Fahrzeug-Schließfächer registriert')
end

RegisterNetEvent('lockers:client:syncLockers', function(data)
    lockers = {}

    for i = 1, #(data or {}) do
        local entry = data[i]
        lockers[entry.id] = entry
    end

    registerVehicleTarget()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'ox_target' then
        SetTimeout(500, registerVehicleTarget)
    end
end)
