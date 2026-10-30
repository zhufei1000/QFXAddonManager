local _, AM = ...
local API, L = AM.API, AM.L
local guard = { names = {}, failed = {}, shown = false }
AM.LegacyToolboxGuard = guard

function AM.IsLegacyToolboxAddon(name)
    if type(name) ~= "string" then return false end
    name = name:lower()
    return name == "qfxtoolbox" or name:match("^qfxtoolbox_") ~= nil
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function MigrationMayBeRemoved()
    local R = AM.ToolboxRuntime
    return R and (R.migrationPersisted or R.legacyAbsent)
end

function guard:Check()
    if InCombat() then self.pendingCheck = true; return end
    self.pendingCheck = nil
    local names, failed, changed, loaded, featureChanged = {}, {}, false, false, false
    for index = 1, API.GetNumAddOns() do
        local name = API.GetAddOnInfo(index)
        if AM.IsLegacyToolboxAddon(name) then
            local bridge = name:lower() == "qfxtoolbox" and API.GetAddOnMetadata
                and API.GetAddOnMetadata(name, "X-QFX-Toolbox-Migration") == "1"
            local R = AM.ToolboxRuntime
            local db = rawget(_G, "QFXAddonManagerDB")
            local emptyBridge = bridge and ((R and R.legacyAbsent)
                or (db and db.toolboxMigrationVersion == 1 and db.toolboxMigrationSource == "no-legacy-save"))
            if not emptyBridge then names[#names + 1] = name end
            if not bridge and API.IsAddOnLoaded(name) then loaded = true end
            -- A harmless data-only bridge must stay loadable until its data
            -- has been saved by the manager and read back on the next login.
            if name:lower() == "qfxtoolbox" and (not bridge or MigrationMayBeRemoved())
                and API.GetAddOnEnableState(name) ~= 0 then
                API.DisableAddOn(name)
                if API.GetAddOnEnableState(name) == 0 then
                    changed = true
                    if not bridge then featureChanged = true end
                else
                    failed[#failed + 1] = name
                end
            end
        end
    end
    table.sort(names)
    table.sort(failed)
    self.names, self.failed = names, failed
    self.needsReload = self.needsReload or featureChanged or loaded
    if changed then API.SaveAddOns() end
    if self.needsReload then
        if AM.MarkReloadRequired then AM.MarkReloadRequired()
        else AM.reloadRequired = true end
    end
end

function guard:ShowNotice(fromQueue)
    if self.shown or self.showing or #self.names == 0 then return end
    if AM.NoticeQueue and not fromQueue then
        AM.NoticeQueue:Enqueue("toolbox-migration", 100, function()
            self:Check()
            return self:ShowNotice(true)
        end)
        return
    end
    if InCombat() then self.pendingNotice = true; return end
    self.showing = true
    local ready = AM.EnsureConfigLoaded and AM.EnsureConfigLoaded()
    local W = ready and AM.GetWidgets and AM.GetWidgets()
    self.showing = nil
    if not (W and W.Confirm) then return end
    local R = AM.ToolboxRuntime
    local choice = R and R.pendingLegacyDB ~= nil
    local awaitingSave = R and R.migrationSavePending and not R.legacyAbsent
    local unverified = R and not R.migrationPersisted and not R.legacyCaptured
    local needsReload = self.needsReload or awaitingSave
    local text
    if choice then
        text = L.TOOLBOX_MIGRATION_CHOICE
    elseif awaitingSave then
        text = L.TOOLBOX_MIGRATION_SAVE
    elseif unverified then
        text = L.TOOLBOX_MIGRATION_REQUIRED
    else
        text = L.LEGACY_TOOLBOX_REMOVAL
    end
    text = text .. "\n\n" .. table.concat(self.names, "\n")
    if #self.failed > 0 then
        text = text .. "\n\n" .. L.LEGACY_TOOLBOX_DISABLE_FAILED .. "\n" .. table.concat(self.failed, "\n")
    elseif not choice and not awaitingSave and not unverified then
        text = L.LEGACY_TOOLBOX_DISABLED .. "\n\n" .. text
    end
    if needsReload and not choice and not awaitingSave then text = text .. "\n\n" .. L.LEGACY_TOOLBOX_RELOAD end
    local function Choose(useLegacy)
        if InCombat() then
            self.shown, self.pendingNotice = false, true
            return
        end
        if R:ChooseLegacyDB(useLegacy) then API.OpenReloadDialog() end
    end
    self.shown, self.pendingNotice = true, nil
    self.dialog = W:Confirm({
        title = L.LEGACY_TOOLBOX_TITLE, text = text, width = 500,
        acceptText = choice and L.TOOLBOX_MIGRATION_USE_OLD or needsReload and L.RELOAD_UI or L.CLOSE,
        cancelText = L.LEGACY_TOOLBOX_LATER,
        onAccept = function()
            if choice then Choose(true); return end
            if not needsReload then return end
            if InCombat() then
                self.shown, self.pendingNotice = false, true
                return
            end
            API.OpenReloadDialog()
        end,
    })
    if choice then
        local scope = W._refreshScope
        local keep = W:DetachedControl(self.dialog._panel, "button", {
            text = L.TOOLBOX_MIGRATION_KEEP_CURRENT, width = 150, height = 24,
        })
        W._refreshScope = scope
        keep:SetPoint("BOTTOMLEFT", self.dialog._panel, "BOTTOMLEFT", 14, 12)
        keep:SetScript("OnClick", function()
            if InCombat() then return end
            self.dialog:Close(false)
            Choose(false)
        end)
        self.dialog.keepCurrent = keep
    end
    return self.dialog
end

local frame = CreateFrame("Frame")
guard.eventFrame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
local function QueueNotice()
    if guard.noticeQueued or guard.shown or #guard.names == 0 then return end
    guard.noticeQueued = true
    C_Timer.After(0, function()
        guard.noticeQueued = nil
        guard:Check()
        guard:ShowNotice()
    end)
end
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        guard.loggedIn = true
        guard:Check()
        QueueNotice()
    elseif event == "ADDON_LOADED" and (name == AM.name or AM.IsLegacyToolboxAddon(name)) then
        guard:Check()
        if guard.loggedIn then QueueNotice() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if guard.pendingCheck then guard:Check() end
        if guard.loggedIn and (guard.pendingNotice or not guard.shown) then QueueNotice() end
    end
end)

-- Run before the built-in toolbox starts, so old packages still waiting in
-- the login queue can be disabled before their own startup handlers run.
guard:Check()
