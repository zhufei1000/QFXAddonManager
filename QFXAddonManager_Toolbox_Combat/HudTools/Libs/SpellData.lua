local _, manager = ...
manager.ToolboxRuntime:AddFile("HudTools", function(...)
local addonName = ...
local ns = _G.QFXAddonManagerToolboxNS
if not ns then return end

-- Resolve candidates against the active spellbook before checking range.
--
-- Entries may be a spell ID or { spellID, fallbackMaxRange }. The fallback is
-- used only when live spell data reports no usable maximum range (mainly melee).
ns.LibRangeCheckQFXSpellData = {
    commonFriend = { 28880 }, -- Gift of the Naaru, filtered by active spellbook

    EVOKER = {
        harm = { 362969 },
        friend = { 355913, 361469, 360823 },
        res = { 361227 },
    },
    DEATHKNIGHT = {
        harm = { 49576, 47541 },
        res = { 61999 },
    },
    DEMONHUNTER = {
        harm = { 185123, 183752, 204021 },
    },
    DRUID = {
        harm = { 5176, 339, 6795, 33786, { 22568, 5 }, 8921 },
        friend = { 8936, 774, 2782, 88423 },
        res = { 50769, 20484 },
    },
    HUNTER = {
        harm = { 466930, 75 },
        pet = { 136 },
    },
    MAGE = {
        harm = { 44614, 5019, 118, 116, 133, 44425 },
        friend = { 1459, 475 },
    },
    MONK = {
        harm = { 115546, 115078, { 100780, 5 }, 117952 },
        friend = { 115450, 115546, 116670 },
        res = { 115178 },
    },
    PALADIN = {
        harm = { 853, { 35395, 5 }, 62124, 183218, 20271, 20473 },
        friend = { 19750, 85673, 4987, 213644 },
        res = { 7328 },
    },
    PRIEST = {
        harm = { 589, 8092, 585, 5019 },
        friend = { 21562, 17, 527, 2061 },
        res = { 2006 },
    },
    ROGUE = {
        harm = { 185565, 36554, 185763, 2094, 921 },
        friend = { 36554, 921 },
    },
    SHAMAN = {
        harm = { 370, 8042, 117014, 188196, { 73899, 5 } },
        friend = { 546, 8004, 188070 },
        res = { 2008 },
    },
    WARLOCK = {
        harm = { 234153, 198590, 232670, 5019, 686, 5782 },
        friend = { 20707, 5697 },
        res = { 20707 },
        pet = { 755 },
    },
    WARRIOR = {
        harm = { 355, 5246, 100 },
    },
}

if ns.Compat and ns.Compat.IsForever and ns.Compat.IsForever() then
    local rankedProbes = {
        DRUID = { 9912, 9835, { 9830, 5 }, { 9904, 5 }, { 9881, 5 }, { 9908, 5 } },
        HUNTER = { 14287 },
        MAGE = { 25306, 25304 },
        PALADIN = { 10314 },
        PRIEST = { 10934, 10894 },
        ROGUE = { { 11294, 5 } },
        SHAMAN = { 15208 },
        WARLOCK = { 25307, 25311 },
        WARRIOR = { { 25286, 5 } },
    }
    for class, ranked in pairs(rankedProbes) do
        local harm = ns.LibRangeCheckQFXSpellData[class].harm
        for i = 1, #ranked do
            harm[#harm + 1] = ranked[i]
        end
    end
end

end)
