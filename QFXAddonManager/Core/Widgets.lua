local _, QFXAM = ...

-- QFXWidgets factory bootstrap (suite foundation).
-- This addon IS a factory provider, exactly like the standalone QFXWidgets
-- addon: the verbatim factory copy ships in the load-on-demand companion
-- (QFXAddonManager_Config\Libs\QFXWidgets.lua) and installs the version-guarded
-- singleton _G.QFXWidgets the first time the manager window or a settings page
-- is opened. Any consumer plugin that declares ## OptionalDeps: QFXAddonManager
-- (or loads after us) resolves the very same table via rawget(_G, "QFXWidgets")
-- once that copy is loaded -- no second copy, no duplicate frames. When the
-- standalone QFXWidgets addon is installed and newer, our embedded copy reuses
-- it instead; when only we are installed, consumers get ours. Either way there
-- is exactly one factory.
-- Plain reads here stay side-effect free; QFXAM.EnsureConfigLoaded() is the
-- explicit load gate for the companion addon.
-- NOTE: keep ## X-QFX-Provides-Widgets in the .toc in sync with the embedded
-- copy's VERSION whenever Libs\QFXWidgets.lua is replaced wholesale.
QFXAM.Widgets = QFXAM.Widgets or {}

local function ResolveWidgets()
    local W = rawget(_G, "QFXWidgets") or (QFXAM and QFXAM.QFXWidgets)
    if type(W) == "table" and type(W.DualRow) == "function" then
        if type(W.EnsureAddonToggle) == "function" then W:EnsureAddonToggle() end
        return W
    end
    return nil
end

function QFXAM.GetWidgets()
    return ResolveWidgets()
end

function QFXAM.Widgets.Ensure()
    return ResolveWidgets()
end

function QFXAM.Widgets.IsAvailable()
    return ResolveWidgets() ~= nil
end

-- Winning factory copy's VERSION (nil when no provider is loaded).
-- Consumers use it to gate on factory features, same as with standalone.
function QFXAM.Widgets.GetVersion()
    local W = ResolveWidgets()
    return W and tonumber(W.VERSION) or nil
end

-- The provider ships its own media so a disabled/absent standalone library
-- cannot change the appearance of controls built by the shared singleton.
local brandedFactory
function QFXAM.Widgets.ApplyBrand()
    local W = ResolveWidgets()
    if not W or brandedFactory == W then return end
    local root = [[Interface\AddOns\QFXAddonManager\Media\]]
    W:SetCircleTexture(root .. "circle-crisp.blp")
    W:SetPillTexture(root .. "pill-crisp.blp")
    W:SetSliderThumbTexture(root .. "slider-thumb-crisp.blp")
    W:SetArrowTexture(root .. "dropdown-chevron.blp")
    W:SetCloseTexture(root .. "close-x.blp")
    W:SetAddonPowerTexture(root .. "addon-power.blp")
    W:SetDefaultAddonIcon(root .. "addon-fei.blp")
    W:SetBrand({
        logo = root .. "brand-extension-emblem.blp",
        logoRatio = 2,
        -- A consumer's project title is local to its window, not factory branding.
        nameplate = false,
        nameplateRatio = false,
        nameplateTexCoord = false,
        watermark = root .. "brand-watermark-v3.blp",
        watermarkRatio = 16,
        watermarkTint = { 1, 1, 1, 0.78 },
        sheenMask = root .. "brand-sheen-mask.blp",
        contactRoot = root,
    })
    brandedFactory = W
end
