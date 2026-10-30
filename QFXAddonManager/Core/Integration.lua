local _, QFXAM = ...

-- Public suite API for future QFX pack plugins.
-- External addons integrate with one call, before or after our scan:
--   if QFXAddonManager then
--       QFXAddonManager.API.RegisterModule("myplug", { title = "...", category = "tool", primary = "MyPlug", addons = { "MyPlug" }, tip = "..." })
--   end
-- Registration is safe at any time: when the DB already exists we rescan so the
-- new mapping takes effect immediately and refresh the manager if it is open.
QFXAM.Integration = QFXAM.Integration or {}

local function RefreshAfterExternalChange()
    if not QFXAM.db then return end
    if QFXAM.ScanAddOns then QFXAM.ScanAddOns() end
    if QFXAM.UI and QFXAM.UI.Refresh and QFXAM.UI.frame and QFXAM.UI.frame:IsShown() then
        QFXAM.UI.Refresh(QFXAM.ScanAddOns ~= nil)
    end
end

function QFXAM.RegisterOpenOptions(name, fn)
    if not name or type(fn) ~= "function" then return end
    local reg = QFXAM.Registry and QFXAM.Registry.Get and QFXAM.Registry.Get(name)
    if reg then
        reg.openOptions = fn
    elseif QFXAM.RegisterAddon then
        QFXAM.RegisterAddon(name, { openOptions = fn })
    end
end

QFXAM.API = QFXAM.API or {}

function QFXAM.API.GetManagerVersion()
    local v = QFXAM.API.GetAddOnMetadata(QFXAM.name, "Version")
    return v or "0"
end

function QFXAM.API.GetWidgets()
    if QFXAM.GetWidgets then
        return QFXAM.GetWidgets()
    end
    return rawget(_G, "QFXWidgets")
end

function QFXAM.API.IsWidgetsAvailable()
    local W = QFXAM.API.GetWidgets()
    return type(W) == "table" and type(W.DualRow) == "function"
end

-- Factory VERSION provided by us or the standalone addon (nil if none).
-- Consumer plugins gate factory-dependent features on this.
function QFXAM.API.GetWidgetsVersion()
    if QFXAM.Widgets and QFXAM.Widgets.GetVersion then
        return QFXAM.Widgets.GetVersion()
    end
    local W = QFXAM.API.GetWidgets()
    return W and tonumber(W.VERSION) or nil
end

-- Same singleton as embedded consumer copies; available before options open.
function QFXAM.API.GetGlow()
    return rawget(_G, "QFXGlow")
end

function QFXAM.API.IsGlowAvailable()
    local G = QFXAM.API.GetGlow()
    return type(G) == "table" and type(G.Start) == "function"
end

function QFXAM.API.GetGlowVersion()
    local G = QFXAM.API.GetGlow()
    return G and tonumber(G.VERSION) or nil
end

function QFXAM.API.RegisterModule(key, data)
    if QFXAM.RegisterModule then
        QFXAM.RegisterModule(key, data)
        RefreshAfterExternalChange()
    end
end

function QFXAM.API.RegisterGroup(key, data)
    if QFXAM.RegisterGroup then
        QFXAM.RegisterGroup(key, data)
        RefreshAfterExternalChange()
    end
end

function QFXAM.API.RegisterAddon(name, data)
    if QFXAM.RegisterAddon then
        QFXAM.RegisterAddon(name, data)
        RefreshAfterExternalChange()
    end
end

function QFXAM.API.RegisterOpenOptions(name, fn)
    QFXAM.RegisterOpenOptions(name, fn)
end

-- Stable global alias for external plugins (the root table is already
-- exposed as _G.QFXAddonManager from Core\DB.lua).
_G.QFXAddonManagerAPI = QFXAM.API
