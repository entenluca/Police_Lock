Lockers = Lockers or {}
Lockers.Inventory = Lockers.Inventory or {}

local adapter

local function getItemLabel(itemName)
    local info = Lockers.Framework.GetResolved()

    if info.inventory == 'ox_inventory' then
        local item = exports.ox_inventory:Items(itemName)
        return item and item.label or itemName
    end

    if info.framework == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local shared = QBCore.Shared.Items[itemName]
        return shared and shared.label or itemName
    end

    return itemName
end

local function getItemWeight(itemName)
    local info = Lockers.Framework.GetResolved()

    if info.inventory == 'ox_inventory' then
        local item = exports.ox_inventory:Items(itemName)
        return item and item.weight or 0
    end

    if info.framework == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local shared = QBCore.Shared.Items[itemName]
        return shared and shared.weight or 0
    end

    return 0
end

function Lockers.Inventory.Init()
    local info = Lockers.Framework.GetResolved()
    adapter = info.inventory
    Lockers.Debug('Inventar-Adapter: ' .. tostring(adapter))
end

---@param source number
---@param itemName string
---@return number
function Lockers.Inventory.GetCount(source, itemName)
    if adapter == 'ox_inventory' then
        return exports.ox_inventory:GetItemCount(source, itemName) or 0
    end

    if adapter == 'qb-inventory' then
        local player = Lockers.Framework.GetPlayer(source)

        if not player then
            return 0
        end

        local QBCore = exports['qb-core']:GetCoreObject()
        local item = QBCore.Functions.GetPlayer(source).Functions.GetItemByName(itemName)
        return item and item.amount or 0
    end

    return 0
end

---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
function Lockers.Inventory.CanCarry(source, itemName, amount, metadata)
    if adapter == 'ox_inventory' then
        return exports.ox_inventory:CanCarryItem(source, itemName, amount, metadata)
    end

    if adapter == 'qb-inventory' then
        return true
    end

    return true
end

---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
function Lockers.Inventory.AddItem(source, itemName, amount, metadata)
    if adapter == 'ox_inventory' then
        return exports.ox_inventory:AddItem(source, itemName, amount, metadata) ~= false
    end

    if adapter == 'qb-inventory' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayer(source).Functions.AddItem(itemName, amount, false, metadata)
    end

    return false
end

---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
function Lockers.Inventory.RemoveItem(source, itemName, amount, metadata)
    if adapter == 'ox_inventory' then
        return exports.ox_inventory:RemoveItem(source, itemName, amount, metadata)
    end

    if adapter == 'qb-inventory' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayer(source).Functions.RemoveItem(itemName, amount, false, metadata)
    end

    return false
end

---@param source number
---@param keyItem string
---@param keyMetadata table|nil
---@param lockerId number
---@return boolean found
---@return table|nil slotMetadata
function Lockers.Inventory.HasKey(source, keyItem, keyMetadata, lockerId)
    if not keyItem or keyItem == '' then
        return false
    end

    if adapter == 'ox_inventory' then
        local items = exports.ox_inventory:Search(source, 'slots', keyItem) or {}

        for i = 1, #items do
            local slot = items[i]
            local meta = slot.metadata or {}

            if keyMetadata and keyMetadata.universal then
                return true, meta
            end

            if meta.locker_id and tonumber(meta.locker_id) == lockerId then
                return true, meta
            end

            if not meta.locker_id and (not keyMetadata or not keyMetadata.locker_id) then
                return true, meta
            end

            if keyMetadata and keyMetadata.locker_id and tonumber(keyMetadata.locker_id) == lockerId then
                return true, meta
            end
        end

        return false
    end

    if adapter == 'qb-inventory' then
        local count = Lockers.Inventory.GetCount(source, keyItem)
        return count > 0, {}
    end

    return false
end

---@param source number
---@param item table
---@param player table
---@return table
function Lockers.Inventory.BuildClientItem(source, item, player)
    local label = item.display_name or getItemLabel(item.item_name)
    local image = item.image or (Config.NUI.imageBase .. item.item_name .. '.png')
    local allowed = Lockers.HasJobAccess(item.allowed_jobs, player.job, player.grade)
        and player.grade >= (item.minimum_grade or 0)

    return {
        id = item.id,
        item_name = item.item_name,
        display_name = label,
        description = item.description or '',
        image = image,
        amount = item.unlimited and -1 or item.amount,
        maximum_take_amount = item.maximum_take_amount,
        minimum_grade = item.minimum_grade,
        weight = getItemWeight(item.item_name),
        player_amount = Lockers.Inventory.GetCount(source, item.item_name),
        returnable = item.returnable,
        unlimited = item.unlimited,
        allowed = allowed,
        rank_label = Lockers.L('rank_required', item.minimum_grade),
    }
end

function Lockers.Inventory.GenerateSerial()
    return ('LK%s%s'):format(os.time(), Lockers.Security.RandomString(6)):upper()
end
