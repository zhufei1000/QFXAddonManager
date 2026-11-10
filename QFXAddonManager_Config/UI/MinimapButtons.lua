local AM = _G.QFXAddonManager
local UI, L = AM.UI, AM.L

local collectors = {
    "QFXMinimapTools", "EllesmereUIMinimap", "MinimapButtonButton",
    "MBB", "MinimapButtonBag", "MinimapButtonDrawer", "ButtonCollector", "HidingBar",
}
local namedButtons = { Lueur = "LueurMinimapButton" }
local collected = {}
local holder, confirm, watchedLibrary, rescanPending

local function Enabled()
    return AM.db.ui.collectMinimapButtons == true
end

local function RefreshManager()
    if UI.frame and UI.frame:IsVisible() then UI.Refresh() end
end

local function FindCollector()
    for _, name in ipairs(collectors) do
        if AM.API.IsAddOnLoaded(name) then return name end
    end
end

local function CanMove(button)
    return button and not button:IsForbidden() and not button:IsProtected()
end

local function HasManagerEntry(name)
    local entry = AM.Registry.Get(name)
    local owner = entry and entry.name or name
    local info = AM.Cache.addons[owner] or AM.Cache.addons[owner:lower()]
    return info and not info.technical and info.name ~= AM.name
        and (info.adapted or AM.Registry.IsAdapted(info.name))
        and AM.API.IsAddOnLoaded(info.name)
        and AM.Registry.GetOpenOptions(info.name)
end

local function Collect(button, owner)
    if not CanMove(button) or button:GetParent() ~= Minimap or not HasManagerEntry(owner) then return end
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
    end
    -- Inherit invisibility without changing the owning addon's shown flag,
    -- saved minimap settings, button scripts, or anchors.
    button:SetParent(holder)
    collected[button] = true
end

local function Stop()
    AM.db.ui.collectMinimapButtons = false
    if watchedLibrary then
        watchedLibrary.UnregisterCallback(collected, "LibDBIcon_IconCreated")
        watchedLibrary = nil
    end
    for button in pairs(collected) do
        if CanMove(button) and button:GetParent() == holder then button:SetParent(Minimap) end
        collected[button] = nil
    end
end

local function QueueRescan()
    if rescanPending then return end
    rescanPending = true
    C_Timer.After(0, function()
        rescanPending = nil
        AM.RefreshMinimapButtons()
    end)
end

function AM.RefreshMinimapButtons()
    if not Enabled() or not Minimap or UI.GetWidgets():InCombatLocked() then return end
    local conflict = FindCollector()
    if conflict then
        Stop()
        AM.Print(string.format(L.MINIMAP_BUTTONS_CONFLICT, conflict))
        RefreshManager()
        return
    end
    local library = LibStub and LibStub("LibDBIcon-1.0", true)
    if library and library.GetButtonList and library.GetMinimapButton then
        if not watchedLibrary and library.RegisterCallback and library.UnregisterCallback then
            library.RegisterCallback(collected, "LibDBIcon_IconCreated", QueueRescan)
            watchedLibrary = library
        end
        for _, name in ipairs(library:GetButtonList()) do Collect(library:GetMinimapButton(name), name) end
    end
    for owner, name in pairs(namedButtons) do Collect(_G[name], owner) end
end

local function SetEnabled(on)
    local W = UI.GetWidgets()
    if W:InCombatLocked() then return end
    if not on then Stop(); return end
    -- The factory paints the clicked value after setValue returns.
    C_Timer.After(0, RefreshManager)
    confirm = W:Confirm({
        reuse = confirm, title = L.MINIMAP_BUTTONS_TITLE, text = L.MINIMAP_BUTTONS_CONFIRM,
        acceptText = L.ENABLE, cancelText = L.CANCEL,
        onAccept = function()
            if W:InCombatLocked() then return end
            local conflict = FindCollector()
            if conflict then AM.Print(string.format(L.MINIMAP_BUTTONS_CONFLICT, conflict)); return end
            AM.db.ui.collectMinimapButtons = true
            AM.RefreshMinimapButtons()
            RefreshManager()
        end,
    })
end

AM.Toolbox.RegisterSummarySwitch("minimapButtons", {
    title = L.MINIMAP_BUTTONS_TITLE, description = L.MINIMAP_BUTTONS_DESC,
    get = Enabled, set = SetEnabled,
})
