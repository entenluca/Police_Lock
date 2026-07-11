AutoGlovebox.Adapters = AutoGlovebox.Adapters or {}

local STORAGE_PREFIXES = {
    glovebox = 'glovebox',
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
        ids[#ids + 1] = ('%s-%s'):format(prefix, variants[i])
    end

    return ids
end

---@param plate string
---@param _netId number
---@param _vehicleClass number|nil
---@param _storageType string|nil
---@return boolean
local function ensureStorage(plate, _netId, _vehicleClass, _storageType)
    return true
end

---@param plate string
---@param items table
---@param vehicleClass number|nil
---@param _netId number|nil
---@param storageType string|nil
---@return boolean success
---@return string|nil reason
local function addItems(plate, items, vehicleClass, _netId, storageType)
    local storageLabel = AutoGlovebox.GetStorageLabel(storageType)
    local inventoryIds = getInventoryIds(plate, storageType)

    for i = 1, #items do
        local entry = items[i]
        local itemName = entry.item
        local amount = entry.amount or 1
        local metadata = entry.metadata or false
        local added = false

        if itemName and amount > 0 then
            for j = 1, #inventoryIds do
                local inventoryId = inventoryIds[j]
                local success = exports['qb-inventory']:AddItem(
                    inventoryId,
                    itemName,
                    amount,
                    false,
                    metadata,
                    'autoglovebox',
                    vehicleClass or 0
                )

                if success then
                    added = true
                    break
                end
            end

            if not added then
                return false, ('%s x%s: %s voll oder Item ungültig'):format(itemName, amount, storageLabel)
            end
        end
    end

    return true
end

AutoGlovebox.Adapters['qb-inventory'] = {
    name = 'qb-inventory',
    ensureStorage = ensureStorage,
    addItems = addItems,
}
