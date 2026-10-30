local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local KEY = "combat_numbers"
local mod = {}

-- 12.0 后优先使用 _v2；旧版只作为兼容回退。
-- 参数范围按目前可查到的 CVar 规则，不再随意扩大：
-- WorldTextScale_v2: 0.1 - 3.0，默认 1，支持小数。
-- floatingCombatTextCombatDamageDirectionalScale_v2: 0 - 5，整数档位。
local CVARS = {
    size = { "WorldTextScale_v2", "WorldTextScale" },
    damageEnable = { "floatingCombatTextCombatDamage_v2", "floatingCombatTextCombatDamage" },
    healingEnable = { "floatingCombatTextCombatHealing_v2", "floatingCombatTextCombatHealing" },
    periodicEnable = { "floatingCombatTextCombatLogPeriodicSpells_v2", "floatingCombatTextCombatLogPeriodicSpells" },
    petMeleeEnable = { "floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetMeleeDamage" },
    petSpellEnable = { "floatingCombatTextPetSpellDamage_v2", "floatingCombatTextPetSpellDamage" },
    damageMotion = { "floatingCombatTextCombatDamageDirectionalScale_v2", "floatingCombatTextCombatDamageDirectionalScale" },
    separator = { "breakUpLargeNumbers" },
}

local LIMITS = {
    sizeMin = 0.1,
    sizeMax = 3.0,
    sizeStep = 0.1,
    motionMin = 0,
    motionMax = 5,
    motionStep = 1,
}

local function L(key)
    return ns.L and ns.L(key) or key
end

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

local function FirstExisting(list)
    for _, name in ipairs(list or {}) do
        if GetCVarSafe(name) ~= nil then return name end
    end
    return list and list[1]
end

local function SetFirst(list, value)
    local name = FirstExisting(list)
    if not name then return false end
    return SetCVarSafe(name, value), name
end

local function GetFirst(list, fallback)
    local name = FirstExisting(list)
    local value = name and GetCVarSafe(name)
    if value == nil or value == "" then return fallback, name end
    local n = tonumber(value)
    if n ~= nil then return n, name end
    return value, name
end

local function ReadBoolCVar(list, fallback)
    local value = GetFirst(list, nil)
    if value == nil or value == "" then return fallback and true or false end
    if type(value) == "number" then return value ~= 0 end
    value = tostring(value):lower()
    if value == "1" or value == "true" or value == "yes" or value == "on" then return true end
    if value == "0" or value == "false" or value == "no" or value == "off" then return false end
    return fallback and true or false
end

local function B(v)
    return v and "1" or "0"
end

local function RoundStep(value, step)
    value = tonumber(value) or 0
    step = tonumber(step) or 1
    if step > 0 then
        value = math.floor(value / step + 0.5) * step
    end
    return value
end

local function ClampStep(value, minValue, maxValue, step)
    value = RoundStep(value, step)
    if minValue and value < minValue then value = minValue end
    if maxValue and value > maxValue then value = maxValue end
    return value
end

local function SyncFromClientCVars(db)
    if not db then return end

    local rawSize = GetFirst(CVARS.size, nil)
    local size = tonumber(rawSize)
    if size then
        db.worldTextScale = ClampStep(size, LIMITS.sizeMin, LIMITS.sizeMax, LIMITS.sizeStep)
    end

    db.showDamage = ReadBoolCVar(CVARS.damageEnable, db.showDamage ~= false)
    db.showHealing = ReadBoolCVar(CVARS.healingEnable, db.showHealing ~= false)
    db.showPeriodic = ReadBoolCVar(CVARS.periodicEnable, db.showPeriodic ~= false)
    db.showPetMelee = ReadBoolCVar(CVARS.petMeleeEnable, db.showPetMelee ~= false)
    db.showPetSpell = ReadBoolCVar(CVARS.petSpellEnable, db.showPetSpell ~= false)

    local rawMotion = GetFirst(CVARS.damageMotion, nil)
    local motion = tonumber(rawMotion)
    if motion then
        db.damageMotion = ClampStep(motion, LIMITS.motionMin, LIMITS.motionMax, LIMITS.motionStep)
    end

    db.keepSeparators = ReadBoolCVar(CVARS.separator, db.keepSeparators ~= false)
    db.clientSnapshotTaken = true
end

local function MarkUserConfigured(db)
    if db then
        db.userConfigured = true
        db.clientSnapshotTaken = true
    end
end

-- 禁用即恢复：首次初始化时拍下客户端原值快照（精确原字符串），之后只读
-- 不写；OnDisable 把快照写回，插件改过的 CVar 不会残留。
local function SnapshotClientCVars(db)
    if not db then return end
    if type(db.clientSnapshot) == "table" then return end
    local snap = {}
    for _, list in pairs(CVARS) do
        local name = FirstExisting(list)
        if name then
            local value = GetCVarSafe(name)
            if value ~= nil then snap[name] = tostring(value) end
        end
    end
    db.clientSnapshot = snap
end

local function RestoreClientCVars(db)
    local snap = db and db.clientSnapshot
    if type(snap) ~= "table" then return end
    for _, list in pairs(CVARS) do
        local name = FirstExisting(list)
        if name and snap[name] ~= nil then
            SetCVarSafe(name, snap[name])
        end
    end
end

local function ApplyAll(db)
    if not db then return end
    if not db.userConfigured and not db.clientSnapshotTaken then
        SyncFromClientCVars(db)
    end
    if not db.enabled then return end

    local size = ClampStep(db.worldTextScale or 1, LIMITS.sizeMin, LIMITS.sizeMax, LIMITS.sizeStep)
    db.worldTextScale = size
    SetFirst(CVARS.size, size)

    SetFirst(CVARS.damageEnable, B(db.showDamage ~= false))
    SetFirst(CVARS.healingEnable, B(db.showHealing ~= false))
    SetFirst(CVARS.periodicEnable, B(db.showPeriodic ~= false))
    SetFirst(CVARS.petMeleeEnable, B(db.showPetMelee ~= false))
    SetFirst(CVARS.petSpellEnable, B(db.showPetSpell ~= false))

    local motion = ClampStep(db.damageMotion or 1, LIMITS.motionMin, LIMITS.motionMax, LIMITS.motionStep)
    db.damageMotion = motion
    SetFirst(CVARS.damageMotion, motion)

    SetFirst(CVARS.separator, db.keepSeparators == false and "0" or "1")
end

function mod:OnInitialize(db)
    SnapshotClientCVars(db)
    if db and not db.userConfigured and not db.clientSnapshotTaken then
        SyncFromClientCVars(db)
    end
end

function mod:OnEnable(db)
    SnapshotClientCVars(db)
    ApplyAll(db)
end

function mod:OnDisable(db)
    RestoreClientCVars(db)
end

function mod:ApplySettings(db)
    ApplyAll(db)
end

local function MotionOptions()
    return {
        { value = 0, text = "0 - " .. L("Straight Up") },
        { value = 1, text = "1 - " .. L("Small Spread") },
        { value = 2, text = "2 - " .. L("Medium Spread") },
        { value = 3, text = "3 - " .. L("Diagonal Spread") },
        { value = 4, text = "4 - " .. L("Strong Spread") },
        { value = 5, text = "5 - " .. L("Random Spread") },
    }
end

local function MakeModuleEnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        return true
    end
end

local function MakeDamageEnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        if db.showDamage == false then return false, ui.L("Enable Show Damage first.") end
        return true
    end
end

local function MakeAnyNumberEnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        if db.showDamage == false and db.showHealing == false then
            return false, ui.L("Enable damage or healing numbers first.")
        end
        return true
    end
end

local function StatusLine()
    local size, sizeName = GetFirst(CVARS.size, "?")
    local dmg, dmgName = GetFirst(CVARS.damageEnable, "?")
    local heal, healName = GetFirst(CVARS.healingEnable, "?")
    local motion, motionName = GetFirst(CVARS.damageMotion, "?")
    return string.format("%s=%s, %s=%s, %s=%s, %s=%s",
        tostring(sizeName or "WorldTextScale"), tostring(size),
        tostring(dmgName or "Damage"), tostring(dmg),
        tostring(healName or "Healing"), tostring(heal),
        tostring(motionName or "DamageMotion"), tostring(motion))
end

ns.RegisterModule(KEY, {
    titleKey = "Combat Numbers",
    descKey = "Adjust default floating combat text size and movement.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Combat Numbers") .. " / " .. ui.L("Basic"))
                s:Check(ui.L("Enable"), function() return db.enabled end, function(v)
                    ns.SetModuleEnabled(KEY, v)
                end, ui.L("New 12.0 CVars are used first, old CVars are fallback."))
                s:ButtonRow({
                    { text = ui.L("Apply Now"), width = 92, onClick = function() ApplyAll(db) end },
                    { text = ui.L("Read Current Client Settings"), width = 158, onClick = function()
                        db.userConfigured = false
                        db.clientSnapshot = nil
                        SnapshotClientCVars(db)
                        SyncFromClientCVars(db)
                        ApplyAll(db)
                        ui.Refresh()
                    end },
                    { text = ui.L("Restore Defaults"), width = 108, onClick = function()
                        -- 战斗数字不再写死插件默认值；这里回读玩家当前客户端 CVar。
                        db.userConfigured = false
                        db.clientSnapshotTaken = false
                        db.clientSnapshot = nil
                        SnapshotClientCVars(db)
                        SyncFromClientCVars(db)
                        ApplyAll(db)
                        ui.Refresh()
                    end },
                })
                page:AddSection(s)

                if not ui.summary then
                    local s2 = page:NewSection(ui.L("CVar Status"))
                    s2:DynamicText(StatusLine, ui.Colors.warning, 48)
                    page:AddSection(s2)
                end
            end,
        },
        {
            key = "numbers",
            titleKey = "Numbers",
            build = function(page, db, info, ui)
                local enabledRule = MakeModuleEnabledRule(db, ui)
                local damageRule = MakeDamageEnabledRule(db, ui)
                local anyNumberRule = MakeAnyNumberEnabledRule(db, ui)
                local s = page:NewSection(ui.L("Numbers"))
                s:ValueSlider(ui.L("Number Size"), LIMITS.sizeMin, LIMITS.sizeMax, LIMITS.sizeStep, function()
                    return db.worldTextScale or 1
                end, function(v)
                    MarkUserConfigured(db)
                    db.worldTextScale = v
                    if db.enabled then ApplyAll(db) end
                end, { decimals = 1, enabled = anyNumberRule, note = ui.L("Shared by damage and healing. CVar range: 0.1 - 3.0, default 1.") })
                s:CheckGrid({
                    {
                        label = ui.L("Show Damage"),
                        getValue = function() return db.showDamage ~= false end,
                        setValue = function(v)
                            MarkUserConfigured(db)
                            db.showDamage = v and true or false
                            if db.enabled then ApplyAll(db) end
                        end,
                        note = ui.L("Master switch for damage-related combat text."),
                        enabled = enabledRule,
                    },
                    {
                        label = ui.L("Show Healing"),
                        getValue = function() return db.showHealing ~= false end,
                        setValue = function(v)
                            MarkUserConfigured(db)
                            db.showHealing = v and true or false
                            if db.enabled then ApplyAll(db) end
                        end,
                        note = ui.L("Master switch for healing combat text."),
                        enabled = enabledRule,
                    },
                }, { columns = 2 })
                page:AddSection(s)

                local s2 = page:NewSection(ui.L("Damage Details"))
                s2:CheckGrid({
                    {
                        label = ui.L("Show DoT Damage"),
                        getValue = function() return db.showPeriodic ~= false end,
                        setValue = function(v)
                            MarkUserConfigured(db)
                            db.showPeriodic = v and true or false
                            if db.enabled then ApplyAll(db) end
                        end,
                        note = ui.L("This option depends on Show Damage."),
                        enabled = damageRule,
                    },
                    {
                        label = ui.L("Show Pet Melee"),
                        getValue = function() return db.showPetMelee ~= false end,
                        setValue = function(v)
                            MarkUserConfigured(db)
                            db.showPetMelee = v and true or false
                            if db.enabled then ApplyAll(db) end
                        end,
                        note = ui.L("This option depends on Show Damage."),
                        enabled = damageRule,
                    },
                    {
                        label = ui.L("Show Pet Spell"),
                        getValue = function() return db.showPetSpell ~= false end,
                        setValue = function(v)
                            MarkUserConfigured(db)
                            db.showPetSpell = v and true or false
                            if db.enabled then ApplyAll(db) end
                        end,
                        note = ui.L("This option depends on Show Damage."),
                        enabled = damageRule,
                    },
                    {
                        label = ui.L("Keep Thousand Separators"),
                        getValue = function() return db.keepSeparators ~= false end,
                        setValue = function(v)
                            MarkUserConfigured(db)
                            db.keepSeparators = v and true or false
                            if db.enabled then ApplyAll(db) end
                        end,
                        note = ui.L("Only useful when damage or healing numbers are enabled."),
                        enabled = anyNumberRule,
                    },
                }, { columns = 2 })
                page:AddSection(s2)

                local s3 = page:NewSection(ui.L("Motion"))
                s3:Dropdown(ui.L("Damage Motion"), function() return db.damageMotion or 1 end, function(v)
                    MarkUserConfigured(db)
                    db.damageMotion = tonumber(v) or 1
                    if db.enabled then ApplyAll(db) end
                end, MotionOptions(), 108, 210, { enabled = damageRule, note = ui.L("CVar range: 0 - 5. Integer only. This option depends on Show Damage.") })
                page:AddSection(s3)
            end,
        },
        {
            key = "cvars",
            titleKey = "System CVars",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("System CVars"))
                s:DynamicText(StatusLine, ui.Colors.warning, 64)
                page:AddSection(s)
            end,
        },
    },
})

end)
