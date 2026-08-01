require "TimedActions/ISTransferAction"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISDropWorldItemAction"
require "TimedActions/ISDetachItemHotbar"
require "TimedActions/ISAttachItemHotbarNoStopOnAim"
require "TimedActions/ISEquipWeaponAction"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISStakedSpearAction"
require "Items/OnBreak"

local pendingEquipFromBack = {}   -- [playerNum] = timestamp when break happened (for fallback timeout)
local equipReadyFromAttackFinished = {}  -- set when OnPlayerAttackFinished fires so we equip next frame
local equipOneShotHandlers = {}   -- [playerNum] = one-shot handler (so we can remove it on fallback)
local pendingAttachFromInventory = {}  -- [playerNum] = timestamp when R pressed (try until success or timeout)
-- After a spear break: empty hands + R equips a spare to hands for a short window.
local reloadGraceUntilMs = {}  -- [playerNum] = getTimestampMs() deadline
local RELOAD_GRACE_AFTER_BREAK_MS = 5000

local function isSpear(item)
    if not item or item:getCategory() ~= 'Weapon' then return false end
    local scriptItem = item:getScriptItem()
    if not scriptItem or not scriptItem.containsWeaponCategory then return false end
    return scriptItem:containsWeaponCategory(WeaponCategory.SPEAR)
end

-- B42: When spears break, player holds LongStick_Broken instead of nil
local function isBrokenSpearPiece(item)
    return item and item:getFullType() == "Base.LongStick_Broken"
end

local function findAllSpears(player)
    local spears = player:getInventory():getAllEvalRecurse(function(item)
        return isSpear(item)
    end)
    if type(spears) == "userdata" then
        local t = {}
        for i = 0, spears:size() - 1 do
            t[i + 1] = spears:get(i)
        end
        return t
    end
    return type(spears) == "table" and spears or {}
end

-- Prefer main-inventory spare; else return a bag spare (no transfer here).
-- Attach path uses transferIfNeeded so one R incurs bag-transfer time, then attaches — no second press.
local function getAvailableSpear(player)
    local spears = findAllSpears(player)
    if not spears or #spears == 0 then return nil end

    local player_inv = player:getInventory()
    local main, other = {}, {}

    for _, spear in ipairs(spears) do
        if spear:getContainer() == player_inv then
            table.insert(main, spear)
        else
            table.insert(other, spear)
        end
    end

    local function usableSpare(item)
        return isSpear(item) and item:getAttachedSlot() ~= 1 and not item:isEquipped() and not item:isBroken()
    end

    for _, item in ipairs(main) do
        if usableSpare(item) then return item end
    end
    for _, item in ipairs(other) do
        if usableSpare(item) then return item end
    end
    return nil
end

-- Back slot = hotbar slot 1. Use hotbar as source of truth.
local function getBackSlotSpear(player)
    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if hotbar and hotbar.attachedItems and hotbar.attachedItems[1] then
        local item = hotbar.attachedItems[1]
        if isSpear(item) and not item:isBroken() then
            return item
        end
    end
    return nil
end

-- Wrap HandleHandler: for spear breaks, drop LongStick_Broken to ground instead of putting in hand.
-- This prevents the broken swing. Never call original for spear breaks—vanilla would put broken piece in hand.
local originalHandleHandler = OnBreak.HandleHandler
function OnBreak.HandleHandler(item, player, newItemString, breakItem)
    if not item then return end
    local cont = item:getContainer()
    local isSpearBreak = isSpear(item) and newItemString == "Base.LongStick_Broken"
    if isSpearBreak then
        local sq = player and player:getCurrentSquare()
        if not sq and item:getWorldItem() and item:getWorldItem():getSquare() then
            sq = item:getWorldItem():getSquare()
        end
        if sq then
            local newItem = sq:AddWorldInventoryItem(newItemString, ZombRand(100)/100, ZombRand(100)/100, 0.0)
            if newItem then
                if breakItem then
                    newItem:setCondition(0)
                else
                    newItem:setCondition(ZombRand(newItem:getConditionMax()) + 1)
                end
                newItem:copyBloodLevelFrom(item)
                if newItem:hasSharpness() and item:hasSharpness() then
                    newItem:setSharpnessFrom(item)
                end
                newItem:SynchSpawn()
            end
            item:Remove()
            triggerEvent("OnContainerUpdate")
                if player and cont == player:getInventory() and not isServer() then
                    local playerNum = player:getPlayerNum()
                    reloadGraceUntilMs[playerNum] = (getTimestampMs() or 0) + RELOAD_GRACE_AFTER_BREAK_MS
                    local hotbar = getPlayerHotbar(playerNum)
                    local back_slot_spear = getBackSlotSpear(player)
                    if hotbar and back_slot_spear then
                        pendingEquipFromBack[playerNum] = getTimestamp() or 0
                        -- Equip as soon as this swing ends (OnPlayerAttackFinished), not after a fixed delay
                        local oneShot
                        oneShot = function(p, _)
                            if p == player then
                                Events.OnPlayerAttackFinished.Remove(oneShot)
                                equipOneShotHandlers[playerNum] = nil
                                equipReadyFromAttackFinished[playerNum] = true
                            end
                        end
                        equipOneShotHandlers[playerNum] = oneShot
                        Events.OnPlayerAttackFinished.Add(oneShot)
                    end
                end
        else
            item:Remove()
            triggerEvent("OnContainerUpdate")
        end
    else
        originalHandleHandler(item, player, newItemString, breakItem)
    end
end

-- Spear / broken piece in hand → stage to back. Empty hands during post-break grace → equip to hands.
-- Equipping anything else clears the grace window.
local function isPostBreakEmptyHandGrace(player)
    local equipped = player:getPrimaryHandItem()
    local playerNum = player:getPlayerNum()
    local untilMs = reloadGraceUntilMs[playerNum]
    if not untilMs then return false end
    local now = getTimestampMs() or 0
    if now > untilMs then
        reloadGraceUntilMs[playerNum] = nil
        return false
    end
    if equipped then
        if isSpear(equipped) or isBrokenSpearPiece(equipped) then return false end
        reloadGraceUntilMs[playerNum] = nil
        return false
    end
    return true
end

local function handsHoldingSpearOrBroken(player)
    local equipped = player:getPrimaryHandItem()
    return isSpear(equipped) or isBrokenSpearPiece(equipped)
end

local function pollEquipWhenReady(player)
    local playerNum = player:getPlayerNum()
    local when = pendingEquipFromBack[playerNum]
    if not when then return end
    local now = getTimestamp() or 0
    local elapsed = now - when
    -- Prefer: equip on first update after attack finished (no magic delay)
    local ready = equipReadyFromAttackFinished[playerNum]
    -- Fallback: if OnPlayerAttackFinished never fired (e.g. death), equip after 2s
    if not ready and elapsed < 2.0 then return end
    -- Remove one-shot if we're taking the fallback path (event never fired)
    local oneShot = equipOneShotHandlers[playerNum]
    if oneShot then
        Events.OnPlayerAttackFinished.Remove(oneShot)
        equipOneShotHandlers[playerNum] = nil
    end
    pendingEquipFromBack[playerNum] = nil
    equipReadyFromAttackFinished[playerNum] = nil
    if player:isDead() then return end
    local hotbar = getPlayerHotbar(playerNum)
    local spear = getBackSlotSpear(player)
    if hotbar and spear then
        hotbar:equipItem(spear)
    end
end

local RELOAD_COOLDOWN_MS = 300
local lastReloadKeyMs = 0

-- Spear in hand: stage spare onto back (pipeline).
local function attachSpearToBackFromInventory()
    local player = getPlayer()
    if not player then return false end
    if player:isRunning() then return false end

    local queue = ISTimedActionQueue.queues[player]
    if queue and #queue.queue > 0 then return false end

    if not handsHoldingSpearOrBroken(player) then return false end

    local back_slot_spear = getBackSlotSpear(player)
    if back_slot_spear and not back_slot_spear:isEquipped() then return false end

    local new_spear = getAvailableSpear(player)
    if not new_spear then return false end

    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if not hotbar then return false end
    if not hotbar.availableSlot or not hotbar.availableSlot[1] then return false end

    local slot = hotbar.availableSlot[1]
    local slotDef = slot.def
    -- Use vanilla slot resolution: attachments[type] then Back replacement if any
    local attachSlot = (slotDef.attachments and new_spear:getAttachmentType() and slotDef.attachments[new_spear:getAttachmentType()])
        or 'Shovel Back'
    if slotDef.name == "Back" and hotbar.replacements and hotbar.replacements[new_spear:getAttachmentType()] then
        attachSlot = hotbar.replacements[new_spear:getAttachmentType()]
    end
    if attachSlot == "null" then return false end
    hotbar:setAttachAnim(new_spear, slotDef)
    ISInventoryPaneContextMenu.transferIfNeeded(player, new_spear)
    if hotbar.attachedItems[1] then
        ISTimedActionQueue.add(ISDetachItemHotbar:new(player, hotbar.attachedItems[1]))
    end
    ISTimedActionQueue.add(ISAttachItemHotbarNoStopOnAim:new(player, new_spear, attachSlot, 1, slotDef))
    reloadGraceUntilMs[player:getPlayerNum()] = nil
    return true
end

-- Empty hands after break: equip spare to hands (transfer time still applies; slower than back→hand).
local function equipSpearToHandsFromInventory()
    local player = getPlayer()
    if not player then return false end
    if player:isRunning() then return false end

    local queue = ISTimedActionQueue.queues[player]
    if queue and #queue.queue > 0 then return false end

    if not isPostBreakEmptyHandGrace(player) then return false end

    local new_spear = getAvailableSpear(player)
    if not new_spear then return false end

    -- Vanilla equipWeapon path: transfer into main inv if needed, then two-handed equip.
    ISInventoryPaneContextMenu.transferIfNeeded(player, new_spear)
    ISTimedActionQueue.add(ISEquipWeaponAction:new(player, new_spear, 50, true, true))
    reloadGraceUntilMs[player:getPlayerNum()] = nil
    return true
end

local function canAttachSpearToBackFromInventory(player)
    if not player or player:isRunning() then return false end
    if not handsHoldingSpearOrBroken(player) then return false end
    local back_slot_spear = getBackSlotSpear(player)
    if back_slot_spear and not back_slot_spear:isEquipped() then return false end
    if not getAvailableSpear(player) then return false end
    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if not hotbar or not hotbar.availableSlot or not hotbar.availableSlot[1] then return false end
    return true
end

local function canEquipSpearToHandsFromInventory(player)
    if not player or player:isRunning() then return false end
    if not isPostBreakEmptyHandGrace(player) then return false end
    if not getAvailableSpear(player) then return false end
    return true
end

local function canReloadSpear(player)
    return canAttachSpearToBackFromInventory(player) or canEquipSpearToHandsFromInventory(player)
end

-- Try reload action when queue is empty. No fixed delay—retry until success or timeout.
-- Long enough for bag→main transfer timed action + attach/equip anim (one R queues both).
local PENDING_ATTACH_TIMEOUT_MS = 8000
local function pollAttachWhenReady(player)
    local playerNum = player:getPlayerNum()
    local when = pendingAttachFromInventory[playerNum]
    if not when then return end
    local elapsed = (getTimestampMs() or 0) - when
    if elapsed > PENDING_ATTACH_TIMEOUT_MS then
        pendingAttachFromInventory[playerNum] = nil
        return
    end
    local queue = ISTimedActionQueue.queues[player]
    if queue and #queue.queue > 0 then return end
    local ok = false
    if isPostBreakEmptyHandGrace(player) then
        ok = equipSpearToHandsFromInventory()
    else
        ok = attachSpearToBackFromInventory()
    end
    if ok then
        pendingAttachFromInventory[playerNum] = nil
    end
end

Events.OnPlayerUpdate.Add(pollEquipWhenReady)
Events.OnPlayerUpdate.Add(pollAttachWhenReady)

-- B42: spear breaks → LongStick_Broken in hand. Player auto-swings it and interrupts timed actions.
-- Wait for the broken-piece swing to finish (next OnPlayerAttackFinished) before queuing.
local function doSwap(player, in_hand, back_slot_spear, hotbar)
    if in_hand then
        local sq = player:getCurrentSquare()
        if sq then
            if player:isHandItem(in_hand) then
                ISTimedActionQueue.add(ISUnequipAction:new(player, in_hand, 1))
            end
            local dropX, dropY, dropZ = ISTransferAction.GetDropItemOffset(player, sq, in_hand)
            ISTimedActionQueue.add(ISDropWorldItemAction:new(player, in_hand, sq, dropX, dropY, dropZ, 0, false))
        end
    end
    if back_slot_spear and hotbar then
        hotbar:equipItem(back_slot_spear)
    end
end

local function swapSpears(player, weapon)
    if not player then return end
    local in_hand = weapon or player:getPrimaryHandItem()
    local should_swap = not in_hand
        or isBrokenSpearPiece(in_hand)
        or (isSpear(in_hand) and in_hand:isBroken())
    if not should_swap then return end

    local back_slot_spear = getBackSlotSpear(player)
    local hotbar = getPlayerHotbar(player:getPlayerNum())

    local handler
    handler = function(p, _)
        if p == player then
            Events.OnPlayerAttackFinished.Remove(handler)
            doSwap(player, in_hand, back_slot_spear, hotbar)
        end
    end
    Events.OnPlayerAttackFinished.Add(handler)
end
Events.OnPlayerAttackFinished.Add(swapSpears)

local function reloadSpearFromInventory(keynum)
    if not getCore():isKey("ReloadWeapon", keynum) and not getCore():isKey("Hotbar 1", keynum) then return end
    local player = getPlayer()
    if not player then return end
    if player:isDead() then return end
    if UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then return end

    local now = getTimestampMs()
    if now - lastReloadKeyMs < RELOAD_COOLDOWN_MS then return end
    lastReloadKeyMs = now

    if not canReloadSpear(player) then return end
    pendingAttachFromInventory[player:getPlayerNum()] = getTimestampMs() or 0
end

Events.OnKeyStartPressed.Add(reloadSpearFromInventory)
Events.OnKeyPressed.Add(reloadSpearFromInventory)

-- Faster spear swing (Spearbreaker trait only): drain melee delay faster so next attack can start sooner (vanilla drains 0.625/frame).
-- Bigger impact early (low Spear), tapers off as Spear level increases.
local SPEAR_MELEE_DRAIN_BASE = 0.35    -- extra drain at Spear 0 (noticeable but not spammy)
local SPEAR_MELEE_DRAIN_PER_LEVEL = -0.025  -- subtract per level (less benefit over time)
local SPEAR_MELEE_DRAIN_MIN = 0.12     -- floor so high level still gets a small boost
-- Vanilla API (installed game Lua): CharacterTrait.get(ResourceLocation.of(id))
local SPEARBREAKER_TRAIT = CharacterTrait.get(ResourceLocation.of("spearbreaker:spearbreaker"))
local function drainSpearMeleeDelayFaster(player)
    if not player or player ~= getPlayer() or player:isDead() then return end
    if not SPEARBREAKER_TRAIT or not player:hasTrait(SPEARBREAKER_TRAIT) then return end
    local weapon = player:getPrimaryHandItem()
    if not weapon or not isSpear(weapon) then return end
    local delay = player:getMeleeDelay()
    if delay <= 0 then return end
    local level = player:getPerkLevel(PerkFactory.Perks.Spear) or 0
    local bonus = math.max(SPEAR_MELEE_DRAIN_MIN, SPEAR_MELEE_DRAIN_BASE + level * SPEAR_MELEE_DRAIN_PER_LEVEL)
    local mult = getGameTime() and getGameTime():getMultiplier() or 1.0
    player:setMeleeDelay(math.max(0, delay - bonus * mult))
end
Events.OnPlayerUpdate.Add(drainSpearMeleeDelayFaster)

-- --- Staked spears (Phase 1 SP) -------------------------------------------------

local function getLocalOwnerId(player)
	if not player then return nil end
	if player.getSteamID then
		local sid = player:getSteamID()
		if sid and tostring(sid) ~= "0" then
			return tostring(sid)
		end
	end
	return player:getUsername() or ("local" .. tostring(player:getPlayerNum()))
end

local function isSoftStakeGround(square)
	if not square then return false end
	local groundType = ISShovelGroundCursor.GetDirtGravelSand(square)
	return groundType == "dirt" or groundType == "sand" or groundType == "clay"
end

-- Primary-hand spear first; else first inv/bag spare (not back-attached).
local function getSpearToStake(player)
	local primary = player:getPrimaryHandItem()
	if isSpear(primary) and not primary:isBroken() then
		return primary
	end
	return getAvailableSpear(player)
end

local function squareFromWorldObjects(worldobjects)
	if not worldobjects then return nil end
	for _, obj in ipairs(worldobjects) do
		if obj and obj.getSquare then
			local sq = obj:getSquare()
			if sq then return sq end
		end
	end
	return nil
end

local function onStakedSpear(worldobjects, square, playerNum)
	local player = getSpecificPlayer(playerNum)
	if not player or not square then return end
	if not isSoftStakeGround(square) then return end

	local spear = getSpearToStake(player)
	if not spear then return end

	if not luautils.walkAdj(player, square) then return end

	if luautils.haveToBeTransfered(player, spear) then
		ISTimedActionQueue.add(ISInventoryTransferAction:new(
			player, spear, spear:getContainer(), player:getInventory(), 1))
	end
	if player:isHandItem(spear) then
		ISTimedActionQueue.add(ISUnequipAction:new(player, spear, 1, "place"))
	end
	ISTimedActionQueue.add(ISStakedSpearAction:new(player, spear, square, getLocalOwnerId(player)))
end

local function fillStakedSpearMenu(playerNum, context, worldobjects, test)
	if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end

	local player = getSpecificPlayer(playerNum)
	if not player then return end

	local square = squareFromWorldObjects(worldobjects)
	if not square then return end
	if not isSoftStakeGround(square) then return end
	if not getSpearToStake(player) then return end

	if test then return true end
	context:addOption(getText("UI_Spearbreaker_StakedSpear"), worldobjects, onStakedSpear, square, playerNum)
end

Events.OnFillWorldObjectContextMenu.Add(fillStakedSpearMenu)

-- Square-entry edge: primary empty → instant take from world + two-hand equip.
-- ISGrabItemAction stops on walk, so mid-stride contact cancels it; take directly instead.
local lastStakeSquareKey = {}

local function squareKey(sq)
	if not sq then return nil end
	return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
end

local function clearStakedFlags(item)
	if not item then return end
	local md = item:getModData()
	if not md or not md.SpearbreakerStaked then return end
	md.SpearbreakerStaked = nil
	md.SpearbreakerOwner = nil
end

-- Clear after vanilla Grab / any path that puts a staked spear into inventory.
local function clearStakedFlagsFromInventory(player)
	if not player then return end
	local marked = player:getInventory():getAllEvalRecurse(function(item)
		local md = item:getModData()
		return md and md.SpearbreakerStaked and not item:getWorldItem()
	end)
	if type(marked) == "userdata" then
		for i = 0, marked:size() - 1 do
			clearStakedFlags(marked:get(i))
		end
	elseif type(marked) == "table" then
		for _, item in ipairs(marked) do
			clearStakedFlags(item)
		end
	end
end

-- Vanilla ISGrabItemAction:transferItem SP path (time=0 feel, no stopOnWalk cancel).
local function takeWorldItemToInventory(player, wo)
	local item = wo and wo:getItem()
	if not item then return nil end
	local square = wo:getSquare()
	if not square then return nil end
	-- Same foley as stake-in (reverse not available via scripted sounds).
	player:getEmitter():playSound("DigFurrowWithTrowel")
	addSound(player, player:getX(), player:getY(), player:getZ(), 10, 1)
	square:transmitRemoveItemFromSquare(wo)
	wo:removeFromWorld()
	wo:removeFromSquare()
	wo:setSquare(nil)
	item:setWorldItem(nil)
	item:setJobDelta(0.0)
	clearStakedFlags(item)
	local inv = player:getInventory()
	inv:setDrawDirty(true)
	inv:AddItem(item)
	ISInventoryPage.renderDirty = true
	return item
end

local function findOwnedStakedSpearOnSquare(sq, ownerId)
	local wos = sq and sq:getWorldObjects()
	if not wos then return nil, nil end
	for i = 0, wos:size() - 1 do
		local wo = wos:get(i)
		local item = wo and wo:getItem()
		if item and isSpear(item) and not item:isBroken() then
			local md = item:getModData()
			if md and md.SpearbreakerStaked and tostring(md.SpearbreakerOwner or "") == ownerId then
				return wo, item
			end
		end
	end
	return nil, nil
end

local function pollStakedSpearContact(player)
	if not player or player ~= getPlayer() or player:isDead() then return end

	local sq = player:getCurrentSquare()
	local playerNum = player:getPlayerNum()
	local key = squareKey(sq)
	local prev = lastStakeSquareKey[playerNum]
	if not key then
		lastStakeSquareKey[playerNum] = nil
		return
	end
	-- Not an entry (same tile, or first frame on this character).
	if prev == nil or prev == key then
		lastStakeSquareKey[playerNum] = key
		return
	end

	if player:getPrimaryHandItem() then
		lastStakeSquareKey[playerNum] = key
		return
	end

	local queue = ISTimedActionQueue.queues[player]
	if queue and #queue.queue > 0 then
		return
	end

	local ownerId = tostring(getLocalOwnerId(player) or "")
	local wo, item = findOwnedStakedSpearOnSquare(sq, ownerId)
	lastStakeSquareKey[playerNum] = key
	if not wo or not item then return end

	local taken = takeWorldItemToInventory(player, wo)
	if not taken then return end
	ISTimedActionQueue.add(ISEquipWeaponAction:new(player, taken, 1, true, true))
end

Events.OnPlayerUpdate.Add(pollStakedSpearContact)
Events.OnContainerUpdate.Add(function()
	clearStakedFlagsFromInventory(getPlayer())
end)
