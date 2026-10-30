local _, manager = ...
manager.ToolboxRuntime:AddFile("Config", function(...)
local ns = _G.QFXAddonManagerToolboxNS
ns.QFXPanel = {}
function ns.OpenConfig() return QFXAddonManagerAPI.OpenToolbox() end
function ns.ToggleConfig() return QFXAddonManagerAPI.ToggleToolbox() end
ns.QFXPanel.OpenConfig = ns.OpenConfig
ns.QFXPanel.ToggleConfig = ns.ToggleConfig
function ns.RebuildConfig() if ns.QFXManagerHost then ns.QFXManagerHost.Invalidate() end end
ns.RebuildConfigPage = ns.RebuildConfig
end)
