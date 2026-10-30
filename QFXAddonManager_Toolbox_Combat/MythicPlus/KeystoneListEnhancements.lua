local _, manager = ...
manager.ToolboxRuntime:AddFile("MythicPlus", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

-- Optional compatibility and presentation layer for the Party Keystone List.
-- This file intentionally contains an independent implementation. It only
-- consumes public library APIs and public Blizzard events; no reference-addon
-- code is embedded here.
local E = {}
ns.KeystoneListEnhancements = E

local KEYSTONE_GLOW_KEY = "QFX_KEYSTONE_TARGET"

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function safeField(tbl, key)
    if type(tbl) ~= "table" then return nil end
    local ok, value = pcall(function() return tbl[key] end)
    if ok then return value end
    return nil
end

local function safeNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    local ok, number = pcall(tonumber, value)
    if ok then return number end
    return nil
end

local function safeString(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if value == nil then return nil end
    local ok, text = pcall(function() return "" .. value end)
    if ok and type(text) == "string" then return text end
    return nil
end

local function readUnitFullName(context, unit)
    if context and type(context.GetUnitFullName) == "function" then
        return context.GetUnitFullName(unit)
    end
    if type(UnitFullName) ~= "function" then return nil end
    local name, realm = safeCall(UnitFullName, unit)
    name, realm = safeString(name), safeString(realm)
    if not name or name == "" then return nil end
    return name, realm
end

local function readBooleanCall(context, fn, ...)
    if context and type(context.ReadBooleanCall) == "function" then
        return context.ReadBooleanCall(fn, ...)
    end
    if type(fn) ~= "function" then return nil end
    local value = safeCall(fn, ...)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if value == nil then return nil end
    local ok, result = pcall(function() return value == true end)
    if not ok then return nil end
    return result == true
end

local function after(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, callback)
    else
        callback()
    end
end

local function cancelTimer(timer)
    if timer and timer.Cancel then pcall(timer.Cancel, timer) end
end

local function groupSize()
    if not GetNumGroupMembers then return 0 end
    return safeNumber(safeCall(GetNumGroupMembers)) or 0
end

local function groupChannel(context)
    if context and type(context.GetGroupChannel) == "function" then
        local channel = safeCall(context.GetGroupChannel)
        if channel == "PARTY" or channel == "INSTANCE_CHAT" then return channel end
        return nil
    end
    return IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) and "PARTY" or nil
end

local function isSmallGroup(context)
    return groupChannel(context) ~= nil
end

local function shortName(fullName)
    if not fullName then return "?" end
    if Ambiguate then
        local value = safeCall(Ambiguate, fullName, "short")
        if value then return value end
    end
    return tostring(fullName):match("^([^-]+)") or tostring(fullName)
end

function E:Initialize(context)
    self.ctx = context
    self.enabled = true
    self.syncSerial = (self.syncSerial or 0) + 1
    self.glowSettingsVersion = self.glowSettingsVersion or 0
    self:DiscoverLibraries()
    self:RegisterLibraryCallbacks()
    self:SchedulePartySync("enable")
end

function E:Disable()
    self.enabled = false
    self.syncSerial = (self.syncSerial or 0) + 1
    self.pendingLeaderHint = nil
    self.pendingLeaderGlowMapID = nil
    self.pendingApplicantActivityID = nil
    self.activeEntryActivityIDs = nil
    self:ClearQueueGlow()
    self:StopCastEffect()
    self:ClearRowEffects()
    if self.banner then
        self.banner.fade:Stop()
        self.banner:Hide()
    end
end

function E:IsReady()
    return self.enabled and self.ctx and self.ctx.IsEnabled and self.ctx.IsEnabled()
end

function E:L(key)
    return self.ctx and self.ctx.L and self.ctx.L(key) or key
end

function E:GetLibrary(name)
    local stub = _G.LibStub
    if stub then
        if type(stub.GetLibrary) == "function" then
            local lib = safeCall(stub.GetLibrary, stub, name, true)
            if lib then return lib end
        end
        local lib = safeCall(stub, name, true)
        if lib then return lib end
    end
    return _G[name]
end

function E:DiscoverLibraries()
    if not self.openRaid then
        self.openRaid = self:GetLibrary("LibOpenRaid-1.0")
    end
    if not self.libKeystone then
        self.libKeystone = self:GetLibrary("LibKeystone")
    end
end

function E:ResolvePartyFullName(rawName)
    if type(rawName) ~= "string" or rawName == "" then return nil end
    local targetShort = shortName(rawName)
    local targetFull = self.ctx.NormalizeFullName(rawName)
    local units = { "player", "party1", "party2", "party3", "party4" }
    local shortMatch
    local shortMatchCount = 0
    for _, unit in ipairs(units) do
        if UnitExists and UnitExists(unit) then
            local name, realm = readUnitFullName(self.ctx, unit)
            if name then
                local full = self.ctx.NormalizeFullName(name, realm)
                if full == rawName or full == targetFull then return full end
                if shortName(full) == targetShort then
                    shortMatch = full
                    shortMatchCount = shortMatchCount + 1
                end
            end
        end
    end
    if shortMatchCount == 1 then return shortMatch end
    return nil
end

function E:StoreExternal(rawName, mapID, level, source)
    if not self:IsReady() then return false end
    mapID, level = safeNumber(mapID), safeNumber(level)
    if not mapID or mapID <= 0 or not level or level <= 0 then return false end
    local owner = self:ResolvePartyFullName(rawName)
    if not owner or not self.ctx.IsPartyMember(owner) then return false end
    local changed = self.ctx.UpsertKeystone({
        challengeMapID = mapID,
        keystoneLevel = level,
        activityID = 0,
        groupID = 0,
        resilientFlag = 0,
        keystoneOwner = owner,
        owner = owner,
        class = self.ctx.GetClassForFullName(owner),
        updatedAt = GetTime and GetTime() or 0,
    }, source)
    if changed then
        self.ctx.ScheduleRefresh(0.05)
        self:TryShowLeaderKeystone()
    end
    return changed
end

function E:RegisterLibraryCallbacks()
    if self.openRaid and not self.openRaidRegistered and type(self.openRaid.RegisterCallback) == "function" then
        local handler = {}
        handler.OnKeystoneUpdate = function(playerName, info)
            if not E:IsReady() or type(playerName) ~= "string" or type(info) ~= "table" then return end
            E:StoreExternal(playerName, safeField(info, "challengeMapID"), safeField(info, "level"), "openraid")
        end
        if pcall(self.openRaid.RegisterCallback, handler, "KeystoneUpdate", "OnKeystoneUpdate") then
            self.openRaidHandler = handler
            self.openRaidRegistered = true
        end
    end

    if self.libKeystone and not self.libKeystoneRegistered and type(self.libKeystone.Register) == "function" then
        self.libKeystoneOwner = self.libKeystoneOwner or {}
        local callback = function(keyLevel, keyChallengeMapID, _, sender)
            if not E:IsReady() then return end
            E:StoreExternal(sender, keyChallengeMapID, keyLevel, "libkeystone")
        end
        if pcall(self.libKeystone.Register, self.libKeystoneOwner, callback) then
            self.libKeystoneRegistered = true
        end
    end
end

function E:LookupOpenRaidRoster()
    if not self.openRaid or type(self.openRaid.GetKeystoneInfo) ~= "function" then return end
    local _, playerRealm = readUnitFullName(self.ctx, "player")
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists and UnitExists(unit) then
            local name, realm = readUnitFullName(self.ctx, unit)
            realm = (realm and realm ~= "") and realm or playerRealm or (GetRealmName and GetRealmName())
            if name and realm then
                local lookup = realm == playerRealm and name or (name .. "-" .. realm)
                local info = safeCall(self.openRaid.GetKeystoneInfo, lookup)
                if type(info) == "table" then
                    self:StoreExternal(name .. "-" .. realm, safeField(info, "challengeMapID"), safeField(info, "level"), "openraid")
                end
            end
        end
    end
end

function E:RequestExternalData()
    self:DiscoverLibraries()
    self:RegisterLibraryCallbacks()
    local channel = groupChannel(self.ctx)
    if not channel then return end
    -- This OpenRaid entry point is explicitly PARTY-only. Do not let it emit
    -- invalid PARTY traffic while the player belongs only to an instance group.
    if channel == "PARTY" and self.openRaid and type(self.openRaid.RequestKeystoneDataFromParty) == "function" then
        safeCall(self.openRaid.RequestKeystoneDataFromParty)
    end
    if self.libKeystone and type(self.libKeystone.Request) == "function" then
        safeCall(self.libKeystone.Request, channel)
    end
    self:LookupOpenRaidRoster()
end

function E:RunSyncPass()
    if not self:IsReady() or not isSmallGroup(self.ctx) then return end
    self.ctx.SendOwnKeystone()
    self.ctx.RequestPartyKeystones()
    self:RequestExternalData()
    self:TryShowLeaderKeystone()
end

function E:SchedulePartySync(reason)
    if not self:IsReady() then return end
    self.syncSerial = (self.syncSerial or 0) + 1
    local serial = self.syncSerial
    local delays
    if reason == "joined" then
        delays = { 0.25, 1.5, 5.0 }
    elseif reason == "entering" or reason == "enable" then
        delays = { 0.05, 0.8, 3.0 }
    else
        delays = { 0.35, 2.5 }
    end
    for _, delay in ipairs(delays) do
        after(delay, function()
            if E.syncSerial ~= serial then return end
            E:RunSyncPass()
        end)
    end
end

function E:GetLeaderFullName()
    local units = { "player", "party1", "party2", "party3", "party4" }
    for _, unit in ipairs(units) do
        if UnitExists and UnitExists(unit) and readBooleanCall(self.ctx, UnitIsGroupLeader, unit) == true then
            local name, realm = readUnitFullName(self.ctx, unit)
            if name then return self.ctx.NormalizeFullName(name, realm) end
        end
    end
    return nil
end

function E:ArmLeaderHint()
    if not isSmallGroup(self.ctx) then return end
    self.pendingLeaderHint = true
    self.leaderHintSerial = (self.leaderHintSerial or 0) + 1
    local serial = self.leaderHintSerial
    after(12, function()
        if E.leaderHintSerial == serial then E.pendingLeaderHint = nil end
    end)
    self:TryShowLeaderKeystone()
end

function E:TryShowLeaderKeystone()
    if not self:IsReady() or not self.pendingLeaderHint then return end
    local leader = self:GetLeaderFullName()
    if not leader then return end
    local player = self.ctx.GetPlayerFullName()
    local key
    local showBanner = leader ~= player
    if leader == player then
        self.pendingLeaderHint = nil
        -- 自己就是队长：直接读自己的钥匙触发特效（不发横幅）。
        key = self.ctx.GetKeystone(player)
    else
        key = self.ctx.GetKeystone(leader)
    end
    if not key or not key.challengeMapID or not key.keystoneLevel then return end
    self.pendingLeaderHint = nil
    if showBanner then
        local db = self.ctx.GetDB and self.ctx.GetDB() or {}
        local dungeon = self.ctx.GetDungeonName(key.challengeMapID, db.keystoneListUseAbbreviation ~= false)
        self:ShowBanner({
            title = self:L("Group Leader Keystone"),
            line1 = self:L("Leader") .. ": " .. shortName(leader),
            line2 = tostring(dungeon or "?") .. "  +" .. tostring(key.keystoneLevel),
        })
    end
    -- 队长的钥匙决定了目标副本：事件驱动触发目标副本发光。
    self:ActivateLeaderGlow(key.challengeMapID)
end

function E:EnsureBanner()
    if self.banner then return self.banner end
    local f = CreateFrame("Frame", "QFXToolBoxKeystoneJoinBanner", UIParent)
    f:SetSize(460, 92)
    f:SetPoint("TOP", UIParent, "TOP", 0, -170)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.025, 0.025, 0.035, 0.92)
    f.top = f:CreateTexture(nil, "BORDER")
    f.top:SetPoint("TOPLEFT", 0, 0); f.top:SetPoint("TOPRIGHT", 0, 0); f.top:SetHeight(2)
    f.top:SetColorTexture(1, 0.82, 0, 1)
    f.bottom = f:CreateTexture(nil, "BORDER")
    f.bottom:SetPoint("BOTTOMLEFT", 0, 0); f.bottom:SetPoint("BOTTOMRIGHT", 0, 0); f.bottom:SetHeight(1)
    f.bottom:SetColorTexture(0.35, 0.35, 0.4, 0.8)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetWidth(430)
    f.title:SetJustifyH("CENTER")
    f.title:SetTextColor(1, 0.82, 0)
    f.line1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.line1:SetPoint("TOP", f.title, "BOTTOM", 0, -7)
    f.line1:SetWidth(430)
    f.line1:SetJustifyH("CENTER")
    f.line2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.line2:SetPoint("TOP", f.line1, "BOTTOM", 0, -5)
    f.line2:SetWidth(430)
    f.line2:SetJustifyH("CENTER")
    f.line2:SetTextColor(0.75, 0.82, 0.9)

    f.fade = f:CreateAnimationGroup()
    local hold = f.fade:CreateAnimation("Alpha")
    hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(5)
    hold:SetOrder(1)
    local out = f.fade:CreateAnimation("Alpha")
    out:SetFromAlpha(1); out:SetToAlpha(0); out:SetDuration(0.6)
    out:SetOrder(2)
    f.fade:SetScript("OnFinished", function() f:Hide() end)
    f:Hide()
    self.banner = f
    return f
end

function E:ShowBanner(info)
    if not info then return end
    local f = self:EnsureBanner()
    f.fade:Stop()
    f:SetAlpha(1)
    f.title:SetText(info.title or self:L("Joined Group"))
    f.line1:SetText(info.line1 or "")
    f.line2:SetText(info.line2 or "")
    f.line1:SetShown(info.line1 and info.line1 ~= "")
    f.line2:SetShown(info.line2 and info.line2 ~= "")
    f:Show()
    f.fade:Play()
end

function E:ActivityIDsFromInfo(info)
    local ids = safeField(info, "activityIDs")
    if type(ids) == "table" and ids[1] then return ids end
    local id = safeField(info, "activityID")
    if id then return { id } end
    return nil
end

function E:BuildDungeonNameLookup()
    local lookup = {}
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then return lookup end
    local maps = safeCall(C_ChallengeMode.GetMapTable)
    if type(maps) ~= "table" then return lookup end
    for _, mapID in ipairs(maps) do
        local name = safeCall(C_ChallengeMode.GetMapUIInfo, mapID)
        if type(name) == "string" and name ~= "" then lookup[name] = mapID end
    end
    return lookup
end

function E:ActivityToMapID(activityID)
    activityID = safeNumber(activityID)
    if not activityID or not C_LFGList then return nil end
    local info = C_LFGList.GetActivityInfoTable and safeCall(C_LFGList.GetActivityInfoTable, activityID)
    local direct = safeField(info, "challengeMapID") or safeField(info, "mapID")
    direct = safeNumber(direct)
    if direct and direct > 0 then return direct end
    local fullName = safeString(safeField(info, "fullName"))
    local short = safeString(safeField(info, "shortName"))
    if not fullName and C_LFGList.GetActivityFullName then
        fullName = safeString(safeCall(C_LFGList.GetActivityFullName, activityID))
    end
    if type(fullName) ~= "string" and type(short) ~= "string" then return nil end
    self.dungeonNameLookup = self.dungeonNameLookup or self:BuildDungeonNameLookup()
    if short and self.dungeonNameLookup[short] then return self.dungeonNameLookup[short] end
    if fullName and self.dungeonNameLookup[fullName] then return self.dungeonNameLookup[fullName] end
    if fullName then
        for dungeonName, mapID in pairs(self.dungeonNameLookup) do
            if fullName:find(dungeonName, 1, true) then return mapID end
        end
    end
    return nil
end

function E:EnsureRowGlow(row)
    if not row.qfxCastShade then
        row.qfxCastShade = row.iconBox:CreateTexture(nil, "OVERLAY")
        row.qfxCastShade:SetAllPoints(row.iconBox)
        row.qfxCastShade:SetColorTexture(0.25, 0.72, 1, 0.28)
        row.qfxCastShade:SetBlendMode("ADD")
        row.qfxCastShade:Hide()
    end
    return row.iconBox
end

function E:SetRowEffect(row, queueOn, castOn)
    if not row or not row.iconBox then return end
    self:EnsureRowGlow(row)

    local desiredState
    if castOn then
        desiredState = "cast"
    elseif queueOn then
        desiredState = "queue"
    end

    local settingsVersion = self.glowSettingsVersion or 0
    if row.qfxGlowState == desiredState
        and row.qfxGlowSettingsVersion == settingsVersion
    then
        return
    end

    local db = self.ctx and self.ctx.GetDB and self.ctx.GetDB()
    if not db then return end

    if desiredState == "cast" then
        ns.GlowService:RestartPixelGlow(row.iconBox, KEYSTONE_GLOW_KEY, {
            color = db.castGlowColor,
            speed = db.glowSpeed,
            style = db.glowStyle,
            lines = 8,
            thickness = 3,
            border = true,
            frameLevel = row.iconBox:GetFrameLevel() + 4,
        })
        row.qfxCastShade:Show()
    elseif desiredState == "queue" then
        ns.GlowService:RestartPixelGlow(row.iconBox, KEYSTONE_GLOW_KEY, {
            color = db.queueGlowColor,
            speed = db.glowSpeed,
            style = db.glowStyle,
            lines = 8,
            thickness = 3,
            border = true,
            frameLevel = row.iconBox:GetFrameLevel() + 4,
        })
        row.qfxCastShade:Hide()
    else
        ns.GlowService:StopPixelGlow(row.iconBox, KEYSTONE_GLOW_KEY)
        row.qfxCastShade:Hide()
    end

    row.qfxGlowState = desiredState
    row.qfxGlowSettingsVersion = settingsVersion
end

function E:RefreshGlowSettings()
    self.glowSettingsVersion = (self.glowSettingsVersion or 0) + 1
    self:SyncRows()
end

function E:ApplyRowEffects(row, data)
    if not row then return end
    row.qfxMapID = data and safeNumber(data.challengeMapID) or nil
    self:SyncRows()
end

function E:SyncRows()
    if not self.ctx or not self.ctx.GetRows then return end
    local desiredMapID = self.castMapID or self.glowMapID
    local desiredState = self.castMapID and "cast" or (self.glowMapID and "queue" or nil)
    local effectAssigned = false
    for _, row in ipairs(self.ctx.GetRows()) do
        if row and row:IsShown() and row.data then
            row.qfxMapID = safeNumber(row.data.challengeMapID)
            local useEffect = not effectAssigned
                and desiredMapID
                and row.qfxMapID == desiredMapID
            if useEffect then effectAssigned = true end
            self:SetRowEffect(
                row,
                useEffect and desiredState == "queue",
                useEffect and desiredState == "cast"
            )
        elseif row then
            self:SetRowEffect(row, false, false)
        end
    end
end

function E:ClearRowEffects()
    if not self.ctx or not self.ctx.GetRows then return end
    for _, row in ipairs(self.ctx.GetRows()) do
        self:SetRowEffect(row, false, false)
    end
end

function E:ClearQueueGlow()
    self.glowMapID = nil
    self.pendingLeaderGlowMapID = nil
    cancelTimer(self.glowClearTimer)
    self.glowClearTimer = nil
    self.pendingApplicantActivityID = nil
    cancelTimer(self.pendingApplicantTimer)
    self.pendingApplicantTimer = nil
    self:SyncRows()
end

-- 战斗中不检测：把队长的钥匙特效延后到脱战（PLAYER_REGEN_ENABLED）再触发。
function E:ActivateLeaderGlow(mapID)
    mapID = safeNumber(mapID)
    if not mapID then return end
    if safeCall(InCombatLockdown) then
        self.pendingLeaderGlowMapID = mapID
        return
    end
    self.pendingLeaderGlowMapID = nil
    self:GlowMap(mapID)
end

function E:GlowMap(mapID)
    mapID = safeNumber(mapID)
    if not mapID then return end
    self.glowMapID = mapID
    self:SyncRows()
    cancelTimer(self.glowClearTimer)
    if C_Timer and C_Timer.NewTimer then
        self.glowClearTimer = C_Timer.NewTimer(30, function() E:ClearQueueGlow() end)
    else
        after(30, function() if E.glowMapID == mapID then E:ClearQueueGlow() end end)
    end
end

function E:TryApplicantGlow()
    if not self.pendingApplicantActivityID or groupSize() < 5 then return end
    local activityID = self.pendingApplicantActivityID
    self.pendingApplicantActivityID = nil
    cancelTimer(self.pendingApplicantTimer)
    self.pendingApplicantTimer = nil
    after(2, function()
        if not E:IsReady() then return end
        local mapID = E:ActivityToMapID(activityID)
        if mapID then E:GlowMap(mapID) end
    end)
end

function E:HandleLFGApplication(searchResultID, newStatus)
    if newStatus ~= "inviteaccepted" or not (searchResultID and C_LFGList and C_LFGList.GetSearchResultInfo) then return end
    local result = safeCall(C_LFGList.GetSearchResultInfo, searchResultID)
    if type(result) ~= "table" then return end
    local ids = self:ActivityIDsFromInfo(result)
    local activityID = ids and ids[1]
    if activityID then
        self.pendingApplicantActivityID = activityID
        cancelTimer(self.pendingApplicantTimer)
        if C_Timer and C_Timer.NewTimer then
            self.pendingApplicantTimer = C_Timer.NewTimer(300, function() E.pendingApplicantActivityID = nil end)
        end
        after(0, function() E:TryApplicantGlow() end)
    end

    local activityInfo = activityID and C_LFGList.GetActivityInfoTable and safeCall(C_LFGList.GetActivityInfoTable, activityID)
    local title = safeString(safeField(result, "name"))
    local leader = safeString(safeField(result, "leaderName"))
    local comment = safeString(safeField(result, "comment"))
    local dungeon = safeString(safeField(activityInfo, "fullName")) or safeString(safeField(activityInfo, "shortName"))
    if type(title) == "string" or type(dungeon) == "string" then
        local line1 = dungeon or title
        if title and dungeon and title ~= dungeon then line1 = title .. "  ·  " .. dungeon end
        local line2 = leader and (self:L("Leader") .. ": " .. tostring(leader)) or ""
        if type(comment) == "string" and comment ~= "" then
            line2 = line2 ~= "" and (line2 .. "  ·  " .. comment) or comment
        end
        self:ShowBanner({ title = self:L("Joined Group"), line1 = line1, line2 = line2 })
    end
    self:ArmLeaderHint()
end

function E:HandleLFGActiveEntry(created)
    if not (C_LFGList and C_LFGList.GetActiveEntryInfo) then return end
    if created then
        local info = safeCall(C_LFGList.GetActiveEntryInfo)
        self.activeEntryActivityIDs = self:ActivityIDsFromInfo(info)
        return
    end
    local ids = self.activeEntryActivityIDs
    self.activeEntryActivityIDs = nil
    if not ids or groupSize() < 5 then return end
    after(2, function()
        if not E:IsReady() then return end
        for _, activityID in ipairs(ids) do
            local mapID = E:ActivityToMapID(activityID)
            if mapID then E:GlowMap(mapID); break end
        end
    end)
end

function E:FindMapForTeleportSpell(spellID)
    if not spellID or not self.ctx or not self.ctx.GetRows then return nil end
    for _, row in ipairs(self.ctx.GetRows()) do
        local data = row and row.data
        if data and data.challengeMapID then
            local portID = self.ctx.SelectTeleportSpell(data.challengeMapID)
            if portID then
                local ok, same = pcall(function() return spellID == portID end)
                if ok and same then return safeNumber(data.challengeMapID) end
            end
        end
    end
    return nil
end

function E:StartCastEffect(spellID)
    local mapID = self:FindMapForTeleportSpell(spellID)
    if not mapID then return end
    self.castMapID = mapID
    self:SyncRows()
end

function E:StopCastEffect()
    if not self.castMapID then return end
    self.castMapID = nil
    self:SyncRows()
end

function E:HandleSpellSucceeded(spellID)
    local castMap = self:FindMapForTeleportSpell(spellID)
    self:StopCastEffect()
    if castMap and self.glowMapID == castMap then self:ClearQueueGlow() end
end

function E:OnKeystoneUpdated()
    self:TryShowLeaderKeystone()
end

function E:OnEvent(event, ...)
    if not self:IsReady() then return end
    if event == "ADDON_LOADED" then
        self:DiscoverLibraries()
        self:RegisterLibraryCallbacks()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:DiscoverLibraries()
        self:RegisterLibraryCallbacks()
        self:SchedulePartySync("entering")
        local inInstance, instanceType = safeCall(IsInInstance)
        if inInstance and instanceType == "party" then self:ClearQueueGlow() end
    elseif event == "GROUP_JOINED" then
        self:ArmLeaderHint()
        self:SchedulePartySync("joined")
    elseif event == "GROUP_LEFT" then
        self.pendingLeaderHint = nil
        self:ClearQueueGlow()
        self:StopCastEffect()
    elseif event == "GROUP_ROSTER_UPDATE" then
        self:SchedulePartySync("roster")
        self:TryApplicantGlow()
        self:TryShowLeaderKeystone()
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        self:HandleLFGApplication(...)
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        self:HandleLFGActiveEntry(...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 脱战：补跑战斗期间延后的队长钥匙特效检测。
        if self.pendingLeaderGlowMapID and isSmallGroup(self.ctx) then
            local mapID = self.pendingLeaderGlowMapID
            self.pendingLeaderGlowMapID = nil
            self:GlowMap(mapID)
        else
            self.pendingLeaderGlowMapID = nil
        end
    elseif event == "CHALLENGE_MODE_START" then
        self:ClearQueueGlow()
        self:StopCastEffect()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local inInstance, instanceType = safeCall(IsInInstance)
        if inInstance and instanceType == "party" then self:ClearQueueGlow() end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, _, spellID = ...
        unit, spellID = safeString(unit), safeNumber(spellID)
        if unit == "player" and spellID then self:StartCastEffect(spellID) end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
    then
        local unit = safeString(...)
        if unit == "player" then self:StopCastEffect() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        unit, spellID = safeString(unit), safeNumber(spellID)
        if unit == "player" and spellID then self:HandleSpellSucceeded(spellID) end
    end
end

end)
