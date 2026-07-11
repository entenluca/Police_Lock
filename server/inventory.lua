Lockers = Lockers or {}
Lockers.Inventory = Lockers.Inventory or {}

local STASH_PREFIX = 'police_lock_'
local UNLIMITED_DISPLAY_AMOUNT = 9999

local activeOpens = {}
local hooksRegistered = false
local swapHookId

local function getItemLabel(itemName)
    local item = exports.ox_inventory:Items(itemName)
    return item and item.label or itemName
end

local function getItemWeight(itemName)
    local item = exports.ox_inventory:Items(itemName)
    return item and item.weight or 0
end

---@param lockerItem table|string
---@return string
function Lockers.Inventory.GetItemLabel(lockerItem)
    if type(lockerItem) == 'string' then
        return getItemLabel(lockerItem)
    end

    if type(lockerItem) == 'table' then
        if lockerItem.display_name and lockerItem.display_name ~= '' then
            return lockerItem.display_name
        end

        if lockerItem.item_name then
            return getItemLabel(lockerItem.item_name)
        end
    end

    return tostring(lockerItem)
end

local function notifyPlayer(source, message, ntype)
    TriggerClientEvent('ox_lib:notify', source, {
        title = Lockers.L('locker_title'),
        description = message,
        type = ntype or 'inform',
    })
end

---@param lockerId number
---@return string
function Lockers.Inventory.GetStashId(lockerId)
    return ('%s%s'):format(STASH_PREFIX, lockerId)
end

---@param stashId string|number|nil
---@return number|nil
function Lockers.Inventory.ParseLockerId(stashId)
    if type(stashId) ~= 'string' then
        return nil
    end

    local lockerId = stashId:match(('^%s(%d+)$'):format(STASH_PREFIX))

    return lockerId and tonumber(lockerId) or nil
end

---@param inv string|number|table|nil
---@return string|nil
local function resolveInventoryId(inv)
    if type(inv) == 'string' then
        return inv
    end

    if type(inv) == 'table' and inv.id then
        return inv.id
    end

    return nil
end

---@param source number
---@return table|nil
function Lockers.Inventory.GetActiveOpen(source)
    return activeOpens[source]
end

---@param source number
---@param lockerId number
---@param token string
function Lockers.Inventory.SetActiveOpen(source, lockerId, token)
    activeOpens[source] = {
        lockerId = lockerId,
        token = token,
    }
end

---@param source number
function Lockers.Inventory.ClearActiveOpen(source)
    activeOpens[source] = nil
end

---@param locker table
function Lockers.Inventory.RegisterLockerStash(locker)
    if not locker or not locker.id then
        return
    end

    local stashId = Lockers.Inventory.GetStashId(locker.id)

    exports.ox_inventory:RegisterStash(
        stashId,
        locker.name or ('Locker %s'):format(locker.id),
        locker.slots or 50,
        locker.max_weight or 100000,
        false
    )
end

function Lockers.Inventory.RegisterAllStashes()
    local lockers = Lockers.DB.GetLockers()

    for _, locker in pairs(lockers) do
        Lockers.Inventory.RegisterLockerStash(locker)
    end
end

---@param lockerItem table
---@return table
local function buildStashMetadata(lockerItem)
    local metadata = lockerItem.metadata and json.decode(json.encode(lockerItem.metadata)) or {}
    metadata.locker_item_id = lockerItem.id
    metadata.locker_id = lockerItem.locker_id
    return metadata
end

---@param lockerId number
function Lockers.Inventory.SyncStashFromDB(lockerId)
    local locker = Lockers.DB.GetLocker(lockerId)

    if not locker then
        return
    end

    local stashId = Lockers.Inventory.GetStashId(lockerId)
    Lockers.Inventory.RegisterLockerStash(locker)

    exports.ox_inventory:GetInventory(stashId, false)
    exports.ox_inventory:ClearInventory(stashId)

    local items = Lockers.DB.GetItems(lockerId)

    for i = 1, #items do
        local item = items[i]
        local count = item.unlimited and UNLIMITED_DISPLAY_AMOUNT or item.amount

        if count > 0 then
            exports.ox_inventory:AddItem(stashId, item.item_name, count, buildStashMetadata(item))
        end
    end
end

---@param lockerId number
function Lockers.Inventory.SyncDBFromStash(lockerId)
    local stashId = Lockers.Inventory.GetStashId(lockerId)
    local stashItems = exports.ox_inventory:GetInventoryItems(stashId, false) or {}
    local countsByItemId = {}

    for _, item in pairs(stashItems) do
        local itemId = item.metadata and tonumber(item.metadata.locker_item_id)

        if itemId then
            countsByItemId[itemId] = (countsByItemId[itemId] or 0) + (item.count or 0)
        end
    end

    local lockerItems = Lockers.DB.GetItems(lockerId)

    for i = 1, #lockerItems do
        local lockerItem = lockerItems[i]

        if not lockerItem.unlimited then
            local count = countsByItemId[lockerItem.id] or 0

            if count ~= lockerItem.amount then
                Lockers.DB.UpdateItemAmount(lockerItem.id, count)
            end
        end
    end
end

---@param source number
---@param locker table
---@param token string
---@return boolean
function Lockers.Inventory.OpenForPlayer(source, locker, token)
    if not Lockers.Security.IsSessionAuthenticated(source, token) then
        return false
    end

    Lockers.Inventory.SyncStashFromDB(locker.id)
    Lockers.Inventory.SetActiveOpen(source, locker.id, token)

    local stashId = Lockers.Inventory.GetStashId(locker.id)
    exports.ox_inventory:forceOpenInventory(source, 'stash', stashId)

    return true
end

---@param source number
---@param lockerItem table
---@param count number
---@param toSlot table|number|nil
local function applyTakeMetadata(source, lockerItem, count, toSlot)
    local metadata = {}

    if lockerItem.metadata and lockerItem.metadata.registered then
        metadata.registered = true
        metadata.serial = Lockers.Inventory.GenerateSerial()
    end

    if lockerItem.personal_bind then
        local player = Lockers.Framework.GetPlayer(source)

        if player then
            metadata.owner = player.citizenid
        end
    end

    if next(metadata) == nil then
        return
    end

    if type(toSlot) == 'table' and toSlot.slot then
        local slotMetadata = toSlot.metadata or {}

        for key, value in pairs(metadata) do
            slotMetadata[key] = value
        end

        exports.ox_inventory:SetMetadata(source, toSlot.slot, slotMetadata)
        return
    end

    local playerItems = exports.ox_inventory:GetInventoryItems(source) or {}

    for _, slot in pairs(playerItems) do
        if slot.name == lockerItem.item_name and slot.count >= count then
            local slotMetadata = slot.metadata or {}

            for key, value in pairs(metadata) do
                slotMetadata[key] = value
            end

            exports.ox_inventory:SetMetadata(source, slot.slot, slotMetadata)
            break
        end
    end
end

---@param source number
---@param lockerId number
---@param lockerItem table
---@param count number
---@param toSlot table|number|nil
local function handleTakeSuccess(source, lockerId, lockerItem, count, toSlot)
    local player = Lockers.Framework.GetPlayer(source)

    if not player then
        return
    end

    if not lockerItem.unlimited then
        Lockers.DB.UpdateItemAmount(lockerItem.id, math.max(lockerItem.amount - count, 0))
    else
        local stashId = Lockers.Inventory.GetStashId(lockerId)
        exports.ox_inventory:AddItem(stashId, lockerItem.item_name, count, buildStashMetadata(lockerItem))
    end

    if lockerItem.cooldown > 0 then
        Lockers.DB.SetCooldown(lockerId, lockerItem.id, player.identifier, lockerItem.cooldown)
    end

    applyTakeMetadata(source, lockerItem, count, toSlot)

    Lockers.DB.Log(
        lockerId,
        player.identifier,
        player.name,
        'item_taken',
        lockerItem.item_name,
        count,
        lockerItem.metadata
    )

    notifyPlayer(source, Lockers.L('success_take', count, Lockers.Inventory.GetItemLabel(lockerItem)), 'success')
end

---@param source number
---@param lockerId number
---@param lockerItem table
---@param count number
local function handleReturnSuccess(source, lockerId, lockerItem, count)
    local player = Lockers.Framework.GetPlayer(source)

    if not player then
        return
    end

    if not lockerItem.unlimited then
        Lockers.DB.UpdateItemAmount(lockerItem.id, lockerItem.amount + count)
    end

    Lockers.DB.Log(
        lockerId,
        player.identifier,
        player.name,
        'item_returned',
        lockerItem.item_name,
        count,
        nil
    )

    local stashId = Lockers.Inventory.GetStashId(lockerId)
    local stashItems = exports.ox_inventory:GetInventoryItems(stashId, false) or {}

    for _, slot in pairs(stashItems) do
        if slot.name == lockerItem.item_name and not (slot.metadata and slot.metadata.locker_item_id) then
            exports.ox_inventory:SetMetadata(stashId, slot.slot, buildStashMetadata(lockerItem))
        end
    end

    notifyPlayer(source, Lockers.L('success_return', count, Lockers.Inventory.GetItemLabel(lockerItem)), 'success')
end

---@param source number
---@param lockerId number
---@return boolean
local function hasActiveLockerAccess(source, lockerId)
    local active = activeOpens[source]

    if not active or active.lockerId ~= lockerId then
        return false
    end

    return Lockers.Security.IsSessionAuthenticated(source, active.token) == true
end

---@param lockerId number
---@param itemName string
---@return table|nil
local function findLockerItemByName(lockerId, itemName)
    local items = Lockers.DB.GetItems(lockerId)

    for i = 1, #items do
        if items[i].item_name == itemName then
            return items[i]
        end
    end

    return nil
end

---@param lockerId number
---@param itemName string
---@return table|nil
local function findReturnableLockerItem(lockerId, itemName)
    local items = Lockers.DB.GetItems(lockerId)

    for i = 1, #items do
        local item = items[i]

        if item.item_name == itemName and item.returnable then
            return item
        end
    end

    return nil
end

local function registerInventoryHooks()
    if hooksRegistered then
        return
    end

    hooksRegistered = true

    exports.ox_inventory:registerHook('openInventory', function(payload)
        local lockerId = Lockers.Inventory.ParseLockerId(payload.inventoryId)

        if not lockerId then
            return
        end

        if not hasActiveLockerAccess(payload.source, lockerId) then
            return false
        end
    end, {
        inventoryFilter = { ('^%s'):format(STASH_PREFIX) },
    })

    swapHookId = exports.ox_inventory:registerHook('swapItems', function(payload)
        local fromId = resolveInventoryId(payload.fromInventory)
        local toId = resolveInventoryId(payload.toInventory)
        local fromLockerId = Lockers.Inventory.ParseLockerId(fromId)
        local toLockerId = Lockers.Inventory.ParseLockerId(toId)
        local lockerId = fromLockerId or toLockerId

        if not lockerId then
            return
        end

        if not hasActiveLockerAccess(payload.source, lockerId) then
            return false
        end

        local player = Lockers.Framework.GetPlayer(payload.source)

        if not player then
            return false
        end

        local count = math.floor(payload.count or 0)

        if count < 1 then
            return false
        end

        if fromLockerId and payload.toType == 'player' then
            local fromSlot = payload.fromSlot

            if not fromSlot or not fromSlot.name then
                return false
            end

            local lockerItemId = fromSlot.metadata and tonumber(fromSlot.metadata.locker_item_id)
            local lockerItem = lockerItemId and Lockers.DB.GetItem(lockerId, lockerItemId)

            if not lockerItem then
                lockerItem = findLockerItemByName(lockerId, fromSlot.name)
            end

            if not lockerItem or lockerItem.item_name ~= fromSlot.name then
                return false
            end

            if player.grade < lockerItem.minimum_grade
                or not Lockers.HasJobAccess(lockerItem.allowed_jobs, player.job, player.grade) then
                notifyPlayer(payload.source, Lockers.L('not_allowed'), 'error')
                return false
            end

            if Lockers.DB.IsOnCooldown(lockerId, lockerItem.id, player.identifier) then
                notifyPlayer(payload.source, Lockers.L('error_generic'), 'error')
                return false
            end

            if count > lockerItem.maximum_take_amount then
                notifyPlayer(payload.source, Lockers.L('error_amount'), 'error')
                return false
            end

            if not lockerItem.unlimited and lockerItem.amount < count then
                notifyPlayer(payload.source, Lockers.L('error_stock'), 'error')
                return false
            end

            if not Lockers.Inventory.CanCarry(payload.source, lockerItem.item_name, count, fromSlot.metadata) then
                notifyPlayer(payload.source, Lockers.L('error_inventory'), 'error')
                return false
            end

            return
        end

        if toLockerId and payload.fromType == 'player' then
            local fromSlot = payload.fromSlot

            if not fromSlot or not fromSlot.name then
                return false
            end

            local lockerItem = findReturnableLockerItem(lockerId, fromSlot.name)

            if not lockerItem then
                notifyPlayer(payload.source, Lockers.L('error_return'), 'error')
                return false
            end

            if Lockers.Inventory.GetCount(payload.source, fromSlot.name) < count then
                notifyPlayer(payload.source, Lockers.L('error_amount'), 'error')
                return false
            end

            if not lockerItem.unlimited
                and lockerItem.maximum_amount > 0
                and (lockerItem.amount + count) > lockerItem.maximum_amount then
                notifyPlayer(payload.source, Lockers.L('error_stock'), 'error')
                return false
            end

            return
        end

        return false
    end, {
        inventoryFilter = { ('^%s'):format(STASH_PREFIX) },
    })

    AddEventHandler(swapHookId, function(success, payload)
        if not success then
            return
        end

        local fromId = resolveInventoryId(payload.fromInventory)
        local toId = resolveInventoryId(payload.toInventory)
        local fromLockerId = Lockers.Inventory.ParseLockerId(fromId)
        local toLockerId = Lockers.Inventory.ParseLockerId(toId)
        local lockerId = fromLockerId or toLockerId
        local count = math.floor(payload.count or 0)

        if not lockerId or count < 1 then
            return
        end

        if fromLockerId and payload.toType == 'player' then
            local lockerItemId = payload.fromSlot.metadata and tonumber(payload.fromSlot.metadata.locker_item_id)
            local lockerItem = lockerItemId and Lockers.DB.GetItem(lockerId, lockerItemId)

            if not lockerItem and payload.fromSlot.name then
                lockerItem = findLockerItemByName(lockerId, payload.fromSlot.name)
            end

            if lockerItem then
                local toSlot = type(payload.toSlot) == 'table' and payload.toSlot or nil
                handleTakeSuccess(payload.source, lockerId, lockerItem, count, toSlot)
            end

            return
        end

        if toLockerId and payload.fromType == 'player' then
            local lockerItem = findReturnableLockerItem(lockerId, payload.fromSlot.name)

            if lockerItem then
                handleReturnSuccess(payload.source, lockerId, lockerItem, count)
            end
        end
    end)

    AddEventHandler('ox_inventory:closedInventory', function(playerId, inventoryId)
        local lockerId = Lockers.Inventory.ParseLockerId(inventoryId)
        local active = activeOpens[playerId]

        if not lockerId or not active or active.lockerId ~= lockerId then
            return
        end

        Lockers.Inventory.SyncDBFromStash(lockerId)
        Lockers.Security.DestroySession(playerId, active.token)
        Lockers.Inventory.ClearActiveOpen(playerId)
    end)
end

function Lockers.Inventory.Init()
    Lockers.Debug('Inventar: ox_inventory')
    registerInventoryHooks()

    if Lockers.DB.IsReady() then
        Lockers.Inventory.RegisterAllStashes()
    end
end

---@return table
function Lockers.Inventory.GetItemOptions()
    local itemList = exports.ox_inventory:Items()
    local options = {}

    if type(itemList) ~= 'table' then
        return options
    end

    for name, data in pairs(itemList) do
        if type(name) == 'string' and type(data) == 'table' then
            options[#options + 1] = {
                name = name,
                label = data.label or name,
            }
        end
    end

    table.sort(options, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    return options
end

lib.callback.register('lockers:server:getInventoryItems', function(source)
    if not Lockers.Framework.IsAdmin(source) then
        return {}
    end

    return Lockers.Inventory.GetItemOptions()
end)

---@param source number
---@param itemName string
---@return number
function Lockers.Inventory.GetCount(source, itemName)
    return exports.ox_inventory:GetItemCount(source, itemName) or 0
end

---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
function Lockers.Inventory.CanCarry(source, itemName, amount, metadata)
    return exports.ox_inventory:CanCarryItem(source, itemName, amount, metadata)
end

---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
function Lockers.Inventory.AddItem(source, itemName, amount, metadata)
    return exports.ox_inventory:AddItem(source, itemName, amount, metadata) ~= false
end

---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
function Lockers.Inventory.RemoveItem(source, itemName, amount, metadata)
    return exports.ox_inventory:RemoveItem(source, itemName, amount, metadata)
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

---@param source number
---@param item table
---@param player table
---@return table
function Lockers.Inventory.BuildClientItem(source, item, player)
    local label = Lockers.Inventory.GetItemLabel(item)
    local image = item.image or ('%s%s.png'):format('nui://ox_inventory/web/images/', item.item_name)
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

AddEventHandler('playerDropped', function()
    Lockers.Inventory.ClearActiveOpen(source)
end)
