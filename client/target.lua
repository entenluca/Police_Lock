Lockers = Lockers or {}
Lockers.Client = Lockers.Client or {}

local lockers = {}
local targetRegistered = false

function Lockers.Client.GetLockers()
    return lockers
end

---@param entity number
---@return boolean
function Lockers.Client.CanInteractWithLocker(entity)
    if not Lockers.Client.GetLockerForVehicle(entity) then
        return false
    end

    return Lockers.IsTrunkOpen(entity)
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
    if not Lockers.Client.CanInteractWithLocker(entity) then
        return
    end

    local lockerId = Lockers.Client.GetLockerForVehicle(entity)
    TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(entity))
end

local function registerVehicleTarget()
    if targetRegistered then
        return
    end

    local label = Lockers.L('open_locker')
    local bones = Config.Vehicle.targetBones or { 'boot' }
    local distance = Config.Vehicle.defaultDistance or 2.5

    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicle_locker',
            icon = 'fa-solid fa-box-open',
            label = label,
            bones = bones,
            distance = distance,
            canInteract = function(entity)
                return Lockers.Client.CanInteractWithLocker(entity)
            end,
            onSelect = function(data)
                openVehicleLocker(data.entity)
            end,
        },
    })

    targetRegistered = true
    Lockers.Debug('ox_target Kofferraum-Schließfächer registriert (nur bei offenem Kofferraum)')
end

RegisterNetEvent('lockers:client:syncLockers', function(data)
    lockers = {}

    for i = 1, #(data or {}) do
        lockers[data[i].id] = data[i]
    end

    registerVehicleTarget()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'ox_target' then
        SetTimeout(500, registerVehicleTarget)
    end
end)
