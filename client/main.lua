local currentToken
local currentPayload

local function makeRequestId()
    return ('%s-%s'):format(GetGameTimer(), math.random(100000, 999999))
end

local function closeSession()
    if currentToken then
        TriggerServerEvent('lockers:server:closeSession', currentToken)
        currentToken = nil
    end

    currentPayload = nil
end

local function showItemActions(item)
    if not currentToken or not currentPayload then
        return
    end

    local strings = currentPayload.strings
    local options = {}

    if item.allowed then
        options[#options + 1] = {
            title = strings.take,
            description = ('%s: %s'):format(strings.stock, item.unlimited and strings.unlimited or item.amount),
            icon = 'download',
            onSelect = function()
                local input = lib.inputDialog(strings.take, {
                    {
                        type = 'number',
                        label = strings.amount,
                        min = 1,
                        max = item.maximum_take_amount or 1,
                        default = 1,
                    },
                })

                if not input or not input[1] then
                    return
                end

                local amount = math.floor(input[1])

                if amount >= (currentPayload.confirm_threshold or 10) then
                    local confirm = lib.alertDialog({
                        header = strings.confirm_yes,
                        content = strings.confirm_take:format(amount, item.display_name),
                        centered = true,
                        cancel = true,
                    })

                    if confirm ~= 'confirm' then
                        return
                    end
                end

                TriggerServerEvent('lockers:server:takeItem', currentToken, item.id, amount, makeRequestId())
            end,
        }

        if item.returnable then
            options[#options + 1] = {
                title = strings.return_item,
                description = ('%s: %s'):format(strings.inventory, item.player_amount),
                icon = 'upload',
                onSelect = function()
                    local input = lib.inputDialog(strings.return_item, {
                        {
                            type = 'number',
                            label = strings.amount,
                            min = 1,
                            max = math.max(item.player_amount, 1),
                            default = 1,
                        },
                    })

                    if input and input[1] then
                        TriggerServerEvent('lockers:server:returnItem', currentToken, item.id, math.floor(input[1]), makeRequestId())
                    end
                end,
            }
        end
    else
        options[#options + 1] = {
            title = strings.not_allowed,
            description = item.rank_label,
            icon = 'ban',
            disabled = true,
        }
    end

    lib.registerContext({
        id = ('locker_item_%s'):format(item.id),
        menu = 'locker_main',
        title = item.display_name,
        description = item.description,
        options = options,
    })

    lib.showContext(('locker_item_%s'):format(item.id))
end

local function showLockerMenu(payload)
    currentToken = payload.token
    currentPayload = payload

    local options = {}

    for i = 1, #payload.items do
        local item = payload.items[i]
        local stock = item.unlimited and payload.strings.unlimited or tostring(item.amount)

        options[#options + 1] = {
            title = item.display_name,
            description = ('%s: %s | %s: %s | %s: %sg'):format(
                payload.strings.stock,
                stock,
                payload.strings.inventory,
                item.player_amount,
                payload.strings.weight,
                item.weight
            ),
            icon = item.allowed and 'box' or 'lock',
            arrow = true,
            disabled = not item.allowed and item.amount <= 0,
            onSelect = function()
                showItemActions(item)
            end,
        }
    end

    if #options == 0 then
        options[#options + 1] = {
            title = Lockers.L('error_generic'),
            icon = 'circle-info',
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'locker_main',
        title = payload.locker.name,
        description = payload.locker.description,
        onExit = closeSession,
        options = options,
    })

    lib.showContext('locker_main')
end

local function showAuthMenu(session)
    currentToken = session.token
    local options = {}

    if session.requires_pin then
        options[#options + 1] = {
            title = Lockers.L('pin_title'),
            description = Lockers.L('pin_placeholder'),
            icon = 'key',
            onSelect = function()
                local input = lib.inputDialog(Lockers.L('pin_title'), {
                    {
                        type = 'input',
                        label = Lockers.L('pin_placeholder'),
                        password = true,
                        required = true,
                    },
                })

                if input and input[1] and input[1] ~= '' then
                    TriggerServerEvent('lockers:server:submitPin', currentToken, input[1], makeRequestId())
                end
            end,
        }
    end

    if session.requires_key then
        options[#options + 1] = {
            title = Lockers.L('use_key'),
            description = Lockers.L('key_missing'),
            icon = 'id-card',
            onSelect = function()
                TriggerServerEvent('lockers:server:useKey', currentToken, makeRequestId())
            end,
        }
    end

    options[#options + 1] = {
        title = Lockers.L('pin_cancel'),
        icon = 'xmark',
        onSelect = closeSession,
    }

    lib.registerContext({
        id = 'locker_auth',
        title = session.name,
        description = session.description,
        onExit = closeSession,
        options = options,
    })

    lib.showContext('locker_auth')
end

RegisterNetEvent('lockers:client:openAuth', function(session)
    showAuthMenu(session)
end)

RegisterNetEvent('lockers:client:authResult', function(success, message, extra)
    if success and extra and (extra.needsKey or extra.needsPin) then
        lib.notify({ title = Lockers.L('locker_title'), description = message, type = 'inform' })
        return
    end

    if success then
        lib.notify({ title = Lockers.L('locker_title'), description = message or 'OK', type = 'success' })
        return
    end

    lib.notify({ title = Lockers.L('locker_title'), description = message or Lockers.L('error_generic'), type = 'error' })
end)

RegisterNetEvent('lockers:client:openLocker', function(payload)
    showLockerMenu(payload)
end)

exports('OpenLocker', function(lockerId, vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(vehicle))
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local closest = lib.getClosestVehicle(coords, Config.Security.maxDistance or 3.5, false)

    if closest and closest ~= 0 then
        TriggerServerEvent('lockers:server:requestOpen', lockerId, NetworkGetNetworkIdFromEntity(closest))
    end
end)

exports('CloseLocker', closeSession)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        closeSession()
    end
end)
