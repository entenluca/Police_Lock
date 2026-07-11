fx_version 'cerulean'
game 'gta5'

name 'Police_Lock'
author 'pfuschbyluis'
description 'Fahrzeug-Schließfachsystem für ESX mit ox_inventory und ox_target'
version '1.2.7'

lua54 'yes'

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
    'es_extended',
    'ox_inventory',
    'ox_target',
}
