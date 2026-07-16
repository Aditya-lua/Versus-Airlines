--[[
    Versus-Airlines :: loader
    --------------------------
    Public entry point. Loaded via:

        loadstring(game:HttpGet("<host>/loader.lua"))()

    Boot order:
        1. Load the Versus UI library and mount the window
        2. Boot the kernel (compat, events, conn, registry, stealth,
           watchdog, services, game probe, data)
        3. Mount the section tree (every toggle is wired to
           kernel.events and kernel.registry)
        4. Start the live status label
        5. Start the watchdog
        6. Eager-warm the services cache
        7. Probe the current game (sea)
        8. Load the data files (17 tables)
        9. Emit "started" with version

    Version:  0.5.0-slice5
    License:  see docs/LICENSE (TBD)
    Entry:    <host>/loader.lua
    Internal: see docs/STYLE.md
]]

local function loadFromSrc(name)
    local path = "src/" .. name:gsub("%.", "/") .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then
        error("loadFromSrc failed: " .. path .. " :: " .. tostring(err))
    end
    return chunk()
end

-- 1. Mount the Versus window.
local Window  = loadFromSrc("ui.window")
local Library = Window.create()

-- 2. Boot the kernel.
local Kernel = loadFromSrc("kernel.init")
local kernel = Kernel.boot(Library)

-- 3. Mount the section tree.
local Sections = loadFromSrc("ui.sections")
Sections.build(Library, kernel)

-- 4. Start the live status label.
local Status = loadFromSrc("ui.status")
local _statusHandle = Status.start(kernel)

-- 5. Start the watchdog.
if kernel.watchdog and kernel.watchdog.start then
    kernel.watchdog:start()
end

-- 6. Eager-warm the services cache.
if kernel.services and kernel.services.init then
    kernel.services:init()
end

-- 7. Probe the current game.
if kernel.game and kernel.game.detectSea then
    local sea = kernel.game:detectSea()
    if sea == 0 then
        kernel.events:emit("milestone", { text = "not in Blox Fruits (or unknown placeId)", level = "warn" })
    end
end

-- 8. Load the data files.
if kernel.data and kernel.data.loadAll then
    kernel.data:loadAll()
end

-- 9. Boot complete.
return kernel
