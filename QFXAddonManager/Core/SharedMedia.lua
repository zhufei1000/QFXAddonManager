local _, QFXAM = ...
local registered = false

-- Keep the legacy asset root: saved voice, image and texture paths use it.
local ROOT = "Interface\\AddOns\\QFX_SharedMedia\\Media\\"

local statusbars = {
    { "QFX Smooth", "QFX_Smooth.tga" },
    { "QFX Blizzard Soft", "QFX_BlizzardSoft.tga" },
    { "QFX Dragonline", "QFX_Dragonline.tga" },
    { "QFX Skyline", "QFX_Skyline.tga" },
    { "QFX Stripes", "QFX_Stripes.tga" },
    { "QFX Thin Stripes", "QFX_ThinStripes.tga" },
    { "QFX Deep Glass", "QFX_DeepGlass.tga" },
    { "QFX Complex Gradient 1", "QFX_ComplexGradient1.tga" },
    { "QFX Complex Gradient 2", "QFX_ComplexGradient2.tga" },
    { "QFX Complex Gradient 5", "QFX_ComplexGradient5.tga" },
    { "QFX 3D Glass", "QFX_3DGlass.tga" },
    { "QFX Gloss Fill", "QFX_GlossFill.tga" },
    { "QFX Dark Bevel", "QFX_DarkBevel.tga" },
    { "QFX Live Player Health", "QFX_Live_PlayerHealth_mMediaTagG1.tga" },
    { "QFX Live Nameplate", "QFX_Live_Nameplate_mMediaTagB4.tga" },
    { "QFX Live Nameplate Slant 60", "QFX_Live_Nameplate_Slant60.tga" },
    { "QFX Live Party Frames", "QFX_Live_PartyFrames_mMediaTagB1.tga" },
    { "mMediaTag G1", "QFX_Live_PlayerHealth_mMediaTagG1.tga" },
    { "mMediaTag B4", "QFX_Live_Nameplate_mMediaTagB4.tga" },
    { "mMediaTag B1", "QFX_Live_PartyFrames_mMediaTagB1.tga" },
}

local images = {
    { "QFX Personal Tag Red White", "QFX_PersonalTag_RedWhite.tga" },
    { "QFX Personal Tag Red Black", "QFX_PersonalTag_RedBlack.tga" },
    { "QFX Personal Tag Red Gold", "QFX_PersonalTag_RedGold.tga" },
}

local sounds = {
    { "QFX iPhone", "iphone.ogg" },
    { "QFX 你有新的订单", "你有新的订单.ogg" },
    { "QFX 冲锋号", "冲锋号.ogg" },
    { "QFX 广寒宫破阵曲", "广寒宫破阵曲.ogg" },
    { "QFX 拔剑声", "拔剑声.ogg" },
    { "QFX 枪声", "枪声.ogg" },
    { "QFX 枪声 2", "枪声2.ogg" },
    { "QFX 水滴声", "水滴声.ogg" },
    { "QFX 火花", "火花.ogg" },
    { "QFX 狼嚎", "狼嚎.ogg" },
    { "QFX 短信提示音", "短信提示音.ogg" },
    { "QFX Bankai", "bankai.ogg" },
    { "QFX Jianlai", "jianlai.ogg" },
    { "QFX Xiyaoshi", "xiyaoshi.ogg" },
    { "QFX Alarm", "Alarm.ogg" },
    { "QFX Alert", "Alert.ogg" },
    { "QFX Info", "Info.ogg" },
    { "QFX Long", "Long.ogg" },
    { "QFX Spell On You", "spell_on_you.ogg" },
    { "QFX Spell Under You", "spell_under_you.ogg" },
    { "QFX Defeat", "defeat.ogg" },
    { "QFX Victory", "victory.ogg" },
    { "QFX Victory 1", "Victory1.ogg" },
    { "QFX Victory Classic", "VictoryClassic.ogg" },
    { "QFX Victory Long", "VictoryLong.ogg" },
}

function QFXAM.RegisterSharedMedia()
    if registered then return true end
    local stub = _G.LibStub
    local media = stub and stub("LibSharedMedia-3.0", true)
    if not (media and media.Register) then return false end

    for _, item in ipairs(statusbars) do
        media:Register("statusbar", item[1], ROOT .. "Textures\\Statusbar\\" .. item[2])
    end
    media:Register("statusbar", "QFX Blizzard Raid Health", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    media:Register("statusbar", "QFX Blizzard Raid Power", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill")
    for _, item in ipairs(images) do
        media:Register("background", item[1], ROOT .. "Textures\\PersonalTags\\" .. item[2])
    end
    for _, item in ipairs(sounds) do
        media:Register("sound", item[1], ROOT .. "Sounds\\" .. item[2])
    end
    registered = true
    return true
end
