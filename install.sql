CREATE TABLE IF NOT EXISTS `lockers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `coordinates` JSON DEFAULT NULL,
    `vehicle_match_type` ENUM('model', 'plate') NOT NULL DEFAULT 'model',
    `vehicle_key` VARCHAR(50) NOT NULL DEFAULT '',
    `target_distance` FLOAT NOT NULL DEFAULT 2.0,
    `access_mode` VARCHAR(32) NOT NULL DEFAULT 'pin_or_key',
    `pin_hash` VARCHAR(256) DEFAULT NULL,
    `key_item` VARCHAR(64) DEFAULT NULL,
    `key_metadata` JSON DEFAULT NULL,
    `key_consume` TINYINT(1) NOT NULL DEFAULT 0,
    `key_job_restrict` JSON DEFAULT NULL,
    `allowed_jobs` JSON DEFAULT NULL,
    `minimum_grade` INT NOT NULL DEFAULT 0,
    `allowed_identifiers` JSON DEFAULT NULL,
    `slots` INT UNSIGNED NOT NULL DEFAULT 50,
    `max_weight` INT UNSIGNED NOT NULL DEFAULT 100000,
    `auto_restock` TINYINT(1) NOT NULL DEFAULT 0,
    `restock_interval` INT UNSIGNED NOT NULL DEFAULT 3600,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_by` VARCHAR(80) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `locker_items` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `locker_id` INT UNSIGNED NOT NULL,
    `item_name` VARCHAR(64) NOT NULL,
    `display_name` VARCHAR(100) DEFAULT NULL,
    `description` TEXT DEFAULT NULL,
    `image` VARCHAR(255) DEFAULT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `maximum_amount` INT NOT NULL DEFAULT 0,
    `maximum_take_amount` INT NOT NULL DEFAULT 1,
    `minimum_grade` INT NOT NULL DEFAULT 0,
    `allowed_jobs` JSON DEFAULT NULL,
    `metadata` JSON DEFAULT NULL,
    `returnable` TINYINT(1) NOT NULL DEFAULT 1,
    `unlimited` TINYINT(1) NOT NULL DEFAULT 0,
    `cooldown` INT UNSIGNED NOT NULL DEFAULT 0,
    `locker_cooldown` INT UNSIGNED NOT NULL DEFAULT 0,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `deposit` INT UNSIGNED NOT NULL DEFAULT 0,
    `personal_bind` TINYINT(1) NOT NULL DEFAULT 0,
    `sort_order` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_locker_id` (`locker_id`),
    CONSTRAINT `fk_locker_items_locker`
        FOREIGN KEY (`locker_id`) REFERENCES `lockers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `locker_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `locker_id` INT UNSIGNED NOT NULL,
    `player_identifier` VARCHAR(80) NOT NULL,
    `player_name` VARCHAR(80) DEFAULT NULL,
    `action` VARCHAR(64) NOT NULL,
    `item_name` VARCHAR(64) DEFAULT NULL,
    `amount` INT DEFAULT NULL,
    `metadata` JSON DEFAULT NULL,
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_locker_logs_locker` (`locker_id`),
    KEY `idx_locker_logs_player` (`player_identifier`),
    KEY `idx_locker_logs_action` (`action`),
    CONSTRAINT `fk_locker_logs_locker`
        FOREIGN KEY (`locker_id`) REFERENCES `lockers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `locker_cooldowns` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `locker_id` INT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `player_identifier` VARCHAR(80) NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_cooldown` (`locker_id`, `item_id`, `player_identifier`),
    CONSTRAINT `fk_locker_cooldowns_locker`
        FOREIGN KEY (`locker_id`) REFERENCES `lockers` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_locker_cooldowns_item`
        FOREIGN KEY (`item_id`) REFERENCES `locker_items` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
