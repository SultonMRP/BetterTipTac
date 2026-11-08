-----------------------------------------------------------------------
-- BetterTipTac - Everlight paint
--
-- Rounded fill and cyan border overlay. Positioning stays in TipTac core.
--

local MOD_NAME = ...;
local tt = _G[MOD_NAME];
local LibFroznFunctions = LibStub:GetLibrary("LibFroznFunctions-1.0");

local paint = {};
LibFroznFunctions:RegisterForGroupEvents(MOD_NAME, paint, MOD_NAME .. " - Everlight Paint");

local configDb, cfg, TT_ExtendedConfig, TT_CacheForFrames;

local skins = setmetatable({}, { __mode = "k" });
local cornerPoints = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" };
local cornerCoords = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } };
local mediaPath = "Interface\\AddOns\\BetterTipTac\\media\\everlight\\";

local function Texture(tooltip, skin, layer, sublevel)
	local texture = tooltip:CreateTexture(nil, layer, nil, sublevel);
	skin.regions[texture] = true;
	return texture;
end

local function CreateSkin(tooltip)
	local skin = { regions = {}, edges = {}, extension = 0, rounded = true };
	skins[tooltip] = skin;
	skin.background = Texture(tooltip, skin, "BACKGROUND", -8);
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do
		skin.edges[side] = Texture(tooltip, skin, "BORDER", 7);
	end
	skin.edges.top:SetHeight(2);
	skin.edges.bottom:SetHeight(2);
	skin.edges.left:SetWidth(2);
	skin.edges.right:SetWidth(2);
	tooltip:HookScript("OnSizeChanged", function()
		paint:LayoutSkin(tooltip, skin.extension);
	end);
	return skin;
end

local function CreateRoundedPieces(tooltip, skin)
	if (skin.cornerBorders) then
		return;
	end
	skin.backgroundStrips, skin.backgroundCorners, skin.cornerBorders = {}, {}, {};
	for index = 1, 2 do
		skin.backgroundStrips[index] = Texture(tooltip, skin, "BACKGROUND", -8);
	end
	for index = 1, 4 do
		local background = Texture(tooltip, skin, "BACKGROUND", -8);
		local border = Texture(tooltip, skin, "BORDER", 7);
		background:SetTexture(mediaPath .. "rounded-fill");
		border:SetTexture(mediaPath .. "rounded-border");
		background:SetTexCoord(unpack(cornerCoords[index]));
		border:SetTexCoord(unpack(cornerCoords[index]));
		skin.backgroundCorners[index], skin.cornerBorders[index] = background, border;
	end
end

local function HideNativeChrome(tooltip)
	if (tooltip.NineSlice) then
		tooltip.NineSlice:SetAlpha(0);
	end
	if (tooltip.SetBackdrop) then
		-- TipTac still owns the real backdrop; keep it transparent so the overlay is the visible chrome.
		pcall(tooltip.SetBackdropColor, tooltip, 0, 0, 0, 0);
	end
end

function paint:LayoutSkin(tooltip, extension)
	local skin = skins[tooltip];
	if (not skin) then
		return;
	end
	extension = math.max(0, tonumber(extension) or 0);
	skin.extension = extension;
	local radius = 10;
	local width, height = tooltip:GetWidth(), tooltip:GetHeight();
	if (type(width) == "number") and (width > 0) then
		radius = math.min(radius, width / 2);
	end
	if (type(height) == "number") and (height > 0) then
		radius = math.min(radius, (height + extension) / 2);
	end
	local background, edges = skin.background, skin.edges;
	background:ClearAllPoints();
	background:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, -radius);
	background:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, radius - extension);
	edges.top:ClearAllPoints();
	edges.top:SetPoint("TOPLEFT", tooltip, "TOPLEFT", radius, 0);
	edges.top:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -radius, 0);
	edges.bottom:ClearAllPoints();
	edges.bottom:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", radius, -extension);
	edges.bottom:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -radius, -extension);
	edges.left:ClearAllPoints();
	edges.left:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, -radius);
	edges.left:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 0, radius - extension);
	edges.right:ClearAllPoints();
	edges.right:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", 0, -radius);
	edges.right:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, radius - extension);
	if (not skin.rounded) then
		return;
	end
	CreateRoundedPieces(tooltip, skin);
	local top, bottom = skin.backgroundStrips[1], skin.backgroundStrips[2];
	top:ClearAllPoints();
	top:SetHeight(radius);
	top:SetPoint("TOPLEFT", tooltip, "TOPLEFT", radius, 0);
	top:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -radius, 0);
	bottom:ClearAllPoints();
	bottom:SetHeight(radius);
	bottom:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", radius, -extension);
	bottom:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -radius, -extension);
	for index, point in ipairs(cornerPoints) do
		local y = index > 2 and -extension or 0;
		for _, texture in ipairs({ skin.backgroundCorners[index], skin.cornerBorders[index] }) do
			texture:ClearAllPoints();
			texture:SetSize(radius, radius);
			texture:SetPoint(point, tooltip, point, 0, y);
		end
	end
end

function paint:ApplyTooltipSkin(tooltip)
	if (not tooltip) or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return;
	end
	local skin = skins[tooltip] or CreateSkin(tooltip);
	skin.rounded = true;
	CreateRoundedPieces(tooltip, skin);
	HideNativeChrome(tooltip);
	local br, bg, bb, ba = 0.12, 0.13, 0.15, 0.92;
	local rr, rg, rb, ra = 0.08, 0.72, 0.78, 1;
	if (cfg) and (cfg.tipColor) then
		br, bg, bb, ba = unpack(cfg.tipColor);
	end
	if (cfg) and (cfg.tipBorderColor) then
		rr, rg, rb, ra = unpack(cfg.tipBorderColor);
	end
	local ok, r, g, b, a = pcall(tooltip.GetBackdropColor, tooltip);
	if (ok) and (type(r) == "number") then
		br, bg, bb, ba = r, g, b, a;
	end
	ok, r, g, b, a = pcall(tooltip.GetBackdropBorderColor, tooltip);
	if (ok) and (type(r) == "number") then
		rr, rg, rb, ra = r, g, b, a;
	end
	pcall(tooltip.SetBackdropColor, tooltip, 0, 0, 0, 0);
	pcall(tooltip.SetBackdropBorderColor, tooltip, 0, 0, 0, 0);
	skin.background:SetColorTexture(br, bg, bb, 1);
	skin.background:SetAlpha(ba or 0.92);
	for _, edge in pairs(skin.edges) do
		edge:SetColorTexture(rr, rg, rb, ra);
	end
	if (skin.cornerBorders) then
		for _, strip in ipairs(skin.backgroundStrips) do
			strip:SetColorTexture(br, bg, bb, 1);
			strip:SetAlpha(ba or 0.92);
			strip:SetShown(true);
		end
		for index, corner in ipairs(skin.cornerBorders) do
			corner:SetVertexColor(rr, rg, rb, ra);
			corner:SetShown(true);
			local fill = skin.backgroundCorners[index];
			fill:SetVertexColor(br, bg, bb, 1);
			fill:SetAlpha(ba or 0.92);
			fill:SetShown(true);
		end
	end
	self:LayoutSkin(tooltip, 0);
end

function paint:OnConfigLoaded(_TT_CacheForFrames, _configDb, _cfg, _TT_ExtendedConfig)
	TT_CacheForFrames = _TT_CacheForFrames;
	configDb = _configDb;
	cfg = _cfg;
	TT_ExtendedConfig = _TT_ExtendedConfig;
end

function paint:OnApplyConfig(_TT_CacheForFrames, _configDb, _cfg, _TT_ExtendedConfig)
	self:OnConfigLoaded(_TT_CacheForFrames, _configDb, _cfg, _TT_ExtendedConfig);
	if (not TT_CacheForFrames) then
		return;
	end
	for tip in pairs(TT_CacheForFrames) do
		if (type(tip) == "table") and (tip.GetObjectType) then
			self:ApplyTooltipSkin(tip);
		end
	end
end

function paint:OnTipPostSetStyling(_TT_CacheForFrames, tip)
	TT_CacheForFrames = _TT_CacheForFrames or TT_CacheForFrames;
	self:ApplyTooltipSkin(tip);
end

function paint:OnTipResized(_TT_CacheForFrames, tip)
	TT_CacheForFrames = _TT_CacheForFrames or TT_CacheForFrames;
	self:ApplyTooltipSkin(tip);
end
