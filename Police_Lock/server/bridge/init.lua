AutoGlovebox = AutoGlovebox or {}
AutoGlovebox.Inventory = AutoGlovebox.Inventory or {}

local activeAdapter
local initialized = false

local function debugPrint(...)
    if Config.Debug then
        print('^3[AutoGlovebox]^7', ...)
    end
end

function AutoGlovebox.Inventory.GetAdapter()
    return activeAdapter
end

function AutoGlovebox.Inventory.GetAdapterName()
    return activeAdapter and activeAdapter.name or 'unbekannt'
end

function AutoGlovebox.Inventory.IsInitialized()
    return initialized
end

---@return boolean success
---@return string|nil error
function AutoGlovebox.Inventory.Init()
    local resolved = AutoGlovebox.AutoDetect.Resolve(true)

    if not resolved.valid then
        initialized = false
        activeAdapter = nil
        return false, resolved.error
    end

    activeAdapter = AutoGlovebox.Adapters[resolved.inventory]

    if not activeAdapter then
        initialized = false
        return false, ('Kein Adapter für Inventarsystem "%s" vorhanden'):format(resolved.inventory)
    end

    initialized = true
    debugPrint(AutoGlovebox.AutoDetect.FormatResolved())

    return true
end

---@param plate string
---@param netId number
---@param vehicleClass number|nil
---@param storageType string|nil
---@return boolean
function AutoGlovebox.Inventory.EnsureStorage(plate, netId, vehicleClass, storageType)
    if not activeAdapter then
        return false
    end

    return activeAdapter.ensureStorage(plate, netId, vehicleClass, storageType)
end

---@param plate string
---@param items table
---@param vehicleClass number|nil
---@param netId number|nil
---@param storageType string|nil
---@return boolean success
---@return string|nil reason
function AutoGlovebox.Inventory.AddItems(plate, items, vehicleClass, netId, storageType)
    if not activeAdapter then
        return false, 'Inventar-Adapter nicht initialisiert'
    end

    return activeAdapter.addItems(plate, items, vehicleClass, netId, storageType)
end

---@param plate string
---@param netId number
---@param vehicleClass number|nil
---@return boolean
function AutoGlovebox.Inventory.EnsureGlovebox(plate, netId, vehicleClass)
    return AutoGlovebox.Inventory.EnsureStorage(plate, netId, vehicleClass, 'glovebox')
end
