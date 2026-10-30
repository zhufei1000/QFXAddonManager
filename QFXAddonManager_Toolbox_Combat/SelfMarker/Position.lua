local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)
local QSM = _G.QFXToolBoxSelfMarker
local Position = {}
QSM.Position = Position

function Position:IsLinked()
    return QSM:GetDB().linkGCDToMarker ~= false
end

function Position:GetAnchor()
    if not self.anchor then
        local anchor = CreateFrame("Frame", "QFXToolBoxSelfMarkerAnchor", UIParent)
        anchor:SetMovable(true)
        anchor:SetClampedToScreen(true)
        anchor:EnableMouse(false)
        self.anchor = anchor
    end
    local db = QSM:GetDB()
    local size = math.max(db.markerSize or 64, db.gcdSize or 64)
    self.anchor:SetSize(size, size)
    if not self.dragFrame then
        self.anchor:ClearAllPoints()
        self.anchor:SetPoint("CENTER", UIParent, "CENTER", db.markerX or 0, db.markerY or 0)
    end
    return self.anchor
end

function Position:Attach(frame, kind)
    local db = QSM:GetDB()
    frame:ClearAllPoints()
    if self:IsLinked() then
        frame:SetPoint("CENTER", self:GetAnchor(), "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", db[kind .. "X"] or 0, db[kind .. "Y"] or 0)
    end
end

function Position:Refresh()
    if QSM.Marker then QSM.Marker:RefreshPosition(); QSM.Marker:RefreshLock() end
    if QSM.GCD then QSM.GCD:RefreshPosition(); QSM.GCD:RefreshLock() end
end

function Position:StartDrag(frame, kind)
    local db = QSM:GetDB()
    local lockKey = self:IsLinked() and "markerLocked" or kind .. "Locked"
    if db[lockKey] or self.dragFrame then return end
    self.dragSource, self.dragKind = frame, kind
    self.dragFrame = self:IsLinked() and self:GetAnchor() or frame
    self.dragFrame:StartMoving()
end

function Position:StopDrag()
    local frame, kind = self.dragFrame, self.dragKind
    if not frame then return end
    frame:StopMovingOrSizing()
    local x, y = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local db = QSM:GetDB()
    if x and y and ux and uy then
        local prefix = self:IsLinked() and "marker" or kind
        db[prefix .. "X"] = math.floor(x - ux + 0.5)
        db[prefix .. "Y"] = math.floor(y - uy + 0.5)
    end
    self.dragFrame, self.dragSource, self.dragKind = nil, nil, nil
    self:Refresh()
    if QSM.OptionsFrame then QSM.OptionsFrame:Refresh() end
end

function Position:SetLinked(linked)
    self:StopDrag()
    local db = QSM:GetDB()
    db.linkGCDToMarker = linked and true or false
    if linked then db.gcdLocked = db.markerLocked end
    self:Refresh()
end

function Position:SetOffset(axis, value)
    self:StopDrag()
    QSM:GetDB()["marker" .. axis] = value
    self:Refresh()
end
end)
