local addonName, addon = ...

addon = LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- TODO: Check if Pawn is loaded and enabled.
addon.pawn = false

local gameVersion = select(4, GetBuildInfo())
addon.gameVersion = gameVersion

if gameVersion > 40000 then
	addon.game = "RETAIL"
elseif gameVersion > 30000 then
	addon.game = "WOTLK"
elseif gameVersion > 20000 then
	addon.game = "TBC"
else
	addon.game = "CLASSIC"
end

local _G = _G

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
addon.title = GetAddOnMetadata(addonName, "Title")

addon.myArmory = {}
addon.invSlots = {}
addon.bagSlots = {}

addon.scaleName = nil

----------------------------------------------------------------------
--Ace Interface
----------------------------------------------------------------------
function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(addon.title .. "DB", self.defaults)

	AceConfig:RegisterOptionsTable(addon.title .. "_Options", self.options)
	self.optionsFrame = AceConfigDialog:AddToBlizOptions(addon.title .. "_Options", addon.title)

	AceConfig:RegisterOptionsTable(addon.title .. "_paperDoll", self.paperDoll)
	AceConfigDialog:AddToBlizOptions(addon.title .. "_paperDoll", "Paper Doll", addon.title)

	self:GetCharacterInfo()

	self:RegisterChatCommand(addon.title, "SlashCommand")
	self:RegisterChatCommand("EZ", "SlashCommand")
end

function addon:GetCharacterInfo()
	-- stores character-specific data
	self.db.char.level = UnitLevel("player")
	self.db.char.classId = select(3, UnitClass("player"))
end

function addon:SlashCommand(input, editbox)
	if input == "enable" then
		self:Enable()
		self:Print("Enabled.")
	elseif input == "disable" then
		-- unregisters all events and calls addon:OnDisable() if you defined that
		self:Disable()
		self:Print("Disabled.")
	elseif input == "run" then
		self:AdornSet()
		self:Print("Running..")
	-- elseif input == "message" then
	--   print("this is our saved message:", self.db.profile.someInput)
	else
		self:Print("Opening Options window.")
		-- https://github.com/Stanzilla/WoWUIBugs/issues/89
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
		--[[ 
    --or as a standalone window
    if ACD.OpenFrames["addon_Options"] then
      ACD:Close("addon_Options")
    else
      ACD:Open("addon_Options")
    end
    ]]
	end
end

function addon:OnEnable()
	--triggers
	self:RegisterEvent("PLAYER_LEVEL_UP", "autoTrigger")
	self:RegisterEvent("QUEST_TURNED_IN", "autoTrigger")
	self:RegisterEvent("LOOT_CLOSED", "autoTrigger")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "autoTrigger")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "autoTrigger")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "autoTrigger")
	self:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED", "autoTrigger")
end

local lastEventTime = {}
local timeThreshold = 7 -- in seconds

-- Event handler to automate the AdornSet() function.
function addon:autoTrigger(event)
	-- check if the player is in combat, if so return.
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		return
	end

	--check if the player has a fishing pole equipped.
	--exception: auto equipping while fishing can be annoying.
	local itemId = GetInventoryItemID("player", 16)
	if itemId and select(7, GetItemInfo(itemId)) == "Fishing Poles" then
		return
	end

	local currentTime = GetTime()

	if not lastEventTime[event] or (currentTime - lastEventTime[event] > timeThreshold) then
		self:AdornSet()
		lastEventTime[event] = currentTime
	end
end

--Helper function to put items on.
function addon:PutTheseOn(theoreticalSet)
	-- Check if theoreticalSet is not nil and not empty
	if not theoreticalSet or next(theoreticalSet) == nil then
		return
	end

	for _, item in pairs(theoreticalSet) do
		-- Check if item properties are not nil
		if item and item.hex and item.slotId then
			local action = self:SetupEquipAction(item.hex, item.slotId)
			if action then
				self:RunAction(action)
			end
		end
	end
end

function addon:AdornSet()
	addon.myArmory = {}
	local myArmory = addon.myArmory
	addon:UpdateArmory()
	-- Use myArmory to decide what to equip.
	--Theorize best sets of items.
	local weaponSet, armorSet, ringSet, trinketSet = addon.TheorizeSet(myArmory)

	-- Put on the items that we want to equip.
	local sets = { armorSet, ringSet, trinketSet, weaponSet }

	for _, set in ipairs(sets) do
		if set then
			addon:PutTheseOn(set)
		end
	end

	ClearCursor()
end
