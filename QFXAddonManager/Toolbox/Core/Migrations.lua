local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local CURRENT_SCHEMA = tonumber(ns.defaults and ns.defaults.schemaVersion) or 10

local DEPRECATED_MODULE_KEYS = {
    party_interrupt = true,
}

local function EnsureModules(db)
    if type(db) ~= "table" then return nil end
    if type(db.modules) ~= "table" then db.modules = {} end
    return db.modules
end

local function CleanupDeprecatedModules(db)
    local modules = EnsureModules(db)
    if not modules then return end
    for key in pairs(DEPRECATED_MODULE_KEYS) do
        modules[key] = nil
    end
end

local function CleanupMythicPlusTools(db)
    local modules = EnsureModules(db)
    local mplus = modules and modules.mythic_plus_tools
    if type(mplus) ~= "table" then return end

    -- Teleport announcement was removed; strip all old switches so SavedVariables
    -- cannot resurrect hidden UI or behavior after a settings restore.
    mplus.enableTeleport = nil
    mplus.announceTeleport = nil
    mplus.announceTeleportToParty = nil
    mplus.teleportAnnounce = nil
    mplus.teleportAnnouncementEnabled = nil
    mplus.teleportAnnouncementTiming = nil
    mplus.teleportAnnouncementSuffix = nil
    mplus.teleportAnnouncementDebug = nil
end


local function MigrateChatBarEditBoxLayout(db)
    local modules = EnsureModules(db)
    local chatBar = modules and modules.chat_bar
    if type(chatBar) ~= "table" then return end

    local legacyAlignment = chatBar.editBoxAlignment
    if chatBar.editBoxWidthMode == nil then
        if legacyAlignment == "left" or legacyAlignment == "right" then
            chatBar.editBoxWidthMode = "original"
        else
            chatBar.editBoxWidthMode = "chatbar"
        end
    end

    if legacyAlignment == "right" then
        chatBar.editBoxAlignment = "right"
    else
        chatBar.editBoxAlignment = "left"
    end
end

-- Retired focus module saves remain dormant for rollback; QFXfocus owns its own save.

local MIGRATIONS = {
    [9] = function(db)
        CleanupDeprecatedModules(db)
        CleanupMythicPlusTools(db)
    end,
    [10] = function(db)
        MigrateChatBarEditBoxLayout(db)
    end,
}

function ns.MigrateDB(db)
    if type(db) ~= "table" then return db end

    EnsureModules(db)

    local fromSchema = tonumber(db.schemaVersion) or 0
    for version = fromSchema + 1, CURRENT_SCHEMA do
        local migrate = MIGRATIONS[version]
        if migrate then migrate(db) end
    end

    -- Always run idempotent cleanup once, even if the schema already matches. This catches
    -- manually edited SavedVariables and old data restored from backups.
    CleanupDeprecatedModules(db)
    CleanupMythicPlusTools(db)

    db.schemaVersion = CURRENT_SCHEMA
    return db
end

end)
