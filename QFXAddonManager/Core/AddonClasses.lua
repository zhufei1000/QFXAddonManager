local _, AM = ...
local API, L = AM.API, AM.L
-- Forever is a Classic-era game type: only the nine original classes exist.
-- Keep the full Retail order for every other client.
local RETAIL_CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
local FOREVER_CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local classOrder = (AM.IsForever and AM.IsForever()) and FOREVER_CLASS_ORDER or RETAIL_CLASS_ORDER
local classes = {}
for _, token in ipairs(classOrder) do
    classes[#classes + 1] = { key = token, label = L["CLASS_" .. token],
        atlas = "classicon-" .. token:lower(), texture = "Interface\\Icons\\INV_Misc_QuestionMark" }
end
AM.AddonClasses = classes
local known, playerClass = {}, nil
for _, entry in ipairs(classes) do known[entry.key] = true end

function AM.GetPlayerClassToken()
    if playerClass then return playerClass end
    if UnitClass then
        local _, token = UnitClass("player")
        if known[token] then playerClass = token end
    end
    return playerClass
end

local function Identity(item)
    if not item or item.missing or item.type == "single" then return nil end
    if item.type == "toolboxFeature" then return item.key and ("toolbox:" .. item.key) end
    return item.primary or (item.source and item.source.name) or item.name
end

local function Rules()
    local db = AM.db
    if not db then return nil end
    if type(db.addonClassRules) ~= "table" then db.addonClassRules = {} end
    return db.addonClassRules
end

local function Restricted(rule)
    if type(rule) ~= "table" then return false end
    for token in pairs(known) do if rule[token] == true then return true end end
    return false
end

local function Blocked(rule)
    local token = AM.GetPlayerClassToken()
    return token ~= nil and Restricted(rule) and rule[token] ~= true
end

function AM.GetItemClassRule(item)
    local rules, key = Rules(), Identity(item)
    return rules and key and rules[key] or nil
end

function AM.GetItemClassIcons(item)
    local rule, icons = AM.GetItemClassRule(item), {}
    for _, entry in ipairs(classes) do
        if type(rule) == "table" and rule[entry.key] == true then
            icons[#icons + 1] = { atlas = entry.atlas, texture = entry.texture, text = entry.label }
        end
    end
    return icons
end

function AM.IsToolboxClassBlocked(key)
    local rules = Rules()
    return rules ~= nil and Blocked(rules["toolbox:" .. key])
end

local revision, cache = 0, nil
local function Suppressed()
    local rules = Rules()
    local generation = AM.registrationGeneration or 0
    local class = AM.GetPlayerClassToken()
    if cache and cache.rules == rules and cache.revision == revision and cache.generation == generation and cache.class == class then
        return cache.suppressed
    end
    local result, needed = {}, false
    for key, rule in pairs(rules or {}) do
        if type(key) == "string" and not key:match("^toolbox:") and Blocked(rule) then needed = true; break end
    end
    if needed and AM.GetAddonPowerInventory then
        local installed, ordered, protected, children = AM.GetAddonPowerInventory()
        for _, name in ipairs(ordered) do
            if not protected[name] and not children[name] and Blocked(rules[name])
                and not (AM.IsLegacyToolboxAddon and AM.IsLegacyToolboxAddon(name)) then result[name] = true end
        end
        local changed = true
        while changed do
            changed = false
            for name, info in pairs(installed) do
                if not protected[name] and not result[name] then
                    for _, dep in ipairs(info.deps or {}) do
                        if result[dep] then result[name], changed = true, true; break end
                    end
                end
            end
        end
        for name in pairs(children) do result[name] = nil end
    end
    cache = { rules = rules, revision = revision, generation = generation, class = class, suppressed = result }
    return result
end

function AM.IsAddonClassBlocked(name) return Suppressed()[name] == true end
function AM.GetClassAddonTarget(name, desired)
    if desired ~= false and AM.IsAddonClassBlocked(name) then return false end
    return desired
end

function AM.IsItemClassBlocked(item)
    if not item or item.missing then return false end
    if item.type == "toolboxFeature" then return AM.IsToolboxClassBlocked(item.key) end
    local key = Identity(item)
    return key ~= nil and AM.IsAddonClassBlocked(key)
end

-- Automatic class writes bypass manual preferences, exclusions and mode
-- snapshots. Only the effective game enablement and this receipt change.
function AM.ApplyClassRules()
    if InCombatLockdown and InCombatLockdown() then AM.classRulesPending = true; return false end
    AM.classRulesPending = nil
    local rules = Rules()
    if not rules or not AM.GetAddonPowerInventory or not AM.GetPlayerClassToken() then return true end
    local previous = type(AM.db.addonClassState) == "table" and AM.db.addonClassState or {}
    if next(rules) == nil and (type(previous) ~= "table" or next(previous) == nil) then return true end
    local suppressed = Suppressed()
    local installed, ordered, protected, children = AM.GetAddonPowerInventory()
    local changed, before, seeds = {}, {}, {}
    for _, name in ipairs(ordered) do
        if not protected[name] and not children[name] and (Restricted(rules[name]) or suppressed[name] or (previous and previous[name]))
            and not (AM.IsLegacyToolboxAddon and AM.IsLegacyToolboxAddon(name)) then
            local current = API.GetAddOnEnableState(name) > 0
            local manual = AM.db.addonEnablement[name]
            if type(manual) ~= "boolean" then manual, seeds[name] = current, current end
            local desired = manual
            if AM.GetAddonModeTarget then desired = AM.GetAddonModeTarget(name, manual) end
            desired = AM.GetClassAddonTarget(name, desired)
            if current ~= desired then
                before[name], changed[#changed + 1] = current, name
                if desired then API.EnableAddOn(name) else API.DisableAddOn(name) end
                if (API.GetAddOnEnableState(name) > 0) ~= desired then
                    for _, rollback in ipairs(changed) do
                        if before[rollback] then API.EnableAddOn(rollback) else API.DisableAddOn(rollback) end
                    end
                    API.SaveAddOns()
                    AM.Print(string.format(L.MODE_APPLY_FAILED, name))
                    return false
                end
            end
        end
    end
    for name, value in pairs(seeds) do AM.db.addonEnablement[name] = value end
    AM.db.addonClassState = suppressed
    if #changed > 0 then
        API.SaveAddOns()
        if AM.MarkReloadRequired then AM.MarkReloadRequired() end
        if AM.RefreshAddOnStates then AM.RefreshAddOnStates() end
    end
    return true
end

function AM.SetItemClassRule(item, selection)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not AM.CanExcludeModeItem or not AM.CanExcludeModeItem(item) then AM.Print(L.MODE_PROTECTED); return false end
    local rules, key = Rules(), Identity(item)
    if not rules or not key then return false end
    local rule = {}
    for token in pairs(known) do if type(selection) == "table" and selection[token] == true then rule[token] = true end end
    local previous = rules[key]
    rules[key] = next(rule) and rule or nil
    revision, cache = revision + 1, nil
    if not AM.ApplyClassRules() then
        rules[key] = previous
        revision, cache = revision + 1, nil
        return false
    end
    if item.type == "toolboxFeature" then
        local ns = AM.Toolbox and AM.Toolbox.GetNamespace()
        if ns and ns.ApplyModule then
            AM.classRuleApplying = true
            ns.ApplyModule(item.key)
            AM.classRuleApplying = nil
        end
    end
    return true
end
