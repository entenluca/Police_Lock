Lockers = Lockers or {}

---@param key string
---@param ... any
---@return string
function Lockers.L(key, ...)
    local locale = Locales and Locales[Config.Locale] or Locales and Locales['en'] or {}
    local str = locale[key] or key

    if select('#', ...) > 0 then
        return str:format(...)
    end

    return str
end

---@param data any
---@return string|nil
function Lockers.EncodeJSON(data)
    if data == nil then
        return nil
    end

    local ok, encoded = pcall(json.encode, data)

    if ok and encoded then
        return encoded
    end

    return nil
end

---@param raw string|nil
---@return table
function Lockers.DecodeJSON(raw)
    if not raw or raw == '' or raw == 'null' then
        return {}
    end

    local ok, decoded = pcall(json.decode, raw)

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

---@param coords table|string
---@return vector3|nil
function Lockers.ParseCoords(coords)
    if type(coords) == 'vector3' then
        return coords
    end

    if type(coords) == 'table' then
        return vector3(coords.x or coords[1] or 0.0, coords.y or coords[2] or 0.0, coords.z or coords[3] or 0.0)
    end

    if type(coords) == 'string' then
        local decoded = Lockers.DecodeJSON(coords)

        if decoded.x then
            return vector3(decoded.x, decoded.y, decoded.z)
        end
    end

    return nil
end

---@param value vector3|table
---@return table
function Lockers.CoordsToTable(value)
    if type(value) == 'vector3' then
        return { x = value.x, y = value.y, z = value.z }
    end

    return {
        x = value.x or 0.0,
        y = value.y or 0.0,
        z = value.z or 0.0,
        h = value.h or value.w or 0.0,
    }
end

---@param a vector3
---@param b vector3
---@return number
function Lockers.Distance(a, b)
    return #(a - b)
end

---@param jobs table|nil
---@param jobName string
---@param grade number
---@return boolean
function Lockers.HasJobAccess(jobs, jobName, grade)
    if not jobs or not next(jobs) then
        return true
    end

    local required = jobs[jobName]

    if required == nil then
        return false
    end

    return grade >= tonumber(required) or 0
end

---@param identifiers table|nil
---@param playerIdentifier string
---@return boolean
function Lockers.HasIdentifierAccess(identifiers, playerIdentifier)
    if not identifiers or #identifiers == 0 then
        return true
    end

    for i = 1, #identifiers do
        if identifiers[i] == playerIdentifier then
            return true
        end
    end

    return false
end

---@param mode string
---@return boolean
function Lockers.IsValidAccessMode(mode)
    return mode == 'pin_only'
        or mode == 'key_only'
        or mode == 'pin_or_key'
        or mode == 'pin_and_key'
        or mode == 'job_only'
        or mode == 'identifier_only'
end

function Lockers.Debug(...)
    if Config.Debug then
        print('^3[Police_Lock]^7', ...)
    end
end

---@param vehicle number
---@return boolean
function Lockers.IsTrunkOpen(vehicle)
    if not vehicle or vehicle == 0 or GetEntityType(vehicle) ~= 2 then
        return false
    end

    local doorIndices = Config.Vehicle and Config.Vehicle.trunkDoorIndices or { 5 }
    local threshold = Config.Vehicle and Config.Vehicle.trunkOpenThreshold or 0.05

    for i = 1, #doorIndices do
        local door = doorIndices[i]

        if GetVehicleDoorAngleRatio(vehicle, door) > threshold then
            return true
        end

        if IsVehicleDoorFullyOpen(vehicle, door) then
            return true
        end
    end

    return false
end

---@param key string
---@return number|nil
function Lockers.ResolveVehicleHash(key)
    if not key or key == '' then
        return nil
    end

    local numeric = tonumber(key)

    if numeric then
        return numeric
    end

    return joaat(key:lower())
end

---@param vehicle number
---@return string
function Lockers.GetVehicleKeyFromEntity(vehicle)
    return tostring(GetEntityModel(vehicle))
end

---@param plate string
---@return string
function Lockers.NormalizePlate(plate)
    if not plate then
        return ''
    end

    return plate:gsub('%s+', ''):upper()
end

---@param modelHash number
---@return string
function Lockers.GetModelName(modelHash)
    if not modelHash or modelHash == 0 then
        return 'unknown'
    end

    local name = GetDisplayNameFromVehicleModel(modelHash)

    if name and name ~= 'CARNOTFOUND' then
        return string.lower(name)
    end

    return tostring(modelHash)
end

---@param matchType string
---@return boolean
function Lockers.IsValidVehicleMatchType(matchType)
    return matchType == 'model' or matchType == 'plate'
end

---@param locker table
---@param modelHash number
---@param plate string
---@return boolean
function Lockers.VehicleMatchesLocker(locker, modelHash, plate)
    if not locker or not locker.vehicle_match_type or not locker.vehicle_key then
        return false
    end

    if locker.vehicle_match_type == 'plate' then
        return Lockers.NormalizePlate(locker.vehicle_key) == Lockers.NormalizePlate(plate)
    end

    if locker.vehicle_match_type == 'model' then
        local hash = Lockers.ResolveVehicleHash(locker.vehicle_key)
        return hash ~= nil and hash == modelHash
    end

    return false
end

---@param lockers table
---@param modelHash number
---@param plate string
---@return number|nil
function Lockers.FindLockerForVehicle(lockers, modelHash, plate)
    local modelMatch

    for id, locker in pairs(lockers) do
        if locker.enabled and locker.vehicle_match_type == 'plate'
            and Lockers.VehicleMatchesLocker(locker, modelHash, plate) then
            return id
        end
    end

    for id, locker in pairs(lockers) do
        if locker.enabled and locker.vehicle_match_type == 'model'
            and Lockers.VehicleMatchesLocker(locker, modelHash, plate) then
            modelMatch = id
            break
        end
    end

    return modelMatch
end

---@return table
function Lockers.GetAccessModes()
    return {
        { value = 'pin_only', label = Lockers.L('access_pin_only') },
        { value = 'key_only', label = Lockers.L('access_key_only') },
        { value = 'pin_or_key', label = Lockers.L('access_pin_or_key') },
        { value = 'pin_and_key', label = Lockers.L('access_pin_and_key') },
        { value = 'job_only', label = Lockers.L('access_job_only') },
        { value = 'identifier_only', label = Lockers.L('access_identifier_only') },
    }
end

---@return table
function Lockers.GetVehicleMatchTypes()
    return {
        { value = 'model', label = Lockers.L('vehicle_match_model') },
        { value = 'plate', label = Lockers.L('vehicle_match_plate') },
    }
end
