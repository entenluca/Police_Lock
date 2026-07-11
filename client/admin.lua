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

local function showAdminLogs()
    TriggerServerEvent('lockers:server:adminGetLogs', selectedLockerId)
end

local function editLockerDialog(entry)
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

    local input = lib.inputDialog(Lockers.L('admin_save'), {
        { type = 'input', label = Lockers.L('admin_name'), default = locker.name, required = true },
        { type = 'textarea', label = Lockers.L('admin_description'), default = locker.description or '' },
        { type = 'select', label = Lockers.L('admin_access_mode'), options = accessOptions, default = locker.access_mode },
        { type = 'select', label = Lockers.L('admin_vehicle_match'), options = matchOptions, default = locker.vehicle_match_type or 'model' },
        { type = 'input', label = Lockers.L('admin_vehicle_key'), default = locker.vehicle_key or '', description = 'Spawn-Name (police) oder Modell-Hash' },
        { type = 'input', label = Lockers.L('admin_pin'), password = true, description = 'Leer lassen = unverändert' },
        { type = 'input', label = Lockers.L('admin_key_item'), default = locker.key_item or '' },
        { type = 'number', label = Lockers.L('admin_grade'), default = locker.minimum_grade or 0 },
        { type = 'number', label = Lockers.L('admin_distance'), default = locker.target_distance or 2.5 },
        { type = 'number', label = Lockers.L('admin_slots'), default = locker.slots or 50 },
        { type = 'number', label = Lockers.L('admin_weight'), default = locker.max_weight or 100000 },
        { type = 'checkbox', label = Lockers.L('admin_enabled'), checked = locker.enabled ~= false },
        { type = 'checkbox', label = 'Schlüssel verbrauchen', checked = locker.key_consume == true },
    })

    if not input then
        return
    end

    TriggerServerEvent('lockers:server:adminSaveLocker', {
        id = locker.id,
        name = input[1],
        description = input[2],
        access_mode = input[3],
        vehicle_match_type = input[4],
        vehicle_key = input[5],
        pin = input[6] ~= '' and input[6] or nil,
        keep_pin = input[6] == '' and locker.has_pin,
        key_item = input[7],
        minimum_grade = input[8],
        target_distance = input[9],
        slots = input[10],
        max_weight = input[11],
        enabled = input[12],
        key_consume = input[13],
        allowed_jobs = locker.allowed_jobs or {},
        allowed_identifiers = locker.allowed_identifiers or {},
        key_metadata = locker.key_metadata or {},
        key_job_restrict = locker.key_job_restrict or {},
    })
end

local function addItemDialog(lockerId)
    local input = lib.inputDialog(Lockers.L('admin_add_item'), {
        { type = 'input', label = 'Item-Name', required = true },
        { type = 'number', label = 'Menge', default = 1, min = 0 },
        { type = 'number', label = 'Max. Entnahme', default = 1, min = 1 },
        { type = 'number', label = 'Min. Rang', default = 0, min = 0 },
        { type = 'checkbox', label = 'Zurücklegbar', checked = true },
        { type = 'checkbox', label = 'Unbegrenzt', checked = false },
    })

    if not input then
        return
    end

    TriggerServerEvent('lockers:server:adminSaveItem', lockerId, {
        item_name = input[1],
        amount = input[2],
        maximum_take_amount = input[3],
        minimum_grade = input[4],
        returnable = input[5],
        unlimited = input[6],
    })
end

local function showLockerAdminMenu()
    local entry = getSelectedEntry()

    if not entry then
        return
    end

    local locker = entry.locker
    local itemOptions = {}

    for i = 1, #(entry.items or {}) do
        local item = entry.items[i]

        itemOptions[#itemOptions + 1] = {
            title = item.display_name or item.item_name,
            description = ('%s x%s'):format(item.item_name, item.unlimited and '∞' or item.amount),
            icon = 'box',
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
        title = locker.name,
        description = ('%s | %s: %s'):format(
            accessModeLabel(locker.access_mode),
            locker.vehicle_match_type == 'plate' and Lockers.L('vehicle_match_plate') or Lockers.L('vehicle_match_model'),
            locker.vehicle_key or '-'
        ),
        options = {
            {
                title = Lockers.L('admin_save'),
                icon = 'pen',
                onSelect = function()
                    editLockerDialog(entry)
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

                    locker.vehicle_match_type = 'model'
                    locker.vehicle_key = Lockers.GetVehicleKeyFromEntity(vehicle)
                    editLockerDialog({ locker = locker, items = entry.items })
                end,
            },
            {
                title = Lockers.L('admin_items'),
                icon = 'boxes-stacked',
                arrow = true,
                menu = 'locker_admin_items',
            },
            {
                title = Lockers.L('admin_add_item'),
                icon = 'plus',
                onSelect = function()
                    addItemDialog(locker.id)
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
                TriggerServerEvent('lockers:server:adminSaveLocker', {
                    name = 'Neues Fahrzeug-Schließfach',
                    description = '',
                    access_mode = 'pin_or_key',
                    vehicle_match_type = 'model',
                    vehicle_key = '',
                    target_distance = 2.5,
                    minimum_grade = 0,
                    slots = 50,
                    max_weight = 100000,
                    enabled = true,
                    allowed_jobs = {},
                    allowed_identifiers = {},
                })
            end,
        },
    }

    for i = 1, #(adminData.lockers or {}) do
        local entry = adminData.lockers[i]
        local locker = entry.locker

        options[#options + 1] = {
            title = locker.name,
            description = ('#%s | %s'):format(locker.id, locker.vehicle_key or '-'),
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

RegisterNetEvent('lockers:client:requestAdmin', function()
    TriggerServerEvent('lockers:server:adminOpenRequest')
end)

RegisterNetEvent('lockers:client:openAdmin', function(payload)
    adminData = payload or {}
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
