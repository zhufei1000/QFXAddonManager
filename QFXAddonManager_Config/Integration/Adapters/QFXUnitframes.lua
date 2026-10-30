local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXUnitframes") then return end
local A=AM.AdapterUtils
local definition,context
A.Register("QFXUnitframes",{category="ui",categories={"combat"},embeddedSettings=function(ctx)
    local ns=rawget(_G,"QFXUnitframesManagerAPI")
    if not ns or not ns.BuildManagerSettings then return end
    context=ctx
    local language=ns.db and ns.db.uiLanguage
    if definition and definition.language==language then return definition end
    definition={tabs={},language=language}
    for _, entry in ipairs(ns.GetManagerSettingsPages()) do
        local unit=entry.key~="global" and entry.key or nil
        if entry.subtabs then
            for _, tab in ipairs(entry.subtabs) do
                local key=tab.key
                tab.build=function(page) ns.BuildManagerSettings(page,context,A.Page(context,page),unit,key) end
            end
        else entry.build=function(page) ns.BuildManagerSettings(page,context,A.Page(context,page)) end end
        definition.tabs[#definition.tabs+1]=entry
    end
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("QFXUnitframes") end})
