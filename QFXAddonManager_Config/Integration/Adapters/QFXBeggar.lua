local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXBeggar") then return end
local A = AM.AdapterUtils
local definition, context
local function Settings(ctx)
    local addon = rawget(_G, "QFXBeggar")
    if not addon or not addon.db then return end
    context = ctx
    if definition then return definition end
    local L = addon.L
    definition = { tabs = {{ key = "rules", title = L.AUTO_RULES_TITLE, build = function(page)
        local p = A.Page(context, page)
        p:Section(L.AUTO_RULES_TITLE, L.AUTO_RULES_DESC)
        for _, pair in ipairs({ {"mplusUpgrade", "AUTO_RULE_MPLUS_UPGRADE"}, {"mplusWatched", "AUTO_RULE_MPLUS_WATCHED"}, {"raidWatched", "AUTO_RULE_RAID_WATCHED"} }) do
            local key = pair[1]
            p:Row({ type = "toggle", text = L[pair[2]], tooltip = L[pair[2] .. "_DESC"],
                getValue = function() return addon:GetAutoRule(key) end,
                setValue = function(v) addon:SetAutoRules({[key] = v}, true) end })
        end
        p:Section(A.Text("Whisper templates", "密语模板", "密語範本"))
        for _, pair in ipairs({ {"mythicplus", "Mythic+", "大秘境"}, {"raid", "Raid", "团队副本"} }) do
            local mode = pair[1]
            p:Row({ type = "input", layout = "stacked",
                text = A.Text(pair[2] .. " template", pair[3] .. "密语模板", pair[3] .. "密語範本"), tooltip = "%player%  %item%",
                getValue = function() return addon:GetWhisperTemplate(mode) end,
                setValue = function(v)
                    addon:SetWhisperTemplates(mode == "mythicplus" and v or addon.db.mplusWhisperTemplate,
                        mode == "raid" and v or addon.db.raidWhisperTemplate)
                end })
        end
        p:Section(A.Text("Wishlist", "装备关注清单", "裝備關注清單"))
        p:Note(A.Text("Open the Adventure Guide to view the current wishlist.",
            "具体关注清单，请打开冒险指南查看。",
            "具體關注清單，請打開冒險指南查看。"))
        p:Finish()
    end }} }
    return definition
end
A.Register("QFXBeggar", { category = "equipment", categories = {"raid"},
    embeddedSettings = Settings, openOptions = function(tabKey) return A.OpenEmbeddedSettings("QFXBeggar", tabKey) end })
