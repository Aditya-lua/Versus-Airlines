--[[
    Versus-Airlines :: kernel/init
    --------------------------------
    The kernel entry point. Wires Compat + Connection + Registry +
    Stealth + Watchdog + Services + BloxFruits + Data + Events into a
    single graph and publishes it to _G.VersusKernel (D16).

    In addition, the kernel *loads and instantiates* the game-side
    modules (movement, quest, mob, combat) and exposes them as
    kernel.movement / kernel.quest / kernel.mob / kernel.combat.
    Modules like the autofarm access these directly without doing
    their own file I/O.

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
            movement = <Movement>,
            quest    = <Quest>,
            mob      = <Mob>,
            combat   = <Combat>,
            bring    = <Bring>,
            boss     = <Boss>,
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
local Movement   = require(script.Parent.game.movement)
local Quest      = require(script.Parent.game.quest)
local Mob        = require(script.Parent.game.mob)
local Combat     = require(script.Parent.game.combat)
local Bring      = require(script.Parent.game.bring)
local Boss       = require(script.Parent.game.boss)
local Fruit      = require(script.Parent.game.fruit)
local SeaEvent   = require(script.Parent.game.sea_event)
local Raid       = require(script.Parent.game.raid)
local V4Trial    = require(script.Parent.game.v4_trial)

local Kernel = {}

local KERNEL_VERSION = "0.9.0-slice9"

function Kernel.boot(Library)
    -- 1. Connection tracker.
    local conn = Connection.new(Library)

    -- 2. Events system.
    local flags = (Library and Library.Flags) or {}
    local events = Events.new(conn, Library, flags)

    -- 3. Compat detection.
    local compat = Compat.detect()

    -- 4. Module registry.
    local registry = Registry.new(conn)
    registry:setEmitter(function(name, payload)
        events:emit(name, payload)
    end)

    -- 5. Stealth layer.
    local stealth = Stealth.new()
    stealth:setEmitter(function(name, payload)
        events:emit(name, payload)
    end)

    -- 6. Watchdog.
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

    -- 10. Game modules. Pre-built so the autofarm and any other
    --     module can use them via kernel.movement / kernel.quest / etc.
    local movement = Movement.new(services, stealth, conn)
    local quest    = Quest.new(data, bloxFruits)
    local mob      = Mob.new(services)
    local combat   = Combat.new(services, stealth)
    local bring    = Bring.new(services, mob)
    local boss     = Boss.new(services, mob, data)
    local fruit    = Fruit.new(services, stealth, data, mob)
    local seaEvent = SeaEvent.new(services, mob, data)
    local raid     = Raid.new(services, data, stealth)
    local v4       = V4Trial.new(data)

    -- 11. Publish to _G.VersusKernel.
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
        movement = movement,
        quest    = quest,
        mob      = mob,
        combat   = combat,
        bring    = bring,
        boss     = boss,
        fruit    = fruit,
        seaEvent = seaEvent,
        raid     = raid,
        v4       = v4,
        _library = Library,
    }
    _G.VersusKernel = graph

    -- 12. Boot complete.
    events:emit("started", { version = KERNEL_VERSION })

    return graph
end

return Kernel

