require "TimedActions/ISTransferAction"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISDropWorldItemAction"
require "TimedActions/ISDetachItemHotbar"
require "TimedActions/ISAttachItemHotbarNoStopOnAim"
require "TimedActions/ISEquipWeaponAction"
require "Items/OnBreak"

local pendingEquipFromBack = {}
local pendingAttachFromInventory = {}

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

    for _, item in ipairs(main) do
        if isSpear(item) and item:getAttachedSlot() ~= 1 and not item:isEquipped() and not item:isBroken() then
            return item
        end
    end

    for _, item in ipairs(other) do
        if not item:isBroken() then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), player_inv, 1))
            return nil
        end
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
                local hotbar = getPlayerHotbar(playerNum)
                local back_slot_spear = getBackSlotSpear(player)
                if hotbar and back_slot_spear then
                    pendingEquipFromBack[playerNum] = getTimestamp() or 0
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

local function pollEquipWhenReady(player)
    local playerNum = player:getPlayerNum()
    local when = pendingEquipFromBack[playerNum]
    if not when then return end
    local elapsed = (getTimestamp() or 0) - when
    if elapsed < 1.2 then return end
    pendingEquipFromBack[playerNum] = nil
    local hotbar = getPlayerHotbar(playerNum)
    local spear = getBackSlotSpear(player)
    if hotbar and spear then
        hotbar:equipItem(spear)
    end
end

local RELOAD_COOLDOWN_MS = 300
local lastReloadKeyMs = 0

local function attachSpearToBackFromInventory()
    local player = getPlayer()
    if not player then return false end
    if player:isRunning() then return false end

    local queue = ISTimedActionQueue.queues[player]
    if queue and #queue.queue > 0 then return false end

    local equipped = player:getPrimaryHandItem()
    if not isSpear(equipped) and not isBrokenSpearPiece(equipped) then return false end

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
    return true
end

-- Defer attach so combat/aiming doesn't interrupt the timed action.
local function pollAttachWhenReady(player)
    local playerNum = player:getPlayerNum()
    local when = pendingAttachFromInventory[playerNum]
    if not when then return end
    local elapsed = (getTimestampMs() or 0) - when
    if elapsed < 200 then return end  -- 200ms settle
    pendingAttachFromInventory[playerNum] = nil  -- clear first so we don't retry on failure
    attachSpearToBackFromInventory()
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

    pendingAttachFromInventory[player:getPlayerNum()] = getTimestampMs() or 0
end

Events.OnKeyStartPressed.Add(reloadSpearFromInventory)
Events.OnKeyPressed.Add(reloadSpearFromInventory)
