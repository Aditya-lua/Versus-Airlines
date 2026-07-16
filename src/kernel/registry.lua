--[[
    Versus-Airlines :: kernel/registry
    ------------------------------------
    Module registry. Each module registers a definition:
        { name, ui, start, stop, isRunning, health }
    UI code calls registry.start(name) / registry.stop(name) when a
    toggle flips. The registry dispatches, updates state, and asks the
    Connection tracker to clean up any connections owned by the
    module's tag.

    Public API:
        Registry.new(Connection)                -> Registry
        Registry:register(modDef)               -> bool
        Registry:start(name)                    -> bool
        Registry:stop(name)                     -> bool
        Registry:stopAll()                      -> int
        Registry:isRunning(name)                -> bool
        Registry:list()                         -> { {name, running, tag} }
        Registry:health(name)                   -> { ok = bool, msg = string } | nil

    Error policy: every method is pcall-guarded. A failed start or stop
    is logged via the events system (kernel.events) but does not throw
    to the caller.
]]

local Registry = {}
Registry.__index = Registry

local MODULE_TAG_PREFIX = "mod:"

function Registry.new(Connection)
    local self = setmetatable({}, Registry)
    self._conn = Connection
    self._mods = {}
    return self
end

function Registry:register(modDef)
    local err = self:_validate(modDef)
    if err then return false end
    if self._mods[modDef.name] then
        if self._emit then self._emit("milestone", { text = "registry: replacing " .. modDef.name }) end
    end
    modDef._running = false
    modDef._tag     = modDef.tag or (MODULE_TAG_PREFIX .. modDef.name)
    self._mods[modDef.name] = modDef
    return true
end

-- Set the event emitter (called by kernel.init after the events
-- system is built). The registry logs to the events system but
-- doesn't take it as a constructor arg so the dependency graph
-- stays simple.
function Registry:setEmitter(emitFn)
    self._emit = emitFn
end

function Registry:start(name)
    local modDef = self._mods[name]
    if not modDef then return false end
    if modDef._running then return true end
    if self._conn then
        self._conn:cleanup(modDef._tag)
        self._conn:cleanupPrefix(modDef._tag .. ":")
    end
    local ok, err = pcall(modDef.start)
    if not ok then
        if self._emit then
            self._emit("milestone", { text = "start(" .. name .. ") failed: " .. tostring(err), level = "warn" })
        end
        return false
    end
    modDef._running = true
    if self._emit then self._emit("milestone", { text = "started " .. name }) end
    return true
end

function Registry:stop(name)
    local modDef = self._mods[name]
    if not modDef then return false end
    if not modDef._running then return true end
    local ok, err = pcall(modDef.stop)
    if not ok and self._emit then
        self._emit("milestone", { text = "stop(" .. name .. ") failed: " .. tostring(err), level = "warn" })
    end
    local removed = 0
    if self._conn then
        removed = self._conn:cleanup(modDef._tag)
        removed = removed + self._conn:cleanupPrefix(modDef._tag .. ":")
    end
    modDef._running = false
    return true
end

function Registry:stopAll()
    local stopped = 0
    for name, _ in pairs(self._mods) do
        if self:stop(name) then stopped = stopped + 1 end
    end
    return stopped
end

function Registry:isRunning(name)
    local modDef = self._mods[name]
    return modDef and modDef._running or false
end

function Registry:list()
    local out = {}
    for name, modDef in pairs(self._mods) do
        out[#out + 1] = {
            name    = name,
            running = modDef._running and true or false,
            tag     = modDef._tag,
        }
    end
    return out
end

function Registry:health(name)
    local modDef = self._mods[name]
    if not modDef or type(modDef.health) ~= "function" then return nil end
    local ok, res = pcall(modDef.health)
    if not ok then return { ok = false, msg = tostring(res) } end
    if type(res) == "table" then return res end
    return { ok = res and true or false, msg = nil }
end

function Registry:_validate(modDef)
    if type(modDef) ~= "table" then return "modDef is not a table" end
    if type(modDef.name) ~= "string" or modDef.name == "" then
        return "modDef.name missing"
    end
    if type(modDef.start) ~= "function" then return "modDef.start not a function" end
    if type(modDef.stop)  ~= "function" then return "modDef.stop not a function"  end
    return nil
end

return Registry
