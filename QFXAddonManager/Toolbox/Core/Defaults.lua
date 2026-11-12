local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

--[[
QFXToolBox 默认值集中管理文件。
规则：
1. 模块默认值统一放在 ns.ModuleDefaults。
2. DB 初始化只补 nil 字段，不覆盖玩家已经保存的 false / 0 / 空字符串。
3. schemaVersion 只用于数据结构迁移；单纯调整默认值时不要升级。
4. Combat Numbers 的数值类设置不在这里写死，登录后读取玩家当前 CVar；Lag Tolerance 按当前专精读取/保存当前 SpellQueueWindow。
]]

local function Copy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = Copy(v)
    end
    return dst
end

-- 统一使用暴雪原生风格：不再使用第一版的蓝黑现代卡片配色。
-- 这里的颜色只用于文字状态，不再用于绘制自定义面板背景。
ns.Colors = {
    bg = { 0, 0, 0, 0 },
    card = { 0, 0, 0, 0 },
    border = { 1, 1, 1, 0 },
    accent = { 1.00, 0.82, 0.00, 1.00 },
    text = { 1.00, 0.82, 0.00, 1.00 },
    muted = { 0.72, 0.72, 0.72, 1.00 },
    warning = { 1.00, 0.82, 0.00, 1.00 },
    danger = { 1.00, 0.18, 0.12, 1.00 },
    good = { 0.25, 1.00, 0.35, 1.00 },
}

ns.UI = {
    panelW = 1020,
    outer = 16,
    inner = 12,
    gap = 8,
    sectionGap = 9,
    rowH = 30,
    sliderRowH = 46,
    buttonH = 28,
    buttonW = 122,
    navW = 320,
    scrollBarW = 16,
}

ns.ModuleDefaults = {
    combat_numbers = {
        enabled = true,
        userConfigured = false,
        clientSnapshotTaken = false,
        -- worldTextScale / showDamage / showHealing / showPeriodic / showPetMelee /
        -- showPetSpell / damageMotion / keepSeparators 不写死默认值，首次启用时读取当前客户端 CVar。
    },

    map_entrances = {
        enabled = true,
        showDelveEntrances = true,
        showDungeonEntrances = true,
    },

    player_stats = {
        enabled = false,
        locked = true,
        point = "BOTTOMLEFT",
        relativeTo = "ChatFrame1",
        relPoint = "BOTTOMRIGHT",
        x = 12,
        y = 0,
        customPosition = false,
        scale = 1,
        layoutVersion = 12,
        labelWidth = 50,
        labelCenterX = 25,
        valueStartX = 58,
        valueWidth = 112,
        rowSpacing = 1,
        framePaddingX = 4,
        framePaddingY = 4,
        primaryFontSize = 20,
        otherFontSize = 16,
        showRating = true,
        show = {
            primary = true,
            crit = true,
            haste = true,
            mastery = true,
            versatility = true,
            avoidance = true,
            leech = true,
        },
        showMode = {
            armor = "auto",
            dodge = "auto",
        },
        colors = {
            primary = { 1.00, 0.72, 0.05, 1.00 },
            crit = { 1.00, 0.24, 0.32, 1.00 },
            haste = { 0.33, 1.00, 0.04, 1.00 },
            mastery = { 0.04, 0.57, 1.00, 1.00 },
            versatility = { 0.36, 0.91, 1.00, 1.00 },
            armor = { 0.95, 0.62, 0.32, 1.00 },
            dodge = { 0.56, 1.00, 0.58, 1.00 },
            avoidance = { 0.78, 0.42, 1.00, 1.00 },
            leech = { 1.00, 0.36, 0.74, 1.00 },
        },
    },

    lag_tolerance = {
        enabled = true,
        specs = {},
        -- 只读不写：没有保存值的专精不动客户端 SpellQueueWindow；
        -- 只有用户保存过数值的专精才在登录/切换专精时强制应用。
    },

    cvar_presets = {
        enabled = false,
        autoApply = true,
        smartApply = true,
        customSettings = {},
        specialSettings = {
            simplifiedNameplatesDisabled = true,
        },
    },

    auto_quest = {
        enabled = false,
        autoAccept = true,
        autoTurnIn = true,
        preventMulti = true,
        ignoreTrivial = false,
        ignoreOldExpansion = false,
        acceptShiftEnable = false,
        acceptShiftSkip = true,
        turnInShiftEnable = false,
        turnInShiftSkip = true,
    },

    auto_merchant = {
        enabled = false,
        autoRepair = true,
        autoSellJunk = true,
        useGuildRepair = false,
        printSummary = true,
        keepItems = {},
        forceSellItems = {},
        defaultKeepSeedVersion = 0,
        defaultKeepSeedCount = 0,
        pendingFilterText = "",
        lastImportText = "",
        lastRepairFailed = false,
        lastRepairGuild = false,
        lastSoldCount = 0,
        lastSoldValue = 0,
    },

    mythic_plus_tools = {
        enabled = false,
        showAbbr = true,
        showBestLevel = true,
        hideOriginalLevel = true,
        showScore = false,
        showWeeklyPanel = true,
        abbrFontSize = 15,
        bestLevelFontSize = 25,
        scoreFontSize = 13,
        abbr = {},
    },

    mythic_plus_keystone_list = {
        enabled = false,
        keystoneListLocked = false,
        keystoneListClickTeleport = true,
        keystoneListShowSolo = true,
        keystoneListShowInParty = true,
        keystoneListHideInChallengeMode = true,
        keystoneListUseAbbreviation = true,
        keystoneListShowNoPort = true,
        keystoneListScale = 1.0,
        keystoneListPoint = "CENTER",
        keystoneListRelPoint = "CENTER",
        keystoneListX = 0,
        keystoneListY = 160,
        queueGlowColor = {
            r = 1.00,
            g = 0.82,
            b = 0.00,
            a = 1.00,
        },
        castGlowColor = {
            r = 0.25,
            g = 0.72,
            b = 1.00,
            a = 1.00,
        },
        glowSpeed = 1.00,
        glowStyle = "auto",
    },

    cast_target_alert = {
        enabled = false,
        environments = {
            outdoor = false,
            party = true,
            raid = false,
            delve = false,
            battleground = false,
            arena = false,
            scenario = false,
        },
        glowColor = {
            r = 1.00,
            g = 0.08,
            b = 0.02,
            a = 1.00,
        },
        glowSpeed = 1.00,
        glowStyle = "auto",
    },

    chat_bar = {
        enabled = false,
        locked = true,
        layoutDefaultsVersion = 5,
        scale = 1.10,
        buttonSize = 26,
        blockWidth = 28,
        blockHeight = 16,
        gap = 4,
        labelOffsetX = 1,
        labelOffsetY = 1,
        -- 每种聊天条外观模式都要有自己的布局默认值。
        -- 不能只写顶层 scale/buttonSize/gap，否则子插件在 NormalizeModeSettings()
        -- 里会优先保留旧 modeSettings，导致设置页仍显示旧默认值。
        modeSettings = {
            qfx = {
                scale = 1.10,
                buttonSize = 26,
                gap = 0,
                blockWidth = 28,
                blockHeight = 16,
                labelOffsetX = 1,
                labelOffsetY = 1,
                editBoxGap = 3,
            },
            native = {
                scale = 1.10,
                buttonSize = 26,
                gap = 0,
                blockWidth = 28,
                blockHeight = 16,
                labelOffsetX = 1,
                labelOffsetY = 1,
                editBoxGap = 3,
            },
            color_text = {
                scale = 1.10,
                buttonSize = 26,
                gap = 0,
                blockWidth = 28,
                blockHeight = 16,
                labelOffsetX = 1,
                labelOffsetY = 1,
                editBoxGap = 3,
            },
            color_blocks = {
                scale = 1.10,
                buttonSize = 26,
                gap = 4,
                blockWidth = 28,
                blockHeight = 16,
                labelOffsetX = 1,
                labelOffsetY = 1,
                editBoxGap = 3,
            },
            ndui_blocks = {
                scale = 1.10,
                buttonSize = 26,
                gap = 4,
                blockWidth = 40,
                blockHeight = 8,
                labelOffsetX = 1,
                labelOffsetY = 1,
                editBoxGap = 3,
            },
        },
        layout = "horizontal",
        appearanceStyle = "qfx",
        visible = {},
        modeVisible = {},
        buttonProfiles = {},
        buttonOrder = {},
        colorBarOrder = {},
        modeOrder = {},
        customText = {},
        textColors = {},
        blockColors = {},
        nduiBlockColors = {},
        worldBlockEnabled = false,
        shortenWorldName = false,
        attachEditBox = true,
        tabCycleChatType = true,
        rememberLastChatType = true,
        editBoxPosition = "above",
        editBoxWidthMode = "chatbar",
        editBoxAlignment = "left",
        editBoxGap = 3,
        editBoxOffsetX = 3,
        editBoxRightOffset = 0,
        borderEnabled = true,
        borderSkin = "auto",
        borderThickness = 2,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
    },

    minimap_button = {
        -- Always on: the launcher is the guaranteed in-game entry to the
        -- settings panel and has no user-facing off switch.
        enabled = true,
        show = true,
        minimap = { hide = false, minimapPos = 225, lock = false },
    },

    self_marker = {
        enabled = false,
        version = 5,
        linkGCDToMarker = true,
        markerEnabled = false,
        markerStyle = "flower",
        markerLocked = true,
        markerX = 0,
        markerY = -80,
        markerSize = 64,
        markerAlpha = 0.9,
        markerSpinMode = "none",
        markerSpinSpeed = 5,
        markerColorMode = "class",
        markerCustomColor = { r = 1, g = 1, b = 1, a = 0.9 },
        attackRangeEnabled = false,
        attackRangeColor = { r = 1, g = 0.12, b = 0.08 },
        markerDisplayMode = "always",
        markerHideInPetBattle = true,
        markerHideWhenMounted = false,
        markerHideInVehicle = false,
        crossLength = 26,
        crossThickness = 3,
        crossGap = 8,
        gcdEnabled = true,
        gcdLocked = true,
        gcdX = 0,
        gcdY = -80,
        gcdSize = 64,
        gcdDisplayMode = "gcd_only",
        gcdColorMode = "class",
        gcdCustomColor = { r = 1, g = 1, b = 1, a = 0.9 },
        gcdHideInPetBattle = true,
        gcdHideWhenMounted = false,
        gcdHideInVehicle = false,
        gcdDurationMode = "auto",
        gcdFixedDuration = 1.5,
        ringThickness = 12,
        gcdIdleAlpha = 0.35,
        gcdActiveAlpha = 0.9,
        frameStrata = "HIGH",
        frameLevel = 20,
    },

    auto_skip_quiet_dialogs = {
        enabled = false,
        skipCinematics = true,
        skipMovies = true,
        hideTalkingHead = true,
        muteTalkingHead = true,
        pauseOnModifier = true,
        onlyInInstance = false,
        verbose = false,
        skipStoryGossip = false,
        cinematicSkipped = 0,
        movieSkipped = 0,
        talkingHeadHidden = 0,
        talkingHeadMuted = 0,
        gossipSkipped = 0,
    },

    set_viewer = {
        enabled = false,
    },

    macro_enhance = {
        enabled = true,
    },

    player_death_alert = {
        enabled = false,
        voiceEnabled = true,
        voiceSource = "shared",
        voiceShared = "builtin:raid_warning",
        voiceCustomPath = "",
        imageEnabled = true,
        imageSource = "shared",
        imageShared = "builtin:skull",
        imageCustomPath = "",
        imageSize = 256,
        imageAlpha = 0.9,
        imageX = 0,
        imageY = 0,
        imageLocked = true,
        imageStrata = "BACKGROUND",
        keepInGhost = false,
    },

    merchant_expand = {
        enabled = false,
        expand = true,
        columns = 4,
        nameFontSize = 11,
    },

    auto_tank_misdirection = {
        enabled = false,
        preferFocus = false,
    },

    damage_meter_reset = {
        enabled = false,
        mode = "ask",
        dungeons = true,
        dungeonDifficulties = {
            normal = true,
            heroic = true,
            mythic = true,
        },
        -- @deprecated 0.47.03: dungeonMythicOnly superseded by dungeonKeystoneOnly; nothing reads it anymore
        dungeonKeystoneOnly = false,
        raids = true,
        raidDifficulties = {
            lfr = true,
            normal = true,
            heroic = true,
            mythic = true,
        },
        requireGroup = false,
        waitForCombatEnd = true,
        delay = 1.5,
        quiet = false,
    },

    fast_loot = {
        enabled = false,
    },

    gcd_history = {
        enabled = false,
        locked = true,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -180,
        iconSize = 34,
        iconCount = 8,
        spacing = 2,
        direction = "LEFT",
        combatOnly = false,
        showIdleGap = true,
        fadeEnabled = true,
        fadeStartSeconds = 6,
        fadeDurationSeconds = 3,
    },

    range_to_target = {
        enabled = false,
        locked = true,
        showFocus = false,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -130,
        fontSize = 18,
        combatOnly = false,
    },

    raid_marker_panel = {
        enabled = false,
        locked = true,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 80,
        layout = "horizontal",
        scale = 1.0,
        spacing = 2,
        backgroundAlpha = 0.78,
        hoverFadeEnabled = false,
        idleAlpha = 0.15,
        showReadyCheck = true,
        showCountdown = true,
        countdownSeconds = 10,
        readyPosition = "after",
        countdownPosition = "after",
    },

    whisper_history = {
        enabled = false,
        lockButton = true,
        lockWindow = true,
        allowInCombatOpen = true,
        buttonDisplayMode = "UNREAD",
        buttonScale = 1,
        buttonAlpha = 1,
        buttonColorMode = "SOURCE",
        windowColorMode = "SOURCE",
        windowDetached = false,
        autoCloseOnLeave = true,
        autoCloseSeconds = 10,
        windowBackgroundAlpha = 0.13,
        readBrightness = 0.55,
        messageFontSize = 12,
        maxMessages = 300,
        soundEnabled = true,
        soundName = "QFX iPhone",
        button = { point = "CENTER", relativePoint = "CENTER", x = 360, y = 0 },
        window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 620, height = 430 },
    },
}

function ns.GetModuleDefaults(key)
    local defaults = ns.ModuleDefaults and ns.ModuleDefaults[key]
    if type(defaults) ~= "table" then return {} end
    return defaults
end

ns.defaults = {
    schemaVersion = 10,
    locked = true,
    scale = 1,
    uiLanguage = "AUTO",
    minimap = { show = false },
    panel = {
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 0,
    },
    modules = {},
}

end)
