-- Utility function to check if an item is a spear
local function isSpear(item)
    return item and item:getCategory() == 'Weapon' and WeaponType.getWeaponType(item) == WeaponType.spear
end

-- Find all spears in the player's inventory
local function findAllSpears(player)
    -- Fetch the player's inventory
    local inventory = player:getInventory()

    -- Retrieve all items that are spears using a recursive evaluation
    local spears = inventory:getAllEvalRecurse(function(item)
        return isSpear(item)  -- Check if the item is a spear
    end)

    -- getAllEvalRecurse may return Java ArrayList (userdata) or Lua table
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
    local spears = findAllSpears(player)  -- Retrieve all spears
    local non_main_inventory = {}  -- Initialize the list for spears not in main inventory
    local main_inventory = {}  -- Initialize the list for spears in main inventory

    if spears and #spears then
        local player_inventory = player:getInventory()

        for _, spear in ipairs(spears) do
            local container_spear_is_in = spear:getContainer()
            if container_spear_is_in == player_inventory then
                table.insert(main_inventory, spear)  -- Add the item to the in_inventory list
            else
                table.insert(non_main_inventory, spear)  -- Add the item to the non_inventory list
            end
        end

        -- Check in_inventory items first
        for _, item in ipairs(main_inventory) do
            local attached_slot = item:getAttachedSlot()  -- Get attached slot for the item
            if isSpear(item) and attached_slot ~= 1 and not item:isEquipped() and not item:isBroken() then
                return item  -- Return the first in-inventory item that meets all conditions
            end
        end

        -- If no suitable spear is found in the main inventory, check non_inventory
        for _, item in ipairs(non_main_inventory) do
            if not item:isBroken() then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), player:getInventory(), 1))
                return nil
            end
        end
    end

    return nil -- Return nil if no appropriate spear is found
end

-- Function to find the spear attached to the back slot (slot 1) from all unbroken spears
local function getBackSlotSpear(player)
    local spears = findAllSpears(player)  -- Retrieve all spears
    if spears and  #spears then
        for _, item in ipairs(spears) do
            if item:getAttachedSlot() == 1 then  -- Check if the item is attached to slot 1
                return item  -- Return the item if it's in the back slot
            end
        end
    end
    return nil  -- Return nil if no appropriate spear is found
end

-- Function to find the first broken spear in the player's inventory
local function getBrokenSpear(player)
    -- Retrieve all spears in the inventory
    local spears = findAllSpears(player)
    if spears and #spears then
        -- Iterate through the list of spears to find a broken one using ipairs
        for _, spear in ipairs(spears) do
            if spear:isBroken() then  -- Check if the spear is broken
                return spear  -- Return the broken spear if found
            end
        end
    end
    return nil  -- Return nil if no broken spear is found
end

-- Function to swap a broken spear with a spear from the back slot
local function swapSpears(player, weapon)
    if not weapon then
        local broken_spear = getBrokenSpear(player)
        if broken_spear then
            ISTimedActionQueue.add(ISDropItemAction:new(player, broken_spear, 0))
            local back_slot_spear = getBackSlotSpear(player)
            if back_slot_spear then
                ISTimedActionQueue.add(ISEquipWeaponAction:new(player, back_slot_spear, 2, true, true))
            end
        end
    end
end
Events.OnPlayerAttackFinished.Add(swapSpears)

-- Reload spear from inventory to back slot
local function reloadSpearFromInventory(keynum)
    if keynum == 19 then
        local player = getPlayer()
        local equipped_spear = player:getPrimaryHandItem()
        if isSpear(equipped_spear) then
            local back_slot_spear = getBackSlotSpear(player)
            if not back_slot_spear or back_slot_spear:isEquipped() then
                local new_spear = getAvailableSpear(player)
                if new_spear then
                    local hotbar = getPlayerHotbar(player:getPlayerNum())
                    local slot = hotbar.availableSlot[1];
                    hotbar:attachItem(new_spear, 'Shovel Back', 1, slot.def, true)
                end
            end
        end
    end
end
Events.OnKeyPressed.Add(reloadSpearFromInventory)
