local _, manager = ...
manager.ToolboxRuntime:AddFile("MythicPlus", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local Overlay = {}
ns.MythicPlusIconOverlay = Overlay

function Overlay:Init(context)
    self.ctx = context or {}
    self.teleport = self.ctx.Teleport or ns.MythicPlusTeleport
end

local function Ctx(self)
    return self.ctx or {}
end

local function L(self, key)
    local ctx = Ctx(self)
    return ctx.L and ctx.L(key) or (ns.L and ns.L(key)) or key
end

local function SetFont(self, fs, size, outline)
    local ctx = Ctx(self)
    if ctx.SetFont then return ctx.SetFont(fs, size, outline) end
end

local function ShowTeleportTooltip(self, btn, mapID, spellID, rating)
    local ctx = Ctx(self)
    local teleport = self.teleport
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText(ctx.GetMapName and ctx.GetMapName(mapID) or tostring(mapID or "?"), 1, 1, 1)

    local db = ns.GetModuleDB(ctx.key or "mythic_plus_tools")
    local abbr = ctx.GetAbbr and ctx.GetAbbr(db, mapID) or tostring(mapID or "?")
    GameTooltip:AddLine(L(self, "Abbreviation") .. "：" .. abbr, 0.75, 0.9, 1)

    local best = rating and rating[mapID]
    if best and (best.level or 0) > 0 then
        GameTooltip:AddLine(L(self, "Best Level") .. "：+" .. tostring(best.level), 1, 0.82, 0)
    end
    if best and (best.score or 0) > 0 then
        GameTooltip:AddLine(L(self, "Dungeon Score") .. "：" .. tostring(math.floor(best.score + 0.5)), 0.75, 1, 1)
    end

    if ctx.GetOwnedKeystone then
        local ownedMap, ownedLevel = ctx.GetOwnedKeystone()
        if ownedMap == mapID and ownedLevel then
            GameTooltip:AddLine(L(self, "Owned Keystone") .. "：+" .. tostring(ownedLevel), 0.35, 1, 0.35)
        end
    end

    if spellID and teleport then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L(self, "Teleport") .. "：" .. tostring(teleport:GetSpellName(spellID) or spellID), 0.75, 1, 0.75)
        local cd = teleport:GetCooldownText(spellID)
        if cd == L(self, "Ready") then
            GameTooltip:AddLine(cd, 0.25, 1, 0.25)
        elseif cd == L(self, "Not Learned") then
            GameTooltip:AddLine(cd, 1, 0.25, 0.25)
        else
            GameTooltip:AddLine(cd, 1, 0.35, 0.35)
        end
        GameTooltip:AddLine(L(self, "Click the dungeon icon to teleport."), 0.65, 0.65, 0.65)
    end
    GameTooltip:Show()
end

local function EnsureOverlays(self, icon)
    if not icon then return end

    if not icon.qfxtMPlusAbbr then
        icon.qfxtMPlusAbbr = icon:CreateFontString(nil, "OVERLAY")
        icon.qfxtMPlusAbbr:SetPoint("CENTER", icon, "CENTER", 0, 21)
        icon.qfxtMPlusAbbr:SetJustifyH("CENTER")
        SetFont(self, icon.qfxtMPlusAbbr, 15, "THICKOUTLINE")
        icon.qfxtMPlusAbbr:SetTextColor(1, 0.63, 0.04, 1)
    end

    if not icon.qfxtMPlusBest then
        icon.qfxtMPlusBest = icon:CreateFontString(nil, "OVERLAY")
        icon.qfxtMPlusBest:SetPoint("CENTER", icon, "CENTER", 0, -1)
        icon.qfxtMPlusBest:SetJustifyH("CENTER")
        SetFont(self, icon.qfxtMPlusBest, 25, "OUTLINE")
    end

    if not icon.qfxtMPlusScore then
        icon.qfxtMPlusScore = icon:CreateFontString(nil, "OVERLAY")
        icon.qfxtMPlusScore:SetPoint("CENTER", icon, "CENTER", 0, -23)
        icon.qfxtMPlusScore:SetJustifyH("CENTER")
        SetFont(self, icon.qfxtMPlusScore, 13, "OUTLINE")
    end
end

local function EnsureTeleportButton(self, icon)
    if not icon or icon.qfxtMPlusTeleportButton then return icon and icon.qfxtMPlusTeleportButton end
    if InCombatLockdown and InCombatLockdown() then return nil end

    local btn = CreateFrame("Button", nil, icon, "SecureActionButtonTemplate")
    btn:SetAllPoints(icon)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetFrameLevel((icon:GetFrameLevel() or 1) + 25)
    btn:SetAlpha(0)
    btn:EnableMouse(true)
    btn:SetScript("OnLeave", function(selfBtn)
        if GameTooltip:IsOwned(selfBtn) then GameTooltip:Hide() end
    end)
    -- Announcement is handled by the always-loaded player spellcast monitor.
    -- Do not announce from the button itself, otherwise a failed/blocked click may still speak.
    icon.qfxtMPlusTeleportButton = btn
    return btn
end

function Overlay:Hide(icon)
    if not icon then return end
    if icon.qfxtMPlusAbbr then icon.qfxtMPlusAbbr:Hide() end
    if icon.qfxtMPlusBest then icon.qfxtMPlusBest:Hide() end
    if icon.qfxtMPlusScore then icon.qfxtMPlusScore:Hide() end
    if icon.qfxtMPlusTeleportButton and not (InCombatLockdown and InCombatLockdown()) then
        icon.qfxtMPlusTeleportButton:Hide()
        icon.qfxtMPlusTeleportButton:EnableMouse(false)
    end
    if icon.HighestLevel and icon.__qfxtOriginalLevelHidden then
        icon.HighestLevel:SetAlpha(1)
        icon.HighestLevel:Show()
        icon.__qfxtOriginalLevelHidden = nil
    end
end

function Overlay:Update(icon, db, rating)
    if not icon or not icon.mapID then return end
    local mapID = tonumber(icon.mapID)
    if not mapID then return end
    local ctx = Ctx(self)

    EnsureOverlays(self, icon)

    if icon.Icon and icon.Icon.SetTexCoord then
        icon.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local abbr = icon.qfxtMPlusAbbr
    if abbr then
        SetFont(self, abbr, db.abbrFontSize or 15, "THICKOUTLINE")
        abbr:SetText(db.showAbbr ~= false and ctx.GetAbbr and ctx.GetAbbr(db, mapID) or "")
        abbr:SetShown(db.enabled and db.showAbbr ~= false)
    end

    local bestLevel = rating[mapID] and tonumber(rating[mapID].level) or 0
    local bestText = bestLevel > 0 and tostring(bestLevel) or ""
    local best = icon.qfxtMPlusBest
    if best then
        SetFont(self, best, db.bestLevelFontSize or 25, "OUTLINE")
        best:SetText(bestText)
        if bestLevel > 0 and ctx.SetRarityColorByLevel then ctx.SetRarityColorByLevel(best, bestLevel) end
        best:SetShown(db.enabled and db.showBestLevel ~= false and bestText ~= "")
    end

    if icon.HighestLevel and db.hideOriginalLevel ~= false and db.showBestLevel ~= false then
        icon.HighestLevel:SetAlpha(0)
        icon.HighestLevel:Hide()
        icon.__qfxtOriginalLevelHidden = true
    elseif icon.HighestLevel and icon.__qfxtOriginalLevelHidden then
        icon.HighestLevel:SetAlpha(1)
        icon.HighestLevel:Show()
        icon.__qfxtOriginalLevelHidden = nil
    end

    local scoreValue = rating[mapID] and tonumber(rating[mapID].score) or 0
    local score = icon.qfxtMPlusScore
    if score then
        SetFont(self, score, db.scoreFontSize or 13, "OUTLINE")
        local text = scoreValue > 0 and tostring(math.floor(scoreValue + 0.5)) or ""
        score:SetText(text)
        if scoreValue > 0 and ctx.SetRarityColorByScore then ctx.SetRarityColorByScore(score, scoreValue) end
        score:SetShown(db.enabled and db.showScore == true and text ~= "")
    end

    if not (InCombatLockdown and InCombatLockdown()) then
        local btn = EnsureTeleportButton(self, icon)
        if btn then
            local spellID = self.teleport and self.teleport:SelectSpell(mapID)
            local canUse = db.enabled and spellID ~= nil
            btn.qfxtMPlusMapID = mapID
            btn.qfxtMPlusSpellID = spellID
            btn.qfxtMPlusCanUse = canUse and true or false
            btn:SetShown(canUse and true or false)
            btn:EnableMouse(canUse and true or false)
            if canUse then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", spellID)
                btn:SetScript("OnEnter", function(selfBtn)
                    ShowTeleportTooltip(self, selfBtn, mapID, spellID, rating)
                end)
            else
                btn.qfxtMPlusCanUse = false
                btn:SetAttribute("type", nil)
                btn:SetAttribute("spell", nil)
            end
        end
    end
end

end)
