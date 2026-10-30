local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("HandyNotes", "AbilityTimeline", "BlizzMove", "SavedInstances") then return end
local UI_NAME = "QFXAddonManager-1.1.0"
local inherited = { get = true, set = true, func = true, confirm = true, validate = true, disabled = true, hidden = true }
local literal = { name = true, desc = true, icon = true, image = true, usage = true, width = true, fontSize = true }
local states = {}
local TREE_GROUP_LIMIT = 8

local function Library(name)
    return LibStub and LibStub(name, true)
end

local function Options(app)
    local registry = Library("AceConfigRegistry-3.0")
    if not registry or not registry.GetOptionsTable then return end
    local ok, options = pcall(registry.GetOptionsTable, registry, app, "dialog", UI_NAME)
    if ok and type(options) == "table" then return options end
end

-- Read Ace's option tree; never attach fields to a foreign options/handler table.
local function Resolve(app, path)
    local root = Options(app)
    if not root then return end
    local node, handler, parents = root, root.handler, { root }
    for _, key in ipairs(path) do
        local args = type(node.args) == "function" and node.args() or node.args
        node = args and args[key]
        if not node then return end
        handler = node.handler or handler
        parents[#parents + 1] = node
    end
    local info = { [0] = app, appName = app, options = root, option = node,
        handler = handler, arg = node.arg, type = node.type, uiType = "dialog", uiName = UI_NAME }
    for i, key in ipairs(path) do info[i] = key end
    return node, info, parents
end

local function Member(app, path, field, ...)
    local node, info, parents = Resolve(app, path)
    if not node then return end
    local value = node[field]
    if inherited[field] then
        value = nil
        for _, parent in ipairs(parents) do
            if parent[field] ~= nil then value = parent[field] end
        end
    end
    if type(value) == "function" then return value(info, ...) end
    if type(value) == "string" and not literal[field] then
        assert(info.handler and type(info.handler[value]) == "function", "Missing Ace option handler: " .. value)
        return info.handler[value](info.handler, info, ...)
    end
    return value
end

local function Path(parent, key)
    local path = {}
    for i, value in ipairs(parent) do path[i] = value end
    path[#path + 1] = key
    return path
end

local function Children(app, path)
    local node = Resolve(app, path)
    local args = node and (type(node.args) == "function" and node.args() or node.args)
    local children = {}
    for key, child in pairs(args or {}) do
        local childPath = Path(path, key)
        if type(child) == "table" and not child.hiddenDialog and not Member(app, childPath, "hidden") then
            children[#children + 1] = { path = childPath, node = child,
                order = tonumber(Member(app, childPath, "order")) or 100 }
        end
    end
    table.sort(children, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return tostring(a.path[#a.path]) < tostring(b.path[#b.path])
    end)
    return children
end

local function Changed(state)
    state.definition = nil
    if state.pending then return end
    state.pending = true
    C_Timer.After(0, function()
        state.pending = nil
        if state.active and state.context and state.context.Rebuild then state.context.Rebuild() end
    end)
end

local function Apply(state, path, callback, values, count, after)
    local function run()
        if state.context.Widgets:InCombatLocked() or Member(state.app, path, "disabled") or Member(state.app, path, "hidden") then return false end
        Member(state.app, path, callback, unpack(values, 1, count))
        if after then after() end
        return true
    end
    if callback == "set" then
        local validation = Member(state.app, path, "validate", unpack(values, 1, count))
        if validation == false or type(validation) == "string" then
            AM.Print(type(validation) == "string" and validation or AM.L.OPEN_OPTIONS_FAILED)
            return false
        end
    end
    local confirm = Member(state.app, path, "confirm", unpack(values, 1, count))
    if confirm then
        state.context.Widgets:Confirm({ title = Member(state.app, path, "name"),
            text = type(confirm) == "string" and confirm or Member(state.app, path, "desc") or AM.L.CONFIRM,
            onAccept = run })
        return false
    end
    return run()
end

local function Commit(state, path, callback, ...)
    return Apply(state, path, callback, { ... }, select("#", ...), function() Changed(state) end)
end

local function Values(app, path)
    local values = Member(app, path, "values") or {}
    local items = {}
    for key, label in pairs(values) do items[#items + 1] = { key = key, label = tostring(label) } end
    table.sort(items, function(a, b) return a.label < b.label end)
    local sorting = Member(app, path, "sorting")
    if type(sorting) == "table" then
        local rank = {}; for index, key in ipairs(sorting) do rank[key] = index end
        table.sort(items, function(a, b)
            local ar, br = rank[a.key] or math.huge, rank[b.key] or math.huge
            if ar ~= br then return ar < br end
            return a.label < b.label
        end)
    end
    return items
end

-- Long option lists (BlizzMove frame tables) collapse into one row: the factory
-- searchable checkbox dropdown toggles each entry in place and the button shows
-- how many entries are active.
local function MultiSelect(state, layout, path, name, desc)
    local app, W = state.app, state.context.Widgets
    local items = Values(app, path)
    local function Active(key) return Member(app, path, "get", key) and true or false end
    local function Locked()
        if W:InCombatLocked() then return true end
        return Member(app, path, "disabled") and true or false
    end
    local function Summary()
        if #items == 0 then return "" end
        local active = 0
        for i = 1, #items do
            if Active(items[i].key) then active = active + 1 end
        end
        return string.format("%d / %d", active, #items)
    end
    local row = layout:Row({ type = "label", text = name, tooltip = desc })
    local region = row._leftRegion
    local dd
    dd = W:EditorDropdown(region, {
        width = 220,
        emptyText = AM.L.LIST_EMPTY,
        items = function()
            local list = {}
            for i = 1, #items do list[i] = { key = items[i].key, label = items[i].label } end
            return list
        end,
        checked = Active,
        disabled = Locked,
        searchable = function() return true end,
        onPick = function(key)
            Apply(state, path, "set", { key, not Active(key) }, 2, function() dd:SetText(Summary()) end)
            return true
        end,
    })
    dd:SetPoint("RIGHT", region, "RIGHT", -(W.Theme.rightPad or 16), 0)
    if region._label then region._label:SetPoint("RIGHT", dd, "LEFT", -(W.Theme.labelGap or 8), 0) end
    dd:SetText(Summary())
    local function Repaint() dd:SetAlpha(Locked() and 0.35 or 1) end
    Repaint()
    W:RegisterRefresh(Repaint)
end

local function Render(state, layout, path, depth)
    if depth > 12 then return end
    local app, node = state.app, Resolve(state.app, path)
    if not node or Member(app, path, "hidden") or node.hiddenDialog then return end
    local name = Member(app, path, "name") or tostring(path[#path] or app)
    local desc = Member(app, path, "desc")
    if node.type == "group" then
        if #path > 0 then layout:Section(name, desc) end
        for _, child in ipairs(Children(app, path)) do Render(state, layout, child.path, depth + 1) end
        return
    elseif node.type == "header" then layout:Section(name); return
    elseif node.type == "description" then
        if name:find("%S") then layout:Note(name) end
        return
    end
    local cfg = { text = name, tooltip = desc, disabled = function()
        local current = Resolve(app, path)
        return not current or current.disabledDialog or Member(app, path, "disabled") or Member(app, path, "hidden")
    end, getValue = function() return Member(app, path, "get") end,
        setValue = function(...) Commit(state, path, "set", ...) end }
    if node.type == "toggle" then cfg.type = "toggle"
    elseif node.type == "range" and not node.isPercent then
        cfg.type, cfg.min, cfg.max = "slider", node.min or node.softMin or 0, node.max or node.softMax or 100
        cfg.step = node.step and node.step > 0 and node.step or node.bigStep or .01
    elseif node.type == "range" then
        cfg.type, cfg.min, cfg.max, cfg.step = "slider", (node.min or 0) * 100, (node.max or 1) * 100, (node.step or .01) * 100
        cfg.getValue = function() return (Member(app, path, "get") or 0) * 100 end
        cfg.setValue = function(value) Commit(state, path, "set", value / 100) end
    elseif node.type == "select" then
        cfg.type, cfg.values = "dropdown", function() return Values(app, path) end
        cfg.width = 190
    elseif node.type == "input" and not node.multiline then cfg.type, cfg.width = "input", 190
    elseif node.type == "input" then
        cfg.label, cfg.hint, cfg.height = cfg.text, cfg.tooltip, 120
        cfg.setValue = function(value)
            if not state.context.Widgets:InCombatLocked() then Commit(state, path, "set", value) end
        end
        local _, height = state.context.Widgets:MultilineBox(layout.content, layout.y, cfg)
        layout.y = layout.y - height
        return
    elseif node.type == "keybinding" then cfg.type = "keybind"
    elseif node.type == "color" then
        cfg.type, cfg.alpha = "color", node.hasAlpha
    elseif node.type == "execute" then
        cfg.type, cfg.onClick, cfg.setValue = "button", function() Commit(state, path, "func") end, nil
    elseif node.type == "multiselect" then
        MultiSelect(state, layout, path, name, desc)
        return
    else
        layout:Note(name .. ": " .. A.Text("Use the original options window.", "请在原插件配置窗口调整。", "請在原插件設定視窗調整。"))
        return
    end
    layout:Row(cfg)
end

function A.AceSettings(app)
    return function(context)
        local root = Options(app)
        if not root then return end
        local state = states[app] or { app = app }
        states[app], state.context = state, context
        if not state.registered then
            local registry = Library("AceConfigRegistry-3.0")
            if registry and registry.RegisterCallback then
                state.OnConfigTableChange = function(self, _, changedApp)
                    if changedApp == self.app then Changed(self) end
                end
                registry.RegisterCallback(state, "ConfigTableChange", "OnConfigTableChange")
                state.registered = true
            end
        end
        if state.root ~= root then state.root, state.definition = root, nil end
        if state.definition then return state.definition end
        local definition = { external = true, tabs = {},
            OnSettingsShow = function() state.active = true end,
            OnSettingsHide = function() state.active = false end }
        local function Tab(path)
            return { key = table.concat(path, "/"), path = path, title = Member(app, path, "name") or path[#path] or app,
                build = function(page)
                    local p = A.Page(state.context, page)
                    Render(state, p, path, 0)
                    p:Finish()
                end }
        end
        local rootControls, groups = {}, {}
        for _, child in ipairs(Children(app, {})) do
            if child.node.type == "group" and not child.node.inline then groups[#groups + 1] = child
            else rootControls[#rootControls + 1] = child end
        end
        if #rootControls > 0 or #groups == 0 then
            definition.tabs[#definition.tabs + 1] = { key = "general", title = AM.L.SETTINGS, build = function(page)
                local p = A.Page(state.context, page)
                for _, child in ipairs(rootControls) do Render(state, p, child.path, 0) end
                p:Finish()
            end }
        end
        for _, child in ipairs(groups) do
            local tab, subs = Tab(child.path), {}
            local localControls = {}
            for _, sub in ipairs(Children(app, child.path)) do
                if sub.node.type == "group" and not sub.node.inline then subs[#subs + 1] = Tab(sub.path)
                else localControls[#localControls + 1] = sub end
            end
            if #subs > TREE_GROUP_LIMIT then
                -- Tree groups (BlizzMove registers one per addon) do not become
                -- a tab strip; one searchable dropdown selects the group.
                local groupKey = tab.key
                local function Current()
                    state.groups = state.groups or {}
                    for _, sub in ipairs(subs) do
                        if sub.key == state.groups[groupKey] then return sub end
                    end
                    state.groups[groupKey] = subs[1].key
                    return subs[1]
                end
                tab.build = function(page)
                    local p = A.Page(state.context, page)
                    for _, control in ipairs(localControls) do Render(state, p, control.path, 0) end
                    local current, W = Current(), state.context.Widgets
                    local row = p:Row({ type = "label", text = AM.L.GROUP, tooltip = Member(app, child.path, "desc") })
                    local selector = W:EditorDropdown(row._leftRegion, {
                        width = 260,
                        emptyText = AM.L.LIST_EMPTY,
                        items = function()
                            local list = {}
                            for i = 1, #subs do list[i] = { key = subs[i].key, label = subs[i].title } end
                            return list
                        end,
                        checked = function(key) return key == current.key end,
                        searchable = function() return true end,
                        onPick = function(key)
                            if state.groups[groupKey] ~= key then
                                state.groups[groupKey] = key
                                Changed(state)
                            end
                            return false
                        end,
                    })
                    selector:SetPoint("RIGHT", row._leftRegion, "RIGHT", -(W.Theme.rightPad or 16), 0)
                    if row._leftRegion._label then
                        row._leftRegion._label:SetPoint("RIGHT", selector, "LEFT", -(W.Theme.labelGap or 8), 0)
                    end
                    selector:SetText(current.title)
                    Render(state, p, current.path, 0)
                    p:Finish()
                end
            elseif #subs > 0 then
                if #localControls > 0 then
                    table.insert(subs, 1, { key = tab.key .. "/general", title = AM.L.SETTINGS, build = function(page)
                        local p = A.Page(state.context, page)
                        for _, sub in ipairs(localControls) do Render(state, p, sub.path, 0) end
                        p:Finish()
                    end })
                end
                tab.subtabs = subs
            end
            definition.tabs[#definition.tabs + 1] = tab
        end
        state.definition = definition
        return definition
    end
end

function A.OpenAce(app)
    local dialog = Library("AceConfigDialog-3.0")
    if dialog and Options(app) then dialog:Open(app); return end
    error(AM.L.OPEN_OPTIONS_FAILED)
end

A.Update("HandyNotes", { embeddedSettings = A.AceSettings("HandyNotes") })
A.Update("AbilityTimeline", { embeddedSettings = A.AceSettings("AbilityTimeline"), openOptions = function() A.OpenAce("AbilityTimeline") end })
