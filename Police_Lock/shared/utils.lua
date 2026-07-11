---@param entry table
---@return 'once'|'always', table
function AutoGlovebox.ParseVehicleEntry(entry)
    if not entry then
        return Config.AddMode, {}
    end

    if entry[1] and type(entry[1]) == 'table' and entry[1].item then
        return Config.AddMode, entry
    end

    if entry.items then
        return entry.addMode or Config.AddMode, entry.items
    end

    return Config.AddMode, {}
end

---@param plate string
---@return string
function AutoGlovebox.NormalizePlate(plate)
    if not plate then
        return ''
    end

    return plate:gsub('^%s+', ''):gsub('%s+$', '')
end

---@param addMode string
---@return boolean
function AutoGlovebox.IsValidAddMode(addMode)
    return addMode == 'once' or addMode == 'always'
end

---@param storageType string|nil
---@return boolean
function AutoGlovebox.IsValidStorageType(storageType)
    return storageType == 'glovebox' or storageType == 'trunk'
end

---@param storageType string|nil
---@return 'glovebox'|'trunk'
function AutoGlovebox.NormalizeStorageType(storageType)
    if storageType == 'trunk' then
        return 'trunk'
    end

    return 'glovebox'
end

---@param storageType 'glovebox'|'trunk'
---@return string
function AutoGlovebox.GetStorageLabel(storageType)
    if storageType == 'trunk' then
        return 'Kofferraum'
    end

    return 'Handschuhfach'
end
