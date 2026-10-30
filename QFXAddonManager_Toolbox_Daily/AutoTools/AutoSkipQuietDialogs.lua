local _, manager = ...
manager.ToolboxRuntime:AddFile("AutoTools", function(...)
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

local KEY = "auto_skip_quiet_dialogs"
local mod = {}

local function L(key)
    return ns.L and ns.L(key) or key
end

local function DB()
    return ns.GetModuleDB(KEY)
end

local SafeCall = ns.Compat.SafeCall

local function SafeBoolCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function InAllowedLocation(db)
    if not db or db.onlyInInstance ~= true then return true end
    local inInstance = SafeBoolCall(IsInInstance)
    return inInstance and true or false
end

local function IsPausedByModifier(db)
    if not db or db.pauseOnModifier == false then return false end
    if type(IsModifierKeyDown) ~= "function" then return false end
    local pressed = SafeBoolCall(IsModifierKeyDown)
    return pressed and true or false
end

local function ShouldRun(db)
    if not db or not db.enabled then return false end
    if IsPausedByModifier(db) then return false end
    if not InAllowedLocation(db) then return false end
    return true
end

local function Stamp(db, key, text)
    if not db then return end

    -- Some clients can fire both an event and an OnShow hook for the same
    -- cinematic/movie. Keep the module event-driven, but avoid double-counting
    -- the same action in the same instant.
    local now = (type(GetTime) == "function" and GetTime()) or 0
    mod.lastStamp = mod.lastStamp or {}
    local last = mod.lastStamp[key]
    if last and now > 0 and (now - last) < 0.35 then return end
    mod.lastStamp[key] = now

    db[key] = (tonumber(db[key]) or 0) + 1
    db.lastAction = text or key
    db.lastActionTime = date and date("%H:%M:%S") or nil
    if db.verbose and ns.Print then
        ns.Print((text or key) .. " +1")
    end
end

local function TryCancelCinematic()
    -- Prefer Blizzard's normal cinematic cancel path when available.
    if type(CinematicFrame_CancelCinematic) == "function" then
        return SafeCall(CinematicFrame_CancelCinematic)
    end
    if C_Cinematic and type(C_Cinematic.StopCinematic) == "function" then
        return SafeCall(C_Cinematic.StopCinematic)
    end
    if type(StopCinematic) == "function" then
        return SafeCall(StopCinematic)
    end
    return false
end

local function HandleCinematicFrame()
    local db = DB()
    if not ShouldRun(db) or db.skipCinematics == false then return end
    if CinematicFrame and CinematicFrame.IsShown then
        local shown = SafeBoolCall(CinematicFrame.IsShown, CinematicFrame)
        if shown == false then return end
    end
    if TryCancelCinematic() then
        Stamp(db, "cinematicSkipped", L("Skipped Cinematic"))
    end
end

local function TryFinishMovie()
    -- Retail still exposes this path for MovieFrame-based movies. If the client
    -- removes/blocks it, do nothing and let the movie play normally.
    if type(CinematicFinished) == "function" then
        return SafeCall(CinematicFinished, 1)
    end
    if type(GameMovieFinished) == "function" then
        return SafeCall(GameMovieFinished)
    end
    if MovieFrame and type(MovieFrame.StopMovie) == "function" then
        return SafeCall(MovieFrame.StopMovie, MovieFrame)
    end
    return false
end

local function HandleMovieBeforePlay(...)
    local db = DB()
    if ShouldRun(db) and db.skipMovies ~= false then
        if TryFinishMovie() then
            Stamp(db, "movieSkipped", L("Skipped Movie"))
            return true
        end
    end
    if mod.originalMovieFramePlayMovie then
        return mod.originalMovieFramePlayMovie(...)
    end
    return nil
end

local function StopTalkingHeadVO(frame, db)
    if not frame or db.muteTalkingHead == false then return end
    local function stop()
        local handle = frame.voHandle
        if handle and type(StopSound) == "function" then
            local ok = SafeCall(StopSound, handle)
            if ok then Stamp(db, "talkingHeadMuted", L("Muted Talking Head")) end
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.025, stop)
    else
        stop()
    end
end

local function HandleTalkingHead(frame)
    local db = DB()
    if not ShouldRun(db) then return end
    frame = frame or TalkingHeadFrame
    if not frame then return end

    if db.hideTalkingHead ~= false and frame.Hide then
        local ok = SafeCall(frame.Hide, frame)
        if ok then Stamp(db, "talkingHeadHidden", L("Hidden Talking Head")) end
    end
    StopTalkingHeadVO(frame, db)
end

local function CleanText(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local SKIP_GOSSIP_KEYWORDS = {
    "<skip>", "skip", "i have heard", "heard this", "already heard", "don't need to hear", "do not need to hear",
    "跳过", "跳過", "略过", "略過", "我听过", "我聽過", "已经听过", "已經聽過", "不需要听", "不需要聽",
}

local function IsSkipGossipText(text)
    text = CleanText(text):lower()
    if text == "" then return false end
    for _, keyword in ipairs(SKIP_GOSSIP_KEYWORDS) do
        if text:find(keyword, 1, true) then return true end
    end
    return false
end

local function TrySelectGossipOption()
    if not C_GossipInfo or type(C_GossipInfo.GetOptions) ~= "function" then return false end
    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or type(options) ~= "table" then return false end

    for index, option in ipairs(options) do
        local text = option and (option.name or option.text or option.gossipOptionText)
        if IsSkipGossipText(text) then
            local optionID = option.gossipOptionID or option.gossipOptionId or option.optionID or option.id
            if optionID and C_GossipInfo.SelectOption then
                local selected = SafeCall(C_GossipInfo.SelectOption, optionID)
                if selected then return true, text end
            elseif type(SelectGossipOption) == "function" then
                local selected = SafeCall(SelectGossipOption, index)
                if selected then return true, text end
            end
        end
    end
    return false
end

local function OnEvent(self, event, ...)
    local db = DB()
    if event == "GOSSIP_SHOW" then
        if ShouldRun(db) and db.skipStoryGossip == true then
            local ok, text = TrySelectGossipOption()
            if ok then Stamp(db, "gossipSkipped", L("Skipped Gossip") .. "：" .. CleanText(text)) end
        end
    elseif event == "CINEMATIC_START" then
        HandleCinematicFrame()
    elseif event == "PLAY_MOVIE" then
        -- Some clients fire PLAY_MOVIE instead of going through MovieFrame_PlayMovie.
        if ShouldRun(db) and db.skipMovies ~= false then
            if TryFinishMovie() then Stamp(db, "movieSkipped", L("Skipped Movie")) end
        end
    end
end

local function UpdateEvents(db)
    if not mod.eventFrame then return end
    mod.eventFrame:UnregisterAllEvents()
    if not db or not db.enabled then return end

    if db.skipStoryGossip == true then
        mod.eventFrame:RegisterEvent("GOSSIP_SHOW")
    end
    if db.skipCinematics ~= false then
        mod.eventFrame:RegisterEvent("CINEMATIC_START")
    end
    if db.skipMovies ~= false then
        mod.eventFrame:RegisterEvent("PLAY_MOVIE")
    end
end

local function InstallHooks()
    if mod.hooksInstalled then return end
    mod.hooksInstalled = true

    if not mod.eventFrame then
        mod.eventFrame = CreateFrame("Frame")
        mod.eventFrame:SetScript("OnEvent", OnEvent)
    end

    if CinematicFrame and CinematicFrame.HookScript then
        CinematicFrame:HookScript("OnShow", function()
            HandleCinematicFrame()
        end)
    end

    if type(_G.MovieFrame_PlayMovie) == "function" and not mod.movieHookInstalled then
        mod.movieHookInstalled = true
        mod.originalMovieFramePlayMovie = _G.MovieFrame_PlayMovie
        _G.MovieFrame_PlayMovie = function(...)
            return HandleMovieBeforePlay(...)
        end
    end

    if TalkingHeadFrame and type(hooksecurefunc) == "function" and not mod.talkingHeadHookInstalled then
        mod.talkingHeadHookInstalled = true
        hooksecurefunc(TalkingHeadFrame, "PlayCurrent", function(self)
            HandleTalkingHead(self)
        end)
    end
end

function mod:OnInitialize(db)
    InstallHooks()
    UpdateEvents(db)
end

function mod:OnEnable(db)
    InstallHooks()
    UpdateEvents(db)
end

function mod:OnDisable(db)
    UpdateEvents(db)
end

function mod:ApplySettings(db)
    InstallHooks()
    UpdateEvents(db)
end

local function EnabledRule(db, ui)
    return function()
        if not db.enabled then return false, ui.L("Enable this tool first.") end
        return true
    end
end

local function StatusLine(db, ui)
    local last = db.lastAction or ui.L("N/A")
    if db.lastActionTime then last = tostring(db.lastActionTime) .. " " .. tostring(last) end
    return string.format("%s：%s | CG=%d, Movie=%d, Head=%d, VO=%d, Gossip=%d",
        ui.L("Last Action"), tostring(last),
        tonumber(db.cinematicSkipped) or 0,
        tonumber(db.movieSkipped) or 0,
        tonumber(db.talkingHeadHidden) or 0,
        tonumber(db.talkingHeadMuted) or 0,
        tonumber(db.gossipSkipped) or 0)
end

ns.RegisterModule(KEY, {
    titleKey = "Auto Skip & Quiet Dialogs",
    descKey = "Automatically skips skippable cinematics/movies and hides talking-head dialogs when they appear.",
    defaults = ns.GetModuleDefaults(KEY),
    OnInitialize = function(info, db) mod:OnInitialize(db) end,
    OnEnable = function(info, db) mod:OnEnable(db) end,
    OnDisable = function(info, db) mod:OnDisable(db) end,
    ApplySettings = function(info, db) mod:ApplySettings(db) end,
    tabs = {
        {
            key = "basic",
            titleKey = "Basic",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Auto Skip & Quiet Dialogs") .. " / " .. ui.L("Basic"))
                s:CheckGrid({
                    { label = ui.L("Enable"),                  getValue = function() return db.enabled end,                  setValue = function(
                        v) ns.SetModuleEnabled(KEY, v) end,                                                                                                                                                            note = ui.L(info.descKey or "") },
                    { label = ui.L("Skip Cinematics"),         getValue = function() return db.skipCinematics ~= false end,  setValue = function(
                        v)
                        db.skipCinematics = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui),  note = ui.L("Runs only when a cinematic starts; no OnUpdate polling is used.") },
                    { label = ui.L("Skip Movies"),             getValue = function() return db.skipMovies ~= false end,      setValue = function(
                        v)
                        db.skipMovies = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui),  note = ui.L("Runs only when MovieFrame starts playing and falls back if the client cannot skip it.") },
                    { label = ui.L("Hide Talking Head"),       getValue = function() return db.hideTalkingHead ~= false end, setValue = function(
                        v)
                        db.hideTalkingHead = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui),  note = ui.L("Hides the large NPC talking-head popup after Blizzard starts it.") },
                    { label = ui.L("Mute Talking Head Voice"), getValue = function() return db.muteTalkingHead ~= false end, setValue = function(
                        v)
                        db.muteTalkingHead = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui),  note = ui.L("Stops only the talking-head voice handle; other game sounds are not touched.") },
                    { label = ui.L("Hold Modifier to Watch"),  getValue = function() return db.pauseOnModifier ~= false end, setValue = function(
                        v)
                        db.pauseOnModifier = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui),  note = ui.L("Hold Shift/Ctrl/Alt to temporarily pause auto skip.") },
                    { label = ui.L("Only in Instances"),       getValue = function() return db.onlyInInstance == true end,   setValue = function(
                        v)
                        db.onlyInInstance = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui),  note = ui.L("When enabled, outdoor quests and city dialogs are left untouched.") },
                    { label = ui.L("Verbose Chat"),            getValue = function() return db.verbose == true end,          setValue = function(
                        v)
                        db.verbose = v and true or false; ns.ApplyModule(KEY)
                    end,                                                                                                                                                                                               enabled = EnabledRule(db, ui) },
                }, { columns = 2 })
                page:AddSection(s)

                local s2 = page:NewSection(ui.L("Status"))
                s2:DynamicText(function() return StatusLine(db, ui) end, ui.Colors.warning, 44)
                s2:ButtonRow({
                    {
                        text = ui.L("Reset Statistics"),
                        width = 118,
                        onClick = function()
                            db.cinematicSkipped = 0
                            db.movieSkipped = 0
                            db.talkingHeadHidden = 0
                            db.talkingHeadMuted = 0
                            db.gossipSkipped = 0
                            db.lastAction = nil
                            db.lastActionTime = nil
                            ui.Refresh()
                        end
                    },
                })
                page:AddSection(s2)
            end,
        },
        {
            key = "advanced",
            titleKey = "Advanced",
            build = function(page, db, info, ui)
                local s = page:NewSection(ui.L("Auto Skip & Quiet Dialogs") .. " / " .. ui.L("Advanced"))
                s:Check(ui.L("Skip Story Gossip"), function() return db.skipStoryGossip == true end, function(v)
                    db.skipStoryGossip = v and true or false
                    ns.ApplyModule(KEY)
                end,
                    ui.L(
                    "Optional and conservative: only clicks gossip choices whose text clearly contains skip/already-heard keywords."),
                    { enabled = EnabledRule(db, ui) })
                page:AddSection(s)
            end,
        },
    },
})

end)
