-- Config/Integration carries per-plugin adapters that patch the registry with
-- descriptions, categories, embedded settings, and open-options entry points.
-- Loaded by QFXAM.EnsureAdaptersLoaded() the first time the manager window or
-- an external settings entry needs the adapter data.
local _, ns = ...
local AM = _G.QFXAddonManager
if not AM then return end

ns.Manager = AM
