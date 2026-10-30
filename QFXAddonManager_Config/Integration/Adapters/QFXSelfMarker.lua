local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QFXSelfMarker") then return end
local A=AM.AdapterUtils
local definition,context
A.Register("QFXSelfMarker",{category="combat",categories={"ui"},embeddedSettings=function(ctx)
    local ns=rawget(_G,"QFXSelfMarker")
    if not ns or not ns.db then return end
    context=ctx
    if definition then return definition end
    local L=ns.L
    local function Apply(method)
        if method then ns.Marker[method](ns.Marker) end
        if ns.RefreshRuntimeEvents then ns:RefreshRuntimeEvents() end
    end
    local function Field(p,key,label,kind,min,max,step,method,values)
        p:Row({type=kind,text=L[label],min=min,max=max,step=step,values=values,getValue=function() return ns:GetDB()[key] end,
            setValue=function(v)
                local db=ns:GetDB(); db[key]=v
                if key=="showAlways" and v then db.showInCombatOnly=false; db.showInInstanceOnly=false end
                if (key=="showInCombatOnly" or key=="showInInstanceOnly") and v then db.showAlways=false end
                if key=="gcdIdleAlpha" then db.gcdActiveAlpha=v end
                if key=="enabled" and not v then ns.GCD:Stop() end
                Apply(method)
            end})
    end
    local function Tab(key,label,build)
        return {key=key,title=L[label],build=function(page) local p=A.Page(context,page); p:Section(L[label]); build(p); p:Finish() end}
    end
    definition={tabs={
        Tab("overview","TAB_OVERVIEW",function(p)
            Field(p,"enabled","ENABLE_ADDON","toggle",nil,nil,nil,"RefreshVisibility")
            Field(p,"locked","LOCK_MARKER","toggle",nil,nil,nil,"RefreshLock")
            p:Row({type="toggle",text=L.SHOW_PREVIEW,getValue=function() return ns.forcePreview end,setValue=function(v) ns.forcePreview=v; Apply("RefreshVisibility") end})
            p:Row({type="button",text=L.RESET_POSITION,onClick=function() ns:ResetPosition(); context.Refresh() end})
        end),
        Tab("marker","TAB_MARKER",function(p)
            Field(p,"style","STYLE","dropdown",nil,nil,nil,"RefreshStyle",{gcd_ring=L.STYLE_GCD_RING,flower=L.STYLE_FLOWER,star=L.STYLE_STAR,crosshair=L.STYLE_CROSSHAIR})
            Field(p,"size","SIZE","slider",24,160,1,"RefreshSize")
            Field(p,"alpha","ALPHA","slider",.1,1,.01,"RefreshColor")
            Field(p,"x","OFFSET_X","slider",-500,500,1,"RefreshPosition")
            Field(p,"y","OFFSET_Y","slider",-500,500,1,"RefreshPosition")
            p:Section(L.TAB_ANIMATION)
            Field(p,"markerSpinMode","SPIN_MODE","dropdown",nil,nil,nil,"RefreshSpin",{none=L.SPIN_NONE,clockwise=L.SPIN_CLOCKWISE,counterclockwise=L.SPIN_COUNTERCLOCKWISE,alternate=L.SPIN_ALTERNATE})
            Field(p,"markerSpinSpeed","SPIN_SPEED","slider",1,10,1,"RefreshSpin")
            p:Section(L.TAB_COLOR)
            Field(p,"colorMode","COLOR_MODE","dropdown",nil,nil,nil,"RefreshColor",{class=L.COLOR_CLASS,white=L.COLOR_WHITE,custom=L.COLOR_CUSTOM})
            p:Row({type="color",text=L.CUSTOM_COLOR,getValue=function() local c=ns:GetDB().customColor; return c.r,c.g,c.b,c.a end,
                setValue=function(r,g,b,a) local db=ns:GetDB(); db.customColor={r=r,g=g,b=b,a=a}; db.colorMode="custom"; Apply("RefreshColor") end})
        end),
        Tab("visibility","TAB_VISIBILITY",function(p)
            for _, pair in ipairs({{"showAlways","SHOW_ALWAYS"},{"showInCombatOnly","SHOW_COMBAT"},{"showInInstanceOnly","SHOW_INSTANCE"},
                {"hideInPetBattle","HIDE_PET_BATTLE"},{"hideWhenMounted","HIDE_MOUNTED"},{"hideInVehicle","HIDE_VEHICLE"}}) do Field(p,pair[1],pair[2],"toggle",nil,nil,nil,"RefreshVisibility") end
        end),
        Tab("gcd","TAB_GCD",function(p)
            Field(p,"gcdDurationMode","GCD_MODE","dropdown",nil,nil,nil,nil,{auto=L.GCD_AUTO,fixed=L.GCD_FIXED})
            Field(p,"gcdFixedDuration","GCD_FIXED_DURATION","slider",.5,2,.05)
            Field(p,"ringThickness","RING_THICKNESS","slider",4,20,2,"RefreshRingTexture")
            Field(p,"gcdIdleAlpha","GCD_IDLE_ALPHA","slider",.1,1,.01,"RefreshColor")
            Field(p,"gcdEndAlpha","GCD_END_ALPHA","slider",.05,1,.01)
        end),
        Tab("advanced","TAB_ADVANCED",function(p)
            Field(p,"frameStrata","FRAME_STRATA","dropdown",nil,nil,nil,"RefreshFrameLevel",{LOW="LOW",MEDIUM="MEDIUM",HIGH="HIGH",DIALOG="DIALOG",FULLSCREEN="FULLSCREEN",FULLSCREEN_DIALOG="FULLSCREEN_DIALOG",TOOLTIP="TOOLTIP"})
            Field(p,"frameLevel","FRAME_LEVEL","slider",1,100,1,"RefreshFrameLevel")
            p:Row({type="button",text=L.RESET_DEFAULTS,onClick=function() context.Widgets:Confirm({title=L.RESET_DEFAULTS,text=L.RESET_DEFAULTS,onAccept=function() ns:ResetDB(); context.Refresh() end}) end})
        end),
    },OnTabShow=function(key) if key~="overview" then ns.forcePreview=false; Apply("RefreshVisibility") end end,
    OnSettingsHide=function() ns.forcePreview=false; Apply("RefreshVisibility") end}
    return definition
end,openOptions=function() A.OpenEmbeddedSettings("QFXSelfMarker") end})
