local clientCache = {
    modelHashes = {},
    plates = {},
}

---@param cache table|nil
function AutoGlovebox.SetClientCache(cache)
    clientCache = cache or {
        modelHashes = {},
        plates = {},
    }
end

---@return table
function AutoGlovebox.GetClientCache()
    return clientCache
end

local function refreshClientCache()
    local cache = lib.callback.await('autoglovebox:server:getClientCache', false)

    if cache then
        AutoGlovebox.SetClientCache(cache)
    end
end

---@param vehicle number
---@return boolean
function AutoGlovebox.IsConfiguredVehicle(vehicle)
    local plate = AutoGlovebox.NormalizePlate(GetVehicleNumberPlateText(vehicle))
    local modelHash = GetEntityModel(vehicle)

    for i = 1, #clientCache.plates do
        if clientCache.plates[i] == plate then
            return true
        end
    end

    for i = 1, #clientCache.modelHashes do
        if clientCache.modelHashes[i] == modelHash then
            return true
        end
    end

    return false
end

RegisterNetEvent('autoglovebox:client:syncCache', function(cache)
    AutoGlovebox.SetClientCache(cache)
end)

CreateThread(function()
    Wait(1000)
    refreshClientCache()
end)

RegisterNetEvent('esx:playerLoaded', refreshClientCache)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshClientCache)

exports('RefreshCache', refreshClientCache)
