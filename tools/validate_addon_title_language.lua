-- Exercise native title resolution and the real pooled factory cards.
dofile("tools/validate_ui.lua")
local AM, API, UI = QFXAddonManager, QFXAddonManager.API, QFXAddonManager.UI
AM.Registry, AM.Groups, AM.Modules = nil, nil, nil
AM.Cache = { addons = {}, list = {}, display = {} }
local function load(path) assert(loadfile("QFXAddonManager/" .. path))(AM.name, AM) end
for _, path in ipairs({ "Core/Registry.lua", "Core/Groups.lua", "Core/Modules.lua",
    "Core/Scanner.lua", "Configs/Categories.lua", "Configs/Titles.lua" }) do load(path) end
local names = { "BlizzMove", "BugSack", "FriendGroups", "NativeTitle", "ChineseOnly", "QFXSystemBar" }
local raw = { BlizzMove = "暴雪窗口移动", BugSack = "BugSack", FriendGroups = "好友分组",
    NativeTitle = "Native Original Name", ChineseOnly = "中文插件", QFXSystemBar = "顶部微型菜单" }
local english = { BlizzMove = "|cffff8800BlizzMove|r", FriendGroups = "FriendGroups Original",
    QFXSystemBar = "|cffff66ccQ|cffffa64dF|cffffd100X|r|cffffffffSystemBar|r" }
local reads = 0
API.GetNumAddOns = function() return #names end
API.GetAddOnInfo = function(value)
    local name = type(value) == "number" and names[value] or value
    return name, raw[name], "", true
end
API.GetAddOnMetadata = function(name, key)
    reads = reads + 1
    if key == "Title-enUS" then return english[name] end
end
API.GetAddOnDependencies = function() return {} end
API.GetAddOnOptionalDependencies = function() return {} end
API.GetAddOnEnableState = function() return 2 end
API.IsAddOnLoaded = function() return true end
API.IsAddOnLoadOnDemand = function() return false end
for _, name in ipairs(names) do
    if name ~= "FriendGroups" then
        AM.RegisterGroup(name, { title = raw[name], titleEN = "Legacy English", primary = name,
            children = { name }, category = "other" })
    end
end
AM.RegisterModule("friends", { title = "好友分组", titleCN = "好友分组", titleEN = "Legacy English",
    primary = "FriendGroups", addons = { "FriendGroups" }, category = "chat" })
AM.State.category, AM.State.search = "all", ""
AM.ScanAddOns()
assert(AM.Cache.addons.BlizzMove.titleEN == "BlizzMove")
assert(AM.Cache.addons.BugSack.titleEN == "BugSack")
assert(AM.Cache.addons.NativeTitle.titleEN == "Native Original Name")
assert(AM.Cache.addons.ChineseOnly.titleEN == "ChineseOnly")
assert(AM.Cache.addons.QFXSystemBar.titleEN == "QFXSystemBar")
local selectedLocale = AM.GetLocale()
for _, item in ipairs(AM.Cache.display) do
    local expected = selectedLocale == "enUS" and AM.Cache.addons[item.primary or item.name].titleEN or item.titleZH
    assert(UI.GetItemTitle(item) == expected, "Title must follow manager session language")
    if item.key == "friends" then assert(item.titleEN == "FriendGroups Original") end
end
UI.RefreshList()
local checked = 0
for index = 1, math.ceil(#AM.Cache.display / 2) do
    local row = UI.addonListPanel.factoryApi:GetRow(index)
    for _, slot in ipairs({ row._leftSlot, row._rightSlot }) do
        if slot.item then
            checked = checked + 1
            assert(slot.cfg.getText() == UI.GetItemTitle(slot.item))
            if selectedLocale == "enUS" then
                assert(slot.cfg.getSubText() == "", "English cards must hide duplicate subtitles")
            end
        end
    end
end
assert(checked == #names, "Exercise every visible factory card")
local before = reads
local copied
C_Clipboard.SetClipboard = function(text) copied = text end
for _, item in ipairs(AM.Cache.display) do
    AM.SelectItem(item); UI.RefreshDetail()
    assert((UI.detailPanel.title._fullText or UI.detailPanel.title:GetText()) == UI.GetItemTitle(item))
    copied = nil
    UI.detailPanel.copyButton:Click()
    assert(copied == AM.Cache.addons[item.primary or item.name].titleEN,
        "The detail copy button must use the native English title in every locale")
end
AM.BuildDisplayList(); UI.RefreshList(); UI.RefreshDetail()
assert(reads == before, "Copying and ordinary refresh cannot query addon metadata")
assert(UI.GetItemTitle({ type = "toolboxFeature", title = "Localized Tool", titleEN = "dictionary_key" }) == "Localized Tool")
local active = AM.GetLocale()
AM.db.ui.language = active == "enUS" and "zhCN" or "enUS"
assert(AM.GetLocale() == active, "Pending language selection applies only after reload")
print("PASS: " .. selectedLocale .. " native English titles, module identity, pooled cards, localized detail titles, English copies and cached refresh")
