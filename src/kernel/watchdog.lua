--[[
    Versus-Airlines :: kernel/watchdog
    ------------------------------------
    Long-session AFK supervisor (D11). Three independent supervisors run
    on independent tags so any one can be stopped without affecting the
    others.

        (1) Heartbeat supervisor: every HEARTBEAT_INTERVAL_SEC, verify
            a health flag has flipped. If not, emit a "stalled" event.
        (2) Connection-audit supervisor: every AUDIT_INTERVAL_SEC, walk
            the kernel's connection table. Anything not owned by an
            active module tag is flagged as an orphan.
        (3) Reconnect supervisor: listen on PlayerRemoving, game.Idled,
            game.Close. On disconnect, attempt queue_on_teleport if
            available, else TeleportService.

    Public API:
        Watchdog.new(Connection, Registry, Compat) -> Watchdog
        Watchdog:start()    -> nil
        Watchdog:stop()     -> nil
        Watchdog:isRunning() -> bool
        Watchdog:health()   -> { ok = bool, hb = bool, audit = bool, reconnect = bool }
        Watchdog:setEmitter(emitFn) -> nil
]]

local Watchdog = {}
Watchdog.__index = Watchdog

local HEARTBEAT_INTERVAL_SEC = 30.0
local AUDIT_INTERVAL_SEC     = 300.0
local HEARTBEAT_TAG          = "kernel:watchdog:heartbeat"
local AUDIT_TAG              = "kernel:watchdog:audit"
local RECONNECT_TAG          = "kernel:watchdog:reconnect"
local HEALTH_FLAG_KEY        = "_vs_health_tick"
local QUEUE_TP_SCRIPT_NAME   = "Versus-Airlines"

function Watchdog.new(Connection, Registry, Compat)
    local self = setmetatable({}, Watchdog)
    self._conn     = Connection
    self._reg      = Registry
    self._compat   = Compat
    self._running  = false
    self._hbUp     = false
    self._auUp     = false
    self._reUp     = false
    self._emit     = nil
    return self
end

function Watchdog:setEmitter(emitFn)
    self._emit = emitFn
end

function Watchdog:start()
    if self._running then return end
    self._running = true
    self._hbUp = self:_startHeartbeat()
    self._auUp = self:_startAudit()
    self._reUp = self:_startReconnect()
end

function Watchdog:stop()
    if not self._running then return end
    self._running = false
    if self._conn then
        self._conn:cleanup(HEARTBEAT_TAG)
        self._conn:cleanup(AUDIT_TAG)
        self._conn:cleanup(RECONNECT_TAG)
    end
    self._hbUp, self._auUp, self._reUp = false, false, false
end

function Watchdog:isRunning()
    return self._running
end

function Watchdog:health()
    return {
        ok        = self._running,
        heartbeat = self._hbUp,
        audit     = self._auUp,
        reconnect = self._reUp,
    }
end

function Watchdog:_startHeartbeat()
    local ok = pcall(function()
        self._conn:bindHeartbeat(function()
            if not self._running then return end
            local prev = _G[HEALTH_FLAG_KEY]
            local now  = os.clock()
            if prev and (now - prev) > (HEARTBEAT_INTERVAL_SEC * 3) then
                if self._emit then
                    self._emit("milestone", { text = "watchdog: heartbeat missed " .. tostring(math.floor(now - prev)) .. "s", level = "warn" })
                end
            end
            _G[HEALTH_FLAG_KEY] = now
        end, HEARTBEAT_TAG)
    end)
    _G[HEALTH_FLAG_KEY] = os.clock()
    return ok and true or false
end

function Watchdog:_startAudit()
    local ok = pcall(function()
        self._conn:bindHeartbeat(function()
            if not self._running then return end
            local list = self._conn:list()
            local orphanCount = 0
            for _, entry in ipairs(list) do
                local tag = entry.tag or ""
                if not (tag:sub(1, 7) == "kernel:") and not (tag:sub(1, 4) == "mod:") then
                    orphanCount = orphanCount + 1
                end
            end
            if orphanCount > 0 and self._emit then
                self._emit("milestone", { text = "watchdog: " .. tostring(orphanCount) .. " orphan connection(s)", level = "warn" })
            end
        end, AUDIT_TAG)
    end)
    return ok and true or false
end

function Watchdog:_startReconnect()
    local ok = pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        if not LocalPlayer then return end

        LocalPlayer.PlayerRemoving:Connect(function()
            self:_attemptReconnect("PlayerRemoving")
        end)

        game.Idled:Connect(function()
            self:_attemptReconnect("game.Idled")
        end)

        game.Close:Connect(function()
            if self._compat and self._compat.canQueueTeleport then
                pcall(function()
                    queue_on_teleport(QUEUE_TP_SCRIPT_NAME .. " rejoin script")
                end)
            end
        end)
    end)
    return ok and true or false
end

function Watchdog:_attemptReconnect(reason)
    if not self._running then return end
    if self._emit then
        self._emit("disconnected", { reason = reason })
    end

    if self._compat and self._compat.canQueueTeleport then
        pcall(function()
            queue_on_teleport(QUEUE_TP_SCRIPT_NAME .. " rejoin script")
        end)
    end

    pcall(function()
        local TeleportService = game:GetService("TeleportService")
        if TeleportService and game.PlaceId and game.JobId then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
        end
    end)

    if self._emit then
        self._emit("reconnected", { reason = reason })
    end
end

return Watchdog
