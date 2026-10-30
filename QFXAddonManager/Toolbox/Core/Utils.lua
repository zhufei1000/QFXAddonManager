local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

--[[
    QFXToolBox Shared Utility Boundary

    Keep small cross-module helpers here instead of re-creating local copies in
    every module.  Feature logic stays inside modules; this file only provides
    safe wrappers, text/number normalization, and DB access helpers.
]]

local U = ns.Util or {}
ns.Util = U

local function IsFunction(value)
    return type(value) == "function"
end

function U.L(key)
    return ns.L and ns.L(key) or key
end

function U.Print(msg)
    if ns.Print then ns.Print(msg) end
end

-- Return function results, or nil on error/unavailable function.
function U.Call(fn, ...)
    if ns.Compat and ns.Compat.Call then
        return ns.Compat.Call(fn, ...)
    end
    if not IsFunction(fn) then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k, l, m, n end
    return nil
end

-- Return pcall-style results: ok, ...
function U.SafeCall(fn, ...)
    if ns.Compat and ns.Compat.SafeCall then
        return ns.Compat.SafeCall(fn, ...)
    end
    if not IsFunction(fn) then return false end
    return pcall(fn, ...)
end

function U.GetModuleDB(key)
    if type(key) ~= "string" or key == "" then return {} end
    if ns.GetModuleDB then return ns.GetModuleDB(key) end
    ns.db = type(ns.db) == "table" and ns.db or {}
    ns.db.modules = type(ns.db.modules) == "table" and ns.db.modules or {}
    ns.db.modules[key] = type(ns.db.modules[key]) == "table" and ns.db.modules[key] or {}
    return ns.db.modules[key]
end

function U.EnsureTable(parent, key)
    if type(parent) ~= "table" then return {} end
    if type(parent[key]) ~= "table" then parent[key] = {} end
    return parent[key]
end

function U.Trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

function U.ClampNumber(value, fallback, minValue, maxValue, integer)
    value = tonumber(value)
    if value == nil then value = fallback end
    value = tonumber(value) or 0
    if minValue ~= nil and value < minValue then value = minValue end
    if maxValue ~= nil and value > maxValue then value = maxValue end
    if integer then value = math.floor(value + 0.5) end
    return value
end

function U.Clamp01(value, fallback)
    return U.ClampNumber(value, fallback or 0, 0, 1)
end

function U.GetClientLocale()
    local loc = IsFunction(_G.GetLocale) and _G.GetLocale() or "enUS"
    if loc == "zhCN" or loc == "zhTW" then return loc end
    return "enUS"
end

function U.After(delay, callback)
    if ns.Compat and ns.Compat.After then
        return ns.Compat.After(delay, callback)
    end
    if C_Timer and IsFunction(C_Timer.After) then
        return C_Timer.After(tonumber(delay) or 0, callback)
    end
    if IsFunction(callback) then callback() end
    return nil
end

end)
