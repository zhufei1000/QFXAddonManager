local _, manager = ...
manager.ToolboxRuntime:AddFile("AutoTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "damage_meter_reset"
local mod = {}

local IS_FOREVER = false
if ns.Compat and type(ns.Compat.IsForever) == "function" then
    local ok, forever = pcall(ns.Compat.IsForever)
    IS_FOREVER = ok and forever == true
end

-- 进本后等待实例信息稳定再提示；大秘境开始会再触发一次，用冷却避免连续打扰。
local REPEAT_COOLDOWN = 30

-- 暴雪难度 ID 归类。数值取自 GetInstanceInfo 的第三个返回值。
-- 五人本：1 普通 / 2 英雄 / 23 史诗 / 8 史诗钥石（大秘境正式开始计时）。
-- 团本：17 随机 / 14 普通 / 15 英雄 / 16 史诗 / 24 时空漫游（按普通档处理）。
--
-- 关键事实：进门那一刻客户端分不出「史诗五人本」和「大秘境」——两者都是 23，
-- 只有插入钥石后难度才变成 8。所以进本提示与钥石提示必须是两条独立的触发路径。
local MYTHIC_DUNGEON_DIFFICULTY = 23
local MYTHIC_KEYSTONE_DIFFICULTY = 8
local DUNGEON_DIFFICULTY_IDS = {
    normal = { [1] = true },
    heroic = { [2] = true },
    mythic = { [MYTHIC_DUNGEON_DIFFICULTY] = true, [MYTHIC_KEYSTONE_DIFFICULTY] = true },
}
local RAID_DIFFICULTY_IDS = {
    lfr    = { [17] = true },
    normal = { [14] = true, [24] = true },
    heroic = { [15] = true },
    mythic = { [16] = true },
}
local DUNGEON_DIFFICULTY_ORDER = { "normal", "heroic", "mythic" }
local RAID_DIFFICULTY_ORDER = { "lfr", "normal", "heroic", "mythic" }
local DIFFICULTY_LABEL = {
    lfr = "LFR",
    normal = "Normal",
    heroic = "Heroic",
    mythic = "Mythic",
}

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "PLAYER_REGEN_ENABLED",
}
if not IS_FOREVER then
    EVENTS[#EVENTS + 1] = "CHALLENGE_MODE_START"
    EVENTS[#EVENTS + 1] = "CHALLENGE_MODE_RESET"
end

local function L(key)
    if ns.Util and ns.Util.L then return ns.Util.L(key) end
    if ns.L then return ns.L(key) end
    return key
end

local SafeCall = ns.Compat.Call

local function Print(msg)
    if ns.Print then ns.Print(msg) end
end

local function GetDB()
    return ns.GetModuleDB(KEY)
end

local function InCombat()
    if ns.Compat and type(ns.Compat.InCombatLockdown) == "function" then
        return ns.Compat.InCombatLockdown() and true or false
    end
    if type(InCombatLockdown) == "function" then
        return InCombatLockdown() and true or false
    end
    return false
end

local function Grouped()
    if type(IsInGroup) == "function" then return IsInGroup() and true or false end
    if type(IsInRaid) == "function" then return IsInRaid() and true or false end
    return false
end

local function Now()
    if type(GetTime) == "function" then return GetTime() end
    return 0
end

local function HasResetAPI()
    local meter = _G.C_DamageMeter
    return type(meter) == "table" and type(meter.ResetAllCombatSessions) == "function"
end

-- ---------------------------------------------------------------------------
-- 实例信息与难度判定
-- ---------------------------------------------------------------------------

local function InstanceSnapshot()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    return {
        name = name,
        instanceType = instanceType,
        difficultyID = tonumber(difficultyID),
        difficultyName = difficultyName,
    }
end

local function DifficultyIdsFor(instanceType)
    if instanceType == "party" then return DUNGEON_DIFFICULTY_IDS end
    if instanceType == "raid" then return RAID_DIFFICULTY_IDS end
    return nil
end

local function DifficultySettingsFor(db, instanceType)
    if instanceType == "party" then return db.dungeonDifficulties end
    if instanceType == "raid" then return db.raidDifficulties end
    return nil
end

-- 难度名优先用客户端本地化文本，取不到时退回内置英文标签。
local function DifficultyText(snapshot, difficultyID)
    if snapshot and snapshot.difficultyName and snapshot.difficultyName ~= "" then
        return snapshot.difficultyName
    end
    if difficultyID == nil then return nil end
    local ids = DUNGEON_DIFFICULTY_IDS
    for key, mapped in pairs(ids) do
        if mapped[difficultyID] then return L(DIFFICULTY_LABEL[key]) end
    end
    for key, mapped in pairs(RAID_DIFFICULTY_IDS) do
        if mapped[difficultyID] then return L(DIFFICULTY_LABEL[key]) end
    end
    return nil
end

local function IsMythicDifficulty(instanceType, difficultyID)
    local ids = DifficultyIdsFor(instanceType)
    return ids ~= nil and difficultyID ~= nil and ids.mythic[difficultyID] == true
end

-- 难度过滤。未知难度放行，避免将来客户端新增难度后功能静默失效。
local function DifficultyAllowed(db, instanceType, difficultyID)
    local ids = DifficultyIdsFor(instanceType)
    local settings = DifficultySettingsFor(db, instanceType)
    if not ids then return false end
    if not settings then return true end

    if difficultyID == nil then return true end

    local recognized = false
    for _, mapped in pairs(ids) do
        if mapped[difficultyID] then recognized = true break end
    end
    if not recognized then return true end

    for key, mapped in pairs(ids) do
        if settings[key] ~= false and mapped[difficultyID] then return true end
    end
    return false
end

-- 勾了「只在大秘境开始时提示」后，进入史诗难度五人本先按住不提示，等 CHALLENGE_MODE_START 走钥石路径。
-- 普通 / 英雄五人本不受影响，进门照常提示。
-- 之所以只能压到「史诗难度」这一层：进门那一刻客户端分不出史诗本和大秘境，两者都是难度 23。
local function WaitsForKeystone(db, snapshot)
    if IS_FOREVER then return false end
    return db.dungeonKeystoneOnly == true
        and snapshot ~= nil
        and snapshot.instanceType == "party"
        and IsMythicDifficulty("party", snapshot.difficultyID)
end

-- 钥石启动时的准入。这个选项本身就是「我要大秘境」的表达，
-- 所以勾了它就不再要求史诗难度框，避免两个开关互相打架。
local function KeystoneAllowed(db)
    if IS_FOREVER then return false end
    if db.dungeons == false then return false end
    if db.dungeonKeystoneOnly == true then return true end
    return DifficultyAllowed(db, "party", MYTHIC_KEYSTONE_DIFFICULTY)
end

-- 作用范围：实例类型 + 难度 + 组队条件。reason 区分「进本」与「钥石启动」两条路径。
local function MatchesScope(db, reason)
    local snapshot = InstanceSnapshot()
    if not snapshot then return false end

    if reason == "keystone" then
        return KeystoneAllowed(db)
    end

    if snapshot.instanceType == "raid" then
        if db.raids == false then return false end
    elseif snapshot.instanceType == "party" then
        if db.dungeons == false then return false end
        if WaitsForKeystone(db, snapshot) then return false end
    else
        return false
    end
    return DifficultyAllowed(db, snapshot.instanceType, snapshot.difficultyID)
end

-- ---------------------------------------------------------------------------
-- 重置动作
-- ---------------------------------------------------------------------------

local function ResetMeter(announce)
    if not HasResetAPI() then
        if announce ~= false then
            Print(L("This client does not provide the built-in damage meter reset API."))
        end
        return false
    end

    local meter = _G.C_DamageMeter
    SafeCall(meter.ResetAllCombatSessions, meter)
    if announce ~= false then
        Print(L("Damage meter data reset."))
    end
    return true
end

-- 设置变更后调用，保持模块内状态与设置页显示同步。
local function NotifyChanged()
    if ns.ApplyModule then ns.ApplyModule(KEY) end
    if ns.RequestConfigRefresh then ns.RequestConfigRefresh("damage-meter-reset") end
end

-- ---------------------------------------------------------------------------
-- 确认弹窗
-- ---------------------------------------------------------------------------

local dialog
local dialogBody
local dialogHint
local alwaysCheck
local keystoneCheck
local quietCheck

local function BuildDialog()
    if dialog then return dialog end
    if type(CreateFrame) ~= "function" then return nil end

    local frame = CreateFrame("Frame", "QFXToolBoxDamageMeterResetFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(430, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    if frame.TitleText then
        frame.TitleText:SetText(L("Damage Meter Reset"))
    end

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 22, -44)
    body:SetPoint("TOPRIGHT", -22, -44)
    body:SetJustifyH("CENTER")
    body:SetJustifyV("TOP")
    body:SetHeight(52)
    dialogBody = body

    local options = CreateFrame("Frame", nil, frame)
    options:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -106)
    options:SetSize(386, 100)

    local function MakeCheck(index, label, onClick)
        local cb = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", options, "TOPLEFT", 0, -(index - 1) * 30)
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        text:SetText(label)
        cb.Text = text
        cb:SetScript("OnClick", function(self)
            if onClick then onClick(self:GetChecked() and true or false) end
        end)
        return cb
    end

    alwaysCheck = MakeCheck(1, L("Always reset without asking"), function(checked)
        local db = GetDB()
        db.mode = checked and "auto" or "ask"
        NotifyChanged()
    end)
    keystoneCheck = MakeCheck(2, L("Only when a Mythic+ key starts"), function(checked)
        local db = GetDB()
        db.dungeonKeystoneOnly = checked and true or false
        NotifyChanged()
    end)
    quietCheck = MakeCheck(3, L("Chat notice"), function(checked)
        local db = GetDB()
        db.quiet = not checked
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", options, "BOTTOMLEFT", 4, -2)
    hint:SetPoint("TOPRIGHT", options, "BOTTOMRIGHT", 0, -2)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    hint:SetHeight(30)
    hint:SetText(L("These options are saved to the settings page."))
    dialogHint = hint

    local function MakeButton(text, width, onClick)
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(width, 26)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local resetBtn = MakeButton(L("Reset now"), 130, function()
        frame:Hide()
        local db = GetDB()
        ResetMeter(db.quiet ~= true)
    end)
    resetBtn:SetPoint("BOTTOMRIGHT", -20, 16)

    local laterBtn = MakeButton(L("Not now"), 130, function()
        frame:Hide()
    end)
    laterBtn:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)

    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    end

    if type(_G.UISpecialFrames) == "table" and type(tinsert) == "function" then
        tinsert(_G.UISpecialFrames, "QFXToolBoxDamageMeterResetFrame")
    end

    frame:Hide()
    dialog = frame
    return dialog
end

local function ShowDialog()
    local frame = BuildDialog()
    if not frame then return end

    local db = GetDB()
    local snapshot = InstanceSnapshot()
    local isParty = snapshot and snapshot.instanceType == "party"

    -- 弹窗上的选项与设置页是同一份数据，每次打开都回读一次，避免两边显示不一致。
    if alwaysCheck then alwaysCheck:SetChecked(db.mode == "auto") end
    if quietCheck then quietCheck:SetChecked(db.quiet ~= true) end
    if keystoneCheck then
        if isParty and not IS_FOREVER then
            keystoneCheck:SetChecked(db.dungeonKeystoneOnly == true)
            keystoneCheck:Show()
        else
            -- 团本没有大秘境概念；Forever 也没有钥石，藏起来但不影响布局
            keystoneCheck:Hide()
        end
    end

    if dialogBody then
        local instanceName = snapshot and snapshot.name
        local difficultyText = snapshot and DifficultyText(snapshot, snapshot.difficultyID)
        if instanceName and instanceName ~= "" and difficultyText then
            dialogBody:SetText(string.format(
                L("You entered %s (%s). Reset the built-in damage meter data now?"),
                instanceName, difficultyText))
        elseif instanceName and instanceName ~= "" then
            dialogBody:SetText(string.format(
                L("You entered %s. Reset the built-in damage meter data now?"), instanceName))
        else
            dialogBody:SetText(L("You entered an instance. Reset the built-in damage meter data now?"))
        end
    end

    frame:Show()
end

local function HideDialog()
    if dialog then dialog:Hide() end
end

-- ---------------------------------------------------------------------------
-- 进本检测：只在「野外 -> 副本」的边沿触发
-- ---------------------------------------------------------------------------

local lastInInstance = nil
local firstEnteringWorld = true
local pendingTimer = nil
local waitingForCombatEnd = false
local pendingReason = nil
local lastTriggerTime = 0

local function CancelPending()
    if pendingTimer then
        if ns.Compat and ns.Compat.CancelTimer then
            ns.Compat.CancelTimer(pendingTimer)
        end
        pendingTimer = nil
    end
    waitingForCombatEnd = false
    pendingReason = nil
end

local function Trigger(db, reason)
    if not db or not db.enabled then return end
    if not HasResetAPI() then return end
    if not MatchesScope(db, reason) then return end
    if db.requireGroup and not Grouped() then return end

    -- 战斗中弹窗会挡住视线，先记下来，脱战后立刻补上
    if db.waitForCombatEnd ~= false and InCombat() then
        waitingForCombatEnd = true
        pendingReason = reason
        return
    end

    lastTriggerTime = Now()
    if db.mode == "auto" then
        ResetMeter(db.quiet ~= true)
    else
        ShowDialog()
    end
end

local function ScheduleTrigger(reason)
    CancelPending()

    local db = GetDB()
    local delay = tonumber(db.delay)
    if not delay or delay < 0 then delay = 0 end

    if delay <= 0 then
        Trigger(db, reason)
        return
    end

    if ns.Compat and ns.Compat.NewTimer then
        pendingTimer = ns.Compat.NewTimer(delay, function()
            pendingTimer = nil
            -- 延迟期间可能已经离开副本或模块被关闭
            if not IsInInstance() then return end
            local current = GetDB()
            if not current.enabled then return end
            Trigger(current, reason)
        end)
    else
        Trigger(db, reason)
    end
end

local function Evaluate(reason)
    local db = GetDB()
    if not db.enabled then return end

    local inInstance = IsInInstance() and true or false

    if inInstance and lastInInstance == false then
        lastInInstance = true
        ScheduleTrigger("entry")
    elseif not inInstance then
        lastInInstance = false
        -- 离开副本即结束本次访问的合并窗口，否则上一次访问的时间戳会误吞下一次的钥石触发。
        lastTriggerTime = Now() - REPEAT_COOLDOWN
        CancelPending()
        HideDialog()
    elseif reason == "keystone" then
        -- 大秘境开始：人已经在副本里，没有 false -> true 的边沿，单独触发
        local elapsed = Now() - lastTriggerTime
        if elapsed < 0 or elapsed >= REPEAT_COOLDOWN then
            ScheduleTrigger("keystone")
        end
    end
end

local function OnEvent(event)
    local db = GetDB()
    if not db.enabled then return end

    if event == "PLAYER_REGEN_ENABLED" then
        if waitingForCombatEnd then
            waitingForCombatEnd = false
            local reason = pendingReason
            pendingReason = nil
            if IsInInstance() then Trigger(db, reason) end
        end
        return
    end

    if event == "CHALLENGE_MODE_START" then
        Evaluate("keystone")
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- 登录/重载后的第一次只同步状态，避免把「上线就在副本」当成刚进本
        if firstEnteringWorld then
            firstEnteringWorld = false
            lastInInstance = IsInInstance() and true or false
            return
        end
    end

    Evaluate()
end

local function RegisterEvents()
    if ns.RegisterModuleEvents then
        ns.RegisterModuleEvents(KEY, EVENTS, OnEvent)
    end
end

local function UnregisterEvents()
    if ns.UnregisterModuleEvents then
        ns.UnregisterModuleEvents(KEY, EVENTS)
    end
end

-- ---------------------------------------------------------------------------
-- 生命周期
-- ---------------------------------------------------------------------------

function mod:OnEnable(db)
    lastInInstance = IsInInstance() and true or false
    -- 合并窗口从「已过期」开始，避免 /reload 后刚上线就被旧时间戳误吞。
    lastTriggerTime = Now() - REPEAT_COOLDOWN
    firstEnteringWorld = true
    RegisterEvents()
end

function mod:OnDisable(db)
    CancelPending()
    HideDialog()
    UnregisterEvents()
    lastInInstance = nil
    waitingForCombatEnd = false
end

function mod:ApplySettings(db)
    if db.enabled then
        RegisterEvents()
    else
        CancelPending()
        HideDialog()
        UnregisterEvents()
    end
end

function mod:HandleSlash(msg)
    if msg ~= "resetmeter" and msg ~= "meterreset" then return false end
    if not HasResetAPI() then
        Print(L("This client does not provide the built-in damage meter reset API."))
        return true
    end
    ResetMeter(true)
    return true
end

-- ---------------------------------------------------------------------------
-- 配置页
-- ---------------------------------------------------------------------------

local function DifficultyItem(db, instanceType, difficultyKey, enabledRule)
    return {
        label = L(DIFFICULTY_LABEL[difficultyKey]),
        getValue = function()
            local current = DifficultySettingsFor(db, instanceType)
            return current == nil or current[difficultyKey] ~= false
        end,
        setValue = function(value)
            local current = DifficultySettingsFor(db, instanceType)
            if current == nil then return end
            current[difficultyKey] = value and true or false
        end,
        enabled = enabledRule,
        note = L("Untick to skip this difficulty."),
    }
end

local function StatusLine(db)
    if not HasResetAPI() then
        return L("This client does not provide the built-in damage meter reset API.")
    end
    if not db.enabled then
        return L("Disabled. Enable the module to watch for instance entry.")
    end
    if not IsInInstance() then
        return L("Watching for instance entry.")
    end

    local snapshot = InstanceSnapshot()
    if not snapshot then
        return L("Watching for instance entry.")
    end
    if snapshot.instanceType ~= "party" and snapshot.instanceType ~= "raid" then
        return L("Inside an instance, but the current instance type is not selected.")
    end
    if snapshot.instanceType == "raid" and db.raids == false then
        return L("Inside a raid, but raids are not selected.")
    end
    if snapshot.instanceType == "party" and db.dungeons == false then
        return L("Inside a dungeon, but dungeons are not selected.")
    end
    -- 人在史诗本里但钥石还没插：这个门口被「只在大秘境开始时提示」按住了。
    if WaitsForKeystone(db, snapshot) and snapshot.difficultyID == MYTHIC_DUNGEON_DIFFICULTY then
        return L("Inside a Mythic dungeon. Waiting for the keystone to start the run.")
    end
    if not DifficultyAllowed(db, snapshot.instanceType, snapshot.difficultyID) then
        local difficultyText = DifficultyText(snapshot, snapshot.difficultyID) or ""
        return string.format(L("Inside %s, but this difficulty is not selected."), difficultyText)
    end
    if db.requireGroup and not Grouped() then
        return L("Waiting: solo play is ignored while \"Only while grouped\" is on.")
    end
    if IS_FOREVER then
        return L("Ready. The next matching instance entry will trigger the reset.")
    end
    return L("Ready. The next matching entry, or a Mythic+ key start, will trigger the reset.")
end

ns.RegisterModule(KEY, {
    titleKey = "Damage Meter Reset",
    descKey = "Ask or auto reset the built-in damage meter when you enter a dungeon or raid.",
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    HandleSlash = function(info, msg) return mod:HandleSlash(msg) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local function EnabledRule()
                    return db.enabled == true
                end
                local function DungeonRule()
                    return db.enabled == true and db.dungeons ~= false
                end
                local function RaidRule()
                    return db.enabled == true and db.raids ~= false
                end

                local main = page:NewSection(ui.L("Damage Meter Reset"))
                main:CheckGrid({
                    {
                        label = ui.L("Enable"),
                        getValue = function() return db.enabled end,
                        setValue = function(v) ns.SetModuleEnabled(KEY, v) end,
                        note = ui.L("Ask or auto reset the built-in damage meter when you enter a dungeon or raid."),
                    },
                    {
                        label = ui.L("Reset automatically without asking"),
                        getValue = function() return db.mode == "auto" end,
                        setValue = function(v)
                            db.mode = v and "auto" or "ask"
                            NotifyChanged()
                        end,
                        enabled = EnabledRule,
                        note = ui.L("Skip the confirmation window and clear the data immediately."),
                    },
                    {
                        label = ui.L("Only while grouped"),
                        getValue = function() return db.requireGroup == true end,
                        setValue = function(v) db.requireGroup = v and true or false end,
                        enabled = EnabledRule,
                        note = ui.L("Ignore solo runs such as farming old content alone."),
                    },
                    {
                        label = ui.L("Wait until out of combat"),
                        getValue = function() return db.waitForCombatEnd ~= false end,
                        setValue = function(v) db.waitForCombatEnd = v and true or false end,
                        enabled = EnabledRule,
                        note = ui.L("Hold the prompt while you are in combat and show it right after combat ends."),
                    },
                    {
                        label = ui.L("Chat notice"),
                        getValue = function() return db.quiet ~= true end,
                        setValue = function(v) db.quiet = not v end,
                        enabled = EnabledRule,
                        note = ui.L("Print a line in chat each time the meter is reset."),
                    },
                }, { columns = 2 })
                page:AddSection(main)

                local scope = page:NewSection(ui.L("Instance scope"))
                scope:CheckGrid({
                    {
                        label = ui.L("Dungeons"),
                        getValue = function() return db.dungeons ~= false end,
                        setValue = function(v) db.dungeons = v and true or false end,
                        enabled = EnabledRule,
                        note = IS_FOREVER and ui.L("Trigger when entering a 5-player dungeon.")
                            or ui.L("Trigger when entering a 5-player dungeon, including Mythic+."),
                    },
                    {
                        label = ui.L("Raids"),
                        getValue = function() return db.raids ~= false end,
                        setValue = function(v) db.raids = v and true or false end,
                        enabled = EnabledRule,
                        note = ui.L("Trigger when entering a raid instance."),
                    },
                }, { columns = 2 })

                scope:Text(ui.L("Dungeon difficulty"), ui.Colors.muted, 22)
                local dungeonItems = {}
                for _, difficultyKey in ipairs(DUNGEON_DIFFICULTY_ORDER) do
                    if not (IS_FOREVER and difficultyKey == "mythic") then
                        local item = DifficultyItem(db, "party", difficultyKey, DungeonRule)
                        item.note = ui.L("Untick to skip this difficulty.")
                        dungeonItems[#dungeonItems + 1] = item
                    end
                end
                scope:CheckGrid(dungeonItems, { columns = IS_FOREVER and 2 or 3 })
                if not IS_FOREVER then
                    scope:Check(ui.L("Only when a Mythic+ key starts"), function()
                        return db.dungeonKeystoneOnly == true
                    end, function(v)
                        db.dungeonKeystoneOnly = v and true or false
                    end, ui.L("Entering a Mythic dungeon stays quiet until a keystone starts the run. Normal and Heroic entries still prompt."), {
                        enabled = DungeonRule,
                    })
                end

                scope:Text(ui.L("Raid difficulty"), ui.Colors.muted, 22)
                local raidItems = {}
                local raidOrder = IS_FOREVER and { "normal" } or RAID_DIFFICULTY_ORDER
                for _, difficultyKey in ipairs(raidOrder) do
                    local item = DifficultyItem(db, "raid", difficultyKey, RaidRule)
                    item.note = ui.L("Untick to skip this difficulty.")
                    raidItems[#raidItems + 1] = item
                end
                scope:CheckGrid(raidItems, { columns = IS_FOREVER and 1 or 4 })
                if not IS_FOREVER then
                    scope:Text(ui.L("Mythic difficulty needs a full group; untick it if you only run Normal or Heroic raids."), ui.Colors.muted, 22)
                end
                page:AddSection(scope)

                local behavior = page:NewSection(ui.L("Behavior"))
                behavior:ValueSlider(ui.L("Prompt delay"), 0, 5, 0.5, function()
                    return tonumber(db.delay) or 1.5
                end, function(v)
                    db.delay = tonumber(v) or 1.5
                end, {
                    labelW = 132,
                    sliderW = 300,
                    enabled = EnabledRule,
                    note = ui.L("Wait this long after entering so instance data is stable."),
                })
                if not IS_FOREVER then
                    behavior:Text(ui.L("Starting a keystone also triggers a reset, but not within 30 seconds of entering the same dungeon."), ui.Colors.muted, 24)
                end
                behavior:ButtonRow({
                    {
                        text = ui.L("Reset now"),
                        width = 122,
                        enabled = EnabledRule,
                        onClick = function() ResetMeter(true) end,
                    },
                })
                page:AddSection(behavior)

                local status = page:NewSection(ui.L("Status"))
                status:DynamicText(function() return StatusLine(db) end, ui.Colors.warning, 42)
                status:Text(ui.L("Tip: /qfxt resetmeter clears the damage meter data immediately."), ui.Colors.muted, 24)
                page:AddSection(status)
            end,
        },
    },
})

end)
