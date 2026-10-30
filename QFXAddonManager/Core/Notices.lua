local _, AM = ...
local Q = { pending = {}, keys = {}, watched = setmetatable({}, {__mode="k"}), sequence = 0 }
AM.NoticeQueue = Q
local CINEMATIC_NAMES = { "CinematicFrame", "MovieFrame" }

local function Visible(frame)
    if not frame then return false end
    if frame.IsVisible then return frame:IsVisible() end
    return frame.IsShown and frame:IsShown()
end

function Q:Schedule(delay)
    if self.scheduled then return end
    self.scheduled = true
    C_Timer.After(delay or 0.15, function()
        self.scheduled = nil
        self:Pump()
    end)
end

function Q:Watch(frame, wakeDelay)
    if self.watched[frame] then return end
    self.watched[frame] = true
    frame:HookScript("OnHide", function()
        if self.active and self.active.frame == frame then self.active = nil end
        if #self.pending > 0 then self:Schedule(wakeDelay) end
    end)
end

function Q:MakeMovable(frame)
    local panel = frame._panel or frame
    if panel._qfxNoticeMovable then return end
    panel._qfxNoticeMovable = true
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    if not panel:GetScript("OnDragStart") then
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    end
    panel:HookScript("OnHide", panel.StopMovingOrSizing)
end

function Q:Pump()
    if not self.ready or self.active or #self.pending == 0 then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- Wait for a settings window the user is already reading, for native
    -- confirmation dialogs, and for cinematic/movie playback. Their OnHide
    -- wakes the queue; no polling is used. A short cushion after playback
    -- keeps automatic notices off the cinematic-skip tap itself.
    local manager = AM.UI and AM.UI.frame
    if Visible(manager) then self:Watch(manager); return end
    for index = 1, 4 do
        local popup = rawget(_G, "StaticPopup" .. index)
        if Visible(popup) then self:Watch(popup); return end
    end
    for _, cinematicName in ipairs(CINEMATIC_NAMES) do
        local cinematic = rawget(_G, cinematicName)
        if Visible(cinematic) then self:Watch(cinematic, 1.0); return end
    end
    table.sort(self.pending, function(a,b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.sequence < b.sequence
    end)
    local item = table.remove(self.pending, 1)
    self.keys[item.key] = nil
    -- Reserve the slot while the callback loads addons or creates frames.
    self.active = item
    local ok, frame = pcall(item.show)
    if ok and Visible(frame) then
        item.frame = frame
        self:Watch(frame)
        if item.movable then self:MakeMovable(frame) end
    else
        self.active = nil
        if not ok and AM.Print then AM.Print(tostring(frame)) end
        if #self.pending > 0 then self:Schedule() end
    end
end

function Q:Enqueue(key, priority, show, options)
    if type(key) ~= "string" or type(show) ~= "function" then return false end
    if self.keys[key] or (self.active and self.active.key == key) then return true end
    self.sequence = self.sequence + 1
    local item = {key=key, priority=priority or 0, show=show, sequence=self.sequence,
        movable = not options or options.movable ~= false}
    self.keys[key] = item
    self.pending[#self.pending + 1] = item
    self:Schedule()
    return true
end

AM.API.QueueNotice = function(key, priority, show, options)
    return Q:Enqueue(key, priority, show, options)
end

local events = CreateFrame("Frame")
Q.eventFrame = events
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then Q.ready = true end
    if #Q.pending > 0 then Q:Schedule() end
end)
