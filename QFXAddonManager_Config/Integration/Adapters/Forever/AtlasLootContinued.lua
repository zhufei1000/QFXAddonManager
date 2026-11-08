local AM = _G.QFXAddonManager or select(2, ...)
local A = AM.AdapterUtils
if not A.IsInstalled("AtlasLootContinued") then return end

A.Register("AtlasLootContinued", {
    category = "equipment", sourceURL = "https://www.curseforge.com/wow/addons/atlasloot-continued",
    nativeOptions = true,
    openOptions = A.NativeOptions(function()
        local atlas = rawget(_G, "AtlasLoot")
        -- Both forks publish the same global. Verify which one owns it.
        if type(atlas) ~= "table" or not tostring(atlas):match("^AtlasLootContinued%-") then return false end
        local commands = atlas.SlashCommands
        if not commands or type(commands.Run) ~= "function" then return false end
        return commands:Run("options")
    end),
})
