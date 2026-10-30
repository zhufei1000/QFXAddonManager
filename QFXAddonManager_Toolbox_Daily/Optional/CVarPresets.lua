local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local _, ns = ...
ns = _G.QFXAddonManagerToolboxNS or ns

local KEY = "cvar_presets"
local mod = {}

-- 常用客户端 CVar 推荐预设（12.x 取值）。
-- 姓名板距离 60 码；不含 equipmentManager 与 spellActivationOverlayOpacity
-- （后者仅在用户勾选“关闭法术触发特效”时才写入 0）；
-- 伤害数字 CVar 由战斗数字模块管理，不纳入本预设。
local PRESET = {
    cameraDistanceMaxZoomFactor = "3.4",
    nameplateMaxDistance = "60",
    alwaysCompareItems = "1",
    chatClassColorOverride = "0",
    ffxDeath = "0",
    ffxGlow = "0",
    violenceLevel = "2",
    weatherdensity = "1",
    scriptErrors = "0",
    lossOfControl = "1",
    autoLootDefault = "1",
    chatStyle = "classic",
    whisperMode = "inline",
}

local STATUS_ORDER = {
    "cameraDistanceMaxZoomFactor",
    "nameplateMaxDistance",
    "alwaysCompareItems",
    "autoLootDefault",
    "chatStyle",
    "whisperMode",
    "ffxDeath",
    "ffxGlow",
    "violenceLevel",
    "weatherdensity",
    "scriptErrors",
    "lossOfControl",
}

-- 简化姓名板开关是 nameplateSimplifiedTypes 的位域（位 1-4），不能走普通 0/1 管线。
local SIMPLIFIED_NAMEPLATES_CVAR = "nameplateSimplifiedTypes"
local SIMPLIFIED_NAMEPLATES_SETTING = "simplifiedNameplatesDisabled"
local SIMPLIFIED_NAMEPLATES_FIRST_BIT = 1
local SIMPLIFIED_NAMEPLATES_LAST_BIT = 4

local pendingCVars
local pendingSpecialSettings

local function GetCVarSafe(name)
    if ns.Compat and ns.Compat.GetCVar then
        return ns.Compat.GetCVar(name, nil)
    end
    return nil
end

local function SetCVarSafe(name, value)
    if ns.Compat and ns.Compat.SetCVar then
        return ns.Compat.SetCVar(name, value)
    end
    return false
end

-- 12.0 起部分 CVar 改名为 *_v2；按 _v2 -> 原名的顺序取客户端实际存在的名字，
-- 客户端没有的 CVar（如 12.x 移除的 chatClassColorOverride）返回 nil 并跳过。
local function ResolveCVarName(cvar)
    if not cvar:match("_v2$") then
        local v2 = cvar .. "_v2"
        if GetCVarSafe(v2) ~= nil then return v2 end
    end
    if GetCVarSafe(cvar) ~= nil then return cvar end
    return nil
end

local function GetCVarValue(cvar)
    local name = ResolveCVarName(cvar)
    if not name then return nil end
    return GetCVarSafe(name)
end

local function SetCVarValue(cvar, value)
    local name = ResolveCVarName(cvar)
    if not name then return false end
    return SetCVarSafe(name, tostring(value))
end

local function InCombat()
    if ns.Compat and ns.Compat.InCombatLockdown then
        return ns.Compat.InCombatLockdown()
    end
    return false
end

-- ==================== 简化姓名板（位域专用设置） ====================

local function IsSimplifiedNameplatesSupported()
    return C_CVar
        and type(C_CVar.GetCVarBitfield) == "function"
        and type(C_CVar.SetCVarBitfield) == "function"
        and type(C_CVar.GetCVarDefault) == "function"
        and type(C_CVar.SetCVar) == "function"
end

-- 返回 true/全部禁用、false/仍有任一简化类型、nil/当前客户端无法可靠检测。
local function IsSimplifiedNameplatesDisabled()
    if not IsSimplifiedNameplatesSupported() then return nil end

    for index = SIMPLIFIED_NAMEPLATES_FIRST_BIT, SIMPLIFIED_NAMEPLATES_LAST_BIT do
        local ok, value = pcall(C_CVar.GetCVarBitfield, SIMPLIFIED_NAMEPLATES_CVAR, index)
        if not ok or type(value) ~= "boolean" then return nil end
        if value then return false end
    end
    return true
end

local function SetSimplifiedNameplatesDisabled(disabled)
    if not IsSimplifiedNameplatesSupported() then return false end

    if not disabled then
        local okDefault, defaultValue = pcall(C_CVar.GetCVarDefault, SIMPLIFIED_NAMEPLATES_CVAR)
        if not okDefault or type(defaultValue) ~= "string" then return false end
        local okSet = pcall(C_CVar.SetCVar, SIMPLIFIED_NAMEPLATES_CVAR, defaultValue)
        return okSet == true
    end

    -- 先读完整快照；任一位无法读取时不盲写。
    local previous = {}
    for index = SIMPLIFIED_NAMEPLATES_FIRST_BIT, SIMPLIFIED_NAMEPLATES_LAST_BIT do
        local ok, value = pcall(C_CVar.GetCVarBitfield, SIMPLIFIED_NAMEPLATES_CVAR, index)
        if not ok or type(value) ~= "boolean" then return false end
        previous[index] = value
    end

    for index = SIMPLIFIED_NAMEPLATES_FIRST_BIT, SIMPLIFIED_NAMEPLATES_LAST_BIT do
        local ok, success = pcall(C_CVar.SetCVarBitfield, SIMPLIFIED_NAMEPLATES_CVAR, index, false)
        if not ok or success ~= true then
            -- 写入中途失败时尽力恢复原位，不伪报成功。
            for rollbackIndex = SIMPLIFIED_NAMEPLATES_FIRST_BIT, index do
                pcall(C_CVar.SetCVarBitfield, SIMPLIFIED_NAMEPLATES_CVAR, rollbackIndex, previous[rollbackIndex])
            end
            return false
        end
    end

    return IsSimplifiedNameplatesDisabled() == true
end

-- ==================== 应用管线 ====================

local function QueueCVar(cvar, value)
    pendingCVars = pendingCVars or {}
    pendingCVars[cvar] = tostring(value)
end

local function QueueSpecialSetting(key, value)
    pendingSpecialSettings = pendingSpecialSettings or {}
    pendingSpecialSettings[key] = value and true or false
end

local function ApplyQueuedSettings()
    if InCombat() then return 0 end
    local applied = 0

    if pendingCVars then
        for cvar, value in pairs(pendingCVars) do
            if SetCVarValue(cvar, value) then
                pendingCVars[cvar] = nil
                applied = applied + 1
            end
        end
        if not next(pendingCVars) then pendingCVars = nil end
    end

    if pendingSpecialSettings then
        for key, desired in pairs(pendingSpecialSettings) do
            if SetSimplifiedNameplatesDisabled(desired) then
                pendingSpecialSettings[key] = nil
                applied = applied + 1
            end
        end
        if not next(pendingSpecialSettings) then pendingSpecialSettings = nil end
    end

    return applied
end

local function OnEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        ApplyQueuedSettings()
    end
end

-- 基准 = 推荐预设；db.customSettings 逐项覆盖基准。
local function GetCurrentSettings(db)
    local settings = {}
    for k, v in pairs(PRESET) do settings[k] = v end
    if type(db.customSettings) == "table" then
        for k, v in pairs(db.customSettings) do
            settings[k] = tostring(v)
        end
    end
    return settings
end

local function ApplyCVarSettings(db, settings)
    if not db or not db.enabled then return 0 end

    local inCombat = InCombat()
    local applied = 0
    for cvar, newValue in pairs(settings) do
        if ResolveCVarName(cvar) then
            if db.smartApply and tostring(GetCVarValue(cvar)) == tostring(newValue) then
                -- 数值一致，跳过以减少系统调用。
            elseif inCombat then
                QueueCVar(cvar, newValue)
                applied = applied + 1
            elseif SetCVarValue(cvar, newValue) then
                applied = applied + 1
            end
        end
    end
    return applied
end

local function ApplySpecialSettings(db)
    if not db or not db.enabled then return 0 end

    local settings = type(db.specialSettings) == "table" and db.specialSettings or {}
    local desired = settings[SIMPLIFIED_NAMEPLATES_SETTING]
    if desired == nil then return 0 end

    local current = IsSimplifiedNameplatesDisabled()
    if current == nil then return 0 end
    if db.smartApply and current == desired then return 0 end

    if InCombat() then
        QueueSpecialSetting(SIMPLIFIED_NAMEPLATES_SETTING, desired)
        return 1
    end
    if SetSimplifiedNameplatesDisabled(desired) then return 1 end
    return 0
end

local function ApplyCurrentSettings(db)
    return ApplyCVarSettings(db, GetCurrentSettings(db)) + ApplySpecialSettings(db)
end

-- value 为 nil 时只清除保存的覆盖值，不写 CVar（“禁用法术特效”取消勾选时同样不回写）。
local function SetCustomSetting(db, cvar, value)
    if not db or not db.enabled then return end
    db.customSettings = db.customSettings or {}
    if value == nil then
        db.customSettings[cvar] = nil
        return
    end

    db.customSettings[cvar] = tostring(value)
    if not ResolveCVarName(cvar) then return end
    if InCombat() then
        QueueCVar(cvar, value)
    else
        SetCVarValue(cvar, value)
    end
end

local function GetEffectiveCVar(db, cvar)
    local custom = db and type(db.customSettings) == "table" and db.customSettings[cvar]
    if custom ~= nil then return tostring(custom) end
    local value = GetCVarValue(cvar)
    if value ~= nil then return tostring(value) end
    return PRESET[cvar]
end

local function SetSpecialSettingIntent(db, value)
    if not db or not db.enabled then return false end
    db.specialSettings = db.specialSettings or {}
    db.specialSettings[SIMPLIFIED_NAMEPLATES_SETTING] = value and true or false

    if InCombat() then
        QueueSpecialSetting(SIMPLIFIED_NAMEPLATES_SETTING, value)
        return true
    end
    return SetSimplifiedNameplatesDisabled(value and true or false)
end

local function ResetToRecommended(db)
    db.customSettings = {}
    db.specialSettings = { [SIMPLIFIED_NAMEPLATES_SETTING] = true }
    ApplyCurrentSettings(db)
end

-- ==================== 模块生命周期 ====================

local EVENTS = { "PLAYER_REGEN_ENABLED" }

function mod:OnEnable(db)
    if ns.RegisterModuleEvents then ns.RegisterModuleEvents(KEY, EVENTS, OnEvent) end
end

function mod:OnDisable(db)
    if ns.UnregisterModuleEvents then ns.UnregisterModuleEvents(KEY, EVENTS) end
    pendingCVars = nil
    pendingSpecialSettings = nil
end

function mod:ApplySettings(db)
    if not db.enabled then
        if ns.UnregisterModuleEvents then ns.UnregisterModuleEvents(KEY, EVENTS) end
        return
    end
    if ns.RegisterModuleEvents then ns.RegisterModuleEvents(KEY, EVENTS, OnEvent) end
    if db.autoApply then
        ApplyCurrentSettings(db)
    end
end

-- ==================== 状态显示 ====================

local function StatusLine()
    local lines = {}
    local current = {}
    for _, cvar in ipairs(STATUS_ORDER) do
        local name = ResolveCVarName(cvar) or cvar
        current[#current + 1] = name .. "=" .. tostring(GetCVarSafe(name) or "?")
        if #current == 5 then
            lines[#lines + 1] = table.concat(current, ", ")
            current = {}
        end
    end
    if #current > 0 then
        lines[#lines + 1] = table.concat(current, ", ")
    end
    return table.concat(lines, "\n")
end

-- ==================== 设置界面 ====================

local function MakeModuleEnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        return true
    end
end

local function MakeSimplifiedNameplatesRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        if not IsSimplifiedNameplatesSupported() then
            return false, ui.L("Simplified nameplate bitfield API is unavailable on this client.")
        end
        return true
    end
end

ns.RegisterModule(KEY, {
    titleKey = "CVar Presets",
    descKey = "Apply a curated recommended CVar preset, with per-option overrides.",
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local enabledRule = MakeModuleEnabledRule(db, ui)

                local s = page:NewSection(ui.L("CVar Presets"))
                s:Check(ui.L("Enable"), function() return db.enabled end, function(v)
                    ns.SetModuleEnabled(KEY, v)
                end, ui.L("A curated recommended preset applied automatically at login; every option can be overridden below."))
                s:CheckGrid({
                    {
                        label = ui.L("Auto Apply at Login"),
                        getValue = function() return db.autoApply ~= false end,
                        setValue = function(v)
                            db.autoApply = v and true or false
                            if v and db.enabled then ApplyCurrentSettings(db) end
                        end,
                        note = ui.L("Check: apply the merged preset automatically at login or when this module is enabled. Uncheck: apply only via the Apply Now button or option changes."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Smart Apply"),
                        getValue = function() return db.smartApply ~= false end,
                        setValue = function(v) db.smartApply = v and true or false end,
                        note = ui.L("Check: only write values that differ from the current client value. Uncheck: rewrite every preset value on each apply."),
                        enabled = enabledRule,
                    },
                }, { columns = 2 })
                s:ButtonRow({
                    { text = ui.L("Apply Now"), width = 92, onClick = function() ApplyCurrentSettings(db); ui.Refresh() end },
                    { text = ui.L("Reset to Recommended"), width = 128, onClick = function() ResetToRecommended(db); ui.Refresh() end },
                })
                page:AddSection(s)

                local common = page:NewSection(ui.L("Common Settings"))
                common:CheckGrid({
                    {
                        label = ui.L("Auto Compare Items"),
                        getValue = function() return GetEffectiveCVar(db, "alwaysCompareItems") == "1" end,
                        setValue = function(v) SetCustomSetting(db, "alwaysCompareItems", v and "1" or "0") end,
                        note = ui.L("Check: hovering over gear automatically compares stats with equipped items. Uncheck: disable auto comparison."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Nameplates 60yd (Uncheck = 20yd)"),
                        getValue = function() return (tonumber(GetEffectiveCVar(db, "nameplateMaxDistance")) or 0) >= 60 end,
                        setValue = function(v) SetCustomSetting(db, "nameplateMaxDistance", v and "60" or "20") end,
                        note = ui.L("Check: nameplate max distance is 60 yards. Uncheck: 20 yards."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Simplified Nameplates (Check = Disable)"),
                        getValue = function() return IsSimplifiedNameplatesDisabled() == true end,
                        setValue = function(v) SetSpecialSettingIntent(db, v) end,
                        note = ui.L("Check: disable simplified nameplates so minions, minor units, friendly players and friendly NPCs show full nameplates. Uncheck: restore Blizzard defaults."),
                        enabled = MakeSimplifiedNameplatesRule(db, ui),
                    },
                    {
                        label = ui.L("Lua Error Popups (Check = Block)"),
                        getValue = function() return GetEffectiveCVar(db, "scriptErrors") == "0" end,
                        setValue = function(v) SetCustomSetting(db, "scriptErrors", v and "0" or "1") end,
                        note = ui.L("Check: silence Lua error popups. Uncheck: show Lua error popups (useful when debugging addons)."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Auto Loot"),
                        getValue = function() return GetEffectiveCVar(db, "autoLootDefault") == "1" end,
                        setValue = function(v) SetCustomSetting(db, "autoLootDefault", v and "1" or "0") end,
                        note = ui.L("Check: enable auto loot. Uncheck: disable auto loot."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Loss of Control Alert"),
                        getValue = function() return GetEffectiveCVar(db, "lossOfControl") == "1" end,
                        setValue = function(v) SetCustomSetting(db, "lossOfControl", v and "1" or "0") end,
                        note = ui.L("Check: show Blizzard's stun, silence and other loss-of-control warnings. Uncheck: hide them."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Spell Activation Effects (Check = Hide)"),
                        getValue = function() return (tonumber(GetEffectiveCVar(db, "spellActivationOverlayOpacity")) or 1) == 0 end,
                        setValue = function(v)
                            if v then
                                SetCustomSetting(db, "spellActivationOverlayOpacity", "0")
                            else
                                -- 取消勾选只清除覆盖值，不回写透明度。
                                SetCustomSetting(db, "spellActivationOverlayOpacity", nil)
                            end
                        end,
                        note = ui.L("Check: spell activation overlay opacity is set to 0, hiding screen-center proc effects. Uncheck: only clears this addon's override; the opacity keeps its current value."),
                        enabled = enabledRule,
                    },
                }, { columns = 2 })
                page:AddSection(common)

                -- 地图入口模块的开关并入本页，不再单独占一个导航入口。
                local mapDB = ns.GetModuleDB and ns.GetModuleDB("map_entrances") or nil
                if mapDB and not ui.omitMapEntrances then
                    local map = page:NewSection(ui.L("Map Entrances"))
                    map:Check(ui.L("Enable"), function() return mapDB.enabled end, function(v)
                        ns.SetModuleEnabled("map_entrances", v)
                    end, ui.L("When enabled, the selected entrance filters are applied automatically at login."))
                    map:CheckGrid({
                        {
                            label = ui.L("Show Delve Entrances"),
                            getValue = function() return mapDB.showDelveEntrances ~= false end,
                            setValue = function(v)
                                mapDB.showDelveEntrances = v and true or false
                                ns.ApplyModule("map_entrances")
                            end,
                            note = ui.L("Check: show delve entrance pins on the world map. Uncheck: hide them."),
                        },
                        {
                            label = ui.L("Show Dungeon Entrances"),
                            getValue = function() return mapDB.showDungeonEntrances ~= false end,
                            setValue = function(v)
                                mapDB.showDungeonEntrances = v and true or false
                                ns.ApplyModule("map_entrances")
                            end,
                            note = ui.L("Check: show dungeon entrance pins on the world map. Uncheck: hide them."),
                        },
                    }, { columns = 2 })
                    map:DynamicText(function()
                        local function current(name)
                            return tostring((ns.Compat and ns.Compat.GetCVar and ns.Compat.GetCVar(name, "?")) or "?")
                        end
                        return "showDelveEntrancesOnMap=" .. current("showDelveEntrancesOnMap")
                            .. ", showDungeonEntrancesOnMap=" .. current("showDungeonEntrancesOnMap")
                    end, ui.Colors.warning, 24)
                    page:AddSection(map)
                end

                local chat = page:NewSection(ui.L("Chat"))
                chat:Dropdown(ui.L("Chat Style"), function()
                    return GetEffectiveCVar(db, "chatStyle") or "classic"
                end, function(v)
                    SetCustomSetting(db, "chatStyle", v)
                end, {
                    { value = "classic", text = ui.L("Classic Style") },
                    { value = "im", text = ui.L("Instant Messaging Style") },
                }, 108, 170, { enabled = enabledRule, note = ui.L("Choose the chat box style.") })
                chat:Dropdown(ui.L("Whisper Mode"), function()
                    return GetEffectiveCVar(db, "whisperMode") or "inline"
                end, function(v)
                    SetCustomSetting(db, "whisperMode", v)
                end, {
                    { value = "inline", text = ui.L("Inline Mode") },
                    { value = "popout_and_inline", text = ui.L("Both") },
                    { value = "popout", text = ui.L("New Tab") },
                }, 108, 170, { enabled = enabledRule, note = ui.L("Choose how whispers are displayed.") })
                page:AddSection(chat)

                local camera = page:NewSection(ui.L("Camera"))
                camera:ValueSlider(ui.L("Camera Distance"), 1, 3.4, 0.1, function()
                    return tonumber(GetEffectiveCVar(db, "cameraDistanceMaxZoomFactor")) or 3.4
                end, function(v)
                    SetCustomSetting(db, "cameraDistanceMaxZoomFactor", v)
                end, { decimals = 1, enabled = enabledRule, note = ui.L("Max camera zoom-out distance. CVar range: 1 - 3.4.") })
                page:AddSection(camera)

                if not ui.summary then
                    local status = page:NewSection(ui.L("CVar Status"))
                    status:DynamicText(StatusLine, ui.Colors.warning, 64)
                    page:AddSection(status)
                end
            end,
        },
        {
            key = "visual",
            titleKey = "Visual",
            build = function(page, db, info, ui)
                local enabledRule = MakeModuleEnabledRule(db, ui)

                local s = page:NewSection(ui.L("Visual Settings"))
                s:CheckGrid({
                    {
                        label = ui.L("Death Effect (Check = Off)"),
                        getValue = function() return GetEffectiveCVar(db, "ffxDeath") == "0" end,
                        setValue = function(v) SetCustomSetting(db, "ffxDeath", v and "0" or "1") end,
                        note = ui.L("Check: the death screen effect is turned off. Uncheck: the death effect is turned on."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Fullscreen Glow (Check = Off)"),
                        getValue = function() return GetEffectiveCVar(db, "ffxGlow") == "0" end,
                        setValue = function(v) SetCustomSetting(db, "ffxGlow", v and "0" or "1") end,
                        note = ui.L("Check: fullscreen glow is turned off. Uncheck: fullscreen glow is turned on."),
                        enabled = enabledRule,
                    },
                }, { columns = 2 })
                page:AddSection(s)

                local sliders = page:NewSection(ui.L("Environment Effects"))
                sliders:ValueSlider(ui.L("Weather Intensity"), 0, 3, 1, function()
                    return tonumber(GetEffectiveCVar(db, "weatherdensity")) or 1
                end, function(v)
                    SetCustomSetting(db, "weatherdensity", v)
                end, { enabled = enabledRule, note = ui.L("Weather effect density. 0 = off, 3 = intense.") })
                sliders:ValueSlider(ui.L("Violence Level"), 0, 5, 1, function()
                    return tonumber(GetEffectiveCVar(db, "violenceLevel")) or 2
                end, function(v)
                    SetCustomSetting(db, "violenceLevel", v)
                end, { enabled = enabledRule, note = ui.L("Blood and violence effect strength. 0 = none, 5 = maximum.") })
                page:AddSection(sliders)

                if not ui.summary then
                    local status = page:NewSection(ui.L("CVar Status"))
                    status:DynamicText(StatusLine, ui.Colors.warning, 64)
                    page:AddSection(status)
                end
            end,
        },
    },
})

end)
