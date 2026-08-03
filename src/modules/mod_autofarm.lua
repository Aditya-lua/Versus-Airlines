--[[
    Versus-Airlines :: modules/mod_autofarm
    ----------------------------------------
    The autofarm level module. The first module that fires a real
    Remote and moves the player (slice 5).

    Loop (one tick per heartbeat, ~0.3s):
        1. Resolve the current quest from the player's level + sea.
        2. If the quest is not active, accept it (fire the quest
           remote with a throttled call routed through stealth).
        3. If the quest IS active, find the closest live mob matching
           the quest's NameMon. Move to it (tween) and attack.
        4. If no mob is in range, move to the quest NPC and wait.
        5. If stuck for > 5s, unstick (random offset, retry).
        6. Emit 'level_up' events on level threshold crosses.
]]

return {
    name = "AutoFarm",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if not (kernel.movement and kernel.quest and kernel.mob and kernel.combat) then
            -- Kernel didn't pre-build the game modules (test
            -- environment, or kernel booted without the game tree).
            return
        end

        local movement = kernel.movement
        local quest    = kernel.quest
        local mob      = kernel.mob
        local combat   = kernel.combat

        -- Tick state.
        local lastTick     = 0
        local lastStuckAt  = 0
        local TICK_INTERVAL_SEC    = 0.3
        local STUCK_AT_SEC         = 5.0
        local LEVEL_UP_EVERY       = 25
        local lastEmittedLevel     = 0
        local running = true

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            local entry = quest:current()
            if not entry then return end

            -- 1. Level-up broadcast.
            local level = 0
            pcall(function()
                local Players = kernel.services:get("Players")
                level = Players.LocalPlayer.Data.Level.Value
            end)
            if lastEmittedLevel == 0 then lastEmittedLevel = level end
            if level >= lastEmittedLevel + LEVEL_UP_EVERY then
                kernel.events:emit("level_up", { level = level })
                lastEmittedLevel = level
            end

            -- 2. Accept the quest if it isn't active.
            if not quest:isQuestActive() then
                pcall(function()
                    local ReplicatedStorage = kernel.services:get("ReplicatedStorage")
                    if not ReplicatedStorage then return end
                    local questRemote = ReplicatedStorage:FindFirstChild(entry.NameQuest .. tostring(entry.LevelQuest))
                    if not questRemote then return end
                    if questRemote:IsA("RemoteEvent") then
                        kernel.stealth:fire(questRemote, {})
                    elseif questRemote:IsA("Part") then
                        local prompt = questRemote:FindFirstChildWhichIsA("ProximityPrompt")
                        if prompt then fireproximityprompt(prompt) end
                    end
                end)
            end

            -- 3. Find a mob, move to it, attack.
            local target = mob:find(entry.NameMon)
            if target and combat:isAlive(target) then
                local root = kernel.services:get("Players").LocalPlayer.Character
                          and kernel.services:get("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - mob:position(target)).Magnitude
                    if dist > 50 then movement:tween(target) end
                    combat:equip("Melee")
                    combat:attack(target)
                end
            elseif entry.CFrameQuest then
                movement:tween(entry.CFrameQuest)
            end

            -- 4. Anti-stuck.
            if movement:isStuck() then
                movement:unstick()
            end
        end, "mod:AutoFarm")

        kernel._autofarmRunning = true
        kernel._autofarmStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoFarm")
            kernel._autofarmRunning = false
            kernel.events:emit("stopped", { module = "AutoFarm" })
        end
        kernel.events:emit("started", { module = "AutoFarm" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._autofarmStop then kernel._autofarmStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._autofarmRunning == true, msg = nil }
    end,
}
