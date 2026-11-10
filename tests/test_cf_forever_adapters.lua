local ranking = dofile("tests/fixtures/cf_forever_top100.lua")
local tocFiles = dofile("tools/toc_lua_files.lua")
local locale = arg[1] or "enUS"
local root = arg[2] and (arg[2]:gsub("[/\\]+$", "") .. "/") or ""
GetLocale = function() return locale end
local combat = false
InCombatLockdown = function() return combat end
CreateFrame = function() error("Ordinary adapters must not create frames") end
hooksecurefunc = function() error("Ordinary adapters must not hook addon UI") end
C_Timer = setmetatable({}, {__index = function() error("Ordinary adapters must not start timers") end})

local installed, projects = {}, {}
assert(#ranking == 100)
for _, project in ipairs(ranking) do
    assert(not projects[project.slug], "Duplicate ranked project " .. project.slug)
    projects[project.slug] = true
    assert(project.project and project.file and project.toc)
    assert(project.role == "support" or project.source, "Missing entry evidence for " .. project.slug)
    installed[project.name] = project
end
local retailOnly = {}
for line in io.lines(root .. "QFXAddonManager_Config/QFXAddonManager_Config.toc") do
    local name = line:match("^Integration[\\/]Adapters[\\/]([^\\/]+)%.lua%s+%[AllowLoadGameType standard%]%s*$")
    if name then retailOnly[#retailOnly + 1] = name end
end
assert(#retailOnly > 0, "Missing Retail-only TOC entries")
for _, name in ipairs(retailOnly) do installed[name] = {} end
for _, name in ipairs({"QFXBeggar", "QfxUI_Installer", "QFXSystemBar", "Lueur"}) do installed[name] = {} end

local function session(gameType, addons)
    local forever = gameType == "camelot"
    GetBuildInfo = function() return "", "", "", forever and 16001 or 120105 end
    SlashCmdList = {}
    QFXAddonManagerDB = nil
    local names, queries, loads = {}, {}, {}
    for name in pairs(addons) do names[#names + 1] = name end
    table.sort(names)
    local AM = {name = "QFXAddonManager", API = {}, L = {}, State = {}, Cache = {}}
    QFXAddonManager = AM
    local main = root .. "QFXAddonManager/"
    local function core(path) assert(loadfile(main .. path))(AM.name, AM) end
    core("Locale/enUS.lua")
    if locale ~= "enUS" then core("Locale/" .. locale .. ".lua") end
    for _, path in ipairs({"Core/DB.lua", "Core/API.lua", "Core/Registry.lua", "Core/Groups.lua",
        "Core/Modules.lua", "Core/Scanner.lua", "Core/AddonModes.lua", "Core/Loader.lua"}) do core(path) end
    assert(AM.IsForever() == forever)
    AM.InitDB()
    AM.State.category, AM.State.search = "all", ""
    AM.Print = function(message) AM.lastMessage = message end
    AM.Toolbox = {BuildDisplay = function() return {} end}
    local API = AM.API
    API.GetNumAddOns = function() return #names end
    API.GetAddOnInfo = function(value)
        local name = type(value) == "number" and names[value] or value
        queries[name] = (queries[name] or 0) + 1
        if addons[name] then return name, name, "", true end
    end
    API.GetAddOnMetadata = function() end
    API.GetAddOnDependencies = function(name) return addons[name] and addons[name].deps or {} end
    API.GetAddOnOptionalDependencies = function() return {} end
    API.GetAddOnEnableState = function() return 2 end
    API.IsAddOnLoaded = function() return true end
    API.IsAddOnLoadOnDemand = function() return false end
    API.EnableAddOn = function() error("Options must not change addon power") end
    API.DisableAddOn = API.EnableAddOn
    API.LoadAddOn = function(name) loads[#loads + 1] = name; return true end
    for path in tocFiles(main .. "QFXAddonManager.toc", "Configs", gameType) do core(path) end
    local config, ns = root .. "QFXAddonManager_Config/", {}
    for path in tocFiles(config .. "QFXAddonManager_Config.toc", "Integration", gameType) do
        -- The preset event watcher is outside the settings adapter contract.
        if path ~= "Integration/Initialize.lua" then
            assert(loadfile(config .. path))(AM.name, ns)
        end
    end
    AM.adaptersReady = true
    assert(#loads == 0, "Reading adapters must not load an addon")
    return AM, queries, loads
end

local retail, retailQueries = session("standard", installed)
local forever, foreverQueries, loads = session("camelot", installed)
local absent = session("camelot", {})
for _, name in ipairs(retailOnly) do
    assert(retail.Registry.GetOpenOptions(name), "Missing Retail opener " .. name)
    assert(not foreverQueries[name] and not forever.Registry.Get(name), "Retail adapter leaked into Forever: " .. name)
end
for _, key in ipairs({"weakauras", "mdt", "raiderio"}) do
    assert(retail.Groups.Get(key) and retail.Modules.Get(key))
    assert(not forever.Groups.Get(key) and not forever.Modules.Get(key), "Retail group leaked into Forever: " .. key)
end
assert(not forever.Registry.Get("MythicDungeonTools_UI"))
for _, AM in ipairs({retail, forever}) do
    local pages = {}
    for name, registration in pairs(AM.Registry.addons) do
        if name == registration.name and registration.embeddedSettings then pages[name] = true end
    end
    assert(pages.QFXBeggar and pages.QfxUI_Installer)
    pages.QFXBeggar, pages.QfxUI_Installer = nil, nil
    assert(next(pages) == nil, "Unexpected manager-rendered addon settings")
    assert(AM.Registry.GetOpenOptions("QFXSystemBar"))
end
assert(not retailQueries.Lueur and forever.Registry.GetOpenOptions("Lueur"))
assert(not retail.Registry.Get("SpokenQuestsAudioShared") and not retail.Registry.Get("QuestieDB"))

QFXAddonManager = forever
forever.ScanAddOns()
local cards = {}
for _, card in ipairs(forever.Cache.display) do
    local name = card.primary or card.name
    assert(not cards[name], "Duplicate addon card " .. name)
    cards[name] = card
end
local children, parents = forever.GetAddonPowerChildren()
local tested = 0
for _, project in ipairs(ranking) do
    local name, entry, role = project.name, project.entry, project.role
    assert(not absent.Registry.GetOpenOptions(name), "An absent plugin received a launcher: " .. name)
    if role == "support" then
        assert(not forever.Registry.GetOpenOptions(name), "Support project received a settings button: " .. name)
        if project.parent then
            assert(children[name] and parents[name] == project.parent and not cards[name], "Wrong owner for " .. name)
        end
    else
        assert(cards[name], "Missing Forever addon card " .. name)
        if role == "command" then
            assert(not forever.Registry.GetOpenOptions(name), "Command-only addon received a window: " .. name)
        elseif role == "shared" then
            assert(retail.Registry.GetOpenOptions(name) and forever.Registry.GetOpenOptions(name), "Broken shared entry: " .. name)
        end
    end
    if role == "forever" or name == "QuestieTrace" then
        assert(not retailQueries[name] and not retail.Registry.Get(name), "Forever adapter leaked into Retail: " .. name)
    end
    if entry then
        local opened = 0
        local function mark() opened = opened + 1 end
        if entry:sub(1, 1) == "/" then
            SLASH_QFXFOREVERTEST1 = entry:upper()
            SlashCmdList.QFXFOREVERTEST = function(argument) assert(argument == project.argument); mark() end
        elseif entry == "AtlasLoot.SlashCommands:Run" then
            local commands = {}
            function commands:Run(argument) assert(self == commands and argument == "options"); mark() end
            AtlasLoot = setmetatable({SlashCommands = commands}, {__tostring = function() return name .. "-123" end})
            local other = name == "AtlasLootClassic" and "AtlasLootContinued" or "AtlasLootClassic"
            assert(not forever.OpenRegisteredOptions(other), "AtlasLoot fork opened the other fork's options")
        elseif entry == "ForeverAuras.OpenOptions" then
            WeakAuras = {OpenOptions = function() error("ForeverAuras used the Retail global") end}
            ForeverAuras = {OpenOptions = mark}
        elseif entry == "SkillUpForever_OnAddonCompartmentClick" then
            SkillUpForever_OnAddonCompartmentClick = mark
        else
            SettingsPanel = {GetAllCategories = function() return {
                {GetName = function() return entry end, GetID = function() return 42 end},
            } end}
            Settings = {OpenToCategory = function(id) assert(id == 42); mark() end}
        end
        combat = true
        assert(not forever.OpenRegisteredOptions(name) and opened == 0, "Combat allowed " .. name)
        combat = false
        assert(forever.OpenRegisteredOptions(name) and opened == 1, "Native dispatch failed for " .. name)
        tested = tested + 1
    end
end
assert(#loads == 0 and tested == 20)
local target = forever.Cache.addons.SkillUpForever
target.lod, target.loaded = true, false
local opened = 0
SkillUpForever_OnAddonCompartmentClick = function() opened = opened + 1 end
forever.IsAddonClassBlocked = function(name) return name == "SkillUpForever" end
assert(not forever.OpenRegisteredOptions("SkillUpForever") and #loads == 0 and opened == 0)
forever.IsAddonClassBlocked = nil
assert(forever.OpenRegisteredOptions("SkillUpForever") and loads[1] == "SkillUpForever" and opened == 1)
SkillUpForever_OnAddonCompartmentClick = nil
assert(not forever.OpenRegisteredOptions("SkillUpForever"), "Missing native API must fail")

local function CollectCards(manager, category)
    QFXAddonManager = manager
    manager.State.category = category
    manager.ScanAddOns()
    local found = {}
    for _, card in ipairs(manager.Cache.display) do
        assert(not found[card.primary], "Duplicate card: " .. card.primary)
        found[card.primary] = card
    end
    return found
end
local both = {"QFXSystemBar", "QFXUnitframes", "QFXMinimapTools", "QFXSkillAlerts", "PetStatusAlert"}
local emptyRetail = session("standard", {})
for _, manager in ipairs({emptyRetail, absent}) do
    local recommended = CollectCards(manager, "recommended")
    local isRetail = manager == emptyRetail
    assert(#manager.Cache.display == (isRetail and 6 or 5))
    assert((recommended.QFXfocus ~= nil) == isRetail, "QFXfocus is recommended only on Retail")
    for _, name in ipairs(both) do
        local card = assert(recommended[name], "Missing recommendation: " .. name)
        assert(card.missing and not card.loaded and not card.enabled and card.downloadURL and card.icon)
        assert(not manager.Cache.addons[name] and not manager.CanExcludeModeItem(card))
    end
    assert(next(CollectCards(manager, "all")) == nil, "Downloads belong only in Recommended Addons")
    assert(next(CollectCards(manager, "combat")) == nil, "Missing cards are hidden from functional categories")
end
local orphaned = session("camelot", {QFXSystemBar_Config = {}, QFXSkillAlerts_Config = {}})
local orphanCards = CollectCards(orphaned, "recommended")
assert(orphanCards.QFXSystemBar.missing and orphanCards.QFXSkillAlerts.missing, "Subpackages do not count as installation")
local allInstalled = {QFXfocus = {}}
for _, name in ipairs(both) do allInstalled[name] = {} end
for _, gameType in ipairs({"standard", "camelot"}) do
    local manager = session(gameType, allInstalled)
    manager.API.IsAddOnLoaded = function() return false end
    manager.API.GetAddOnEnableState = function() return 0 end
    assert(next(CollectCards(manager, "recommended")) == nil, "Installed but disabled addons are never recommended")
    local normal = CollectCards(manager, "all")
    assert(#manager.Cache.display == 6)
    assert(manager.CanAssignAddonCategory(normal.QFXUnitframes))
    for name in pairs(allInstalled) do
        local card = assert(normal[name], "Installed addon has no regular card: " .. name)
        assert(not card.missing and not card.loaded and not card.enabled and manager.Registry.GetOpenOptions(name))
        assert(not manager.SetAddonCategoryOverride(card, "recommended"), "Recommendations are not manually assignable")
    end
end

print("PASS: " .. locale .. " Forever Top 100, 20 native launchers, support ownership, two dedicated pages, TOC isolation, and Retail/Forever recommendations")
