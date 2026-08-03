--[[
    Versus-Airlines :: modules/mod_party
    --------------------------------------
    Party auto-pilot. Subscribes to "button" events:
        "Add Member"   - reads Library.Flags.PartyAdd
        "Remove Member" - reads Library.Flags.PartyRemove
        "Teleport to Party" - teleport to each member
    The party is a simple in-memory list; Blox Fruits doesn't
    expose a private-party API on the client.
]]

return {
    name = "AutoParty",

    start = function()
        local kernel = _G.VersusKernel
        if not kernel or not kernel.party then return end

        local party = kernel.party
        local running = true

        local function flag(name)
            local flags = kernel._library and kernel._library.Flags
            return flags and flags[name]
        end

        -- Subscribe to button events. The section tree emits
        -- 'button' with { name = <button name> }.
        local handler = function(_event, payload)
            if not running then return end
            if not payload or not payload.name then return end
            if payload.name == "Add Member" then
                local n = flag("PartyAdd")
                if n and n ~= "" then
                    party:add(n)
                    kernel.events:emit("milestone", { text = "party +" .. n })
                end
            elseif payload.name == "Remove Member" then
                local n = flag("PartyRemove")
                if n and n ~= "" then
                    party:remove(n)
                    kernel.events:emit("milestone", { text = "party -" .. n })
                end
            elseif payload.name == "Teleport to Party" then
                local n = party:teleportAll()
                kernel.events:emit("milestone", { text = "teleported to " .. n .. " party members" })
            end
        end
        kernel.events:on("button", handler)

        kernel._partyRunning = true
        kernel._partyStop = function()
            running = false
            kernel._partyRunning = false
            kernel.events:emit("stopped", { module = "AutoParty" })
        end
        kernel.events:emit("started", { module = "AutoParty" })
    end,

    stop = function()
        local kernel = _G.VersusKernel
        if not kernel then return end
        if kernel._partyStop then kernel._partyStop() end
    end,

    health = function()
        local kernel = _G.VersusKernel
        if not kernel then return { ok = false, msg = "no kernel" } end
        return { ok = kernel._partyRunning == true, msg = nil }
    end,
}
