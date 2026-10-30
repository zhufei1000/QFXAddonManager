local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local KEY = "whisper_history"

local function HandleCommand(message)
    if manager.IsToolboxClassBlocked and manager.IsToolboxClassBlocked(KEY) then
        manager.Print(manager.L.CLASS_BLOCKED)
        return
    end
    local db = ns.GetModuleDB and ns.GetModuleDB(KEY)
    if not db or not db.enabled then
        if ns.Print then ns.Print(ns.L("WHISPER_HISTORY_DISABLED_COMMAND")) end
        return
    end

    if not ns.EnsureExternalModuleLoaded or not ns.EnsureExternalModuleLoaded(KEY) then return end
    if ns.ApplyModule then ns.ApplyModule(KEY) end
    local history = ns.WhisperHistory
    if history and history.conflict then
        if history.ReportConflict then history.ReportConflict() end
        return
    end
    local module = history and history.mod
    if not module then return end

    message = tostring(message or ""):lower():match("^%s*(.-)%s*$") or ""
    if message == "read" then
        module:MarkAllRead(false)
    elseif message == "clear" then
        module:ShowClearConfirmation()
    elseif message == "reset" then
        module:ResetPositions()
    elseif message == "help" or message == "?" then
        module:PrintHelp()
    else
        module:ToggleWindow()
    end
end

_G.SLASH_QFXTOOLBOXWHISPER1 = "/qfw"
_G.SLASH_QFXTOOLBOXWHISPER2 = "/qfxwhisper"
SlashCmdList.QFXTOOLBOXWHISPER = HandleCommand

end)
