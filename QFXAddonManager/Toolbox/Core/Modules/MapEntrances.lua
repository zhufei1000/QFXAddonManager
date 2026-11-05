local _, manager = ...
manager.ToolboxRuntime:AddFile("Core", function(...)
local _, ns = ...

local KEY = "map_entrances"

local IS_FOREVER = false
if ns.Compat and type(ns.Compat.IsForever) == "function" then
    local ok, forever = pcall(ns.Compat.IsForever)
    IS_FOREVER = ok and forever == true
end

local CVARS = {
    delve = "showDelveEntrancesOnMap",
    dungeon = "showDungeonEntrancesOnMap",
}

local function GetCVar(name)
    if ns.Compat and ns.Compat.GetCVar then
        return ns.Compat.GetCVar(name, "?")
    end
    return "?"
end

local function SetCVar(name, enabled)
    if ns.Compat and ns.Compat.SetCVar then
        return ns.Compat.SetCVar(name, enabled and "1" or "0")
    end
    return false
end

local function SetCVarRaw(name, value)
    if ns.Compat and ns.Compat.SetCVar then
        return ns.Compat.SetCVar(name, value)
    end
    return false
end

-- 禁用即恢复：首次启用时拍下客户端原值，OnDisable 写回。
local function SnapshotClientCVars(db)
    if not db then return end
    if type(db.clientSnapshot) == "table" then return end
    local snap = {}
    for key, name in pairs(CVARS) do
        if not (IS_FOREVER and key == "delve") then
            local value = GetCVar(name)
            if value ~= nil and value ~= "?" then snap[name] = tostring(value) end
        end
    end
    db.clientSnapshot = snap
end

local function RestoreClientCVars(db)
    local snap = db and db.clientSnapshot
    if type(snap) ~= "table" then return end
    for _, name in pairs(CVARS) do
        if snap[name] ~= nil then
            SetCVarRaw(name, snap[name])
        end
    end
end

local function ApplyAll(db)
    if not db or not db.enabled then return end

    if not IS_FOREVER then
        SetCVar(CVARS.delve, db.showDelveEntrances ~= false)
    end
    SetCVar(CVARS.dungeon, db.showDungeonEntrances ~= false)
end

ns.RegisterModule(KEY, {
    titleKey = "Map Entrances",
    descKey = IS_FOREVER and "Show dungeon entrances on the world map."
        or "Keep delve and dungeon entrances visible on the world map.",
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function(info, db)
        SnapshotClientCVars(db)
        ApplyAll(db)
    end,
    OnDisable = function(info, db)
        RestoreClientCVars(db)
    end,
    ApplySettings = function(info, db) ApplyAll(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local basic = page:NewSection(ui.L("Map Entrances"))
                basic:Check(ui.L("Enable"), function() return db.enabled end, function(value)
                    ns.SetModuleEnabled(KEY, value)
                end, ui.L("When enabled, the selected entrance filters are applied automatically at login."))
                local filters = basic
                local items = {}
                if not IS_FOREVER then
                    items[#items + 1] = {
                        label = ui.L("Show Delve Entrances"),
                        getValue = function() return db.showDelveEntrances ~= false end,
                        setValue = function(value)
                            db.showDelveEntrances = value and true or false
                            ApplyAll(db)
                        end,
                        note = ui.L("Controls delve entrance pins on the world map."),
                    }
                end
                items[#items + 1] = {
                    label = ui.L("Show Dungeon Entrances"),
                    getValue = function() return db.showDungeonEntrances ~= false end,
                    setValue = function(value)
                        db.showDungeonEntrances = value and true or false
                        ApplyAll(db)
                    end,
                    note = ui.L("Controls dungeon entrance pins on the world map."),
                }
                filters:CheckGrid(items, { columns = IS_FOREVER and 1 or 2 })
                page:AddSection(filters)


            end,
        },
    },
})

end)
