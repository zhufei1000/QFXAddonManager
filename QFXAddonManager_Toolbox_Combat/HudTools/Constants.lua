local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local addonName, RM = ...
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

RM.KEY = "raid_marker_panel"
RM.EVENT_OWNER = addonName .. ":events"
RM.BUTTON_SIZE = 26
RM.ICON_INSET = 2
RM.PANEL_PADDING = 3
RM.DEFAULT_POINT = "CENTER"
RM.DEFAULT_RELATIVE_POINT = "CENTER"
RM.DEFAULT_X = 0
RM.DEFAULT_Y = 80

RM.VALID_LAYOUTS = {
    horizontal = true,
    vertical = true,
}

RM.VALID_POSITIONS = {
    before = true,
    after = true,
}

-- Raid-target and world-marker indices use different orders. Match Blizzard's
-- WORLD_RAID_MARKER_ORDER (skull, cross, square, moon, triangle, diamond, circle, star).
RM.MARKERS = {
    { raidIndex = 8, worldIndex = 8, nameKey = "Skull",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { raidIndex = 7, worldIndex = 4, nameKey = "Cross",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    { raidIndex = 6, worldIndex = 1, nameKey = "Square",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    { raidIndex = 5, worldIndex = 7, nameKey = "Moon",     icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    { raidIndex = 4, worldIndex = 2, nameKey = "Triangle", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    { raidIndex = 3, worldIndex = 3, nameKey = "Diamond",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    { raidIndex = 2, worldIndex = 6, nameKey = "Circle",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    { raidIndex = 1, worldIndex = 5, nameKey = "Star",     icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
}

-- Drag-reorderable panel order. Keys: "1".."8" map to RM.MARKERS, "clear",
-- "countdown" and "ready" are the utility buttons. The countdown/ready entries
-- are filtered at layout time by their show switches, so the saved order can
-- include buttons that are currently hidden.
RM.BUTTON_ORDER_KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "clear", "countdown", "ready" }

-- Shared by the live panel and its drag-order settings; use the whole circle.
local actionMedia = "Interface\\AddOns\\QFXAddonManager_Toolbox_Combat\\HudTools\\Media\\"
RM.UTILITY_ICONS = {
    clear = actionMedia .. "raid-clear.blp",
    countdown = actionMedia .. "raid-countdown.blp",
    ready = actionMedia .. "raid-ready.blp",
}

-- Visible artwork bounds (left, top, right, bottom), measured at alpha >= 128
-- in the retained 1254px PNGs. Normalize display size without cropping the art.
RM.UTILITY_ICON_BOUNDS = {
    clear = { 100 / 1254, 107 / 1254, 1145 / 1254, 1147 / 1254 },
    countdown = { 130 / 1254, 130 / 1254, 1122 / 1254, 1126 / 1254 },
    ready = { 100 / 1254, 104 / 1254, 1153 / 1254, 1161 / 1254 },
}

end)
