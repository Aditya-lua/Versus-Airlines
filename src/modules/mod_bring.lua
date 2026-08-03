--[[
    Versus-Airlines :: modules/mod_bring
    --------------------------------------
    Autofarm bring. Pulls mobs to the player instead of running to them.
    Uses the same quest resolution as mod_autofarm.
]]

return {
    name = "BringMob",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not (kernel.bring and kernel.quest) then return end

        local bring = kernel.bring
        local quest = kernel.quest

        local TICK_INTERVAL_SEC = 0.5
        local lastTick = 0
        local running = true

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            local entry = quest:current()
            if not entry then return end
            bring:tick(entry.NameMon, 150)
        end, "mod:BringMob")

        kernel._bringRunning = true
        kernel._bringStop = function()
            running = false
            kernel.conn:cleanup("mod:BringMob")
            kernel._bringRunning = false
            kernel.events:emit("stopped", { module = "BringMob" })
        end
        kernel.events:emit("started", { module = "BringMob" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._bringStop then kernel._bringStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._bringRunning == true, msg = nil }
    end,
}
