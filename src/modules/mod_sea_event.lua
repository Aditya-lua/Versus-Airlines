--[[
    Versus-Airlines :: modules/mod_sea_event
    ------------------------------------------
    Sea event auto-farm. Polls every 2s; if any sea event is active,
    tweens the player to it and attacks (using the same combat
    primitives as the autofarm).
]]

return {
    name = "AutoSeaEvent",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not (kernel.seaEvent and kernel.movement and kernel.combat) then return end

        local seaEvent = kernel.seaEvent
        local movement  = kernel.movement
        local combat   = kernel.combat

        local TICK_INTERVAL_SEC = 2.0
        local lastTick = 0
        local running  = true

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            local hit = seaEvent:findAny()
            if hit and hit.model and combat:isAlive(hit.model) then
                local root = kernel.services:get("Players").LocalPlayer.Character
                          and kernel.services:get("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local pos = seaEvent._mob:position(hit.model)
                    local dist = (root.Position - pos).Magnitude
                    if dist > 50 then movement:tween(hit.model) end
                    combat:equip("Melee")
                    combat:attack(hit.model)
                end
            end
        end, "mod:AutoSeaEvent")

        kernel._seaEventRunning = true
        kernel._seaEventStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoSeaEvent")
            kernel._seaEventRunning = false
            kernel.events:emit("stopped", { module = "AutoSeaEvent" })
        end
        kernel.events:emit("started", { module = "AutoSeaEvent" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._seaEventStop then kernel._seaEventStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._seaEventRunning == true, msg = nil }
    end,
}
