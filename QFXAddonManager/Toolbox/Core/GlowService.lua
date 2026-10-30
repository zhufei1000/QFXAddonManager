local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local Service = ns.GlowService or {}
ns.GlowService = Service

local LCG
local warningPrinted = false
local backends = setmetatable({}, { __mode = "k" })
local preparedOptions = setmetatable({}, { __mode = "k" })
local procOptionsCache = setmetatable({}, { __mode = "k" })

local function SharedGlow()
    local G = rawget(_G, "QFXGlow")
    return type(G) == "table" and type(G.Start) == "function" and G or nil
end

local DEFAULT_COLOR = {
    r = 1,
    g = 0.08,
    b = 0.02,
    a = 1,
}

local BASE_FREQUENCY = 0.25

local STRONG_PROFILE = {
    lines = 8,
    baseFrequency = BASE_FREQUENCY,
    length = nil,
    thickness = 3,
    xOffset = 0,
    yOffset = 0,
    border = true,
}

local function ResolveLibrary(allowLoad)
    if LCG then
        return LCG
    end

    local libStub = _G.LibStub
    if libStub then
        local ok, library = pcall(libStub, "LibCustomGlow-1.0", true)
        if ok and library then
            LCG = library
            return LCG
        end
    end

    LCG = _G["LibCustomGlow-1.0"]
    if not LCG and allowLoad ~= false and ns.Compat and ns.Compat.LoadAddOn then
        if ns.Compat.LoadAddOn("QFXAddonManager_Libraries_GlowFallback") and libStub then
            local ok, library = pcall(libStub, "LibCustomGlow-1.0", true)
            if ok then LCG = library end
        end
    end
    return LCG
end

local function WarnUnavailable()
    if warningPrinted then return end
    warningPrinted = true
    local message = "QFX ToolBox: LibCustomGlow-1.0 is unavailable; glow effects are disabled."
    if ns.Print then
        ns.Print(message)
    elseif print then
        print(message)
    end
end

function Service:IsAvailable()
    if SharedGlow() then return true end
    local lib = ResolveLibrary()
    local available = type(lib) == "table"
        and type(lib.PixelGlow_Start) == "function"
        and type(lib.PixelGlow_Stop) == "function"
    if not available then WarnUnavailable() end
    return available
end

function Service:NormalizeColor(color, fallback)
    fallback = type(fallback) == "table" and fallback or DEFAULT_COLOR
    color = type(color) == "table" and color or fallback

    local r = tonumber(color.r or color[1]) or fallback.r or fallback[1] or 1
    local g = tonumber(color.g or color[2]) or fallback.g or fallback[2] or 1
    local b = tonumber(color.b or color[3]) or fallback.b or fallback[3] or 1
    local a = tonumber(color.a or color[4]) or fallback.a or fallback[4] or 1

    r = math.max(0, math.min(1, r))
    g = math.max(0, math.min(1, g))
    b = math.max(0, math.min(1, b))
    a = math.max(0, math.min(1, a))

    return {
        r = r,
        g = g,
        b = b,
        a = a,
        [1] = r,
        [2] = g,
        [3] = b,
        [4] = a,
    }
end

function Service:NormalizeSpeed(speed)
    speed = tonumber(speed) or 1
    return math.max(0.5, math.min(3.0, speed))
end

function Service:SpeedToFrequency(speed)
    return BASE_FREQUENCY * self:NormalizeSpeed(speed)
end

-------------------------------------------------------------------------------
--  Style dispatch
--  "pixel"    LibCustomGlow Pixel Glow  - Lua OnUpdate ticks; freezes into a
--             static artifact while 12.x restricted (secret-value) execution
--             is active on Blizzard surfaces.
--  "proc"     LibCustomGlow Proc Glow   - C-side FlipBook AnimationGroup
--             (Blizzard action-button proc loop); keeps animating under the
--             same restrictions. Used as the automatic fallback.
--  "autocast" LibCustomGlow Auto-Cast Shine (orbiting sparkles, Lua ticks).
--  "button"   LibCustomGlow Action Button Glow (soft halo, AnimationGroup);
--             supports one glow per frame (key is ignored by the library).
--  "auto"     resolves to "proc" on 12.x restricted clients, "pixel" otherwise.
-------------------------------------------------------------------------------
local STYLE_PIXEL = "pixel"
local STYLE_PROC = "proc"
local STYLE_AUTOCAST = "autocast"
local STYLE_BUTTON = "button"

local KNOWN_STYLES = {
    [STYLE_PIXEL] = true,
    [STYLE_PROC] = true,
    [STYLE_AUTOCAST] = true,
    [STYLE_BUTTON] = true,
}

Service.STYLE_AUTO = "auto"
Service.STYLES = { "auto", STYLE_PIXEL, STYLE_PROC, STYLE_AUTOCAST, STYLE_BUTTON }

local restrictedClient = nil

-- True when the client ships the 12.x secret-value restriction system, where
-- Lua-ticked glows attached to restricted surfaces can stop ticking.
function Service:IsRestrictedClient()
    if restrictedClient == nil then
        restrictedClient = false
        if _G.issecretvalue then
            local compat = ns.Compat
            if compat and type(compat.IsRetail12x) == "function" then
                local ok, is12x = pcall(compat.IsRetail12x)
                restrictedClient = (ok and is12x == true) or false
            else
                restrictedClient = true
            end
        end
    end
    return restrictedClient
end

-- Clamp an arbitrary stored value to a known style key ("auto" default).
function Service:NormalizeStyle(style)
    if style == nil then
        return Service.STYLE_AUTO
    end
    style = tostring(style):lower()
    if style == Service.STYLE_AUTO or KNOWN_STYLES[style] then
        return style
    end
    return Service.STYLE_AUTO
end

-- Resolve "auto" (or nil) against the client's restriction profile.
function Service:ResolveStyle(style)
    style = self:NormalizeStyle(style)
    if style == Service.STYLE_AUTO then
        if self:IsRestrictedClient() then
            return STYLE_PROC
        end
        return STYLE_PIXEL
    end
    return style
end

-- Mutable options must be prepared again after a settings change. Ordinary
-- callers retain the validating path; hot event callers can reuse a snapshot.
function Service:PrepareGlowOptions(options)
    options.color = self:NormalizeColor(options.color)
    options.speed = self:NormalizeSpeed(options.speed)
    options.style = self:ResolveStyle(options.style)
    preparedOptions[options] = true
    procOptionsCache[options] = nil
    return options
end

local function StartPixelGlowOn(lib, target, key, options, color, speed, frequency, lines, xOffset, yOffset, frameLevel)
    local length = options.length
    local thickness = tonumber(options.thickness) or STRONG_PROFILE.thickness
    local border
    if options.border == nil then
        border = STRONG_PROFILE.border
    else
        border = options.border == true
    end

    local ok = pcall(
        lib.PixelGlow_Start,
        target,
        color,
        lines,
        frequency,
        length,
        thickness,
        xOffset,
        yOffset,
        border,
        key,
        frameLevel
    )
    return ok == true
end

local function StartProcGlowOn(lib, target, key, options, color, speed, frameLevel)
    if type(lib.ProcGlow_Start) ~= "function" then
        return false
    end

    local procOptions = preparedOptions[options] and procOptionsCache[options]
    if not procOptions or procOptions.key ~= key then
        procOptions = {
            color = color,
            duration = 1.0 / speed,
            key = key,
            xOffset = tonumber(options.xOffset) or 0,
            yOffset = tonumber(options.yOffset) or 0,
            startAnim = options.startAnim ~= false,
        }
        if preparedOptions[options] then procOptionsCache[options] = procOptions end
    end
    if frameLevel then
        procOptions.frameLevel = frameLevel
    end

    local ok = pcall(lib.ProcGlow_Start, target, procOptions)
    return ok == true
end

local function StartAutoCastGlowOn(lib, target, key, color, speed, frequency, lines, xOffset, yOffset, frameLevel)
    if type(lib.AutoCastGlow_Start) ~= "function" then
        return false
    end

    local ok = pcall(
        lib.AutoCastGlow_Start,
        target,
        color,
        lines,
        frequency,
        1.0,
        xOffset,
        yOffset,
        key,
        frameLevel
    )
    return ok == true
end

local function StartButtonGlowOn(lib, target, color, speed, frequency, frameLevel)
    if type(lib.ButtonGlow_Start) ~= "function" then
        return false
    end

    local ok = pcall(lib.ButtonGlow_Start, target, color, frequency, frameLevel)
    return ok == true
end

-- Start a glow with the requested style (options.style; "auto" default).
function Service:StartGlow(target, key, options)
    if not target or type(key) ~= "string" or key == "" then
        return false
    end

    options = type(options) == "table" and options or {}

    local prepared = preparedOptions[options]
    local style = prepared and options.style or self:ResolveStyle(options.style)
    local color = prepared and options.color or self:NormalizeColor(options.color)
    local speed = prepared and options.speed or self:NormalizeSpeed(options.speed)
    local frequency = (tonumber(options.baseFrequency) or STRONG_PROFILE.baseFrequency) * speed
    local lines = tonumber(options.lines) or STRONG_PROFILE.lines
    local xOffset = tonumber(options.xOffset) or STRONG_PROFILE.xOffset
    local yOffset = tonumber(options.yOffset) or STRONG_PROFILE.yOffset
    local frameLevel = tonumber(options.frameLevel)

    local G = SharedGlow()
    local oldBackend = backends[target] and backends[target][key]
    if G and xOffset == yOffset and not frameLevel then
        local W = rawget(_G, "QFXWidgets")
        local overlay = G:Start(target, {
            key = "QFXToolBox." .. key, style = style, color = color,
            lines = lines, length = options.length, thickness = options.thickness or STRONG_PROFILE.thickness,
            padding = xOffset, period = style == STYLE_PROC and (1 / speed) or frequency * 4,
            static = W and W.MotionAllowed and not W:MotionAllowed() or false,
        })
        if overlay then
            if oldBackend == "legacy" then
                -- Clear the old library overlays without stopping the new shared glow.
                local legacy = ResolveLibrary()
                if legacy then
                    for _, name in ipairs({ "PixelGlow_Stop", "ProcGlow_Stop", "AutoCastGlow_Stop" }) do
                        if legacy[name] then pcall(legacy[name], target, key) end
                    end
                    if legacy.ButtonGlow_Stop then pcall(legacy.ButtonGlow_Stop, target) end
                end
            end
            backends[target] = backends[target] or {}
            backends[target][key] = "shared"
            return true
        end
    end
    -- Secure/restricted hosts and asymmetric offsets retain the existing backend.
    if oldBackend == "shared" and G then G:Stop(target, "QFXToolBox." .. key) end
    local lib = ResolveLibrary()
    if not lib or type(lib.PixelGlow_Start) ~= "function" then WarnUnavailable(); return false end
    backends[target] = backends[target] or {}
    backends[target][key] = "legacy"

    if style == STYLE_PROC then
        return StartProcGlowOn(lib, target, key, options, color, speed, frameLevel)
    elseif style == STYLE_AUTOCAST then
        return StartAutoCastGlowOn(lib, target, key, color, speed, frequency, lines, xOffset, yOffset, frameLevel)
    elseif style == STYLE_BUTTON then
        return StartButtonGlowOn(lib, target, color, speed, frequency, frameLevel)
    end

    return StartPixelGlowOn(lib, target, key, options, color, speed, frequency, lines, xOffset, yOffset, frameLevel)
end

-- Stop every engine that could own this glow. All stops are keyed no-ops for
-- engines that do not hold a matching glow, so calling all four is the only
-- leak-proof way to stop a glow whose style may have changed since it started.
-- Known library limitation: ButtonGlow holds a single glow per frame (keyless).
function Service:StopGlow(target, key)
    if not target or type(key) ~= "string" or key == "" then
        return
    end

    local G = SharedGlow()
    if G then G:Stop(target, "QFXToolBox." .. key) end
    if backends[target] then backends[target][key] = nil end
    local lib = ResolveLibrary(false)
    if not lib then return end

    if type(lib.PixelGlow_Stop) == "function" then
        pcall(lib.PixelGlow_Stop, target, key)
    end
    if type(lib.ProcGlow_Stop) == "function" then
        pcall(lib.ProcGlow_Stop, target, key)
    end
    if type(lib.AutoCastGlow_Stop) == "function" then
        pcall(lib.AutoCastGlow_Stop, target, key)
    end
    if type(lib.ButtonGlow_Stop) == "function" then
        pcall(lib.ButtonGlow_Stop, target)
    end
end

function Service:RestartGlow(target, key, options)
    self:StopGlow(target, key)
    return self:StartGlow(target, key, options)
end

-- Legacy aliases kept for existing callers; both honor options.style.
Service.StartPixelGlow = Service.StartGlow
Service.StopPixelGlow = Service.StopGlow
Service.RestartPixelGlow = Service.RestartGlow

end)
