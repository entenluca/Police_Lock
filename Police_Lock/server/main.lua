local equippedPlates = {}

local STORAGE_TYPES = { 'glovebox', 'trunk' }

local function debugPrint(...)
    if Config.Debug then
        print('^3[AutoGlovebox]^7', ...)
    end
end

local function logFailure(message, ...)
    print(('^1[AutoGlovebox]^7 %s'):format(message:format(...)))
end

local function notify(source, message, type)
    if source == 0 then
        print(('^3[AutoGlovebox]^7 %s'):format(message))
        return
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'AutoGlovebox',
        description = message,
        type = type or 'inform',
    })
end

local function hasPermission(source, permission)
    if source == 0 then
        return true
    end

    return IsPlayerAceAllowed(source, permission)
end

---@param entity number
---@return string
local function getVehiclePlate(entity)
    return AutoGlovebox.NormalizePlate(GetVehicleNumberPlateText(entity))
end

local function getEquippedCacheKey(plate, storageType)
    return ('%s:%s'):format(AutoGlovebox.NormalizePlate(plate), AutoGlovebox.NormalizeStorageType(storageType))
end

local function isAlreadyEquipped(plate, storageType)
    local normalizedPlate = AutoGlovebox.NormalizePlate(plate)
    local storage = AutoGlovebox.NormalizeStorageType(storageType)
    local cacheKey = getEquippedCacheKey(normalizedPlate, storage)

    if equippedPlates[cacheKey] then
        return true
    end

    local result = MySQL.scalar.await(
        'SELECT 1 FROM autoglovebox_equipped WHERE plate = ? AND storage_type = ? LIMIT 1',
        { normalizedPlate, storage }
    )

    if result then
        equippedPlates[cacheKey] = true
        return true
    end

    return false
end

local function markEquipped(plate, modelName, storageType)
    local normalizedPlate = AutoGlovebox.NormalizePlate(plate)
    local storage = AutoGlovebox.NormalizeStorageType(storageType)
    local cacheKey = getEquippedCacheKey(normalizedPlate, storage)
    equippedPlates[cacheKey] = true

    MySQL.insert.await(
        'INSERT INTO autoglovebox_equipped (plate, storage_type, model) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE model = VALUES(model)',
        { normalizedPlate, storage, modelName }
    )
end

---@param source number
---@param netId number
---@param plate string
---@param modelHash number
---@param vehicleClass number|nil
---@param force boolean|nil
---@param loadoutId number|nil
---@param storageType string|nil
---@return boolean success
---@return string|nil reason
local function equipVehicle(source, netId, plate, modelHash, vehicleClass, force, loadoutId, storageType)
    if not AutoGlovebox.Loadouts.IsReady() then
        return false, 'Loadouts noch nicht geladen'
    end

    if not AutoGlovebox.Inventory.IsInitialized() then
        return false, 'Inventar noch nicht initialisiert'
    end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then
        return false, 'Fahrzeug nicht gefunden'
    end

    local normalizedPlate = getVehiclePlate(entity)
    local modelName = AutoGlovebox.Loadouts.GetModelName(modelHash)
    local addMode, items, resolvedStorage

    if loadoutId then
        addMode, items, resolvedStorage = AutoGlovebox.Loadouts.GetLoadoutById(loadoutId)
        storageType = resolvedStorage or storageType
    else
        storageType = AutoGlovebox.NormalizeStorageType(storageType)
        addMode, items = AutoGlovebox.Loadouts.GetLoadout(normalizedPlate, modelHash, storageType)
        resolvedStorage = storageType
    end

    resolvedStorage = AutoGlovebox.NormalizeStorageType(resolvedStorage)
    local storageLabel = AutoGlovebox.GetStorageLabel(resolvedStorage)

    if not addMode or #items == 0 then
        if loadoutId then
            return false, 'Loadout nicht gefunden oder ohne Items'
        end

        return false, ('Kein %s-Loadout für %s (%s)'):format(storageLabel, normalizedPlate, modelName or modelHash)
    end

    if not AutoGlovebox.IsValidAddMode(addMode) then
        return false, ('Ungültiger addMode: %s'):format(addMode)
    end

    if addMode == 'once' and not force and isAlreadyEquipped(normalizedPlate, resolvedStorage) then
        return false, ('%s wurde bereits ausgerüstet (once)'):format(storageLabel)
    end

    local ensured = AutoGlovebox.Inventory.EnsureStorage(normalizedPlate, netId, vehicleClass, resolvedStorage)

    if not ensured then
        return false, ('%s konnte nicht geladen werden'):format(storageLabel)
    end

    local success, reason = AutoGlovebox.Inventory.AddItems(normalizedPlate, items, vehicleClass, netId, resolvedStorage)

    if not success then
        return false, reason or 'Items konnten nicht hinzugefügt werden'
    end

    if addMode == 'once' then
        markEquipped(normalizedPlate, modelName, resolvedStorage)
    end

    debugPrint(('Fahrzeug ausgerüstet (%s): %s (%s, %s)'):format(storageLabel, normalizedPlate, modelName or 'unbekannt', addMode))
    return true
end

---@param source number
---@param netId number
---@param plate string
---@param modelHash number
---@param vehicleClass number|nil
---@param loadoutId number|nil
---@return boolean success
---@return string|nil reason
function AutoGlovebox.ForceEquipVehicle(source, netId, plate, modelHash, vehicleClass, loadoutId)
    local retries = Config.EquipRetries or 4
    local delay = Config.EquipRetryDelay or 750
    local lastReason

    for attempt = 1, retries do
        local success, reason = equipVehicle(source, netId, plate, modelHash, vehicleClass, true, loadoutId, nil)

        if success then
            return true
        end

        lastReason = reason

        if attempt < retries then
            Wait(delay)
        end
    end

    return false, lastReason
end

---@param source number
---@param netId number
---@param plate string
---@param modelHash number
---@param vehicleClass number|nil
---@param force boolean
local function equipVehicleWithRetry(source, netId, plate, modelHash, vehicleClass, force)
    local retries = Config.EquipRetries or 4
    local delay = Config.EquipRetryDelay or 750

    CreateThread(function()
        for storageIndex = 1, #STORAGE_TYPES do
            local storageType = STORAGE_TYPES[storageIndex]

            for attempt = 1, retries do
                local success, reason = equipVehicle(source, netId, plate, modelHash, vehicleClass, force, nil, storageType)

                if success then
                    if force and source > 0 and storageIndex == #STORAGE_TYPES then
                        notify(source, ('Fahrzeug %s wurde ausgerüstet.'):format(AutoGlovebox.NormalizePlate(plate)), 'success')
                    end
                    break
                end

                if reason and reason:find('^Kein ') then
                    break
                end

                debugPrint(('[%s] Versuch %s/%s fehlgeschlagen: %s'):format(
                    storageType,
                    attempt,
                    retries,
                    reason or 'unbekannt'
                ))

                if attempt == retries then
                    logFailure('Ausrüstung fehlgeschlagen (%s, %s): %s', storageType, AutoGlovebox.NormalizePlate(plate), reason or 'unbekannt')

                    if force and source > 0 then
                        notify(source, reason or 'Ausrüstung fehlgeschlagen.', 'error')
                    end
                else
                    Wait(delay)
                end
            end
        end
    end)
end

RegisterNetEvent('autoglovebox:server:vehicleSpawned', function(netId, plate, modelHash, vehicleClass)
    local source = source

    if type(netId) ~= 'number' or type(plate) ~= 'string' or type(modelHash) ~= 'number' then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if not entity or entity == 0 then
        return
    end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(entity)
    local distance = #(playerCoords - vehicleCoords)

    if distance > Config.MaxReportDistance then
        debugPrint(('Spieler %s zu weit vom Fahrzeug entfernt (%.1fm)'):format(source, distance))
        return
    end

    equipVehicleWithRetry(source, netId, plate, modelHash, vehicleClass, false)
end)

RegisterNetEvent('autoglovebox:server:forceEquip', function(netId, plate, modelHash, vehicleClass)
    local source = source

    if not hasPermission(source, Config.IngameConfig.equipPermission)
        and not hasPermission(source, Config.AdminPanel.permission) then
        return
    end

    if type(netId) ~= 'number' or type(plate) ~= 'string' or type(modelHash) ~= 'number' then
        return
    end

    equipVehicleWithRetry(source, netId, plate, modelHash, vehicleClass, true)
end)

exports('EquipVehicle', function(netId, plate, modelHash, force, vehicleClass)
    equipVehicleWithRetry(0, netId, plate, modelHash, vehicleClass, force == true)
    return true
end)

exports('IsEquipped', function(plate, storageType)
    return isAlreadyEquipped(plate, storageType or 'glovebox')
end)

exports('ResetEquipped', function(plate, storageType)
    local normalizedPlate = AutoGlovebox.NormalizePlate(plate)

    if storageType then
        local storage = AutoGlovebox.NormalizeStorageType(storageType)
        equippedPlates[getEquippedCacheKey(normalizedPlate, storage)] = nil
        MySQL.update.await(
            'DELETE FROM autoglovebox_equipped WHERE plate = ? AND storage_type = ?',
            { normalizedPlate, storage }
        )
        return true
    end

    for i = 1, #STORAGE_TYPES do
        local storage = STORAGE_TYPES[i]
        equippedPlates[getEquippedCacheKey(normalizedPlate, storage)] = nil
    end

    MySQL.update.await('DELETE FROM autoglovebox_equipped WHERE plate = ?', { normalizedPlate })
    return true
end)

if Config.IngameConfig and Config.IngameConfig.enabled then
    lib.addCommand('gloveboxequip', {
        help = 'Rüstet das aktuelle Fahrzeug manuell aus (erzwingt Ausrüstung)',
        restricted = Config.IngameConfig.equipPermission,
    }, function(source)
        TriggerClientEvent('autoglovebox:client:manualEquip', source, true)
    end)
end

local function startup()
    local success, errorMessage = AutoGlovebox.Inventory.Init()

    if not success then
        print(('^1[AutoGlovebox]^7 %s'):format(errorMessage))
        print('^3[AutoGlovebox]^7 Warte auf Framework/Inventar-Resources (Auto-Modus aktiv)...')
        return
    end

    print(('^2[AutoGlovebox]^7 gestartet | %s'):format(AutoGlovebox.AutoDetect.FormatResolved()))
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(500, startup)
        return
    end

    if not AutoGlovebox.AutoDetect.IsDependencyResource(resourceName) then
        return
    end

    if AutoGlovebox.Inventory.IsInitialized() then
        return
    end

    SetTimeout(500, startup)
end)

AddEventHandler('playerJoining', function()
    local source = source

    SetTimeout(2000, function()
        if AutoGlovebox.Loadouts.IsReady() then
            TriggerClientEvent('autoglovebox:client:syncCache', source, AutoGlovebox.Loadouts.GetClientCache())
        end
    end)
end)
