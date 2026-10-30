local _, manager = ...
manager.ToolboxRuntime:AddFile("MythicPlus", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local E = ns.KeystoneListEnhancements
if type(E) ~= "table" or E._qfxExternalCompatInstalled then return end
E._qfxExternalCompatInstalled = true

-- Optional compatibility for AngryKeystones and ExwindTools PartySync.
-- No hard dependency is introduced; integrations activate only when available.
local ANGRY_PREFIX = "AngryKeystones"
local ANGRY_MODULE = "Schedule"
local REQUEST_THROTTLE = 1.0
local RESPONSE_THROTTLE = 1.0

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

local function safeNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    local ok, number = pcall(tonumber, value)
    if ok then return number end
    return nil
end

local function readUnitFullName(context, unit)
    if context and type(context.GetUnitFullName) == "function" then
        return context.GetUnitFullName(unit)
    end
    if type(UnitFullName) ~= "function" then return nil end
    local name, realm = safeCall(UnitFullName, unit)
    if type(issecretvalue) == "function" then
        if issecretvalue(name) or issecretvalue(realm) then return nil end
    end
    if type(name) ~= "string" or name == "" then return nil end
    return name, type(realm) == "string" and realm or nil
end

local function now()
    return GetTime and safeNumber(safeCall(GetTime)) or 0
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

local function sendGroupAddonMessage(context, prefix, message)
    local channel = groupChannel(context)
    if not channel then return false end
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, prefix, message, channel)
    return ok and result ~= false
end

local function encodeAngryMessage(message)
    return ANGRY_MODULE .. "|" .. tostring(message or "")
end

local function decodeAngryMessage(message)
    if type(message) ~= "string" then return nil end
    local moduleName, payload = message:match("^([^|]+)|(.*)$")
    if moduleName ~= ANGRY_MODULE then return nil end
    return payload
end

function E:RegisterExternalCompatibilityPrefixes()
    if self.angryPrefixRegistered then return true end
    if not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function") then return false end
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, ANGRY_PREFIX)
    self.angryPrefixRegistered = ok and result ~= false
    return self.angryPrefixRegistered
end

function E:SendAngryKeystoneResponse()
    if not self:IsReady() or not isSmallGroup(self.ctx) then return false end

    local current = now()
    if self.lastAngryResponseAt and current - self.lastAngryResponseAt < RESPONSE_THROTTLE then
        return false
    end

    local playerName = self.ctx.GetPlayerFullName and self.ctx.GetPlayerFullName()
    local key = playerName and self.ctx.GetKeystone and self.ctx.GetKeystone(playerName)
    local mapID = safeNumber(key and key.challengeMapID)
    local level = safeNumber(key and key.keystoneLevel)
    local message = "0"

    if mapID and mapID > 0 and level and level > 0 then
        message = string.format("%d:%d", math.floor(mapID), math.floor(level))
    end
    local sent = sendGroupAddonMessage(self.ctx, ANGRY_PREFIX, encodeAngryMessage(message))
    if sent then self.lastAngryResponseAt = current end
    return sent
end

function E:RequestAngryKeystones()
    if not self:IsReady() or not isSmallGroup(self.ctx) then return false end
    self:RegisterExternalCompatibilityPrefixes()

    local current = now()
    if self.lastAngryRequestAt and current - self.lastAngryRequestAt < REQUEST_THROTTLE then
        return false
    end
    local sent = sendGroupAddonMessage(self.ctx, ANGRY_PREFIX, encodeAngryMessage("request"))
    if sent then self.lastAngryRequestAt = current end
    return sent
end

function E:HandleAngryKeystonesMessage(message, sender)
    if not self:IsReady() or not isSmallGroup(self.ctx) then return end
    if type(message) ~= "string" or type(sender) ~= "string" then return end

    message = decodeAngryMessage(message)
    if message == nil then return end

    local owner = self:ResolvePartyFullName(sender)
    local playerName = self.ctx.GetPlayerFullName and self.ctx.GetPlayerFullName()
    if not owner or owner == playerName then return end
    if not (self.ctx.IsPartyMember and self.ctx.IsPartyMember(owner)) then return end

    if message == "request" then
        self:SendAngryKeystoneResponse()
        return
    end

    if message == "0" then
        self:ClearExternalKeystone(owner)
        return
    end

    local mapText, levelText = message:match("^(%d+):(%d+)$")
    local mapID = safeNumber(mapText)
    local level = safeNumber(levelText)
    if not mapID or mapID <= 0 or not level or level <= 0 then return end

    -- Direct addon communication is treated with the same priority as QFX's
    -- native KSGL exchange. A later KSGL message may refresh the same record.
    self:StoreExternal(owner, mapID, level, "native")
end

function E:ClearExternalKeystone(owner, expectedSource)
    local existing = self.ctx.GetKeystone and self.ctx.GetKeystone(owner)
    if type(existing) ~= "table" or existing.isSelf then return false end
    if expectedSource and existing._qfxSource ~= expectedSource then return false end

    -- GetKeystone returns the live cache record. Clear it in place and lower
    -- its priority so another valid source can repopulate it.
    existing.challengeMapID = nil
    existing.keystoneLevel = nil
    existing.activityID = 0
    existing.groupID = 0
    existing.resilientFlag = 0
    existing._qfxSource = nil
    existing._qfxSourcePriority = 0
    existing.updatedAt = now()
    if self.ctx.ScheduleRefresh then self.ctx.ScheduleRefresh(0.05) end
    return true
end

function E:AcquireExwindToolsKeystones()
    if not self:IsReady() or not isSmallGroup(self.ctx) then return end

    local exwindTools = _G.ExwindTools
    local partySync = type(exwindTools) == "table" and exwindTools.PartySync or nil
    if type(partySync) ~= "table" or type(partySync.GetKeystone) ~= "function" then return end

    for index = 1, 4 do
        local unit = "party" .. index
        if UnitExists and UnitExists(unit) then
            local ok, level, mapID = pcall(partySync.GetKeystone, partySync, unit)
            if ok then
                level = safeNumber(level)
                mapID = safeNumber(mapID)
                local name, realm = readUnitFullName(self.ctx, unit)
                local owner = name and self.ctx.NormalizeFullName(name, realm)
                if owner then
                    if mapID and mapID > 0 and level and level > 0 then
                        -- ExwindTools is a cached third-party source, so keep it at
                        -- a lower priority than QFX's directly queried libraries.
                        self:StoreExternal(owner, mapID, level, "exwind")
                    else
                        self:ClearExternalKeystone(owner, "exwind")
                    end
                end
            end
        end
    end
end

local originalInitialize = E.Initialize
function E:Initialize(context)
    local result = originalInitialize(self, context)
    self:RegisterExternalCompatibilityPrefixes()
    return result
end

local originalRequestExternalData = E.RequestExternalData
function E:RequestExternalData(...)
    local a, b, c, d
    if type(originalRequestExternalData) == "function" then
        a, b, c, d = originalRequestExternalData(self, ...)
    end
    self:RequestAngryKeystones()
    self:AcquireExwindToolsKeystones()
    return a, b, c, d
end

local originalOnEvent = E.OnEvent
function E:OnEvent(event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == ANGRY_PREFIX then
            self:HandleAngryKeystonesMessage(message, sender)
        end
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if (addonName == "ExwindCore" or addonName == "ExwindTools") and _G.ExwindTools then
            self:AcquireExwindToolsKeystones()
        end
    end

    if type(originalOnEvent) == "function" then
        return originalOnEvent(self, event, ...)
    end
end

end)
