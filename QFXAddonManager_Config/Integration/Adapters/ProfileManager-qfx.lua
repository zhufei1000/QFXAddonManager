local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("ProfileManager-qfx") then return end
local A=AM.AdapterUtils
local definition,context
A.Register("ProfileManager-qfx",{category="tool",categories={"ui"},embeddedSettings=function(ctx)
    local ns=rawget(_G,"ProfileManagerQfx")
    if not ns or not ns.GetDB then return end
    context=ctx
    if definition then return definition end
    definition={tabs={}}
    for _, profile in ipairs(ns.GetProfileOrder()) do
        local key=profile
        definition.tabs[#definition.tabs+1]={key=key,title=ns.GetProfile(key).name,build=function(page)
            local p=A.Page(context,page)
            p:Section(ns.GetProfile(key).name)
            for _, tuple in ipairs({{"enabled","Automatic loading","自动载入","自動載入"},{"autoSave","Automatic saving","自动保存","自動儲存"}}) do
                local field=tuple[1]
                p:Row({type="toggle",text=A.Text(tuple[2],tuple[3],tuple[4]),getValue=function() return ns.GetDB()[field] end,setValue=function(v)
                    ns.GetDB()[field]=v
                    if v and field=="enabled" then ns.ApplyCurrentProfile("manager-enable")
                    elseif v and field=="autoSave" then ns.AutoSaveCurrentProfile("manager-auto-save") end
                end})
            end
            p:Row({type="button",text=A.Text("Save current positions","保存当前位置","儲存目前位置"),onClick=function() ns.SaveCurrentToProfile(key) end})
            p:Row({type="button",text=A.Text("Apply this layout","应用该布局","套用此版面配置"),onClick=function() ns.ApplyProfile(key,"manager") end})
            p:Row({type="button",text=A.Text("Apply current EUI layout","载入当前 EUI 布局","載入目前 EUI 版面配置"),onClick=function() ns.ApplyCurrentProfile("manager") end})
            for _, addon in ipairs(ns.GetRegisteredAddons()) do
                p:Section(addon.label or addon.name or addon.key)
                for _, module in ipairs(ns.GetRegisteredModules(addon.key)) do
                    local moduleKey=module
                    p:Row({type="toggle",text=moduleKey,getValue=function() return ns.IsModuleManaged(moduleKey) end,
                        setValue=function(v) ns.SetModuleManaged(moduleKey,v) end})
                end
            end
            p:Finish()
        end}
    end
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("ProfileManager-qfx") end})
