Lockers = Lockers or {}
Lockers.Framework = Lockers.Framework or {}

local resolved
local ESX
local QBCore

local FRAMEWORK_RESOURCES = {
    { resource = 'qbx_core', framework = 'qb' },
    { resource = 'qb-core', framework = 'qb' },
    { resource = 'es_extended', framework = 'esx' },
}

local TARGET_RESOURCES = {
    { resource = 'ox_target', target = 'ox_target' },
    { resource = 'qb-target', target = 'qb-target' },
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

---@return boolean
local function isAutoFramework()
    return Config.Auto and Config.Auto.Framework == true or Config.Framework == 'auto'
end

---@return boolean
local function isAutoTarget()
    return Config.Auto and Config.Auto.Target == true or Config.Target == 'auto'
end

---@return boolean
local function isAutoInventory()
    return Config.Auto and Config.Auto.Inventory == true or Config.Inventory == 'auto'
end

---@return 'qb'|'esx'|'standalone'
function Lockers.Framework.Detect()
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

---@return 'ox_target'|'qb-target'|nil
function Lockers.Framework.DetectTarget()
    if not isAutoTarget() then
        return Config.Target
    end

    for i = 1, #TARGET_RESOURCES do
        local entry = TARGET_RESOURCES[i]

        if isResourceActive(entry.resource) then
            return entry.target
        end
    end

    return nil
end

---@return 'ox_inventory'|'qb-inventory'|nil
function Lockers.Framework.DetectInventory()
    if not isAutoInventory() then
        return Config.Inventory
    end

    for i = 1, #INVENTORY_RESOURCES do
        local entry = INVENTORY_RESOURCES[i]

        if isResourceActive(entry.resource) then
            return entry.inventory
        end
    end

    return nil
end

---@param force boolean|nil
---@return table
function Lockers.Framework.Resolve(force)
    if resolved and not force then
        return resolved
    end

    resolved = {
        framework = Lockers.Framework.Detect(),
        target = Lockers.Framework.DetectTarget(),
        inventory = Lockers.Framework.DetectInventory(),
    }

    return resolved
end

---@return table
function Lockers.Framework.GetResolved()
    return Lockers.Framework.Resolve(false)
end

function Lockers.Framework.Init()
    local info = Lockers.Framework.Resolve(true)

    if info.framework == 'esx' and isResourceActive('es_extended') then
        ESX = exports['es_extended']:getSharedObject()
    elseif info.framework == 'qb' then
        if isResourceActive('qbx_core') then
            QBCore = exports['qbx_core']:GetCoreObject()
        elseif isResourceActive('qb-core') then
            QBCore = exports['qb-core']:GetCoreObject()
        end
    end

    Lockers.Debug(('Framework: %s | Target: %s | Inventory: %s'):format(
        info.framework,
        info.target or 'keins',
        info.inventory or 'keins'
    ))
end

---@param source number
---@return table|nil
function Lockers.Framework.GetPlayer(source)
    local info = Lockers.Framework.GetResolved()

    if info.framework == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)

        if not xPlayer then
            return nil
        end

        return {
            source = source,
            identifier = xPlayer.getIdentifier(),
            citizenid = xPlayer.getIdentifier(),
            name = xPlayer.getName(),
            job = xPlayer.job.name,
            grade = xPlayer.job.grade,
            group = xPlayer.getGroup and xPlayer.getGroup() or 'user',
        }
    end

    if info.framework == 'qb' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)

        if not player then
            return nil
        end

        return {
            source = source,
            identifier = player.PlayerData.license or player.PlayerData.citizenid,
            citizenid = player.PlayerData.citizenid,
            name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname),
            job = player.PlayerData.job.name,
            grade = player.PlayerData.job.grade.level,
            group = QBCore.Functions.GetPermission(source) and 'admin' or player.PlayerData.group or 'user',
        }
    end

  local identifiers = GetPlayerIdentifiers(source)
    local license

    for i = 1, #identifiers do
        if identifiers[i]:find('license:') then
            license = identifiers[i]
            break
        end
    end

    return {
        source = source,
        identifier = license or ('source:%s'):format(source),
        citizenid = license or ('source:%s'):format(source),
        name = GetPlayerName(source) or 'Unknown',
        job = 'unemployed',
        grade = 0,
        group = 'user',
    }
end

---@param source number
---@return boolean
function Lockers.Framework.IsAdmin(source)
    if source == 0 then
        return true
    end

    if IsPlayerAceAllowed(source, Config.Admin.permission) then
        return true
    end

    local player = Lockers.Framework.GetPlayer(source)

    if not player then
        return false
    end

    local info = Lockers.Framework.GetResolved()
    local groups = Config.Admin.groups[info.framework] or {}

    for i = 1, #groups do
        if player.group == groups[i] then
            return true
        end
    end

    if info.framework == 'qb' and QBCore then
        return QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')
    end

    if info.framework == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and (xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin')
    end

    return false
end

---@param resourceName string
---@return boolean
function Lockers.Framework.IsDependencyResource(resourceName)
    for i = 1, #FRAMEWORK_RESOURCES do
        if FRAMEWORK_RESOURCES[i].resource == resourceName then
            return true
        end
    end

    for i = 1, #TARGET_RESOURCES do
        if TARGET_RESOURCES[i].resource == resourceName then
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
