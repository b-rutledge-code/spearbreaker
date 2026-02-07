require "TimedActions/ISTransferAction"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISDropWorldItemAction"
require "TimedActions/ISDetachItemHotbar"
require "TimedActions/ISAttachItemHotbarNoStopOnAim"
require "TimedActions/ISEquipWeaponAction"
require "Items/OnBreak"

-- Test: set SpearbreakerTestEmptyHands=true in debug console to attach with empty hands (unequip first).
-- Compare animation: does it play when hands empty vs occupied?
SpearbreakerTestEmptyHands = SpearbreakerTestEmptyHands or false

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
            print("[Spearbreaker] getAvailableSpear: spear in bag, queuing transfer")
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
                print("[Spearbreaker] spear break: hotbar=" .. tostring(hotbar) .. " back_slot_spear=" .. tostring(back_slot_spear))
                if hotbar and back_slot_spear then
                    pendingEquipFromBack[playerNum] = getTimestamp() or 0
                    print("[Spearbreaker] spear break: scheduling equip (t=" .. tostring(pendingEquipFromBack[playerNum]) .. ")")
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
    if elapsed < 1.5 then return end
    pendingEquipFromBack[playerNum] = nil
    print("[Spearbreaker] equip: elapsed=" .. string.format("%.2f", elapsed) .. "s")
    local hotbar = getPlayerHotbar(playerNum)
    local spear = getBackSlotSpear(player)
    print("[Spearbreaker] pollEquipWhenReady: actionsEmpty, equipping hotbar=" .. tostring(hotbar) .. " spear=" .. tostring(spear))
    if hotbar and spear then
        hotbar:equipItem(spear)
    end
end

local RELOAD_COOLDOWN_MS = 300
local lastReloadKeyMs = 0

local function attachSpearToBackFromInventory()
    local player = getPlayer()
    if not player then print("[Spearbreaker] attach: no player"); return false end

    if player:isRunning() then print("[Spearbreaker] attach: bail player running"); return false end

    local queue = ISTimedActionQueue.queues[player]
    if queue and #queue.queue > 0 then print("[Spearbreaker] attach: bail queue not empty"); return false end

    local equipped = player:getPrimaryHandItem()
    if not isSpear(equipped) and not isBrokenSpearPiece(equipped) then print("[Spearbreaker] attach: bail no spear/broken in hand"); return false end

    local back_slot_spear = getBackSlotSpear(player)
    if back_slot_spear and not back_slot_spear:isEquipped() then print("[Spearbreaker] attach: bail back slot full (spear not equipped)"); return false end

    local new_spear = getAvailableSpear(player)
    if not new_spear then print("[Spearbreaker] attach: bail no available spear"); return false end

    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if not hotbar then print("[Spearbreaker] attach: bail no hotbar"); return false end
    if not hotbar.availableSlot or not hotbar.availableSlot[1] then print("[Spearbreaker] attach: bail no back slot"); return false end

    local slot = hotbar.availableSlot[1]
    local slotDef = slot.def
    -- Use vanilla slot resolution: attachments[type] then Back replacement if any
    local attachSlot = (slotDef.attachments and new_spear:getAttachmentType() and slotDef.attachments[new_spear:getAttachmentType()])
        or 'Shovel Back'
    if slotDef.name == "Back" and hotbar.replacements and hotbar.replacements[new_spear:getAttachmentType()] then
        attachSlot = hotbar.replacements[new_spear:getAttachmentType()]
    end
    if attachSlot == "null" then return false end
    -- Test: empty hands first to see if animation plays
    if SpearbreakerTestEmptyHands then
        print("[Spearbreaker] attach: TEST MODE (empty hands first) - queuing unequip+attach+reequip")
        local toReequip = isSpear(equipped) and equipped or nil
        ISTimedActionQueue.add(ISUnequipAction:new(player, equipped, 1))
        hotbar:setAttachAnim(new_spear, slotDef)
        ISInventoryPaneContextMenu.transferIfNeeded(player, new_spear)
        if hotbar.attachedItems[1] then
            ISTimedActionQueue.add(ISDetachItemHotbar:new(player, hotbar.attachedItems[1]))
        end
        ISTimedActionQueue.add(ISAttachItemHotbarNoStopOnAim:new(player, new_spear, attachSlot, 1, slotDef))
        if toReequip then
            ISTimedActionQueue.add(ISEquipWeaponAction:new(player, toReequip, 2, true, true))
        end
        return true
    end
    -- Normal: attach with hands occupied
    print("[Spearbreaker] attach: normal mode (hands occupied) - queuing attach")
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
    if elapsed < 400 then return end  -- 400ms settle
    pendingAttachFromInventory[playerNum] = nil  -- clear first so we don't retry on failure
    print("[Spearbreaker] pollAttach: elapsed=" .. elapsed .. "ms calling attach")
    attachSpearToBackFromInventory()
end

Events.OnPlayerUpdate.Add(pollEquipWhenReady)
Events.OnPlayerUpdate.Add(pollAttachWhenReady)

-- B42: spear breaks → LongStick_Broken in hand. Player auto-swings it and interrupts timed actions.
-- Wait for the broken-piece swing to finish (next OnPlayerAttackFinished) before queuing.
local function doSwap(player, in_hand, back_slot_spear, hotbar)
    print("[Spearbreaker] doSwap: in_hand=" .. tostring(in_hand) .. " back_slot_spear=" .. tostring(back_slot_spear))
    if in_hand then
        local sq = player:getCurrentSquare()
        if sq then
            if player:isHandItem(in_hand) then
                ISTimedActionQueue.add(ISUnequipAction:new(player, in_hand, 1))
            end
            local dropX, dropY, dropZ = ISTransferAction.GetDropItemOffset(player, sq, in_hand)
            ISTimedActionQueue.add(ISDropWorldItemAction:new(player, in_hand, sq, dropX, dropY, dropZ, 0, false))
            print("[Spearbreaker] doSwap: queued drop")
        end
    end
    if back_slot_spear and hotbar then
        print("[Spearbreaker] doSwap: equipping from back")
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
    print("[Spearbreaker] swapSpears: scheduling doSwap on next OnPlayerAttackFinished in_hand=" .. tostring(in_hand) .. " back=" .. tostring(back_slot_spear))

    local handler
    handler = function(p, _)
        if p == player then
            Events.OnPlayerAttackFinished.Remove(handler)
            print("[Spearbreaker] swapSpears: firing doSwap")
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
    if player:isDead() then print("[Spearbreaker] reload: bail dead"); return end
    if UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then print("[Spearbreaker] reload: bail paused"); return end

    local now = getTimestampMs()
    if now - lastReloadKeyMs < RELOAD_COOLDOWN_MS then print("[Spearbreaker] reload: bail cooldown"); return end
    lastReloadKeyMs = now

    pendingAttachFromInventory[player:getPlayerNum()] = getTimestampMs() or 0
    print("[Spearbreaker] reload: scheduled attach")
end

Events.OnKeyStartPressed.Add(reloadSpearFromInventory)
Events.OnKeyPressed.Add(reloadSpearFromInventory)
