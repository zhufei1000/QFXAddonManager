local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("QfxUI_Installer") then return end
local A = AM.AdapterUtils

-- QfxUI_Installer dedicated page: mirrors the addon's own "layout overview"
-- so every preset string shows whether it is loaded, imported, missing or
-- unavailable, instead of a generic row of plain action buttons.

local definition, context, status, statusOK

local function Text(en, cn, tw) return A.Text(en, cn, tw) end

local function Profile()
    local ns = rawget(_G, "QfxUI_InstallerManagerAPI")
    if not ns or not ns.Installer or not ns.Data then return nil end
    return ns
end

local KIND = {
    active = { en = "Loaded", cn = "已加载", tw = "已載入", tone = "good" },
    imported = { en = "Imported", cn = "已导入", tw = "已匯入", tone = "warmAccent" },
    missing = { en = "Not imported", cn = "未导入", tw = "未匯入", tone = "danger" },
    none = { en = "No preset", cn = "无预设", tw = "無預設", tone = "textMuted" },
    unavailable = { en = "EllesmereUI not loaded", cn = "EllesmereUI 未载入", tw = "EllesmereUI 未載入", tone = "textMuted" },
}

local ERROR = {
    full = { en = "Layout list is full", cn = "布局数量已满", tw = "版面數量已滿" },
    activate_failed = { en = "Imported but not activated", cn = "已导入但启用失败", tw = "已匯入但啟用失敗" },
}

local function Kind(kind) return KIND[kind] or KIND.none end

local function KindText(kind)
    local k = Kind(kind)
    return Text(k.en, k.cn, k.tw)
end

local function KindTone(kind)
    local k = Kind(kind)
    local S = context.Widgets:Tokens()
    return S[k.tone] or S.text
end

local function ErrorText(err)
    local mapped = type(err) == "string" and ERROR[err]
    if mapped then return Text(mapped.en, mapped.cn, mapped.tw) end
    if err == nil or err == "" then return Text("Unable to complete", "未能完成", "未能完成") end
    return tostring(err)
end

local function Report(ok, message) status, statusOK = message, ok and true or false end

local function Refresh()
    if context and context.Refresh then context.Refresh() end
end

local function EditKind(ns)
    if not ns.Data.ActiveEditMode() then return "unavailable" end
    if not ns.Installer.HasEditModeProfile() then return "missing" end
    if ns.Installer.IsEditModeCurrent() then return "active" end
    return "imported"
end

local function SpecKind(ns, index)
    local E = ns.Installer
    local preset = ns.Data.SpecPreset(index)
    if not preset or preset == "" then return "none" end
    local current = GetSpecialization and GetSpecialization() or nil
    if current == index then
        if E.IsCDMCurrent(index) then return "active" end
        if not context.Widgets:InCombatLocked() and E.VerifyCDMProfile(index) == true then return "imported" end
    elseif E.HasImportRecord(index) then
        return "imported"
    end
    return "missing"
end

local function ApplyEditMode()
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local ok, detail = ns.Installer.InstallEditModeProfile()
    if not ok then
        Report(false, ErrorText(detail))
    elseif detail == "active" or detail == "activated" then
        Report(true, Text("Layout activated", "布局已启用", "版面已啟用"))
    else
        Report(true, Text("Edit mode layout imported", "编辑模式布局已导入", "編輯模式版面已匯入"))
    end
    Refresh()
end

local function ReinstallEditMode()
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local ok, err = ns.Installer.ReinstallEditModeProfile()
    Report(ok and true or false, ok and Text("Edit mode preset restored", "编辑模式预设已恢复", "編輯模式預設已恢復") or ErrorText(err))
    Refresh()
end

local function ApplySpec(index)
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local E = ns.Installer
    if E.VerifyCDMProfile(index) then
        local applied, err = E.ActivateCDMProfile(index)
        Report(applied and true or false, applied and Text("Layout activated", "布局已启用", "版面已啟用") or ErrorText(err))
    else
        local imported, err = E.InstallCDMProfile(index)
        if not imported then
            Report(false, ErrorText(err))
        else
            local applied, applyErr = E.ActivateCDMProfile(index)
            Report(applied and true or false,
                applied and Text("Layout imported and activated", "布局已导入并启用", "版面已匯入並啟用")
                or ErrorText(applyErr or "activate_failed"))
        end
    end
    Refresh()
end

local function ReinstallSpec(index)
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local ok, err = ns.Installer.ReinstallCDMProfile(index)
    Report(ok and true or false, ok and Text("Spec preset restored", "该专精预设已恢复", "該專精預設已恢復") or ErrorText(err))
    Refresh()
end

local function ImportAll()
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local E, Data = ns.Installer, ns.Data
    local editOK, editErr = E.InstallEditModeProfile()
    if not editOK then
        Report(false, ErrorText(editErr))
        Refresh()
        return
    end
    local failed = {}
    local current = GetSpecialization and GetSpecialization() or nil
    local currentFailed = false
    for _, spec in ipairs(Data.SpecList()) do
        local preset = Data.SpecPreset(spec.index)
        if preset and preset ~= "" and E.VerifyCDMProfile(spec.index) ~= true then
            local imported, err = E.InstallCDMProfile(spec.index)
            if not imported then
                failed[#failed + 1] = spec.name .. "：" .. ErrorText(err)
                if spec.index == current then currentFailed = true end
            end
        end
    end
    if current and not currentFailed then
        local preset = Data.SpecPreset(current)
        if preset and preset ~= "" and E.VerifyCDMProfile(current) and E.ActivateCDMProfile(current) ~= true then
            failed[#failed + 1] = Text("Current spec activation failed", "当前专精布局启用失败", "目前專精版面啟用失敗")
        end
    end
    if #failed > 0 then
        Report(false, table.concat(failed, "；"))
    else
        Report(true, Text("All specs imported", "全部导入完成", "全部匯入完成"))
    end
    Refresh()
end

local function QuickImport()
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local E, Data = ns.Installer, ns.Data
    local editOK, editErr = E.InstallEditModeProfile()
    if not editOK then
        Report(false, ErrorText(editErr))
        Refresh()
        return
    end
    local current = GetSpecialization and GetSpecialization() or nil
    local preset = current and Data.SpecPreset(current)
    if preset and preset ~= "" then
        if E.VerifyCDMProfile(current) then
            if E.ActivateCDMProfile(current) ~= true then
                Report(false, Text("Current spec activation failed", "当前专精布局启用失败", "目前專精版面啟用失敗"))
                Refresh()
                return
            end
        else
            local imported, err = E.InstallCDMProfile(current)
            if not imported or E.ActivateCDMProfile(current) ~= true then
                Report(false, ErrorText(err))
                Refresh()
                return
            end
        end
    end
    Report(true, Text("Quick import finished", "一键导入完成", "一鍵匯入完成"))
    Refresh()
end

local function RestorePreset()
    local ns = Profile()
    if not ns or context.Widgets:InCombatLocked() then return end
    local E, Data = ns.Installer, ns.Data
    local editOK, editErr = E.ReinstallEditModeProfile()
    if not editOK then
        Report(false, ErrorText(editErr))
        Refresh()
        return
    end
    local current = GetSpecialization and GetSpecialization() or nil
    local preset = current and Data.SpecPreset(current)
    if preset and preset ~= "" then
        local cdmOK, cdmErr = E.ReinstallCDMProfile(current)
        if not cdmOK then
            Report(false, Text("Edit mode restored; cooldown layout failed: ", "编辑模式已恢复；冷却管理器布局失败：", "編輯模式已恢復；冷卻管理器版面失敗：") .. ErrorText(cdmErr))
            Refresh()
            return
        end
    end
    Report(true, Text("Preset restored", "预设已恢复", "預設已恢復"))
    Refresh()
end

local function ConfirmRestore(text, onAccept)
    context.Widgets:Confirm({
        title = Text("Restore preset", "恢复预设", "恢復預設"),
        text = text,
        acceptText = Text("Restore", "恢复", "恢復"),
        cancelText = Text("Cancel", "取消", "取消"),
        danger = true,
        onAccept = onAccept,
    })
end

local function Build(page)
    local ns = Profile()
    if not ns then return end
    local W = context.Widgets
    local E, Data = ns.Installer, ns.Data
    local content = page.content
    local theme = W.Theme
    local y = -theme.pad

    local updaters = {}
    W:RegisterRefresh(function()
        for i = 1, #updaters do updaters[i]() end
    end)

    local function Gap(px) y = y - (px or 8) end
    local function Section(title, note)
        local _, h = W:SectionHeader(content, title, y, note and { note = note } or nil)
        y = y - h
    end
    local function Status(label, getText, getColor)
        local row, h = W:StatusRow(content, y, { label = label, getText = getText, color = getColor })
        y = y - h
        updaters[#updaters + 1] = row.Update
        return row
    end
    local function Row(left, right)
        for _, cfg in ipairs({ left, right }) do
            if type(cfg) == "table" and cfg.type ~= "label" then
                cfg.blockInCombat = cfg.blockInCombat ~= false
                cfg.combatTooltip = AM.L.COMBAT_LOCKED_TIP
            end
        end
        local row, h = W:DualRow(content, y, left, right)
        y = y - h
        return row
    end

    Section(Text("Overall layout", "整体布局", "整體版面"),
        Text("Edit mode layout string", "编辑模式布局字符串", "編輯模式版面字串"))
    Row({ type = "label", text = Text("QFX exclusive layout", "群飞轩专属布局", "群飛軒專屬版面") },
        { type = "buttonRow", text = "", buttons = {
            { text = Text("Apply", "应用", "套用"), width = 64,
              disabled = function() local k = EditKind(ns) return k == "unavailable" or k == "active" end,
              disabledTooltip = function()
                  if EditKind(ns) == "unavailable" then return Text("EllesmereUI is required", "需要 EllesmereUI", "需要 EllesmereUI") end
                  return Text("Layout already active", "布局已启用", "版面已啟用")
              end,
              onClick = ApplyEditMode },
            { text = Text("Reinstall", "重装", "重裝"), width = 64,
              disabled = function() return EditKind(ns) == "unavailable" end,
              disabledTooltip = Text("EllesmereUI is required", "需要 EllesmereUI", "需要 EllesmereUI"),
              onClick = function()
                  ConfirmRestore(Text("Replace the overall layout with its preset string?",
                      "用预设字符串重装整体布局？", "用預設字串重裝整體版面？"), ReinstallEditMode)
              end },
        } })
    Status(Text("Status", "状态", "狀態"),
        function() return KindText(EditKind(ns)) end,
        function() return KindTone(EditKind(ns)) end)
    Gap()

    Section(Text("Cooldown Manager", "冷却管理器", "冷卻管理器"),
        Text("Per-spec cooldown layout strings", "按专精的冷却管理器布局字符串", "依專精的冷卻管理器版面字串"))
    Status(Text("Character layouts", "角色布局", "角色版面"), function()
        if W:InCombatLocked() then return "-" end
        if not E.CDMReady() then return Text("Cooldown Manager not loaded", "冷却管理器尚未加载", "冷卻管理器尚未載入") end
        return tostring(E.CountCharacterCDMLayouts()) .. " / " .. tostring(E.MAX_CHARACTER_CDM_LAYOUTS or 5)
    end, function()
        if W:InCombatLocked() or not E.CDMReady() then return nil end
        local used = E.CountCharacterCDMLayouts()
        local max = E.MAX_CHARACTER_CDM_LAYOUTS or 5
        local tone = W:Tokens()
        return used >= max and tone.danger or tone.warmAccent
    end)

    local list, listHeight, listAPI = W:ListRows(content, y, {
        items = function() return Data.SpecList() end,
        rowH = 26,
        rowBuilder = function(row)
            local S = W:Tokens()
            row._icon = row:CreateTexture(nil, "ARTWORK")
            row._icon:SetSize(18, 18)
            row._icon:SetPoint("LEFT", row, "LEFT", 8, 0)
            row._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row._name = W.Font(row, theme.labelSize, unpack(S.text))
            row._name:SetJustifyH("LEFT")
            row._name:SetPoint("LEFT", row._icon, "RIGHT", 7, 0)
            row._state = W.Font(row, theme.labelSize, unpack(S.textMuted))
            row._state:SetJustifyH("RIGHT")
            -- DetachedControl ends the factory refresh scope; restore it so the
            -- rows built after this list still refresh with their page.
            local scope = W._refreshScope
            row._applyButton = W:DetachedControl(row, "button", { width = 56, height = 20 })
            row._reinstallButton = W:DetachedControl(row, "button", { width = 56, height = 20 })
            W._refreshScope = scope
            row._applyButton:SetPoint("RIGHT", row, "RIGHT", -(theme.rightPad or 16), 0)
            row._reinstallButton:SetPoint("RIGHT", row._applyButton, "LEFT", -4, 0)
            row._state:SetPoint("RIGHT", row._reinstallButton, "LEFT", -10, 0)
            row._name:SetPoint("RIGHT", row._state, "LEFT", -8, 0)
            row._applyButton:SetScript("OnClick", function()
                if row._item then ApplySpec(row._item.index) end
            end)
            row._reinstallButton:SetScript("OnClick", function()
                local item = row._item
                if not item then return end
                ConfirmRestore(Text("Replace this spec's layout with its preset string?",
                    "用预设字符串重装该专精布局？", "用預設字串重裝該專精版面？"),
                    function() ReinstallSpec(item.index) end)
            end)
        end,
        rowUpdate = function(row, spec)
            row:SetWidth(W.ContentWidth(content))
            local S = W:Tokens()
            local kind = SpecKind(ns, spec.index)
            local k = Kind(kind)
            local tone = S[k.tone] or S.text
            local current = GetSpecialization and GetSpecialization() or nil
            row._icon:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row._icon:SetDesaturated(kind == "none")
            row._name:SetText(spec.name or "")
            if spec.index == current then
                row._name:SetTextColor(S.warmAccent[1], S.warmAccent[2], S.warmAccent[3], 1)
            else
                row._name:SetTextColor(S.text[1], S.text[2], S.text[3], S.text[4] or 1)
            end
            row._state:SetText(Text(k.en, k.cn, k.tw))
            row._state:SetTextColor(tone[1], tone[2], tone[3], tone[4] or 1)
            local usable = kind == "imported" or kind == "missing"
            local label = Text("No preset", "无预设", "無預設")
            if kind == "imported" then label = Text("Apply", "应用", "套用")
            elseif kind == "missing" then label = Text("Import", "导入", "匯入")
            elseif kind == "active" then label = Text("Current", "当前", "目前") end
            row._applyButton:SetText(label)
            row._reinstallButton:SetText(Text("Reinstall", "重装", "重裝"))
            local locked = W:InCombatLocked()
            row._applyButton:SetAlpha(usable and not locked and 1 or 0.35)
            row._reinstallButton:SetAlpha(kind ~= "none" and not locked and 1 or 0.35)
        end,
    })
    y = y - listHeight
    updaters[#updaters + 1] = function()
        list:SetWidth(W.ContentWidth(content))
        listAPI.Render()
    end
    Gap(4)

    Row({ type = "label", text = Text("Layout tools", "布局管理", "版面管理") },
        { type = "buttonRow", text = "", buttons = {
            { text = Text("Layouts", "管理布局", "管理版面"), width = 78,
              onClick = function()
                  local current = Profile()
                  if current and current.LayoutManagers and current.LayoutManagers.ShowCDMLayoutManager then
                      current.LayoutManagers.ShowCDMLayoutManager(function() listAPI.Render() end)
                  end
              end },
            { text = Text("Restore", "一键恢复", "一鍵恢復"), width = 78,
              onClick = function()
                  ConfirmRestore(Text("Restore the overall layout and the current spec's cooldown layout?",
                      "确定恢复整体布局和当前专精冷却管理器预设吗？", "確定恢復整體版面與目前專精的冷卻管理器預設嗎？"), RestorePreset)
              end },
        } })
    Row({ type = "label", text = Text("Bulk import", "批量导入", "批次匯入") },
        { type = "buttonRow", text = "", buttons = {
            { text = Text("Import all", "全部导入", "全部匯入"), width = 78, onClick = ImportAll },
            { text = Text("Quick import", "一键导入", "一鍵匯入"), width = 78, onClick = QuickImport },
        } })
    Gap()

    Section(Text("Entry", "入口", "入口"))
    Row({ type = "toggle",
        text = Text("Stop Auto-open", "不再自动提示安装", "不再自動提示安裝"),
        tooltip = Text("The installer stops opening automatically after log-in or a version update.",
            "关闭后，登录和版本更新时不再自动打开安装面板。", "關閉後，登入與版本更新時不再自動開啟安裝面板。"),
        getValue = function() return QfxUI_InstallerCharDB and QfxUI_InstallerCharDB.dismissEditModePopup == true end,
        setValue = function(value)
            if QfxUI_InstallerCharDB then QfxUI_InstallerCharDB.dismissEditModePopup = value and true or false end
        end })
    Gap()

    Status(Text("Result", "操作结果", "操作結果"),
        function() return status or "" end,
        function()
            local S = W:Tokens()
            if statusOK == nil then return S.text end
            return statusOK and S.good or S.danger
        end)

    page.cursor = -y
    page:SetContentHeight(-y + theme.pad)
end

A.Register("QfxUI_Installer", { category = "other", addons = { "QfxUI_Installer" },
    embeddedSettings = function(ctx)
        local ns = Profile()
        if not ns then return nil end
        context = ctx
        ns.Installer.EnsureDB()
        if definition then return definition end
        definition = { tabs = { {
            key = "layout",
            title = Text("Layout overview", "布局总览", "版面配置總覽"),
            build = Build,
        } } }
        return definition
    end,
    openOptions = function() A.OpenEmbeddedSettings("QfxUI_Installer") end })
