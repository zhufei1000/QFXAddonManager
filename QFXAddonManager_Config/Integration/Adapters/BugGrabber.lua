local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("!BugGrabber") then return end

-- Paired error collector/viewer; reuse the installed viewer's native artwork.
AM.AdapterUtils.Update("!BugGrabber", { getIcon = function()
    local texture = AM.API.GetAddOnMetadata("BugSack", "IconTexture")
    local atlas = AM.API.GetAddOnMetadata("BugSack", "IconAtlas")
    if texture == "" then texture = nil end
    if atlas == "" then atlas = nil end
    return texture, atlas
end })
AM.NotifyRegistrationChanged()
