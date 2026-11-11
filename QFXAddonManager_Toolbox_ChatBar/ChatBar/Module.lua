local _, manager = ...
manager.ToolboxRuntime:AddFile("ChatBar", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local M = ns.WhisperHistory
if not M then return end

local KEY = M.KEY
local mod = {}
M.mod = mod

local function L(key) return M.L(key) end

local function ShowClearConfirmation()
    if not StaticPopupDialogs or not StaticPopup_Show then return end
    StaticPopupDialogs.QFXTOOLBOX_WHISPER_HISTORY_CLEAR = StaticPopupDialogs.QFXTOOLBOX_WHISPER_HISTORY_CLEAR or {
        text = L("CLEAR_CONFIRM"),
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function() mod:ClearHistory() end,
    }
    StaticPopupDialogs.QFXTOOLBOX_WHISPER_HISTORY_CLEAR.text = L("CLEAR_CONFIRM")
    StaticPopup_Show("QFXTOOLBOX_WHISPER_HISTORY_CLEAR")
end

local function PrintHelp()
    if not ns.Print then return end
    ns.Print(L("HELP_1"))
    ns.Print(L("HELP_2"))
    ns.Print(L("HELP_3"))
    ns.Print(L("HELP_4"))
end

function mod:ShowClearConfirmation()
    ShowClearConfirmation()
end

function mod:PrintHelp()
    PrintHelp()
end

local function HandleWhisperSlash(message)
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$") or ""
    if M.conflict then M.ReportConflict() return end
    if not M.enabled then
        if ns.Print then ns.Print(L("DISABLED_COMMAND")) end
        return
    end
    if message == "read" then
        mod:MarkAllRead(false)
    elseif message == "clear" then
        ShowClearConfirmation()
    elseif message == "reset" then
        mod:ResetPositions()
    elseif message == "help" or message == "?" then
        PrintHelp()
    else
        mod:ToggleWindow()
    end
end

local function RegisterSlashCommands()
    if M.slashRegistered or M.conflict then return end
    M.slashRegistered = true
    _G.SLASH_QFXTOOLBOXWHISPER1 = "/qfw"
    _G.SLASH_QFXTOOLBOXWHISPER2 = "/qfxwhisper"
    SlashCmdList.QFXTOOLBOXWHISPER = HandleWhisperSlash
end

function mod:ToggleWindow()
    if M.UI then M.UI.ToggleWindow() end
end

function mod:OpenWindow()
    return M.UI and M.UI.OpenWindow() or false
end

function mod:CloseWindow()
    if M.UI then M.UI.CloseWindow() end
end

function mod:MarkAllRead(silent)
    return M.MarkAllRead(silent)
end

function mod:ClearHistory()
    M.ClearHistory(false)
end

function mod:GetUnreadCount()
    return M.GetUnreadCount()
end

function mod:GetMessageCount()
    return M.GetMessageCount()
end

function mod:ResetPositions()
    if M.UI then M.UI.ResetPositions() end
    if ns.Print then ns.Print(L("POSITIONS_RESET")) end
end

function mod:Refresh()
    if not M.UI then return end
    if M.UI.IsWindowShown() then
        if M.UI.UpdateFloatButton then M.UI.UpdateFloatButton() end
        M.UI.RefreshWindow(false)
    else
        M.UI.RefreshIndicators()
    end
end

function mod:OnInitialize(db)
    M.InitializeData(db, true)
    if M.IsStandaloneEnabled() then
        M.conflict = true
        M.ReportConflict()
        return
    end
    M.conflict = false
    RegisterSlashCommands()
end

function mod:OnEnable(db)
    if M.IsStandaloneEnabled() then
        M.conflict = true
        M.ReportConflict()
        M.enabled = false
        return
    end
    M.conflict = false
    M.EnsureConfig(db)
    M.InitializeData(db, false)
    M.enabled = true
    RegisterSlashCommands()
    M.UI.EnsureFrames()
    ns.RegisterModuleEvents(M, M.EVENTS, function(event, ...)
        M.HandleEvent(event, ...)
    end)
    M.UI.ApplySettings()
    M.UI.ResetPulse()
    M.UI.RefreshIndicators()
end

function mod:OnDisable()
    M.enabled = false
    ns.UnregisterModuleEvents(M, M.EVENTS)
    if M.UI then M.UI.Shutdown() end
end

function mod:ApplySettings(db)
    M.EnsureConfig(db)
    M.TrimMessages(db.maxMessages)
    if M.enabled and M.UI then M.UI.ApplySettings() end
end

local function ColorOptions(ui)
    return {
        { text = ui.L("WHISPER_HISTORY_COLOR_SOURCE"), value = "SOURCE" },
        { text = ui.L("WHISPER_HISTORY_COLOR_PLAYER"), value = "PLAYER" },
        { text = ui.L("WHISPER_HISTORY_COLOR_ORIGINAL"), value = "ORIGINAL" },
    }
end

local function EnabledRule(db, ui)
    return function()
        if M.conflict then return false, ui.L("WHISPER_HISTORY_CONFLICT") end
        if not db.enabled then return false, ui.L("WHISPER_HISTORY_ENABLE_FIRST") end
        return true
    end
end

local function SoundOptions(db, ui)
    local options = {
        { text = M.DEFAULT_SOUND_KEY, value = M.DEFAULT_SOUND_KEY },
        { text = ui.L("WHISPER_HISTORY_SOUND_DEFAULT"), value = M.BLIZZARD_SOUND_KEY },
    }
    local seen = { [M.DEFAULT_SOUND_KEY] = true, [M.BLIZZARD_SOUND_KEY] = true }
    for _, name in ipairs(M.GetSharedMediaSoundNames()) do
        if not seen[name] then
            options[#options + 1] = { text = name, value = name }
            seen[name] = true
        end
    end
    local selected = type(db.soundName) == "string" and db.soundName or M.DEFAULT_SOUND_KEY
    if not seen[selected] then
        options[#options + 1] = { text = selected, value = selected }
    end
    return options
end

ns.RegisterModule(KEY, {
    titleKey = "WHISPER_HISTORY_TITLE",
    descKey = "WHISPER_HISTORY_DESC",
    OnInitialize = function(_, db) mod:OnInitialize(db) end,
    OnEnable = function(_, db) mod:OnEnable(db) end,
    OnDisable = function() mod:OnDisable() end,
    ApplySettings = function(_, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "button",
            titleKey = "WHISPER_HISTORY_TAB_BUTTON",
            build = function(page, db, info, ui)
                local enabled = EnabledRule(db, ui)
                local section = page:NewSection(ui.L("WHISPER_HISTORY_TITLE") .. " / " .. ui.L("WHISPER_HISTORY_TAB_BUTTON"))
                section:Check(ui.L("Enable"), function() return db.enabled end, function(value)
                    ns.SetModuleEnabled(KEY, value)
                end, ui.L("WHISPER_HISTORY_DESC"))
                section:Dropdown(ui.L("WHISPER_HISTORY_DISPLAY_MODE"), function()
                    return db.buttonDisplayMode or "UNREAD"
                end, function(value)
                    db.buttonDisplayMode = value == "ALWAYS" and "ALWAYS" or "UNREAD"
                    mod:ApplySettings(db)
                end, {
                    { text = ui.L("WHISPER_HISTORY_DISPLAY_ALWAYS"), value = "ALWAYS" },
                    { text = ui.L("WHISPER_HISTORY_DISPLAY_UNREAD"), value = "UNREAD" },
                }, 150, 230, { enabled = enabled })
                section:Check(ui.L("WHISPER_HISTORY_LOCK_BUTTON"), function() return db.lockButton end, function(value)
                    db.lockButton = value and true or false
                end, nil, { enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_BUTTON_SCALE"), 0.65, 1.80, 0.05, function()
                    return db.buttonScale or 1
                end, function(value)
                    db.buttonScale = value
                    mod:ApplySettings(db)
                end, { decimals = 2, enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_BUTTON_ALPHA"), 0.20, 1, 0.05, function()
                    return db.buttonAlpha or 1
                end, function(value)
                    db.buttonAlpha = value
                    mod:ApplySettings(db)
                end, { decimals = 2, enabled = enabled })
                section:Dropdown(ui.L("WHISPER_HISTORY_BUTTON_COLOR"), function()
                    return db.buttonColorMode or "SOURCE"
                end, function(value)
                    db.buttonColorMode = value
                    mod:ApplySettings(db)
                end, ColorOptions(ui), 150, 230, { enabled = enabled })
                page:AddSection(section)
            end,
        },
        {
            key = "sound",
            titleKey = "WHISPER_HISTORY_TAB_SOUND",
            build = function(page, db, info, ui)
                local enabled = EnabledRule(db, ui)
                local section = page:NewSection(ui.L("WHISPER_HISTORY_TAB_SOUND"))
                section:Check(ui.L("WHISPER_HISTORY_SOUND_ENABLE"), function()
                    return db.soundEnabled ~= false
                end, function(value)
                    db.soundEnabled = value and true or false
                end, ui.L("WHISPER_HISTORY_SOUND_ENABLE_DESC"), { enabled = enabled })
                section:Dropdown(ui.L("WHISPER_HISTORY_SOUND_SELECT"), function()
                    return db.soundName or M.DEFAULT_SOUND_KEY
                end, function(value)
                    db.soundName = type(value) == "string" and value or M.DEFAULT_SOUND_KEY
                end, SoundOptions(db, ui), 150, 300, {
                    enabled = enabled,
                    note = ui.L("WHISPER_HISTORY_SOUND_SELECT_DESC"),
                })
                section:ButtonRow({
                    {
                        text = ui.L("WHISPER_HISTORY_SOUND_PREVIEW"),
                        width = 118,
                        onClick = function() M.PlayWhisperAlert(true) end,
                        enabled = enabled,
                    },
                })
                section:DynamicText(function()
                    if M.GetSharedMedia() then return ui.L("WHISPER_HISTORY_SOUND_LSM_AVAILABLE") end
                    return ui.L("WHISPER_HISTORY_SOUND_LSM_MISSING")
                end, ui.Colors.muted, 38)
                page:AddSection(section)
            end,
        },
        {
            key = "window",
            titleKey = "WHISPER_HISTORY_TAB_WINDOW",
            build = function(page, db, info, ui)
                local enabled = EnabledRule(db, ui)
                local section = page:NewSection(ui.L("WHISPER_HISTORY_TAB_WINDOW"))
                section:CheckGrid({
                    { label = ui.L("WHISPER_HISTORY_LOCK_WINDOW"), getValue = function() return db.lockWindow end, setValue = function(value) db.lockWindow = value and true or false end, enabled = enabled },
                    { label = ui.L("WHISPER_HISTORY_ALLOW_COMBAT"), getValue = function() return db.allowInCombatOpen end, setValue = function(value) db.allowInCombatOpen = value and true or false; mod:ApplySettings(db) end, enabled = enabled },
                    { label = ui.L("WHISPER_HISTORY_DETACHED"), getValue = function() return db.windowDetached end, setValue = function(value) db.windowDetached = value and true or false; mod:ApplySettings(db) end, enabled = enabled },
                    { label = ui.L("WHISPER_HISTORY_AUTO_CLOSE"), getValue = function() return db.autoCloseOnLeave end, setValue = function(value) db.autoCloseOnLeave = value and true or false; mod:ApplySettings(db) end, enabled = enabled },
                }, { columns = 2 })
                section:Dropdown(ui.L("WHISPER_HISTORY_WINDOW_COLOR"), function()
                    return db.windowColorMode or "SOURCE"
                end, function(value)
                    db.windowColorMode = value
                    mod:ApplySettings(db)
                end, ColorOptions(ui), 150, 230, { enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_AUTO_CLOSE_SECONDS"), 1, 300, 1, function() return db.autoCloseSeconds or 10 end, function(value)
                    db.autoCloseSeconds = math.floor(value + 0.5); mod:ApplySettings(db)
                end, { decimals = 0, enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_BACKGROUND_ALPHA"), 0.02, 0.60, 0.02, function() return db.windowBackgroundAlpha or 0.13 end, function(value)
                    db.windowBackgroundAlpha = value; mod:ApplySettings(db)
                end, { decimals = 2, enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_FONT_SIZE"), 10, 24, 1, function() return db.messageFontSize or 12 end, function(value)
                    db.messageFontSize = math.floor(value + 0.5); mod:ApplySettings(db)
                end, { decimals = 0, enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_READ_BRIGHTNESS"), 0.20, 0.95, 0.05, function() return db.readBrightness or 0.55 end, function(value)
                    db.readBrightness = value; mod:ApplySettings(db)
                end, { decimals = 2, enabled = enabled })
                page:AddSection(section)
            end,
        },
        {
            key = "history",
            titleKey = "WHISPER_HISTORY_TAB_HISTORY",
            build = function(page, db, info, ui)
                local enabled = EnabledRule(db, ui)
                local section = page:NewSection(ui.L("WHISPER_HISTORY_TAB_HISTORY"))
                section:Check(ui.L("WHISPER_HISTORY_PERSIST"), function() return db.persistHistory end, function(value)
                    db.persistHistory = value and true or false
                    if not db.persistHistory and QFXAddonManagerToolboxDB and QFXAddonManagerToolboxDB.globalData then
                        QFXAddonManagerToolboxDB.globalData.whisperHistory = nil
                    end
                end, ui.L("WHISPER_HISTORY_PERSIST_DESC"), { enabled = enabled })
                section:ValueSlider(ui.L("WHISPER_HISTORY_MAX_MESSAGES"), 50, 2000, 10, function() return db.maxMessages or 300 end, function(value)
                    db.maxMessages = math.floor(value + 0.5)
                    M.TrimMessages(db.maxMessages)
                    mod:Refresh()
                end, { decimals = 0, enabled = enabled })
                section:ButtonRow({
                    { text = ui.L("WHISPER_HISTORY_MARK_ALL_READ"), width = 118, onClick = function() mod:MarkAllRead(false); ui.Refresh() end },
                    { text = ui.L("WHISPER_HISTORY_CLEAR"), width = 108, onClick = ShowClearConfirmation },
                    { text = ui.L("WHISPER_HISTORY_RESET_POSITIONS"), width = 126, onClick = function() mod:ResetPositions(); ui.Refresh() end },
                    { text = ui.L("WHISPER_HISTORY_OPEN_WINDOW"), width = 126, onClick = function() mod:OpenWindow() end },
                })
                section:DynamicText(function()
                    return string.format(ui.L("WHISPER_HISTORY_STATUS"), mod:GetMessageCount(), mod:GetUnreadCount())
                end, ui.Colors.warning, 36)
                page:AddSection(section)
            end,
        },
    },
})

end)
