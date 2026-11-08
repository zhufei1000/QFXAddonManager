-- Run from the repository root: lua tests/test_auto_quest.lua
local ns, info, frames = {}, nil, {}
QFXAddonManagerToolboxNS = ns
local function Load(path)
    local body
    assert(loadfile(path))("QFXAddonManager", { ToolboxRuntime = {
        AddFile = function(_, _, fn) body = fn end,
    } })
    assert(body)("QFXAddonManager", ns)
end
Load("QFXAddonManager/Toolbox/Core/Defaults.lua")
Load("QFXAddonManager/Toolbox/Core/Compat.lua")
local defaults = ns.GetModuleDefaults("auto_quest")
local db = {}
for key, value in pairs(defaults) do db[key] = value end
assert(not db.enabled and db.autoAccept and db.autoTurnIn and db.preventMulti)
assert(db.acceptShiftSkip and db.turnInShiftSkip and not db.ignoreOldExpansion)
ns.GetModuleDB = function(key) assert(key == "auto_quest"); return db end
ns.RegisterModule = function(key, data) assert(key == "auto_quest"); info = data end
ns.ApplyModule = function(key) assert(key == "auto_quest"); info.ApplySettings(info, db) end
ns.SetModuleEnabled = function(key, value) db.enabled = value; ns.ApplyModule(key) end
function CreateFrame()
    local frame = { events = {} }
    function frame:SetScript(key, value) assert(key == "OnEvent"); self.callback = value end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = frame
    return frame
end
local combat, shift, trivial, chromie, forever = false, false, false, false, false
local npc, level, expansion, cost, choices, completable = "npc-a", 90, 10, 0, 0, true
local calls, available, active = {}, {}, {}
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return shift end
UnitGUID = function() return npc end
UnitLevel = function() return level end
GetMaxLevelForPlayerExpansion = function() return 90 end
GetServerExpansionLevel = function() return 11 end
GetQuestExpansion = function() return expansion end
GetQuestID = function() return 100 end
GetQuestMoneyToGet = function() return cost end
GetNumQuestChoices = function() return choices end
IsQuestCompletable = function() return completable end
C_PlayerInfo = { IsPlayerInChromieTime = function() return chromie end }
C_QuestLog = { IsQuestTrivial = function() return trivial end }
ns.Compat.IsForever = function() return forever end
local function Record(name, value) calls[#calls + 1] = { name, value } end
AcceptQuest = function() Record("accept") end
CompleteQuest = function() Record("continue") end
GetQuestReward = function(index) Record("reward", index) end
C_GossipInfo = {
    GetActiveQuests = function() return active end,
    GetAvailableQuests = function() return available end,
    SelectActiveQuest = function(id) Record("active", id) end,
    SelectAvailableQuest = function(id) Record("available", id) end,
}
GetNumActiveQuests = function() return #active end
GetActiveTitle = function(index) return "Quest", active[index].isComplete end
SelectActiveQuest = function(index) Record("greeting-active", index) end
GetNumAvailableQuests = function() return #available end
GetAvailableQuestInfo = function(index)
    return available[index].isTrivial, nil, nil, nil, available[index].questID
end
SelectAvailableQuest = function(index) Record("greeting-available", index) end
Load("QFXAddonManager_Toolbox_Daily/AutoTools/AutoQuest.lua")
info.OnInitialize(info, db)
assert(#frames == 0, "Disabled tools must not allocate an event frame")
db.enabled = true; ns.ApplyModule("auto_quest")
assert(#frames == 1 and not frames[1].events.QUEST_AUTOCOMPLETE)
local function Fire(event, expected, value)
    calls = {}
    local frame = frames[1]
    if frame.events[event] then frame.callback(frame, event) end
    assert(#calls == (expected and 1 or 0), event .. " unexpected action count: " .. #calls)
    if expected then assert(calls[1][1] == expected and calls[1][2] == value, event .. " wrong action") end
end

Fire("QUEST_DETAIL", "accept")
shift = true; Fire("QUEST_DETAIL"); Fire("QUEST_PROGRESS"); Fire("QUEST_COMPLETE")
db.acceptShiftEnable, db.acceptShiftSkip = true, false
Fire("QUEST_DETAIL", "accept")
shift = false; Fire("QUEST_DETAIL")
db.acceptShiftEnable, db.acceptShiftSkip = false, false
shift = true; Fire("QUEST_DETAIL", "accept")
shift = false; Fire("QUEST_DETAIL", "accept")
db.acceptShiftEnable, db.acceptShiftSkip = false, true
combat = true
for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING" }) do Fire(event) end
combat = false
db.ignoreTrivial, trivial = true, true; Fire("QUEST_DETAIL")
trivial = false; Fire("QUEST_DETAIL", "accept")
db.ignoreOldExpansion = true; Fire("QUEST_DETAIL")
chromie = true; Fire("QUEST_DETAIL", "accept")
chromie = false; level = 89; Fire("QUEST_DETAIL", "accept")
level = 90; expansion = 11; Fire("QUEST_DETAIL", "accept")
expansion = nil; Fire("QUEST_DETAIL", "accept")
expansion = 10; forever = true; Fire("QUEST_DETAIL", "accept")
forever = false; db.ignoreOldExpansion = false
local savedExpansion = GetQuestExpansion
GetQuestExpansion = nil
assert(not ns.Compat.IsQuestFromOlderExpansion(100))
GetQuestExpansion = savedExpansion

available = { { questID = 1, isTrivial = true }, { questID = 2 } }
Fire("GOSSIP_SHOW", "available", 2)
assert(#available == 2, "Do not mutate the API's quest list")
db.ignoreTrivial = false
Fire("GOSSIP_SHOW")
available = { { questID = 2 } }; Fire("GOSSIP_SHOW")
npc = "npc-b"; Fire("GOSSIP_SHOW", "available", 2)
available[2] = { questID = 3 }; db.preventMulti = false
Fire("GOSSIP_SHOW", "available", 2)
active = { { questID = 8, isComplete = false }, { questID = 9, isComplete = true } }
Fire("GOSSIP_SHOW", "active", 9)
Fire("QUEST_GREETING", "greeting-active", 2)
active = {}; Fire("QUEST_GREETING", "greeting-available", 1)
db.preventMulti = true; Fire("QUEST_GREETING")
available = { { questID = 3 } }; Fire("QUEST_GREETING")
npc = "npc-c"; Fire("QUEST_GREETING", "greeting-available", 1)
-- Missing NPC identity still permits a single quest and protects multiple offers.
npc = nil; Fire("QUEST_GREETING", "greeting-available", 1)
available[2] = { questID = 4 }; Fire("QUEST_GREETING")
available[2] = nil; Fire("QUEST_GREETING")

Fire("QUEST_PROGRESS", "continue")
completable = false; Fire("QUEST_PROGRESS")
completable = true; cost = 1; Fire("QUEST_PROGRESS"); Fire("QUEST_COMPLETE")
cost = 0
for index = 0, 1 do choices = index; Fire("QUEST_COMPLETE", "reward", index) end
choices = 2; Fire("QUEST_COMPLETE")
choices = nil; Fire("QUEST_COMPLETE")
choices = 0; cost = nil; Fire("QUEST_COMPLETE")
cost = 0
db.autoAccept = false; ns.ApplyModule("auto_quest")
Fire("QUEST_DETAIL"); Fire("QUEST_COMPLETE", "reward", 0)
db.turnInShiftEnable, db.turnInShiftSkip = true, false
Fire("QUEST_COMPLETE"); shift = true; Fire("QUEST_COMPLETE", "reward", 0)
shift = false
db.autoTurnIn = false; ns.ApplyModule("auto_quest")
assert(next(frames[1].events) == nil)
db.enabled = false; info.OnDisable(info, db)
assert(next(frames[1].events) == nil and defaults.enabled == false)

-- Exercise the settings callbacks, including mutually exclusive Shift modes.
local controls, sections = {}, {}
local page = {}
function page:NewSection(title)
    local section = { title = title }
    function section:Check(label, get, set) controls[self.title .. ":" .. label] = { get = get, set = set } end
    function section:Text() end
    return section
end
function page:AddSection(section) sections[#sections + 1] = section end
info.tabs[1].build(page, db, info, { L = function(key) return key end, Colors = {} })
controls["Auto Quest:Enable"].set(true)
controls["Auto Accept Quests:Auto Accept Quests"].set(true)
controls["Auto Accept Quests:Hold Shift to Enable"].set(true)
assert(db.acceptShiftEnable and not db.acceptShiftSkip)
controls["Auto Accept Quests:Hold Shift to Skip"].set(true)
assert(db.acceptShiftSkip and not db.acceptShiftEnable)
controls["Auto Turn In Quests:Auto Turn In Quests"].set(true)
controls["Auto Turn In Quests:Hold Shift to Enable"].set(true)
assert(db.turnInShiftEnable and not db.turnInShiftSkip)
controls["Auto Turn In Quests:Hold Shift to Skip"].set(true)
assert(db.turnInShiftSkip and not db.turnInShiftEnable)
assert(#frames == 1 and #sections == 3, "Reuse the event frame through setting changes")
print("PASS: Auto Quest defaults, gossip/greeting flows, filters, Shift modes, combat, rewards, costs, lifecycle and settings")
