local _, manager = ...
manager.ToolboxRuntime:AddFile("AutoTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "auto_quest"
local Compat = ns.Compat
local eventFrame, blockedNPC

local function ShiftAllows(db, prefix)
    local down = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
    if db[prefix .. "ShiftEnable"] then return down end
    return not db[prefix .. "ShiftSkip"] or not down
end

local function IgnoreQuest(db, questID, trivial)
    return (db.ignoreTrivial and trivial)
        or (db.ignoreOldExpansion and Compat.IsQuestFromOlderExpansion(questID))
end

local function CanSelectAvailable(db, count)
    if not db.preventMulti then return true end
    local npc = type(UnitGUID) == "function" and UnitGUID("npc") or nil
    -- Remember this NPC after a manual selection, even if only one offer is
    -- left. No foreign-frame state or saved NPC history is needed.
    if count > 1 then blockedNPC = npc or false; return false end
    if blockedNPC ~= nil and blockedNPC == (npc or false) then return false end
    blockedNPC = nil
    return true
end

local function HandleGossip(db)
    local gossip = C_GossipInfo
    if not gossip then return end
    if db.autoTurnIn and ShiftAllows(db, "turnIn")
        and type(gossip.GetActiveQuests) == "function" and type(gossip.SelectActiveQuest) == "function" then
        for _, quest in ipairs(gossip.GetActiveQuests() or {}) do
            if quest.isComplete and quest.questID then
                gossip.SelectActiveQuest(quest.questID)
                return
            end
        end
    end
    if not db.autoAccept or not ShiftAllows(db, "accept")
        or type(gossip.GetAvailableQuests) ~= "function" or type(gossip.SelectAvailableQuest) ~= "function" then return end
    local first, count = nil, 0
    for _, quest in ipairs(gossip.GetAvailableQuests() or {}) do
        if quest.questID and not IgnoreQuest(db, quest.questID, quest.isTrivial) then
            first, count = first or quest.questID, count + 1
        end
    end
    if first and CanSelectAvailable(db, count) then gossip.SelectAvailableQuest(first) end
end

local function HandleGreeting(db)
    if db.autoTurnIn and ShiftAllows(db, "turnIn") and type(GetNumActiveQuests) == "function"
        and type(GetActiveTitle) == "function" and type(SelectActiveQuest) == "function" then
        for index = 1, GetNumActiveQuests() do
            local _, complete = GetActiveTitle(index)
            if complete then SelectActiveQuest(index); return end
        end
    end
    if not db.autoAccept or not ShiftAllows(db, "accept") or type(GetNumAvailableQuests) ~= "function"
        or type(GetAvailableQuestInfo) ~= "function" or type(SelectAvailableQuest) ~= "function" then return end
    local first, count = nil, 0
    for index = 1, GetNumAvailableQuests() do
        local trivial, _, _, _, questID = GetAvailableQuestInfo(index)
        if not IgnoreQuest(db, questID, trivial) then first, count = first or index, count + 1 end
    end
    if first and CanSelectAvailable(db, count) then SelectAvailableQuest(first) end
end

local function OnEvent(_, event)
    local db = ns.GetModuleDB(KEY)
    if not db.enabled or (type(InCombatLockdown) == "function" and InCombatLockdown()) then return end
    if event == "GOSSIP_SHOW" then
        HandleGossip(db)
    elseif event == "QUEST_GREETING" then
        HandleGreeting(db)
    elseif event == "QUEST_DETAIL" then
        if not db.autoAccept or not ShiftAllows(db, "accept") or type(GetQuestID) ~= "function"
            or type(AcceptQuest) ~= "function" then return end
        local questID = GetQuestID()
        if questID and questID > 0 and not IgnoreQuest(db, questID, Compat.IsQuestTrivial(questID)) then
            AcceptQuest()
        end
    elseif db.autoTurnIn and ShiftAllows(db, "turnIn") then
        -- Keep paid turn-ins and reward choices in the player's hands. Never
        -- open the world-map quest completion popup from addon execution.
        if type(GetQuestMoneyToGet) ~= "function" then return end
        local cost = GetQuestMoneyToGet()
        if type(cost) ~= "number" or cost ~= 0 then return end
        if event == "QUEST_PROGRESS" and type(IsQuestCompletable) == "function"
            and IsQuestCompletable() and type(CompleteQuest) == "function" then
            CompleteQuest()
        elseif event == "QUEST_COMPLETE" and type(GetNumQuestChoices) == "function"
            and type(GetQuestReward) == "function" then
            local choices = GetNumQuestChoices()
            if type(choices) == "number" and choices >= 0 and choices <= 1 then GetQuestReward(choices) end
        end
    end
end

local function UpdateEvents(_, db)
    if not eventFrame and db.enabled and (db.autoAccept or db.autoTurnIn) then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", OnEvent)
    end
    if not eventFrame then return end
    eventFrame:UnregisterAllEvents()
    blockedNPC = nil
    if not db.enabled or not (db.autoAccept or db.autoTurnIn) then return end
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("QUEST_GREETING")
    if db.autoAccept then eventFrame:RegisterEvent("QUEST_DETAIL") end
    if db.autoTurnIn then
        eventFrame:RegisterEvent("QUEST_PROGRESS")
        eventFrame:RegisterEvent("QUEST_COMPLETE")
    end
end

local function BuildSettings(page, db, info, ui)
    local function Enabled()
        return db.enabled, ui.L("Enable this tool first.")
    end
    local function Toggle(section, label, field, note, prefix, opposite)
        section:Check(ui.L(label), function() return db[field] == true end, function(value)
            db[field] = value == true
            if value and opposite then db[opposite] = false end
            ns.ApplyModule(KEY)
        end, ui.L(note), { enabled = function()
            return db.enabled and (not prefix or db[prefix] == true), ui.L("Enable this tool first.")
        end })
    end

    local main = page:NewSection(ui.L("Auto Quest"))
    main:Check(ui.L("Enable"), function() return db.enabled end,
        function(value) ns.SetModuleEnabled(KEY, value) end, ui.L(info.descKey))
    main:Text(ui.L("Auto Quest pauses in combat. Multiple reward choices and turn-ins that cost gold require manual confirmation."), ui.Colors.muted, 48)
    main:Text(ui.L("Use only one addon's quest automation at a time, including EUI's Auto Accept and Auto Turn In."), ui.Colors.muted, 42)
    page:AddSection(main)

    local accept = page:NewSection(ui.L("Auto Accept Quests"))
    accept:Check(ui.L("Auto Accept Quests"), function() return db.autoAccept end, function(value)
        db.autoAccept = value == true; ns.ApplyModule(KEY)
    end, ui.L("Accept quests from NPC quest lists and quest detail pages."), { enabled = Enabled })
    Toggle(accept, "Prevent Multi Quest Accept", "preventMulti",
        "Leave NPCs offering multiple eligible quests for manual selection.", "autoAccept")
    Toggle(accept, "Ignore Low Level Quests", "ignoreTrivial",
        "Skip quests marked as trivial by the game.", "autoAccept")
    if not (Compat.IsForever and Compat.IsForever()) then
        Toggle(accept, "Ignore Older Expansion Quests", "ignoreOldExpansion",
            "At maximum level, skip older expansion quests unless you are in Chromie Time.", "autoAccept")
    end
    Toggle(accept, "Hold Shift to Enable", "acceptShiftEnable",
        "Run only while Shift is held. This turns off Hold Shift to Skip.", "autoAccept", "acceptShiftSkip")
    Toggle(accept, "Hold Shift to Skip", "acceptShiftSkip",
        "Hold Shift to pause. This turns off Hold Shift to Enable.", "autoAccept", "acceptShiftEnable")
    page:AddSection(accept)

    local turnIn = page:NewSection(ui.L("Auto Turn In Quests"))
    turnIn:Check(ui.L("Auto Turn In Quests"), function() return db.autoTurnIn end, function(value)
        db.autoTurnIn = value == true; ns.ApplyModule(KEY)
    end, ui.L("Turn in completed quests when there is no reward choice or only one reward."), { enabled = Enabled })
    Toggle(turnIn, "Hold Shift to Enable", "turnInShiftEnable",
        "Run only while Shift is held. This turns off Hold Shift to Skip.", "autoTurnIn", "turnInShiftSkip")
    Toggle(turnIn, "Hold Shift to Skip", "turnInShiftSkip",
        "Hold Shift to pause. This turns off Hold Shift to Enable.", "autoTurnIn", "turnInShiftEnable")
    page:AddSection(turnIn)
end

ns.RegisterModule(KEY, {
    titleKey = "Auto Quest",
    descKey = "Automatically accept and turn in quests, with separate Shift controls and quest filters.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = UpdateEvents,
    OnEnable = UpdateEvents,
    OnDisable = UpdateEvents,
    ApplySettings = UpdateEvents,
    tabs = { { key = "basic", titleKey = "Basic", build = BuildSettings } },
})
end)
