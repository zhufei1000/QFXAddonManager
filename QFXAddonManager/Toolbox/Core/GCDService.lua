local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local EVENT = "SPELL_UPDATE_COOLDOWN"
local OWNER = "QFXToolBox:GCDService"
local CACHE_WINDOW = 0.03

local service = ns.GCDService or {}
ns.GCDService = service

service.subscribers = service.subscribers or {}
service.registered = service.registered or false
service.snapshot = service.snapshot or nil
service.readAt = service.readAt or nil

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local function IsAccessibleNumber(value)
    return not IsSecret(value) and type(value) == "number"
end

local function SafeNow()
    local now = type(GetTime) == "function" and GetTime() or 0
    return IsAccessibleNumber(now) and now or 0
end

-- Reused read buffer: SPELL_UPDATE_COOLDOWN fires per skill in combat, and
-- every subscriber reads the fields immediately, so a single table is rewritten
-- in place instead of allocating one snapshot per event.
local SNAPSHOT = {}

local function ReadCooldown(now)
    if not C_Spell or type(C_Spell.GetSpellCooldown) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, 61304)
    if not ok or type(info) ~= "table" then return nil end

    local startTime, duration = info.startTime, info.duration
    if not IsAccessibleNumber(startTime) or not IsAccessibleNumber(duration) then return nil end
    if startTime <= 0 or duration <= 0.05 then return nil end
    if IsAccessibleNumber(now) and now > 0 and now >= startTime + duration then return nil end

    local modRate = IsAccessibleNumber(info.modRate) and info.modRate or 1
    local isEnabled = info.isEnabled
    if IsSecret(isEnabled) or type(isEnabled) ~= "boolean" then isEnabled = nil end
    SNAPSHOT.startTime = startTime
    SNAPSHOT.duration = duration
    SNAPSHOT.modRate = modRate
    SNAPSHOT.isEnabled = isEnabled
    SNAPSHOT.capturedAt = now
    return SNAPSHOT
end

function service:GetSnapshot(forceRead)
    local now = SafeNow()
    if not forceRead and IsAccessibleNumber(self.readAt) and now - self.readAt <= CACHE_WINDOW then
        return self.snapshot
    end
    self.readAt = now
    self.snapshot = ReadCooldown(now)
    return self.snapshot
end

function service:Invalidate()
    self.readAt = nil
end

local function SubscriberCount()
    local count = 0
    for _ in pairs(service.subscribers) do count = count + 1 end
    return count
end

local function OnCooldownEvent()
    service:Invalidate()
    local snapshot = service:GetSnapshot(true)
    for owner, callback in pairs(service.subscribers) do
        local ok, err = pcall(callback, snapshot)
        if not ok and ns.Print then
            ns.Print((ns.L and ns.L("Event handler error") or "Event handler error") .. ": " .. tostring(owner) .. " - " .. tostring(err))
        end
    end
end

local function RegisterEvent()
    if service.registered or SubscriberCount() == 0 then return end
    if ns.RegisterEvent and ns.RegisterEvent(EVENT, OWNER, OnCooldownEvent) then
        service.registered = true
    end
end

local function UnregisterEvent()
    if not service.registered then return end
    if ns.UnregisterEvent then ns.UnregisterEvent(EVENT, OWNER) end
    service.registered = false
    service.snapshot = nil
    service.readAt = nil
end

function service:Acquire(owner, callback)
    if owner == nil or type(callback) ~= "function" then return false end
    self.subscribers[owner] = callback
    RegisterEvent()
    return true
end

function service:Release(owner)
    if owner == nil then return end
    self.subscribers[owner] = nil
    if SubscriberCount() == 0 then UnregisterEvent() end
end

function service:GetSubscriberCount()
    return SubscriberCount()
end

function service:IsEventRegistered()
    return self.registered == true
end

end)
