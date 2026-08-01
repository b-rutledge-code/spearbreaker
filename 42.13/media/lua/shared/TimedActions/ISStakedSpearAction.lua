require "TimedActions/ISBaseTimedAction"

-- Place a spear tip-down on soft ground as a Spearbreaker staked spear.
ISStakedSpearAction = ISBaseTimedAction:derive("ISStakedSpearAction")

-- Tip-in-ground vertical. HandWeapons already get a flat "weapon fix" transform; worldX
-- spins along the shaft (still looks flat). Pitch with worldY (→ render angle.z).
-- HandWeapon maps angle.x←worldX, angle.y←worldZ, angle.z←worldY.
local TIP_DOWN_WORLD_X = 0
local TIP_DOWN_WORLD_Y = 270
local TIP_DOWN_WORLD_Z = 0
-- Square-local offsets: 0.5/0.5 = tile center (0/0 randomizes). Z lifts tip out of the ground.
local STAKE_OFF_X = 0.5
local STAKE_OFF_Y = 0.5
local STAKE_OFF_Z = 0.18

function ISStakedSpearAction:isValid()
	if not self.square or not self.item then return false end
	if isClient() then
		return self.character:getInventory():containsID(self.item:getID())
	end
	return self.character:getInventory():contains(self.item)
end

function ISStakedSpearAction:update()
	self.item:setJobDelta(self:getJobDelta())
end

function ISStakedSpearAction:start()
	if isClient() and self.item then
		self.item = self.character:getInventory():getItemById(self.item:getID())
	end
	self.item:setJobType(getText("UI_Spearbreaker_StakedSpear"))
	self.item:setJobDelta(0.0)
	self:setActionAnim("Loot")
end

function ISStakedSpearAction:stop()
	self.item:setJobDelta(0.0)
	ISBaseTimedAction.stop(self)
end

function ISStakedSpearAction:complete()
	if isClient() and self.item then
		self.item = self.character:getInventory():getItemById(self.item:getID())
	end
	if not self.item then return false end

	if self.character:isHandItem(self.item) then
		self.character:removeFromHands(self.item)
	end

	local worldItem = self.square:AddWorldInventoryItem(self.item, STAKE_OFF_X, STAKE_OFF_Y, STAKE_OFF_Z, false)
	if worldItem then
		worldItem:setWorldXRotation(TIP_DOWN_WORLD_X)
		worldItem:setWorldYRotation(TIP_DOWN_WORLD_Y)
		worldItem:setWorldZRotation(TIP_DOWN_WORLD_Z)
		local md = worldItem:getModData()
		md.SpearbreakerStaked = true
		md.SpearbreakerOwner = self.ownerId
		local wi = worldItem:getWorldItem()
		if wi then
			wi:setIgnoreRemoveSandbox(true)
			wi:setExtendedPlacement(true)
		end
	end

	self.character:getInventory():Remove(self.item)
	sendRemoveItemFromContainer(self.character:getInventory(), self.item)
	triggerEvent("OnContainerUpdate")
	return true
end

function ISStakedSpearAction:perform()
	if self.item and self.item:getContainer() then
		self.item:getContainer():setDrawDirty(true)
	end
	self.item:setJobDelta(0.0)
	ISInventoryPage.renderDirty = true
	ISBaseTimedAction.perform(self)
end

function ISStakedSpearAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 40
end

function ISStakedSpearAction:new(character, item, square, ownerId)
	local o = ISBaseTimedAction.new(self, character)
	o.character = character
	o.item = item
	o.square = square
	o.ownerId = ownerId
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
