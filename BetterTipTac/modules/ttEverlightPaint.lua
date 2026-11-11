-----------------------------------------------------------------------
-- BetterTipTac - Everlight paint
--
-- Overlay chrome is disabled. TipTac SetBackdrop owns the border so
-- Backdrop options and layout presets stay 100% compatible.
--

local MOD_NAME = ...;
local LibFroznFunctions = LibStub:GetLibrary("LibFroznFunctions-1.0");

local paint = {};
LibFroznFunctions:RegisterForGroupEvents(MOD_NAME, paint, MOD_NAME .. " - Everlight Paint");

local function RestoreNativeChrome(tooltip)
	if (not tooltip) or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return;
	end
	if (tooltip.NineSlice) then
		tooltip.NineSlice:SetAlpha(1);
	end
end

function paint:OnApplyConfig(_TT_CacheForFrames)
	if (not _TT_CacheForFrames) then
		return;
	end
	for tip in pairs(_TT_CacheForFrames) do
		RestoreNativeChrome(tip);
	end
end

function paint:OnTipPostSetStyling(_TT_CacheForFrames, tip)
	RestoreNativeChrome(tip);
end

function paint:OnTipResized(_TT_CacheForFrames, tip)
	RestoreNativeChrome(tip);
end
