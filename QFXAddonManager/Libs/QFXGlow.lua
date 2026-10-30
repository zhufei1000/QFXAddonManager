--[[
QFXGlow: embeddable shared glow renderer, independent of any UI suite.
Copy this file unchanged into a consumer and load it before runtime modules.
Consumers should declare OptionalDeps: QFXAddonManager.

  local G = ns.QFXGlow or _G.QFXGlow
  G:Start(icon, { key = "MyAddon.alert", style = "pixel", color = {1, .7, .1, 1} })
  G:Stop(icon, "MyAddon.alert")

All copies reuse one table and one runtime. The manager owns the provider role;
the highest implementation VERSION wins, including a newer embedded copy.
Scripts belong only to our own overlay frames. No foreign-frame fields/hooks,
SavedVariables, external library, EUI source, or addon media are required.
Hosts must be ordinary addon frames, outside restricted/secure aura trees.
]]
local addonName, ns = ...
local VERSION, STATE_SCHEMA = 1, 1
local G = rawget(_G, "QFXGlow")
if type(G) ~= "table" then G = {}; _G.QFXGlow = G end
if type(ns) == "table" then ns.QFXGlow = G end

-- Ownership and implementation revision are separate. Never downgrade a newer
-- renderer merely because the manager's copy loads last.
if addonName == "QFXAddonManager" then
    G.PROVIDER = addonName
    G.MANAGED = true
elseif not G.PROVIDER then
    G.PROVIDER = addonName or "embedded"
end
if (tonumber(G.VERSION) or 0) >= VERSION then return end
if G._runtime and G._runtime.schema ~= STATE_SCHEMA then return end

local floor, min, max, sin = math.floor, math.min, math.max, math.sin
local TAU = math.pi * 2
local R = G._runtime or {
    schema = STATE_SCHEMA,
    hosts = setmetatable({}, { __mode = "k" }),
    running = {}, index = {}, count = 0, requested = 0, elapsed = 0,
}
G._runtime = R

local WHITE = [[Interface\Buttons\WHITE8X8]]
local HALO = [[Interface\SpellActivationOverlay\IconAlert]]
local ANTS = [[Interface\SpellActivationOverlay\IconAlertAnts]]
local PROC_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"

local styles = {
    { id = "pixel", enUS = "Pixel Glow", zhCN = "像素跑马灯", zhTW = "像素跑馬燈" },
    { id = "border", enUS = "Pulse Border", zhCN = "脉冲边框", zhTW = "脈衝邊框" },
    { id = "button", enUS = "Button Halo", zhCN = "按钮光晕", zhTW = "按鈕光暈" },
    { id = "autocast", enUS = "Orbit Shine", zhCN = "施法闪光", zhTW = "施法閃光" },
    { id = "proc", enUS = "Modern Proc", zhCN = "现代触发发光", zhTW = "現代觸發發光" },
    { id = "classic", enUS = "Classic Proc", zhCN = "经典触发发光", zhTW = "經典觸發發光" },
    { id = "fill", enUS = "Color Fill", zhCN = "颜色覆盖", zhTW = "顏色覆蓋" },
}
local known = {}
for _, style in ipairs(styles) do known[style.id] = true end

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Number(value, fallback, low, high)
    if Secret(value) then return fallback end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return max(low, min(high, value))
end

local function Key(value)
    if Secret(value) then return nil end
    if value == nil then return "default" end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

local function Color(color)
    if Secret(color) or type(color) ~= "table" then color = {} end
    local out = {}
    for i, name in ipairs({ "r", "g", "b", "a" }) do
        local value = color[name]
        if not Secret(value) and value == nil then value = color[i] end
        out[i] = Number(value, ({ 1, .72, .12, 1 })[i], 0, 1)
    end
    return out
end

local function Flag(frame, name)
    if not frame[name] then return false end
    local value = frame[name](frame)
    -- Secrecy is a display limitation, never a source of gameplay decisions.
    return Secret(value) or value == true
end

local function HostAllowed(parent)
    if Secret(parent) then return false, "restricted-host" end
    local kind = type(parent)
    if (kind ~= "table" and kind ~= "userdata") or not parent.CreateTexture or not parent.GetWidth then
        return false, "invalid-host"
    end
    if Flag(parent, "IsForbidden") or Flag(parent, "IsProtected")
        or Flag(parent, "IsAnchoringRestricted") or Flag(parent, "IsAnchoringSecret") then
        return false, "restricted-host"
    end
    return true
end

local function Dimensions(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    if Secret(width) or Secret(height) then return nil end
    if type(width) ~= "number" or type(height) ~= "number"
        or width ~= width or height ~= height or width <= 0 or height <= 0
        or width == math.huge or height == math.huge then return nil end
    return width, height
end

local function Unregister(s)
    local index = R.index[s]
    if not index then return end
    local last = R.running[R.count]
    R.running[index] = last
    R.index[last] = index
    R.running[R.count] = nil
    R.index[s] = nil
    R.count = R.count - 1
    if R.count == 0 and R.driver then
        R.driver:SetScript("OnUpdate", nil)
        R.driver:Hide()
        R.elapsed = 0
    end
end

local function Register(s)
    if R.index[s] then return end
    R.count = R.count + 1
    R.running[R.count] = s
    R.index[s] = R.count
    if not R.driver then
        R.driver = CreateFrame("Frame")
        R.driver:Hide()
    end
    if R.count == 1 then
        R.elapsed = 0
        R.driver:SetScript("OnUpdate", function(_, elapsed) G._Tick(elapsed) end)
        R.driver:Show()
    end
end

local function Pause(s)
    Unregister(s)
    if s.group then s.group:Stop() end
end

local function Visible(frame)
    local visible = frame:IsVisible()
    return not Secret(visible) and visible == true
end

local function Resume(s)
    if not s.requested or not Visible(s.frame) or not s.width then return end
    if s.flipStyle and not s.options.static and not R.reducedMotion then
        s.group:Play()
    elseif s.luaStyle and not s.options.static and not R.reducedMotion then
        Register(s)
    end
end

local function Texture(s, index)
    local texture = s.textures[index]
    if not texture then
        texture = s.frame:CreateTexture(nil, "OVERLAY")
        s.textures[index] = texture
    end
    texture:Show()
    texture:SetTexture(WHITE)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetBlendMode("ADD")
    local c = s.options.color
    texture:SetVertexColor(c[1], c[2], c[3], c[4])
    texture:SetAlpha(1)
    return texture
end

local function Place(texture, frame, x, y, width, height)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    texture:SetSize(max(.01, width), max(.01, height))
end

local function Around(distance, width, height)
    local perimeter = 2 * (width + height)
    distance = distance % perimeter
    if distance < width then return distance, 0, 1, width - distance end
    distance = distance - width
    if distance < height then return width, distance, 2, height - distance end
    distance = distance - height
    if distance < width then return width - distance, height, 3, width - distance end
    distance = distance - width
    return 0, height - distance, 4, height - distance
end

local function DrawPixel(s)
    local o, w, h = s.options, s.width, s.height
    local perimeter = 2 * (w + h)
    local spacing = perimeter / o.lines
    local length = min(o.length or spacing * .4, spacing * .8, w, h)
    local thickness = min(o.thickness, w, h)
    for i = 1, o.lines do
        local x, y, side, remaining = Around(s.phase * perimeter + (i - 1) * spacing, w, h)
        local segment = min(length, remaining)
        local texture = s.textures[i]
        if side == 1 then Place(texture, s.frame, x, 0, segment, thickness)
        elseif side == 2 then Place(texture, s.frame, w - thickness, y, thickness, segment)
        elseif side == 3 then Place(texture, s.frame, x - segment, h - thickness, segment, thickness)
        else Place(texture, s.frame, 0, y - segment, thickness, segment) end
    end
end

local function DrawOrbit(s)
    local o, w, h = s.options, s.width, s.height
    local size = min(o.sparkSize, w, h)
    local perimeter = 2 * (w + h)
    for i = 1, o.lines do
        local x, y = Around((s.phase + (i - 1) / o.lines) * perimeter, w, h)
        Place(s.textures[i], s.frame, x - size / 2, y - size / 2, size, size)
        s.textures[i]:SetAlpha(.6 + .4 * sin(s.phase * TAU + i)^2)
    end
end

local function DrawPulse(s)
    local alpha = .45 + .55 * (.5 + .5 * sin(s.phase * TAU))
    for _, texture in ipairs(s.textures) do texture:SetAlpha(alpha) end
end

function G._Tick(elapsed)
    R.elapsed = R.elapsed + elapsed
    if R.elapsed < 1 / 30 then return end
    local dt = R.elapsed
    R.elapsed = 0
    local i = 1
    while i <= R.count do
        local s = R.running[i]
        s.phase = (s.phase + dt * s.options.speed / s.options.period) % 1
        if s.options.style == "pixel" then DrawPixel(s)
        elseif s.options.style == "autocast" then DrawOrbit(s)
        else DrawPulse(s) end
        i = i + 1
    end
end

local function ProcAvailable()
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(PROC_ATLAS) ~= nil
end

local function FlipBook(s, texture, modern)
    if not s.group then
        s.group = texture:CreateAnimationGroup()
        s.group:SetLooping("REPEAT")
        s.flip = s.group:CreateAnimation("FlipBook")
        s.flip:SetOrder(1)
    end
    s.flip:SetFlipBookRows(modern and 6 or 5)
    s.flip:SetFlipBookColumns(5)
    s.flip:SetFlipBookFrames(modern and 30 or 22)
    s.flip:SetFlipBookFrameWidth(0)
    s.flip:SetFlipBookFrameHeight(0)
    s.flip:SetDuration(s.options.period / s.options.speed)
    -- Animated FlipBooks use the whole sheet (or the atlas UV rectangle).
    -- A paused preview explicitly selects the first cell instead.
    if s.options.static or R.reducedMotion then
        if modern then
            local info = C_Texture.GetAtlasInfo(PROC_ATLAS)
            local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
            texture:SetTexCoord(left, left + (right - left) / 5, top, top + (bottom - top) / 6)
        else
            texture:SetTexCoord(0, 1 / 5, 0, 1 / 5)
        end
    end
end

local function Render(s)
    Pause(s)
    for _, texture in ipairs(s.textures) do texture:Hide() end
    s.luaStyle, s.flipStyle = false, false
    local w, h = Dimensions(s.frame)
    s.width, s.height = w, h
    if not w then return false, "restricted-size" end
    local o, style = s.options, s.options.style
    if style == "pixel" or style == "autocast" then
        for i = 1, o.lines do
            local texture = Texture(s, i)
            if style == "autocast" then
                texture:SetTexture([[Interface\Artifacts\Artifacts]])
                texture:SetTexCoord(.8115234375, .9169921875, .8798828125, .9853515625)
            end
        end
        if style == "pixel" then DrawPixel(s) else DrawOrbit(s) end
        s.luaStyle = true
    elseif style == "border" then
        local thickness = min(o.thickness, w / 2, h / 2)
        Place(Texture(s, 1), s.frame, 0, 0, w, thickness)
        Place(Texture(s, 2), s.frame, w - thickness, thickness, thickness, h - 2 * thickness)
        Place(Texture(s, 3), s.frame, 0, h - thickness, w, thickness)
        Place(Texture(s, 4), s.frame, 0, thickness, thickness, h - 2 * thickness)
        s.luaStyle = true
    elseif style == "fill" then
        local texture = Texture(s, 1)
        texture:SetBlendMode("BLEND")
        Place(texture, s.frame, 0, 0, w, h)
    elseif style == "button" then
        local texture = Texture(s, 1)
        texture:SetTexture(HALO)
        texture:SetTexCoord(.0078125, .5078125, .27734375, .52734375)
        Place(texture, s.frame, -w * .2, -h * .2, w * 1.4, h * 1.4)
        s.luaStyle = true
    else
        local texture = Texture(s, 1)
        local modern = style == "proc" and ProcAvailable()
        s.renderedStyle = modern and "proc" or "classic"
        if modern then texture:SetAtlas(PROC_ATLAS) else texture:SetTexture(ANTS) end
        local padding = modern and .2 or .125
        Place(texture, s.frame, -w * padding, -h * padding, w * (1 + 2 * padding), h * (1 + 2 * padding))
        FlipBook(s, texture, modern)
        s.flipStyle = true
    end
    if not s.flipStyle then s.renderedStyle = style end
    if (style == "border" or style == "button") and not o.static and not R.reducedMotion then
        DrawPulse(s)
    end
    Resume(s)
    return true
end
G._Render = Render
G._Resume = Resume
G._Pause = Pause

local function Options(input)
    local style = input.style
    if Secret(style) then return nil, "invalid-style" end
    if style == nil then style = "pixel" end
    if not known[style] then return nil, "invalid-style" end
    if Secret(input.static) or Secret(input.host) then return nil, "restricted-options" end
    if input.host ~= nil and input.host ~= "addon" then return nil, "restricted-host" end
    local key = Key(input.key)
    if not key then return nil, "invalid-key" end
    local length = input.length
    if Secret(length) then return nil, "restricted-options" end
    return {
        key = key, style = style, color = Color(input.color), static = input.static == true,
        lines = floor(Number(input.lines, style == "autocast" and 6 or 8, 1, 32)),
        thickness = Number(input.thickness, 2, .5, 16),
        length = length ~= nil and Number(length, 8, 1, 256) or nil,
        sparkSize = Number(input.sparkSize, 10, 2, 64),
        speed = Number(input.speed, 1, .1, 5),
        period = Number(input.period, style == "classic" and .35 or 1, .1, 10),
        padding = Number(input.padding, 2, -32, 64),
        frameLevel = floor(Number(input.frameLevel, 5, 0, 100)),
    }
end

function G:Start(parent, input)
    if Secret(input) then return nil, "restricted-options" end
    if input ~= nil and type(input) ~= "table" then return nil, "invalid-options" end
    local o, reason = Options(input or {})
    if not o then return nil, reason end
    local allowed
    allowed, reason = HostAllowed(parent)
    if not allowed then return nil, reason end
    if not Dimensions(parent) then return nil, "restricted-size" end
    local slots = R.hosts[parent]
    if not slots then slots = {}; R.hosts[parent] = slots end
    local s = slots[o.key]
    if not s then
        local frame = CreateFrame("Frame", nil, parent)
        frame:Hide()
        frame:EnableMouse(false)
        s = { frame = frame, textures = {}, phase = 0 }
        slots[o.key] = s
        frame:SetScript("OnShow", function() G._Resume(s) end)
        frame:SetScript("OnHide", function() G._Pause(s) end)
        frame:SetScript("OnSizeChanged", function()
            if s.requested then G._Render(s) end
        end)
    end
    Pause(s)
    if not s.requested then R.requested = R.requested + 1 end
    s.requested, s.options = true, o
    s.frame:ClearAllPoints()
    s.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", -o.padding, o.padding)
    s.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", o.padding, -o.padding)
    local level = parent:GetFrameLevel()
    if not Secret(level) then s.frame:SetFrameLevel(level + o.frameLevel) end
    local ok
    ok, reason = Render(s)
    if not ok then self:Stop(parent, o.key); return nil, reason end
    s.frame:Show()
    Resume(s)
    return s.frame
end

function G:Stop(parent, key)
    key = Key(key)
    if not key or Secret(parent) then return false end
    local slots = R.hosts[parent]
    local s = slots and slots[key]
    if not s or not s.requested then return false end
    s.requested = false
    R.requested = R.requested - 1
    Pause(s)
    s.frame:Hide()
    return true
end

function G:StopAll(parent)
    if Secret(parent) then return end
    local slots = R.hosts[parent]
    if not slots then return end
    for key in pairs(slots) do self:Stop(parent, key) end
end

function G:IsActive(parent, key)
    key = Key(key)
    if not key or Secret(parent) then return false end
    local slots = R.hosts[parent]
    return slots and slots[key] and slots[key].requested == true or false
end

function G:SetColor(parent, key, color)
    key = Key(key)
    if not key or Secret(parent) then return false end
    local slots = R.hosts[parent]
    local s = slots and slots[key]
    if not s or not s.options then return false end
    s.options.color = Color(color)
    local c = s.options.color
    for _, texture in ipairs(s.textures) do texture:SetVertexColor(c[1], c[2], c[3], c[4]) end
    return true
end

function G:SetReducedMotion(value)
    if Secret(value) then return end
    R.reducedMotion = value == true
    for _, slots in pairs(R.hosts) do
        for _, s in pairs(slots) do if s.requested then Render(s) end end
    end
end

function G:GetStyles(locale)
    if Secret(locale) then locale = nil end
    locale = locale or (GetLocale and GetLocale()) or "enUS"
    local list = {}
    for _, style in ipairs(styles) do
        list[#list + 1] = { id = style.id, name = style[locale] or style.enUS }
    end
    return list
end

function G:GetStatus()
    return {
        version = self.VERSION, provider = self.PROVIDER, managed = self.MANAGED == true,
        implementation = self.IMPLEMENTATION, requested = R.requested, ticking = R.count,
        reducedMotion = R.reducedMotion == true,
    }
end

function G:GetRenderedStyle(parent, key)
    key = Key(key)
    if not key or Secret(parent) then return nil end
    local slots = R.hosts[parent]
    local s = slots and slots[key]
    return s and s.requested and s.renderedStyle or nil
end

G.VERSION = VERSION
G.IMPLEMENTATION = addonName or "embedded"
-- Refresh existing overlays after an additive implementation upgrade. Their
-- frames, key ownership, singleton references and phase all stay intact.
for _, slots in pairs(R.hosts) do
    for _, s in pairs(slots) do if s.requested then Render(s) end end
end
