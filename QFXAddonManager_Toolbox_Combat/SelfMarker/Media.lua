local _, manager = ...
manager.ToolboxRuntime:AddFile("SelfMarker", function(...)
_G.QFXToolBoxSelfMarker = _G.QFXToolBoxSelfMarker or {}
local QSM = _G.QFXToolBoxSelfMarker

local root = "Interface\\AddOns\\QFXAddonManager_Toolbox_Combat\\SelfMarker\\Media\\"

QSM.Media = {
    flower = root .. "marker_flower.blp",
    star = root .. "marker_star.blp",
    ring = root .. "marker_ring.blp",
    rings = {
        [4] = root .. "marker_ring_04.blp",
        [6] = root .. "marker_ring_06.blp",
        [8] = root .. "marker_ring_08.blp",
        [10] = root .. "marker_ring_10.blp",
        [12] = root .. "marker_ring_12.blp",
        [14] = root .. "marker_ring_14.blp",
        [16] = root .. "marker_ring_16.blp",
        [18] = root .. "marker_ring_18.blp",
        [20] = root .. "marker_ring_20.blp",
    },
}


end)
