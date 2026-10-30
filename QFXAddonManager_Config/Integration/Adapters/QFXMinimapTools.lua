local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXMinimapTools") then return end
local A = AM.AdapterUtils
local definition, context
A.Register("QFXMinimapTools", {category="map",categories={"ui"},embeddedSettings=function(ctx)
    local ns=rawget(_G,"QFXMinimapTools")
    if not ns or not ns.BuildManagerPage or not ns.db then return end
    context=ctx
    if definition and definition.language==ns.db.ui.language then return definition end
    definition={tabs={},language=ns.db.ui.language}
    for _, pair in ipairs({{"overview","OVERVIEW"},{"minimap","MINIMAP"},{"stats","STATS"},{"bag","BUTTONS"},{"flight","FLIGHT_SECTION"},{"advanced","ADVANCED"}}) do
        local key=pair[1]
        definition.tabs[#definition.tabs+1]={key=key,title=ns.L[pair[2]],build=function(page)
            ns:BuildManagerPage(key,page,context,A.Page(context,page))
        end}
    end
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("QFXMinimapTools") end})
