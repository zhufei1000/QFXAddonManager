local _, AM = ...

-- Verified project artwork; original TOC/native icons take priority.
-- Sources: docs/CF_PROJECT_ICONS.md and docs/NETEASE_DD_ICON.md.
local root = [[Interface\AddOns\QFXAddonManager\Media\ProjectIcons\]]
local icons = {
    ["LibSharedMedia-3.0"] = "curseforge-flame",
    HandyNotes = "handynotes",
    InspectForEllesmereUI = "inspect-for-ellesmereui",
    PetStatusAlert = "petstatusalert",
    QFXfocus = "qfxfocus.tga",
    QFXSkillAlerts = "qfxskillalerts.png",
    QFXTalents = "qfxtalents",
    QFXTalentData = "qfx-talent-data",
    QFXTalentData_MythicPlus = "qfx-talent-data",
    QFXTalentData_RaidHeroic = "qfx-talent-data",
    QFXTalentData_RaidMythic = "qfx-talent-data",
    ["163UI_Info"] = "netease-dd",
}
AM.ProjectIcons = {}
for name, file in pairs(icons) do
    local texture = root .. file .. (file:find("%.") and "" or ".blp")
    AM.ProjectIcons[name], AM.ProjectIcons[string.lower(name)] = texture, texture
end
-- This TOC points into an absent legacy UI bundle in the current installation.
-- Match the addon and exact old path; any replacement native TOC stays intact.
AM.TOCIconFallbacks = {
    ["163UI_Info"] = {
        [ [[Interface\AddOns\!!!163UI!!!\Media\Textures\UI2-logo]] ] = AM.ProjectIcons["163UI_Info"],
    },
}
if AM.NotifyRegistrationChanged then AM.NotifyRegistrationChanged() end
