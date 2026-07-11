local adminData = {}
local selectedLockerId

local function getSelectedEntry()
    if not selectedLockerId or not adminData.lockers then
        return nil
    end

    for i = 1, #adminData.lockers do
        if adminData.lockers[i].locker.id == selectedLockerId then
            return adminData.lockers[i]
        end
    end

    return nil
end

local function accessModeLabel(value)
    for i = 1, #(adminData.access_modes or {}) do
        local mode = adminData.access_modes[i]

        if mode.value == value then
            return mode.label
        end
    end

    return value
end

local function lockerStatusLabel(locker)
    if locker.enabled == false then
        return Lockers.L('admin_status_inactive')
    end

    if not locker.vehicle_key or locker.vehicle_key == '' then
        return Lockers.L('admin_status_no_vehicle')
    end

    return Lockers.L('admin_status_active')
end

local function emptyLockerTemplate()
    return {
        name = '',
        description = '',
        access_mode = 'pin_or_key',
        vehicle_match_type = 'model',
        vehicle_key = '',
        target_distance = Config.Vehicle and Config.Vehicle.defaultDistance or 2.5,
        minimum_grade = 0,
        slots = 50,
        max_weight = 100000,
        enabled = true,
        key_consume = false,
        auto_restock = false,
        restock_interval = 3600,
        allowed_jobs = {},
        allowed_identifiers = {},
        key_metadata = {},
        key_job_restrict = {},
    }
end

local function lockerToSavePayload(locker, overrides)
    overrides = overrides or {}

    return {
        id = locker.id,
        name = overrides.name or locker.name,
        description = overrides.description or locker.description,
        access_mode = overrides.access_mode or locker.access_mode,
        vehicle_match_type = overrides.vehicle_match_type or locker.vehicle_match_type,
        vehicle_key = overrides.vehicle_key or locker.vehicle_key,
        pin = overrides.pin,
        keep_pin = overrides.keep_pin ~= nil and overrides.keep_pin or (locker.has_pin and overrides.pin == nil),
        key_item = overrides.key_item or locker.key_item,
        minimum_grade = overrides.minimum_grade or locker.minimum_grade,
        target_distance = overrides.target_distance or locker.target_distance,
        slots = overrides.slots or locker.slots,
        max_weight = overrides.max_weight or locker.max_weight,
        enabled = overrides.enabled ~= nil and overrides.enabled or locker.enabled,
        key_consume = overrides.key_consume ~= nil and overrides.key_consume or locker.key_consume,
        auto_restock = overrides.auto_restock ~= nil and overrides.auto_restock or locker.auto_restock,
        restock_interval = overrides.restock_interval or locker.restock_interval,
        allowed_jobs = locker.allowed_jobs or {},
        allowed_identifiers = locker.allowed_identifiers or {},
        key_metadata = locker.key_metadata or {},
        key_job_restrict = locker.key_job_restrict or {},
    }
end

local function fetchInventoryItems()
    return lib.callback.await('lockers:server:getInventoryItems', false) or {}
end

local function getItemLabelFromList(itemName, inventoryItems)
    for i = 1, #(inventoryItems or {}) do
        if inventoryItems[i].name == itemName then
            return inventoryItems[i].label
        end
    end

    return nil
end

local function buildInventorySelectField(fieldName, label, defaultValue, inventoryItems, required)
    local options = {}

    for i = 1, #(inventoryItems or {}) do
        local item = inventoryItems[i]
        options[#options + 1] = {
            value = item.name,
            label = ('%s | %s'):format(item.label, item.name),
        }
    end

    if #options == 0 then
        return {
            type = 'input',
            name = fieldName,
            label = label,
            default = defaultValue or '',
            required = required,
            description = Lockers.L('admin_item_manual_hint'),
        }
    end

    return {
        type = 'select',
        name = fieldName,
        label = label,
        options = options,
        searchable = true,
        required = required,
        default = defaultValue,
        description = Lockers.L('admin_item_search_hint'),
    }
end

local function identifiersToString(identifiers)
    if type(identifiers) ~= 'table' or #identifiers == 0 then
        return ''
    end

    return table.concat(identifiers, ', ')
end

local function parseIdentifiersInput(value)
    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local identifiers = {}

    for part in value:gmatch('[^,%s]+') do
        identifiers[#identifiers + 1] = part
    end

    return identifiers
end

local function buildLockerOptionFields(accessMode, locker, inventoryItems)
    local fields = {}

    if Lockers.AccessModeNeedsPin(accessMode) then
        fields[#fields + 1] = {
            type = 'input',
            name = 'pin',
            label = Lockers.L('admin_pin'),
            password = true,
            description = Lockers.L('admin_pin_hint'),
        }
    end

    if Lockers.AccessModeNeedsKey(accessMode) then
        fields[#fields + 1] = buildInventorySelectField(
            'key_item',
            Lockers.L('admin_key_item'),
            locker.key_item,
            inventoryItems,
            false
        )
        fields[#fields + 1] = {
            type = 'checkbox',
            name = 'key_consume',
            label = Lockers.L('admin_key_consume'),
            checked = locker.key_consume == true,
        }
    end

    if Lockers.AccessModeNeedsJobFields(accessMode) then
        fields[#fields + 1] = {
            type = 'number',
            name = 'minimum_grade',
            label = Lockers.L('admin_grade'),
            default = locker.minimum_grade or 0,
            min = 0,
        }
    end

    if Lockers.AccessModeNeedsIdentifiers(accessMode) then
        fields[#fields + 1] = {
            type = 'textarea',
            name = 'allowed_identifiers',
            label = Lockers.L('admin_identifiers'),
            default = identifiersToString(locker.allowed_identifiers),
            description = Lockers.L('admin_identifiers_hint'),
        }
    end

    fields[#fields + 1] = {
        type = 'number',
        name = 'target_distance',
        label = Lockers.L('admin_distance'),
        default = locker.target_distance or 2.5,
    }
    fields[#fields + 1] = {
        type = 'number',
        name = 'slots',
        label = Lockers.L('admin_slots'),
        default = locker.slots or 50,
    }
    fields[#fields + 1] = {
        type = 'number',
        name = 'max_weight',
        label = Lockers.L('admin_weight'),
        default = locker.max_weight or 100000,
    }
    fields[#fields + 1] = {
        type = 'checkbox',
        name = 'auto_restock',
        label = Lockers.L('admin_auto_restock'),
        checked = locker.auto_restock == true,
    }

    if locker.auto_restock == true then
        fields[#fields + 1] = {
            type = 'number',
            name = 'restock_interval',
            label = Lockers.L('admin_restock_interval'),
            default = locker.restock_interval or 3600,
            min = 60,
        }
    end

    return fields
end

local function editLockerDialog(entry, onComplete)
    local locker = entry.locker
    local accessOptions = {}

    for i = 1, #(adminData.access_modes or {}) do
        accessOptions[#accessOptions + 1] = {
            value = adminData.access_modes[i].value,
            label = adminData.access_modes[i].label,
        }
    end

    local matchOptions = {}

    for i = 1, #(adminData.vehicle_match_types or {}) do
        matchOptions[#matchOptions + 1] = {
            value = adminData.vehicle_match_types[i].value,
            label = adminData.vehicle_match_types[i].label,
        }
    end

    local vehicleMatchType = locker.vehicle_match_type or 'model'
    local vehicleKeyLabel = vehicleMatchType == 'plate' and Lockers.L('vehicle_match_plate') or Lockers.L('admin_vehicle_key')

    local baseInput = lib.inputDialog(Lockers.L('admin_edit_basic'), {
        { type = 'input', name = 'name', label = Lockers.L('admin_name'), default = locker.name or '', required = true },
        { type = 'textarea', name = 'description', label = Lockers.L('admin_description'), default = locker.description or '' },
        { type = 'select', name = 'access_mode', label = Lockers.L('admin_access_mode'), options = #accessOptions > 0 and accessOptions or {
            { value = 'pin_or_key', label = Lockers.L('access_pin_or_key') },
        }, default = locker.access_mode or 'pin_or_key' },
        { type = 'select', name = 'vehicle_match_type', label = Lockers.L('admin_vehicle_match'), options = #matchOptions > 0 and matchOptions or {
            { value = 'model', label = Lockers.L('vehicle_match_model') },
        }, default = vehicleMatchType },
        { type = 'input', name = 'vehicle_key', label = vehicleKeyLabel, default = locker.vehicle_key or '', description = Lockers.L('admin_vehicle_key_hint') },
        { type = 'checkbox', name = 'enabled', label = Lockers.L('admin_enabled'), checked = locker.enabled ~= false },
    })

    if not baseInput then
        if onComplete then
            onComplete(false)
        end
        return
    end

    local accessMode = Lockers.GetDialogValue(baseInput, 'access_mode', 3, locker.access_mode or 'pin_or_key')
    local inventoryItems = fetchInventoryItems()
    local optionFields = buildLockerOptionFields(accessMode, locker, inventoryItems)

    local optionInput

    if #optionFields > 0 then
        optionInput = lib.inputDialog(Lockers.L('admin_edit_options'), optionFields)

        if not optionInput then
            if onComplete then
                onComplete(false)
            end
            return
        end
    else
        optionInput = {}
    end

    local pin = Lockers.GetDialogValue(optionInput, 'pin', nil, '')
    local autoRestock = Lockers.ToBool(Lockers.GetDialogValue(optionInput, 'auto_restock', nil, locker.auto_restock), false)

    local saveData = {
        name = Lockers.GetDialogValue(baseInput, 'name', 1, ''),
        description = Lockers.GetDialogValue(baseInput, 'description', 2, ''),
        access_mode = accessMode,
        vehicle_match_type = Lockers.GetDialogValue(baseInput, 'vehicle_match_type', 4, 'model'),
        vehicle_key = Lockers.GetDialogValue(baseInput, 'vehicle_key', 5, ''),
        enabled = Lockers.ToBool(Lockers.GetDialogValue(baseInput, 'enabled', 6, true), true),
        target_distance = Lockers.GetDialogValue(optionInput, 'target_distance', nil, locker.target_distance or 2.5),
        slots = Lockers.GetDialogValue(optionInput, 'slots', nil, locker.slots or 50),
        max_weight = Lockers.GetDialogValue(optionInput, 'max_weight', nil, locker.max_weight or 100000),
        auto_restock = autoRestock,
        restock_interval = Lockers.GetDialogValue(optionInput, 'restock_interval', nil, locker.restock_interval or 3600),
        allowed_jobs = locker.allowed_jobs or {},
        allowed_identifiers = locker.allowed_identifiers or {},
        key_metadata = locker.key_metadata or {},
        key_job_restrict = locker.key_job_restrict or {},
    }

    if Lockers.AccessModeNeedsPin(accessMode) then
        saveData.pin = pin ~= '' and pin or nil
        saveData.keep_pin = pin == '' and locker.has_pin
    else
        saveData.pin = nil
        saveData.keep_pin = false
    end

    if Lockers.AccessModeNeedsKey(accessMode) then
        saveData.key_item = Lockers.GetDialogValue(optionInput, 'key_item', nil, locker.key_item or '')
        saveData.key_consume = Lockers.ToBool(Lockers.GetDialogValue(optionInput, 'key_consume', nil, locker.key_consume), false)
    else
        saveData.key_item = nil
        saveData.key_consume = false
    end

    if Lockers.AccessModeNeedsJobFields(accessMode) then
        saveData.minimum_grade = Lockers.GetDialogValue(optionInput, 'minimum_grade', nil, locker.minimum_grade or 0)
    else
        saveData.minimum_grade = locker.minimum_grade or 0
    end

    if Lockers.AccessModeNeedsIdentifiers(accessMode) then
        saveData.allowed_identifiers = parseIdentifiersInput(Lockers.GetDialogValue(optionInput, 'allowed_identifiers', nil, ''))
    end

    if not autoRestock then
        saveData.restock_interval = locker.restock_interval or 3600
    end

    TriggerServerEvent('lockers:server:adminSaveLocker', lockerToSavePayload(locker, saveData))
end

local function buildItemStockFields(item)
    return {
        { type = 'number', name = 'amount', label = Lockers.L('admin_item_amount'), default = item and item.amount or 1, min = 0 },
        { type = 'number', name = 'maximum_amount', label = Lockers.L('admin_max_stock'), default = item and item.maximum_amount or 0, min = 0, description = Lockers.L('admin_max_stock_hint') },
        { type = 'number', name = 'maximum_take_amount', label = Lockers.L('admin_max_take'), default = item and item.maximum_take_amount or 1, min = 1 },
    }
end

local function saveItemFromDialogs(lockerId, baseInput, stockInput, itemId, inventoryItems)
    local unlimited = Lockers.ToBool(Lockers.GetDialogValue(baseInput, 'unlimited', nil, false), false)
    local itemName = Lockers.GetDialogValue(baseInput, 'item_name', nil, '')
    local displayName = getItemLabelFromList(itemName, inventoryItems)

    TriggerServerEvent('lockers:server:adminSaveItem', lockerId, {
        id = itemId,
        item_name = itemName,
        display_name = displayName,
        amount = unlimited and 0 or Lockers.GetDialogValue(stockInput, 'amount', nil, 1),
        maximum_amount = unlimited and 0 or Lockers.GetDialogValue(stockInput, 'maximum_amount', nil, 0),
        maximum_take_amount = unlimited and 1 or Lockers.GetDialogValue(stockInput, 'maximum_take_amount', nil, 1),
        minimum_grade = Lockers.GetDialogValue(baseInput, 'minimum_grade', nil, 0),
        returnable = Lockers.ToBool(Lockers.GetDialogValue(baseInput, 'returnable', nil, true), true),
        unlimited = unlimited,
    })
end

local function addItemDialog(lockerId)
    local inventoryItems = fetchInventoryItems()

    local baseInput = lib.inputDialog(Lockers.L('admin_add_item'), {
        buildInventorySelectField('item_name', Lockers.L('admin_item_name'), nil, inventoryItems, true),
        { type = 'checkbox', name = 'returnable', label = Lockers.L('admin_returnable'), checked = true },
        { type = 'checkbox', name = 'unlimited', label = Lockers.L('admin_unlimited'), checked = false },
        { type = 'number', name = 'minimum_grade', label = Lockers.L('admin_grade'), default = 0, min = 0 },
    })

    if not baseInput then
        return
    end

    local unlimited = Lockers.ToBool(Lockers.GetDialogValue(baseInput, 'unlimited', nil, false), false)
    local stockInput = {}

    if not unlimited then
        stockInput = lib.inputDialog(Lockers.L('admin_item_stock'), buildItemStockFields(nil))

        if not stockInput then
            return
        end
    end

    saveItemFromDialogs(lockerId, baseInput, stockInput, nil, inventoryItems)
end

local function editItemDialog(lockerId, item)
    local inventoryItems = fetchInventoryItems()

    local baseInput = lib.inputDialog(Lockers.L('admin_edit_item'), {
        buildInventorySelectField('item_name', Lockers.L('admin_item_name'), item.item_name, inventoryItems, true),
        { type = 'checkbox', name = 'returnable', label = Lockers.L('admin_returnable'), checked = item.returnable ~= false },
        { type = 'checkbox', name = 'unlimited', label = Lockers.L('admin_unlimited'), checked = item.unlimited == true },
        { type = 'number', name = 'minimum_grade', label = Lockers.L('admin_grade'), default = item.minimum_grade or 0, min = 0 },
    })

    if not baseInput then
        return
    end

    local unlimited = Lockers.ToBool(Lockers.GetDialogValue(baseInput, 'unlimited', nil, item.unlimited == true), false)
    local stockInput = {}

    if not unlimited then
        stockInput = lib.inputDialog(Lockers.L('admin_item_stock'), buildItemStockFields(item))

        if not stockInput then
            return
        end
    end

    saveItemFromDialogs(lockerId, baseInput, stockInput, item.id, inventoryItems)
end

local function showLockerAdminMenu()
    local entry = getSelectedEntry()

    if not entry then
        showAdminMainMenu()
        return
    end

    local locker = entry.locker
    local itemOptions = {}

    if #(entry.items or {}) == 0 then
        itemOptions[#itemOptions + 1] = {
            title = Lockers.L('admin_no_items'),
            icon = 'circle-info',
            disabled = true,
        }
    end

    for i = 1, #(entry.items or {}) do
        local item = entry.items[i]

        itemOptions[#itemOptions + 1] = {
            title = item.display_name or item.item_name,
            description = ('%s | %s: %s'):format(
                item.item_name,
                Lockers.L('admin_item_amount'),
                item.unlimited and Lockers.L('unlimited') or item.amount
            ),
            icon = 'box',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'locker_admin_item_actions',
                    menu = 'locker_admin_items',
                    title = item.display_name or item.item_name,
                    options = {
                        {
                            title = Lockers.L('admin_edit_item'),
                            icon = 'pen',
                            onSelect = function()
                                editItemDialog(locker.id, item)
                            end,
                        },
                        {
                            title = Lockers.L('admin_delete'),
                            icon = 'trash',
                            onSelect = function()
                                local confirm = lib.alertDialog({
                                    header = Lockers.L('admin_delete'),
                                    content = ('%s löschen?'):format(item.display_name or item.item_name),
                                    centered = true,
                                    cancel = true,
                                })

                                if confirm == 'confirm' then
                                    TriggerServerEvent('lockers:server:adminDeleteItem', locker.id, item.id)
                                end
                            end,
                        },
                    },
                })

                lib.showContext('locker_admin_item_actions')
            end,
        }
    end

    lib.registerContext({
        id = 'locker_admin_items',
        menu = 'locker_admin_detail',
        title = Lockers.L('admin_items'),
        options = itemOptions,
    })

    lib.registerContext({
        id = 'locker_admin_detail',
        menu = 'locker_admin_main',
        title = locker.name ~= '' and locker.name or ('Schließfach #%s'):format(locker.id),
        description = ('%s | %s | %s: %s | %s'):format(
            lockerStatusLabel(locker),
            accessModeLabel(locker.access_mode),
            locker.vehicle_match_type == 'plate' and Lockers.L('vehicle_match_plate') or Lockers.L('vehicle_match_model'),
            locker.vehicle_key or '-',
            locker.auto_restock and Lockers.L('admin_auto_restock_on') or Lockers.L('admin_auto_restock_off')
        ),
        options = {
            {
                title = Lockers.L('admin_edit'),
                icon = 'pen',
                onSelect = function()
                    editLockerDialog(entry)
                end,
            },
            {
                title = Lockers.L('admin_add_item'),
                icon = 'plus',
                description = Lockers.L('admin_add_item_hint'),
                onSelect = function()
                    if not locker.id then
                        lib.notify({ title = Lockers.L('admin_title'), description = Lockers.L('admin_save_first'), type = 'error' })
                        return
                    end

                    addItemDialog(locker.id)
                end,
            },
            {
                title = Lockers.L('admin_items'),
                icon = 'boxes-stacked',
                arrow = true,
                menu = 'locker_admin_items',
            },
            {
                title = locker.auto_restock and Lockers.L('admin_auto_restock_disable') or Lockers.L('admin_auto_restock_enable'),
                icon = 'rotate',
                description = Lockers.L('admin_auto_restock_hint'),
                onSelect = function()
                    TriggerServerEvent('lockers:server:adminToggleAutoRestock', locker.id)
                end,
            },
            {
                title = Lockers.L('admin_set_vehicle'),
                icon = 'car',
                onSelect = function()
                    local coords = GetEntityCoords(PlayerPedId())
                    local vehicle = lib.getClosestVehicle(coords, 6.0, false)

                    if not vehicle or vehicle == 0 then
                        lib.notify({ title = Lockers.L('admin_title'), description = Lockers.L('no_vehicle'), type = 'error' })
                        return
                    end

                    if locker.id then
                        TriggerServerEvent('lockers:server:adminAssignVehicle', locker.id, Lockers.GetVehicleKeyFromEntity(vehicle))
                        return
                    end

                    locker.vehicle_match_type = 'model'
                    locker.vehicle_key = Lockers.GetVehicleKeyFromEntity(vehicle)
                    editLockerDialog({ locker = locker, items = entry.items })
                end,
            },
            {
                title = Lockers.L('admin_duplicate'),
                icon = 'copy',
                onSelect = function()
                    TriggerServerEvent('lockers:server:adminDuplicateLocker', locker.id)
                end,
            },
            {
                title = Lockers.L('admin_delete'),
                icon = 'trash',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = Lockers.L('admin_delete'),
                        content = ('%s wirklich löschen?'):format(locker.name),
                        centered = true,
                        cancel = true,
                    })

                    if confirm == 'confirm' then
                        TriggerServerEvent('lockers:server:adminDeleteLocker', locker.id)
                        selectedLockerId = nil
                    end
                end,
            },
        },
    })

    lib.showContext('locker_admin_detail')
end

local function showAdminMainMenu()
    local options = {
        {
            title = Lockers.L('admin_new'),
            icon = 'plus',
            onSelect = function()
                editLockerDialog({
                    locker = emptyLockerTemplate(),
                    items = {},
                })
            end,
        },
    }

    for i = 1, #(adminData.lockers or {}) do
        local entry = adminData.lockers[i]
        local locker = entry.locker

        options[#options + 1] = {
            title = locker.name ~= '' and locker.name or ('Schließfach #%s'):format(locker.id),
            description = ('#%s | %s | %s | %s Items'):format(
                locker.id,
                lockerStatusLabel(locker),
                locker.vehicle_key or '-',
                #(entry.items or {})
            ),
            icon = locker.enabled and 'box' or 'box-open',
            arrow = true,
            onSelect = function()
                selectedLockerId = locker.id
                showLockerAdminMenu()
            end,
        }
    end

    lib.registerContext({
        id = 'locker_admin_main',
        title = Lockers.L('admin_title'),
        options = options,
    })

    lib.showContext('locker_admin_main')
end

RegisterNetEvent('lockers:client:openAdminRequest', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)

RegisterNetEvent('lockers:client:requestAdmin', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)

RegisterCommand(Config.Admin.command, function()
    if not Config.Admin.enabled then
        return
    end

    TriggerServerEvent('lockers:server:adminOpenRequest')
end, false)

RegisterNetEvent('lockers:client:openAdmin', function(payload)
    adminData = payload or {}

    if not next(adminData) then
        lib.notify({
            title = Lockers.L('admin_title'),
            description = Lockers.L('admin_loading'),
            type = 'error',
        })
        return
    end

    if payload and payload.selected_locker_id then
        selectedLockerId = payload.selected_locker_id
        showLockerAdminMenu()
        return
    end

    showAdminMainMenu()
end)

exports('OpenAdminPanel', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)
