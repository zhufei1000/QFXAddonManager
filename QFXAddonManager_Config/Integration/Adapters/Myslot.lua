local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("Myslot") then return end
local A = AM.AdapterUtils
local function Label(en, cn, tw) return A.Text(en, cn, tw) end
local definition, context

-- Myslot stores its per-character settings in MyslotSettings and keeps the
-- import/export window in the addon's private table; the window is opened with
-- the original slash command and destructive clears still use the native
-- confirmation dialog (keyword input).
A.Update("Myslot", {
    embeddedSettings = function(ctx)
        local settings = rawget(_G, "MyslotSettings")
        if not settings then return end
        context = ctx
        if definition then return definition end
        definition = { tabs = {{ key = "general", title = AM.L.SETTINGS, build = function(page)
            local p = A.Page(context, page)
            p:Section(Label("Window", "窗口", "視窗"))
            p:Row({ type = "button", text = Label("Open Myslot", "打开 Myslot 窗口", "開啟 Myslot 視窗"),
                onClick = function()
                    if not A.TrySlash({ "MYSLOT" }, "") then error(AM.L.OPEN_OPTIONS_FAILED) end
                end })
            p:Row({ type = "toggle", text = Label("Minimap icon", "小地图图标", "小地圖圖示"), blockInCombat = false,
                getValue = function() return not (settings.minimap and settings.minimap.hide) end,
                setValue = function(on)
                    settings.minimap = settings.minimap or { hide = false }
                    settings.minimap.hide = not on
                    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
                    if icon then
                        if on then icon:Show("Myslot") else icon:Hide("Myslot") end
                    end
                end })
            p:Section(Label("Loadout list", "方案列表", "方案列表"))
            p:Row({ type = "toggle", text = Label("Only my class", "仅显示本职业", "只顯示本職業"), blockInCombat = false,
                getValue = function() return settings.loadoutFilterClass and true or false end,
                setValue = function(on) settings.loadoutFilterClass = on and true or false end })
            p:Row({ type = "dropdown", text = Label("Sort by", "排序方式", "排序方式"), width = 190, blockInCombat = false,
                values = {{ key = "date", label = Label("By date", "按日期", "按日期") },
                    { key = "name", label = Label("By name", "按名称", "按名稱") },
                    { key = "class", label = Label("By class", "按职业", "按職業") }},
                getValue = function() return settings.loadoutSort or "date" end,
                setValue = function(value) settings.loadoutSort = value end })
            p:Section(Label("Import", "导入", "匯入"))
            p:Row({ type = "toggle", text = Label("Allow clearing before import", "导入前允许清空", "匯入前允許清空"),
                blockInCombat = false,
                getValue = function() return settings.allowclearonimport and true or false end,
                setValue = function(on) settings.allowclearonimport = on and true or false end })
            p:Note(Label("The clear buttons below still open the original confirmation and require typing the keyword.",
                "下面的清空按钮仍会打开原确认框并要求输入关键字确认。",
                "下方的清空按鈕仍會開啟原確認框並要求輸入關鍵字確認。"))
            p:Section(Label("Cleanup", "清理", "清理"))
            local function ClearButton(text, what)
                p:Row({ type = "button", text = text, onClick = function()
                    if StaticPopupDialogs and StaticPopupDialogs.MYSLOT_CONFIRM_CLEAR and StaticPopup_Show then
                        StaticPopup_Show("MYSLOT_CONFIRM_CLEAR", what, nil, what)
                    end
                end })
            end
            ClearButton(Label("Clear action bars", "清空动作条", "清空動作列"), "ACTION")
            ClearButton(Label("Clear key bindings", "清空按键绑定", "清空按鍵綁定"), "BINDING")
            ClearButton(Label("Clear macros", "清空宏", "清空巨集"), "MACRO")
            if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
                ClearButton(Label("Clear cooldown manager", "清空冷却管理器", "清空冷卻管理器"), "COOLDOWNMANAGER")
                ClearButton(Label("Clear click-cast bindings", "清空点击施法绑定", "清空點擊施法綁定"), "CLICKBINDING")
                ClearButton(Label("Clear Myslot talent loadouts", "清空 Myslot 天赋方案", "清空 Myslot 天賦方案"), "TALENTLOADOUT")
            end
            p:Finish()
        end }} }
        return definition
    end,
})
