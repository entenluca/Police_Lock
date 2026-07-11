fx_version 'cerulean'
game 'gta5'

name 'AutoGlovebox'
author 'pfuschbyluis'
description 'Legt beim Spawnen von Fahrzeugen automatisch Items ins Handschuhfach'
version '1.6.3'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/init.lua',
    'shared/autodetect.lua',
    'shared/plate.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/cache.lua',
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/loadouts.lua',
    'server/database.lua',
    'server/bridge/adapters/*.lua',
    'server/bridge/init.lua',
    'server/admin.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Optional (mindestens eines erforderlich):
-- ox_inventory  → ESX, QBCore oder Standalone
-- qb-inventory  → QBCore
-- es_extended   → ESX ohne ox_inventory (owned_vehicles.glovebox)
