local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local _, ns = ...
ns = _G.QFXAddonManagerToolboxNS or ns

local KEY = "fast_loot"
local enabled = false
local looting = false
local lootCycleHandled = false
local closeTimer
local closeCheckCount = 0

local CLOSE_CHECK_DELAY = 0.05
local MAX_CLOSE_CHECKS = 2

local SafeCall = ns.Compat.Call

local function GetAutoLootDefault()
    if ns.Compat and ns.Compat.GetCVarBool then
        return ns.Compat.GetCVarBool("autoLootDefault", false)
    end
    return false
end

local function IsAutoLooting(autoLoot)
    -- Newer clients pass autoLoot on LOOT_READY / LOOT_OPENED. Prefer that when present.
    if autoLoot ~= nil then
        return autoLoot and true or false
    end

    local defaultAutoLoot = GetAutoLootDefault()
    local toggleHeld = false
    if type(IsModifiedClick) == "function" then
        toggleHeld = IsModifiedClick("AUTOLOOTTOGGLE") and true or false
    end

    return (defaultAutoLoot and not toggleHeld) or ((not defaultAutoLoot) and toggleHeld)
end

local function SlotCanBeLooted(slot)
    if type(slot) ~= "number" then return false end

    if type(LootSlotHasItem) == "function" then
        local hasItem = SafeCall(LootSlotHasItem, slot)
        if hasItem then return true end
    end

    if type(GetLootSlotType) == "function" then
        local slotType = SafeCall(GetLootSlotType, slot)
        if slotType and slotType ~= 0 then return true end
    end

    -- Fallback for older clients where the helper APIs may be incomplete.
    return true
end

local function CloseLootIfEmpty()
    if not enabled or type(GetNumLootItems) ~= "function" then return false end
    local numItems = SafeCall(GetNumLootItems) or 0
    if numItems <= 0 and type(CloseLoot) == "function" then
        SafeCall(CloseLoot)
        return true
    end
    return false
end

local function CancelCloseTimer()
    closeCheckCount = 0
    if not closeTimer then return end

    if ns.Compat and ns.Compat.CancelTimer then
        ns.Compat.CancelTimer(closeTimer)
    elseif type(closeTimer.Cancel) == "function" then
        SafeCall(closeTimer.Cancel, closeTimer)
    end
    closeTimer = nil
end

local ScheduleCloseIfEmpty

local function OnCloseTimer()
    closeTimer = nil
    if not enabled or not lootCycleHandled then return end

    closeCheckCount = closeCheckCount + 1
    if CloseLootIfEmpty() then return end
    if closeCheckCount < MAX_CLOSE_CHECKS then
        ScheduleCloseIfEmpty()
    end
end

ScheduleCloseIfEmpty = function()
    if closeTimer then return end

    if ns.Compat and ns.Compat.NewTimer then
        closeTimer = ns.Compat.NewTimer(CLOSE_CHECK_DELAY, OnCloseTimer)
    elseif C_Timer and type(C_Timer.NewTimer) == "function" then
        closeTimer = C_Timer.NewTimer(CLOSE_CHECK_DELAY, OnCloseTimer)
    end

    if not closeTimer then
        CloseLootIfEmpty()
    end
end

local function LootAllSlots(autoLoot)
    if not enabled or looting or lootCycleHandled then return false end
    if not IsAutoLooting(autoLoot) then return false end
    if type(GetNumLootItems) ~= "function" or type(LootSlot) ~= "function" then return false end

    local numItems = SafeCall(GetNumLootItems) or 0
    if numItems <= 0 then return false end

    looting = true
    lootCycleHandled = true
    for slot = numItems, 1, -1 do
        if SlotCanBeLooted(slot) then
            SafeCall(LootSlot, slot)
        end
    end
    looting = false

    ScheduleCloseIfEmpty()
    return true
end

local EVENTS = { "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED" }

local function OnLootEvent(event, autoLoot)
    if event == "LOOT_READY" then
        -- LOOT_READY marks a new loot window. Reset here as well as on
        -- LOOT_CLOSED so a missed close event cannot disable fast loot.
        lootCycleHandled = false
        CancelCloseTimer()
        LootAllSlots(autoLoot)
    elseif event == "LOOT_OPENED" then
        -- Some clients only provide usable slots at LOOT_OPENED. If
        -- LOOT_READY already handled them, this is intentionally a no-op.
        LootAllSlots(autoLoot)
    elseif event == "LOOT_CLOSED" then
        lootCycleHandled = false
        looting = false
        CancelCloseTimer()
    end
end

local function RegisterEvents()
    if ns.RegisterModuleEvents then
        ns.RegisterModuleEvents(KEY, EVENTS, OnLootEvent)
    end
end

local function UnregisterEvents()
    if ns.UnregisterModuleEvents then
        ns.UnregisterModuleEvents(KEY, EVENTS)
    end
end

ns.RegisterModule(KEY, {
    titleKey = "Fast Loot",
    descKey = "Speeds up auto-looting without changing manual loot behavior.",
    defaults = ns.GetModuleDefaults(KEY),
    OnEnable = function()
        enabled = true
        RegisterEvents()
    end,
    OnDisable = function()
        enabled = false
        looting = false
        lootCycleHandled = false
        CancelCloseTimer()
        UnregisterEvents()
    end,
})

end)
