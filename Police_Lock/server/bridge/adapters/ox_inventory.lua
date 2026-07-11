AutoGlovebox.Adapters = AutoGlovebox.Adapters or {}

local STORAGE_PREFIXES = {
    glovebox = 'glove',
    trunk = 'trunk',
}

---@param plate string
---@param storageType string|nil
---@return string[]
local function getInventoryIds(plate, storageType)
    local storage = AutoGlovebox.NormalizeStorageType(storageType)
    local prefix = STORAGE_PREFIXES[storage]
    local variants = AutoGlovebox.UniquePlateVariants(AutoGlovebox.GetPlateVariants(plate))
    local ids = {}

    for i = 1, #variants do
        ids[#ids + 1] = ('%s%s'):format(prefix, variants[i])
    end

    return ids
end

---@param plate string
---@param netId number
---@param _vehicleClass number|nil
---@param storageType string|nil
---@return boolean
---@return string|nil
local function ensureStorage(plate, netId, _vehicleClass, storageType)
    local inventoryIds = getInventoryIds(plate, storageType)

    for attempt = 1, 5 do
        for i = 1, #inventoryIds do
            local inventory = exports.ox_inventory:GetInventory({
                id = inventoryIds[i],
                netid = netId,
            })

            if inventory then
                return true, inventoryIds[i]
            end
        end

        Wait(400)
    end

    return false, inventoryIds[1]
end

---@param plate string
---@param items table
---@param _vehicleClass number|nil
---@param netId number|nil
---@param storageType string|nil
---@return boolean success
---@return string|nil reason
local function addItems(plate, items, _vehicleClass, netId, storageType)
    local storageLabel = AutoGlovebox.GetStorageLabel(storageType)
    local successEnsure, inventoryId = ensureStorage(plate, netId or 0, _vehicleClass, storageType)

    if not successEnsure or not inventoryId then
        return false, ('%s konnte nicht geladen werden'):format(storageLabel)
    end

    for i = 1, #items do
        local entry = items[i]
        local itemName = entry.item
        local amount = entry.amount or 1
        local metadata = entry.metadata

        if itemName and amount > 0 then
            local success, response = exports.ox_inventory:AddItem(inventoryId, itemName, amount, metadata)

            if not success then
                return false, ('%s x%s: %s'):format(itemName, amount, response or 'unbekannter Fehler')
            end
        end
    end

    return true
end

AutoGlovebox.Adapters.ox_inventory = {
    name = 'ox_inventory',
    ensureStorage = ensureStorage,
    addItems = addItems,
}
