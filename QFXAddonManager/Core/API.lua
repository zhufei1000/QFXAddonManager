local _, QFXAM = ...
QFXAM.API = QFXAM.API or {}
local API = QFXAM.API

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g end
    return nil
end

function API.GetNumAddOns()
    return Safe(C_AddOns and C_AddOns.GetNumAddOns) or Safe(_G.GetNumAddOns) or 0
end

function API.GetAddOnInfo(nameOrIndex)
    local name, title, notes, loadable, reason, security, updateAvailable = Safe(C_AddOns and C_AddOns.GetAddOnInfo, nameOrIndex)
    if name ~= nil then return name, title, notes, loadable, reason, security, updateAvailable end
    return Safe(_G.GetAddOnInfo, nameOrIndex)
end

function API.GetAddOnMetadata(nameOrIndex, key)
    return Safe(C_AddOns and C_AddOns.GetAddOnMetadata, nameOrIndex, key) or Safe(_G.GetAddOnMetadata, nameOrIndex, key)
end

function API.GetAddOnEnableState(nameOrIndex)
    local state = Safe(C_AddOns and C_AddOns.GetAddOnEnableState, nameOrIndex)
    if state ~= nil then return state end
    return Safe(_G.GetAddOnEnableState, nil, nameOrIndex) or 0
end

function API.IsAddOnLoaded(nameOrIndex)
    local loaded, finished = Safe(C_AddOns and C_AddOns.IsAddOnLoaded, nameOrIndex)
    if loaded ~= nil then return loaded, finished end
    return Safe(_G.IsAddOnLoaded, nameOrIndex)
end

function API.IsAddOnLoadOnDemand(nameOrIndex)
    local lod = Safe(C_AddOns and C_AddOns.IsAddOnLoadOnDemand, nameOrIndex)
    if lod ~= nil then return lod end
    return Safe(_G.IsAddOnLoadOnDemand, nameOrIndex)
end

function API.EnableAddOn(nameOrIndex)
    return Safe(C_AddOns and C_AddOns.EnableAddOn, nameOrIndex) or Safe(_G.EnableAddOn, nameOrIndex)
end

function API.DisableAddOn(nameOrIndex)
    return Safe(C_AddOns and C_AddOns.DisableAddOn, nameOrIndex) or Safe(_G.DisableAddOn, nameOrIndex)
end

function API.LoadAddOn(nameOrIndex)
    local loaded, reason = Safe(C_AddOns and C_AddOns.LoadAddOn, nameOrIndex)
    if loaded ~= nil or reason ~= nil then return loaded, reason end
    return Safe(_G.LoadAddOn, nameOrIndex)
end

function API.SaveAddOns()
    return Safe(C_AddOns and C_AddOns.SaveAddOns) or Safe(_G.SaveAddOns)
end

function API.GetAddOnDependencies(nameOrIndex)
    local deps = { Safe(C_AddOns and C_AddOns.GetAddOnDependencies, nameOrIndex) }
    if #deps == 0 then deps = { Safe(_G.GetAddOnDependencies, nameOrIndex) } end
    return deps
end

function API.GetAddOnOptionalDependencies(nameOrIndex)
    local deps = { Safe(C_AddOns and C_AddOns.GetAddOnOptionalDependencies, nameOrIndex) }
    if #deps == 0 then deps = { Safe(_G.GetAddOnOptionalDependencies, nameOrIndex) } end
    return deps
end

function API.OpenReloadDialog()
    if ReloadUI then ReloadUI() end
end

-- Interface number is the only reliable way to tell the Forever (Camelot)
-- client from Retail: WOW_PROJECT_ID still reports MAINLINE there. Treat
-- 16000-19999 as the "Forever" family and keep 12.x checks working for it.
local function ReadInterfaceNumber()
    if type(_G.GetBuildInfo) ~= "function" then return nil end
    local ok, _, _, _, interfaceNumber = pcall(_G.GetBuildInfo)
    if ok then return tonumber(interfaceNumber) end
    return nil
end

function QFXAM.GetInterfaceNumber()
    return ReadInterfaceNumber()
end

function QFXAM.IsForever()
    local interfaceNumber = ReadInterfaceNumber()
    return interfaceNumber ~= nil and interfaceNumber >= 16000 and interfaceNumber < 20000
end

function QFXAM.IsRetail12x()
    local interfaceNumber = ReadInterfaceNumber()
    if interfaceNumber == nil then return false end
    return (interfaceNumber >= 120000 and interfaceNumber < 130000)
        or (interfaceNumber >= 16000 and interfaceNumber < 20000)
end
