-----------------------------------------------------------------------
-- BetterTipTacTalents
--
-- Show player talents/specialization including role and talent/specialization icon and the average item level in the tooltip.
--

-- create addon
local MOD_NAME = ...;
local PARENT_MOD_NAME = "BetterTipTac";
local ttt = CreateFrame("Frame", MOD_NAME, nil, BackdropTemplateMixin and "BackdropTemplate");
ttt:Hide();

-- get libs
local LibFroznFunctions = LibStub:GetLibrary("LibFroznFunctions-1.0");

-- register with TipTac core addon if available
local TipTac = _G[PARENT_MOD_NAME];

if (TipTac) then
	LibFroznFunctions:RegisterForGroupEvents(PARENT_MOD_NAME, ttt, PARENT_MOD_NAME .. " - Talents Module");
end

----------------------------------------------------------------------------------------------------
--                                             Config                                             --
----------------------------------------------------------------------------------------------------

-- config
local configDb, cfg;
local TT_ExtendedConfig;
local TT_CacheForFrames;

-- default config
local TTT_DefaultConfig = {
	t_enable = true,                      -- "main switch", addon does nothing if false
	t_showTalents = true,                 -- show talents
	t_talentOnlyInParty = false,          -- only show talents/AIL for party/raid members
	t_talentDontShowOutOfRange = false,   -- don't show talents/AIL for players out of range
	
	t_showRoleIcon = true,                -- show role icon
	t_showTalentIcon = true,              -- show talent icon
	
	t_showTalentText = true,              -- show talent text
	t_colorTalentTextByClass = true,      -- color specialization text by class color
	t_talentFormat = 1,                   -- talent Format
	
	t_showAverageItemLevel = true,        -- show average item level (AIL)
	t_showGearScore = false,              -- show GearScore
	t_gearScoreAlgorithm =                -- GearScore algorithm
		LibFroznFunctions.hasWoWFlavor.defaultGearScoreAlgorithm,
	t_colorAILAndGSTextByQuality = true   -- color average item level and GearScore text by average quality
};

----------------------------------------------------------------------------------------------------
--                                           Variables                                            --
----------------------------------------------------------------------------------------------------

-- text constants
local TTT_TEXT = {
	talentsPrefix = ((LibFroznFunctions.hasWoWFlavor.specializationAvailable) and SPECIALIZATION or TALENTS), -- MoP: Could be changed from TALENTS (Talents) to SPECIALIZATION (Specialization)
	ailAndGSPrefix = STAT_AVERAGE_ITEM_LEVEL, -- Item Level
	onlyGSPrefix = "GearScore",
	loading = SEARCH_LOADING_TEXT, -- Loading...
	outOfRange = ERR_SPELL_OUT_OF_RANGE:sub(1, -2), -- Out of range.
	none = NONE_KEY, -- None
	-- na = NOT_APPLICABLE:lower() -- N/A
};

-- colors
local TTT_COLOR = {
	text = {
		default = HIGHLIGHT_FONT_COLOR, -- white
		spec = HIGHLIGHT_FONT_COLOR, -- white
		pointsSpent = LIGHTYELLOW_FONT_COLOR,
		ail = HIGHLIGHT_FONT_COLOR, -- white
		inlineGSPrefix = LIGHTYELLOW_FONT_COLOR
	}
};

----------------------------------------------------------------------------------------------------
--                                          Setup Addon                                           --
----------------------------------------------------------------------------------------------------

-- EVENT: addon loaded (one-time-event)
function ttt:ADDON_LOADED(event, addOnName, containsBindings)
	-- not this addon
	if (addOnName ~= MOD_NAME) then
		return;
	end
	
	-- setup config
	self:SetupConfig();
	
	-- apply hooks for inspecting
	self:ApplyHooksForInspecting();
	
	-- remove this event handler as it's not needed anymore
	self:UnregisterEvent(event);
	self[event] = nil;
end

-- register events
ttt:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...);
end);

ttt:RegisterEvent("ADDON_LOADED");

-- setup config
function ttt:SetupConfig()
	-- Use TipTac config if installed
	configDb, cfg = LibFroznFunctions:CreateDbWithLibAceDB("BetterTipTac_Config", TTT_DefaultConfig);
end

----------------------------------------------------------------------------------------------------
--                                         Element Events                                         --
----------------------------------------------------------------------------------------------------

function ttt:OnApplyConfig(_TT_CacheForFrames, _configDb, _cfg, _TT_ExtendedConfig)
	TT_CacheForFrames = _TT_CacheForFrames;
	TT_ExtendedConfig = _TT_ExtendedConfig;
end

----------------------------------------------------------------------------------------------------
--                                           Inspecting                                           --
----------------------------------------------------------------------------------------------------

-- hides "Item Level" lines in the unit tip (also lines added by other addons) if the option "Show Average Item Level (AIL)" is off.
local tttHideItemLevelActive = false; -- true while a unit tip is shown and the option is off. reset by OnTooltipCleared.

local function TTT_HideItemLevelLine(tip, i)
	local prefix = TTT_TEXT.ailAndGSPrefix;
	
	if (type(prefix) ~= "string") or (prefix == "") then
		return false;
	end
	
	local left = _G[tip:GetName() .. "TextLeft" .. i];
	local text = left and left:GetText();
	
	if (type(text) ~= "string") or (LibFroznFunctions:IsSecretValue(text)) then
		return false;
	end
	
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", "");
	
	if (text:sub(1, #prefix) == prefix) and ((#text == #prefix) or (text:sub(#prefix + 1):match("^[%s:]"))) then
		left:SetText(nil);
		
		local right = _G[tip:GetName() .. "TextRight" .. i];
		
		if (right) then
			right:SetText(nil);
		end
		
		return true;
	end
	
	return false;
end

local function TTT_HideItemLevelLines(tip)
	if (cfg.t_showAverageItemLevel) then
		return false;
	end
	
	local hidden = false;
	
	for i = 2, tip:NumLines() do
		if (TTT_HideItemLevelLine(tip, i)) then
			hidden = true;
		end
	end
	
	return hidden;
end

-- HOOK: GameTooltip:AddLine + GameTooltip:AddDoubleLine -- hide an item level line right when another addon adds it (same frame, so no flicker)
local function GTT_AddLine_Hook(self)
	if (tttHideItemLevelActive) and (not cfg.t_showAverageItemLevel) then
		TTT_HideItemLevelLine(self, self:NumLines());
	end
end

-- HOOK: GameTooltip's OnTooltipSetUnit -- will schedule a delayed inspect request
local tttTipLineIndexTalents, tttTipLineIndexAILAndGS;

local function GTT_OnTooltipSetUnit(self, ...)
	-- exit if "main switch" isn't enabled
	if (not cfg.t_enable) then
		return;
	end
	
	-- get the unit id -- check the UnitFrame unit if this tip is from a concated unit, such as "targettarget".
	local _, unitID = LibFroznFunctions:GetUnitFromTooltip(self);
	
	if (LibFroznFunctions:IsSecretValue(unitID)) or (not unitID) then
		local mouseFocus = LibFroznFunctions:GetMouseFocus();
		
		unitID = mouseFocus and mouseFocus.GetAttribute and mouseFocus:GetAttribute("unit");
	end
	
	-- no unit id or unit id is a secret value
	if (LibFroznFunctions:IsSecretValue(unitID)) or (not unitID) then
		return;
	end
	
	-- check if only talents/AIL for people in your party/raid should be shown
	if (cfg.t_talentOnlyInParty) and (not UnitInParty(unitID)) and (not UnitInRaid(unitID)) then
		return;
	end
	
	-- invalidate line indexes
	tttTipLineIndexTalents = nil;
	tttTipLineIndexAILAndGS = nil;
	
	-- hide item level lines if option is off. lines added later by other addons are hidden by GTT_AddLine_Hook().
	tttHideItemLevelActive = (not cfg.t_showAverageItemLevel);
	
	if (tttHideItemLevelActive) and (TTT_HideItemLevelLines(self)) then
		LibFroznFunctions:RecalculateSizeOfGameTooltip(self);
	end
	
	-- inspect unit
	local unitCacheRecord = LibFroznFunctions:InspectUnit(unitID, TTT_UpdateTooltip, true);
	
	if (unitCacheRecord) then
		TTT_UpdateTooltip(unitCacheRecord);
	end
end

-- apply hooks for inspecting during event ADDON_LOADED (one-time-function)
function ttt:ApplyHooksForInspecting()
	-- hooks needs to be applied as late as possible during load, as we want to try and be the
	-- last addon to hook GameTooltip's OnTooltipSetUnit so we always have a "completed" tip to work on.
	
	-- HOOK: GameTooltip's OnTooltipSetUnit -- will schedule a delayed inspect request
	LibFroznFunctions:HookScriptOnTooltipSetUnit(GameTooltip, GTT_OnTooltipSetUnit);
	GameTooltip:HookScript("OnTooltipCleared", function() tttHideItemLevelActive = false; end);
	hooksecurefunc(GameTooltip, "AddLine", GTT_AddLine_Hook);
	hooksecurefunc(GameTooltip, "AddDoubleLine", GTT_AddLine_Hook);
	
	-- remove this function as it's not needed anymore
	self.ApplyHooksForInspecting = nil;
end

----------------------------------------------------------------------------------------------------
--                                         Main Functions                                         --
----------------------------------------------------------------------------------------------------

-- update tooltip with the unit cache record
function TTT_UpdateTooltip(unitCacheRecord)
	-- exit if "main switch" isn't enabled
	if (not cfg.t_enable) then
		return;
	end
	
	-- exit if unit from unit cache record doesn't match the current displaying unit
	local _, unitID = LibFroznFunctions:GetUnitFromTooltip(GameTooltip);
	
	if (LibFroznFunctions:IsSecretValue(unitID)) or (not unitID) then
		return;
	end
	
	local unitGUID = UnitGUID(unitID);
	
	if (unitGUID ~= unitCacheRecord.guid) then
		return;
	end
	
	-- update tooltip with the unit cache record
	
	-- talents
	if (cfg.t_showTalents) and (unitCacheRecord.talents) then
		local specText = LibFroznFunctions:CreatePushArray();
		
		-- talents available but no inspect data
		if (unitCacheRecord.talents == LFF_TALENTS.available) then
			if (unitCacheRecord.canInspect) then
				specText:Push(TTT_TEXT.loading);
			else
				-- check if talents/AIL for people out of range shouldn't be shown
				if (not cfg.t_talentDontShowOutOfRange) then
					specText:Push(TTT_TEXT.outOfRange);
				end
			end
		
		-- no talents available
		elseif (unitCacheRecord.talents == LFF_TALENTS.na) then
			specText:Clear();
		
		-- no talents found
		elseif (unitCacheRecord.talents == LFF_TALENTS.none) then
			specText:Push(TTT_TEXT.none);
		
		-- talents found
		else
			local spacer, color;
			local talentFormat = (cfg.t_talentFormat or 1);
			local specNameAdded = false;
			
			if (cfg.t_showRoleIcon) and (unitCacheRecord.talents.role) then
				specText:Push(LibFroznFunctions:CreateMarkupForRoleIcon(unitCacheRecord.talents.role));
			end
			
			if (cfg.t_showTalentIcon) and (unitCacheRecord.talents.iconFileID) then
				spacer = (specText:GetCount() > 0) and " " or "";

				specText:Push(spacer .. LibFroznFunctions:CreateMarkupForClassIcon(unitCacheRecord.talents.iconFileID));
			end
			
			if (cfg.t_showTalentText) and ((talentFormat == 1) or (talentFormat == 2)) and (unitCacheRecord.talents.name) then
				spacer = (specText:GetCount() > 0) and " " or "";

				if (cfg.t_colorTalentTextByClass) then
					local classColor = LibFroznFunctions:GetClassColor(unitCacheRecord.classID, 5, cfg.enableCustomClassColors and TT_ExtendedConfig.customClassColors or nil);
					specText:Push(spacer .. classColor:WrapTextInColorCode(unitCacheRecord.talents.name));
				else
					specText:Push(spacer .. unitCacheRecord.talents.name);
				end
				
				specNameAdded = true;
			end
			
			if (cfg.t_showTalentText) and ((talentFormat == 1) or (talentFormat == 3)) and (unitCacheRecord.talents.pointsSpent) then
				spacer = (specText:GetCount() > 0) and " " or "";
				
				if (specNameAdded) then
					specText:Push(spacer .. TTT_COLOR.text.pointsSpent:WrapTextInColorCode("(" .. table.concat(unitCacheRecord.talents.pointsSpent, "/") .. ")"));
				else
					specText:Push(spacer .. TTT_COLOR.text.pointsSpent:WrapTextInColorCode(table.concat(unitCacheRecord.talents.pointsSpent, "/")));
				end
			end
		end
		
		-- show spec text
		if (specText:GetCount() > 0) then
			local tipLineTextTalents = LibFroznFunctions:FormatText("{prefix}: {specText}", {
				prefix = TTT_TEXT.talentsPrefix,
				specText = TTT_COLOR.text.spec:WrapTextInColorCode(specText:Concat())
			});
			
			if (tttTipLineIndexTalents) then
				_G["GameTooltipTextLeft" .. tttTipLineIndexTalents]:SetText(tipLineTextTalents);
			else
				GameTooltip:AddLine(tipLineTextTalents);
				tttTipLineIndexTalents = GameTooltip:NumLines();
			end
		end
	end
	
	-- average item level and GearScore
	if ((cfg.t_showAverageItemLevel) or (cfg.t_showGearScore)) and (unitCacheRecord.averageItemLevel) then
		local ailAndGSText = LibFroznFunctions:CreatePushArray();
		local useOnlyGSPrefix = false;
		
		-- average item level available or no item data
		if (unitCacheRecord.averageItemLevel == LFF_AVERAGE_ITEM_LEVEL.available) then
			if (unitCacheRecord.canInspect) then
				ailAndGSText:Push(TTT_TEXT.loading);
			else
				-- check if talents/AIL for people out of range shouldn't be shown
				if (not cfg.t_talentDontShowOutOfRange) then
					ailAndGSText:Push(TTT_TEXT.outOfRange);
				end
			end
		
		-- no average item level available
		elseif (unitCacheRecord.averageItemLevel == LFF_AVERAGE_ITEM_LEVEL.na) then
			ailAndGSText:Clear();
		
		-- no average item level found
		elseif (unitCacheRecord.averageItemLevel == LFF_AVERAGE_ITEM_LEVEL.none) then
			ailAndGSText:Push(TTT_TEXT.none);
		
		-- average item level found
		elseif (unitCacheRecord.averageItemLevel) then
			local spacer;
			
			-- average item level
			if (cfg.t_showAverageItemLevel) then
				local averageItemLevel = (unitCacheRecord.averageItemLevel.value > 0) and unitCacheRecord.averageItemLevel.value or "-";
				
				if (cfg.t_colorAILAndGSTextByQuality) then
					ailAndGSText:Push(unitCacheRecord.averageItemLevel.qualityColor:WrapTextInColorCode(averageItemLevel));
				else
					ailAndGSText:Push(averageItemLevel);
				end
			end
			
			-- GearScore
			if (cfg.t_showGearScore) then
				spacer = (ailAndGSText:GetCount() > 0) and ("  " .. TTT_COLOR.text.inlineGSPrefix:WrapTextInColorCode("GS: ")) or "";
				
				if (ailAndGSText:GetCount() == 0) then
					useOnlyGSPrefix = true;
				end
				
				local gearScore;
				
				if (cfg.t_gearScoreAlgorithm == LFF_GEAR_SCORE_ALGORITHM.TacoTip) then -- TacoTip's GearScore algorithm
					gearScore = (unitCacheRecord.averageItemLevel.TacoTipGearScore > 0) and unitCacheRecord.averageItemLevel.TacoTipGearScore or "-";
					
					if (cfg.t_colorAILAndGSTextByQuality) then
						ailAndGSText:Push(spacer .. unitCacheRecord.averageItemLevel.TacoTipGearScoreQualityColor:WrapTextInColorCode(gearScore));
					else
						ailAndGSText:Push(spacer .. gearScore);
					end
				else -- TipTac's GearScore algorithm
					gearScore = (unitCacheRecord.averageItemLevel.TipTacGearScore > 0) and unitCacheRecord.averageItemLevel.TipTacGearScore or "-";
					
					if (cfg.t_colorAILAndGSTextByQuality) then
						ailAndGSText:Push(spacer .. unitCacheRecord.averageItemLevel.TipTacGearScoreQualityColor:WrapTextInColorCode(gearScore));
					else
						ailAndGSText:Push(spacer .. gearScore);
					end
				end
			end
		end
		
		-- show ail and GS text
		if (ailAndGSText:GetCount() > 0) then
			local tipLineTextAverageItemLevel = LibFroznFunctions:FormatText("{prefix}: {averageItemLevelAndGearScore}", {
				prefix = useOnlyGSPrefix and TTT_TEXT.onlyGSPrefix or TTT_TEXT.ailAndGSPrefix,
				averageItemLevelAndGearScore = TTT_COLOR.text.ail:WrapTextInColorCode(ailAndGSText:Concat())
			});
			
			if (tttTipLineIndexAILAndGS) then
				_G["GameTooltipTextLeft" .. tttTipLineIndexAILAndGS]:SetText(tipLineTextAverageItemLevel);
			else
				GameTooltip:AddLine(tipLineTextAverageItemLevel);
				tttTipLineIndexAILAndGS = GameTooltip:NumLines();
			end
		end
	end
	
	-- hide item level lines if option is off
	TTT_HideItemLevelLines(GameTooltip);
	
	-- recalculate size of tip to ensure that it has the correct dimensions
	LibFroznFunctions:RecalculateSizeOfGameTooltip(GameTooltip);
end

----------------------------------------------------------------------------------------------------
--                                   Diagnostics (WoW: Forever)                                   --
----------------------------------------------------------------------------------------------------

-- prints what the talent APIs return, e.g. to review how talents work on WoW: Forever.
-- usage: "/tttdump" (own character) or "/tttdump target" (after inspecting the target, e.g. by hovering it for a moment).
SLASH_BETTERTIPTACDUMP1 = "/bttdump";

SlashCmdList["BETTERTIPTACDUMP"] = function(msg)
	local unitID = (msg and msg:match("%S+")) or "player";
	
	local function out(...)
		local parts = { "|cff33ff99TTT|r" };
		for i = 1, select("#", ...) do
			parts[#parts + 1] = tostring((select(i, ...)));
		end
		print(table.concat(parts, " "));
	end
	
	local function describe(v)
		if (type(v) ~= "table") then
			return tostring(v);
		end
		local parts = {};
		for k, val in pairs(v) do
			parts[#parts + 1] = tostring(k) .. "=" .. ((type(val) == "table") and ("{" .. #val .. " items}") or tostring(val));
		end
		return "{ " .. table.concat(parts, ", ") .. " }";
	end
	
	local function try(label, fn)
		local ok, res = pcall(fn);
		out(label, ok and describe(res) or ("ERROR: " .. tostring(res)));
		return ok and res or nil;
	end
	
	out("interface", select(4, GetBuildInfo()), "isForever", LibFroznFunctions.isForever, "unit", unitID);
	out("exists: GetSpecialization", type(GetSpecialization), "C_SpecializationInfo", type(C_SpecializationInfo), "C_Traits", type(C_Traits), "C_ClassTalents", type(C_ClassTalents), "GetTalentTabInfo", type(GetTalentTabInfo));
	
	local isSelf = UnitIsUnit(unitID, "player");
	local configID;
	
	if (isSelf) then
		configID = try("activeConfigID", function() return C_ClassTalents.GetActiveConfigID(); end);
	else
		try("HasValidInspectData", function() return C_Traits.HasValidInspectData(); end);
		configID = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID;
		out("inspect configID", configID);
	end
	
	if (configID) then
		local configInfo = try("configInfo", function() return C_Traits.GetConfigInfo(configID); end);
		
		if (type(configInfo) == "table") and (type(configInfo.treeIDs) == "table") then
			for i, treeID in ipairs(configInfo.treeIDs) do
				try("tree " .. i .. " id", function() return treeID; end);
				try("tree " .. i .. " info", function() return C_Traits.GetTreeInfo(configID, treeID); end);
				
				if (i == 1) and (C_Traits.GetTreeNodes) then
					local nodeIDs = C_Traits.GetTreeNodes(treeID) or {};
					out("tree 1 node count", #nodeIDs);
					for n = 1, math.min(#nodeIDs, 12) do
						try("  node " .. n, function() local ni = C_Traits.GetNodeInfo(configID, nodeIDs[n]); return { id = ni.ID, x = ni.posX, y = ni.posY, rank = ni.currentRank, maxRanks = ni.maxRanks, type = ni.type }; end);
					end
				end
				
				-- nodes with points spent (to see in which column the points are)
				if (C_Traits.GetTreeNodes) and (C_Traits.GetNodeInfo) then
					local minX, maxX, ranked, shown = nil, nil, 0, 0;
					local sums = { 0, 0, 0 };
					local nodeList = C_Traits.GetTreeNodes(treeID) or {};
					
					for _, nodeID in ipairs(nodeList) do
						local ni = C_Traits.GetNodeInfo(configID, nodeID);
						if (type(ni) == "table") and (type(ni.posX) == "number") then
							minX = (not minX) and ni.posX or math.min(minX, ni.posX);
							maxX = (not maxX) and ni.posX or math.max(maxX, ni.posX);
						end
					end
					
					out("tree " .. i .. " nodes", #nodeList, "minX", minX, "maxX", maxX);
					
					for _, nodeID in ipairs(nodeList) do
						local ni = C_Traits.GetNodeInfo(configID, nodeID);
						if (type(ni) == "table") then
							local rank = tonumber(ni.currentRank) or 0;
							if (rank > 0) or ((tonumber(ni.activeRank) or 0) > 0) or ((tonumber(ni.ranksPurchased) or 0) > 0) then
								ranked = ranked + 1;
								if (minX) and (maxX) and (maxX > minX) and (type(ni.posX) == "number") then
									local column = math.min(3, math.floor((ni.posX - minX) / ((maxX - minX) / 3)) + 1);
									sums[column] = sums[column] + rank;
								end
								if (shown < 25) then
									shown = shown + 1;
									out("  ranked node", "id", ni.ID, "x", ni.posX, "y", ni.posY, "currentRank", ni.currentRank, "activeRank", ni.activeRank, "ranksPurchased", ni.ranksPurchased);
								end
							end
						end
					end
					
					out("tree " .. i .. " ranked nodes", ranked, "points per equal-third column (old method, may be wrong)", sums[1] .. "/" .. sums[2] .. "/" .. sums[3]);
					
					-- layout: for every distinct x position "x=points/nodes"
					local xPoints, xNodes, xList = {}, {}, {};
					local firstRanked;
					
					for _, nodeID in ipairs(nodeList) do
						local ni = C_Traits.GetNodeInfo(configID, nodeID);
						if (type(ni) == "table") and (type(ni.posX) == "number") then
							if (not xNodes[ni.posX]) then
								xNodes[ni.posX], xPoints[ni.posX] = 0, 0;
								xList[#xList + 1] = ni.posX;
							end
							xNodes[ni.posX] = xNodes[ni.posX] + 1;
							xPoints[ni.posX] = xPoints[ni.posX] + (tonumber(ni.currentRank) or 0);
							if (not firstRanked) and ((tonumber(ni.currentRank) or 0) > 0) then
								firstRanked = ni;
							end
						end
					end
					
					table.sort(xList);
					local parts = {};
					for _, x in ipairs(xList) do
						parts[#parts + 1] = x .. "=" .. xPoints[x] .. "/" .. xNodes[x];
						if (#parts == 8) then
							out("  x layout", table.concat(parts, "  "));
							parts = {};
						end
					end
					if (#parts > 0) then
						out("  x layout", table.concat(parts, "  "));
					end
					
					-- all fields of the first node with points (to look for a specialization/tab field)
					if (firstRanked) then
						local fieldParts = {};
						for k, v in pairs(firstRanked) do
							local text = tostring(v);
							if (type(v) == "table") then
								local items = {};
								for n = 1, math.min(#v, 8) do
									items[#items + 1] = tostring(v[n]);
								end
								text = "{" .. table.concat(items, ",") .. "}";
							end
							fieldParts[#fieldParts + 1] = tostring(k) .. "=" .. text;
							if (#fieldParts == 5) then
								out("  first ranked node fields", table.concat(fieldParts, ", "));
								fieldParts = {};
							end
						end
						if (#fieldParts > 0) then
							out("  first ranked node fields", table.concat(fieldParts, ", "));
						end
					end
				end
				
				local currencies = try("tree " .. i .. " currencies", function() return C_Traits.GetTreeCurrencyInfo(configID, treeID, false); end);
				
				if (type(currencies) == "table") then
					for j, currency in ipairs(currencies) do
						try("  currency " .. j, function() return currency; end);
					end
				end
			end
		end
	end
	
	local result = try("GetTalents result", function() return LibFroznFunctions:GetTalents(unitID); end);
	
	if (type(result) == "table") and (type(result.pointsSpent) == "table") then
		out("GetTalents pointsSpent", table.concat(result.pointsSpent, "/"), "name", result.name);
	end
	
	out("unit class", select(2, UnitClass(unitID)), "hasPet", UnitExists("pet") and "yes" or "no");
end;
