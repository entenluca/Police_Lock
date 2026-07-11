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

local function showAdminLogs()
    TriggerServerEvent('lockers:server:adminGetLogs', selectedLockerId)
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
        keep_pin = overrides.keep_pin ~= false and locker.has_pin and not overrides.pin,
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

    local input = lib.inputDialog(Lockers.L('admin_edit'), {
        { type = 'input', name = 'name', label = Lockers.L('admin_name'), default = locker.name or '', required = true },
        { type = 'textarea', name = 'description', label = Lockers.L('admin_description'), default = locker.description or '' },
        { type = 'select', name = 'access_mode', label = Lockers.L('admin_access_mode'), options = #accessOptions > 0 and accessOptions or {
            { value = 'pin_or_key', label = Lockers.L('access_pin_or_key') },
        }, default = locker.access_mode or 'pin_or_key' },
        { type = 'select', name = 'vehicle_match_type', label = Lockers.L('admin_vehicle_match'), options = #matchOptions > 0 and matchOptions or {
            { value = 'model', label = Lockers.L('vehicle_match_model') },
        }, default = locker.vehicle_match_type or 'model' },
        { type = 'input', name = 'vehicle_key', label = Lockers.L('admin_vehicle_key'), default = locker.vehicle_key or '', description = 'Spawn-Name (police) oder Kennzeichen' },
        { type = 'input', name = 'pin', label = Lockers.L('admin_pin'), password = true, description = 'Leer lassen = unverändert' },
        { type = 'input', name = 'key_item', label = Lockers.L('admin_key_item'), default = locker.key_item or '' },
        { type = 'number', name = 'minimum_grade', label = Lockers.L('admin_grade'), default = locker.minimum_grade or 0 },
        { type = 'number', name = 'target_distance', label = Lockers.L('admin_distance'), default = locker.target_distance or 2.5 },
        { type = 'number', name = 'slots', label = Lockers.L('admin_slots'), default = locker.slots or 50 },
        { type = 'number', name = 'max_weight', label = Lockers.L('admin_weight'), default = locker.max_weight or 100000 },
        { type = 'checkbox', name = 'enabled', label = Lockers.L('admin_enabled'), checked = locker.enabled ~= false },
        { type = 'checkbox', name = 'key_consume', label = Lockers.L('admin_key_consume'), checked = locker.key_consume == true },
        { type = 'checkbox', name = 'auto_restock', label = Lockers.L('admin_auto_restock'), checked = locker.auto_restock == true },
        { type = 'number', name = 'restock_interval', label = Lockers.L('admin_restock_interval'), default = locker.restock_interval or 3600, min = 60 },
    })

    if not input then
        if onComplete then
            onComplete(false)
        end
        return
    end

    local pin = Lockers.GetDialogValue(input, 'pin', 6, '')

    TriggerServerEvent('lockers:server:adminSaveLocker', lockerToSavePayload(locker, {
        name = Lockers.GetDialogValue(input, 'name', 1, ''),
        description = Lockers.GetDialogValue(input, 'description', 2, ''),
        access_mode = Lockers.GetDialogValue(input, 'access_mode', 3, 'pin_or_key'),
        vehicle_match_type = Lockers.GetDialogValue(input, 'vehicle_match_type', 4, 'model'),
        vehicle_key = Lockers.GetDialogValue(input, 'vehicle_key', 5, ''),
        pin = pin ~= '' and pin or nil,
        keep_pin = pin == '' and locker.has_pin,
        key_item = Lockers.GetDialogValue(input, 'key_item', 7, ''),
        minimum_grade = Lockers.GetDialogValue(input, 'minimum_grade', 8, 0),
        target_distance = Lockers.GetDialogValue(input, 'target_distance', 9, 2.5),
        slots = Lockers.GetDialogValue(input, 'slots', 10, 50),
        max_weight = Lockers.GetDialogValue(input, 'max_weight', 11, 100000),
        enabled = Lockers.ToBool(Lockers.GetDialogValue(input, 'enabled', 12, true), true),
        key_consume = Lockers.ToBool(Lockers.GetDialogValue(input, 'key_consume', 13, false), false),
        auto_restock = Lockers.ToBool(Lockers.GetDialogValue(input, 'auto_restock', 14, false), false),
        restock_interval = Lockers.GetDialogValue(input, 'restock_interval', 15, 3600),
    }))
end

local function addItemDialog(lockerId)
    local input = lib.inputDialog(Lockers.L('admin_add_item'), {
        { type = 'input', name = 'item_name', label = Lockers.L('admin_item_name'), required = true },
        { type = 'input', name = 'display_name', label = Lockers.L('admin_item_label'), description = 'Optional' },
        { type = 'number', name = 'amount', label = Lockers.L('admin_item_amount'), default = 1, min = 0 },
        { type = 'number', name = 'maximum_amount', label = Lockers.L('admin_max_stock'), default = 0, min = 0, description = Lockers.L('admin_max_stock_hint') },
        { type = 'number', name = 'maximum_take_amount', label = Lockers.L('admin_max_take'), default = 1, min = 1 },
        { type = 'number', name = 'minimum_grade', label = Lockers.L('admin_grade'), default = 0, min = 0 },
        { type = 'checkbox', name = 'returnable', label = Lockers.L('admin_returnable'), checked = true },
        { type = 'checkbox', name = 'unlimited', label = Lockers.L('admin_unlimited'), checked = false },
    })

    if not input then
        return
    end

    local displayName = Lockers.GetDialogValue(input, 'display_name', 2, '')

    TriggerServerEvent('lockers:server:adminSaveItem', lockerId, {
        item_name = Lockers.GetDialogValue(input, 'item_name', 1, ''),
        display_name = displayName ~= '' and displayName or nil,
        amount = Lockers.GetDialogValue(input, 'amount', 3, 1),
        maximum_amount = Lockers.GetDialogValue(input, 'maximum_amount', 4, 0),
        maximum_take_amount = Lockers.GetDialogValue(input, 'maximum_take_amount', 5, 1),
        minimum_grade = Lockers.GetDialogValue(input, 'minimum_grade', 6, 0),
        returnable = Lockers.ToBool(Lockers.GetDialogValue(input, 'returnable', 7, true), true),
        unlimited = Lockers.ToBool(Lockers.GetDialogValue(input, 'unlimited', 8, false), false),
    })
end

local function editItemDialog(lockerId, item)
    local input = lib.inputDialog(Lockers.L('admin_edit_item'), {
        { type = 'input', name = 'item_name', label = Lockers.L('admin_item_name'), default = item.item_name, required = true },
        { type = 'input', name = 'display_name', label = Lockers.L('admin_item_label'), default = item.display_name or '' },
        { type = 'number', name = 'amount', label = Lockers.L('admin_item_amount'), default = item.amount or 0, min = 0 },
        { type = 'number', name = 'maximum_amount', label = Lockers.L('admin_max_stock'), default = item.maximum_amount or 0, min = 0, description = Lockers.L('admin_max_stock_hint') },
        { type = 'number', name = 'maximum_take_amount', label = Lockers.L('admin_max_take'), default = item.maximum_take_amount or 1, min = 1 },
        { type = 'number', name = 'minimum_grade', label = Lockers.L('admin_grade'), default = item.minimum_grade or 0, min = 0 },
        { type = 'checkbox', name = 'returnable', label = Lockers.L('admin_returnable'), checked = item.returnable ~= false },
        { type = 'checkbox', name = 'unlimited', label = Lockers.L('admin_unlimited'), checked = item.unlimited == true },
    })

    if not input then
        return
    end

    local displayName = Lockers.GetDialogValue(input, 'display_name', 2, '')

    TriggerServerEvent('lockers:server:adminSaveItem', lockerId, {
        id = item.id,
        item_name = Lockers.GetDialogValue(input, 'item_name', 1, item.item_name),
        display_name = displayName ~= '' and displayName or nil,
        amount = Lockers.GetDialogValue(input, 'amount', 3, item.amount),
        maximum_amount = Lockers.GetDialogValue(input, 'maximum_amount', 4, item.maximum_amount),
        maximum_take_amount = Lockers.GetDialogValue(input, 'maximum_take_amount', 5, item.maximum_take_amount),
        minimum_grade = Lockers.GetDialogValue(input, 'minimum_grade', 6, item.minimum_grade),
        returnable = Lockers.ToBool(Lockers.GetDialogValue(input, 'returnable', 7, item.returnable ~= false), true),
        unlimited = Lockers.ToBool(Lockers.GetDialogValue(input, 'unlimited', 8, item.unlimited == true), false),
    })
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
                title = Lockers.L('admin_logs'),
                icon = 'list',
                onSelect = showAdminLogs,
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

RegisterNetEvent('lockers:client:adminLogs', function(logs)
    local lines = {}

    for i = 1, #(logs or {}) do
        local log = logs[i]
        lines[#lines + 1] = ('[%s] %s - %s %s %s'):format(
            log.timestamp or '',
            log.player_name or '',
            log.action or '',
            log.item_name or '',
            log.amount or ''
        )
    end

    lib.alertDialog({
        header = Lockers.L('admin_logs'),
        content = #lines > 0 and table.concat(lines, '\n') or 'Keine Logs.',
        centered = true,
    })
end)

exports('OpenAdminPanel', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)
