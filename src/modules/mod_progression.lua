--[[
    Versus-Airlines :: modules/mod_progression
    --------------------------------------------
    Drives three small loops in one module:
        1. AutoStat    - allocate stat points to the chosen priority.
        2. AutoEnhance - re-roll the equipped sword's enhancement tier.
        3. AutoMastery - keep a chosen weapon category equipped so
                         mastery exp accumulates while the autofarm
                         (or any other module) is attacking.

    Each loop ticks on its own cadence:
        AutoStat:    1.0s   - re-checks available points.
        AutoEnhance: 2.0s   - rolls at most one enhancement at a time.
        AutoMastery: 1.5s   - re-equips if Backpack changed.

    All three are gated on their own Library.Flags:
        AutoStat, AutoEnhance, AutoMastery, StatPriority, MasteryWeapon.
]]

return {
    name = "AutoProgression",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not (kernel.stat and kernel.enhance and kernel.mastery) then return end

        local stat     = kernel.stat
        local enhance  = kernel.enhance
        local mastery  = kernel.mastery

        local STAT_TICK    = 1.0
        local ENHANCE_TICK = 2.0
        local MASTERY_TICK = 1.5

        local lastStat    = 0
        local lastEnhance = 0
        local lastMastery = 0
        local running = true

        local function flag(name)
            local flags = kernel._library and kernel._library.Flags
            return flags and flags[name]
        end

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()

            -- 1. AutoStat
            if flag("AutoStat") and (now - lastStat) >= STAT_TICK then
                lastStat = now
                local prio = flag("StatPriority") or "Melee"
                local n = stat:allocateByPriority(prio)
                if n and n > 0 then
                    kernel.events:emit("milestone", { text = "allocated " .. n .. " stat -> " .. prio })
                end
            end

            -- 2. AutoEnhance
            if flag("AutoEnhance") and (now - lastEnhance) >= ENHANCE_TICK then
                lastEnhance = now
                local ok = enhance:roll()
                if ok then
                    local t = enhance:tier()
                    kernel.events:emit("milestone", { text = "enhance roll (tier=" .. tostring(t) .. ")" })
                end
            end

            -- 3. AutoMastery
            if flag("AutoMastery") and (now - lastMastery) >= MASTERY_TICK then
                lastMastery = now
                local w = flag("MasteryWeapon") or "Melee"
                mastery:equip(w)
            end
        end, "mod:AutoProgression")

        kernel._progRunning = true
        kernel._progStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoProgression")
            kernel._progRunning = false
            kernel.events:emit("stopped", { module = "AutoProgression" })
        end
        kernel.events:emit("started", { module = "AutoProgression" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._progStop then kernel._progStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._progRunning == true, msg = nil }
    end,
}
