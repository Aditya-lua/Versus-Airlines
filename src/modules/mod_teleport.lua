--[[
    Versus-Airlines :: modules/mod_teleport
    ------------------------------------------
    Teleport-To-Island on demand. The "Teleport To" dropdown reads
    Library.Flags.dd_teleport_to (the auto-flag from the
    `dropdown(...)` helper). The teleport runs once on toggle-on
    and the module stops itself. The user can re-enable to
    teleport again.
]]

return {
    name = "AutoTeleport",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not kernel.teleport then return end

        local teleport = kernel.teleport

        local function flag(name)
            local flags = kernel._library and kernel._library.Flags
            return flags and flags[name]
        end

        -- The dropdown helper sets flagName = "dd_teleport_to".
        local target = flag("dd_teleport_to") or flag("TeleportTo")
        if not target then
            target = teleport:islands()[1] or "Jungle"
        end

        local ok = teleport:island(target)
        if ok then
            kernel.events:emit("milestone", { text = "teleported to " .. target })
        else
            kernel.events:emit("milestone", { text = "teleport failed: " .. target, level = "warn" })
        end

        -- Self-stop: teleport is a one-shot action.
        kernel._tpRunning = true
        kernel._tpStop = function()
            kernel._tpRunning = false
            kernel.events:emit("stopped", { module = "AutoTeleport" })
        end
        kernel.events:emit("started", { module = "AutoTeleport" })
        -- Defer the stop by one frame so the UI shows the toggle
        -- on for a brief moment.
        if task and task.defer then
            pcall(function() task.defer(function() kernel.registry:stop("AutoTeleport") end) end)
        end
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._tpStop then kernel._tpStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._tpRunning == true, msg = nil }
    end,
}
