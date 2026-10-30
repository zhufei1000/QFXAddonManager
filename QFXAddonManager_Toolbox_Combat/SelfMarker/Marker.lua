local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)

_G.QFXToolBoxSelfMarker = _G.QFXToolBoxSelfMarker or {}
local QSM = _G.QFXToolBoxSelfMarker

QSM.Marker = {}
local Marker = QSM.Marker

local STYLE_ORDER = { "flower", "star", "crosshair" }
QSM.StyleOrder = STYLE_ORDER
local TWO_PI = math.pi * 2
local DEFAULT_SPIN_SPEED = 5

local function IsInPetBattle()
    return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
end

function Marker:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "QFXToolBoxSelfMarkerFrame", UIParent)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        QSM.Position:StartDrag(f, "marker")
    end)
    frame:SetScript("OnDragStop", function(f)
        QSM.Position:StopDrag()
    end)

    self.frame = frame
    self.styles = {}
    frame:HookScript("OnHide", function()
        if QSM.Position.dragSource == frame then QSM.Position:StopDrag() end
        if self.spinGroup then self.spinGroup:Pause() end
        if QSM.AttackRange then QSM.AttackRange:RefreshRuntime() end
    end)
    frame:HookScript("OnShow", function()
        self:RefreshSpin()
        if QSM.AttackRange then QSM.AttackRange:RefreshRuntime() end
    end)
    self:CreateFlower()
    self:CreateStar()
    self:CreateCrosshair()
    self:RefreshAll()
end

function Marker:CreateFlower()
    local texture = self.frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(self.frame)
    texture:Hide()
    self.styles.flower = texture
end

function Marker:CreateStar()
    local texture = self.frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(self.frame)
    texture:Hide()
    self.styles.star = texture
end

function Marker:CreateCrosshair()
    local holder = CreateFrame("Frame", nil, self.frame)
    holder:SetAllPoints(self.frame)
    holder.lines = {}
    for i = 1, 4 do
        holder.lines[i] = holder:CreateTexture(nil, "ARTWORK")
        holder.lines[i]:SetColorTexture(1, 1, 1, 1)
    end
    holder:Hide()
    self.styles.crosshair = holder
end

function Marker:GetConfiguredColor()
    local db = QSM:GetDB()
    local alpha = db.markerAlpha or 1

    if db.markerColorMode == "white" then
        return 1, 1, 1, alpha
    end

    if db.markerColorMode == "custom" and type(db.markerCustomColor) == "table" then
        return db.markerCustomColor.r or 1, db.markerCustomColor.g or 1, db.markerCustomColor.b or 1, alpha
    end

    local _, classFile = UnitClass("player")
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b, alpha
    end

    return 1, 1, 1, alpha
end

function Marker:GetColor()
    local db = QSM:GetDB()
    local alpha = db.markerAlpha or 1

    if db.attackRangeEnabled
        and QSM.AttackRange
        and QSM.AttackRange:IsOutOfRange()
    then
        local color = type(db.attackRangeColor) == "table" and db.attackRangeColor or {}
        return color.r or 1, color.g or 0.12, color.b or 0.08, alpha
    end

    return self:GetConfiguredColor()
end

function Marker:RefreshPosition()
    if not self.frame then return end
    QSM.Position:Attach(self.frame, "marker")
end

function Marker:RefreshSize()
    if not self.frame then return end
    local db = QSM:GetDB()
    local size = db.markerSize or 64
    self.frame:SetSize(size, size)
    self:LayoutCrosshair()
end

function Marker:LayoutCrosshair()
    local crosshair = self.styles and self.styles.crosshair
    if not crosshair then return end

    local db = QSM:GetDB()
    local scale = (db.markerSize or 64) / 64
    local length = math.max(4, (db.crossLength or 26) * scale)
    local thickness = math.max(1, (db.crossThickness or 3) * scale)
    local gap = math.max(2, (db.crossGap or 8) * scale)
    local left, right, top, bottom = crosshair.lines[1], crosshair.lines[2], crosshair.lines[3], crosshair.lines[4]

    left:ClearAllPoints()
    left:SetPoint("RIGHT", crosshair, "CENTER", -gap, 0)
    left:SetSize(length, thickness)

    right:ClearAllPoints()
    right:SetPoint("LEFT", crosshair, "CENTER", gap, 0)
    right:SetSize(length, thickness)

    top:ClearAllPoints()
    top:SetPoint("BOTTOM", crosshair, "CENTER", 0, gap)
    top:SetSize(thickness, length)

    bottom:ClearAllPoints()
    bottom:SetPoint("TOP", crosshair, "CENTER", 0, -gap)
    bottom:SetSize(thickness, length)
end

function Marker:TextureNeeded()
    local db = QSM:GetDB()
    return db ~= nil and db.enabled == true
        and (db.markerEnabled == true or QSM.forceMarkerPreview == true)
end

function Marker:EnsureStyleTexture(style)
    local texture = self.styles and self.styles[style]
    if not texture or texture.qfxTextureLoaded then return end
    local media = QSM.Media
    if not media then return end
    local path = style == "flower" and media.flower or style == "star" and media.star
    if not path then return end
    texture:SetTexture(path)
    texture.qfxTextureLoaded = true
end

function Marker:RefreshStyle()
    if not self.frame then return end

    local db = QSM:GetDB()
    for _, style in ipairs(STYLE_ORDER) do
        local object = self.styles[style]
        if object then object:Hide() end
    end

    local style = db.markerStyle
    if not self.styles[style] then
        style = "flower"
        db.markerStyle = style
    end
    self.styles[style]:Show()
    self.activeStyle = style
    if self:TextureNeeded() then
        self:EnsureStyleTexture(style)
    end
    self:RefreshColor()
    self:RefreshSpin()
end

function Marker:RefreshColor()
    if not self.frame then return end

    local r, g, b, a = self:GetColor()
    for key, object in pairs(self.styles) do
        if key == "crosshair" then
            for _, line in ipairs(object.lines) do
                line:SetColorTexture(r, g, b, a)
            end
        else
            object:SetVertexColor(r, g, b, a)
        end
    end
end

function Marker:RefreshLock()
    if not self.frame then return end
    local db = QSM:GetDB()
    self.frame:EnableMouse((db.markerEnabled or QSM.forceMarkerPreview) and not db.markerLocked)
end

function Marker:PassesBaseVisibility()
    local db = QSM:GetDB()
    if not db or not db.enabled then
        return false
    end

    if QSM.forceMarkerPreview then
        return true
    end

    if not db.markerEnabled then
        return false
    end

    if db.markerHideInPetBattle and IsInPetBattle() then
        return false
    end
    if db.markerHideWhenMounted and IsMounted and IsMounted() then
        return false
    end
    if db.markerHideInVehicle and UnitInVehicle and UnitInVehicle("player") then
        return false
    end

    local mode = db.markerDisplayMode or "always"
    if mode == "combat" and not QSM:IsCombatActive() then
        return false
    end
    if mode == "instance" then
        local inInstance = IsInInstance and IsInInstance()
        if not inInstance then return false end
    end

    return true
end

function Marker:ShouldBeVisible()
    return self:PassesBaseVisibility()
end

function Marker:RefreshVisibility()
    if not self.frame then return end

    if self:ShouldBeVisible() then
        if self:TextureNeeded() then
            self:EnsureStyleTexture(self.activeStyle or QSM:GetDB().markerStyle)
        end
        self.frame:Show()
        self:RefreshSpin()
    else
        if self.spinGroup then self.spinGroup:Pause() end
        self.frame:Hide()
    end

    if QSM.AttackRange and QSM.AttackRange.RefreshRuntime then
        QSM.AttackRange:RefreshRuntime()
    end
end

function Marker:GetSpinnableTexture()
    local db = QSM:GetDB()
    if db.markerStyle == "flower" or db.markerStyle == "star" then
        return self.styles[db.markerStyle]
    end
    return nil
end

function Marker:RefreshSpin()
    if not self.frame then return end

    local db = QSM:GetDB()
    local texture = self:GetSpinnableTexture()
    local mode = db.markerSpinMode or "none"

    if not texture or mode == "none" then
        if self.spinGroup then self.spinGroup:Stop(); self.spinGroup = nil end
        if texture and texture.SetRotation then texture:SetRotation(0) end
        return
    end
    local speed = math.max(1, math.min(10, tonumber(db.markerSpinSpeed) or DEFAULT_SPIN_SPEED))
    if self.spinTexture ~= texture or self.spinMode ~= mode or self.spinSpeed ~= speed or not self.spinGroup then
        if self.spinGroup then self.spinGroup:Stop() end
        if not texture.qfxSpinGroup then
            texture.qfxSpinGroup = texture:CreateAnimationGroup()
            texture.qfxSpinRotation = texture.qfxSpinGroup:CreateAnimation("Rotation")
            texture.qfxSpinRotation:SetSmoothing("NONE")
            texture.qfxSpinRotation:SetOrigin("CENTER", 0, 0)
        end
        self.spinGroup = texture.qfxSpinGroup
        texture.qfxSpinRotation:SetRadians(mode == "counterclockwise" and -TWO_PI or TWO_PI)
        texture.qfxSpinRotation:SetDuration(11 - speed)
        self.spinGroup:SetLooping(mode == "alternate" and "BOUNCE" or "REPEAT")
        self.spinTexture, self.spinMode, self.spinSpeed = texture, mode, speed
    end
    if self.frame:IsVisible() then
        if not self.spinGroup:IsPlaying() then self.spinGroup:Play() end
    else
        self.spinGroup:Pause()
    end
end

function Marker:RefreshFrameLevel()
    if not self.frame then return end
    local db = QSM:GetDB()
    self.frame:SetFrameStrata(db.frameStrata or "HIGH")
    self.frame:SetFrameLevel((db.frameLevel or 20) + 1)
end

function Marker:RefreshAll()
    self:Create()
    self:RefreshFrameLevel()
    self:RefreshSize()
    self:RefreshPosition()
    self:RefreshStyle()
    self:RefreshSpin()
    self:RefreshLock()
    self:RefreshVisibility()
end

function Marker:CycleStyle()
    local db = QSM:GetDB()
    local currentIndex = 1
    for index, style in ipairs(STYLE_ORDER) do
        if style == db.markerStyle then
            currentIndex = index
            break
        end
    end
    currentIndex = currentIndex + 1
    if currentIndex > #STYLE_ORDER then currentIndex = 1 end
    db.markerStyle = STYLE_ORDER[currentIndex]
    self:RefreshStyle()
    return db.markerStyle
end

end)
