local _, QFXAM = ...
QFXAM.Registry = QFXAM.Registry or { addons = {}, aliases = {} }
local Registry = QFXAM.Registry

-- Registration (addons/groups/modules) invalidates Scanner's per-addon meta
-- cache; every entry point bumps one shared generation counter. Test harnesses
-- that bypass the Register* functions must call NotifyRegistrationChanged.
function QFXAM.NotifyRegistrationChanged()
    QFXAM.registrationGeneration = (QFXAM.registrationGeneration or 0) + 1
    -- A display cache built before this registration must be refreshed when the
    -- manager is next opened, even if no ADDON_LOADED event arrived.
    QFXAM.scanDirty = true
end

function QFXAM.RegisterAddon(name, data)
    if not name or type(data) ~= "table" then return end
    data.name = name
    QFXAM.NotifyRegistrationChanged()
    Registry.addons[name] = data
    Registry.addons[string.lower(name)] = data
    if data.aliases then
        for _, alias in ipairs(data.aliases) do
            Registry.aliases[alias] = name
            Registry.aliases[string.lower(alias)] = name
        end
    end
end

function Registry.Get(name)
    if not name then return nil end
    return Registry.addons[name] or Registry.addons[string.lower(name)] or Registry.addons[Registry.aliases[name] or ""]
end

function Registry.IsAdapted(name)
    local reg = Registry.Get(name)
    return reg and reg.adapted ~= false or false
end

function Registry.GetCategory(name)
    local reg = Registry.Get(name)
    return reg and reg.category or nil
end

function Registry.GetTitle(name)
    local reg = Registry.Get(name)
    return reg and (reg.title or reg.titleCN) or nil
end

function Registry.GetOpenOptions(name)
    local reg = Registry.Get(name)
    if not reg then return nil end
    if reg.openOptions then return reg.openOptions end
    if reg.findOpenOptions then return reg.findOpenOptions() end
end

function Registry.GetEmbeddedSettings(name)
    local reg = Registry.Get(name)
    return reg and reg.embeddedSettings or nil
end

-- Internal feature control is independent of saved addon load enablement.
function Registry.GetFeatureToggle(name)
    local reg = Registry.Get(name)
    return reg and reg.featureToggle or nil
end

function Registry.GetDescription(name)
    local reg = Registry.Get(name)
    local description = reg and reg.description
    if type(description) == "function" then return description() end
    return description
end

-- TOC icons are resolved by Scanner first. Native adapters then take priority
-- over bundled, verified project artwork; missing artwork uses the UI fallback.
function Registry.GetIcon(name)
    local reg = Registry.Get(name)
    if reg and type(reg.getIcon) == "function" then
        local ok, texture, atlas, coords = pcall(reg.getIcon)
        if ok and (texture or atlas) then return texture, atlas, coords end
    end
    if reg and (reg.icon or reg.iconAtlas) then return reg.icon, reg.iconAtlas, reg.iconCoords end
    local icons = QFXAM.ProjectIcons
    return icons and name and (icons[name] or icons[string.lower(name)]) or nil
end

function Registry.GetPresetInfo(name)
    local reg = Registry.Get(name)
    return reg and reg.preset or nil
end
