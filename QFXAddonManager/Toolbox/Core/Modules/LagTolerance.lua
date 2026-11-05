local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local KEY = "lag_tolerance"
local mod = {}
local CVAR = "SpellQueueWindow"

local IS_FOREVER = false
if ns.Compat and type(ns.Compat.IsForever) == "function" then
    local ok, forever = pcall(ns.Compat.IsForever)
    IS_FOREVER = ok and forever == true
end

local function L(key)
    return ns.L and ns.L(key) or key
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local function Clamp(value, fallback)
    value = tonumber(value)
    if value == nil then value = tonumber(fallback) or 400 end
    if value < 0 then value = 0 end
    if value > 400 then value = 400 end
    return math.floor(value + 0.5)
end

local function GetCVarSafe(name)
    if ns.Compat and ns.Compat.GetCVar then
        return ns.Compat.GetCVar(name, nil)
    end
    return nil
end

local function SetCVarSafe(name, value)
    if ns.Compat and ns.Compat.SetCVar then
        return ns.Compat.SetCVar(name, Clamp(value, 400))
    end
    return false
end

local function ReadCurrentCVarValue(fallback)
    return Clamp(GetCVarSafe(CVAR), fallback)
end

local function EnsureClientDefaults(db)
    if not db then return end
    db.specs = db.specs or {}
end

local function GetCurrentSpecID()
    if ns.Compat and ns.Compat.GetPlayerSpecializationID then
        return ns.Compat.GetPlayerSpecializationID(nil)
    end
    return nil
end

-- Forever has Classic talent trees, not the modern specialization API. Use a
-- single per-character bucket there so the tool still saves and applies a value.
local function GetCurrentSpecKey()
    local specID = GetCurrentSpecID()
    if specID then return tostring(specID) end
    if IS_FOREVER then return "classic" end
    return nil
end

local function GetSpecValue(db, specID)
    EnsureClientDefaults(db)
    if not specID then return ReadCurrentCVarValue(400) end
    local value = db.specs[tostring(specID)]
    if value == nil then return ReadCurrentCVarValue(400) end
    return Clamp(value, ReadCurrentCVarValue(400))
end

-- 专精列表显示值：保存值优先；当前专精未保存时显示客户端实时值；其余未保存显示 400。
local function SpecDisplayValue(db, specID, currentSpecID)
    local saved = db.specs and db.specs[tostring(specID)]
    if saved ~= nil then return Clamp(saved, 400) end
    if specID == currentSpecID then return ReadCurrentCVarValue(400) end
    return 400
end

local function SetSpecValue(db, specID, value)
    EnsureClientDefaults(db)
    if not specID then return end
    db.specs[tostring(specID)] = Clamp(value, 400)
end

local function Apply(db)
    EnsureClientDefaults(db)
    if not db or not db.enabled then return end
    local key = GetCurrentSpecKey()
    if not key then return end
    -- 只读不写：该专精没有保存值时尊重用户当前客户端容限，只有保存过数值才强制应用。
    -- Clamp 收敛在 SetCVarSafe 内做一次即可。
    local saved = db.specs[key]
    if saved == nil then
        return
    end
    SetCVarSafe(CVAR, saved)
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED" }

local function OnEvent(event)
    local db = ns.GetModuleDB(KEY)
    if not db or not db.enabled then return end
    if event == "PLAYER_ENTERING_WORLD" then
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function() Apply(ns.GetModuleDB(KEY)) end)
        else
            Apply(db)
        end
    else
        Apply(db)
        if ns.RequestConfigRefresh then ns.RequestConfigRefresh("lag-tolerance") elseif ns.RefreshConfig then ns.RefreshConfig() end
    end
end

local function RegisterEvents()
    if ns.RegisterModuleEvents then ns.RegisterModuleEvents(KEY, EVENTS, OnEvent) end
end

local function UnregisterEvents()
    if ns.UnregisterModuleEvents then ns.UnregisterModuleEvents(KEY, EVENTS) end
end

function mod:OnInitialize(db)
    EnsureClientDefaults(db)
    -- 一次性清理旧版本"登录时自动收编客户端值"写入的保存数据：
    -- 那些不是用户显式设置的值，按新语义不应显示为已保存、也不应被强制应用。
    if not db.legacyAdoptionsPurged then
        db.legacyAdoptionsPurged = true
        db.specs = {}
    end
end

function mod:OnEnable(db)
    EnsureClientDefaults(db)
    RegisterEvents()
    Apply(db)
end

function mod:OnDisable(db)
    UnregisterEvents()
end

function mod:ApplySettings(db)
    EnsureClientDefaults(db)
    if db.enabled then
        RegisterEvents()
        Apply(db)
    else
        UnregisterEvents()
    end
end

-- 全职业专精表：专精 ID 是暴雪固定编号，德鲁伊（4 个专精）排在最后。
-- 名称与图标优先通过客户端按 classID 枚举取本地化数据，接口不可用时回退到表里的英文短名。
local CLASS_SPECS = {
    { classFile = "DEATHKNIGHT", specs = { { id = 250, label = "Blood" }, { id = 251, label = "Frost" }, { id = 252, label = "Unholy" } } },
    { classFile = "DEMONHUNTER", specs = { { id = 577, label = "Havoc" }, { id = 581, label = "Vengeance" }, { id = 1480, label = "San'layn" } } },
    { classFile = "EVOKER", specs = { { id = 1467, label = "Devastation" }, { id = 1468, label = "Preservation" }, { id = 1473, label = "Augmentation" } } },
    { classFile = "HUNTER", specs = { { id = 253, label = "Beast Mastery" }, { id = 254, label = "Marksmanship" }, { id = 255, label = "Survival" } } },
    { classFile = "MAGE", specs = { { id = 62, label = "Arcane" }, { id = 63, label = "Fire" }, { id = 64, label = "Frost" } } },
    { classFile = "MONK", specs = { { id = 268, label = "Brewmaster" }, { id = 269, label = "Windwalker" }, { id = 270, label = "Mistweaver" } } },
    { classFile = "PALADIN", specs = { { id = 65, label = "Holy" }, { id = 66, label = "Protection" }, { id = 70, label = "Retribution" } } },
    { classFile = "PRIEST", specs = { { id = 256, label = "Discipline" }, { id = 257, label = "Holy" }, { id = 258, label = "Shadow" } } },
    { classFile = "ROGUE", specs = { { id = 259, label = "Assassination" }, { id = 260, label = "Outlaw" }, { id = 261, label = "Subtlety" } } },
    { classFile = "SHAMAN", specs = { { id = 262, label = "Elemental" }, { id = 263, label = "Enhancement" }, { id = 264, label = "Restoration" } } },
    { classFile = "WARLOCK", specs = { { id = 265, label = "Affliction" }, { id = 266, label = "Demonology" }, { id = 267, label = "Destruction" } } },
    { classFile = "WARRIOR", specs = { { id = 71, label = "Arms" }, { id = 72, label = "Fury" }, { id = 73, label = "Protection" } } },
    { classFile = "DRUID", specs = { { id = 102, label = "Balance" }, { id = 103, label = "Feral" }, { id = 104, label = "Guardian" }, { id = 105, label = "Restoration" } } },
}

-- 12.x 上按专精 ID 查询的旧全局函数已不可用；按 classID 枚举
-- GetSpecializationInfoForClassID 是可靠的本地化名称/图标来源。缓存只建一次；
-- 若登录前数据还不可用则不缓存，登录后首次打开面板会重新尝试。
local specInfoCache

local function BuildSpecInfoCache()
    if specInfoCache then return specInfoCache end
    local cache = {}
    for classID = 1, 13 do
        local numSpecs = 0
        if C_SpecializationInfo and type(C_SpecializationInfo.GetNumSpecializationsForClassID) == "function" then
            local ok, count = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
            if ok then numSpecs = tonumber(count) or 0 end
        elseif type(GetNumSpecializationsForClassID) == "function" then
            local ok, count = pcall(GetNumSpecializationsForClassID, classID)
            if ok then numSpecs = tonumber(count) or 0 end
        end
        if type(GetSpecializationInfoForClassID) == "function" then
            for index = 1, numSpecs do
                local ok, specID, name, _, icon = pcall(GetSpecializationInfoForClassID, classID, index)
                if ok and specID ~= nil and type(name) == "string" and name ~= "" then
                    cache[tonumber(specID) or specID] = { name = name, icon = icon }
                end
            end
        end
    end
    if next(cache) then specInfoCache = cache end
    return cache
end

local function ResolveSpecInfo(spec)
    local cached = BuildSpecInfoCache()[spec.id]
    if cached then return cached.name, cached.icon end
    return L(spec.label), nil
end

local function LocalizedClassName(classFile, fallback)
    if LOCALIZED_CLASS_NAMES_MALE and type(LOCALIZED_CLASS_NAMES_MALE[classFile]) == "string" then
        return LOCALIZED_CLASS_NAMES_MALE[classFile]
    end
    return fallback or classFile
end

local function ClassHeaderColor(classFile)
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return { c.r or 1, c.g or 1, c.b or 1, 1 }
    end
    return nil
end

local function BuildAllClassSpecInputs(section, db, ui)
    EnsureClientDefaults(db)
    section:Text(ui.L("Unset specializations show 400 and are never modified; a specialization is enforced only after you save a value for it."), ui.Colors.muted, 26)

    local currentSpecID = GetCurrentSpecID()
    for _, classData in ipairs(CLASS_SPECS) do
        section:Text(LocalizedClassName(classData.classFile), ClassHeaderColor(classData.classFile) or ui.Colors.text, 20)
        local items = {}
        for _, spec in ipairs(classData.specs) do
            local specID = spec.id
            local name, icon = ResolveSpecInfo(spec)
            local suffix = (specID == currentSpecID) and (" (" .. ui.L("Current Spec Value") .. ")") or ""
            local label = icon and string.format("|T%d:14:14:0:0|t %s%s", icon, name, suffix) or (name .. suffix)
            items[#items + 1] = {
                label = label,
                getValue = function() return tostring(SpecDisplayValue(db, specID, currentSpecID)) end,
                setValue = function(text)
                    SetSpecValue(db, specID, text)
                    if GetCurrentSpecID() == specID then ns.ApplyModule(KEY) end
                end,
            }
        end
        section:EditBoxGrid(items, { columns = 2, labelW = 150, boxW = 74 })
    end
end

local moduleInfo = {
    titleKey = "Lag Tolerance",
    descKey = IS_FOREVER and "Reads the client's SpellQueueWindow. Applies only after you save a value."
        or "Read the client's SpellQueueWindow without changing it; a specialization is enforced only after you save a value for it.",
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
                local s = page:NewSection(ui.L("Lag Tolerance"))
                s:CheckGrid({
                    { label = ui.L("Enable"), getValue = function() return db.enabled end, setValue = function(v) ns.SetModuleEnabled(KEY, v) end, note = ui.L("This changes SpellQueueWindow, not your real network latency.") },
                }, { columns = 2 })
                s:EditBox(ui.L("Current Spec Value"), function()
                    local key = GetCurrentSpecKey()
                    return tostring(key and GetSpecValue(db, key) or ReadCurrentCVarValue(400))
                end, function(text)
                    local key = GetCurrentSpecKey()
                    if key then SetSpecValue(db, key, text) end
                    ns.ApplyModule(KEY)
                end, 118, 74, { note = not IS_FOREVER and ui.L("Saving a value takes over this specialization; use the Specializations tab reset to stop managing it.") or nil })
                local buttons = {
                    { text = ui.L("Apply Now"), width = 92, onClick = function() Apply(db); ui.Refresh() end },
                }
                if not IS_FOREVER then
                    buttons[#buttons + 1] = { text = ui.L("Set Current Spec"), width = 126, onClick = function()
                        local key = GetCurrentSpecKey()
                        if key then SetSpecValue(db, key, ReadCurrentCVarValue(400)) end
                        ns.ApplyModule(KEY)
                        ui.Refresh()
                    end }
                end
                s:ButtonRow(buttons)
                page:AddSection(s)


            end,
        },
        {
            key = "specs",
            titleKey = "Specializations",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Specialization Values"))
                BuildAllClassSpecInputs(s, db, ui)
                s:ButtonRow({
                    { text = ui.L("Apply Now"), width = 92, onClick = function() Apply(db); ui.Refresh() end },
                    { text = ui.L("Reset Current Class"), width = 128, onClick = function()
                        -- 清除当前职业所有专精的保存值：这些专精回到“只读不接管”状态。
                        -- 职业读不到（受限/秘密值）时不做任何事，避免拿秘密值比较。
                        local classFile
                        if type(UnitClass) == "function" then
                            local ok, _, cFile = pcall(UnitClass, "player")
                            if ok and not IsSecretValue(cFile) and type(cFile) == "string" then
                                classFile = cFile
                            end
                        end
                        if classFile == nil or classFile == "" then return end
                        for _, classData in ipairs(CLASS_SPECS) do
                            if classData.classFile == classFile then
                                for _, spec in ipairs(classData.specs) do
                                    db.specs[tostring(spec.id)] = nil
                                end
                            end
                        end
                        ns.ApplyModule(KEY)
                        ui.Refresh()
                    end },
                    { text = ui.L("Reset All Specializations"), width = 140, onClick = function()
                        db.specs = {}
                        ns.ApplyModule(KEY)
                        ui.Refresh()
                    end },
                })
                page:AddSection(s)
            end,
        },
    },
}

if IS_FOREVER then
    -- No modern specializations: keep only the basic value page.
    table.remove(moduleInfo.tabs, 2)
end
ns.RegisterModule(KEY, moduleInfo)

end)
