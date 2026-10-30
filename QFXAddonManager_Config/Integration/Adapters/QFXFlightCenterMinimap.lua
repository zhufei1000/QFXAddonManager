local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXFlightCenterMinimap") then return end
local A=AM.AdapterUtils
local definition,context
A.Register("QFXFlightCenterMinimap",{category="map",embeddedSettings=function(ctx)
    local ns=rawget(_G,"QFXFlightCenterMinimap")
    if not ns or not ns.db then return end
    context=ctx
    if definition then return definition end
    local L=ns.L or ns.LOCALIZATION.enUS
    definition={tabs={{key="flight",title=L.FLIGHT_VISUALS,build=function(page)
        local p=A.Page(context,page)
        p:Section(L.GENERAL_SETTINGS)
        p:Row({type="toggle",text=L.ENABLED,getValue=function() return ns.db.enabled end,setValue=function(v)
            ns.db.enabled=v; if not v then ns.testCenterMode=false end; ns:RefreshWatcher(); ns:UpdateCenterState(true)
        end})
        p:Row({type="dropdown",text=A.Text("Language","语言","語言"),values={AUTO=A.Text("Automatic","跟随客户端","跟隨客戶端"),enUS="English",zhCN="简体中文",zhTW="繁體中文"},
            getValue=function() return ns:GetLanguageMode() end,setValue=function(v) ns:SetLanguageMode(v); definition=nil; context.Rebuild() end})
        p:Section(L.FLIGHT_VISUALS)
        p:Row({type="toggle",text=L.TEST_CENTER,getValue=function() return ns:IsTestCenterMode() end,setValue=function(v)
            if v~=ns:IsTestCenterMode() then ns:ToggleTestCenterMode() end
        end})
        for _, tuple in ipairs({{"flightScale","SCALE",1,3,.05},{"flightAlpha","ALPHA",.1,1,.05}}) do
            local key=tuple[1]
            p:Row({type="slider",text=L[tuple[2]],min=tuple[3],max=tuple[4],step=tuple[5],getValue=function() return ns.db[key] end,
                setValue=function(v) ns.db[key]=v; if ns.centerActive then ns:ApplyFlightVisual() end end})
        end
        p:Section(L.PROVIDER_SETTINGS)
        for _, tuple in ipairs({{"x","POS_X",-400,400},{"y","POS_Y",-240,40}}) do
            local axis=tuple[1]
            p:Row({type="slider",text=L[tuple[2]],min=tuple[3],max=tuple[4],step=1,getValue=function() return ns:GetProviderPositionConfig(ns:GetOptionsProviderKey())[axis] end,
                setValue=function(v)
                    local provider=ns:GetOptionsProviderKey()
                    ns:GetProviderPositionConfig(provider)[axis]=v
                    if ns.centerActive and ns.returnState and ns.returnState.providerKey==provider then ns:ApplyFlightPosition(ns.returnState) end
                end})
        end
        p:Finish()
    end}},OnSettingsHide=function() if ns:IsTestCenterMode() then ns:ToggleTestCenterMode() end end}
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("QFXFlightCenterMinimap") end})
