local registered = {}
local targetSystem

local function getTargetSystem()
    if targetSystem then
        return targetSystem
    end

    targetSystem = Lockers.Framework.DetectTarget()
    return targetSystem
end

local function removeLockerTarget(lockerId)
    local entry = registered[lockerId]

    if not entry then
        return
    end

    local system = getTargetSystem()

    if system == 'ox_target' then
        exports.ox_target:removeZone(entry.zoneId)
    elseif system == 'qb-target' then
        exports['qb-target']:RemoveZone(entry.zoneName)
    end

    registered[lockerId] = nil
end

local function addLockerTarget(locker)
    removeLockerTarget(locker.id)

    local coords = Lockers.ParseCoords(locker.coordinates)

    if not coords then
        return
    end

    local system = getTargetSystem()
    local distance = locker.target_distance or 2.0
    local label = Lockers.L('open_locker')

    if system == 'ox_target' then
        local zoneId = exports.ox_target:addSphereZone({
            coords = coords,
            radius = distance,
            debug = Config.Debug,
            options = {
                {
                    name = ('locker_%s'):format(locker.id),
                    icon = 'fa-solid fa-box-open',
                    label = label,
                    distance = distance,
                    onSelect = function()
                        TriggerServerEvent('lockers:server:requestOpen', locker.id)
                    end,
                },
            },
        })

        registered[locker.id] = { zoneId = zoneId }
        return
    end

    if system == 'qb-target' then
        local zoneName = ('locker_%s'):format(locker.id)

        exports['qb-target']:AddCircleZone(zoneName, coords, distance, {
            name = zoneName,
            debugPoly = Config.Debug,
            useZ = true,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'lockers:client:targetOpen',
                    icon = 'fas fa-box-open',
                    label = label,
                    lockerId = locker.id,
                },
            },
            distance = distance,
        })

        registered[locker.id] = { zoneName = zoneName }
        return
    end

    Lockers.Debug('Kein Target-System gefunden – Fallback-TextUI aktiv')
end

RegisterNetEvent('lockers:client:targetOpen', function(data)
    local lockerId = data and data.lockerId

    if lockerId then
        TriggerServerEvent('lockers:server:requestOpen', lockerId)
    end
end)

RegisterNetEvent('lockers:client:refreshTargets', function(lockerList)
    for lockerId in pairs(registered) do
        removeLockerTarget(lockerId)
    end

    for i = 1, #(lockerList or {}) do
        addLockerTarget(lockerList[i])
    end
end)

-- Fallback ohne Target-System
CreateThread(function()
    local showing = false

    while not getTargetSystem() do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local nearest

        for i = 1, 200 do
            local locker = registered[i]

            if locker and locker.coords then
                local dist = #(playerCoords - locker.coords)

                if dist <= (locker.distance or 2.0) and (not nearest or dist < nearest.dist) then
                    nearest = { id = i, dist = dist }
                end
            end
        end

        if nearest and nearest.dist <= 2.0 then
            sleep = 0

            if not showing then
                lib.showTextUI(Lockers.L('open_locker'))
                showing = true
            end

            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('lockers:server:requestOpen', nearest.id)
            end
        elseif showing then
            lib.hideTextUI()
            showing = false
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for lockerId in pairs(registered) do
        removeLockerTarget(lockerId)
    end
end)
