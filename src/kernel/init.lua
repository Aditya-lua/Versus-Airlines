--[[
    Versus-Airlines :: kernel/init
    --------------------------------
    The kernel entry point. Wires Compat + Connection + Registry +
    Stealth + Watchdog + Services + BloxFruits + Data + Events into a
    single graph and publishes it to _G.VersusKernel (D16).

    The events system (D30) replaces the old logger. Modules call
    kernel.events:emit("name", payload) — no info/warn/error surface,
    no log spam, no display messages on every emit.

    The Watchdog is NOT started by Kernel.boot — the caller (loader.lua)
    calls kernel.watchdog:start() after the rest of the boot.

    Public API:
        Kernel.boot(Library) -> {
            compat   = <Compat.detect() result>,
            events   = <Events>,
            conn     = <Connection>,
            registry = <Registry>,
            stealth  = <Stealth>,
            services = <Services>,
            game     = <BloxFruits>,
            data     = <Data>,
            version  = "<semver>",
        }
    -- Plus, after watchdog:start():
    --   watchdog = <Watchdog>
]]

local Compat     = require(script.Parent.compat)
local Connection = require(script.Parent.connection)
local Registry   = require(script.Parent.registry)
local Stealth    = require(script.Parent.stealth)
local Watchdog   = require(script.Parent.watchdog)
local Services   = require(script.Parent.game.services)
local BloxFruits = require(script.Parent.game.blox_fruits)
local Data       = require(script.Parent.data)
local Events     = require(script.Parent.events)

local Kernel = {}

local KERNEL_VERSION = "0.5.0-slice5"

function Kernel.boot(Library)
    -- 1. Connection tracker. Built first because the events system
    --    needs it for any future timed events.
    local conn = Connection.new(Library)

    -- 2. Events system. Built before everything else so every other
    --    module can hold a reference to it from construction. The
    --    Versus library is passed in for the in-window display
    --    subscriber; the Flags table is read on every emit so the
    --    webhook URL can be set without re-initialising.
    local flags = (Library and Library.Flags) or {}
    local events = Events.new(conn, Library, flags)

    -- 3. Compat detection.
    local compat = Compat.detect()

    -- 4. Module registry. Wires to the events system.
    local registry = Registry.new(conn)
    registry:setEmitter(function(name, payload)
        events:emit(name, payload)
    end)

    -- 5. Stealth layer (D17: balanced profile default).
    local stealth = Stealth.new()
    stealth:setEmitter(function(name, payload)
        events:emit(name, payload)
    end)

    -- 6. Watchdog. Constructed, NOT started.
    local watchdog = Watchdog.new(conn, registry, compat)
    watchdog:setEmitter(function(name, payload)
        events:emit(name, payload)
    end)

    -- 7. Services cache.
    local services = Services.new()

    -- 8. Blox Fruits probe.
    local bloxFruits = BloxFruits.new()

    -- 9. Data registry.
    local data = Data.new(services)
    data:setEmitter(function(name, payload)
        events:emit(name, payload)
    end)

    -- 10. Publish to _G.VersusKernel.
    local graph = {
        version  = KERNEL_VERSION,
        compat   = compat,
        events   = events,
        conn     = conn,
        registry = registry,
        stealth  = stealth,
        watchdog = watchdog,
        services = services,
        game     = bloxFruits,
        data     = data,
    }
    _G.VersusKernel = graph

    -- 11. Boot complete. Emit "started" so the events system is
    --     visibly alive and the user's webhook (if configured) gets
    --     a single "the script is up" ping per session.
    events:emit("started", { version = KERNEL_VERSION })

    return graph
end

return Kernel
