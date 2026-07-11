fx_version 'cerulean'
game 'gta5'

name 'fivem_lockers'
author 'pfuschbyluis'
description 'Performantes und sicheres Schließfachsystem für ESX und QBCore'
version '1.0.0'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'locales/*.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/framework.lua',
    'locales/*.lua',
}

client_scripts {
    'client/target.lua',
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/security.lua',
    'server/inventory.lua',
    'server/admin.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Optional (mindestens eines empfohlen):
-- ox_target / qb-target
-- ox_inventory / qb-inventory
-- es_extended / qb-core / qbx_core
