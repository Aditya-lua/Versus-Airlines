--[[
    Versus-Airlines :: modules/mod_v4
    ----------------------------------
    V4 (race) trial auto-grinder. The "V4" trial is unlocked after
    completing three sub-trials for a given race. This module tweens
    the player to the trial-giver NPC and emits status events. The
    sub-trials themselves are too varied to automate safely; this
    driver just parks the player at the NPC and reports state.
]]

return {
    name = "AutoV4",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not (kernel.v4 and kernel.movement) then return end

        local v4       = kernel.v4
        local movement = kernel.movement

        local TICK_INTERVAL_SEC = 30.0   -- only re-tween periodically
        local lastTick = 0
        local running  = true

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            -- Use the first known race (Human is canonical) as a
            -- safe default. The user can change later by exposing
            -- a dropdown in a follow-up; for now this just parks
            -- at the trial NPC.
            local races = v4:list()
            if #races == 0 then return end
            local entry = v4:data(races[1])
            if entry and entry.CFrame then
                movement:tween(entry.CFrame)
                kernel.events:emit("milestone", { text = "parked at V4 NPC (" .. races[1] .. ")" })
            end
        end, "mod:AutoV4")

        kernel._v4Running = true
        kernel._v4Stop = function()
            running = false
            kernel.conn:cleanup("mod:AutoV4")
            kernel._v4Running = false
            kernel.events:emit("stopped", { module = "AutoV4" })
        end
        kernel.events:emit("started", { module = "AutoV4" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._v4Stop then kernel._v4Stop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._v4Running == true, msg = nil }
    end,
}
