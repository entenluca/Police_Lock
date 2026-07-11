Lockers = Lockers or {}
Lockers.Framework = Lockers.Framework or {}

local ESX

function Lockers.Framework.Init()
    if GetResourceState('es_extended') ~= 'started' then
        print('^1[Police_Lock]^7 es_extended ist nicht gestartet')
        return false
    end

    ESX = exports['es_extended']:getSharedObject()
    Lockers.Debug('Framework: ESX | Inventar: ox_inventory | Target: ox_target')
    return true
end

---@param source number
---@return table|nil
function Lockers.Framework.GetPlayer(source)
    if not ESX then
        return nil
    end

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

---@param source number
---@return boolean
function Lockers.Framework.IsAdmin(source)
    if source == 0 then
        return true
    end

    if IsPlayerAceAllowed(source, Config.Admin.permission) then
        return true
    end

    if not ESX then
        return false
    end

    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return false
    end

    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    local groups = Config.Admin.groups or {}

    for i = 1, #groups do
        if group == groups[i] then
            return true
        end
    end

    return group == 'admin' or group == 'superadmin'
end

---@param resourceName string
---@return boolean
function Lockers.Framework.IsDependencyResource(resourceName)
    return resourceName == 'es_extended'
        or resourceName == 'ox_inventory'
        or resourceName == 'ox_target'
end
