local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local _, ns = ...
ns = _G.QFXAddonManagerToolboxNS or ns

-- 玩家死亡播报（寄生在 QFXToolBox_Optional 内，不单独建子插件）。
--
-- 行为：
--   * PLAYER_DEAD      -> 播共享/自定义语音 + 显示中央大图（两者各有独立开关，可单开）
--   * PLAYER_ALIVE     -> 释放成灵魂时：默认隐藏；勾选“灵魂状态继续显示”则保留到复活
--   * PLAYER_UNGHOST   -> 真复活，隐藏大图
--   * PLAYER_ENTERING_WORLD -> 若进世界时已死亡只补显示大图（不补播语音，避免登录刷屏）
--
-- 语音：voiceSource = "shared" 走内置+LibSharedMedia-3.0 声音列表；
--       voiceSource = "custom" 走文件路径（PlaySoundFile）。
-- 图片：imageSource = "shared" 走内置+LSM background/border；
--       imageSource = "custom" 走文件路径（Texture:SetTexture）。
-- 失败回退：声音解析/播放失败时用客户端朗读兜底。

local KEY = "player_death_alert"

-- 语音/图片解析与播放统一走包内 SharedAudio（ns.OptionalAudio）。
local Audio = ns.OptionalAudio or {}

local DEFAULT_VOICE_SHARED = "builtin:raid_warning"
local DEFAULT_IMAGE_SHARED = "builtin:skull"
local DEFAULT_IMAGE_SIZE = 256
local DEFAULT_IMAGE_ALPHA = 0.9
local DEFAULT_IMAGE_STRATA = "BACKGROUND"

-- 可选层级从低到高排列，默认最低。
local STRATA_ORDER = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",
}

local VALID_STRATA = {}
for _, strata in ipairs(STRATA_ORDER) do
    VALID_STRATA[strata] = true
end

local function NormalizeStrata(value)
    if type(value) == "string" and VALID_STRATA[value] then
        return value
    end
    return DEFAULT_IMAGE_STRATA
end

local function L(key)
    return ns.L and ns.L(key) or key
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local function Trim(value)
    if ns.Util and ns.Util.Trim then return ns.Util.Trim(value) end
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function ClampNumber(value, fallback, minValue, maxValue)
    if ns.Compat and ns.Compat.SafeNumber then
        value = ns.Compat.SafeNumber(value, nil)
    else
        value = tonumber(value)
    end
    if value == nil then value = fallback end
    if minValue and value < minValue then value = minValue end
    if maxValue and value > maxValue then value = maxValue end
    return value
end

local function EnsureDB(db)
    db = (type(db) == "table" and db) or (ns.GetModuleDB and ns.GetModuleDB(KEY)) or {}
    if db.voiceEnabled == nil then db.voiceEnabled = true end
    if db.voiceSource ~= "shared" and db.voiceSource ~= "custom" then
        db.voiceSource = "shared"
    end
    if type(db.voiceShared) ~= "string" or db.voiceShared == "" then
        db.voiceShared = DEFAULT_VOICE_SHARED
    end
    if type(db.voiceCustomPath) ~= "string" then db.voiceCustomPath = "" end
    if db.imageEnabled == nil then db.imageEnabled = true end
    if db.imageSource ~= "shared" and db.imageSource ~= "custom" then
        db.imageSource = "shared"
    end
    if type(db.imageShared) ~= "string" or db.imageShared == "" then
        db.imageShared = DEFAULT_IMAGE_SHARED
    end
    if type(db.imageCustomPath) ~= "string" then db.imageCustomPath = "" end
    db.imageSize = ClampNumber(db.imageSize, DEFAULT_IMAGE_SIZE, 64, 512)
    db.imageAlpha = ClampNumber(db.imageAlpha, DEFAULT_IMAGE_ALPHA, 0.1, 1)
    db.imageX = ClampNumber(db.imageX, 0, -800, 800)
    db.imageY = ClampNumber(db.imageY, 0, -600, 600)
    db.imageStrata = NormalizeStrata(db.imageStrata)
    if db.imageLocked == nil then db.imageLocked = true end
    if db.keepInGhost == nil then db.keepInGhost = false end
    db.voiceEnabled = db.voiceEnabled and true or false
    db.imageEnabled = db.imageEnabled and true or false
    db.imageLocked = db.imageLocked and true or false
    db.keepInGhost = db.keepInGhost and true or false
    return db
end

-- ---------------------------------------------------------------------------
-- 共享库与路径解析（实现见 SharedAudio）
-- ---------------------------------------------------------------------------

local function ResolveVoicePath(db)
    db = EnsureDB(db)
    if db.voiceSource == "custom" then
        local path = Trim(db.voiceCustomPath)
        if path ~= "" then return path end
        return nil
    end
    if Audio.ResolveSoundPath then
        return Audio.ResolveSoundPath(db.voiceShared)
    end
    return nil
end

local function ResolveDeathImagePath(db)
    db = EnsureDB(db)
    if db.imageSource == "custom" then
        local path = Trim(db.imageCustomPath)
        if path ~= "" then return path end
        return nil
    end
    local skull = Audio.BUILTIN_IMAGES and Audio.BUILTIN_IMAGES.skull
    if Audio.ResolveImagePath then
        return Audio.ResolveImagePath(db.imageShared) or skull
    end
    return skull
end

-- ---------------------------------------------------------------------------
-- 语音播放（失败回退客户端朗读）
-- ---------------------------------------------------------------------------

local function PlayDeathVoice(db, playVoice)
    db = EnsureDB(db)
    if not db.voiceEnabled then return false end
    if playVoice == false then return false end
    if Audio.PlaySoundPath and Audio.PlaySoundPath(ResolveVoicePath(db)) then
        return true
    end
    if Audio.SpeakText then
        return Audio.SpeakText(L("You are dead"))
    end
    return false
end

-- ---------------------------------------------------------------------------
-- 中央大图
-- ---------------------------------------------------------------------------

local deathFrame
local deathTexture
local HideDeathImage

local function ApplyDeathFrameSettings(db)
    db = EnsureDB(db)
    if not deathFrame then return end
    local size = ClampNumber(db.imageSize, DEFAULT_IMAGE_SIZE, 64, 512)
    local alpha = ClampNumber(db.imageAlpha, DEFAULT_IMAGE_ALPHA, 0.1, 1)
    deathFrame:SetSize(size, size)
    deathFrame:ClearAllPoints()
    deathFrame:SetPoint("CENTER", UIParent, "CENTER",
        ClampNumber(db.imageX, 0, -800, 800),
        ClampNumber(db.imageY, 0, -600, 600))
    if deathFrame.SetFrameStrata then
        pcall(deathFrame.SetFrameStrata, deathFrame, NormalizeStrata(db.imageStrata))
    end
    deathFrame:EnableMouse(not db.imageLocked)
    if deathTexture then
        deathTexture:SetAlpha(alpha)
    end
end

local function CreateDeathFrame()
    if deathFrame then return deathFrame end
    deathFrame = CreateFrame("Frame", "QFXPlayerDeathAlertFrame", UIParent)
    deathFrame:SetSize(DEFAULT_IMAGE_SIZE, DEFAULT_IMAGE_SIZE)
    deathFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if deathFrame.SetFrameStrata then
        pcall(deathFrame.SetFrameStrata, deathFrame, DEFAULT_IMAGE_STRATA)
    end
    deathFrame:SetClampedToScreen(true)
    deathFrame:SetMovable(true)
    deathFrame:EnableMouse(false)
    deathFrame:RegisterForDrag("LeftButton")
    deathFrame:Hide()

    deathTexture = deathFrame:CreateTexture(nil, "ARTWORK")
    deathTexture:SetAllPoints(deathFrame)
    deathTexture:SetTexture(Audio.BUILTIN_IMAGES and Audio.BUILTIN_IMAGES.skull)
    deathTexture:SetAlpha(DEFAULT_IMAGE_ALPHA)

    deathFrame:SetScript("OnDragStart", function(self)
        local db = EnsureDB()
        if db.imageLocked then return end
        self:StartMoving()
    end)
    deathFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local db = EnsureDB()
        local _, _, _, x, y = self:GetPoint(1)
        -- 只记录 CENTER 锚点的偏移，保持设置页的 sliders 语义单一。
        db.imageX = ClampNumber(x, 0, -800, 800)
        db.imageY = ClampNumber(y, 0, -600, 600)
        if ns.RequestConfigRefresh then
            ns.RequestConfigRefresh("player-death-position")
        end
    end)
    return deathFrame
end

local function ShowDeathImage(db)
    db = EnsureDB(db)
    if not db.imageEnabled then
        HideDeathImage()
        return false
    end
    CreateDeathFrame()
    local path = ResolveDeathImagePath(db)
    if path and deathTexture and deathTexture.SetTexture then
        pcall(deathTexture.SetTexture, deathTexture, path)
    end
    ApplyDeathFrameSettings(db)
    deathFrame:Show()
    return true
end

HideDeathImage = function()
    if deathFrame and deathFrame.Hide then
        pcall(deathFrame.Hide, deathFrame)
    end
end

local function IsShowingDeathImage()
    return deathFrame and deathFrame.IsShown and deathFrame:IsShown() or false
end

-- ---------------------------------------------------------------------------
-- 死亡检测（事件驱动为主，进世界时安全补查一次）
-- ---------------------------------------------------------------------------

local function IsPlayerDeadOrGhostSafe()
    if type(UnitIsDeadOrGhost) ~= "function" then return nil end
    local ok, dead = pcall(UnitIsDeadOrGhost, "player")
    if not ok or IsSecret(dead) or type(dead) ~= "boolean" then return nil end
    return dead
end

local function IsPlayerGhostSafe()
    if type(UnitIsGhost) ~= "function" then return nil end
    local ok, ghost = pcall(UnitIsGhost, "player")
    if not ok or IsSecret(ghost) or type(ghost) ~= "boolean" then return nil end
    return ghost
end

local function ShouldRun()
    local db = ns.GetModuleDB and ns.GetModuleDB(KEY)
    return db and db.enabled and true or false
end

local function HandlePlayerDead()
    if not ShouldRun() then return end
    local db = EnsureDB()
    PlayDeathVoice(db, true)
    ShowDeathImage(db)
end

local function HandlePlayerAlive()
    local db = EnsureDB()
    -- PLAYER_ALIVE 多为“释放成灵魂”。默认行为保持不变：直接隐藏。
    -- 勾选保留后：仍是灵魂/尸体就继续显示，只有真复活（已非死亡也非灵魂）才隐藏；
    -- 读不到安全状态时 fail-closed，直接隐藏避免图片卡死。
    if db.keepInGhost then
        local dead = IsPlayerDeadOrGhostSafe()
        local ghost = IsPlayerGhostSafe()
        if dead == true or ghost == true then
            ShowDeathImage(db)
            return
        end
    end
    HideDeathImage()
end

local function HandlePlayerUnghost()
    -- 真复活：始终隐藏。
    HideDeathImage()
end

local function HandleEnteringWorld()
    if not ShouldRun() then
        HideDeathImage()
        return
    end
    -- 进世界只补显示，不补播语音，避免每次登录/转阶段刷屏。
    local dead = IsPlayerDeadOrGhostSafe()
    if dead == true then
        ShowDeathImage(EnsureDB())
    else
        HideDeathImage()
    end
end

local function OnEvent(event)
    if event == "PLAYER_DEAD" then
        HandlePlayerDead()
    elseif event == "PLAYER_ALIVE" then
        HandlePlayerAlive()
    elseif event == "PLAYER_UNGHOST" then
        HandlePlayerUnghost()
    elseif event == "PLAYER_ENTERING_WORLD" then
        HandleEnteringWorld()
    end
end

local MODULE_EVENTS = {
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
    "PLAYER_ENTERING_WORLD",
}

-- ---------------------------------------------------------------------------
-- 设置页选项
-- ---------------------------------------------------------------------------

local function BuiltinSoundOptions()
    return {
        { value = "builtin:raid_warning", text = L("Built-in: Raid Warning") },
        { value = "builtin:ready_check", text = L("Built-in: Ready Check") },
        { value = "builtin:auction", text = L("Built-in: Auction Chime") },
    }
end

local function BuiltinImageOptions()
    return {
        { value = "builtin:skull", text = L("Built-in: Skull Marker") },
    }
end

local function VoiceOptions()
    local db = EnsureDB()
    local options, seen = {}, {}
    local function Add(name, text)
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            options[#options + 1] = { value = name, text = text or name }
        end
    end
    for _, option in ipairs(BuiltinSoundOptions()) do
        Add(option.value, option.text)
    end
    Add(db.voiceShared)
    local media = Audio.GetSharedMedia and Audio.GetSharedMedia()
    if media and type(media.List) == "function" then
        local ok, list = pcall(media.List, media, "sound")
        if ok and type(list) == "table" then
            local sorted = {}
            for _, name in ipairs(list) do sorted[#sorted + 1] = name end
            table.sort(sorted)
            for _, name in ipairs(sorted) do Add(name) end
        end
    end
    return options
end

local function ImageOptions()
    local db = EnsureDB()
    local options, seen = {}, {}
    local function Add(name, text)
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            options[#options + 1] = { value = name, text = text or name }
        end
    end
    for _, option in ipairs(BuiltinImageOptions()) do
        Add(option.value, option.text)
    end
    Add(db.imageShared)
    local media = Audio.GetSharedMedia and Audio.GetSharedMedia()
    if media and type(media.List) == "function" then
        for _, kind in ipairs({ "background", "border" }) do
            local ok, list = pcall(media.List, media, kind)
            if ok and type(list) == "table" then
                local sorted = {}
                for _, name in ipairs(list) do sorted[#sorted + 1] = name end
                table.sort(sorted)
                for _, name in ipairs(sorted) do Add(name) end
            end
        end
    end
    return options
end

local function VoiceSourceOptions(ui)
    return {
        { text = ui.L("Shared sound"), value = "shared" },
        { text = ui.L("Custom file path"), value = "custom" },
    }
end

local function ImageSourceOptions(ui)
    return {
        { text = ui.L("Shared image"), value = "shared" },
        { text = ui.L("Custom file path"), value = "custom" },
    }
end

local function ImageStrataOptions(ui)
    local options = {}
    for _, strata in ipairs(STRATA_ORDER) do
        options[#options + 1] = { text = ui.L("Strata: " .. strata), value = strata }
    end
    return options
end

local function DeathStatusText()
    local db = EnsureDB()
    if not db.enabled then return L("Disabled") end
    if IsShowingDeathImage() then return L("Showing death alert") end
    return L("Running")
end

ns.RegisterModule(KEY, {
    titleKey = "Player Death Alert",
    descKey = "Play a shared or custom voice and show a central shared or custom image when you die.",
    defaults = ns.GetModuleDefaults and ns.GetModuleDefaults(KEY) or {},
    OnInitialize = function(_, db)
        EnsureDB(db)
        CreateDeathFrame()
        ApplyDeathFrameSettings(db)
        HideDeathImage()
    end,
    OnEnable = function()
        EnsureDB()
        CreateDeathFrame()
        ApplyDeathFrameSettings(EnsureDB())
        if ns.RegisterModuleEvents then
            ns.RegisterModuleEvents(KEY, MODULE_EVENTS, OnEvent)
        end
        HandleEnteringWorld()
    end,
    OnDisable = function()
        if ns.UnregisterModuleEvents then
            ns.UnregisterModuleEvents(KEY, MODULE_EVENTS)
        end
        HideDeathImage()
    end,
    ApplySettings = function(_, db)
        EnsureDB(db)
        CreateDeathFrame()
        ApplyDeathFrameSettings(db)
        if not db.enabled then
            HideDeathImage()
        end
    end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                EnsureDB(db)
                local basic = page:NewSection(ui.L("Player Death Alert"))
                basic:Check(ui.L("Enable"), function() return db.enabled end, function(value)
                    ns.SetModuleEnabled(KEY, value)
                end, ui.L("Play a shared or custom voice and show a central shared or custom image when you die."))
                basic:CheckGrid({
                    {
                        label = ui.L("Enable death voice"),
                        getValue = function() return db.voiceEnabled ~= false end,
                        setValue = function(value) db.voiceEnabled = value and true or false end,
                        note = ui.L("Voice and image have independent switches. Either one can be enabled alone."),
                    },
                    {
                        label = ui.L("Enable death image"),
                        getValue = function() return db.imageEnabled ~= false end,
                        setValue = function(value)
                            db.imageEnabled = value and true or false
                            if not db.imageEnabled then HideDeathImage() end
                        end,
                        note = ui.L("Voice and image have independent switches. Either one can be enabled alone."),
                    },
                    {
                        label = ui.L("Keep showing while ghost"),
                        getValue = function() return db.keepInGhost == true end,
                        setValue = function(value) db.keepInGhost = value and true or false end,
                        note = ui.L("When enabled, releasing into a ghost keeps the image. It hides on true resurrection. When disabled, it hides on release."),
                    },
                }, { columns = 2 })
                basic:DynamicText(DeathStatusText, ui.Colors.text, 24)
                basic:ButtonRow({
                    {
                        text = ui.L("Preview death alert"),
                        width = 150,
                        onClick = function()
                            PlayDeathVoice(db, true)
                            ShowDeathImage(db)
                        end,
                    },
                    {
                        text = ui.L("Hide image"),
                        width = 120,
                        onClick = function() HideDeathImage() end,
                    },
                })
                basic:Text(ui.L("Death is detected with PLAYER_DEAD. Voice and image can each be enabled alone. By default the image hides on release or respawn; keep it to stay visible while ghost. Entering the world while dead only restores the image without replaying the voice."), ui.Colors.muted, 46)
                page:AddSection(basic)
            end,
        },
        {
            key = "voice",
            titleKey = "Voice",
            build = function(page, db, info, ui)
                EnsureDB(db)
                local voice = page:NewSection(ui.L("Death Voice"))
                voice:Dropdown(ui.L("Voice source"), function() return db.voiceSource or "shared" end, function(value)
                    db.voiceSource = (value == "custom") and "custom" or "shared"
                end, VoiceSourceOptions(ui), 132, 190)
                voice:SearchPicker(ui.L("Shared voice"),
                    function() return db.voiceShared end,
                    function(value) db.voiceShared = value end,
                    VoiceOptions,
                    {
                        labelW = 132,
                        buttonW = 250,
                        onPreview = function(value)
                            if Audio.ResolveSoundPath and Audio.PlaySoundPath then
                                Audio.PlaySoundPath(Audio.ResolveSoundPath(value))
                            end
                        end,
                    })
                voice:EditBox(ui.L("Custom voice path"), function() return db.voiceCustomPath or "" end, function(v)
                    db.voiceCustomPath = tostring(v or "")
                end, 112, 420, {
                    note = ui.L("Custom voice file path, for example Interface\\AddOns\\MyMedia\\dead.ogg. Only used when the source is custom file path."),
                })
                voice:ButtonRow({
                    {
                        text = ui.L("Preview voice"),
                        width = 150,
                        onClick = function() PlayDeathVoice(db, true) end,
                    },
                })
                page:AddSection(voice)
            end,
        },
        {
            key = "image",
            titleKey = "Image",
            build = function(page, db, info, ui)
                EnsureDB(db)
                local image = page:NewSection(ui.L("Death Image"))
                image:Dropdown(ui.L("Image source"), function() return db.imageSource or "shared" end, function(value)
                    db.imageSource = (value == "custom") and "custom" or "shared"
                end, ImageSourceOptions(ui), 132, 190)
                image:SearchPicker(ui.L("Shared image"),
                    function() return db.imageShared end,
                    function(value)
                        db.imageShared = value
                        if IsShowingDeathImage() then ShowDeathImage(db) end
                    end,
                    ImageOptions,
                    {
                        labelW = 132,
                        buttonW = 250,
                        onPreview = function(value)
                            local skull = Audio.BUILTIN_IMAGES and Audio.BUILTIN_IMAGES.skull
                            local path = (Audio.ResolveImagePath and Audio.ResolveImagePath(value)) or skull
                            db.imageShared = value
                            db.imageSource = "shared"
                            ShowDeathImage(db)
                            if deathTexture and path then
                                pcall(deathTexture.SetTexture, deathTexture, path)
                            end
                        end,
                    })
                image:EditBox(ui.L("Custom image path"), function() return db.imageCustomPath or "" end, function(v)
                    db.imageCustomPath = tostring(v or "")
                    if IsShowingDeathImage() then ShowDeathImage(db) end
                end, 112, 420, {
                    note = ui.L("Custom image file path, for example Interface\\AddOns\\MyMedia\\dead.blp. Only used when the source is custom file path."),
                })
                image:ValueSlider(ui.L("Image size"), 64, 512, 1,
                    function() return tonumber(db.imageSize) or DEFAULT_IMAGE_SIZE end,
                    function(value)
                        db.imageSize = ClampNumber(value, DEFAULT_IMAGE_SIZE, 64, 512)
                        ApplyDeathFrameSettings(db)
                    end, { labelW = 132, sliderW = 300 })
                image:ValueSlider(ui.L("Image alpha"), 0.1, 1, 0.05,
                    function() return tonumber(db.imageAlpha) or DEFAULT_IMAGE_ALPHA end,
                    function(value)
                        db.imageAlpha = ClampNumber(value, DEFAULT_IMAGE_ALPHA, 0.1, 1)
                        ApplyDeathFrameSettings(db)
                    end, { labelW = 132, sliderW = 300 })
                image:ValueSlider(ui.L("Offset X"), -800, 800, 1,
                    function() return tonumber(db.imageX) or 0 end,
                    function(value)
                        db.imageX = ClampNumber(value, 0, -800, 800)
                        ApplyDeathFrameSettings(db)
                    end, { labelW = 132, sliderW = 300 })
                image:ValueSlider(ui.L("Offset Y"), -600, 600, 1,
                    function() return tonumber(db.imageY) or 0 end,
                    function(value)
                        db.imageY = ClampNumber(value, 0, -600, 600)
                        ApplyDeathFrameSettings(db)
                    end, { labelW = 132, sliderW = 300 })
                image:Dropdown(ui.L("Image strata"), function() return NormalizeStrata(db.imageStrata) end, function(value)
                    db.imageStrata = NormalizeStrata(value)
                    ApplyDeathFrameSettings(db)
                end, ImageStrataOptions(ui), 132, 190, {
                    note = ui.L("Lower strata render behind other UI. BACKGROUND is the lowest."),
                })
                image:CheckGrid({
                    {
                        label = ui.L("Lock image position"),
                        getValue = function() return db.imageLocked ~= false end,
                        setValue = function(value)
                            db.imageLocked = value and true or false
                            ApplyDeathFrameSettings(db)
                        end,
                        note = ui.L("Unlock, preview the image, then drag it on screen."),
                    },
                }, { columns = 1 })
                image:ButtonRow({
                    {
                        text = ui.L("Preview image"),
                        width = 150,
                        onClick = function() ShowDeathImage(db) end,
                    },
                    {
                        text = ui.L("Hide image"),
                        width = 120,
                        onClick = function() HideDeathImage() end,
                    },
                })
                page:AddSection(image)
            end,
        },
    },
})

end)
