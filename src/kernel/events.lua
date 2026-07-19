--[[
    Versus-Airlines :: kernel/events
    ---------------------------------
    Named event system. Replaces the old logger (D30). Modules call
    kernel.events:emit("level_up", {level = 700}) instead of
    kernel.logger:info(...).

    Events are:
        (1) named with a short string ("level_up", "boss_defeated",
            "started", "stopped", "kicked", "disconnected",
            "reconnected", "milestone", etc.),
        (2) routed to subscribers (in-window display + optional
            Discord webhook),
        (3) throttled per-name so the same event doesn't fire
            repeatedly in a short window.

    The webhook subscriber reads the URL from Library.Flags
    (Versus's saves.json, D15). If the URL is empty, the webhook
    subscriber is a no-op for milestone events and a warn for
    important events. This is by design (D31): the script is safe
    to run with no setup, rewarding once the webhook is set.

    Public API:
        Events.new(Connection, Library, Flags)  -> Events
        Events:emit(name, payload?)              -> bool
        Events:on(name, callback)                 -> nil
        Events:onAny(callback)                    -> nil
        Events:throttle(name, seconds)            -> nil
        Events:list()                             -> { name }
        Events:history()                          -> { {name, t, payload}, ... }

    Error policy: every public method is pcall-guarded. The
    webhook POST is fire-and-forget. The in-window display skips
    if the library is closed.
]]

local Events = {}
Events.__index = Events

-- ============================================================================
-- Constants
-- ============================================================================
-- Per-name default throttle, in seconds. Override via :throttle().
local DEFAULT_THROTTLE_SEC = {
    -- Important: short throttle so the user is notified promptly
    started        = 0,
    stopped        = 0,
    kicked         = 0,
    disconnected   = 0,
    reconnected    = 0,
    -- Milestone: throttle so the same milestone doesn't fire repeatedly
    level_up       = 5,     -- max once per 5s even if level jumps
    boss_defeated  = 0,     -- each kill is its own event
    drop_acquired  = 0,     -- each drop is its own event
    milestone      = 10,    -- generic milestone bucket
}

-- Per-name importance. "important" events always reach the user
-- (window + webhook). "milestone" events go to the webhook only.
local DEFAULT_IMPORTANCE = {
    started        = "important",
    stopped        = "important",
    kicked         = "important",
    disconnected   = "important",
    reconnected    = "important",
    level_up       = "milestone",
    boss_defeated  = "milestone",
    drop_acquired  = "milestone",
    milestone      = "milestone",
}

local WINDOW_HISTORY_LIMIT = 50
local WEBHOOK_TIMEOUT_SEC   = 5

-- ============================================================================
-- Construction
-- ============================================================================

-- Create a new Events hub. Connection is required for the heartbeat
-- that fires scheduled events. Library is required for in-window
-- display. Flags is the Versus Library.Flags table, which the
-- webhook subscriber reads each emit (so a flag change takes
-- effect on the next emit, no restart).
function Events.new(Connection, Library, Flags)
    local self = setmetatable({}, Events)
    self._conn      = Connection
    self._lib       = Library
    self._flags     = Flags
    self._throttle  = {}  -- name -> last-emit-tick
    self._subs      = {}  -- name -> { callback, ... }
    self._anySubs   = {}  -- { callback, ... }
    self._history   = {}  -- ring buffer of recent {name, t, payload}
    return self
end

-- ============================================================================
-- Public
-- ============================================================================

-- Emit a named event with an optional payload table. Returns true if
-- the event was dispatched (after throttle), false if throttled.
-- The payload is passed to every subscriber.
function Events:emit(name, payload)
    if type(name) ~= "string" or name == "" then return false end
    payload = payload or {}

    -- 1. Throttle check.
    local now = os.clock()
    local last = self._throttle[name]
    local minGap = DEFAULT_THROTTLE_SEC[name] or 0
    -- First emit of a name (last == nil) always fires.
    if last ~= nil and (now - last) < minGap then
        return false
    end
    self._throttle[name] = now

    -- 2. Record in history.
    table.insert(self._history, 1, { name = name, t = os.time(), payload = payload })
    while #self._history > WINDOW_HISTORY_LIMIT do
        table.remove(self._history)
    end

    -- 3. Fan out to named subscribers + catch-all subscribers.
    local subs = self._subs[name]
    if subs then
        for _, cb in ipairs(subs) do
            pcall(function() cb(name, payload) end)
        end
    end
    for _, cb in ipairs(self._anySubs) do
        pcall(function() cb(name, payload) end)
    end

    -- 4. Built-in subscribers: in-window display + webhook.
    local importance = DEFAULT_IMPORTANCE[name] or "milestone"
    self:_displayWindow(name, payload, importance)
    self:_sendWebhook(name, payload, importance)

    return true
end

-- Subscribe a callback to a specific event name. Multiple
-- subscribers per name are allowed.
function Events:on(name, callback)
    if type(name) ~= "string" or type(callback) ~= "function" then return end
    self._subs[name] = self._subs[name] or {}
    table.insert(self._subs[name], callback)
end

-- Subscribe a callback to ALL events. Used by the status label
-- (it shows the last event name) and by potential future modules
-- that want to react to "anything happened".
function Events:onAny(callback)
    if type(callback) ~= "function" then return end
    table.insert(self._anySubs, callback)
end

-- Set or override the per-name throttle.
function Events:throttle(name, seconds)
    if type(name) == "string" then
        DEFAULT_THROTTLE_SEC[name] = math.max(0, tonumber(seconds) or 0)
    end
end

-- Names of every event ever emitted. Used by the status label.
function Events:list()
    local seen = {}
    for _, entry in ipairs(self._history) do
        seen[entry.name] = true
    end
    local out = {}
    for name, _ in pairs(seen) do out[#out + 1] = name end
    table.sort(out)
    return out
end

-- History snapshot. Most recent first. Used by the status label
-- ("last event: level_up (12s ago)") and by the webhook fallback
-- in case the user asks "what happened while I was away".
function Events:history()
    return self._history
end

-- ============================================================================
-- Built-in subscribers
-- ============================================================================

-- In-window display. Always fired for important events; fired
-- for milestone events too so the user can see them live.
function Events:_displayWindow(name, payload, importance)
    if not self._lib or self._lib.isClosed then return end
    local style = importance == "important" and "danger" or "info"
    pcall(function()
        self._lib:createDisplayMessage(
            "[Versus] " .. name,
            self:_formatPayload(name, payload),
            { { text = "OK" } },
            style
        )
    end)
end

-- Discord webhook. Reads the URL from Flags.WebhookURL each emit.
-- Important events fire regardless of webhook state (in-window
-- always fires; webhook only if URL is set). Milestone events only
-- fire to the webhook; if the URL is empty they're a no-op.
function Events:_sendWebhook(name, payload, importance)
    local url = self._flags and self._flags.WebhookURL
    if type(url) ~= "string" or url == "" then return end
    if not url:match("^https?://discord%.com/api/webhooks/") then return end

    pcall(function()
        local request = (syn and syn.request) or (http and http.request) or http_request
        if not request then return end
        local HttpService = game:GetService("HttpService")
        request({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                content  = string.format("**[%s]** %s", name, self:_formatPayload(name, payload)),
                username = "Versus-Airlines",
            }),
        })
    end)
end

-- Format a payload for display. Falls back to "" if there's nothing
-- interesting to show.
function Events:_formatPayload(name, payload)
    if type(payload) ~= "table" or next(payload) == nil then return "" end
    local parts = {}
    for k, v in pairs(payload) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

return Events
