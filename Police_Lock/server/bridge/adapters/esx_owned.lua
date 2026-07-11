AutoGlovebox.Adapters = AutoGlovebox.Adapters or {}

local ESX

local STORAGE_COLUMNS = {
    glovebox = 'glovebox',
    trunk = 'trunk',
}

local function getESX()
    if ESX then
        return ESX
    end

    if GetResourceState('es_extended') ~= 'started' then
        return nil
    end

    ESX = exports.es_extended:getSharedObject()
    return ESX
end

---@param storageData table|string|nil
---@return table
local function decodeStorage(storageData)
    if not storageData or storageData == '' or storageData == '[]' then
        return {}
    end

    local decoded = json.decode(storageData)

    if type(decoded) ~= 'table' then
        return {}
    end

    return decoded
end

---@param items table
---@return number
local function getNextSlot(items)
    local nextSlot = 1

    for key, value in pairs(items) do
        local slot = tonumber(key) or value.slot

        if slot and slot >= nextSlot then
            nextSlot = slot + 1
        end
    end

    return nextSlot
end

---@param itemName string
---@return table|nil
local function getItemData(itemName)
    local esx = getESX()

    if not esx then
        return nil
    end

    if esx.Items and esx.Items[itemName] then
        return esx.Items[itemName]
    end

    return {
        label = esx.GetItemLabel and esx.GetItemLabel(itemName) or itemName,
        weight = 0,
    }
end

---@param plate string
---@param _netId number
---@param _vehicleClass number|nil
---@param _storageType string|nil
---@return boolean
local function ensureStorage(plate, _netId, _vehicleClass, _storageType)
    local row = MySQL.single.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate })
    return row ~= nil
end

---@param plate string
---@param items table
---@param _vehicleClass number|nil
---@param _netId number|nil
---@param storageType string|nil
---@return boolean success
---@return string|nil reason
local function addItems(plate, items, _vehicleClass, _netId, storageType)
    local storage = AutoGlovebox.NormalizeStorageType(storageType)
    local column = STORAGE_COLUMNS[storage]
    local storageLabel = AutoGlovebox.GetStorageLabel(storage)
    local row = MySQL.single.await(('SELECT `%s` AS storage_data FROM owned_vehicles WHERE plate = ? LIMIT 1'):format(column), { plate })

    if not row then
        return false, 'Fahrzeug nicht in owned_vehicles gefunden'
    end

    local storageData = decodeStorage(row.storage_data)

    for i = 1, #items do
        local entry = items[i]
        local itemName = entry.item
        local amount = entry.amount or 1
        local metadata = entry.metadata

        if itemName and amount > 0 then
            local itemData = getItemData(itemName)

            if not itemData then
                return false, ('%s: Item nicht in ESX registriert'):format(itemName)
            end

            local slot = getNextSlot(storageData)

            storageData[tostring(slot)] = {
                name = itemName,
                count = amount,
                slot = slot,
                label = itemData.label,
                weight = itemData.weight or 0,
                metadata = metadata or {},
            }
        end
    end

    local updated = MySQL.update.await(
        ('UPDATE owned_vehicles SET `%s` = ? WHERE plate = ?'):format(column),
        { json.encode(storageData), plate }
    )

    if not updated or updated < 1 then
        return false, ('owned_vehicles.%s konnte nicht gespeichert werden'):format(column)
    end

    return true
end

AutoGlovebox.Adapters.esx = {
    name = 'esx (owned_vehicles)',
    ensureStorage = ensureStorage,
    addItems = addItems,
}
