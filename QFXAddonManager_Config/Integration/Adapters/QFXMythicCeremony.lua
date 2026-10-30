local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXMythicCeremony") then return end
local A=AM.AdapterUtils
local definition,context
A.Register("QFXMythicCeremony",{category="raid",embeddedSettings=function(ctx)
    local ns=rawget(_G,"QFXMythicCeremonyManagerAPI")
    if not ns or not QFXMythicCeremonyDB then return end
    context=ctx
    if definition then return definition end
    definition={tabs={{key="ceremony",title=A.Text("Completion","结算提示","結算提示"),build=function(page)
        local p=A.Page(context,page)
        p:Section("QFXMythicCeremony")
        for _, pair in ipairs({{"enabled","Enabled","启用","啟用"},{"sound","Sound","播放声音","播放聲音"}}) do
            local key=pair[1]
            p:Row({type="toggle",text=A.Text(pair[2],pair[3],pair[4]),getValue=function() return QFXMythicCeremonyDB[key] end,
                setValue=function(v) QFXMythicCeremonyDB[key]=v end})
        end
        for _, pair in ipairs({{"scale","Scale","缩放","縮放",.5,1.5,.05},{"y","Vertical offset","纵向偏移","縱向偏移",-500,500,1},{"duration","Duration","显示时长","顯示時間",1,30,1}}) do
            local key=pair[1]
            p:Row({type="slider",text=A.Text(pair[2],pair[3],pair[4]),min=pair[5],max=pair[6],step=pair[7],getValue=function() return QFXMythicCeremonyDB[key] end,
                setValue=function(v) QFXMythicCeremonyDB[key]=v; ns.ApplyPosition() end})
        end
        for _, pair in ipairs({{"victory","Test victory","测试胜利","測試勝利"},{"defeat","Test defeat","测试失败","測試失敗"}}) do
            local command=pair[1]
            p:Row({type="button",text=A.Text(pair[2],pair[3],pair[4]),onClick=function() A.TrySlash({"QFXMYTHICCEREMONY"},command) end})
        end
        p:Finish()
    end}},OnSettingsHide=ns.HidePreview}
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("QFXMythicCeremony") end})
