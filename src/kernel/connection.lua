--[[
    Versus-Airlines :: kernel/connection
    -------------------------------------
    Single source of truth for RBXScriptConnections. Every :Connect in
    the script goes through Connection.track(conn, tag) so that:
        (1) a module can disconnect every connection it owns by tag
            (registry.stop),
        (2) the watchdog can audit the live connection table for orphans,
        (3) the kernel never depends on the Versus library being present.

    Public API:
        Connection.new(Library)               -> Connection
        Connection:track(rbxConn, tag)        -> rbxConn     -- chainable
        Connection:cleanup(tag)               -> int         -- disconnected count
        Connection:cleanupPrefix(prefix)      -> int
        Connection:cleanupAll()               -> int
        Connection:list()                     -> { {conn, tag} }
        Connection:count()                    -> int
        Connection:bindHeartbeat(cb, tag?)    -> rbxConn | nil
        Connection:bindRenderStepped(cb, tag?)-> rbxConn | nil

    Error policy: track() accepts a non-connection by warning and
    returning the value unchanged. cleanup/cleanupPrefix/cleanupAll
    pcall every Disconnect. Bind helpers are pcall-guarded against
    missing services.
]]

local Connection = {}
Connection.__index = Connection

-- ============================================================================
-- Constants
-- ============================================================================
local DEFAULT_TAG_HEARTBEAT     = "kernel:heartbeat"
local DEFAULT_TAG_RENDERSTEPPED = "kernel:renderstepped"
local DEFAULT_TAG               = "default"

-- ============================================================================
-- Construction
-- ============================================================================

-- Create a new Connection tracker. Library is optional; if present,
-- track() forwards to the Versus library's own TrackConnection so the
-- library's built-in cleanup continues to work.
function Connection.new(Library)
    local self = setmetatable({}, Connection)
    self._lib   = Library
    self._table = {}   -- array of { conn = rbxScriptConnection, tag = string }
    return self
end

-- ============================================================================
-- Public
-- ============================================================================

-- Register a connection. Tag defaults to "default". Returns the
-- connection unchanged so call sites can chain. Warns (not throws)
-- if a non-connection is passed.
function Connection:track(conn, tag)
    if not Connection._isConn(conn) then
        warn("[Versus/Connection] track() called with non-connection: " .. tostring(conn))
        return conn
    end
    tag = tostring(tag or DEFAULT_TAG)
    table.insert(self._table, { conn = conn, tag = tag })

    -- Forward to the Versus library if it's available.
    if self._lib and type(self._lib.TrackConnection) == "function" then
        pcall(self._lib.TrackConnection, self._lib, conn, tag)
    end
    return conn
end

-- Disconnect every connection whose tag exactly matches. Returns the
-- number of connections removed.
function Connection:cleanup(tag)
    if tag == nil then return 0 end
    return self:_disconnectMatching(function(t) return t == tostring(tag) end)
end

-- Disconnect every connection whose tag starts with the given prefix.
-- Returns the number of connections removed.
function Connection:cleanupPrefix(prefix)
    if type(prefix) ~= "string" or prefix == "" then return 0 end
    return self:_disconnectMatching(function(t) return t:sub(1, #prefix) == prefix end)
end

-- Disconnect every tracked connection. Returns the number removed.
function Connection:cleanupAll()
    return self:_disconnectMatching(function() return true end)
end

-- Snapshot of the connection table. Returns a shallow copy; mutating
-- the result does not affect the tracker.
function Connection:list()
    local out = {}
    for i, entry in ipairs(self._table) do
        out[i] = { conn = entry.conn, tag = entry.tag }
    end
    return out
end

-- Number of currently-tracked connections. Used by the status label
-- and the connection-audit watchdog (slice 2).
function Connection:count()
    return #self._table
end

-- Bind a Heartbeat callback. Creates the :Connect under pcall so
-- missing services don't throw, then registers the connection.
-- Returns the (possibly nil) connection.
function Connection:bindHeartbeat(callback, tag)
    return self:_bindService("Heartbeat", callback, tag or DEFAULT_TAG_HEARTBEAT)
end

-- Bind a RenderStepped callback. Same contract as bindHeartbeat.
function Connection:bindRenderStepped(callback, tag)
    return self:_bindService("RenderStepped", callback, tag or DEFAULT_TAG_RENDERSTEPPED)
end

-- ============================================================================
-- Internal
-- ============================================================================

-- True if x looks like an RBXScriptConnection. We duck-type instead
-- of using typeof() so this works in Luau without the type guard.
function Connection._isConn(x)
    return type(x) == "table"
        and type(x.Disconnect) == "function"
        and type(x.Connected) == "boolean"
end

-- Iterate the table backwards (so removals don't shift indices) and
-- call Disconnect on entries that match the predicate.
function Connection:_disconnectMatching(predicate)
    local removed = 0
    for i = #self._table, 1, -1 do
        local entry = self._table[i]
        if predicate(entry.tag) then
            pcall(function()
                if entry.conn and entry.conn.Connected then
                    entry.conn:Disconnect()
                end
            end)
            table.remove(self._table, i)
            removed = removed + 1
        end
    end
    return removed
end

-- Look up a service by name, attach the callback to the named signal,
-- and register the resulting connection. Pcall-guarded so a missing
-- service (e.g. RunService stripped by a sandbox) doesn't throw.
function Connection:_bindService(signalName, callback, tag)
    local conn
    pcall(function()
        local RunService = game:GetService("RunService")
        local signal = RunService[signalName]
        if signal and type(signal.Connect) == "function" then
            conn = signal:Connect(callback)
        end
    end)
    if conn then
        self:track(conn, tag)
    end
    return conn
end

return Connection
