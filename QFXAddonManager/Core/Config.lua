local _, QFXAM = ...
local API = QFXAM.API
local L = QFXAM.L

-- The manager window, the settings host, and the shared widget factory ship
-- in a load-on-demand companion addon (QFXAddonManager_Config). The core
-- addon keeps its startup path lean; every user entry (slash command, minimap
-- button, options panel, external API) pulls the companion in through this
-- gate first. Plain reads stay side-effect free: QFXAM.UI and _G.QFXWidgets
-- remain nil until something actually needs them.
QFXAM.configAddonName = "QFXAddonManager_Config"

function QFXAM.IsConfigLoaded()
    return API.IsAddOnLoaded(QFXAM.configAddonName) == true
end

function QFXAM.EnsureConfigLoaded()
    if QFXAM.IsConfigLoaded() then return true end
    if QFXAM.__configLoading then return false end
    QFXAM.__configLoading = true
    local ok, reason = API.LoadAddOn(QFXAM.configAddonName)
    QFXAM.__configLoading = nil
    if ok == true or QFXAM.IsConfigLoaded() then return true end
    QFXAM.Print((L.CONFIG_LOAD_FAILED or "The settings module failed to load.") ..
        " (" .. tostring(QFXAM.configAddonName) ..
        (reason and (": " .. tostring(reason)) or "") .. ")")
    return false
end

-- The adapters share the Config package; readiness is separate from the
-- client's loading/loaded flag so callers never observe partial registration.
QFXAM.adaptersAddonName = QFXAM.configAddonName

function QFXAM.IsAdaptersLoaded()
    return QFXAM.adaptersReady == true
end

function QFXAM.EnsureAdaptersLoaded()
    if QFXAM.IsAdaptersLoaded() then return true end
    if not QFXAM.EnsureConfigLoaded() then return false end
    return QFXAM.IsAdaptersLoaded()
end

function QFXAM.OpenUI()
    if not QFXAM.EnsureConfigLoaded() then return false end
    QFXAM.EnsureAdaptersLoaded()
    if QFXAM.UI and QFXAM.UI.Show then
        QFXAM.UI.Show()
        return true
    end
    return false
end

function QFXAM.ToggleUI()
    if not QFXAM.EnsureConfigLoaded() then return false end
    QFXAM.EnsureAdaptersLoaded()
    if QFXAM.UI and QFXAM.UI.Toggle then
        QFXAM.UI.Toggle()
        return true
    end
    return false
end

-- Compatibility entry point: dictionaries now load directly from the main TOC
-- after the toolbox core. No retired locale companion is ever requested.
function QFXAM.LoadLocaleAddon()
    local ns = QFXAM.ToolboxRuntime and QFXAM.ToolboxRuntime.ns
    local locale = ns and ns.GetResolvedLocale and ns.GetResolvedLocale()
    return ns ~= nil and ns.LOCALES ~= nil and ns.LOCALES[locale] ~= nil
end
