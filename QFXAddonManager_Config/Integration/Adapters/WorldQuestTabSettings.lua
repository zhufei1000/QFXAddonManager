local AM = _G.QFXAddonManager or select(2, ...)
if not AM.AdapterUtils.IsInstalled("WorldQuestTab") then return end
local A = AM.AdapterUtils
local context, definition, model

local function Visible(data)
    return not data.isVisibleFunc or data:isVisibleFunc()
end
local function Changed(data, ...)
    if context.Widgets:InCombatLocked() then return end
    if data.valueChangedFunc then data.valueChangedFunc(...) end
    WQT_CallbackRegistry:TriggerEvent("WQT.SettingChanged", data.categoryID, data.tag, ...)
    definition = nil
    if context.Rebuild then context.Rebuild() end
end
local function Render(p, category)
    for _, child in ipairs(category.children or {}) do
        local element = child.elementData
        local data, template = element.data, element.template
        if Visible(data) then
            local cfg = { text = data.label, tooltip = data.tooltip,
                getValue = data.getValueFunc,
                setValue = function(...) Changed(data, ...) end,
                disabled = function() return not Visible(data) or (data.isDisabled and data.isDisabled()) end }
            if template == "WQT_SettingCheckboxTemplate" then cfg.type = "toggle"
            elseif template == "WQT_SettingSliderTemplate" then
                cfg.type, cfg.min, cfg.max, cfg.step = "slider", data.min, data.max, data.valueStep
            elseif template == "WQT_SettingDropDownTemplate" then
                cfg.type, cfg.width, cfg.values = "dropdown", 190, function()
                    local result = {}
                    local options = type(data.options) == "function" and data.options() or data.options
                    for _, option in ipairs(options or {}) do result[#result + 1] = { key = option.id, label = option.label, disabled = option.disabled } end
                    return result
                end
            elseif template == "WQT_SettingTextInputTemplate" then cfg.type, cfg.width = "input", 190
            elseif template == "WQT_SettingColorTemplate" then
                cfg.type = "color"
                cfg.getValue = function() return data.getValueFunc(data.colorID):GetRGB() end
                cfg.setValue = function(r, g, b) Changed(data, data.colorID, r, g, b) end
            elseif template == "WQT_SettingButtonTemplate" or template == "WQT_SettingConfirmButtonTemplate" then
                cfg.type, cfg.setValue = "button", nil
                cfg.onClick = function()
                    if template == "WQT_SettingConfirmButtonTemplate" then
                        context.Widgets:Confirm({ title = data.label, text = data.tooltip or data.label, onAccept = function() Changed(data) end })
                    else Changed(data) end
                end
            elseif template == "WQT_SettingTextTemplate" then p:Note(data.label or "")
            elseif data.label then
                p:Note(data.label .. ": " .. A.Text("Use the original options.", "请使用原插件配置。", "請使用原插件設定。"))
            end
            if cfg.type then p:Row(cfg) end
        end
    end
    for _, sub in ipairs(category.subCategories or {}) do p:Section(sub.elementData.data.label); Render(p, sub) end
end

A.Update("WorldQuestTab", { embeddedSettings = function(ctx)
    local frame = rawget(_G, "WQT_SettingsFrame")
    local current = frame and frame.dataContainer
    if not current or not current.categories or #current.categories == 0 or not WQT_CallbackRegistry then return end
    context = ctx
    if model ~= current then model, definition = current, nil end
    if definition then return definition end
    definition = { external = true, tabs = {} }
    for _, category in ipairs(current.categories) do
        if category.categoryID ~= "CHANGELOG" then
            local tab = { key = category.categoryID, title = category.elementData.data.label,
                build = function(page) local p = A.Page(context, page); Render(p, category); p:Finish() end }
            definition.tabs[#definition.tabs + 1] = tab
        end
    end
    return definition
end, openOptions = function()
    local frame = rawget(_G, "WQT_WorldQuestFrame")
    local button = frame and frame.ScrollFrame and frame.ScrollFrame.SettingsButton
    if button and button.OnClick and WorldMapFrame then
        WorldMapFrame:Show()
        button:OnClick()
        return
    end
    error(AM.L.OPEN_OPTIONS_FAILED)
end })
