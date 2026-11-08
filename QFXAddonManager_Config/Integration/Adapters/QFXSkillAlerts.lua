local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXSkillAlerts") then return end
local A = AM.AdapterUtils

local function Open()
    local NS = rawget(_G, "QFXSkillAlertsNS")
    if not NS then return false end
    if type(NS.LoadConfigAddon) == "function" and not NS.LoadConfigAddon() then return false end
    if NS.UI and NS.UI.MainFrame then return NS.UI.MainFrame:Open() end
    return false
end

A.Register("QFXSkillAlerts", { category = "combat", categories = {"class"},
    addons = {"QFXSkillAlerts", "QFXSkillAlerts_Config"}, nativeOptions = true, openOptions = Open,
    description = function() return AM.L.SKILLALERTS_DESCRIPTION end })
local function HasSavedAlerts(db)
    if type(db.visualGroups) == "table" and type(db.visualGroups.groups) == "table"
        and next(db.visualGroups.groups) then return true end
    if type(db.deletedEntries) == "table" then
        for _, values in pairs(db.deletedEntries) do
            if type(values) == "table" and next(values) then return true end
        end
    end
    for _, key in ipairs({"specConfigs", "castSuccessConfigs", "cdmVoiceProfiles"}) do
        for _, classMap in pairs(type(db[key]) == "table" and db[key] or {}) do
            for _, specMap in pairs(type(classMap) == "table" and classMap or {}) do
                if type(specMap) == "table" and next(specMap) then return true end
            end
        end
    end
    for _, classMap in pairs(type(db.collectionData) == "table" and db.collectionData or {}) do
        for _, scope in pairs(type(classMap) == "table" and classMap or {}) do
            if type(scope) == "table" and type(scope.groups) == "table" and next(scope.groups) then return true end
        end
    end
    local bloodlust = db.bloodlustConfig or {}
    for _, key in ipairs({"soundPath", "builtinSoundPath", "customSoundPath", "sharedMediaSound", "ttsText"}) do
        if type(bloodlust[key]) == "string" and bloodlust[key]:match("%S") then return true end
    end
    for _, path in pairs(bloodlust.customSoundPaths or {}) do
        if type(path) == "string" and path:match("%S") then return true end
    end
    return false
end

if AM.SkillAlertsPresetData then
    A.Update("QFXSkillAlerts", {preset = {
        version = AM.SkillAlertsPresetData.version,
        target = function() return rawget(_G, "QFXSkillAlertsDB") end,
        apply = function(_, target, _, force)
            if type(target) ~= "table" then error("QFXSkillAlerts database is not ready") end
            -- Existing rules are user data. Only explicit Restore may replace them.
            if not force and HasSavedAlerts(target) then return end
            local NS = rawget(_G, "QFXSkillAlertsNS")
            if not NS or type(NS.LoadConfigAddon) ~= "function" or not NS.LoadConfigAddon() then
                error("QFXSkillAlerts config is not ready")
            end
            local codec = NS.ImportCodec
            if not codec or type(codec.Decode) ~= "function" then error("QFXSkillAlerts import codec is unavailable") end
            local payload, reason = codec:Decode(AM.SkillAlertsPresetData.encoded)
            if not payload or payload.type ~= "managerPreset" or type(payload.values) ~= "table" then
                error(reason or "Invalid QFXSkillAlerts package preset")
            end
            local api = NS.API
            if not api or type(api.RefreshCDMVoiceRegistry) ~= "function" then
                error("QFXSkillAlerts API is not ready")
            end
            -- Replace each declared configuration subtree while preserving the
            -- profile table, AceDB references and unrelated player settings.
            local copy = {}
            AM.Presets.Merge(copy, payload.values)
            for key, value in pairs(copy) do target[key] = value end
            target.cdmVoicePendingRemovals = {}
            target.cdmVoiceApplyState = {applyInProgress = false}
            target.cdmVoiceSyncState = {
                importedVersion = AM.SkillAlertsPresetData.version,
                pendingRuntimeReload = false,
            }
            api.RefreshCDMVoiceRegistry()
            local sync = NS.Core and NS.Core.CDMVoicePresetSync
            if sync and sync.AdvanceScope then sync:AdvanceScope() end
            if sync and sync.ResetPromptForCurrentScope then sync:ResetPromptForCurrentScope() end
            if sync and sync.ScheduleEvaluation then
                sync:ScheduleEvaluation("manager-preset", {prompt = true, promptKind = "import"})
            end
            if NS.ImportRefreshScheduler then
                NS.ImportRefreshScheduler:Schedule("manager-preset")
            else
                AM.MarkReloadRequired()
            end
        end,
    }})
end
