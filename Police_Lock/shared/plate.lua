---@param plate string
---@return string[]
function AutoGlovebox.GetPlateVariants(plate)
    local normalized = AutoGlovebox.NormalizePlate(plate)
    local compact = normalized:gsub('%s+', '')

    return {
        normalized,
        compact,
        plate,
    }
end

---@param variants string[]
---@return string[]
function AutoGlovebox.UniquePlateVariants(variants)
    local seen = {}
    local result = {}

    for i = 1, #variants do
        local value = variants[i]

        if value and value ~= '' and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end

    return result
end
