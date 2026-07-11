Lockers = Lockers or {}
Lockers.Security = Lockers.Security or {}

local sessions = {}
local rateLimits = {}
local pinAttempts = {}
local processedRequests = {}

---@param length number
---@return string
function Lockers.Security.RandomString(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}

    for i = 1, length do
        local index = math.random(1, #chars)
        result[i] = chars:sub(index, index)
    end

    return table.concat(result)
end

---@param source number
---@return boolean
function Lockers.Security.CheckRateLimit(source)
    local now = GetGameTimer()
    local entry = rateLimits[source]

    if not entry then
        rateLimits[source] = { count = 1, reset = now + 1000 }
        return true
    end

    if now > entry.reset then
        rateLimits[source] = { count = 1, reset = now + 1000 }
        return true
    end

    entry.count = entry.count + 1
    return entry.count <= (Config.Security.rateLimit or 8)
end

---@param source number
---@param requestId string|nil
---@return boolean
function Lockers.Security.CheckRequestId(source, requestId)
    if not requestId or requestId == '' then
        return true
    end

    local key = ('%s:%s'):format(source, requestId)
    local now = os.time()

    if processedRequests[key] and processedRequests[key] > now then
        return false
    end

    processedRequests[key] = now + (Config.Security.requestIdTTL or 30)
    return true
end

---@param source number
---@param vehicleNetId number
---@return boolean
function Lockers.Security.IsPlayerNearVehicle(source, vehicleNetId)
    if not vehicleNetId or type(vehicleNetId) ~= 'number' then
        return false
    end

    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return false
    end

    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(entity)
    local maxDistance = Config.Security.maxDistance or 3.5

    return Lockers.Distance(playerCoords, vehicleCoords) <= maxDistance
end

---@param source number
---@param locker table
---@param vehicleNetId number
---@return boolean
function Lockers.Security.VehicleMatchesLocker(source, locker, vehicleNetId)
    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not entity or entity == 0 then
        return false
    end

    local plate = GetVehicleNumberPlateText(entity)
    local modelHash = GetEntityModel(entity)

    return Lockers.VehicleMatchesLocker(locker, modelHash, plate)
end

---@param source number
---@param lockerId number
---@param vehicleNetId number
---@return table|nil
function Lockers.Security.CreateSession(source, lockerId, vehicleNetId)
    local locker = Lockers.DB.GetLocker(lockerId)

    if not locker then
        return nil
    end

    local token = Lockers.Security.RandomString(48)
    local expires = os.time() + (Config.Security.sessionTTL or 300)

    sessions[source] = sessions[source] or {}
    sessions[source][token] = {
        lockerId = lockerId,
        vehicleNetId = vehicleNetId,
        expires = expires,
        authenticated = false,
        pinVerified = false,
        keyVerified = false,
        createdAt = os.time(),
    }

    return {
        token = token,
        expires = expires,
        access_mode = locker.access_mode,
        requires_pin = locker.access_mode == 'pin_only'
            or locker.access_mode == 'pin_or_key'
            or locker.access_mode == 'pin_and_key',
        requires_key = locker.access_mode == 'key_only'
            or locker.access_mode == 'pin_or_key'
            or locker.access_mode == 'pin_and_key',
        name = locker.name,
        description = locker.description,
    }
end

---@param source number
---@param token string
---@return table|nil
function Lockers.Security.GetSession(source, token)
    local playerSessions = sessions[source]

    if not playerSessions then
        return nil
    end

    local session = playerSessions[token]

    if not session or session.expires < os.time() then
        if session then
            playerSessions[token] = nil
        end

        return nil
    end

    local locker = Lockers.DB.GetLocker(session.lockerId)

    if not locker
        or not session.vehicleNetId
        or not Lockers.Security.IsPlayerNearVehicle(source, session.vehicleNetId)
        or not Lockers.Security.VehicleMatchesLocker(source, locker, session.vehicleNetId) then
        playerSessions[token] = nil
        return nil
    end

    local entity = NetworkGetEntityFromNetworkId(session.vehicleNetId)

    if not Lockers.IsTrunkOpen(entity) then
        playerSessions[token] = nil
        return nil
    end

    return session, locker
end

---@param source number
---@param token string
---@return boolean
function Lockers.Security.IsSessionAuthenticated(source, token)
    local session, locker = Lockers.Security.GetSession(source, token)

    if not session or not locker then
        return false
    end

    if locker.access_mode == 'job_only' or locker.access_mode == 'identifier_only' then
        return session.authenticated
    end

    if locker.access_mode == 'pin_only' then
        return session.pinVerified
    end

    if locker.access_mode == 'key_only' then
        return session.keyVerified
    end

    if locker.access_mode == 'pin_or_key' then
        return session.pinVerified or session.keyVerified
    end

    if locker.access_mode == 'pin_and_key' then
        return session.pinVerified and session.keyVerified
    end

    return session.authenticated
end

---@param source number
---@param lockerId number
---@return boolean locked
---@return number|nil remaining
function Lockers.Security.GetPinLockout(source, lockerId)
    local key = ('%s:%s'):format(source, lockerId)
    local entry = pinAttempts[key]

    if not entry then
        return false
    end

    if entry.lockedUntil and entry.lockedUntil > os.time() then
        return true, entry.lockedUntil - os.time()
    end

    if entry.lockedUntil and entry.lockedUntil <= os.time() then
        pinAttempts[key] = { count = 0 }
    end

    return false
end

---@param source number
---@param lockerId number
---@param success boolean
---@return boolean locked
---@return number|nil remaining
---@return number|nil attemptsLeft
function Lockers.Security.RegisterPinAttempt(source, lockerId, success)
    local key = ('%s:%s'):format(source, lockerId)
    local entry = pinAttempts[key] or { count = 0 }

    if success then
        pinAttempts[key] = { count = 0 }
        return false
    end

    entry.count = entry.count + 1
    local maxAttempts = Config.Security.pinMaxAttempts or 5

    if entry.count >= maxAttempts then
        entry.lockedUntil = os.time() + (Config.Security.pinLockoutTime or 300)
        entry.count = 0
        pinAttempts[key] = entry

        if Config.Security.pinAlarm then
            local player = Lockers.Framework.GetPlayer(source)
            Lockers.DB.Log(lockerId, player and player.identifier or 'unknown', player and player.name or 'Unknown', 'pin_lockout', nil, entry.count, nil)
        end

        return true, entry.lockedUntil - os.time()
    end

    pinAttempts[key] = entry
    return false, nil, maxAttempts - entry.count
end

function Lockers.Security.DestroySession(source, token)
    if sessions[source] then
        sessions[source][token] = nil
    end
end

function Lockers.Security.DestroyPlayerSessions(source)
    sessions[source] = nil
    rateLimits[source] = nil
end

AddEventHandler('playerDropped', function()
    Lockers.Security.DestroyPlayerSessions(source)
end)

---@param player table
---@param locker table
---@return boolean
function Lockers.Security.CanAccessLocker(player, locker)
    if not locker.enabled then
        return false
    end

    if locker.minimum_grade and player.grade < locker.minimum_grade then
        return false
    end

    if not Lockers.HasJobAccess(locker.allowed_jobs, player.job, player.grade) then
        return false
    end

    if not Lockers.HasIdentifierAccess(locker.allowed_identifiers, player.citizenid)
        and not Lockers.HasIdentifierAccess(locker.allowed_identifiers, player.identifier) then
        return false
    end

    if locker.access_mode == 'identifier_only' then
        return Lockers.HasIdentifierAccess(locker.allowed_identifiers, player.citizenid)
            or Lockers.HasIdentifierAccess(locker.allowed_identifiers, player.identifier)
    end

    if locker.access_mode == 'job_only' then
        return Lockers.HasJobAccess(locker.allowed_jobs, player.job, player.grade)
    end

    return true
end

---@param data table
function Lockers.Security.SendDiscordLog(data)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then
        return
    end

    local action = data.action

    if Config.Discord.logActions and Config.Discord.logActions[action] == false then
        return
    end

    local embed = {
        {
            title = 'Schließfach-Log',
            color = action == 'suspicious' and 16711680 or 16744448,
            fields = {
                { name = 'Spieler', value = data.player_name or 'Unbekannt', inline = true },
                { name = 'Identifier', value = data.player_identifier or 'n/a', inline = true },
                { name = 'Schließfach', value = tostring(data.locker_id or 'n/a'), inline = true },
                { name = 'Aktion', value = action or 'n/a', inline = true },
                { name = 'Item', value = data.item_name or '-', inline = true },
                { name = 'Menge', value = tostring(data.amount or '-'), inline = true },
            },
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        },
    }

    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.botName,
        avatar_url = Config.Discord.avatar ~= '' and Config.Discord.avatar or nil,
        embeds = embed,
    }), { ['Content-Type'] = 'application/json' })
end

function Lockers.Security.LogSuspicious(source, action, details)
    local player = Lockers.Framework.GetPlayer(source)
    Lockers.DB.Log(nil, player and player.identifier or 'unknown', player and player.name or GetPlayerName(source), 'suspicious', action, nil, details)
    Lockers.Security.SendDiscordLog({
        player_name = player and player.name or GetPlayerName(source),
        player_identifier = player and player.identifier,
        locker_id = details and details.locker_id,
        action = 'suspicious',
        item_name = action,
        amount = nil,
    })
end
