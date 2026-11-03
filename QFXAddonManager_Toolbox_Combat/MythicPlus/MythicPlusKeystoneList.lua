local _, manager = ...
manager.ToolboxRuntime:AddFile("MythicPlus", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "mythic_plus_keystone_list"
local CHAT_PREFIX = "WA-KeyStGrList"
local FRAME_NAME = "QFXToolBoxKeystoneListFrame"
local HOVER_BUTTON_NAME = "QFXToolBoxKeystoneListHoverButton"
local ROW_HEIGHT = 40
local FRAME_WIDTH = 430
local FRAME_PAD = 4
local HEADER_HEIGHT = 22
local UNLOCK_PREVIEW_ROWS = 5
local PREVIEW_FALLBACK_MAPS = { 584, 585, 586, 587, 588 }
local PREVIEW_LEVELS = { 10, 12, 14, 16, 18 }
local PREVIEW_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE" }
local DUNGEON_GOLD = "|cffffd100"
local READY_GREEN = "|cff40ff59"
local COOLDOWN_RED = "|cffff4040"

local enabled = false
local frame
local hoverButton
local rows = {}
local keystonesDB = {}
local enhancement = ns.KeystoneListEnhancements
local scheduledFullRefresh = false
local challengeModeActive = false
local statusTicker
local StopStatusTicker, StartStatusTicker
local lastFrameLockedState
local lastFrameHeight
local unlockPreviewList

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "GROUP_JOINED",
    "GROUP_LEFT",
    "PLAYER_REGEN_ENABLED",
    "BAG_UPDATE_DELAYED",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "WEEKLY_REWARDS_UPDATE",
    "CHAT_MSG_ADDON",
    "ZONE_CHANGED_NEW_AREA",
    "LFG_LIST_ACTIVE_ENTRY_UPDATE",
    "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_SUCCEEDED",
}

local DUNGEON_INFO = ns.DungeonData.maps

local function L(key)
    return ns.L and ns.L(key) or key
end

local SafeCall = ns.Compat.Call

local SafeNumber = ns.Compat.SafeNumber

local SafeString = ns.Compat.SafeString

local function SafeField(tbl, key)
    -- Plain field reads cannot throw; secret-protected values flow onward to
    -- SafeNumber, which filters them without a pcall closure per read.
    if type(tbl) ~= "table" then return nil end
    return tbl[key]
end

local function ReadBooleanCall(fn, ...)
    if ns.Compat and ns.Compat.ReadBooleanCall then
        return ns.Compat.ReadBooleanCall(fn, ...)
    end
    if type(fn) ~= "function" then return nil end
    local value = SafeCall(fn, ...)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if value == nil then return nil end
    local ok, result = pcall(function() return value == true end)
    if not ok then return nil end
    return result == true
end

local function ReadUnitFullName(unit)
    if ns.Compat and ns.Compat.GetUnitFullName then
        return ns.Compat.GetUnitFullName(unit)
    end
    if type(UnitFullName) ~= "function" then return nil end
    local name, realm = SafeCall(UnitFullName, unit)
    name = SafeString(name, nil)
    realm = SafeString(realm, nil)
    if not name or name == "" then return nil end
    return name, realm
end

local function ReadUnitClassFile(unit)
    if ns.Compat and ns.Compat.GetUnitClassFile then
        return ns.Compat.GetUnitClassFile(unit)
    end
    if type(UnitClass) ~= "function" then return nil end
    local _, classFile = SafeCall(UnitClass, unit)
    return SafeString(classFile, nil)
end

local function InCombat()
    return ns.Compat and ns.Compat.InCombatLockdown and ns.Compat.InCombatLockdown()
        or (InCombatLockdown and InCombatLockdown())
end

local function IsInsideInstanceOrRaid()
    if IsInRaid and IsInRaid() then return true end
    if IsInInstance then
        local inInstance = SafeCall(IsInInstance)
        if inInstance then return true end
    end
    return false
end

local function GetDB()
    return ns.GetModuleDB and ns.GetModuleDB(KEY) or {}
end

local DEFAULT_QUEUE_GLOW_COLOR = {
    r = 1.00,
    g = 0.82,
    b = 0.00,
    a = 1.00,
}

local DEFAULT_CAST_GLOW_COLOR = {
    r = 0.25,
    g = 0.72,
    b = 1.00,
    a = 1.00,
}

local function EnsureGlowDB(db)
    db = type(db) == "table" and db or GetDB()
    db.queueGlowColor = ns.GlowService:NormalizeColor(db.queueGlowColor, DEFAULT_QUEUE_GLOW_COLOR)
    db.castGlowColor = ns.GlowService:NormalizeColor(db.castGlowColor, DEFAULT_CAST_GLOW_COLOR)
    db.glowSpeed = ns.GlowService:NormalizeSpeed(db.glowSpeed)
    db.glowStyle = ns.GlowService:NormalizeStyle(db.glowStyle)
    return db
end

local function RefreshGlowSettings(db)
    EnsureGlowDB(db)
    if enhancement and enhancement.RefreshGlowSettings then
        enhancement:RefreshGlowSettings()
    end
end

local function ResetGlowSettings(db)
    db.queueGlowColor = {
        r = 1.00,
        g = 0.82,
        b = 0.00,
        a = 1.00,
    }
    db.castGlowColor = {
        r = 0.25,
        g = 0.72,
        b = 1.00,
        a = 1.00,
    }
    db.glowSpeed = 1.00
    RefreshGlowSettings(db)
end

local function IsListLocked()
    return GetDB().keystoneListLocked == true
end

local function GetRowStartY()
    if IsListLocked() then return -FRAME_PAD end
    return -(HEADER_HEIGHT + FRAME_PAD)
end

local function GetFrameHeight(rowCount)
    rowCount = math.max(1, SafeNumber(rowCount, 1) or 1)
    if IsListLocked() then
        return FRAME_PAD * 2 + rowCount * ROW_HEIGHT
    end
    return HEADER_HEIGHT + FRAME_PAD + math.max(UNLOCK_PREVIEW_ROWS, rowCount) * ROW_HEIGHT + FRAME_PAD
end

local function GoldText(text)
    return DUNGEON_GOLD .. tostring(text or "?") .. "|r"
end

local function ReadyText()
    return READY_GREEN .. "(" .. L("Keystone Port Ready") .. ")|r"
end

local function CooldownText()
    return COOLDOWN_RED .. "(" .. L("Keystone Port Cooldown") .. ")|r"
end

local function NoPortText()
    return COOLDOWN_RED .. "(" .. L("No Port") .. ")|r"
end

local function GetPlayerFullName()
    local name, realm = ReadUnitFullName("player")
    if not name and type(UnitName) == "function" then
        name = SafeString(SafeCall(UnitName, "player"), nil)
    end
    if not name then return nil end
    realm = (realm and realm ~= "") and realm or SafeString(SafeCall(GetRealmName), "")
    return realm ~= "" and (name .. "-" .. realm) or name
end

local function NormalizeFullName(name, realm)
    name = SafeString(name, nil)
    realm = SafeString(realm, nil)
    if not name or name == "" then return nil end
    if name:find("-", 1, true) then return name end
    local _, playerRealm = ReadUnitFullName("player")
    realm = (realm and realm ~= "") and realm or playerRealm or SafeString(SafeCall(GetRealmName), "")
    return realm ~= "" and (name .. "-" .. realm) or name
end

local function ShortName(fullName)
    if not fullName then return "?" end
    if Ambiguate then return Ambiguate(fullName, "short") end
    return tostring(fullName):match("^([^-]+)") or tostring(fullName)
end

local function GetClassForFullName(fullName)
    if not fullName then return nil end
    local target = Ambiguate and Ambiguate(fullName, "none") or fullName
    local function check(unit)
        if not (UnitExists and UnitExists(unit)) then return nil end
        local n, r = ReadUnitFullName(unit)
        if not n then return nil end
        local uFull = NormalizeFullName(n, r)
        local cmp = Ambiguate and Ambiguate(uFull or "", "none") or uFull
        if cmp == target then
            return ReadUnitClassFile(unit)
        end
    end
    local own = check("player")
    if own then return own end
    for i = 1, 4 do
        local classFile = check("party" .. i)
        if classFile then return classFile end
    end
    return nil
end

local KEYSTONE_SOURCE_PRIORITY = {
    exwind = 5,
    libkeystone = 10,
    openraid = 20,
    native = 30,
    self = 40,
}

local function UpsertKeystone(data, source)
    if type(data) ~= "table" then return false end
    local owner = data.keystoneOwner or data.owner
    owner = NormalizeFullName(owner)
    local mapID = SafeNumber(data.challengeMapID, nil)
    local level = SafeNumber(data.keystoneLevel, nil)
    if not owner or not mapID or mapID <= 0 or not level or level <= 0 then return false end

    source = source or "native"
    local priority = KEYSTONE_SOURCE_PRIORITY[source] or 0
    local existing = keystonesDB[owner]
    local oldPriority = existing and SafeNumber(existing._qfxSourcePriority, 0) or 0
    if existing and oldPriority > priority then return false, existing end

    local record = {
        challengeMapID = mapID,
        keystoneLevel = level,
        activityID = SafeNumber(data.activityID, 0) or 0,
        groupID = SafeNumber(data.groupID, 0) or 0,
        resilientFlag = SafeNumber(data.resilientFlag, 0) or 0,
        keystoneOwner = owner,
        owner = owner,
        class = data.class or (existing and existing.class) or GetClassForFullName(owner),
        isSelf = data.isSelf == true,
        updatedAt = data.updatedAt or (GetTime and GetTime() or 0),
        _qfxSource = source,
        _qfxSourcePriority = priority,
    }

    local changed = not existing
        or existing.challengeMapID ~= record.challengeMapID
        or existing.keystoneLevel ~= record.keystoneLevel
        or existing.activityID ~= record.activityID
        or existing.groupID ~= record.groupID
        or existing.resilientFlag ~= record.resilientFlag
        or existing._qfxSourcePriority ~= record._qfxSourcePriority
    keystonesDB[owner] = record
    if enhancement and enhancement.OnKeystoneUpdated then
        enhancement:OnKeystoneUpdated(record, changed)
    end
    return changed, record
end

local function ClassColorText(text, classFile)
    text = tostring(text or "")
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = classFile and colors and colors[classFile]
    if not color then return text end
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor((color.r or 1) * 255 + 0.5),
        math.floor((color.g or 1) * 255 + 0.5),
        math.floor((color.b or 1) * 255 + 0.5),
        text)
end

local function GetSmallGroupChannel()
    if ns.Compat and ns.Compat.GetSmallGroupChannel then
        return ns.Compat.GetSmallGroupChannel()
    end
    if type(IsInRaid) == "function" then
        local inRaid = ReadBooleanCall(IsInRaid)
        if inRaid ~= false then return nil end
    end

    local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
    local homeCategory = _G.LE_PARTY_CATEGORY_HOME
    local inInstanceGroup
    if instanceCategory ~= nil then
        inInstanceGroup = ReadBooleanCall(IsInGroup, instanceCategory)
    end
    if inInstanceGroup == true then return "INSTANCE_CHAT" end

    local inHomeGroup
    if homeCategory ~= nil then
        inHomeGroup = ReadBooleanCall(IsInGroup, homeCategory)
    end
    if inHomeGroup == true then return "PARTY" end

    -- On modern clients the category checks are authoritative. In particular,
    -- scenario/delve transitions can briefly make the generic group state look
    -- grouped even though PARTY is not a valid chat destination.
    if instanceCategory ~= nil or homeCategory ~= nil then return nil end

    -- Compatibility fallback for clients that do not expose group categories.
    return ReadBooleanCall(IsInGroup) == true and "PARTY" or nil
end

local function IsInSmallGroup()
    return GetSmallGroupChannel() ~= nil
end

-- Dungeon name/texture from GetMapUIInfo never change during a session; the
-- status ticker and row rebuilds hit this repeatedly, so cache per mapID.
local mapUICache = {}

local function GetDungeonInfo(mapID)
    mapID = SafeNumber(mapID, nil)
    local info = mapID and DUNGEON_INFO[mapID]
    if not mapID then return "?", 136116, info end

    local cached = mapUICache[mapID]
    if not cached then
        local name, _, _, texture
        if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            name, _, _, texture = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
        end
        cached = { name = name or tostring(mapID), texture = texture or 136116 }
        mapUICache[mapID] = cached
    end
    return cached.name, cached.texture, info
end

local function GetDungeonName(mapID, useAbbr)
    local name, _, info = GetDungeonInfo(mapID)
    if useAbbr and info and (info.listAbbr or info.abbr) then return info.listAbbr or info.abbr end
    return name
end

local function SelectTeleportSpell(mapID)
    local _, _, info = GetDungeonInfo(mapID)
    local port = info and (info.listPort or info.ports)
    if type(port) == "table" then
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        port = faction == "Horde" and port[2] or port[1]
    end
    return SafeNumber(port, nil)
end

local function IsKnownSpell(spellID)
    spellID = SafeNumber(spellID, nil)
    if not spellID then return false end
    if ns.Compat and ns.Compat.IsSpellKnown then
        return ns.Compat.IsSpellKnown(spellID)
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        local known = bank and SafeCall(C_SpellBook.IsSpellKnown, spellID, bank)
        if known ~= nil then return known == true end
        known = SafeCall(C_SpellBook.IsSpellKnown, spellID)
        if known ~= nil then return known == true end
    end
    if IsPlayerSpell and SafeCall(IsPlayerSpell, spellID) then return true end
    if IsSpellKnown and SafeCall(IsSpellKnown, spellID) then return true end
    return false
end

local function GetCooldownRemaining(spellID)
    spellID = SafeNumber(spellID, nil)
    if not spellID then return nil end
    local startTime, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = SafeCall(C_Spell.GetSpellCooldown, spellID)
        if type(info) == "table" then
            startTime = SafeNumber(SafeField(info, "startTime"), nil)
            duration = SafeNumber(SafeField(info, "duration"), nil)
        end
    elseif GetSpellCooldown then
        startTime, duration = SafeCall(GetSpellCooldown, spellID)
        startTime = SafeNumber(startTime, nil)
        duration = SafeNumber(duration, nil)
    end
    -- Cooldown values can be Secret while cooldown access is restricted.  Do
    -- not infer "ready" from an unreadable value.
    if startTime == nil or duration == nil then return nil end
    if duration <= 1.5 then return 0 end
    return math.max(0, startTime + duration - (GetTime and GetTime() or 0))
end

local function FormatTime(seconds)
    seconds = math.floor(SafeNumber(seconds, 0) or 0)
    if seconds >= 3600 then
        return string.format("%dh", math.ceil(seconds / 3600))
    end
    if seconds >= 60 then
        return string.format("%dm", math.ceil(seconds / 60))
    end
    return string.format("%ds", seconds)
end

local function GetPortStatus(mapID)
    local spellID = SelectTeleportSpell(mapID)
    if not spellID or not IsKnownSpell(spellID) then return "noport", 0, spellID end
    local remain = GetCooldownRemaining(spellID)
    if remain == nil then return "unknown", 0, spellID end
    if remain > 0 then return "cooldown", remain, spellID end
    return "ready", 0, spellID
end

local function GetOwnedKeystone()
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and
        SafeCall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    mapID = SafeNumber(mapID, nil)
    local activityID, groupID, level
    if C_LFGList and C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel then
        activityID, groupID, level = SafeCall(C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel)
    end
    level = SafeNumber(level, nil)
    if not level and C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel then
        level = SafeNumber(SafeCall(C_MythicPlus.GetOwnedKeystoneLevel), nil)
    end
    activityID = SafeNumber(activityID, 0) or 0
    groupID = SafeNumber(groupID, 0) or 0
    if not mapID or mapID <= 0 or not level or level <= 0 then return nil end
    return {
        challengeMapID = mapID,
        keystoneLevel = level,
        activityID = activityID,
        groupID = groupID,
        resilientFlag = 0,
    }
end

local function StorePersonalKeystone()
    local owner = GetPlayerFullName()
    if not owner then return nil end
    local key = GetOwnedKeystone()
    if not key then
        keystonesDB[owner] = nil
        return nil
    end
    local classFile = ReadUnitClassFile("player")
    key.keystoneOwner = owner
    key.owner = owner
    key.class = classFile
    key.isSelf = true
    key.updatedAt = GetTime and GetTime() or 0
    local _, stored = UpsertKeystone(key, "self")
    return stored
end

local function SendOwnKeystone()
    local channel = GetSmallGroupChannel()
    if not enabled or not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    local key = StorePersonalKeystone()
    if not key then return false end
    local message = string.format("KSGL:Send:%d:%d:%d:%d:%d",
        key.challengeMapID or 0,
        key.keystoneLevel or 0,
        key.activityID or 0,
        key.groupID or 0,
        key.resilientFlag or 0)
    return SafeCall(C_ChatInfo.SendAddonMessage, CHAT_PREFIX, message, channel) and true or false
end

local function RequestPartyKeystones()
    local channel = GetSmallGroupChannel()
    if not enabled or not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    return SafeCall(C_ChatInfo.SendAddonMessage, CHAT_PREFIX, "KSGL:Request:0", channel) and true or false
end

local function IsPartyMember(fullName)
    if not fullName then return false end
    local selfName = GetPlayerFullName()
    local target = Ambiguate and Ambiguate(fullName, "none") or fullName
    local selfCompare = Ambiguate and Ambiguate(selfName or "", "none") or selfName
    if target == selfCompare then return true end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists and UnitExists(unit) then
            local n, r = ReadUnitFullName(unit)
            local uFull = NormalizeFullName(n, r)
            local cmp = Ambiguate and Ambiguate(uFull or "", "none") or uFull
            if cmp == target then return true end
        end
    end
    return false
end

local function PruneLeftMembers()
    local own = GetPlayerFullName()
    for owner in pairs(keystonesDB) do
        if owner ~= own and not IsPartyMember(owner) then
            keystonesDB[owner] = nil
        end
    end
end

local function SavePosition()
    if not frame then return end
    local db = GetDB()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    db.keystoneListPoint = point or "CENTER"
    db.keystoneListRelPoint = relPoint or "CENTER"
    db.keystoneListX = math.floor((tonumber(x) or 0) + 0.5)
    db.keystoneListY = math.floor((tonumber(y) or 0) + 0.5)
end

local function ApplyFramePosition()
    if not frame then return end
    local db = GetDB()
    frame:ClearAllPoints()
    frame:SetPoint(db.keystoneListPoint or "CENTER", UIParent, db.keystoneListRelPoint or "CENTER",
        tonumber(db.keystoneListX) or 0, tonumber(db.keystoneListY) or 160)
end

local function ApplyFrameSettings()
    if not frame then return end
    local db = GetDB()
    local scale = tonumber(db.keystoneListScale) or 1
    if scale < 0.6 then scale = 0.6 elseif scale > 1.8 then scale = 1.8 end
    frame:SetScale(scale)
    frame:SetMovable(not db.keystoneListLocked)
    frame:EnableMouse(true)
end

local function ApplyLockVisualState()
    if not frame then return end
    local locked = IsListLocked()
    if lastFrameLockedState == locked then
        return
    end
    lastFrameLockedState = locked

    if frame.header then
        frame.header:SetShown(not locked)
    end

end

local ShowTooltip

local function HideTooltipOwnedBy(owner)
    if owner and GameTooltip:IsOwned(owner) then
        GameTooltip:Hide()
        return true
    end
    return false
end

local function HideListTooltip()
    if not frame then return end
    local owner = GameTooltip:GetOwner()
    while owner do
        if owner == frame then
            GameTooltip:Hide()
            return
        end
        if not owner.GetParent then return end
        owner = owner:GetParent()
    end
end

local function EnsureHoverButton()
    if hoverButton then return hoverButton end
    hoverButton = _G[HOVER_BUTTON_NAME] or CreateFrame("Button", HOVER_BUTTON_NAME, frame or UIParent, "InsecureActionButtonTemplate")
    hoverButton:RegisterForClicks("AnyDown", "AnyUp")
    hoverButton:SetAttribute("type1", "spell")
    hoverButton:SetFrameStrata("HIGH")
    hoverButton:SetScript("OnEnter", function(self)
        ShowTooltip(self, self.tooltipData)
    end)
    hoverButton:SetScript("OnLeave", function(self)
        HideTooltipOwnedBy(self)
        self.tooltipData = nil
        self:ClearAllPoints()
        self:Hide()
    end)
    hoverButton:Hide()
    return hoverButton
end

local function HideHoverButton()
    if hoverButton then
        local iconBox = hoverButton:GetParent()
        if not HideTooltipOwnedBy(hoverButton) then
            HideTooltipOwnedBy(iconBox)
        end
        hoverButton.tooltipData = nil
        hoverButton:ClearAllPoints()
        hoverButton:Hide()
    end
end

local function AttachHoverButton(iconBox, data)
    local db = GetDB()
    if not data or data.isUnlockPreview or not db.keystoneListClickTeleport or InCombat() then
        HideHoverButton()
        return
    end
    local status, _, spellID = GetPortStatus(data.challengeMapID)
    if status ~= "ready" or not spellID then
        HideHoverButton()
        return
    end
    local button = EnsureHoverButton()
    button.tooltipData = data
    button:SetParent(iconBox)
    button:SetFrameLevel(iconBox:GetFrameLevel() + 5)
    button:ClearAllPoints()
    button:SetAllPoints(iconBox)
    button:SetAttribute("spell", spellID)
    button:Show()
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - FRAME_PAD * 2, ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.bg:Hide()

    row.iconBox = CreateFrame("Frame", nil, row)
    row.iconBox:SetSize(32, 32)
    row.iconBox:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.iconBox:EnableMouse(true)
    -- Tooltip handlers are installed once per row; they read row.data so row
    -- rebuilds do not allocate fresh closures for every list refresh.
    row.iconBox:SetScript("OnEnter", function(self)
        local data = row.data
        if not data or data.isUnlockPreview then return end
        ShowTooltip(self, data)
        AttachHoverButton(self, data)
    end)
    row.iconBox:SetScript("OnLeave", function(_)
        if not (hoverButton and hoverButton:IsMouseOver()) then
            HideHoverButton()
            GameTooltip:Hide()
        end
    end)
    row.icon = row.iconBox:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints(row.iconBox)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.levelText = row.iconBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.levelText:SetPoint("CENTER", row.iconBox, "CENTER", 0, 0)
    row.levelText:SetJustifyH("CENTER")
    row.levelText:SetJustifyV("MIDDLE")
    row.levelText:SetTextColor(1, 0.82, 0, 1)
    row.levelText:SetShadowColor(0, 0, 0, 1)
    row.levelText:SetShadowOffset(1, -1)

    row.ownerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.ownerText:SetPoint("TOPLEFT", row.iconBox, "TOPRIGHT", 8, -1)
    row.ownerText:SetSize(285, 16)
    row.ownerText:SetJustifyH("LEFT")
    if row.ownerText.SetWordWrap then row.ownerText:SetWordWrap(false) end

    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.dungeonText:SetPoint("TOPLEFT", row.ownerText, "BOTTOMLEFT", 0, -2)
    row.dungeonText:SetSize(285, 17)
    row.dungeonText:SetJustifyH("LEFT")
    row.dungeonText:SetTextColor(1, 0.82, 0, 1)
    if row.dungeonText.SetWordWrap then row.dungeonText:SetWordWrap(false) end

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.statusText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.statusText:SetSize(96, 16)
    row.statusText:SetJustifyH("RIGHT")
    if row.statusText.SetWordWrap then row.statusText:SetWordWrap(false) end

    rows[index] = row
    return row
end

local function EnsureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(FRAME_WIDTH, 64)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if GetDB().keystoneListLocked then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetScript("OnHide", function()
        HideHoverButton()
        HideListTooltip()
        if StopStatusTicker then StopStatusTicker() end
        if enhancement and enhancement.ClearRowEffects then enhancement:ClearRowEffects() end
    end)
    frame:SetScript("OnShow", function()
        if IsListLocked() and StartStatusTicker then StartStatusTicker() end
    end)

    frame.header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.header:SetText(L("Party Keystone List"))

    ApplyFramePosition()
    ApplyFrameSettings()
    frame:Hide()
    return frame
end

local function ShouldShow()
    if not enabled then return false end
    local db = GetDB()
    if not db.enabled then return false end
    -- Unlocking is the positioning/test state. Always show the local five-key
    -- preview so the frame can be placed even while solo or inside an instance.
    if not IsListLocked() then return true end
    if IsInsideInstanceOrRaid() then return false end
    if db.keystoneListHideInChallengeMode and challengeModeActive then return false end
    if IsInSmallGroup() then
        return db.keystoneListShowInParty ~= false
    end
    return db.keystoneListShowSolo == true
end

local function CollectUnlockPreviewMapIDs()
    local mapIDs, seen = {}, {}

    local function addMapID(value)
        local mapID = SafeNumber(value, nil)
        if not mapID or mapID <= 0 or seen[mapID] then return end
        seen[mapID] = true
        mapIDs[#mapIDs + 1] = mapID
    end

    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        local currentMaps = SafeCall(C_ChallengeMode.GetMapTable)
        if type(currentMaps) == "table" then
            for _, mapID in ipairs(currentMaps) do
                addMapID(mapID)
                if #mapIDs >= UNLOCK_PREVIEW_ROWS then break end
            end
        end
    end

    for _, mapID in ipairs(PREVIEW_FALLBACK_MAPS) do
        if #mapIDs >= UNLOCK_PREVIEW_ROWS then break end
        addMapID(mapID)
    end

    if #mapIDs < UNLOCK_PREVIEW_ROWS then
        local knownMaps = {}
        for mapID in pairs(DUNGEON_INFO) do
            knownMaps[#knownMaps + 1] = mapID
        end
        table.sort(knownMaps)
        for _, mapID in ipairs(knownMaps) do
            if #mapIDs >= UNLOCK_PREVIEW_ROWS then break end
            addMapID(mapID)
        end
    end

    return mapIDs
end

local function BuildUnlockPreviewList()
    if unlockPreviewList then return unlockPreviewList end

    local mapIDs = CollectUnlockPreviewMapIDs()
    local playerName = ShortName(GetPlayerFullName())
    local playerClass = ReadUnitClassFile("player")
    local list = {}

    for index = 1, UNLOCK_PREVIEW_ROWS do
        local isSelf = index == 1
        local displayName = isSelf and playerName or (L("Preview") .. " " .. tostring(index))
        list[index] = {
            challengeMapID = mapIDs[index] or PREVIEW_FALLBACK_MAPS[index] or PREVIEW_FALLBACK_MAPS[1],
            keystoneLevel = PREVIEW_LEVELS[index] or (8 + index * 2),
            activityID = 0,
            groupID = 0,
            resilientFlag = 0,
            keystoneOwner = displayName .. "-Preview",
            owner = displayName,
            class = isSelf and (playerClass or "WARRIOR") or PREVIEW_CLASSES[index - 1] or "WARRIOR",
            isSelf = isSelf,
            isUnlockPreview = true,
        }
    end

    unlockPreviewList = list
    return list
end

local function BuildDisplayList()
    if not IsListLocked() then
        return BuildUnlockPreviewList()
    end

    unlockPreviewList = nil
    local own = GetPlayerFullName()
    local list = {}
    for owner, data in pairs(keystonesDB) do
        if type(data) == "table" and data.challengeMapID and data.keystoneLevel then
            data.owner = owner
            data.isSelf = owner == own
            data.class = data.class or GetClassForFullName(owner)
            list[#list + 1] = data
        end
    end
    table.sort(list, function(a, b)
        if a.isSelf ~= b.isSelf then return a.isSelf end
        local al = tonumber(a.keystoneLevel) or 0
        local bl = tonumber(b.keystoneLevel) or 0
        if al ~= bl then return al > bl end
        return tostring(a.owner or "") < tostring(b.owner or "")
    end)
    return list
end

local function SetCachedText(fontString, cacheKey, text)
    text = text or ""
    if fontString[cacheKey] ~= text then
        fontString:SetText(text)
        fontString[cacheKey] = text
    end
end

local function UpdateRowStatus(row, data)
    if not row or not data then return end
    local db = GetDB()

    SetCachedText(row.ownerText, "_qfxText", ClassColorText(ShortName(data.owner), data.class))

    local dungeonName = data.dungeonDisplayName or GetDungeonName(data.challengeMapID, db.keystoneListUseAbbreviation ~= false) or "?"
    if data.isUnlockPreview then
        SetCachedText(row.dungeonText, "_qfxText", GoldText(dungeonName))
        SetCachedText(row.statusText, "_qfxText", "")
        return
    end

    local status, remain = GetPortStatus(data.challengeMapID)
    local dungeonText = GoldText(dungeonName)
    if status == "ready" then
        dungeonText = dungeonText .. " " .. ReadyText()
    elseif status == "cooldown" then
        dungeonText = dungeonText .. " " .. CooldownText()
    elseif status == "noport" and db.keystoneListShowNoPort ~= false then
        dungeonText = dungeonText .. " " .. NoPortText()
    end
    SetCachedText(row.dungeonText, "_qfxText", dungeonText)

    -- All teleport states are shown beside the dungeon name.
    SetCachedText(row.statusText, "_qfxText", "")
end

ShowTooltip = function(owner, data)
    if not data then return end
    local db = GetDB()
    local name = GetDungeonName(data.challengeMapID, false)
    local status, remain, spellID = GetPortStatus(data.challengeMapID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(ShortName(data.owner), 1, 1, 1)
    GameTooltip:AddLine(L("Dungeon") .. ": " .. tostring(name or "?"), 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine(L("Level") .. ": +" .. tostring(data.keystoneLevel or "?"), 1, 0.82, 0, true)
    if status == "ready" then
        GameTooltip:AddLine(L("Ready"), 0.25, 1, 0.35, true)
    elseif status == "cooldown" then
        GameTooltip:AddLine(L("Port CD") .. ": " .. FormatTime(remain), 1, 0.62, 0.18, true)
    elseif status == "noport" then
        GameTooltip:AddLine(L("No Port"), 0.9, 0.3, 0.25, true)
    else
        GameTooltip:AddLine(L("N/A"), 0.65, 0.65, 0.65, true)
    end
    if status == "ready" and db.keystoneListClickTeleport and spellID then
        local spellName = (ns.Compat and ns.Compat.GetSpellName and ns.Compat.GetSpellName(spellID, tostring(spellID))) or tostring(spellID)
        GameTooltip:AddLine(L("Click Icon to Teleport") .. ": " .. spellName, 0.75, 0.85, 1, true)
    end
    GameTooltip:Show()
end

local function ConfigureRow(row, data, index)
    local db = GetDB()
    local dungeonName, texture = GetDungeonInfo(data.challengeMapID)
    row.data = data
    data.dungeonDisplayName = GetDungeonName(data.challengeMapID, db.keystoneListUseAbbreviation ~= false) or dungeonName or "?"
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PAD, GetRowStartY() - (index - 1) * ROW_HEIGHT)
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.icon:SetTexture(texture)
    row.levelText:SetText("+" .. tostring(data.keystoneLevel or "?"))
    UpdateRowStatus(row, data)
    row:Show()
    if enhancement and enhancement.ApplyRowEffects then
        enhancement:ApplyRowEffects(row, data)
    end
end

local function UpdateStatusOnly()
    if not frame or not frame:IsVisible() then return end
    for _, row in ipairs(rows) do
        if row:IsShown() and row.data then
            UpdateRowStatus(row, row.data)
        end
    end
end

StopStatusTicker = function()
    if statusTicker then
        statusTicker:Cancel()
        statusTicker = nil
    end
end

StartStatusTicker = function()
    if statusTicker or not enabled or not frame or not frame:IsVisible() then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    statusTicker = C_Timer.NewTicker(10, function()
        if not enabled or not frame or not frame:IsVisible() then
            StopStatusTicker()
            return
        end
        UpdateStatusOnly()
    end)
end

local function RebuildDisplay()
    scheduledFullRefresh = false
    if not enabled then return end

    HideHoverButton()
    HideListTooltip()

    local previewing = not IsListLocked()
    if not previewing then
        StorePersonalKeystone()
    end

    if not ShouldShow() then
        StopStatusTicker()
        if frame then frame:Hide() end
        return
    end

    local f = EnsureFrame()
    ApplyFrameSettings()
    local list = BuildDisplayList()
    local count = #list
    if count == 0 then
        StopStatusTicker()
        f:Hide()
        return
    end
    local frameHeight = GetFrameHeight(count)
    if lastFrameHeight ~= frameHeight then
        f:SetHeight(frameHeight)
        lastFrameHeight = frameHeight
    end
    SetCachedText(f.header, "_qfxText",
        previewing and (L("Party Keystone List") .. " - " .. L("Preview")) or L("Party Keystone List"))
    ApplyLockVisualState()

    for i, data in ipairs(list) do
        ConfigureRow(rows[i] or CreateRow(f, i), data, i)
    end

    for i = count + 1, #rows do
        rows[i].data = nil
        rows[i]:Hide()
    end
    if enhancement and enhancement.SyncRows then enhancement:SyncRows() end
    f:Show()
    if previewing then
        StopStatusTicker()
    else
        StartStatusTicker()
    end
end

local function ScheduleFullRefresh(delay)
    if not enabled or scheduledFullRefresh then return end
    scheduledFullRefresh = true
    local after = (ns.Util and ns.Util.After) or (ns.Compat and ns.Compat.After)
    if after then
        after(delay or 0.2, RebuildDisplay)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.2, RebuildDisplay)
    else
        RebuildDisplay()
    end
end

local function RegisterChatPrefix()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
    if C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(CHAT_PREFIX) then return end
    SafeCall(C_ChatInfo.RegisterAddonMessagePrefix, CHAT_PREFIX)
end

local function ParseAddonMessage(message, sender)
    if not enabled or type(message) ~= "string" then return end
    local senderName = NormalizeFullName(sender)
    if not senderName or senderName == GetPlayerFullName() then return end

    local kind = message:match("^KSGL:(%a+):")
    if kind == "Request" then
        SendOwnKeystone()
        return
    end
    if kind ~= "Send" then return end

    local mapID, level, activityID, groupID, resilientFlag = message:match("^KSGL:Send:(%d+):(%d+):(%d+):(%d+):(%d+)")
    mapID = SafeNumber(mapID, nil)
    level = SafeNumber(level, nil)
    if not mapID or not level then return end

    local changed = UpsertKeystone({
        challengeMapID = mapID,
        keystoneLevel = level,
        activityID = SafeNumber(activityID, 0) or 0,
        groupID = SafeNumber(groupID, 0) or 0,
        resilientFlag = SafeNumber(resilientFlag, 0) or 0,
        keystoneOwner = senderName,
        owner = senderName,
        class = GetClassForFullName(senderName),
        updatedAt = GetTime and GetTime() or 0,
    }, "native")
    if changed then ScheduleFullRefresh(0.05) end
end

local function RefreshChallengeModeState()
    challengeModeActive = false
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
        challengeModeActive = SafeCall(C_ChallengeMode.IsChallengeModeActive) == true
    end
end

local function OnEvent(event, ...)
    if not enabled then return end
    if enhancement and enhancement.OnEvent then enhancement:OnEvent(event, ...) end
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == CHAT_PREFIX then ParseAddonMessage(message, sender) end
        return
    end
    if event == "CHALLENGE_MODE_START" then
        challengeModeActive = true
        ScheduleFullRefresh(0.05)
        return
    end
    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        challengeModeActive = false
        ScheduleFullRefresh(0.2)
        return
    end
    if event == "GROUP_ROSTER_UPDATE" then
        PruneLeftMembers()
        SendOwnKeystone()
        RequestPartyKeystones()
        ScheduleFullRefresh(0.2)
        return
    end
    if event == "BAG_UPDATE_DELAYED" or event == "WEEKLY_REWARDS_UPDATE" then
        StorePersonalKeystone()
        SendOwnKeystone()
        ScheduleFullRefresh(0.2)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        RefreshChallengeModeState()
        StorePersonalKeystone()
        SendOwnKeystone()
        RequestPartyKeystones()
        ScheduleFullRefresh(0.2)
    end
end

local function InitializeEnhancement()
    if not (enhancement and enhancement.Initialize) then return end
    enhancement:Initialize({
        IsEnabled = function() return enabled end,
        L = L,
        NormalizeFullName = NormalizeFullName,
        GetPlayerFullName = GetPlayerFullName,
        GetGroupChannel = GetSmallGroupChannel,
        GetUnitFullName = ReadUnitFullName,
        ReadBooleanCall = ns.Compat and ns.Compat.ReadBooleanCall or nil,
        GetClassForFullName = GetClassForFullName,
        IsPartyMember = IsPartyMember,
        UpsertKeystone = UpsertKeystone,
        GetKeystone = function(owner) return keystonesDB[owner] end,
        GetDB = function() return EnsureGlowDB(GetDB()) end,
        GetRows = function() return rows end,
        GetDungeonName = GetDungeonName,
        SelectTeleportSpell = SelectTeleportSpell,
        SendOwnKeystone = SendOwnKeystone,
        RequestPartyKeystones = RequestPartyKeystones,
        ScheduleRefresh = ScheduleFullRefresh,
    })
end

local function DisableEnhancement()
    if enhancement and enhancement.Disable then enhancement:Disable() end
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

local function SetOption(db, field, value)
    db[field] = value
    if field == "keystoneListLocked" or field == "keystoneListScale" then
        ApplyFrameSettings()
    end
    if field == "keystoneListLocked" then
        unlockPreviewList = nil
        lastFrameLockedState = nil
        lastFrameHeight = nil
        HideHoverButton()
        if value ~= true then
            StopStatusTicker()
        end
        ApplyLockVisualState()
    end
    if enabled then ScheduleFullRefresh(0.05) end
end

local function EnabledRule(db, ui)
    if db.enabled then return true end
    return false, ui.L("Enable this tool first.")
end

ns.RegisterModule(KEY, {
    titleKey = "Party Keystone List",
    descKey = "Shows your party's Mythic+ keystones and lets you click learned dungeon teleport icons.",
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function(_, db)
        EnsureGlowDB(db)
        enabled = true
        InitializeEnhancement()
        RegisterChatPrefix()
        RegisterEvents()
        RefreshChallengeModeState()
        EnsureFrame()
        StorePersonalKeystone()
        SendOwnKeystone()
        RequestPartyKeystones()
        ScheduleFullRefresh(0.05)
    end,
    OnDisable = function()
        enabled = false
        DisableEnhancement()
        scheduledFullRefresh = false
        UnregisterEvents()
        StopStatusTicker()
        HideHoverButton()
        unlockPreviewList = nil
        if frame then frame:Hide() end
    end,
    ApplySettings = function(_, db)
        EnsureGlowDB(db)
        if db.enabled then
            if not enabled then
                enabled = true
                InitializeEnhancement()
                RegisterChatPrefix()
                RegisterEvents()
            end
            EnsureFrame()
            ApplyFramePosition()
            ApplyFrameSettings()
            ScheduleFullRefresh(0.05)
        else
            StopStatusTicker()
            HideHoverButton()
            unlockPreviewList = nil
            if frame then frame:Hide() end
        end
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                EnsureGlowDB(db)
                local s = page:NewSection(ui.L("Party Keystone List"))
                s:CheckGrid({
                    {
                        label = ui.L("Enable Party Keystone List"),
                        getValue = function() return db.enabled end,
                        setValue = function(v) ns.SetModuleEnabled(KEY, v) end,
                        note = ui.L("Shows your own keystone immediately and exchanges party keystones through WA-KeyStGrList."),
                    },
                    {
                        label = ui.L("Lock Position"),
                        getValue = function() return db.keystoneListLocked end,
                        setValue = function(v) SetOption(db, "keystoneListLocked", v and true or false) end,
                        note = ui.L("Unlocking displays five local preview keystones for positioning."),
                        enabled = function() return EnabledRule(db, ui) end,
                    },
                    {
                        label = ui.L("Click Icon to Teleport"),
                        getValue = function() return db.keystoneListClickTeleport ~= false end,
                        setValue = function(v) SetOption(db, "keystoneListClickTeleport", v and true or false) end,
                        enabled = function() return EnabledRule(db, ui) end,
                    },
                    {
                        label = ui.L("Show When Solo"),
                        getValue = function() return db.keystoneListShowSolo == true end,
                        setValue = function(v) SetOption(db, "keystoneListShowSolo", v and true or false) end,
                        enabled = function() return EnabledRule(db, ui) end,
                    },
                    {
                        label = ui.L("Show In Party"),
                        getValue = function() return db.keystoneListShowInParty ~= false end,
                        setValue = function(v) SetOption(db, "keystoneListShowInParty", v and true or false) end,
                        enabled = function() return EnabledRule(db, ui) end,
                    },
                    {
                        label = ui.L("Show No Port"),
                        getValue = function() return db.keystoneListShowNoPort ~= false end,
                        setValue = function(v) SetOption(db, "keystoneListShowNoPort", v and true or false) end,
                        enabled = function() return EnabledRule(db, ui) end,
                    },
                    {
                        label = ui.L("Use Abbreviations"),
                        getValue = function() return db.keystoneListUseAbbreviation ~= false end,
                        setValue = function(v)
                            SetOption(db, "keystoneListUseAbbreviation", v and true or false)
                            RebuildDisplay()
                        end,
                        note = ui.L("Show short dungeon codes (VP, 诸王, 红玉...) instead of full dungeon names in the list."),
                        enabled = function() return EnabledRule(db, ui) end,
                    },
                }, { columns = 2 })
                s:ValueSlider(ui.L("Overall Scale"), 0.6, 1.8, 0.05, function()
                    return tonumber(db.keystoneListScale) or 1
                end, function(v)
                    SetOption(db, "keystoneListScale", tonumber(v) or 1)
                end, {
                    labelW = 120,
                    sliderW = 280,
                    decimals = 2,
                    enabled = function() return EnabledRule(db, ui) end,
                })
                page:AddSection(s)

                local glow = page:NewSection(ui.L("Target Glow"))
                glow:ColorGrid({
                    {
                        label = ui.L("Target Dungeon Glow Color"),
                        getColor = function() return db.queueGlowColor end,
                        setColor = function(color)
                            db.queueGlowColor = ns.GlowService:NormalizeColor(color, DEFAULT_QUEUE_GLOW_COLOR)
                            RefreshGlowSettings(db)
                        end,
                    },
                    {
                        label = ui.L("Teleport Cast Glow Color"),
                        getColor = function() return db.castGlowColor end,
                        setColor = function(color)
                            db.castGlowColor = ns.GlowService:NormalizeColor(color, DEFAULT_CAST_GLOW_COLOR)
                            RefreshGlowSettings(db)
                        end,
                    },
                }, {
                    columns = 1,
                    labelW = 188,
                    buttonW = 70,
                })
                glow:Dropdown(
                    ui.L("Glow Style"),
                    function() return db.glowStyle or "auto" end,
                    function(value)
                        db.glowStyle = ns.GlowService:NormalizeStyle(value)
                        RefreshGlowSettings(db)
                    end,
                    {
                        { text = ui.L("Auto (Restriction-Aware)"), value = "auto" },
                        { text = ui.L("Pixel Glow (Ants)"), value = "pixel" },
                        { text = ui.L("Proc Glow (FlipBook)"), value = "proc" },
                        { text = ui.L("Auto-Cast Shine"), value = "autocast" },
                        { text = ui.L("Action Button Glow"), value = "button" },
                    },
                    188,
                    190,
                    {
                        note = ui.L("Auto picks the pixel glow normally and falls back to the C-side FlipBook proc glow on 12.x clients, where Lua-ticked glows can freeze under restricted execution."),
                        enabled = function() return EnabledRule(db, ui) end,
                    }
                )
                glow:ValueSlider(
                    ui.L("Glow Speed"),
                    0.5,
                    3.0,
                    0.1,
                    function() return db.glowSpeed or 1 end,
                    function(value)
                        db.glowSpeed = ns.GlowService:NormalizeSpeed(value)
                        RefreshGlowSettings(db)
                    end,
                    {
                        labelW = 188,
                        sliderW = 284,
                        decimals = 1,
                    }
                )
                glow:ButtonRow({
                    {
                        text = ui.L("Reset Glow"),
                        width = 132,
                        onClick = function()
                            ResetGlowSettings(db)
                            ui.Refresh()
                        end,
                    },
                })
                page:AddSection(glow)

                local status = page:NewSection(ui.L("Status"))
                status:DynamicText(function()
                    local own = keystonesDB[GetPlayerFullName() or ""]
                    if not own then return ui.L("Owned Keystone") .. ": " .. ui.L("N/A") end
                    return ui.L("Owned Keystone") .. ": " .. GetDungeonName(own.challengeMapID, GetDB().keystoneListUseAbbreviation ~= false) .. " +" .. tostring(own.keystoneLevel)
                end, ui.Colors.warning, 28)
                status:ButtonRow({
                    { text = ui.L("Refresh"), width = 92, onClick = function()
                        StorePersonalKeystone()
                        SendOwnKeystone()
                        RequestPartyKeystones()
                        RebuildDisplay()
                        ui.Refresh()
                    end },
                })
                page:AddSection(status)
            end,
        },
    },
})

end)
