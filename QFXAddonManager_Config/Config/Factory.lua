local _, manager = ...
manager.ToolboxRuntime:AddFile("Config", function(...)
local addonName = ...
local ns = _G.QFXAddonManagerToolboxNS
local W = _G.QFXWidgets
ns.QFXWidgets = W
if ns.Compat and ns.Compat.GetSharedMedia then ns.Compat.GetSharedMedia() end
ns.QFXUIFactory = ns.QFXUIFactory or {}
local F = ns.QFXUIFactory
QFXAddonManager.Widgets.ApplyBrand()
function F.L(key)
    return ns.L and ns.L(key) or key
end

function F.GetAddonVersion(fallback)
    if ns.Compat and ns.Compat.GetAddonVersion then
        return ns.Compat.GetAddonVersion(fallback or "0.0.0")
    end
    local version
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version")
    end
    return tostring(version or fallback or "0.0.0")
end

function F.Color(name, fallback)
    local colors = ns.Colors or {}
    local value = colors and colors[name]
    if type(value) == "table" then return value end
    return fallback or { 1, 1, 1, 1 }
end

function F.ClampNumber(value, minValue, maxValue)
    if ns.Util and ns.Util.ClampNumber then
        return ns.Util.ClampNumber(value, 0, minValue, maxValue)
    end
    value = tonumber(value) or 0
    if minValue ~= nil and value < minValue then value = minValue end
    if maxValue ~= nil and value > maxValue then value = maxValue end
    return value
end

function F.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d
    if ns.Util and ns.Util.SafeCall then
        ok, a, b, c, d = ns.Util.SafeCall(fn, ...)
    else
        ok, a, b, c, d = pcall(fn, ...)
    end
    if ok then return a, b, c, d end
    if ns.Print then ns.Print(F.L("UI callback error") .. ": " .. tostring(a)) end
    return nil
end

function F.ModuleTitle(key, info)
    info = info or (ns.modules and ns.modules[key]) or {}
    return F.L(info.titleKey or info.title or key)
end

function F.ModuleDesc(info)
    info = info or {}
    return F.L(info.descKey or info.desc or "")
end

function F.SetupWidgetTooltip(widget, title, getNote)
    if not widget then return end
    widget:SetScript("OnEnter", function(self)
        local note = type(getNote) == "function" and getNote(self) or getNote
        -- resolve the widget's getEnabled predicate (true = usable) and its
        -- optional reason; a disabled widget explains itself instead of the note
        local enabled, reason = true, nil
        local predicate = self.getEnabled or self.enabled
        if type(predicate) == "function" then
            local ok, value, why = pcall(predicate)
            if ok then
                enabled = (value == nil) and true or (value and true or false)
                reason = why
            end
        end
        if not enabled and reason and reason ~= "" then note = reason end
        if note and note ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title or "", 1, 1, 1)
            GameTooltip:AddLine(note, enabled and 0.75 or 1.0, enabled and 0.85 or 0.45, enabled and 1.0 or 0.35, true)
            GameTooltip:Show()
        end
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

end)
