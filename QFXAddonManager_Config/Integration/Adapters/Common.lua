local QFXAM = _G.QFXAddonManager or select(2, ...)

-- Installation is fixed for the session. Use the existing scan when available;
-- only early Config loads need to cache individual named queries.
local installed = {}
local function IsInstalled(...)
    local cache = QFXAM.Cache
    local snapshot = cache and cache.list and #cache.list > 0 and cache.addons
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local key = string.lower(name)
        if snapshot then
            if snapshot[key] then return true end
        else
            local present = installed[key]
            if present == nil then
                local api = QFXAM.API
                local found, _, _, _, reason
                if api and api.GetAddOnInfo then found, _, _, _, reason = api.GetAddOnInfo(name) end
                present = found ~= nil and reason ~= "MISSING"
                installed[key] = present
            end
            if present then return true end
        end
    end
    return false
end

-- Adapter functions are attached after KnownAddons registers base data.
local function Update(name, patch)
    if not QFXAM.AdapterUtils.IsInstalled(name) then return end
    local reg = QFXAM.Registry.Get(name)
    if not reg then return end
    for k, v in pairs(patch) do reg[k] = v end
end

local function TrySlash(names, arg)
    for _, key in ipairs(names) do
        if SlashCmdList and type(SlashCmdList[key]) == "function" then
            SlashCmdList[key](arg or "")
            return true
        end
    end
    return false
end

QFXAM.AdapterUtils = { Update = Update, TrySlash = TrySlash, IsInstalled = IsInstalled }
local A = QFXAM.AdapterUtils

function A.Text(en, cn, tw)
    local locale = QFXAM.GetLocale and QFXAM.GetLocale() or (GetLocale and GetLocale()) or "enUS"
    return locale == "zhCN" and (cn or en) or locale == "zhTW" and (tw or cn or en) or en
end

-- Wrap native launchers without replacing the target's UI, commands or data.
function A.NativeOptions(open)
    return function()
        if InCombatLockdown and InCombatLockdown() then
            error((QFXAM.L and QFXAM.L.COMBAT_LOCKED_TIP) or "Unavailable in combat.")
        end
        if open() == false then
            error((QFXAM.L and QFXAM.L.OPEN_OPTIONS_FAILED) or "Options unavailable")
        end
    end
end

-- Commands already used in chat may have been moved from SlashCmdList to
-- Blizzard's hash. Prefer a newly registered handler over the cached one.
local function FindNativeSlash(command)
    for key, handler in pairs(SlashCmdList or {}) do
        if type(key) == "string" and type(handler) == "function" then
            local index = 1
            local alias = rawget(_G, "SLASH_" .. key .. index)
            while type(alias) == "string" do
                if string.lower(alias) == command then
                    return handler, key
                end
                index = index + 1
                alias = rawget(_G, "SLASH_" .. key .. index)
            end
        end
    end
    local alias = command:upper()
    return hash_SlashCmdList and hash_SlashCmdList[alias], hash_ChatTypeInfoList and hash_ChatTypeInfoList[alias]
end

function A.CallNativeSlash(command, argument, addonOnly)
    command = command:lower()
    if addonOnly and (command == "/rl" or (IsSecureCmd and IsSecureCmd(command))) then return false end
    local handler, key = FindNativeSlash(command)
    if type(handler) ~= "function" then return false end
    if addonOnly and (type(key) ~= "string" or (SLASH_COMMAND and SLASH_COMMAND[key])) then return false end
    handler(argument or "")
    return true
end

function A.NativeSlash(command, argument)
    return A.NativeOptions(function() return A.CallNativeSlash(command, argument) end)
end

function A.SlashOptions(keys, message)
    return function()
        if A.TrySlash(keys, message or "") then return true end
        error(QFXAM.L.OPEN_OPTIONS_FAILED)
    end
end

-- Older consumer builds route their native settings entry back through the
-- manager. Hide only the manager's launcher for the duration of that call so
-- their own native window opens instead of recursing into the manager.
function A.WithoutManagerOptions(fn)
    if type(fn) ~= "function" then return false end
    local manager = rawget(_G, "QFXAddonManagerAPI")
    if not manager or type(manager.OpenAddonSettings) ~= "function" then
        return fn()
    end
    local original = manager.OpenAddonSettings
    manager.OpenAddonSettings = nil
    local ok, result = pcall(fn)
    manager.OpenAddonSettings = original
    if not ok then error(result) end
    return result
end

-- Only the two retained dedicated pages (QFXBeggar and QfxUI_Installer) use
-- this entry. Every other addon opens its own native options window.
function A.OpenEmbeddedSettings(name, tabKey)
    local manager = _G.QFXAddonManager
    if manager and manager.UI and manager.UI.OpenAddonSettingsWindow then
        return manager.UI.OpenAddonSettingsWindow(name, tabKey)
    end
    return false
end

-- Modern Settings requires the registered category ID, not its display name.
function A.NativeCategory(name)
    return A.NativeOptions(function()
        local panel, settings = rawget(_G, "SettingsPanel"), rawget(_G, "Settings")
        if not panel or not panel.GetAllCategories or not settings or not settings.OpenToCategory then return false end
        for _, category in ipairs(panel:GetAllCategories()) do
            if category:GetName() == name then
                settings.OpenToCategory(category:GetID())
                return true
            end
        end
        return false
    end)
end

-- Registration and layout only; plugin adapters own their APIs and settings.
function A.Register(name, data)
    if not A.IsInstalled(name) then return end
    data.adapted = true
    QFXAM.RegisterAddon(name, data)
    if QFXAM.RegisterModule then
        local key = data.key or string.lower(name)
        local previous = QFXAM.Modules and QFXAM.Modules.Get and QFXAM.Modules.Get(key)
        local module = {
            title = data.title or name, primary = name, addons = data.addons or { name },
            category = data.category, categories = data.categories, adapted = true,
            requirePrimary = true,
            tip = type(data.description) == "string" and data.description or nil,
        }
        -- Native settings registration retains an optional card's download data.
        if previous and previous.showWhenMissing then
            for _, field in ipairs({ "showWhenMissing", "prioritizeUnloaded", "titleCN", "titleEN", "author", "downloadURL", "companionNote", "companionURL" }) do
                module[field] = previous[field]
            end
            module.tip = module.tip or previous.tip
        end
        QFXAM.RegisterModule(key, module)
    end
end

-- Dropdown sources may be a resolver function, a plain { key = label } map or
-- a { { key = ..., label = ..., disabled = ... }, ... } list. Foreign models
-- must never reach the factory as raw functions.
local function ResolveDropdownItems(source)
    local items = source
    if type(items) == "function" then
        local ok, result = pcall(items)
        items = ok and result or nil
    end
    if type(items) ~= "table" then return nil end
    if type(items[1]) == "table" and items[1].key ~= nil then
        local values, order, unavailable = {}, {}, {}
        for i = 1, #items do
            local item = items[i]
            if item.key ~= nil then
                values[item.key], order[#order + 1], unavailable[item.key] = item.label, item.key, item.disabled
            end
        end
        return values, order, unavailable
    end
    return items
end

function A.Page(context, page)
    local W = context.Widgets
    local layout = { y = -W.Theme.pad, content = page.content }
    function layout:Section(title, note)
        if page.HasTitle and page:HasTitle(title) then
            if note and note ~= "" then self.y = W:Note(page.content, self.y, note) end
        else
            local _, height = W:SectionHeader(page.content, title, self.y, { note = note })
            self.y = self.y - height
        end
    end
    function layout:Note(text)
        self.y = W:Note(page.content, self.y, text)
    end
    function layout:CheckGrid(columns, entries, opts)
        local frame, height = W:CheckGrid(page.content, self.y, columns, entries, opts)
        self.y = self.y - height
        return frame
    end
    function layout:Row(config)
        if config.type == "dropdown" then
            local values, order, unavailable = ResolveDropdownItems(config.values)
            if order then
                config.values, config.order = values, order
                local set = config.setValue
                if set then config.setValue = function(value)
                    local disabled = unavailable[value]
                    if disabled == true or (type(disabled) == "function" and disabled()) then return end
                    set(value)
                end end
            elseif values then
                config.values = values
            end
        end
        if config.type ~= "label" then
            config.blockInCombat = config.blockInCombat ~= false
            config.combatTooltip = QFXAM.L.COMBAT_LOCKED_TIP
        end
        local setter = config.setValue
        if setter then config.setValue = function(...)
            if config.blockInCombat and W:InCombatLocked() then return end
            setter(...)
            if context.Refresh then context.Refresh() end
        end end
        local click = config.onClick
        if click then config.onClick = function(...)
            if config.blockInCombat and W:InCombatLocked() then return end
            click(...)
            if context.Refresh then context.Refresh() end
        end end
        local row, height = W:DualRow(page.content, self.y, config)
        self.y = self.y - height
        return row
    end
    function layout:Finish()
        page.cursor = -self.y
        page:SetContentHeight(-self.y + W.Theme.pad)
    end
    return layout
end
