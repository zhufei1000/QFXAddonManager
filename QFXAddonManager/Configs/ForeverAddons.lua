local _, AM = ...

-- The published QFXfocus download currently targets Retail.
local focus = AM.Modules.Get("qfxfocus")
focus.showWhenMissing, focus.prioritizeUnloaded = false, false
local pet = AM.Modules.Get("petstatusalert")
pet.titleCN, pet.tip = AM.L.PSA_FOREVER_TITLE, AM.L.PSA_FOREVER_DESCRIPTION

-- These companion packages lack the usual parent prefix or required TOC
-- dependency. Declare their owner before login restores addon power states.
local function RegisterFamily(name, category, support)
    local addons = {name}
    for _, child in ipairs(support) do
        AM.RegisterAddon(child, {technical = true, adapted = true})
        addons[#addons + 1] = child
    end
    AM.RegisterAddon(name, {category = category, adapted = true})
    AM.RegisterModule(name:lower(), {
        title = name, category = category, primary = name, addons = addons,
        adapted = true, requirePrimary = true,
    })
end

RegisterFamily("Questie", "map", {"QuestieDB"})
RegisterFamily("Spoken", "tool", {
    "SpokenAll", "SpokenContributions", "SpokenQuestsAudioShared",
    "SpokenQuestsAudioAlliance", "SpokenQuestsAudioHorde",
    "SpokenQuestsAudioGossip", "SpokenPlacesAudio", "SpokenReadablesAudio",
})

-- Required dependencies or prefixes already supply parent relationships.
-- Only pure data and options packages are hidden from the right-hand cards.
local technical = {
    "GatherMate2_Data",
    "ForeverAurasOptions", "ForeverAurasArchive", "ForeverAurasModelPaths", "ForeverAurasTemplates",
    "AtlasLootClassic_Options", "AtlasLootClassic_Data", "AtlasLootClassic_Collections",
    "AtlasLootClassic_Crafting", "AtlasLootClassic_DungeonsAndRaids", "AtlasLootClassic_Factions", "AtlasLootClassic_PvP",
    "AtlasLootContinued_Options", "AtlasLootContinued_Data", "AtlasLootContinued_Collections",
    "AtlasLootContinued_Crafting", "AtlasLootContinued_DungeonsAndRaids", "AtlasLootContinued_Factions", "AtlasLootContinued_PvP",
}
for _, class in ipairs({"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}) do
    technical[#technical + 1] = "GearQuestForever_" .. class
end
for _, name in ipairs(technical) do
    AM.RegisterAddon(name, {technical = true, adapted = true})
end
