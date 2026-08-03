--[[
    Versus-Airlines :: modules/mod_boss
    -------------------------------------
    Boss farm. Loops trying to find a configured boss; if found,
    moves to it and attacks. The user picks the boss from a
    dropdown in the section tree.

    Loop (one tick per heartbeat, ~0.5s):
        1. Read the boss name from Library.Flags.SelectBoss.
        2. Look up the boss data (Level, CFrame, Drops).
        3. Find a live instance in Workspace.Enemies.
        4. If alive, tween to it and attack (Melee equipped).
        5. If no live instance, tween to the boss's spawn CFrame
           and wait for the respawn.
        6. Detect "boss died this tick" and emit 'boss_defeated'
           (with the drop list for milestone event context).
]]

return {
    name = "AutoBoss",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not (kernel.boss and kernel.movement and kernel.combat) then return end

        local boss    = kernel.boss
        local movement = kernel.movement
        local combat  = kernel.combat

        local TICK_INTERVAL_SEC = 0.5
        local lastTick     = 0
        local lastWasAlive = false
        local running = true

        -- Read the boss name from the Versus library's Flags each
        -- tick so the user can change it without re-starting.
        local function getTargetBossName()
            local flags = kernel._library and kernel._library.Flags
            return flags and flags.SelectBoss or "Saber Expert"
        end

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            local name = getTargetBossName()
            local entry = boss:data(name)
            local target = boss:find(name)
            local alive = target and combat:isAlive(target) or false

            -- 1. Detect a kill. We saw the boss alive last tick and
            --    not this tick -> it died between ticks.
            if lastWasAlive and not alive and entry then
                kernel.events:emit("boss_defeated", {
                    boss  = name,
                    level = entry.Level,
                    drops = entry.Drops,
                })
            end
            lastWasAlive = alive

            if alive then
                local root = kernel.services:get("Players").LocalPlayer.Character
                          and kernel.services:get("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local pos = boss._mob:position(target)
                    local dist = (root.Position - pos).Magnitude
                    if dist > 50 then movement:tween(target) end
                    combat:equip("Melee")
                    combat:attack(target)
                end
            elseif entry and entry.CFrame then
                -- No live boss -- wait at the spawn CFrame.
                movement:tween(entry.CFrame)
            end
        end, "mod:AutoBoss")

        kernel._bossRunning = true
        kernel._bossStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoBoss")
            kernel._bossRunning = false
            kernel.events:emit("stopped", { module = "AutoBoss" })
        end
        kernel.events:emit("started", { module = "AutoBoss" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._bossStop then kernel._bossStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._bossRunning == true, msg = nil }
    end,
}
