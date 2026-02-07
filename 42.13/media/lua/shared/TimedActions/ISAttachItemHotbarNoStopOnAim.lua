require "TimedActions/ISAttachItemHotbar"

ISAttachItemHotbarNoStopOnAim = ISAttachItemHotbar:derive("ISAttachItemHotbarNoStopOnAim")

function ISAttachItemHotbarNoStopOnAim:new(character, item, slot, slotIndex, slotDef)
    local o = ISAttachItemHotbar.new(self, character, item, slot, slotIndex, slotDef)
    o.stopOnAim = false
    -- Force animation path: ignore isTimedActionInstant() so reach-back anim plays
    if o.maxTime <= 1 then
        o.maxTime = 30
        o.animSpeed = o.maxTime / o:adjustMaxTime(o.maxTime)
        o.maxTime = -1
    end
    return o
end

function ISAttachItemHotbarNoStopOnAim:start()
    print("[Spearbreaker] ISAttachItemHotbarNoStopOnAim:start - animation should begin")
    ISAttachItemHotbar.start(self)
end

function ISAttachItemHotbarNoStopOnAim:perform()
    print("[Spearbreaker] ISAttachItemHotbarNoStopOnAim:perform - attach complete")
    ISAttachItemHotbar.perform(self)
end
