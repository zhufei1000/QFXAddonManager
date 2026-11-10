local tocFiles = dofile("tools/toc_lua_files.lua")
local root = arg[1] and (arg[1]:gsub("[/\\]+$", "") .. "/") or ""
local main = root .. "QFXAddonManager/"
local config = root .. "QFXAddonManager_Config/"
local function Session(flavor, list, early)
    local AM = { name = "QFXAddonManager", API = {}, L = { OPEN_OPTIONS_FAILED = "No options" } }
    local calls = { scans = 0, named = 0, loads = 0 }
    QFXAddonManagerDB = nil
    QFXAddonManager = AM
    GetBuildInfo = function() return "", "", "", flavor == "camelot" and 16001 or 120105 end
    for _, path in ipairs({
        "Locale/enUS.lua", "Core/DB.lua", "Core/API.lua", "Core/Registry.lua", "Core/Groups.lua", "Core/Modules.lua",
        "Core/Scanner.lua", "Core/AddonModes.lua", "Core/Loader.lua", "Configs/Categories.lua",
    }) do
        assert(loadfile(main .. path))(AM.name, AM)
    end
    AM.InitDB()
    AM.State.category = "all"
    AM.Print = function() end
    local names = {}
    for name in pairs(list) do names[#names + 1] = name end
    local API = AM.API
    function API.GetNumAddOns() calls.scans = calls.scans + 1; return #names end
    function API.GetAddOnInfo(key)
        if type(key) == "number" then key = names[key] else calls.named = calls.named + 1 end
        local info = list[key]
        if info then return key, info.title or key, "", false, info.reason end
    end
    function API.GetAddOnMetadata() end
    function API.GetAddOnDependencies(name) return list[name].deps or {} end
    function API.GetAddOnOptionalDependencies() return {} end
    function API.GetAddOnEnableState() return 0 end
    function API.IsAddOnLoaded() return false end
    function API.IsAddOnLoadOnDemand() return false end
    function API.LoadAddOn() calls.loads = calls.loads + 1; return false end
    if not early then AM.ScanAddOns() end
    local ns = { Manager = AM }
    for _, path in ipairs({ "Integration/Adapters/Common.lua", "Integration/RankedOptions.lua" }) do
        assert(loadfile(config .. path))(AM.name, ns)
    end
    return AM, ns, calls
end

local packed = [[

clockaddon	tool	Clock Options
mapaddon	map
mapaddon_child	map	Map Extension
duplicate	combat
gameonly	ui
missing	tool	Missing Settings
ownercard	ui	Fallback Settings
]]

local list = {
    ClockAddon = {}, MapAddon = { title = "|cff99aaffMap Tool|r" },
    MapAddon_Child = { deps = { "MapAddon" } }, Duplicate = { title = "Shared" },
    GameOnly = {}, Missing = { reason = "MISSING" }, OwnerCard = {},
}

local function Category(name, id, set, child)
    return {
        GetName = function() return name end,
        GetID = function() return id end,
        GetCategorySet = function() return set or 2 end,
        HasParentCategory = function() return child == true end,
    }
end
local categories = {
    Category("Clock Options", 1),
    Category("Shared", 2), Category("Shared", 3),
    Category("GameOnly", 4, 1), Category("GameOnly", 5, 2, true),
}
local opened
Settings = { CategorySet = { Game = 1, AddOns = 2 }, OpenToCategory = function(id) opened = id end }
SettingsPanel = { GetAllCategories = function() return categories end }

local AM, ns, calls = Session("standard", list)
local curated = function() return true end
AM.RegisterAddon("OwnerCard", { openOptions = curated })
ns.ApplyRankedOptions(packed)
assert(calls.scans == 1 and calls.named == 0 and calls.loads == 0, "Ranked matching must reuse the cache")
assert(not AM.Registry.Get("Missing") and not AM.Registry.Get("MapAddon_Child"))
assert(AM.Registry.GetOpenOptions("OwnerCard") == curated)
assert(AM.Registry.GetCategory("MapAddon") == "map")
assert(AM.OpenRegisteredOptions("ClockAddon") and opened == 1)
assert(not AM.Registry.GetOpenOptions("MapAddon"), "A missing native category cannot expose a button")
assert(not AM.Registry.GetOpenOptions("Duplicate"), "Ambiguous category names must not open")
assert(not AM.Registry.GetOpenOptions("GameOnly"), "Exclude game and child categories")
categories = { Category("Clock Options", 1), Category("Map Tool", 6) }
local opener = assert(AM.Registry.GetOpenOptions("MapAddon"), "Late native categories must be discovered")
assert(AM.Registry.GetOpenOptions("MapAddon") == opener)
InCombatLockdown = function() return true end
assert(not AM.OpenRegisteredOptions("MapAddon") and opened == 1)
InCombatLockdown = function() return false end
assert(AM.OpenRegisteredOptions("MapAddon") and opened == 6 and calls.loads == 0)

local early, fallback, earlyCalls = Session("camelot", list, true)
fallback.ApplyRankedOptions(packed)
assert(earlyCalls.scans == 1 and earlyCalls.loads == 0)
assert(not early.Registry.Get("MapAddon_Child") and early.Registry.GetOpenOptions("ClockAddon"))

local catalogByClient = {}
local projectRanks = { retail = {}, forever = {} }
local statuses = { ["source-category"] = true, ["installed-category"] = true, support = true }
for line in io.lines("tests/fixtures/cf_ranked_projects.tsv") do
    local client, rank, id, slug, file, status = line:match("^([^\t]+)\t(%d+)\t(%d+)\t([^\t]+)\t(%d*)\t([^\t]+)")
    if client then
        local ranks = assert(projectRanks[client])
        assert(not ranks[id] and tonumber(rank) == #ranks + 1 and statuses[status])
        assert(tonumber(file) and tonumber(file) > 0, "A ranked project must have release provenance")
        ranks[id], ranks[#ranks + 1] = true, slug
    end
end
assert(#projectRanks.retail == 1000 and #projectRanks.forever == 1000)
for _, flavor in ipairs({ "standard", "camelot" }) do
    local manager, spec, metrics = Session(flavor, {})
    local original = spec.ApplyRankedOptions
    local files, records = 0, {}
    spec.ApplyRankedOptions = function(data)
        for name, category, label in data:gmatch("\n([^\t\n]+)\t([^\t\n]+)\t?([^\n]*)") do
            assert(name == name:lower() and not records[name], "Invalid or duplicate folder: " .. name)
            assert(manager.GetCategoryText(category) ~= category, "Unknown category: " .. category)
            records[name] = label
        end
        original(data)
    end
    for path in tocFiles(config .. "QFXAddonManager_Config.toc", "Integration", flavor) do
        if path:find("^Integration/Ranked/") then
            assert(loadfile(config .. path))(manager.name, spec)
            files = files + 1
        end
    end
    assert(files == 1 and next(records) and not next(manager.Registry.addons))
    assert(metrics.named == 0 and metrics.loads == 0, "Missing ranked addons must be inert")
    catalogByClient[flavor] = records
end
assert(catalogByClient.standard.arenaanalytics ~= nil and catalogByClient.camelot.arenaanalytics == nil)
assert(catalogByClient.camelot.adventureguideforever ~= nil and catalogByClient.standard.adventureguideforever == nil)
for _, flavor in ipairs({ "standard", "camelot" }) do
    local manager, spec, metrics = Session(flavor, { ArenaAnalytics = {}, AdventureGuideForever = {} })
    for path in tocFiles(config .. "QFXAddonManager_Config.toc", "Integration", flavor) do
        if path:find("^Integration/Ranked/") then assert(loadfile(config .. path))(manager.name, spec) end
    end
    assert((manager.Registry.Get("ArenaAnalytics") ~= nil) == (flavor == "standard"))
    assert((manager.Registry.Get("AdventureGuideForever") ~= nil) == (flavor == "camelot"))
    assert(metrics.scans == 1 and metrics.named == 0 and metrics.loads == 0)
end
print("PASS: ranked options use one client catalog, cached installation, protected family ownership, native settings and combat guards")
