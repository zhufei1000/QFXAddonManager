local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
-- Ace options are always opened in their native AceConfigDialog window. The
-- manager no longer mirrors foreign option trees into factory pages.
if not A.IsInstalled("AbilityTimeline", "BlizzMove", "SavedInstances", "HandyNotes") then return end
local UI_NAME = "QFXAddonManager-1.1.0"

local function Library(name)
    return LibStub and LibStub(name, true)
end

local function Options(app)
    local registry = Library("AceConfigRegistry-3.0")
    if not registry or not registry.GetOptionsTable then return end
    local ok, options = pcall(registry.GetOptionsTable, registry, app, "dialog", UI_NAME)
    if ok and type(options) == "table" then return options end
end

function A.OpenAce(app)
    local dialog = Library("AceConfigDialog-3.0")
    if dialog and Options(app) then dialog:Open(app); return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end

A.Update("AbilityTimeline", { openOptions = function() A.OpenAce("AbilityTimeline") end })
