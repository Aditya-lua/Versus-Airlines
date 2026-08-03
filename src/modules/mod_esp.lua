--[[
    Versus-Airlines :: modules/mod_esp
    ------------------------------------
    ESP loop. Periodically scans the workspace for Players, Mobs,
    and Fruit drops, and renders labels above them. The user picks
    which kinds to show via three toggles (Show Players, Show Mobs,
    Show Fruits). The maximum render distance is a slider.
]]

return {
    name = "AutoESP",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not kernel.esp then return end

        local esp = kernel.esp
        local TICK_INTERVAL_SEC = 0.5
        local lastTick = 0
        local running  = true

        local function flag(name)
            local flags = kernel._library and kernel._library.Flags
            return flags and flags[name]
        end

        local function num(name, default)
            local flags = kernel._library and kernel._library.Flags
            local v = flags and tonumber(flags[name])
            return v or default
        end

        -- Build the visible list each tick. Each entry is
        -- { kind, label, position }.
        local function collectVisible()
            local out = {}
            esp:setMaxDistance(num("ESPDistance", 1000))
            local md = esp:maxDistance()

            local root = kernel.services:get("Players").LocalPlayer.Character
                      and kernel.services:get("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local origin = root and root.Position or nil

            -- Players
            if flag("ESPPlayers") then
                local Players = kernel.services:get("Players")
                for _, p in ipairs(Players:GetPlayers() or {}) do
                    if p and p ~= Players.LocalPlayer and p.Character then
                        local h = p.Character:FindFirstChild("HumanoidRootPart")
                        if h and h.Position then
                            if not origin or (origin - h.Position).Magnitude <= md then
                                out[#out + 1] = { kind = "player", label = p.Name or "?", position = h.Position }
                            end
                        end
                    end
                end
            end

            -- Mobs (live only)
            if flag("ESPMobs") and kernel.mob then
                local ws = kernel.services:get("Workspace")
                if ws and ws.GetChildren then
                    local enemies = ws:FindFirstChild("Enemies")
                    if enemies and enemies.GetChildren then
                        for _, v in ipairs(enemies:GetChildren()) do
                            if type(v) == "table" and v:FindFirstChild("Humanoid") and kernel.mob:isAlive(v) then
                                local h = v:FindFirstChild("HumanoidRootPart")
                                if h and h.Position then
                                    if not origin or (origin - h.Position).Magnitude <= md then
                                        out[#out + 1] = { kind = "mob", label = v.Name or "?", position = h.Position }
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Fruits (Tools with "fruit" in the name)
            if flag("ESPFruits") then
                local ws = kernel.services:get("Workspace")
                if ws and ws.GetChildren then
                    for _, v in ipairs(ws:GetChildren()) do
                        if type(v) == "table" and v.IsA and v:IsA("Tool") and v.Name and v.Name:lower():find("fruit", 1, true) then
                            local pos
                            if v:IsA("BasePart") and v.Position then
                                pos = v.Position
                            else
                                local b = v.FindFirstChildWhichIsA and v:FindFirstChildWhichIsA("BasePart")
                                if b and b.Position then pos = b.Position end
                            end
                            if pos and (not origin or (origin - pos).Magnitude <= md) then
                                out[#out + 1] = { kind = "fruit", label = v.Name or "?", position = pos }
                            end
                        end
                    end
                end
            end

            return out
        end

        kernel.conn:bindHeartbeat(function()
            if not running then return end
            local now = os.clock()
            if (now - lastTick) < TICK_INTERVAL_SEC then return end
            lastTick = now

            local visible = collectVisible()
            esp:render(visible)
        end, "mod:AutoESP")

        kernel._espRunning = true
        kernel._espStop = function()
            running = false
            kernel.conn:cleanup("mod:AutoESP")
            esp:clear()
            kernel._espRunning = false
            kernel.events:emit("stopped", { module = "AutoESP" })
        end
        kernel.events:emit("started", { module = "AutoESP" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._espStop then kernel._espStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._espRunning == true, msg = nil }
    end,
}
