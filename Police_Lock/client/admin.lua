local panelOpen = false

local function getAdminFillDistance()
    return Config.AdminPanel.fillDistance or Config.MaxReportDistance or 50.0
end

---@param loadoutType string|nil
---@param loadoutKey string|nil
---@return number|nil vehicle
local function findAdminFillVehicle(loadoutType, loadoutKey)
    if cache.vehicle and cache.vehicle ~= 0 and DoesEntityExist(cache.vehicle) then
        return cache.vehicle
    end

    local coords = GetEntityCoords(cache.ped)
    local radius = getAdminFillDistance()
    local targetModel = loadoutType == 'model' and loadoutKey and joaat(loadoutKey:lower()) or nil
    local targetPlate = loadoutType == 'plate' and loadoutKey and AutoGlovebox.NormalizePlate(loadoutKey) or nil
    local closestMatch = nil
    local closestMatchDist = radius + 1.0
    local closestAny = nil
    local closestAnyDist = radius + 1.0

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local distance = #(coords - GetEntityCoords(vehicle))

            if distance <= radius then
                local isMatch = false

                if targetPlate then
                    isMatch = AutoGlovebox.NormalizePlate(GetVehicleNumberPlateText(vehicle)) == targetPlate
                elseif targetModel then
                    isMatch = GetEntityModel(vehicle) == targetModel
                end

                if isMatch and distance < closestMatchDist then
                    closestMatch = vehicle
                    closestMatchDist = distance
                end

                if distance < closestAnyDist then
                    closestAny = vehicle
                    closestAnyDist = distance
                end
            end
        end
    end

    return closestMatch or closestAny
end

local function closeAdminPanel()
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openAdminPanel()
    local allowed = lib.callback.await('autoglovebox:admin:canOpen', false)

    if not allowed then
        lib.notify({
            title = 'AutoGlovebox',
            description = 'Keine Berechtigung für das Admin-Panel.',
            type = 'error',
        })
        return
    end

    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end

RegisterNetEvent('autoglovebox:client:openAdmin', function()
    openAdminPanel()
end)

RegisterNUICallback('close', function(_, cb)
    closeAdminPanel()
    cb('ok')
end)

RegisterNUICallback('getLoadouts', function(_, cb)
    local data = lib.callback.await('autoglovebox:admin:getLoadouts', false)
    cb(data or { loadouts = {}, defaultAddMode = Config.AddMode })
end)

RegisterNUICallback('saveLoadout', function(data, cb)
    local result = lib.callback.await('autoglovebox:admin:saveLoadout', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('deleteLoadout', function(data, cb)
    local result = lib.callback.await('autoglovebox:admin:deleteLoadout', false, data.loadoutId)
    cb(result or { success = false })
end)

RegisterNUICallback('addItem', function(data, cb)
    local result = lib.callback.await('autoglovebox:admin:addItem', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('removeItem', function(data, cb)
    local result = lib.callback.await('autoglovebox:admin:removeItem', false, data.itemId)
    cb(result or { success = false })
end)

RegisterNUICallback('refresh', function(_, cb)
    local result = lib.callback.await('autoglovebox:admin:refresh', false)
    cb(result or { success = false })
end)

RegisterNUICallback('resetEquipped', function(data, cb)
    local result = lib.callback.await('autoglovebox:admin:resetEquipped', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('fillVehicle', function(data, cb)
    local vehicle = findAdminFillVehicle(data.loadoutType, data.loadoutKey)
    local fillDistance = math.floor(getAdminFillDistance())

    if not vehicle or vehicle == 0 then
        cb({
            success = false,
            title = 'Kein Fahrzeug',
            error = ('Kein Fahrzeug in %sm Reichweite gefunden.'):format(fillDistance),
            type = 'error',
        })
        return
    end

    local result = lib.callback.await('autoglovebox:admin:fillVehicle', false, {
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        modelHash = GetEntityModel(vehicle),
        vehicleClass = GetVehicleClass(vehicle),
        loadoutId = data.loadoutId,
    })

    cb(result or { success = false, error = 'Unbekannter Fehler', type = 'error' })
end)

RegisterNUICallback('copyLoadout', function(data, cb)
    local result = lib.callback.await('autoglovebox:admin:copyLoadout', false, data)
    cb(result or { success = false })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeAdminPanel()
end)

exports('OpenAdminPanel', openAdminPanel)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)
