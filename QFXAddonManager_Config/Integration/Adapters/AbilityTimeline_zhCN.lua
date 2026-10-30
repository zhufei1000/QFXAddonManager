local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("AbilityTimeline", "AbilityTimeline_zhCN") then return end
AM.AdapterUtils.Register("AbilityTimeline", { category = "combat", categories = {"raid"},
    addons = {"AbilityTimeline", "AbilityTimeline_zhCN"} })
AM.RegisterAddon("AbilityTimeline_zhCN", { technical = true, adapted = true })
