local _, QFXAM = ...
local API = QFXAM.API
local Registry = QFXAM.Registry
local Groups = QFXAM.Groups
local Modules = QFXAM.Modules
local displayEntries = {}
local sortPositions, sortLoaded = {}, {}
local displayRank = { module = 1, group = 2, toolboxFeature = 3, singleBundle = 9, single = 10, singleAddon = 11, addon = 12 }

local function Wipe(t)
    if type(t) ~= "table" then return end
    if wipe then wipe(t) else for k in pairs(t) do t[k] = nil end end
end

local function EnsureCache()
    QFXAM.Cache = QFXAM.Cache or {}
    QFXAM.Cache.addons = QFXAM.Cache.addons or {}
    QFXAM.Cache.list = QFXAM.Cache.list or {}
    QFXAM.Cache.display = QFXAM.Cache.display or {}
    QFXAM.Cache.groups = QFXAM.Cache.groups or {}
    QFXAM.Cache.singleAddons = QFXAM.Cache.singleAddons or {}
    QFXAM.Cache.singleBundles = QFXAM.Cache.singleBundles or {}
    QFXAM.Cache.meta = QFXAM.Cache.meta or {}
    QFXAM.Cache.seen = QFXAM.Cache.seen or {}
    return QFXAM.Cache
end

local function Lower(s) return string.lower(tostring(s or "")) end

-- Dual-line card names: strip color codes for the plain display text and detect
-- localized (non-ASCII) titles so the Chinese line never falls back to English.
local function StripDecoration(text)
    if type(text) ~= "string" or text == "" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text
end
local function HasLocalizedText(text)
    return type(text) == "string" and text:find("[\128-\255]") ~= nil
end
local function ResolveDisplayTitles(name, title)
    local plain = StripDecoration(title)
    local translation = QFXAM.Titles and (QFXAM.Titles[name] or QFXAM.Titles[Lower(name)])
    local titleZH = translation and translation.cn
    titleZH = titleZH or StripDecoration(API.GetAddOnMetadata(name, "Title-zhCN"))
        or StripDecoration(API.GetAddOnMetadata(name, "Title-zhTW"))
        or (HasLocalizedText(plain) and plain) or plain or name
    local titleEN = StripDecoration(API.GetAddOnMetadata(name, "Title-enUS"))
        or (not HasLocalizedText(plain) and plain) or name
    return titleZH, titleEN
end

local function NormalizeCategory(cat)
    if not cat or cat == "" then return nil end
    cat = Lower(cat)
    if cat:find("raid") or cat:find("dungeon") or cat:find("party") or cat:find("boss") or cat:find("团队") or cat:find("副本") then return "raid" end
    if cat:find("combat") or cat:find("damage") or cat:find("战斗") then return "combat" end
    if cat:find("auction") or cat:find("mail") or cat:find("trad") or cat:find("profession") or cat:find("商业") or cat:find("交易") then return "equipment" end
    if cat:find("bag") or cat:find("inventory") or cat:find("equipment") or cat:find("item") or cat:find("背包") or cat:find("装备") then return "equipment" end
    if cat:find("interface") or cat:find("ui") or cat:find("unit") or cat:find("nameplate") or cat:find("界面") then return "ui" end
    if cat:find("chat") or cat:find("聊天") then return "chat" end
    if cat:find("map") or cat:find("minimap") or cat:find("quest") or cat:find("地图") or cat:find("任务") then return "map" end
    if cat:find("class") or cat:find("职业") then return "class" end
    if cat:find("tool") or cat:find("utility") or cat:find("辅助") then return "tool" end
    return nil
end

local function StartsWith(text, prefix)
    text = Lower(text)
    prefix = Lower(prefix)
    return text:sub(1, #prefix) == prefix
end

local function Contains(text, needle)
    return Lower(text):find(Lower(needle), 1, true) ~= nil
end

-- Hide pure technical/support addons by default: libraries, embedded library packs,
-- database modules, material packs, and Blizzard internal load-on-demand addons.
-- This follows the LNui/163UI style: user-facing modules first, support modules hidden.
function QFXAM.IsTechnicalAddon(name, title, notes, xCategory)
    local registration = Registry.Get(name)
    if registration and registration.technical then return true end
    if registration and registration.userFacing then return false end
    local n, t, d, c = Lower(name), Lower(title), Lower(notes), Lower(xCategory)
    if n == Lower(QFXAM.name or "") then return false end
    -- 管理中心的全部子插件（配置、适配器、语言、功能包）不进入任何插件列表。
    if StartsWith(n, Lower(QFXAM.name or "") .. "_") then return true end

    if n == "qfxtoolbox" or StartsWith(n, "qfxtoolbox_") then return true end
    if QFXAM.configAddonName and n == Lower(QFXAM.configAddonName) then return true end
    if QFXAM.adaptersAddonName and n == Lower(QFXAM.adaptersAddonName) then return true end
    if StartsWith(n, "blizzard_") then return true end
    if StartsWith(n, "!!!") then return true end
    if StartsWith(n, "lib") then return true end
    if StartsWith(n, "ace3") or StartsWith(n, "acegui") or StartsWith(n, "aceconfig") or StartsWith(n, "acedb") then return true end
    if StartsWith(n, "callbackhandler") or StartsWith(n, "libstub") then return true end
    if StartsWith(n, "sharedmedia") or StartsWith(n, "shared_media") then return true end
    if StartsWith(n, "datastore") then return true end
    if StartsWith(n, "raiderio_db") then return true end

    if Contains(n, "_db_") or Contains(n, "_database") or Contains(n, "datastorage") then return true end
    if Contains(n, "libsharedmedia") or Contains(n, "sharedmedia") then return true end
    if Contains(n, "options") and (Contains(n, "weakauras") or Contains(n, "dbm") or Contains(n, "bigwigs") or Contains(n, "cell")) then return true end

    if Contains(c, "library") or Contains(c, "libraries") or Contains(c, "data") or Contains(c, "media") then return true end
    if (Contains(t, "library") or Contains(t, "libraries") or Contains(d, "library")) and (Contains(n, "lib") or Contains(t, "lib")) then return true end
    if Contains(t, "sharedmedia") or Contains(d, "sharedmedia") or Contains(d, "shared media") then return true end
    if Contains(t, "database") or Contains(d, "database module") or Contains(d, "data module") then return true end

    return false
end

function QFXAM.GuessCategory(name, title, notes, xCategory)
    local regCat = Registry.GetCategory(name)
    if regCat then return QFXAM.NormalizeCategoryKey(regCat) end
    local moduleKey = Modules and Modules.GetModuleForAddon and Modules.GetModuleForAddon(name)
    local module = moduleKey and Modules.Get(moduleKey)
    if module and module.category then return QFXAM.NormalizeCategoryKey(module.category) end
    local metaCat = NormalizeCategory(xCategory)
    if metaCat then return QFXAM.NormalizeCategoryKey(metaCat) end

    local s = Lower(table.concat({ name or "", title or "", notes or "" }, " "))
    if s:find("details") or s:find("skada") or s:find("recount") or s:find("dbm") or s:find("bigwigs") or s:find("omnicd") then return "combat" end
    if s:find("raid") or s:find("dungeon") or s:find("mythic") or s:find("mdt") or s:find("raider") then return "raid" end
    if s:find("auction") or s:find("postal") or s:find("mail") or s:find("拍卖") or s:find("邮件") then return "equipment" end
    if s:find("baganator") or s:find("bagnon") or s:find("inventory") or s:find("equipment") or s:find("背包") or s:find("装备") then return "equipment" end
    if s:find("quest") or s:find("任务") then return "map" end
    if s:find("weak") or s:find("plater") or s:find("unit") or s:find("frame") or s:find("nameplate") or s:find("elvui") then return "ui" end
    if s:find("chat") or s:find("prat") or s:find("wim") then return "chat" end
    if s:find("map") or s:find("minimap") or s:find("tomtom") or s:find("handynotes") then return "map" end
    return "other"
end

-- Per-addon facts that cannot change while the client runs: TOC metadata,
-- dependency lists, guessed category and the dual-line display titles.
-- Registration-driven values (adapters, groups, modules) are folded in here as
-- well and the whole entry is rebuilt when the shared registration generation
-- changes, so scans stay cheap: metadata lookups happen once per addon per
-- generation instead of once per scan.
local function BuildAddOnMeta(name, title, notes, gen)
    local author = API.GetAddOnMetadata(name, "Author")
    local version = API.GetAddOnMetadata(name, "Version")
    local xCategory = API.GetAddOnMetadata(name, "X-Category")
    local xWebsite = API.GetAddOnMetadata(name, "X-Website")
    local group = Groups.GetGroupForAddon(name)
    local module = Modules and Modules.GetModuleForAddon and Modules.GetModuleForAddon(name)
    local adapted = Registry.IsAdapted(name) or (group and true or false) or (module and true or false)
    local technical = QFXAM.IsTechnicalAddon(name, title, notes, xCategory)
    local category = technical and "technical" or QFXAM.GuessCategory(name, title, notes, xCategory)
    local registration = Registry.Get(name)
    local icon = API.GetAddOnMetadata(name, "IconTexture")
    local iconAtlas = API.GetAddOnMetadata(name, "IconAtlas")
    if icon == "" then icon = nil end
    if iconAtlas == "" then iconAtlas = nil end
    local fallback = QFXAM.TOCIconFallbacks and QFXAM.TOCIconFallbacks[name]
    if fallback and icon and not iconAtlas then icon = fallback[icon] or icon end
    local iconCoords
    if not icon and not iconAtlas then icon, iconAtlas, iconCoords = Registry.GetIcon(name) end
    local titleZH, titleEN = ResolveDisplayTitles(name, title)
    local displayTitle = title or Registry.GetTitle(name) or name
    return {
        gen = gen,
        title = displayTitle,
        sortKey = Lower(displayTitle),
        titleRaw = title,
        notesRaw = notes,
        titleZH = titleZH,
        titleEN = titleEN,
        notes = notes or "",
        author = author or "",
        version = version or "",
        icon = icon,
        iconAtlas = iconAtlas,
        iconCoords = iconCoords,
        xCategory = xCategory,
        xWebsite = xWebsite,
        deps = API.GetAddOnDependencies(name) or {},
        optdeps = API.GetAddOnOptionalDependencies(name) or {},
        adapted = adapted,
        category = category,
        categories = registration and registration.categories,
        group = group,
        module = module,
        technical = technical,
    }
end

-- Refresh the cache in place: info tables are reused across scans (only the
-- session-mutable enable/loaded state is rewritten), so repeated scans do not
-- allocate per-addon tables or lowercase sort keys.
function QFXAM.ScanAddOns(newDisplaySession)
    local cache = EnsureCache()
    cache.singleBundlesDirty = true
    cache.addonChildrenGeneration = nil
    Wipe(cache.list)
    Wipe(cache.seen)

    local gen = QFXAM.registrationGeneration or 0
    local count = API.GetNumAddOns()
    for i = 1, count do
        local name, title, notes, loadable, reason, security, updateAvailable = API.GetAddOnInfo(i)
        if name and reason ~= "MISSING" then
            cache.seen[name] = true
            local meta = cache.meta[name]
            -- Rebuild when registrations changed, or when the raw GetAddOnInfo
            -- inputs differ from what the cached entry was built from.
            if not meta or meta.gen ~= gen or meta.titleRaw ~= title or meta.notesRaw ~= notes then
                meta = BuildAddOnMeta(name, title, notes, gen)
                cache.meta[name] = meta
            end

            local info = cache.addons[name]
            if not info then
                info = { type = "addon", name = name, key = name, protected = name == QFXAM.name }
                cache.addons[name] = info
                cache.addons[Lower(name)] = info
            end

            local state = API.GetAddOnEnableState(name) or 0
            local loaded = API.IsAddOnLoaded(name) and true or false
            local lod = API.IsAddOnLoadOnDemand(name) and true or false
            if reason == "DEMAND_LOADED" or reason == "DEP_DEMAND_LOADED" then lod = true end
            if lod and reason == "DEMAND_LOADED" then loadable = true end

            info.title = meta.title
            info.titleZH = meta.titleZH
            info.titleEN = meta.titleEN
            info.notes = meta.notes
            info.loadable = loadable and true or false
            info.reason = reason
            info.security = security
            info.updateAvailable = updateAvailable
            info.author = meta.author
            info.version = meta.version
            info.icon = meta.icon
            info.iconAtlas = meta.iconAtlas
            info.iconCoords = meta.iconCoords
            info.xCategory = meta.xCategory
            info.xWebsite = meta.xWebsite
            info.deps = meta.deps
            info.optdeps = meta.optdeps
            info.state = state
            info.enabled = state == 2 or state == 1
            info.loaded = loaded
            info.lod = lod
            info.adapted = meta.adapted
            info.category = meta.category
            info.categories = meta.categories
            info.group = meta.group
            info.module = meta.module
            info.technical = meta.technical
            info.sortKey = meta.sortKey

            table.insert(cache.list, info)
        end
    end

    table.sort(cache.list, function(a, b)
        return a.sortKey < b.sortKey
    end)

    -- Drop entries whose addon is gone from the current list (the mock test
    -- harnesses swap the installed set mid-run; in the game this only happens
    -- across reloads, but pruning keeps the cache contract identical to a
    -- full rebuild).
    local seen = cache.seen
    for key, info in pairs(cache.addons) do
        if not seen[info.name] then cache.addons[key] = nil end
    end
    for name in pairs(cache.meta) do
        if not seen[name] then cache.meta[name] = nil end
    end

    if newDisplaySession then QFXAM.CaptureDisplayLoadOrder() end
    QFXAM.BuildDisplayList()
end

-- Enable/disable changes only session state, never TOC facts or ordering.
function QFXAM.RefreshAddOnStates()
    if not QFXAM.Cache or not QFXAM.Cache.list then return QFXAM.ScanAddOns() end
    for _, info in ipairs(QFXAM.Cache.list) do
        local _, _, _, loadable, reason = API.GetAddOnInfo(info.name)
        info.state = API.GetAddOnEnableState(info.name) or 0
        info.enabled = info.state == 1 or info.state == 2
        info.loaded = API.IsAddOnLoaded(info.name) and true or false
        info.reason = reason
        info.loadable = (loadable or (info.lod and reason == "DEMAND_LOADED")) and true or false
    end
    QFXAM.BuildDisplayList()
end

local function TextMatches(text, needle)
    if not needle or needle == "" then return true end
    return Lower(text):find(needle, 1, true) ~= nil
end

local function AddonMatchesSearch(info, needle)
    if not needle or needle == "" then return true end
    return QFXAM.MatchesSearchKeywords(info, needle) or TextMatches(info.name, needle)
        or TextMatches(info.title, needle) or TextMatches(info.notes, needle) or TextMatches(info.author, needle)
        or TextMatches(Registry.GetDescription(info.name), needle)
end

local function EnsureAddonFamilies()
    local cache = QFXAM.Cache
    local generation = QFXAM.registrationGeneration or 0
    if cache.addonChildrenGeneration == generation then return end
    if not QFXAM.GetAddonPowerChildren then
        cache.addonChildren, cache.addonFamilies = {}, {}
        cache.addonChildrenGeneration = generation
        return
    end
    local installed = {}
    for _, info in ipairs(cache.list) do installed[info.name] = info end
    local children, parents = QFXAM.GetAddonPowerChildren(installed)
    cache.addonChildren, cache.addonFamilies = children, {}
    for _, info in ipairs(cache.list) do
        local primary = parents[info.name] or (not children[info.name] and info.name)
        if primary then
            local family = cache.addonFamilies[primary]
            if not family then family = { primary }; cache.addonFamilies[primary] = family end
            if primary ~= info.name then family[#family + 1] = info.name end
        end
    end
    cache.addonChildrenGeneration = generation
end

local function FamilyMatchesSearch(primary, needle)
    for _, name in ipairs(QFXAM.Cache.addonFamilies[primary] or {}) do
        local info = QFXAM.Cache.addons[name]
        if info and AddonMatchesSearch(info, needle) then return true end
    end
    return false
end

local function GroupMatchesSearch(group, needle)
    if not needle or needle == "" then return true end
    if QFXAM.MatchesSearchKeywords(group, needle, "group") or TextMatches(group.title, needle)
        or TextMatches(group.key, needle) or TextMatches(group.notes, needle)
        or TextMatches(Registry.GetDescription(group.primary), needle) then return true end
    for _, addonName in ipairs(group.children or {}) do
        local info = QFXAM.Cache.addons[addonName]
        if info and AddonMatchesSearch(info, needle) then return true end
    end
    return FamilyMatchesSearch(group.primary or (group.children and group.children[1]), needle)
end

local function ModuleMatchesSearch(module, needle)
    if not needle or needle == "" then return true end
    if QFXAM.MatchesSearchKeywords(module, needle, "module") or TextMatches(module.title, needle)
        or TextMatches(module.companionNote, needle) or TextMatches(module.downloadURL, needle)
        or TextMatches(module.companionURL, needle)
        or TextMatches(module.titleCN, needle) or TextMatches(module.titleEN, needle)
        or TextMatches(module.key, needle) or TextMatches(module.tip, needle) or TextMatches(module.notes, needle)
        or TextMatches(Registry.GetDescription(module.primary), needle) then return true end
    if module.group then
        local group = Groups.Get(module.group)
        if group and GroupMatchesSearch(group, needle) then return true end
    end
    for _, addonName in ipairs(Modules.GetAddonList(module.key)) do
        local info = QFXAM.Cache.addons[addonName]
        if info and AddonMatchesSearch(info, needle) then return true end
    end
    return FamilyMatchesSearch(module.primary or (module.addons and module.addons[1]), needle)
end

local function CategoryMatches(item, category)
    return QFXAM.MatchesCategory(item, category)
end

local function HideAddon(hidden, addonName)
    if not addonName then return end
    hidden[addonName] = true
    hidden[Lower(addonName)] = true
end

local function IsManagedAddon(info)
    if not info then return false end
    if info.protected then return true end
    if info.module then return true end
    if info.group then return true end
    if info.adapted then return true end
    return false
end

local function SingleListMatchesSearch(list, needle)
    if not needle or needle == "" then return true end
    for _, info in ipairs(list or {}) do
        if AddonMatchesSearch(info, needle) then return true end
    end
    return false
end

local function PrimaryState(primary)
    if not primary then return false, false, false end
    return primary.enabled and true or false, primary.loaded and true or false, primary.loadable and true or false
end

local function IsSingleCandidate(info, hidden)
    return info and not QFXAM.Cache.addonChildren[info.name]
        and not hidden[info.name] and not hidden[Lower(info.name)] and not info.technical and not IsManagedAddon(info)
end

local function CandidateExists(candidates, name)
    return name and (candidates[name] or candidates[Lower(name)]) or nil
end

local function GuessSingleParent(info, candidates)
    if not info or not info.name then return nil end

    -- Prefer a real required dependency as parent. This mirrors how many addons
    -- declare optional modules: ParentAddon + ParentAddon_Module.
    for _, dep in ipairs(info.deps or {}) do
        local parent = CandidateExists(candidates, dep)
        if parent and parent.name ~= info.name then return parent.name end
    end

    -- Then use conservative name-prefix grouping. This catches common patterns
    -- such as HandyNotes_Dragonflight or SomeAddon-Options, while still falling
    -- back to a standalone card when the parent is not installed.
    local n = tostring(info.name or "")
    local prefix = n:match("^([^_]+)_") or n:match("^(.+)%-.+$")
    if prefix and prefix ~= n then
        local parent = CandidateExists(candidates, prefix)
        if parent and parent.name ~= info.name then return parent.name end
    end

    return nil
end

local function BuildSingleBundles()
    local candidates, roots, rootOrder = {}, {}, {}

    for _, info in ipairs(QFXAM.Cache.singleAddons or {}) do
        if info then
            candidates[info.name] = info
            candidates[Lower(info.name)] = info
        end
    end

    local function EnsureRoot(rootName)
        local rootInfo = CandidateExists(candidates, rootName)
        if not rootInfo then return nil end
        if not roots[rootInfo.name] then
            roots[rootInfo.name] = { primary = rootInfo, children = {} }
            table.insert(rootOrder, rootInfo.name)
        end
        return roots[rootInfo.name]
    end

    for _, info in ipairs(QFXAM.Cache.singleAddons or {}) do
        if info and CandidateExists(candidates, info.name) then
            local parentName = GuessSingleParent(info, candidates)
            local root = EnsureRoot(parentName or info.name)
            if root then
                local exists = false
                for _, child in ipairs(root.children) do
                    if child.name == info.name then exists = true break end
                end
                if not exists then table.insert(root.children, info) end
            end
        end
    end

    table.sort(rootOrder, function(a, b)
        local ai = roots[a] and roots[a].primary
        local bi = roots[b] and roots[b].primary
        return ((ai and ai.sortKey) or a) < ((bi and bi.sortKey) or b)
    end)

    local bundles = {}
    for _, rootName in ipairs(rootOrder) do
        local root = roots[rootName]
        local family = QFXAM.Cache.addonFamilies[rootName]
        if family then
            root.children = {}
            for _, name in ipairs(family) do
                local info = QFXAM.Cache.addons[name]
                if info then root.children[#root.children + 1] = info end
            end
        end
        table.sort(root.children, function(a, b)
            if a.name == root.primary.name then return true end
            if b.name == root.primary.name then return false end
            return a.sortKey < b.sortKey
        end)
        -- 单体插件只按“父插件/主插件”统计。
        -- 子插件只合并隐藏，不参与总计、已载入、启用/禁用、立即载入判断。
        local primary = root.primary
        local primaryEnabled, primaryLoaded = PrimaryState(primary)
        table.insert(bundles, {
            type = "singleBundle",
            key = primary.name,
            name = primary.name,
            title = primary.title or primary.name,
            titleZH = primary.titleZH,
            titleEN = primary.titleEN,
            notes = primary.notes or primary.name,
            category = "single",
            adapted = false,
            installed = 1,
            enabledCount = primaryEnabled and 1 or 0,
            loadedCount = primaryLoaded and 1 or 0,
            enabled = primaryEnabled,
            partial = false,
            loaded = primaryLoaded,
            loadable = primary.loadable,
            reason = primary.reason,
            lod = primary.lod,
            author = primary.author,
            version = primary.version,
            protected = primary.protected,
            source = primary,
            primary = primary.name,
            children = root.children,
            bundle = true,
        })
    end

    return bundles
end

local function AddSingleBundles(category, needle)
    for _, item in ipairs(QFXAM.Cache.singleBundles or {}) do
        local custom = QFXAM.GetAddonCategoryOverride and QFXAM.GetAddonCategoryOverride(item.primary)
        item.category = custom or "single"
        local visible = category == "single" or (custom and (category == "all" or CategoryMatches(item, category)))
        if visible and (AddonMatchesSearch(item.source or item, needle) or SingleListMatchesSearch(item.children, needle)) then
            table.insert(QFXAM.Cache.display, item)
        end
    end
end

-- Freeze load order for this UI session so a feature toggle never moves its card.
function QFXAM.CaptureDisplayLoadOrder()
    EnsureCache()
    local snapshot = { addons = {}, toolbox = {} }
    for _, info in ipairs(QFXAM.Cache.list) do
        snapshot.addons[info.name] = info.loaded and true or false
    end
    local T = QFXAM.Toolbox
    local ns = T and T.GetNamespace()
    if ns and ns.db then
        for key in pairs(ns.modules or {}) do
            snapshot.toolbox[key] = T.IsEnabled(key)
        end
    end
    QFXAM.Cache.displayLoadOrder = snapshot
end

local function DisplayItemLoaded(item)
    local snapshot = QFXAM.Cache.displayLoadOrder
    if item.type == "toolboxFeature" then
        if snapshot and snapshot.toolbox[item.key] ~= nil then return snapshot.toolbox[item.key] end
        return QFXAM.Toolbox.IsEnabled(item.key)
    end
    local name = item.primary or (item.source and item.source.name)
        or (item.children and item.children[1]) or item.name
    if snapshot and snapshot.addons[name] ~= nil then return snapshot.addons[name] end
    return item.loaded and true or false
end

local function SortDisplayList()
    local positions, loaded = sortPositions, sortLoaded
    Wipe(positions); Wipe(loaded)
    for index, item in ipairs(QFXAM.Cache.display) do
        positions[item], loaded[item] = index, DisplayItemLoaded(item)
    end
    local rank = displayRank
    table.sort(QFXAM.Cache.display, function(a, b)
        local firstA = not loaded[a] and a.moduleData ~= nil and a.moduleData.showWhenMissing == true
        local firstB = not loaded[b] and b.moduleData ~= nil and b.moduleData.showWhenMissing == true
        if firstA ~= firstB then return firstA end
        if loaded[a] ~= loaded[b] then return loaded[a] end
        if a.type ~= b.type then return (rank[a.type] or 99) < (rank[b.type] or 99) end
        if a.type == "toolboxFeature" then return positions[a] < positions[b] end
        if a.adapted ~= b.adapted then return a.adapted end
        return Lower(a.title or a.name) < Lower(b.title or b.name)
    end)
end

function QFXAM.BuildDisplayList()
    EnsureCache()
    EnsureAddonFamilies()
    Wipe(QFXAM.Cache.display)
    QFXAM.Cache.singleAddons = QFXAM.Cache.singleAddons or {}
    Wipe(QFXAM.Cache.singleAddons)

    local hidden = {}
    local needle = Lower(QFXAM.State.search or "")
    local category = QFXAM.NormalizeCategoryKey(QFXAM.State.category or "all")
    QFXAM.State.category = category

    -- 1) User-facing QFX adapted modules.
    if Modules and category ~= "single" then
        for _, key in ipairs(Modules.order or {}) do
            local module = Modules.Get(key)
            local moduleInstalled = module and Modules.IsModuleInstalled(key)
            if module and module.adapted ~= false and (moduleInstalled or module.showWhenMissing) then
                local installed, enabled, loaded = Modules.GetStats(key)
                local primaryInfo = moduleInstalled and Modules.GetPrimaryInfo(key) or nil
                local children = Modules.GetAddonList(key)
                local primaryEnabled, primaryLoaded = PrimaryState(primaryInfo)
                local identity = "module:" .. key
                local item = displayEntries[identity]
                if not item then item = {}; displayEntries[identity] = item end
                item.type = "module"
                item.key = key
                item.name = key
                item.title = module.title or key
                item.titleZH = module.titleCN or (HasLocalizedText(module.title) and module.title)
                        or (primaryInfo and primaryInfo.titleZH) or module.title or key
                item.titleEN = (primaryInfo and primaryInfo.titleEN) or module.titleEN
                        or (not HasLocalizedText(module.title) and module.title) or key
                item.notes = module.tip or module.notes or (primaryInfo and primaryInfo.notes) or ""
                item.category = QFXAM.NormalizeCategoryKey(module.category or (primaryInfo and primaryInfo.category) or "other")
                item.categories = module.categories
                item.adapted = true
                item.installed = moduleInstalled and installed or 0
                item.missing = not moduleInstalled
                item.downloadURL = module.downloadURL
                item.companionNote, item.companionURL = module.companionNote, module.companionURL
                item.author = module.author
                item.enabledCount = primaryEnabled and 1 or 0
                item.loadedCount = moduleInstalled and loaded or 0
                item.enabled = primaryEnabled
                item.partial = false
                item.loaded = primaryLoaded
                item.primary = module.primary or (primaryInfo and primaryInfo.name)
                if item.missing then
                    item.icon, item.iconAtlas, item.iconCoords = Registry.GetIcon(item.primary)
                else
                    item.icon, item.iconAtlas, item.iconCoords = nil, nil, nil
                end
                item.children = QFXAM.Cache.addonFamilies[item.primary] or children
                item.moduleData = module
                local custom = QFXAM.GetAddonCategoryOverride and QFXAM.GetAddonCategoryOverride(item.primary)
                if custom then item.category, item.categories = custom, nil end
                if CategoryMatches(item, category) and ModuleMatchesSearch(module, needle) then
                    table.insert(QFXAM.Cache.display, item)
                end
                for _, child in ipairs(children) do HideAddon(hidden, child) end
            end
        end
    end

    -- 2) Fallback for explicitly registered groups that do not have a module.
    if category ~= "single" then
        for key, group in pairs(QFXAM.Groups.groups) do
            if (not Modules or not Modules.GetModuleForGroup(key)) and group.adapted ~= false and Groups.IsGroupInstalled(key) then
                local installed, enabled, loaded = Groups.GetGroupStats(key)
                local primaryInfo = Groups.GetPrimaryInfo(key)
                local primaryEnabled, primaryLoaded = PrimaryState(primaryInfo)
                local identity = "group:" .. key
                local item = displayEntries[identity]
                if not item then item = {}; displayEntries[identity] = item end
                item.type = "group"
                item.key = key
                item.name = key
                item.title = group.title or key
                item.titleZH = group.titleCN or (HasLocalizedText(group.title) and group.title)
                        or (primaryInfo and primaryInfo.titleZH) or group.title or key
                item.titleEN = (primaryInfo and primaryInfo.titleEN) or group.titleEN
                        or (not HasLocalizedText(group.title) and group.title) or key
                item.notes = group.notes or (primaryInfo and primaryInfo.notes) or ""
                item.category = QFXAM.NormalizeCategoryKey(group.category or (primaryInfo and primaryInfo.category) or "other")
                item.categories = group.categories
                item.adapted = true
                item.installed = installed
                item.enabledCount = primaryEnabled and 1 or 0
                item.loadedCount = loaded
                item.enabled = primaryEnabled
                item.partial = false
                item.loaded = primaryLoaded
                item.primary = group.primary or (primaryInfo and primaryInfo.name)
                item.children = QFXAM.Cache.addonFamilies[item.primary] or group.children
                item.groupData = group
                local custom = QFXAM.GetAddonCategoryOverride and QFXAM.GetAddonCategoryOverride(item.primary)
                if custom then item.category, item.categories = custom, nil end
                if CategoryMatches(item, category) and GroupMatchesSearch(group, needle) then
                    table.insert(QFXAM.Cache.display, item)
                end
                for _, child in ipairs(group.children or {}) do HideAddon(hidden, child) end
            end
        end
    end

    -- 3) Single AddOns collection: unadapted, non-technical user addons.
    -- It is no longer shown as a card inside the module list. A dedicated
    -- sidebar footer switches to this category. When shown, child addons are
    -- merged into their parent bundle so users do not see implementation modules.
    for _, info in ipairs(QFXAM.Cache.list) do
        if IsSingleCandidate(info, hidden) then
            table.insert(QFXAM.Cache.singleAddons, info)
        end
    end

    table.sort(QFXAM.Cache.singleAddons, function(a, b)
        return a.sortKey < b.sortKey
    end)

    local generation = QFXAM.registrationGeneration or 0
    if QFXAM.Cache.singleBundlesDirty or QFXAM.Cache.singleBundlesGeneration ~= generation then
        QFXAM.Cache.singleBundles = BuildSingleBundles()
        QFXAM.Cache.singleBundlesDirty = nil
        QFXAM.Cache.singleBundlesGeneration = generation
    else
        for _, item in ipairs(QFXAM.Cache.singleBundles) do
            local primary = item.source
            item.enabled, item.loaded, item.loadable = PrimaryState(primary)
            item.enabledCount, item.loadedCount = item.enabled and 1 or 0, item.loaded and 1 or 0
            item.reason = primary.reason
        end
    end
    AddSingleBundles(category, needle)

    if QFXAM.Toolbox then
        for _, item in ipairs(QFXAM.Toolbox.BuildDisplay(needle, category)) do
            QFXAM.Cache.display[#QFXAM.Cache.display + 1] = item
        end
    end
    SortDisplayList()
end

function QFXAM.GetSelectedItem()
    local key, typ = QFXAM.State.selectedKey, QFXAM.State.selectedType
    if not key then return nil end
    if typ == "addon" then
        return QFXAM.Cache.addons[key]
    end
    for _, item in ipairs(QFXAM.Cache.display or {}) do
        if item.type == typ and (item.key or item.name) == key then return item end
    end
    return nil
end

function QFXAM.SelectItem(item)
    if not item then
        QFXAM.State.selectedType = nil
        QFXAM.State.selectedKey = nil
        return
    end
    QFXAM.State.selectedType = item.type
    QFXAM.State.selectedKey = item.key or item.name
end
