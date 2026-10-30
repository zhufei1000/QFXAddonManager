local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXWhisper") then return end
local A=AM.AdapterUtils
local definition,context
A.Register("QFXWhisper",{category="chat",embeddedSettings=function(ctx)
    local ns=rawget(_G,"QFXWhisperManagerAPI")
    if not ns or not ns.BuildManagerSettings then return end
    ns.EnsureManagerSettings()
    context=ctx
    if definition then return definition end
    definition={tabs={{key="settings",title=A.Text("Whisper settings","密语设置","密語設定"),build=function(page)
        local p=A.Page(context,page)
        ns.BuildManagerSettings(context,p)
        p:Finish()
    end}}}
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("QFXWhisper") end})
