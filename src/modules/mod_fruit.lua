--[[
    Versus-Airlines :: modules/mod_fruit
    -------------------------------------
    Fruit Sniper + Auto Buy Fruit.
    Two modes, both gated on the same kernel.fruit object:
        1. FruitSniper: every tick, scan Workspace for fruit
           drops. If one is visible, tween to it and pick it up
           (touch the Tool via Humanoid:MoveTo or root.CFrame).
        2. AutoBuyFruit: every tick, if a fruit name is configured
           and the player is high enough level, fire the
           CommF_(PurchaseRandomFruit) remote through stealth.

    The user picks a target fruit in the "Fruit to Buy" dropdown
    in the section tree (Library.Flags.FruitToBuy).
]]

return {
    name = "AutoFruit",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not (kernel.fruit and kernel.movement) then return end

        local fruit   = kernel.fruit
        local movement = kernel.movement

        local TICK_INTERVAL_SEC = 1.0
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

            -- 1. Fruit Sniper.
            if flag("FruitSniper") then
                local drop = fruit:sniper()
                if drop and drop.position then
                    movement:tween(drop.position)
                    -- The Tool pickup happens on touch; movement
                    -- already brings us in range.
                end
            end

            -- 2. Auto Buy Fruit.
            if flag("AutoBuyFruit") then
                local want = flag("FruitToBuy")
                if want and fruit:data(want) and fruit:isOnMap(want) then
                    local ok, err = fruit:buy(want)
                    if ok then
                        kernel.events:emit("milestone", {
                            text = "bought random fruit (wanted " .. want .. ")",
                        })
                    end
                end
            end
        end, "mod:AutoFruit")

        kernel._fruitRunning = true
        kernel._fruitStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoFruit")
            kernel._fruitRunning = false
            kernel.events:emit("stopped", { module = "AutoFruit" })
        end
        kernel.events:emit("started", { module = "AutoFruit" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._fruitStop then kernel._fruitStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._fruitRunning == true, msg = nil }
    end,
}
