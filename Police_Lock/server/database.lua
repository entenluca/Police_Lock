local function debugPrint(...)
    if Config.Debug then
        print('^3[AutoGlovebox]^7', ...)
    end
end

local function runMigrations()
    local storageColumn = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'autoglovebox_loadouts'
          AND COLUMN_NAME = 'storage_type'
    ]])

    if not storageColumn or tonumber(storageColumn) == 0 then
        MySQL.query.await([[
            ALTER TABLE `autoglovebox_loadouts`
            ADD COLUMN `storage_type` ENUM('glovebox', 'trunk') NOT NULL DEFAULT 'glovebox' AFTER `loadout_key`
        ]])

        pcall(function()
            MySQL.query.await('ALTER TABLE `autoglovebox_loadouts` DROP INDEX `unique_loadout`')
        end)

        MySQL.query.await([[
            ALTER TABLE `autoglovebox_loadouts`
            ADD UNIQUE KEY `unique_loadout` (`loadout_type`, `loadout_key`, `storage_type`)
        ]])

        debugPrint('Migration: storage_type zu autoglovebox_loadouts hinzugefügt')
    end

    local equippedStorageColumn = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'autoglovebox_equipped'
          AND COLUMN_NAME = 'storage_type'
    ]])

    if not equippedStorageColumn or tonumber(equippedStorageColumn) == 0 then
        MySQL.query.await([[
            ALTER TABLE `autoglovebox_equipped`
            ADD COLUMN `storage_type` ENUM('glovebox', 'trunk') NOT NULL DEFAULT 'glovebox' AFTER `plate`
        ]])

        pcall(function()
            MySQL.query.await('ALTER TABLE `autoglovebox_equipped` DROP PRIMARY KEY')
        end)

        MySQL.query.await([[
            ALTER TABLE `autoglovebox_equipped`
            ADD PRIMARY KEY (`plate`, `storage_type`)
        ]])

        debugPrint('Migration: storage_type zu autoglovebox_equipped hinzugefügt')
    end
end

MySQL.ready(function()
    local success, errorMessage = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `autoglovebox_equipped` (
                `plate` VARCHAR(12) NOT NULL,
                `storage_type` ENUM('glovebox', 'trunk') NOT NULL DEFAULT 'glovebox',
                `model` VARCHAR(50) DEFAULT NULL,
                `equipped_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`plate`, `storage_type`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `autoglovebox_loadouts` (
                `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `loadout_type` ENUM('model', 'plate') NOT NULL,
                `loadout_key` VARCHAR(50) NOT NULL,
                `storage_type` ENUM('glovebox', 'trunk') NOT NULL DEFAULT 'glovebox',
                `add_mode` VARCHAR(10) DEFAULT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `unique_loadout` (`loadout_type`, `loadout_key`, `storage_type`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `autoglovebox_loadout_items` (
                `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `loadout_id` INT UNSIGNED NOT NULL,
                `item` VARCHAR(50) NOT NULL,
                `amount` INT UNSIGNED NOT NULL DEFAULT 1,
                `metadata` LONGTEXT DEFAULT NULL,
                PRIMARY KEY (`id`),
                KEY `loadout_id` (`loadout_id`),
                CONSTRAINT `fk_autoglovebox_loadout_items`
                    FOREIGN KEY (`loadout_id`)
                    REFERENCES `autoglovebox_loadouts` (`id`)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])

        runMigrations()
    end)

    if not success then
        print(('^1[AutoGlovebox]^7 Datenbank-Fehler: %s'):format(errorMessage))
        return
    end

    AutoGlovebox.Loadouts.Init()
    debugPrint('Datenbank-Tabellen bereit')
end)
