local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
--[[
Name: LibRangeCheck-3.0-QFX
Original project: LibRangeCheck-3.0
Original authors: mitch0, WoWUIDev Community
License: MIT

QFX Retail 12.x implementation:
- Rebuilds checkers from the player's active spellbook, not from broad
  "known or in spellbook" guesses. This preserves replacement spells and
  rejects off-spec entries.
- Uses the reference library's friend/harm/res/pet/misc routing and separate
  combat-safe lists.
- Uses Retail spell and item probes for rich intervals.
- Never calls CheckInteractDistance or UnitPosition.
- Item probes are excluded for restricted friendly/non-attackable units in
  combat. All secret or inaccessible results are treated as unknown.
- Loaded only by QFXToolBox_HudTools.
]]

local addonName = ...
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local MAJOR = "LibRangeCheck-3.0-QFX"
local MINOR = 2

local lib = ns.LibRangeCheckQFX
if lib and type(lib.MINOR) == "number" and lib.MINOR >= MINOR then
    return
end

lib = lib or {}
lib.MAJOR = MAJOR
lib.MINOR = MINOR
lib.MeleeRange = 5
lib.FriendlyRange = 40
lib.revision = lib.revision or 0
lib.checkerSets = lib.checkerSets or {}
lib.requestedItems = lib.requestedItems or {}
lib.requestedItemRanges = lib.requestedItemRanges or {}
lib.pendingItemRanges = lib.pendingItemRanges or { friend = {}, harm = {} }

ns.LibRangeCheckQFX = lib
_G.LibRangeCheck30QFX = lib

local floor = math.floor
local sqrt = math.sqrt
local sort = table.sort
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local wipe = wipe

local C_Item = C_Item
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local Enum = Enum
local InCombatLockdown = InCombatLockdown
local UnitCanAttack = UnitCanAttack
local UnitCanAssist = UnitCanAssist
local UnitClass = UnitClass
local UnitDistanceSquared = UnitDistanceSquared
local UnitExists = UnitExists
local UnitInRange = UnitInRange
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitIsVisible = UnitIsVisible
local canaccessvalue = canaccessvalue
local issecretvalue = issecretvalue

local PLAYER_SPELL_BANK = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or "spell"
local SPELL_ITEM_TYPE = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell

local function IsAccessible(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then
        return false
    end
    if type(canaccessvalue) == "function" and not canaccessvalue(value) then
        return false
    end
    return true
end

local function AccessibleNumber(value)
    if not IsAccessible(value) or type(value) ~= "number" then return nil end
    return value
end

local function AccessibleBoolean(value)
    if not IsAccessible(value) then return nil end
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

local function SafeFlag(func, ...)
    if type(func) ~= "function" then return nil end
    return AccessibleBoolean(func(...))
end

local function RoundRange(value)
    value = AccessibleNumber(value)
    if not value then return nil end
    return floor(value + 0.5)
end

local function CopyArray(source)
    local result = {}
    if type(source) == "table" then
        for i = 1, #source do result[#result + 1] = source[i] end
    end
    return result
end

local function GetSpellInfoTable(spellID)
    if not C_Spell or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local info = C_Spell.GetSpellInfo(spellID)
    if not IsAccessible(info) or type(info) ~= "table" then return nil end
    return info
end

local function GetSpellName(spellID)
    local info = GetSpellInfoTable(spellID)
    local name = info and info.name
    if not IsAccessible(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

local function GetBookItemInfo(slotIndex, spellBank)
    if not C_SpellBook or type(C_SpellBook.GetSpellBookItemInfo) ~= "function" then return nil end
    local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank or PLAYER_SPELL_BANK)
    if not IsAccessible(info) or type(info) ~= "table" then return nil end
    if info.isOffSpec == true then return nil end
    if SPELL_ITEM_TYPE and info.itemType and info.itemType ~= SPELL_ITEM_TYPE then return nil end
    local spellID = AccessibleNumber(info.spellID)
    if not spellID or spellID <= 0 then return nil end
    return info, spellID
end

local function TryFindBookSlot(spellID)
    if not C_SpellBook or type(C_SpellBook.FindSpellBookSlotForSpell) ~= "function" then return nil end
    local slotIndex, spellBank = C_SpellBook.FindSpellBookSlotForSpell(spellID, false, true, false, false)
    slotIndex = AccessibleNumber(slotIndex)
    if not slotIndex then return nil end
    spellBank = spellBank or PLAYER_SPELL_BANK
    local info, actualSpellID = GetBookItemInfo(slotIndex, spellBank)
    if not info then return nil end
    return slotIndex, spellBank, actualSpellID
end

local function BuildSpellIDCandidates(spellID)
    local result, seen = {}, {}
    local function Add(id)
        id = AccessibleNumber(id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            result[#result + 1] = id
        end
    end

    Add(spellID)
    if C_SpellBook and type(C_SpellBook.FindSpellOverrideByID) == "function" then
        Add(C_SpellBook.FindSpellOverrideByID(spellID))
    end
    if C_SpellBook and type(C_SpellBook.FindBaseSpellByID) == "function" then
        Add(C_SpellBook.FindBaseSpellByID(spellID))
    end
    return result
end

local function ScanActiveSpellBookByName(spellName)
    if not spellName or not C_SpellBook then return nil end
    if type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function"
        or type(C_SpellBook.GetSpellBookSkillLineInfo) ~= "function"
        or type(C_SpellBook.GetSpellBookItemName) ~= "function"
    then
        return nil
    end

    local lineCount = AccessibleNumber(C_SpellBook.GetNumSpellBookSkillLines()) or 0
    for lineIndex = 1, lineCount do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        if IsAccessible(lineInfo) and type(lineInfo) == "table"
            and not lineInfo.shouldHide and lineInfo.offSpecID == nil
        then
            local offset = AccessibleNumber(lineInfo.itemIndexOffset) or 0
            local count = AccessibleNumber(lineInfo.numSpellBookItems) or 0
            for itemIndex = 1, count do
                local slotIndex = offset + itemIndex
                local itemName = C_SpellBook.GetSpellBookItemName(slotIndex, PLAYER_SPELL_BANK)
                if IsAccessible(itemName) and itemName == spellName then
                    local info, actualSpellID = GetBookItemInfo(slotIndex, PLAYER_SPELL_BANK)
                    if info then return slotIndex, PLAYER_SPELL_BANK, actualSpellID end
                end
            end
        end
    end
    return nil
end

local function ResolveActiveSpell(spellID)
    local candidates = BuildSpellIDCandidates(spellID)
    for i = 1, #candidates do
        local slotIndex, spellBank, actualSpellID = TryFindBookSlot(candidates[i])
        if slotIndex then return slotIndex, spellBank, actualSpellID end
    end

    for i = 1, #candidates do
        local spellName = GetSpellName(candidates[i])
        if spellName then
            local slotIndex, spellBank, actualSpellID = ScanActiveSpellBookByName(spellName)
            if slotIndex then return slotIndex, spellBank, actualSpellID end
        end
    end
    return nil
end

local function SpellMatchesRelation(spellID, relation)
    if not C_Spell then return true end
    local checker
    if relation == "harm" then
        checker = C_Spell.IsSpellHarmful
    elseif relation == "friend" or relation == "res" or relation == "pet" then
        checker = C_Spell.IsSpellHelpful
    end
    if type(checker) ~= "function" then return true end
    local result = AccessibleBoolean(checker(spellID))
    return result ~= false
end

local function GetSpellRanges(actualSpellID, fallbackMaxRange)
    local info = GetSpellInfoTable(actualSpellID)
    local minRange = info and RoundRange(info.minRange) or nil
    local maxRange = info and RoundRange(info.maxRange) or nil

    if minRange == nil then minRange = 0 end
    if maxRange == nil or maxRange <= 0 then
        maxRange = RoundRange(fallbackMaxRange)
    end
    if not maxRange or maxRange <= 0 then return nil end

    -- A false result from a spell with a positive minimum can mean either
    -- "too close" or "too far". Do not admit it unless another zero-minimum
    -- checker at a compatible range can disambiguate it. QFX currently skips
    -- these probes rather than reporting a false interval.
    if minRange > 0 then return nil end
    return 0, maxRange
end

local function EvaluateSpell(checker, unit)
    if not C_Spell or type(C_Spell.IsSpellInRange) ~= "function" then return nil end
    return AccessibleBoolean(C_Spell.IsSpellInRange(checker.spellID, unit))
end

local function EvaluateItem(checker, unit)
    if not C_Item or type(C_Item.IsItemInRange) ~= "function" then return nil end
    return AccessibleBoolean(C_Item.IsItemInRange(checker.itemID, unit))
end

local function EvaluateGroup(group, unit)
    local sawFalse = false
    for i = 1, #group.checkers do
        local checker = group.checkers[i]
        local result
        if checker.kind == "spell" then
            result = EvaluateSpell(checker, unit)
        elseif checker.kind == "item" then
            result = EvaluateItem(checker, unit)
        end
        if result == true then return true end
        if result == false then sawFalse = true end
    end
    if sawFalse then return false end
    return nil
end

local function AddChecker(groupMap, range, checker, prefer)
    range = RoundRange(range)
    if not range or range <= 0 or type(checker) ~= "table" then return end
    local group = groupMap[range]
    if not group then
        group = { range = range, checkers = {} }
        groupMap[range] = group
    end
    if prefer then
        table.insert(group.checkers, 1, checker)
    else
        group.checkers[#group.checkers + 1] = checker
    end
end

local function GroupMapToDescendingList(groupMap)
    local result = {}
    for _, group in pairs(groupMap) do
        if #group.checkers > 0 then result[#result + 1] = group end
    end
    sort(result, function(a, b) return a.range > b.range end)
    return result
end

local function AddSpellCandidates(groupMap, candidates, relation)
    if type(candidates) ~= "table" then return end
    for i = 1, #candidates do
        local entry = candidates[i]
        local baseSpellID, fallbackMaxRange
        if type(entry) == "table" then
            baseSpellID, fallbackMaxRange = entry[1], entry[2]
        else
            baseSpellID = entry
        end
        baseSpellID = AccessibleNumber(baseSpellID)
        if baseSpellID then
            local slotIndex, spellBank, actualSpellID = ResolveActiveSpell(baseSpellID)
            if slotIndex and actualSpellID and SpellMatchesRelation(actualSpellID, relation) then
                local _, maxRange = GetSpellRanges(actualSpellID, fallbackMaxRange)
                if maxRange then
                    AddChecker(groupMap, maxRange, {
                        kind = "spell",
                        spellID = actualSpellID,
                        slotIndex = slotIndex,
                        spellBank = spellBank,
                        sourceSpellID = baseSpellID,
                    }, false)
                end
            end
        end
    end
end

local function IsItemDataReady(itemID)
    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then return false end
    local name = C_Item.GetItemInfo(itemID)
    return IsAccessible(name) and type(name) == "string" and name ~= ""
end

local function RequestItemData(self, relation, range, itemID)
    if not C_Item or type(C_Item.RequestLoadItemDataByID) ~= "function" then return end
    if self.requestedItems[itemID] then return end
    self.requestedItems[itemID] = true
    self.requestedItemRanges[itemID] = { relation = relation, range = range }
    self.pendingItemRanges[relation] = self.pendingItemRanges[relation] or {}
    self.pendingItemRanges[relation][range] = itemID
    C_Item.RequestLoadItemDataByID(itemID)
end

local function FindReadyRangeItem(self, relation, range, itemIDs)
    if type(itemIDs) ~= "table" then return nil end
    self.pendingItemRanges[relation] = self.pendingItemRanges[relation] or {}

    local pendingItemID = self.pendingItemRanges[relation][range]
    if pendingItemID then
        if IsItemDataReady(pendingItemID) then
            self.pendingItemRanges[relation][range] = nil
            return pendingItemID
        end
        return nil
    end

    local firstUnrequested
    for i = 1, #itemIDs do
        local itemID = AccessibleNumber(itemIDs[i])
        if itemID then
            if IsItemDataReady(itemID) then return itemID end
            if not firstUnrequested and not self.requestedItems[itemID] then
                firstUnrequested = itemID
            end
        end
    end
    if firstUnrequested then RequestItemData(self, relation, range, firstUnrequested) end
    return nil
end

local function AddItemCandidates(self, groupMap, itemData, relation)
    if type(itemData) ~= "table" then return end
    for range, itemIDs in pairs(itemData) do
        local itemID = FindReadyRangeItem(self, relation, range, itemIDs)
        if itemID then
            AddChecker(groupMap, range, { kind = "item", itemID = itemID }, true)
        end
    end
end

local function BuildCheckerLists(self, spellCandidates, itemData, relation, includeItems)
    local normalMap, combatMap = {}, {}

    if includeItems then AddItemCandidates(self, normalMap, itemData, relation) end
    AddSpellCandidates(normalMap, spellCandidates, relation)
    AddSpellCandidates(combatMap, spellCandidates, relation)

    return GroupMapToDescendingList(normalMap), GroupMapToDescendingList(combatMap)
end

local function GetRangeWithCheckerList(unit, checkerList)
    if type(checkerList) ~= "table" or #checkerList == 0 then return nil end

    -- Same descending binary-search model used by LibRangeCheck derivatives.
    -- A checker is monotonic: true inside its range, false outside it.
    local lo, hi = 1, #checkerList
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        local result = EvaluateGroup(checkerList[mid], unit)
        if result == true then
            lo = mid + 1
        else
            hi = mid - 1
        end
    end

    if lo > #checkerList then
        return 0, checkerList[#checkerList].range
    elseif lo <= 1 then
        return checkerList[1].range, nil
    else
        return checkerList[lo].range, checkerList[lo - 1].range
    end
end

local function TryExactDistance(unit)
    if type(UnitDistanceSquared) ~= "function" then return nil end
    local distanceSquared, checkedDistance = UnitDistanceSquared(unit)
    if AccessibleBoolean(checkedDistance) ~= true then return nil end
    distanceSquared = AccessibleNumber(distanceSquared)
    if not distanceSquared or distanceSquared < 0 then return nil end
    return sqrt(distanceSquared)
end

local function TryFriendlyRange(unit)
    if type(UnitInRange) ~= "function" then return nil end
    local inRange, checkedRange = UnitInRange(unit)
    if AccessibleBoolean(checkedRange) ~= true then return nil end
    inRange = AccessibleBoolean(inRange)
    if inRange == true then return 0, lib.FriendlyRange end
    if inRange == false then return lib.FriendlyRange, nil end
    return nil
end

local function GetRelation(unit)
    local canAttack = SafeFlag(UnitCanAttack, "player", unit)
    if canAttack == true then return "harm" end

    local canAssist = SafeFlag(UnitCanAssist, "player", unit)
    if canAssist ~= true then
        local isFriend = SafeFlag(UnitIsFriend, "player", unit)
        if isFriend == true then canAssist = true end
    end

    local isDead = SafeFlag(UnitIsDeadOrGhost, unit)
    if canAssist == true and isDead == true then return "res" end

    local isPet = SafeFlag(UnitIsUnit, "pet", unit)
    if isPet == true then return "pet" end
    if canAssist == true then return "friend" end
    return "misc"
end

local function IsRestrictedUnit(relation)
    if type(InCombatLockdown) ~= "function" or not InCombatLockdown() then return false end
    return relation ~= "harm"
end

local function SelectCheckerList(self, relation)
    if relation == "harm" then
        -- The reference routing keeps hostile item probes available in combat.
        return self.checkerSets.harm
    end
    if IsRestrictedUnit(relation) then
        return self.checkerSets[relation .. "InCombat"] or self.checkerSets[relation]
    end
    return self.checkerSets[relation]
end

function lib:IsAccessible(value)
    return IsAccessible(value)
end

function lib:IsAccessibleNumber(value)
    return AccessibleNumber(value) ~= nil
end

function lib:Rebuild()
    local spellData = ns.LibRangeCheckQFXSpellData
    -- The item probe database is packed on disk and only expands on demand.
    local itemData = type(ns.GetLibRangeCheckQFXItemData) == "function"
        and ns.GetLibRangeCheckQFXItemData() or ns.LibRangeCheckQFXItemData
    local _, classToken = UnitClass("player")
    if not IsAccessible(classToken) or type(classToken) ~= "string" then
        self:Clear()
        return false
    end

    local classData = type(spellData) == "table" and spellData[classToken] or nil
    local commonFriend = type(spellData) == "table" and spellData.commonFriend or nil
    local friendCandidates = CopyArray(classData and classData.friend)
    if type(commonFriend) == "table" then
        for i = 1, #commonFriend do friendCandidates[#friendCandidates + 1] = commonFriend[i] end
    end

    local friend, friendInCombat = BuildCheckerLists(
        self,
        friendCandidates,
        itemData and itemData.friend,
        "friend",
        true
    )
    local harm, harmInCombat = BuildCheckerLists(
        self,
        classData and classData.harm,
        itemData and itemData.harm,
        "harm",
        true
    )
    local res, resInCombat = BuildCheckerLists(self, classData and classData.res, nil, "res", false)
    local pet, petInCombat = BuildCheckerLists(self, classData and classData.pet, nil, "pet", false)

    self.checkerSets = {
        friend = friend,
        friendInCombat = friendInCombat,
        harm = harm,
        harmInCombat = harmInCombat,
        res = res,
        resInCombat = resInCombat,
        pet = pet,
        petInCombat = petInCombat,
        misc = {},
        miscInCombat = {},
    }
    self.classToken = classToken
    self.revision = (self.revision or 0) + 1
    return true
end

function lib:Clear()
    self.checkerSets = {
        friend = {}, friendInCombat = {},
        harm = {}, harmInCombat = {},
        res = {}, resInCombat = {},
        pet = {}, petInCombat = {},
        misc = {}, miscInCombat = {},
    }
    self.classToken = nil
    self.revision = (self.revision or 0) + 1
end

function lib:OnItemDataLoadResult(itemID)
    itemID = AccessibleNumber(itemID)
    if not itemID or not self.requestedItems[itemID] then return false end
    local request = self.requestedItemRanges[itemID]
    self.requestedItemRanges[itemID] = nil
    if type(request) == "table" and self.pendingItemRanges[request.relation]
        and self.pendingItemRanges[request.relation][request.range] == itemID
    then
        self.pendingItemRanges[request.relation][request.range] = nil
    end
    -- Keep requestedItems[itemID] marked to avoid repeatedly requesting a bad ID.
    -- The owning module batches multiple ITEM_DATA_LOAD_RESULT events before
    -- rebuilding, avoiding a burst of repeated spellbook scans.
    return true
end

-- Returns: minRange, maxRange, source, precision, restricted
-- source: distance | spell | item | mixed | unitrange | unknown
-- precision: exact | interval | coarse | unknown
function lib:GetRangeInfo(unit)
    unit = unit or "target"
    if SafeFlag(UnitExists, unit) ~= true then
        return nil, nil, "unknown", "unknown", false
    end

    -- Reject only an explicit invisibility result. Secret/unknown visibility is
    -- not enough reason to discard otherwise safe spell or item probes.
    if type(UnitIsVisible) == "function" and SafeFlag(UnitIsVisible, unit) == false then
        return nil, nil, "unknown", "unknown", false
    end

    local exactDistance = TryExactDistance(unit)
    if exactDistance then
        return exactDistance, exactDistance, "distance", "exact", false
    end

    if not self.classToken then self:Rebuild() end
    local relation = GetRelation(unit)
    local restricted = IsRestrictedUnit(relation)
    local minRange, maxRange

    if relation == "pet" then
        minRange, maxRange = GetRangeWithCheckerList(unit, SelectCheckerList(self, "friend"))
        if minRange == nil and maxRange == nil then
            minRange, maxRange = GetRangeWithCheckerList(unit, SelectCheckerList(self, "pet"))
        end
    else
        minRange, maxRange = GetRangeWithCheckerList(unit, SelectCheckerList(self, relation))
    end

    if minRange ~= nil or maxRange ~= nil then
        return minRange, maxRange, restricted and "spell" or "mixed", "interval", restricted
    end

    if relation == "friend" or relation == "res" or relation == "pet" then
        minRange, maxRange = TryFriendlyRange(unit)
        if minRange ~= nil or maxRange ~= nil then
            return minRange, maxRange, "unitrange", "coarse", restricted
        end
    end

    return nil, nil, "unknown", "unknown", restricted
end

function lib:GetRange(unit)
    local minRange, maxRange = self:GetRangeInfo(unit)
    return minRange, maxRange
end

function lib:GetRevision()
    return self.revision or 0
end

function lib:GetCheckerCounts()
    local result = {}
    for key, list in pairs(self.checkerSets or {}) do
        result[key] = type(list) == "table" and #list or 0
    end
    return result
end

end)
