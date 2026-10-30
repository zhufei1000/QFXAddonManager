local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)
local ns = _G.QFXAddonManagerToolboxNS

_G.QFXToolBoxSelfMarker = _G.QFXToolBoxSelfMarker or {}
local QSM = _G.QFXToolBoxSelfMarker

QSM.GCD = {}
local GCD = QSM.GCD

local function IsInPetBattle()
    return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
end

function GCD:Init()
    self.active = false
    self.lastEventAt = 0
    self.lastStart = 0
    self:Create()
    self:RefreshAll()
end

function GCD:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", "QFXToolBoxSelfMarkerGCDFrame", UIParent)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        QSM.Position:StartDrag(f, "gcd")
    end)
    frame:SetScript("OnDragStop", function(f)
        QSM.Position:StopDrag()
    end)
    frame:HookScript("OnHide", function()
        if QSM.Position.dragSource == frame then QSM.Position:StopDrag() end
    end)

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(frame)
    frame.texture = texture

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    if cooldown.SetReverse then cooldown:SetReverse(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    cooldown:Hide()
    frame.cooldown = cooldown

    self.frame = frame
end

function GCD:GetRingTexture()
    local db = QSM:GetDB()
    local thickness = tonumber(db and db.ringThickness) or 12
    thickness = math.floor((thickness / 2) + 0.5) * 2
    thickness = math.max(4, math.min(20, thickness))
    return (QSM.Media.rings and QSM.Media.rings[thickness]) or QSM.Media.ring
end

function GCD:GetColor(alphaOverride)
    local db = QSM:GetDB()
    local alpha = alphaOverride
    if alpha == nil then alpha = db.gcdIdleAlpha or 0.35 end

    if db.gcdColorMode == "white" then
        return 1, 1, 1, alpha
    end
    if db.gcdColorMode == "custom" and type(db.gcdCustomColor) == "table" then
        return db.gcdCustomColor.r or 1, db.gcdCustomColor.g or 1, db.gcdCustomColor.b or 1, alpha
    end

    local _, classFile = UnitClass("player")
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b, alpha
    end
    return 1, 1, 1, alpha
end

function GCD:TextureNeeded()
    local db = QSM:GetDB()
    return db ~= nil and db.enabled == true
        and (db.gcdEnabled == true or QSM.forceGCDPreview == true)
end

function GCD:RefreshRingTexture()
    if not self.frame then return end
    if not self:TextureNeeded() then return end
    local texturePath = self:GetRingTexture()
    if self.loadedTexturePath == texturePath then return end
    self.loadedTexturePath = texturePath
    self.frame.texture:SetTexture(texturePath)
    if self.frame.cooldown.SetSwipeTexture then
        self.frame.cooldown:SetSwipeTexture(texturePath)
    end
end

function GCD:RefreshColor(alphaOverride)
    if not self.frame then return end
    local r, g, b, a = self:GetColor(alphaOverride)
    self.frame.texture:SetVertexColor(r, g, b, a)
    if self.frame.cooldown.SetSwipeColor then
        self.frame.cooldown:SetSwipeColor(r, g, b, a)
    end
end

function GCD:RefreshPosition()
    if not self.frame then return end
    QSM.Position:Attach(self.frame, "gcd")
end

function GCD:RefreshSize()
    if not self.frame then return end
    local size = QSM:GetDB().gcdSize or 64
    self.frame:SetSize(size, size)
end

function GCD:RefreshLock()
    if not self.frame then return end
    local db = QSM:GetDB()
    local locked = db.gcdLocked
    if QSM.Position:IsLinked() then locked = db.markerLocked end
    self.frame:EnableMouse((db.gcdEnabled or QSM.forceGCDPreview) and not locked)
end

function GCD:RefreshFrameLevel()
    if not self.frame then return end
    local db = QSM:GetDB()
    self.frame:SetFrameStrata(db.frameStrata or "HIGH")
    self.frame:SetFrameLevel(db.frameLevel or 20)
end

function GCD:PassesContext()
    local db = QSM:GetDB()
    if not db or not db.enabled then
        return false
    end

    if QSM.forceGCDPreview then
        return true
    end

    if not db.gcdEnabled then
        return false
    end

    if db.gcdHideInPetBattle and IsInPetBattle() then
        return false
    end
    if db.gcdHideWhenMounted and IsMounted and IsMounted() then
        return false
    end
    if db.gcdHideInVehicle and UnitInVehicle and UnitInVehicle("player") then
        return false
    end

    local mode = db.gcdDisplayMode or "gcd_only"
    if mode == "combat" and not QSM:IsCombatActive() then
        return false
    end
    if mode == "instance" then
        local inInstance = IsInInstance and IsInInstance()
        if not inInstance then return false end
    end

    return true
end

function GCD:ShouldListen()
    return self:PassesContext()
end

function GCD:ShouldBeVisible()
    if not self:PassesContext() then return false end
    if QSM.forceGCDPreview then return true end

    local mode = QSM:GetDB().gcdDisplayMode or "gcd_only"
    if mode == "gcd_only" then
        return self.active == true
    end
    return true
end

function GCD:RefreshVisibility()
    if not self.frame then return end
    if self:ShouldBeVisible() then
        self:RefreshRingTexture()
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function GCD:CanAnimateStyle()
    local db = QSM:GetDB()
    return db and db.enabled and db.gcdEnabled
end

function GCD:GetCooldownInfo(snapshot)
    local db = QSM:GetDB()
    local info = snapshot
    if type(info) ~= "table" and ns and ns.GCDService and ns.GCDService.GetSnapshot then
        info = ns.GCDService:GetSnapshot()
    end
    if type(info) ~= "table" then return nil, nil end

    local start = info.startTime
    local detectedDuration = info.duration
    local now = GetTime()
    if type(start) ~= "number" or type(detectedDuration) ~= "number" then return nil, nil end
    if start <= 0 or detectedDuration < 0.5 or detectedDuration > 2.0 or now >= (start + detectedDuration) then
        return nil, nil
    end

    if db.gcdDurationMode == "fixed" then
        return start, db.gcdFixedDuration or 1.5
    end
    return start, detectedDuration
end

function GCD:TryStart(snapshot)
    local db = QSM:GetDB()
    if not db or not db.enabled or not db.gcdEnabled or not self:ShouldListen() then
        return
    end

    local now = GetTime()
    if now - (self.lastEventAt or 0) < 0.12 then return end
    self.lastEventAt = now

    local start, duration = self:GetCooldownInfo(snapshot)
    if type(start) ~= "number" or type(duration) ~= "number" or duration <= 0 then return end
    if self.active and math.abs(start - (self.lastStart or 0)) < 0.03 then return end

    self.startTime = start
    self.duration = duration
    self.lastStart = start
    self.active = true

    self.frame.texture:Hide()
    self.frame.cooldown:Show()
    self:RefreshRingTexture()
    self:RefreshColor(db.gcdActiveAlpha or 0.9)
    self.frame.cooldown:SetScript("OnCooldownDone", GCD.OnCooldownDone)
    self.frame.cooldown:SetCooldown(start, duration)
    self:RefreshVisibility()
end

function GCD.OnCooldownDone() GCD:Stop() end

function GCD:Stop()
    self.active = false
    if not self.frame then return end

    self.frame:SetScript("OnUpdate", nil)
    self.frame.cooldown:SetScript("OnCooldownDone", nil)
    self.frame.cooldown:SetCooldown(0, 0)
    self.frame.cooldown:Hide()
    self.frame.texture:Show()
    self:RefreshColor(QSM:GetDB().gcdIdleAlpha or 0.35)
    self:RefreshVisibility()
end

function GCD:RefreshAll()
    self:Create()
    self:Stop()
    self:RefreshFrameLevel()
    self:RefreshSize()
    self:RefreshPosition()
    self:RefreshRingTexture()
    self:RefreshColor()
    self:RefreshLock()
    self:RefreshVisibility()
end

end)
