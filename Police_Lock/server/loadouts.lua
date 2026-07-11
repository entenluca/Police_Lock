AutoGlovebox.Loadouts = AutoGlovebox.Loadouts or {}

local STORAGE_TYPES = { 'glovebox', 'trunk' }

local modelLoadouts = {
    glovebox = {},
    trunk = {},
}
local plateLoadouts = {
    glovebox = {},
    trunk = {},
}
local modelHashes = {}
local loadoutsById = {}
local initialized = false

local function debugPrint(...)
    if Config.Debug then
        print('^3[AutoGlovebox:Loadouts]^7', ...)
    end
end

local function parseMetadata(metadata)
    if not metadata or metadata == '' then
        return nil
    end

    return json.decode(metadata)
end

local function encodeMetadata(metadata)
    if not metadata or next(metadata) == nil then
        return nil
    end

    return json.encode(metadata)
end

local function getStorageMaps(storageType)
    local storage = AutoGlovebox.NormalizeStorageType(storageType)

    return modelLoadouts[storage], plateLoadouts[storage]
end

local function seedDefaults()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM autoglovebox_loadouts')

    if count and count > 0 then
        return
    end

    local defaults = {
        {
            type = 'model',
            key = 'sektranser',
            storage_type = 'glovebox',
            add_mode = nil,
            items = {
                { item = 'zugfuehrerweste', amount = 1 },
                { item = 'einsatzmappe', amount = 1 },
                { item = 'flashlight', amount = 1 },
            },
        },
        {
            type = 'model',
            key = 'hlf',
            storage_type = 'glovebox',
            add_mode = nil,
            items = {
                { item = 'atemschutzmaske', amount = 2 },
                { item = 'feuerwehraxt', amount = 1 },
            },
        },
    }

    for i = 1, #defaults do
        local entry = defaults[i]
        local loadoutId = MySQL.insert.await(
            'INSERT INTO autoglovebox_loadouts (loadout_type, loadout_key, storage_type, add_mode) VALUES (?, ?, ?, ?)',
            { entry.type, entry.key, entry.storage_type, entry.add_mode }
        )

        for j = 1, #entry.items do
            local item = entry.items[j]
            MySQL.insert.await(
                'INSERT INTO autoglovebox_loadout_items (loadout_id, item, amount) VALUES (?, ?, ?)',
                { loadoutId, item.item, item.amount }
            )
        end
    end

    print('^2[AutoGlovebox]^7 Standard-Loadouts in die Datenbank importiert')
end

function AutoGlovebox.Loadouts.Refresh()
    modelLoadouts = { glovebox = {}, trunk = {} }
    plateLoadouts = { glovebox = {}, trunk = {} }
    modelHashes = {}
    loadoutsById = {}

    local loadouts = MySQL.query.await([[
        SELECT id, loadout_type, loadout_key, storage_type, add_mode
        FROM autoglovebox_loadouts
        ORDER BY storage_type ASC, loadout_type ASC, loadout_key ASC
    ]]) or {}

    if #loadouts == 0 then
        return
    end

    local loadoutIds = {}

    for i = 1, #loadouts do
        loadoutIds[#loadoutIds + 1] = loadouts[i].id
    end

    local items = MySQL.query.await(([[
        SELECT id, loadout_id, item, amount, metadata
        FROM autoglovebox_loadout_items
        WHERE loadout_id IN (%s)
        ORDER BY id ASC
    ]]):format(table.concat(loadoutIds, ','))) or {}

    local itemsByLoadout = {}

    for i = 1, #items do
        local row = items[i]
        itemsByLoadout[row.loadout_id] = itemsByLoadout[row.loadout_id] or {}
        itemsByLoadout[row.loadout_id][#itemsByLoadout[row.loadout_id] + 1] = {
            id = row.id,
            item = row.item,
            amount = row.amount,
            metadata = parseMetadata(row.metadata),
        }
    end

    for i = 1, #loadouts do
        local row = loadouts[i]
        local storageType = AutoGlovebox.NormalizeStorageType(row.storage_type)
        local loadout = {
            id = row.id,
            storage_type = storageType,
            add_mode = row.add_mode,
            addMode = row.add_mode or Config.AddMode,
            items = itemsByLoadout[row.id] or {},
        }

        loadoutsById[row.id] = {
            loadout_type = row.loadout_type,
            loadout_key = row.loadout_key,
            storage_type = storageType,
            loadout = loadout,
        }

        if row.loadout_type == 'model' then
            local key = row.loadout_key:lower()
            modelLoadouts[storageType][key] = loadout
            modelHashes[joaat(key)] = key
        else
            plateLoadouts[storageType][AutoGlovebox.NormalizePlate(row.loadout_key)] = loadout
        end
    end

    local modelCount, plateCount = 0, 0

    for i = 1, #STORAGE_TYPES do
        for _ in pairs(modelLoadouts[STORAGE_TYPES[i]]) do
            modelCount = modelCount + 1
        end

        for _ in pairs(plateLoadouts[STORAGE_TYPES[i]]) do
            plateCount = plateCount + 1
        end
    end

    debugPrint(('Loadouts geladen: %s Modelle, %s Kennzeichen'):format(modelCount, plateCount))
end

function AutoGlovebox.Loadouts.Init()
    seedDefaults()
    AutoGlovebox.Loadouts.Refresh()
    initialized = true
    TriggerClientEvent('autoglovebox:client:syncCache', -1, AutoGlovebox.Loadouts.GetClientCache())
end

function AutoGlovebox.Loadouts.IsReady()
    return initialized
end

---@return table
function AutoGlovebox.Loadouts.GetClientCache()
    local models = {}
    local plates = {}
    local seenModels = {}
    local seenPlates = {}

    for i = 1, #STORAGE_TYPES do
        local storage = STORAGE_TYPES[i]

        for modelName, loadout in pairs(modelLoadouts[storage]) do
            if #loadout.items > 0 and not seenModels[modelName] then
                seenModels[modelName] = true
                models[#models + 1] = joaat(modelName)
            end
        end

        for plate, loadout in pairs(plateLoadouts[storage]) do
            if #loadout.items > 0 and not seenPlates[plate] then
                seenPlates[plate] = true
                plates[#plates + 1] = plate
            end
        end
    end

    return {
        modelHashes = models,
        plates = plates,
    }
end

---@param modelHash number
---@return string|nil
local function resolveModelName(modelHash)
    if not modelHash then
        return nil
    end

    if modelHashes[modelHash] then
        return modelHashes[modelHash]
    end

    for i = 1, #STORAGE_TYPES do
        for modelName in pairs(modelLoadouts[STORAGE_TYPES[i]]) do
            if joaat(modelName) == modelHash then
                modelHashes[modelHash] = modelName
                return modelName
            end
        end
    end

    return nil
end

---@param modelHash number
---@return string|nil
function AutoGlovebox.Loadouts.GetModelName(modelHash)
    return resolveModelName(modelHash)
end

---@param plate string
---@param modelHash number|nil
---@return boolean
function AutoGlovebox.Loadouts.IsConfigured(plate, modelHash)
    local normalizedPlate = AutoGlovebox.NormalizePlate(plate)

    for i = 1, #STORAGE_TYPES do
        local storage = STORAGE_TYPES[i]

        if plateLoadouts[storage][normalizedPlate] and #plateLoadouts[storage][normalizedPlate].items > 0 then
            return true
        end
    end

    if modelHash and modelHashes[modelHash] then
        for i = 1, #STORAGE_TYPES do
            local loadout = modelLoadouts[STORAGE_TYPES[i]][modelHashes[modelHash]]

            if loadout and #loadout.items > 0 then
                return true
            end
        end
    end

    return false
end

---@param plate string
---@param modelHash number|nil
---@param storageType string|nil
---@return 'once'|'always'|nil addMode
---@return table items
function AutoGlovebox.Loadouts.GetLoadout(plate, modelHash, storageType)
    storageType = AutoGlovebox.NormalizeStorageType(storageType)
    local normalizedPlate = AutoGlovebox.NormalizePlate(plate)
    local models, plates = getStorageMaps(storageType)

    if plates[normalizedPlate] and #plates[normalizedPlate].items > 0 then
        local loadout = plates[normalizedPlate]
        return loadout.addMode, loadout.items
    end

    local modelName = resolveModelName(modelHash)

    if modelName and models[modelName] and #models[modelName].items > 0 then
        local loadout = models[modelName]
        return loadout.addMode, loadout.items
    end

    return nil, {}
end

---@param loadoutId number
---@return 'once'|'always'|nil addMode
---@return table items
---@return 'glovebox'|'trunk'|nil storageType
function AutoGlovebox.Loadouts.GetLoadoutById(loadoutId)
    local entry = loadoutsById[loadoutId]

    if not entry then
        return nil, {}, nil
    end

    return entry.loadout.addMode, entry.loadout.items, entry.storage_type
end

---@return table
function AutoGlovebox.Loadouts.GetAll()
    local result = {}

    for loadoutId, entry in pairs(loadoutsById) do
        result[#result + 1] = {
            id = loadoutId,
            loadout_type = entry.loadout_type,
            loadout_key = entry.loadout_key,
            storage_type = entry.storage_type,
            add_mode = entry.loadout.add_mode,
            items = entry.loadout.items,
        }
    end

    table.sort(result, function(a, b)
        if a.storage_type == b.storage_type then
            if a.loadout_type == b.loadout_type then
                return a.loadout_key < b.loadout_key
            end

            return a.loadout_type < b.loadout_type
        end

        return a.storage_type < b.storage_type
    end)

    return result
end

---@param source number|nil
local function broadcastCache(source)
    local cache = AutoGlovebox.Loadouts.GetClientCache()

    if source then
        TriggerClientEvent('autoglovebox:client:syncCache', source, cache)
    else
        TriggerClientEvent('autoglovebox:client:syncCache', -1, cache)
    end
end

---@param data table
---@return number|nil loadoutId
---@return string|nil error
function AutoGlovebox.Loadouts.SaveLoadout(data)
    local loadoutType = data.loadout_type
    local loadoutKey = data.loadout_key
    local addMode = data.add_mode
    local storageType = AutoGlovebox.NormalizeStorageType(data.storage_type)

    if loadoutType ~= 'model' and loadoutType ~= 'plate' then
        return nil, 'Ungültiger Loadout-Typ'
    end

    if not loadoutKey or loadoutKey == '' then
        return nil, 'Schlüssel fehlt'
    end

    if loadoutType == 'model' then
        loadoutKey = loadoutKey:lower()
    else
        loadoutKey = AutoGlovebox.NormalizePlate(loadoutKey)
    end

    if addMode and not AutoGlovebox.IsValidAddMode(addMode) then
        return nil, 'Ungültiger Add-Modus'
    end

    local existingId = MySQL.scalar.await(
        'SELECT id FROM autoglovebox_loadouts WHERE loadout_type = ? AND loadout_key = ? AND storage_type = ? LIMIT 1',
        { loadoutType, loadoutKey, storageType }
    )

    local loadoutId = data.id

    if existingId and tonumber(existingId) ~= tonumber(loadoutId) then
        return nil, 'Loadout existiert bereits'
    end

    if loadoutId then
        MySQL.update.await(
            'UPDATE autoglovebox_loadouts SET loadout_type = ?, loadout_key = ?, storage_type = ?, add_mode = ? WHERE id = ?',
            { loadoutType, loadoutKey, storageType, addMode, loadoutId }
        )
    else
        loadoutId = MySQL.insert.await(
            'INSERT INTO autoglovebox_loadouts (loadout_type, loadout_key, storage_type, add_mode) VALUES (?, ?, ?, ?)',
            { loadoutType, loadoutKey, storageType, addMode }
        )
    end

    AutoGlovebox.Loadouts.Refresh()
    broadcastCache()

    return loadoutId
end

---@param loadoutId number
---@return boolean success
---@return string|nil error
function AutoGlovebox.Loadouts.DeleteLoadout(loadoutId)
    if not loadoutId then
        return false, 'Loadout-ID fehlt'
    end

    MySQL.update.await('DELETE FROM autoglovebox_loadouts WHERE id = ?', { loadoutId })
    AutoGlovebox.Loadouts.Refresh()
    broadcastCache()

    return true
end

---@param loadoutId number
---@param item string
---@param amount number
---@param metadata table|nil
---@return number|nil itemId
---@return string|nil error
function AutoGlovebox.Loadouts.AddItem(loadoutId, item, amount, metadata)
    if not loadoutId or not item or item == '' then
        return nil, 'Ungültige Item-Daten'
    end

    amount = tonumber(amount) or 1

    if amount < 1 then
        return nil, 'Anzahl muss mindestens 1 sein'
    end

    local itemId = MySQL.insert.await(
        'INSERT INTO autoglovebox_loadout_items (loadout_id, item, amount, metadata) VALUES (?, ?, ?, ?)',
        { loadoutId, item, amount, encodeMetadata(metadata) }
    )

    AutoGlovebox.Loadouts.Refresh()
    broadcastCache()

    return itemId
end

---@param itemId number
---@return boolean success
---@return string|nil error
function AutoGlovebox.Loadouts.RemoveItem(itemId)
    if not itemId then
        return false, 'Item-ID fehlt'
    end

    MySQL.update.await('DELETE FROM autoglovebox_loadout_items WHERE id = ?', { itemId })
    AutoGlovebox.Loadouts.Refresh()
    broadcastCache()

    return true
end

---@param loadoutId number
---@param newSpawnName string
---@return number|nil loadoutId
---@return string|nil error
function AutoGlovebox.Loadouts.CopyLoadout(loadoutId, newSpawnName)
    if not loadoutId then
        return nil, 'Loadout-ID fehlt'
    end

    if not newSpawnName or newSpawnName == '' then
        return nil, 'Spawn-Name fehlt'
    end

    newSpawnName = newSpawnName:lower()

    local source = MySQL.single.await([[
        SELECT id, loadout_type, loadout_key, storage_type, add_mode
        FROM autoglovebox_loadouts
        WHERE id = ?
        LIMIT 1
    ]], { loadoutId })

    if not source then
        return nil, 'Quell-Loadout nicht gefunden'
    end

    if source.loadout_type ~= 'model' then
        return nil, 'Nur Modell-Loadouts können kopiert werden'
    end

    local existingId = MySQL.scalar.await(
        'SELECT id FROM autoglovebox_loadouts WHERE loadout_type = ? AND loadout_key = ? AND storage_type = ? LIMIT 1',
        { 'model', newSpawnName, source.storage_type }
    )

    if existingId then
        return nil, 'Ein Loadout mit diesem Spawn-Namen existiert bereits'
    end

    local newLoadoutId = MySQL.insert.await(
        'INSERT INTO autoglovebox_loadouts (loadout_type, loadout_key, storage_type, add_mode) VALUES (?, ?, ?, ?)',
        { 'model', newSpawnName, source.storage_type, source.add_mode }
    )

    local items = MySQL.query.await(
        'SELECT item, amount, metadata FROM autoglovebox_loadout_items WHERE loadout_id = ? ORDER BY id ASC',
        { loadoutId }
    ) or {}

    for i = 1, #items do
        local item = items[i]
        MySQL.insert.await(
            'INSERT INTO autoglovebox_loadout_items (loadout_id, item, amount, metadata) VALUES (?, ?, ?, ?)',
            { newLoadoutId, item.item, item.amount, item.metadata }
        )
    end

    AutoGlovebox.Loadouts.Refresh()
    broadcastCache()

    return newLoadoutId
end

lib.callback.register('autoglovebox:server:getClientCache', function()
    return AutoGlovebox.Loadouts.GetClientCache()
end)
