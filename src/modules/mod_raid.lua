--[[
    Versus-Airlines :: modules/mod_raid
    ------------------------------------
    Auto-Raid. Periodically fires the raid-join remote through
    stealth. The user picks the raid type from the dropdown
    (Library.Flags.RaidType).
]]

return {
    name = "AutoRaid",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not kernel.raid then return end

        local raid = kernel.raid
        local TICK_INTERVAL_SEC = 5.0
        local lastTick = 0
        local running  = true

        local function flag(name)
            local flags = kernel._library and kernel._library.Flags
            return flags and flags[name]
        end

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            local want = flag("RaidType")
            if not want or not raid:data(want) then return end
            local ok, _err = raid:start(want)
            if ok then
                kernel.events:emit("milestone", { text = "raid join: " .. want })
            end
        end, "mod:AutoRaid")

        kernel._raidRunning = true
        kernel._raidStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoRaid")
            kernel._raidRunning = false
            kernel.events:emit("stopped", { module = "AutoRaid" })
        end
        kernel.events:emit("started", { module = "AutoRaid" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._raidStop then kernel._raidStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._raidRunning == true, msg = nil }
    end,
}
