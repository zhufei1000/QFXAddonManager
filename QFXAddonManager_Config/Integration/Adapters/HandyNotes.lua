local QFXAM = _G.QFXAddonManager or select(2, ...)
if not QFXAM.AdapterUtils.IsInstalled("HandyNotes") then return end
local Update, TrySlash = QFXAM.AdapterUtils.Update, QFXAM.AdapterUtils.TrySlash

-- AceConfig requires a versioned renderer identity, including in callback info.
local CONFIG_UI_NAME = "QFXAddonManager-1.1.0"
local function HandyNotesFeatureOption()
    if not _G.HandyNotes then return end
    local registry = _G.LibStub and _G.LibStub("AceConfigRegistry-3.0", true)
    if not registry or type(registry.GetOptionsTable) ~= "function" then return end
    local options = registry:GetOptionsTable("HandyNotes", "dialog", CONFIG_UI_NAME)
    local option = options and options.args and options.args.enabled
    if not option or type(option.get) ~= "function" or type(option.set) ~= "function" then return end
    local info = { "enabled", appName = "HandyNotes", uiType = "dialog", uiName = CONFIG_UI_NAME,
        options = options, option = option, arg = option.arg, type = option.type }
    return option, info
end

Update("HandyNotes", {
    description = function() return QFXAM.L.HANDYNOTES_DESCRIPTION end,
    featureToggle = {
        isAvailable = function() return HandyNotesFeatureOption() ~= nil end,
        getValue = function()
            local option, info = HandyNotesFeatureOption()
            return option and option.get(info) and true or false
        end,
        setValue = function(on)
            local option, info = HandyNotesFeatureOption()
            if option then option.set(info, on and true or false) end
        end,
    },
    openOptions = function()
        local dialog = _G.LibStub and _G.LibStub("AceConfigDialog-3.0", true)
        if dialog and type(dialog.Open) == "function" and _G.HandyNotes then
            dialog:Open("HandyNotes")
            return
        end
        if TrySlash({ "HANDYNOTES" }, "") then return end
        error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
    end,
})
