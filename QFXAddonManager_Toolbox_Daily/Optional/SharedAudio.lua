local _, manager = ...
manager.ToolboxRuntime:AddFile("Optional", function(...)
local _, ns = ...
ns = _G.QFXAddonManagerToolboxNS or ns
if not ns then return end

-- QFXToolBox_Optional 包内共享的音频/图片解析与播放。
-- PlayerDeathAlert 使用这一份音频与图片解析实现：
-- 内置（builtin:xxx）+ LibSharedMedia-3.0 共享库 + 自定义文件路径。
-- 秘密值只做 issecretvalue 测试与 C 侧透传，不在 Lua 里比较/运算/拼接。

local Audio = {}
ns.OptionalAudio = Audio

Audio.BUILTIN_SOUNDS = {
    raid_warning = "Sound\\Interface\\RaidWarning.wav",
    ready_check = "Sound\\Interface\\ReadyCheck.wav",
    auction = "Sound\\Interface\\AuctionWindowOpen.wav",
}

Audio.BUILTIN_IMAGES = {
    skull = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
}

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

function Audio.GetSharedMedia()
    if ns.Compat and ns.Compat.GetSharedMedia then return ns.Compat.GetSharedMedia() end
    if not LibStub then return nil end
    local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and media and type(media.Fetch) == "function" then
        return media
    end
    return nil
end

-- "builtin:xxx" -> 内置路径；否则走共享声音库；解析不到返回 nil。
function Audio.ResolveSoundPath(name)
    if type(name) ~= "string" or name == "" then return nil end
    local builtinKey = name:match("^builtin:([%w_]+)$")
    if builtinKey then
        return Audio.BUILTIN_SOUNDS[builtinKey]
    end
    local media = Audio.GetSharedMedia()
    if not media then return nil end
    local ok, path = pcall(media.Fetch, media, "sound", name, true)
    if ok and type(path) == "string" and path ~= "" and not IsSecret(path) then
        return path
    end
    return nil
end

-- "builtin:xxx" -> 内置图片；否则走共享背景/边框库；解析不到返回 nil。
function Audio.ResolveImagePath(name)
    if type(name) ~= "string" or name == "" then return nil end
    local builtinKey = name:match("^builtin:([%w_]+)$")
    if builtinKey then
        return Audio.BUILTIN_IMAGES[builtinKey]
    end
    local media = Audio.GetSharedMedia()
    if not media then return nil end
    for _, kind in ipairs({ "background", "border" }) do
        local ok, path = pcall(media.Fetch, media, kind, name, true)
        if ok and type(path) == "string" and path ~= "" and not IsSecret(path) then
            return path
        end
    end
    return nil
end

function Audio.SpeakText(text)
    local frame = TextToSpeechFrame
    if frame and type(frame.Speak) == "function" and text and text ~= "" then
        local ok = pcall(frame.Speak, frame, text)
        if ok then return true end
    end
    return false
end

-- 直接播一个已解析的路径。返回 true = 播出声。
function Audio.PlaySoundPath(path)
    if type(path) ~= "string" or path == "" then return false end
    if type(PlaySoundFile) ~= "function" then return false end
    local ok, played = pcall(PlaySoundFile, path, "Master")
    return ok and played ~= false
end

-- 播共享名（内置/共享库），解析或播放失败时回退客户端朗读。
function Audio.PlaySoundName(name, fallbackText)
    if Audio.PlaySoundPath(Audio.ResolveSoundPath(name)) then
        return true
    end
    return Audio.SpeakText(fallbackText)
end

end)
