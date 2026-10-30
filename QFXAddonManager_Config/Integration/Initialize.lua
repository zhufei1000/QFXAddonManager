-- Runs once when the adapters addon is pulled in. If the manager window is
-- already visible, refresh it so adapter patches take effect immediately.
-- Presets are applied here: every adapter file has registered by now.
local _, ns = ...
local AM = ns.Manager
if not AM then return end

if ns.Presets then ns.Presets.Enable() end
AM.adaptersReady = true

if AM.UI and AM.UI.frame and AM.UI.frame:IsShown() then
    if AM.ScanAddOns then AM.ScanAddOns() end
    if AM.UI.Refresh then AM.UI.Refresh(AM.ScanAddOns ~= nil) end
end
