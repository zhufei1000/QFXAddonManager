local _, manager = ...
manager.ToolboxRuntime:AddFile("ChatBar", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

ns.WhisperHistory = ns.WhisperHistory or {}
local M = ns.WhisperHistory

M.KEY = "whisper_history"
M.ICON_PATH = "Interface\\AddOns\\QFXAddonManager\\Toolbox\\Core\\Media\\WhisperHistory\\whisper_unread.tga"
M.DEFAULT_MAX_MESSAGES = 300
M.DEFAULT_SOUND_KEY = "QFX iPhone"
M.BLIZZARD_SOUND_KEY = "__QFX_BLIZZARD_WHISPER__"
M.EVENTS = {
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
}

local function L(key)
    return ns.L and ns.L("WHISPER_HISTORY_" .. key) or key
end
M.L = L

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end
M.Clamp = Clamp

local function SafeIsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
end
M.SafeIsSecret = SafeIsSecret

local SafeString = ns.Compat.SafeNonEmptyString

local SafeNumber = ns.Compat.SafeNumber
local IS_FOREVER = ns.Compat.IsForever()

local function CopyPosition(value, fallback)
    value = type(value) == "table" and value or {}
    fallback = fallback or {}
    return {
        point = SafeString(value.point) or fallback.point or "CENTER",
        relativePoint = SafeString(value.relativePoint) or fallback.relativePoint or fallback.point or "CENTER",
        x = tonumber(value.x) or fallback.x or 0,
        y = tonumber(value.y) or fallback.y or 0,
        width = tonumber(value.width) or fallback.width,
        height = tonumber(value.height) or fallback.height,
    }
end

local function NormalizeColorMode(value)
    if value == "CLASS" then value = "SOURCE" end
    if value == "CUSTOM" then value = "ORIGINAL" end
    if value ~= "PLAYER" and value ~= "ORIGINAL" then value = "SOURCE" end
    return value
end

local function RemoveRealmSpaces(realm)
    realm = SafeString(realm)
    if not realm then return nil end
    realm = realm:gsub("%s+", "")
    return realm ~= "" and realm or nil
end

function M.NormalizeName(name)
    name = SafeString(name)
    if not name then return nil end
    if name:find("-", 1, true) then return name end

    local realm
    if type(GetNormalizedRealmName) == "function" then
        local ok, result = pcall(GetNormalizedRealmName)
        if ok then realm = RemoveRealmSpaces(result) end
    end
    if not realm and type(GetRealmName) == "function" then
        local ok, result = pcall(GetRealmName)
        if ok then realm = RemoveRealmSpaces(result) end
    end
    return realm and (name .. "-" .. realm) or name
end

local function StripRealm(name)
    name = SafeString(name)
    if not name then return nil end
    return name:match("^([^%-]+)") or name
end

local function SameLooseValue(a, b)
    if a == nil or b == nil or SafeIsSecret(a) or SafeIsSecret(b) then return false end
    return tostring(a) == tostring(b)
end

function M.IsDungeonOrRaidInstance()
    if type(IsInInstance) ~= "function" then return false end
    local ok, inInstance, instanceType = pcall(IsInInstance)
    return ok and inInstance and (instanceType == "party" or instanceType == "raid") or false
end

function M.EnsureConfig(db)
    if type(db) ~= "table" then return end
    M.db = db
    if db.persistHistory == nil then
        local saved = QFXAddonManagerToolboxDB and QFXAddonManagerToolboxDB.globalData and QFXAddonManagerToolboxDB.globalData.whisperHistory
        -- Preserve previously saved histories; new users keep a session history.
        db.persistHistory = type(saved) == "table"
    end
    db.enabled = db.enabled == true
    db.lockButton = db.lockButton ~= false
    db.lockWindow = db.lockWindow ~= false
    db.allowInCombatOpen = db.allowInCombatOpen ~= false
    db.buttonDisplayMode = db.buttonDisplayMode == "ALWAYS" and "ALWAYS" or "UNREAD"
    db.buttonScale = Clamp(db.buttonScale, 0.65, 1.80, 1)
    db.buttonAlpha = Clamp(db.buttonAlpha, 0.20, 1, 1)
    db.buttonColorMode = NormalizeColorMode(db.buttonColorMode)
    db.windowColorMode = NormalizeColorMode(db.windowColorMode)
    db.windowDetached = db.windowDetached == true
    db.autoCloseOnLeave = db.autoCloseOnLeave ~= false
    db.autoCloseSeconds = Clamp(db.autoCloseSeconds, 1, 300, 10)
    db.windowBackgroundAlpha = Clamp(db.windowBackgroundAlpha, 0.02, 0.60, 0.13)
    db.readBrightness = Clamp(db.readBrightness, 0.20, 0.95, 0.55)
    db.messageFontSize = math.floor(Clamp(db.messageFontSize, 10, 24, 12) + 0.5)
    db.maxMessages = math.floor(Clamp(db.maxMessages, 50, 2000, M.DEFAULT_MAX_MESSAGES) + 0.5)
    db.soundEnabled = db.soundEnabled ~= false
    db.soundName = SafeString(db.soundName) or M.DEFAULT_SOUND_KEY
    if db.soundName == "__QFX_DEFAULT_WHISPER__" then db.soundName = M.DEFAULT_SOUND_KEY end
    db.button = CopyPosition(db.button, { point = "CENTER", relativePoint = "CENTER", x = 360, y = 0 })
    db.window = CopyPosition(db.window, { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 620, height = 430 })
    db.window.width = Clamp(db.window.width, 420, 1100, 620)
    db.window.height = Clamp(db.window.height, 260, 820, 430)
    db.applyFilters = nil
    db.buttonCustomColor = nil
    db.showOnlyWithMessages = nil
    db.showOnlyWithUnread = nil
end

function M.GetConfig()
    if type(M.db) == "table" then return M.db end
    M.db = ns.GetModuleDB and ns.GetModuleDB(M.KEY) or nil
    return M.db
end

function M.GetSharedMedia()
    if ns.Compat and ns.Compat.GetSharedMedia then return ns.Compat.GetSharedMedia() end
    local libStub = _G.LibStub
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
        local ok, library = pcall(libStub.GetLibrary, libStub, "LibSharedMedia-3.0", true)
        if ok and type(library) == "table" then return library end
    elseif type(libStub) == "function" then
        local ok, library = pcall(libStub, "LibSharedMedia-3.0", true)
        if ok and type(library) == "table" then return library end
    end
    return nil
end

function M.GetSharedMediaSoundNames()
    local media = M.GetSharedMedia()
    if not media or type(media.List) ~= "function" then return {} end
    local ok, list = pcall(media.List, media, "sound")
    if not ok or type(list) ~= "table" then return {} end

    local names, seen = {}, {}
    for _, name in ipairs(list) do
        if type(name) == "string" and name ~= "" and name ~= "None" and not seen[name] then
            names[#names + 1] = name
            seen[name] = true
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local function TryPlaySharedMediaSound(soundName)
    if soundName == M.BLIZZARD_SOUND_KEY then return false end
    local media = M.GetSharedMedia()
    if not media or type(media.Fetch) ~= "function" or type(PlaySoundFile) ~= "function" then return false end
    local ok, soundFile = pcall(media.Fetch, media, "sound", soundName, true)
    if not ok or (type(soundFile) ~= "string" and type(soundFile) ~= "number") then return false end
    local played, willPlay = pcall(PlaySoundFile, soundFile, "Master")
    return played and willPlay ~= false
end

local function TryPlayDefaultWhisperSound()
    local soundKit = type(SOUNDKIT) == "table" and SOUNDKIT.TELL_MESSAGE or nil
    if soundKit == nil or type(PlaySound) ~= "function" then return false end
    local played, willPlay = pcall(PlaySound, soundKit, "Master")
    return played and willPlay ~= false
end

function M.PlayWhisperAlert(force)
    local db = M.GetConfig()
    if not db or (not force and db.soundEnabled == false) then return false end
    local soundName = SafeString(db.soundName) or M.DEFAULT_SOUND_KEY
    if TryPlaySharedMediaSound(soundName) then return true end
    return TryPlayDefaultWhisperSound()
end

function M.GetData()
    if M.data then return M.data end
    QFXAddonManagerToolboxDB = type(QFXAddonManagerToolboxDB) == "table" and QFXAddonManagerToolboxDB or {}
    QFXAddonManagerToolboxDB.globalData = type(QFXAddonManagerToolboxDB.globalData) == "table" and QFXAddonManagerToolboxDB.globalData or {}
    local saved = QFXAddonManagerToolboxDB.globalData.whisperHistory
    local data = type(saved) == "table" and saved or {}
    data.messages = type(data.messages) == "table" and data.messages or {}
    data.nextID, data.unreadCount, data.sourceMessageID = 0, 0, 0
    -- Detach the live record/counters from SavedVariables. A snapshot is
    -- attached once at PLAYER_LOGOUT, even if the module was disabled meanwhile.
    QFXAddonManagerToolboxDB.globalData.whisperHistory = nil
    M.data = data
    if ns.RegisterEvent then ns.RegisterEvent("PLAYER_LOGOUT", M, M.SaveHistory) end
    return data
end

function M.SaveHistory()
    if not M.data or not QFXAddonManagerToolboxDB or not QFXAddonManagerToolboxDB.globalData then return end
    local db = M.GetConfig()
    if db and db.persistHistory then
        M.TrimMessages(db.maxMessages)
        QFXAddonManagerToolboxDB.globalData.whisperHistory = { messages = M.data.messages }
    else
        QFXAddonManagerToolboxDB.globalData.whisperHistory = nil
    end
end

local function ValidateMessage(raw)
    if type(raw) ~= "table" then return nil end
    local text = SafeString(raw.text)
    if not text then return nil end

    local isBN = raw.isBN == true
    local name = SafeString(raw.name) or L("UNKNOWN")
    local message = {
        id = math.max(0, math.floor(SafeNumber(raw.id, 0))),
        time = SafeNumber(raw.time, time()),
        name = name,
        replyName = SafeString(raw.replyName),
        class = SafeString(raw.class),
        text = text,
        read = raw.read == true,
        isBN = isBN,
    }
    if isBN then
        local bnID = raw.bnID or raw.presenceID or raw.replyID
        if not SafeIsSecret(bnID) and (type(bnID) == "number" or type(bnID) == "string") then
            message.bnID = bnID
            message.presenceID = bnID
        end
        message.bnTag = SafeString(raw.bnTag)
        message.bnAccountName = SafeString(raw.bnAccountName)
    else
        local target = message.replyName or name
        message.replyName = IS_FOREVER and target or M.NormalizeName(target) or target
    end
    return message
end

local function SortMessages(messages)
    table.sort(messages, function(a, b)
        local aTime, bTime = tonumber(a.time) or 0, tonumber(b.time) or 0
        if aTime == bTime then return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end
        return aTime < bTime
    end)
end

function M.RefreshSourceClass()
    local data = M.GetData()
    data.sourceClass = nil
    data.sourceMessageID = 0
    for index = #data.messages, 1, -1 do
        local message = data.messages[index]
        if message and not message.read and message.class then
            data.sourceClass = message.class
            data.sourceMessageID = tonumber(message.id) or 0
            return message.class
        end
    end
    for index = #data.messages, 1, -1 do
        local message = data.messages[index]
        if message and message.class then
            data.sourceClass = message.class
            data.sourceMessageID = tonumber(message.id) or 0
            return message.class
        end
    end
end

function M.RecountUnread()
    local data = M.GetData()
    local unread, maxID = 0, 0
    local clean = {}
    for _, raw in ipairs(data.messages) do
        local message = ValidateMessage(raw)
        if message then
            clean[#clean + 1] = message
            if not message.read then unread = unread + 1 end
            if message.id > maxID then maxID = message.id end
        end
    end
    SortMessages(clean)
    data.messages = clean
    data.unreadCount = unread
    data.nextID = math.max(data.nextID or 0, maxID)
    M.RefreshSourceClass()
    return unread
end

function M.TrimMessages(maxMessages)
    local data = M.GetData()
    maxMessages = math.floor(Clamp(maxMessages, 50, 2000, M.DEFAULT_MAX_MESSAGES))
    local removedAny, sourceRemoved = false, false
    while #data.messages > maxMessages do
        local removed = table.remove(data.messages, 1)
        removedAny = true
        if removed and not removed.read then
            data.unreadCount = math.max(0, (data.unreadCount or 0) - 1)
        end
        if removed and tonumber(removed.id) == tonumber(data.sourceMessageID) then sourceRemoved = true end
    end
    if sourceRemoved then M.RefreshSourceClass() end
    return removedAny
end

function M.GetUnreadCount()
    return (M.GetData().unreadCount or 0)
end

function M.GetMessageCount()
    return #M.GetData().messages
end

function M.NotifyDataChanged(refreshWindow)
    if not M.UI then return end
    local windowShown = M.UI.IsWindowShown and M.UI.IsWindowShown()
    if refreshWindow and windowShown and M.UI.RefreshWindow then
        if M.UI.UpdateFloatButton then M.UI.UpdateFloatButton() end
        M.UI.RefreshWindow(true)
    elseif M.UI.RefreshIndicators then
        M.UI.RefreshIndicators()
    end
end

function M.MarkMessageRead(message)
    if type(message) ~= "table" or message.read then return false end
    message.read = true
    local data = M.GetData()
    data.unreadCount = math.max(0, (data.unreadCount or 0) - 1)
    if tonumber(message.id) == tonumber(data.sourceMessageID) then M.RefreshSourceClass() end
    M.NotifyDataChanged(false)
    return true
end

function M.MarkAllRead(silent)
    local data, changed = M.GetData(), false
    for _, message in ipairs(data.messages) do
        if not message.read then
            message.read = true
            changed = true
        end
    end
    data.unreadCount = 0
    if changed then
        M.RefreshSourceClass()
        M.NotifyDataChanged(true)
    end
    if changed and not silent and ns.Print then ns.Print(L("MARK_ALL_READ_DONE")) end
    return changed
end

function M.ClearHistory(silent)
    local data = M.GetData()
    wipe(data.messages)
    data.unreadCount = 0
    data.nextID = 0
    data.sourceClass = nil
    data.sourceMessageID = 0
    M.NotifyDataChanged(true)
    if not silent and ns.Print then ns.Print(L("CLEARED")) end
end

local function IsBattleTag(value)
    return SafeString(value) and value:match("^.+#%d+$") ~= nil
end

local function StripBNPrefix(value)
    value = SafeString(value)
    return value and (value:match("^[^:]+:(.+)$") or value) or nil
end

local function ExtractBNAccountInfo(accountInfo)
    if type(accountInfo) ~= "table" then return nil end
    local game = accountInfo.gameAccountInfo
    local online = accountInfo.isOnline
    if online == nil and type(game) == "table" then online = game.isOnline end
    return accountInfo.bnetAccountID or accountInfo.accountID or accountInfo.presenceID,
        SafeString(accountInfo.accountName or accountInfo.name), SafeString(accountInfo.battleTag), online
end

function M.GetBNAccountInfoByID(id)
    if id == nil or SafeIsSecret(id) then return nil end
    if type(BNGetFriendInfoByID) == "function" then
        local ok, accountID, accountName, battleTag, _, _, _, _, online = pcall(BNGetFriendInfoByID, id)
        if ok and (accountID or SafeString(accountName) or SafeString(battleTag)) then
            return accountID or id, SafeString(accountName), SafeString(battleTag), online
        end
    end
    if C_BattleNet and type(C_BattleNet.GetAccountInfoByID) == "function" then
        local ok, info = pcall(C_BattleNet.GetAccountInfoByID, id)
        if ok then
            local accountID, accountName, battleTag, online = ExtractBNAccountInfo(info)
            if accountID or accountName or battleTag then return accountID or id, accountName, battleTag, online end
        end
    end
    return id
end

function M.GetBNInfoFromTag(tag)
    if not IsBattleTag(tag) then return nil end
    if type(BNGetNumFriends) == "function" and type(BNGetFriendInfo) == "function" then
        local okCount, count = pcall(BNGetNumFriends)
        if okCount and type(count) == "number" then
            for index = 1, count do
                local ok, accountID, accountName, battleTag, _, _, _, _, online = pcall(BNGetFriendInfo, index)
                if ok and battleTag == tag then return accountID, SafeString(accountName), online, index end
            end
        end
    end
    if C_BattleNet and type(C_BattleNet.GetNumFriends) == "function" and type(C_BattleNet.GetFriendAccountInfo) == "function" then
        local okCount, count = pcall(C_BattleNet.GetNumFriends)
        if okCount and type(count) == "number" then
            for index = 1, count do
                local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, index)
                if ok then
                    local accountID, accountName, battleTag, online = ExtractBNAccountInfo(info)
                    if battleTag == tag then return accountID, accountName, online, index end
                end
            end
        end
    end
end

local function SendBNetTell(target)
    local send = ChatFrame_SendBNetTell or (ChatFrameUtil and ChatFrameUtil.SendBNetTell)
    target = SafeString(target)
    return type(send) == "function" and target and pcall(send, target) or false
end

function M.ReplyToMessage(message)
    if type(message) ~= "table" then return false end
    if message.isBN then
        local rawReply = StripBNPrefix(message.replyName or message.name)
        local rawName = StripBNPrefix(message.name)
        local tag = IsBattleTag(message.bnTag) and message.bnTag or (IsBattleTag(rawReply) and rawReply or (IsBattleTag(rawName) and rawName or nil))
        if tag then
            local _, accountName = M.GetBNInfoFromTag(tag)
            if SendBNetTell(accountName) then return true end
        end
        local accountID = message.bnID or message.presenceID
        if accountID ~= nil then
            local _, accountName, battleTag = M.GetBNAccountInfoByID(accountID)
            if IsBattleTag(battleTag) then
                local _, refreshed = M.GetBNInfoFromTag(battleTag)
                if SendBNetTell(refreshed) then return true end
            end
            if SendBNetTell(accountName) then return true end
        end
        if SendBNetTell(message.bnAccountName) or (rawReply and not IsBattleTag(rawReply) and SendBNetTell(rawReply)) then return true end
        if ns.Print then ns.Print(L("BNET_REPLY_UNAVAILABLE")) end
        return false
    end

    local target = SafeString(message.replyName or message.name)
    if not target then return false end
    if IS_FOREVER and ChatFrameUtil and ChatFrameUtil.ChooseBoxForSend and ChatFrameUtil.ActivateChat then
        local editBox = ChatFrameUtil.ChooseBoxForSend(SELECTED_DOCK_FRAME)
        if editBox and not editBox.disableActivate then
            -- A Forever name can contain spaces. Use the native reply target directly.
            editBox:SetChatType("WHISPER")
            editBox:SetTellTarget(target)
            editBox:SetText("")
            ChatFrameUtil.ActivateChat(editBox)
            return true
        end
    end
    if type(ChatFrame_SendTell) == "function" then
        return pcall(ChatFrame_SendTell, target, SELECTED_DOCK_FRAME)
    end
    local editBox = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    if editBox and type(ChatEdit_ActivateChat) == "function" then
        editBox:SetAttribute("chatType", "WHISPER")
        editBox:SetAttribute("tellTarget", target)
        ChatEdit_ActivateChat(editBox)
        return true
    end
    return false
end

local function MarkMatchingUnread(predicate)
    local data, changed = M.GetData(), 0
    for _, message in ipairs(data.messages) do
        if not message.read and predicate(message) then
            message.read = true
            changed = changed + 1
        end
    end
    if changed > 0 then
        data.unreadCount = math.max(0, (data.unreadCount or 0) - changed)
        M.RefreshSourceClass()
        M.NotifyDataChanged(true)
    end
    return changed > 0
end

function M.MarkNormalTargetRead(targetName)
    targetName = SafeString(targetName)
    if not targetName then return false end
    local normalized = M.NormalizeName(targetName) or targetName
    local short = StripRealm(targetName)
    return MarkMatchingUnread(function(message)
        if message.isBN then return false end
        local replyName, name = message.replyName or message.name, message.name
        if (M.NormalizeName(replyName) or replyName) == normalized or (M.NormalizeName(name) or name) == normalized then return true end
        return short and ((SafeString(replyName) and not replyName:find("-", 1, true) and StripRealm(replyName) == short)
            or (SafeString(name) and not name:find("-", 1, true) and StripRealm(name) == short)) or false
    end)
end

function M.MarkBNetTargetRead(targetName, presenceID)
    targetName = SafeString(targetName)
    local _, accountName, battleTag = M.GetBNAccountInfoByID(presenceID)
    if not battleTag and IsBattleTag(targetName) then battleTag = targetName end
    if not accountName and IsBattleTag(battleTag) then
        local _, refreshed = M.GetBNInfoFromTag(battleTag)
        accountName = refreshed
    end
    local stripped = StripBNPrefix(targetName)
    return MarkMatchingUnread(function(message)
        if not message.isBN then return false end
        if presenceID ~= nil and (SameLooseValue(message.bnID, presenceID) or SameLooseValue(message.presenceID, presenceID)) then return true end
        if battleTag and (message.bnTag == battleTag or StripBNPrefix(message.name) == battleTag or StripBNPrefix(message.replyName) == battleTag) then return true end
        if accountName and (message.bnAccountName == accountName or StripBNPrefix(message.replyName) == accountName or StripBNPrefix(message.name) == accountName) then return true end
        return stripped and (StripBNPrefix(message.replyName) == stripped or StripBNPrefix(message.name) == stripped) or false
    end)
end

function M.AddReceivedWhisper(name, class, text, isBN, replyName, bnID, bnTag, bnAccountName)
    text = SafeString(text)
    if not M.enabled or not text then return false end
    name = SafeString(name) or L("UNKNOWN")
    class = SafeString(class)

    local data = M.GetData()
    data.nextID = (data.nextID or 0) + 1
    local message = {
        id = data.nextID,
        time = time(),
        class = class,
        text = text,
        read = false,
        isBN = isBN == true,
    }
    if isBN then
        local safeTag = IsBattleTag(bnTag) and bnTag or (IsBattleTag(name) and name or nil)
        local safeAccount = SafeString(bnAccountName)
        message.name = string.format("%s:%s", L("BN_PREFIX"), safeTag or safeAccount or name)
        message.replyName = safeAccount or SafeString(replyName) or name
        if not SafeIsSecret(bnID) and (type(bnID) == "number" or type(bnID) == "string") then
            message.bnID, message.presenceID = bnID, bnID
        end
        message.bnTag, message.bnAccountName = safeTag, safeAccount
    else
        message.name = IS_FOREVER and name or M.NormalizeName(name) or name
        message.replyName = message.name
    end

    data.messages[#data.messages + 1] = message
    data.unreadCount = (data.unreadCount or 0) + 1
    if class then
        data.sourceClass = class
        data.sourceMessageID = message.id
    end
    local db = M.GetConfig()
    M.TrimMessages(db and db.maxMessages or M.DEFAULT_MAX_MESSAGES)
    M.NotifyDataChanged(true)
    return true
end

local function TryGetBNDisplayInfo(sender, presenceID)
    local _, accountName, battleTag = M.GetBNAccountInfoByID(presenceID)
    sender = SafeString(sender)
    if not battleTag and IsBattleTag(sender) then battleTag = sender end
    if not accountName and IsBattleTag(battleTag) then
        local _, refreshed = M.GetBNInfoFromTag(battleTag)
        accountName = refreshed
    end
    return battleTag or accountName or sender or L("UNKNOWN"), accountName, battleTag
end

function M.HandleEvent(event, ...)
    if not M.enabled or M.conflict then return end
    if event == "PLAYER_REGEN_DISABLED" then
        local db = M.GetConfig()
        if db and not db.allowInCombatOpen and M.UI and M.UI.CloseWindow then M.UI.CloseWindow() end
        if M.UI and M.UI.RefreshIndicators then M.UI.RefreshIndicators() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if M.UI and M.UI.ResetPulse then M.UI.ResetPulse() end
        if M.UI and M.UI.RefreshIndicators then M.UI.RefreshIndicators() end
        return
    end
    if event == "CHAT_MSG_WHISPER" then
        -- Alert from the inbound event itself. Message payloads can be Secret
        -- in restricted contexts, but the player should still hear that a
        -- whisper arrived even when its contents cannot be stored safely.
        M.PlayWhisperAlert(false)
        local text, name, _, _, _, flag, _, _, _, _, _, guid, _, _, _, hide = ...
        if SafeIsSecret(hide) or hide or SafeIsSecret(text) then return end
        local class
        if not SafeIsSecret(flag) and (flag == "GM" or flag == "DEV") then
            class = "GM"
        elseif guid and not SafeIsSecret(guid) and type(GetPlayerInfoByGUID) == "function" then
            local ok, classToken = pcall(function() return select(2, GetPlayerInfoByGUID(guid)) end)
            if ok then class = SafeString(classToken) end
        end
        M.AddReceivedWhisper(name, class, text, false)
        return
    end
    if event == "CHAT_MSG_WHISPER_INFORM" then
        local _, targetName = ...
        M.MarkNormalTargetRead(targetName)
        return
    end
    if event == "CHAT_MSG_BN_WHISPER_INFORM" then
        local _, targetName, _, _, _, _, _, _, _, _, _, _, presenceID = ...
        M.MarkBNetTargetRead(targetName, presenceID)
        return
    end
    if event == "CHAT_MSG_BN_WHISPER" then
        M.PlayWhisperAlert(false)
        local text, sender, _, _, _, _, _, _, _, _, _, _, presenceID = ...
        if SafeIsSecret(text) then return end
        local displayName, accountName, battleTag = TryGetBNDisplayInfo(sender, presenceID)
        M.AddReceivedWhisper(displayName, "BN", text, true, accountName or displayName, presenceID, battleTag, accountName)
    end
end

local function GetEnableState()
    local character = type(UnitName) == "function" and UnitName("player") or nil
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, "QFXWhisper", character)
        if ok and tonumber(state) then return tonumber(state) end
        ok, state = pcall(C_AddOns.GetAddOnEnableState, character, "QFXWhisper")
        if ok and tonumber(state) then return tonumber(state) end
    end
    if type(GetAddOnEnableState) == "function" then
        local ok, state = pcall(GetAddOnEnableState, character, "QFXWhisper")
        if ok and tonumber(state) then return tonumber(state) end
    end
    return 0
end

function M.IsStandaloneEnabled()
    return GetEnableState() > 0
end

function M.ReportConflict()
    if M.conflictReported then return end
    M.conflictReported = true
    if ns.Print then ns.Print(L("CONFLICT")) end
end

function M.InitializeData(db, forceRepair)
    M.EnsureConfig(db)
    M.GetData()
    if forceRepair or not M.dataInitialized then
        M.RecountUnread()
        M.TrimMessages(db.maxMessages)
        M.dataInitialized = true
    end
end

end)
