AutoGlovebox = AutoGlovebox or {}
AutoGlovebox.AutoDetect = AutoGlovebox.AutoDetect or {}

local resolved

local FRAMEWORK_RESOURCES = {
    { resource = 'qbx_core', framework = 'qb' },
    { resource = 'qb-core', framework = 'qb' },
    { resource = 'es_extended', framework = 'esx' },
}

local INVENTORY_RESOURCES = {
    { resource = 'ox_inventory', inventory = 'ox_inventory' },
    { resource = 'qb-inventory', inventory = 'qb-inventory' },
}

---@param resource string
---@return boolean
local function isResourceActive(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

---@param framework string
---@param inventory string
---@return boolean valid
---@return string|nil warning
local function validateCombination(framework, inventory)
    if inventory == 'qb-inventory' and framework ~= 'qb' then
        return false, 'qb-inventory benötigt QBCore (Config.Framework = "qb")'
    end

    if inventory == 'esx' and framework ~= 'esx' then
        return false, 'ESX-Inventar benötigt es_extended (Config.Framework = "esx")'
    end

    if inventory == 'qb-inventory' and not isResourceActive('qb-inventory') then
        return false, 'qb-inventory ist nicht gestartet'
    end

    if inventory == 'ox_inventory' and not isResourceActive('ox_inventory') then
        return false, 'ox_inventory ist nicht gestartet'
    end

    if inventory == 'esx' and not isResourceActive('es_extended') then
        return false, 'es_extended ist nicht gestartet'
    end

    return true
end

---@return boolean
local function isAutoFramework()
    if Config.Auto and Config.Auto.Framework == true then
        return true
    end

    return Config.Framework == 'auto'
end

---@return boolean
local function isAutoInventory()
    if Config.Auto and Config.Auto.Inventory == true then
        return true
    end

    return Config.Inventory == 'auto'
end

---@return string
local function getFrameworkConfigLabel()
    if isAutoFramework() then
        return 'auto'
    end

    return Config.Framework or 'unbekannt'
end

---@return string
local function getInventoryConfigLabel()
    if isAutoInventory() then
        return 'auto'
    end

    return Config.Inventory or 'unbekannt'
end

---@return 'qb'|'esx'|'standalone'|string
function AutoGlovebox.AutoDetect.Framework()
    if not isAutoFramework() then
        return Config.Framework or 'standalone'
    end

    for i = 1, #FRAMEWORK_RESOURCES do
        local entry = FRAMEWORK_RESOURCES[i]

        if isResourceActive(entry.resource) then
            return entry.framework
        end
    end

    return 'standalone'
end

---@param framework string
---@return 'ox_inventory'|'qb-inventory'|'esx'|nil
local function detectInventoryForFramework(framework)
    if framework == 'qb' then
        if isResourceActive('ox_inventory') then
            return 'ox_inventory'
        end

        if isResourceActive('qb-inventory') then
            return 'qb-inventory'
        end

        return nil
    end

    if framework == 'esx' then
        if isResourceActive('ox_inventory') then
            return 'ox_inventory'
        end

        if isResourceActive('es_extended') then
            return 'esx'
        end

        return nil
    end

    for i = 1, #INVENTORY_RESOURCES do
        local entry = INVENTORY_RESOURCES[i]

        if isResourceActive(entry.resource) then
            return entry.inventory
        end
    end

    return nil
end

---@return 'ox_inventory'|'qb-inventory'|'esx'|nil
function AutoGlovebox.AutoDetect.Inventory()
    if not isAutoInventory() then
        return Config.Inventory
    end

    return detectInventoryForFramework(AutoGlovebox.AutoDetect.Framework())
end

---@param force boolean|nil
---@return table resolved
function AutoGlovebox.AutoDetect.Resolve(force)
    if resolved and not force then
        return resolved
    end

    local frameworkConfig = getFrameworkConfigLabel()
    local inventoryConfig = getInventoryConfigLabel()
    local framework = AutoGlovebox.AutoDetect.Framework()
    local inventory = AutoGlovebox.AutoDetect.Inventory()
    local valid = true
    local errorMessage

    if inventory then
        valid, errorMessage = validateCombination(framework, inventory)
    else
        valid = false
        errorMessage = 'Kein unterstütztes Inventarsystem gefunden'
    end

    resolved = {
        frameworkConfig = frameworkConfig,
        inventoryConfig = inventoryConfig,
        framework = framework,
        inventory = inventory,
        valid = valid,
        error = errorMessage,
    }

    return resolved
end

---@return table
function AutoGlovebox.AutoDetect.GetResolved()
    return AutoGlovebox.AutoDetect.Resolve(false)
end

---@return boolean
function AutoGlovebox.AutoDetect.IsDependencyResource(resourceName)
    for i = 1, #FRAMEWORK_RESOURCES do
        if FRAMEWORK_RESOURCES[i].resource == resourceName then
            return true
        end
    end

    for i = 1, #INVENTORY_RESOURCES do
        if INVENTORY_RESOURCES[i].resource == resourceName then
            return true
        end
    end

    return false
end

---@return string
function AutoGlovebox.AutoDetect.FormatResolved()
    local info = AutoGlovebox.AutoDetect.GetResolved()

    return ('Framework: %s (%s) | Inventar: %s (%s)'):format(
        info.framework,
        info.frameworkConfig,
        info.inventory or 'keins',
        info.inventoryConfig
    )
end

-- Abwärtskompatibilität
function AutoGlovebox.DetectFramework()
    return AutoGlovebox.AutoDetect.Framework()
end

function AutoGlovebox.DetectInventory()
    return AutoGlovebox.AutoDetect.Inventory()
end
