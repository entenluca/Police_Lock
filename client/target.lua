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

    local netId = NetworkGetNetworkIdFromEntity(entity)
    TriggerServerEvent('lockers:server:requestOpen', lockerId, netId)
end

local function registerVehicleTarget()
    if targetRegistered then
        return
    end

    local system = Lockers.Framework.DetectTarget()
    local label = Lockers.L('open_locker')
    local bones = Config.Vehicle and Config.Vehicle.targetBones or { 'boot', 'platelight' }
    local distance = Config.Vehicle and Config.Vehicle.defaultDistance or 2.5

    if system == 'ox_target' then
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
        return
    end

    if system == 'qb-target' then
        exports['qb-target']:AddGlobalVehicle({
            options = {
                {
                    type = 'client',
                    event = 'lockers:client:openVehicleLocker',
                    icon = 'fas fa-box-open',
                    label = label,
                    canInteract = function(entity)
                        return Lockers.Client.GetLockerForVehicle(entity) ~= nil
                    end,
                },
            },
            distance = distance,
        })

        targetRegistered = true
        Lockers.Debug('qb-target Fahrzeug-Schließfächer registriert')
        return
    end

    Lockers.Debug('Kein Target-System – Fahrzeug-Fallback aktiv')
end

RegisterNetEvent('lockers:client:openVehicleLocker', function(data)
    local entity = data and data.entity

    if entity then
        openVehicleLocker(entity)
    end
end)

RegisterNetEvent('lockers:client:syncLockers', function(data)
    lockers = {}

    for i = 1, #(data or {}) do
        local entry = data[i]
        lockers[entry.id] = entry
    end

    registerVehicleTarget()
end)

-- Fallback ohne Target: E-Taste am Fahrzeugheck
CreateThread(function()
    local showing = false

    while not targetRegistered do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local vehicle = lib.getClosestVehicle(playerCoords, Config.Security.maxDistance or 3.5, false)

        if vehicle and vehicle ~= 0 then
            local lockerId = Lockers.Client.GetLockerForVehicle(vehicle)

            if lockerId then
                sleep = 0

                if not showing then
                    lib.showTextUI(Lockers.L('open_locker'))
                    showing = true
                end

                if IsControlJustReleased(0, 38) then
                    openVehicleLocker(vehicle)
                end
            elseif showing then
                lib.hideTextUI()
                showing = false
            end
        elseif showing then
            lib.hideTextUI()
            showing = false
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(500, registerVehicleTarget)
    end
end)
