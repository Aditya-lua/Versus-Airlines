--[[
    Versus-Airlines :: kernel/stealth
    -----------------------------------
    Stealth layer (D17, D7, slice 11). AC-research gated.

    Profiles:
        safe       — long throttle, strict allow + deny
        balanced   — medium throttle, allow (CommF_) + deny
        permissive — short throttle, deny only
        off        — no throttle, no filtering

    Slice 11 additions:
        * Per-executor profile picker (`executorName` -> profile).
          Detected via the Tier from Compat. T1 starts at "balanced";
          T2 starts at "safe" (no hookfunction; harder to hide).
        * 2-minute handshake delay on first `fire` (per session).
          The Blox Fruits server uses a hook-detection handshake
          (1-2 min after join) before triggering its GUI bomb. We
          wait out the handshake, then start firing.
        * Extended deny-list with publicly-known AC remote names
          (gathered from the blox-fruits community, slice 11
          research pass).

    Public API:
        Stealth.new()                     -> Stealth
        Stealth:profile()                 -> "safe" | "balanced" | "permissive" | "off"
        Stealth:setProfile(name)          -> bool
        Stealth:executorTier()            -> 1 | 2 | nil
        Stealth:setExecutorTier(t)        -> nil
        Stealth:handshakeComplete()       -> bool
        Stealth:markHandshakeComplete()   -> nil
        Stealth:handshakeTimeout()        -> bool
        Stealth:handshakeRemaining()      -> number (sec)
        Stealth:humanize()                -> number
        Stealth:guard(remoteName)         -> bool, err
        Stealth:fire(remote, argsTable)   -> bool, err
        Stealth:allowRemote(name)         -> nil
        Stealth:denyRemote(name)          -> nil
        Stealth:listAllowed()             -> { name }
        Stealth:listDenied()              -> { name }
        Stealth:stats()                   -> { allowed, denied, throttled, handshake }
        Stealth:setEmitter(emitFn)        -> nil
]]

local Stealth = {}
Stealth.__index = Stealth

local PROFILE_SAFE       = "safe"
local PROFILE_BALANCED   = "balanced"
local PROFILE_PERMISSIVE = "permissive"
local PROFILE_OFF        = "off"

local PROFILES = {
    [PROFILE_SAFE]       = { minMs = 200, maxMs = 500, useAllow = true,  useDeny = true  },
    [PROFILE_BALANCED]   = { minMs = 100, maxMs = 300, useAllow = true,  useDeny = true  },
    [PROFILE_PERMISSIVE] = { minMs =  50, maxMs = 150, useAllow = false, useDeny = true  },
    [PROFILE_OFF]        = { minMs =   0, maxMs =   0, useAllow = false, useDeny = false },
}

-- Slice 11: extended deny-list. Beyond the 21-entry list from D17,
-- we add names that the Blox Fruits AC has been observed using in
-- public anti-cheat scripts. Names are case-sensitive as they
-- appear in ReplicatedStorage / PlayerGui.
local DEFAULT_DENY_LIST = {
    -- D17 baseline
    TeleportDetect  = true,
    CHECKER_1       = true,
    CHECKER         = true,
    GUI_CHECK       = true,
    OneMoreTime     = true,
    checkingSPEED   = true,
    BANREMOTE       = true,
    PERMAIDBAN      = true,
    KICKREMOTE      = true,
    BR_KICKPC       = true,
    BR_KICKMOBILE   = true,
    AntiCheat       = true,
    AntiHack        = true,
    AntiExploit     = true,
    AC_KICK         = true,
    AC_BAN          = true,
    SusActivity     = true,
    ModCheck        = true,
    AdminCheck      = true,
    Detection       = true,
    ExploitDetect   = true,
    -- Slice 11 additions (community-reported)
    CheckPlayer     = true,
    SpeedCheck      = true,
    TeleportCheck   = true,
    HealthCheck     = true,
    KICK_PLAYER     = true,
    BAN_PLAYER      = true,
    ACKick          = true,
    ACBan           = true,
    AntiTeleport    = true,
    AntiSpeed       = true,
    AntiFly         = true,
    AntiNoclip      = true,
    StatsCheck      = true,
    RejoinCheck     = true,
    ServerCheck     = true,
    ValidationCheck = true,
    AC_CHECK        = true,
    AC_MONITOR      = true,
    AC_DETECT       = true,
    AC_REPORT       = true,
    AC_LOG          = true,
    KickPlayer      = true,
    BanPlayer       = true,
}

local DEFAULT_ALLOW_LIST = {
    CommF_ = true,
    -- Slice 11: also allow Remotes.CommF_ (the standard path used
    -- by every Blox Fruits script). This is the SAME remote as
    -- CommF_ in ReplicatedStorage, just reached by a longer path.
    ["Remotes.CommF_"] = true,
}

-- Per-executor default profile. T1 (hookfunction) is more
-- forgiving because the script can patch detection callbacks
-- before they fire. T2 (no hookfunction) gets the strict profile.
local TIER_DEFAULTS = {
    [1] = PROFILE_BALANCED,
    [2] = PROFILE_SAFE,
}

local HANDSHAKE_DELAY_SEC = 90.0   -- 1.5 min; the 1-2 min Blox Fruits
                                    -- server-side hook-detection window.

function Stealth.new()
    local self = setmetatable({}, Stealth)
    self._profile          = PROFILE_BALANCED
    self._tier             = nil
    self._allow            = {}
    self._deny             = {}
    self._lastFire         = {}
    self._stats            = { allowed = 0, denied = 0, throttled = 0, handshake = 0 }
    self._emit             = nil
    self._bootTime         = os.clock()
    self._handshakeDone    = false
    for name, _ in pairs(DEFAULT_ALLOW_LIST) do self._allow[name] = true end
    for name, _ in pairs(DEFAULT_DENY_LIST)  do self._deny[name]  = true end
    return self
end

function Stealth:setEmitter(emitFn)
    self._emit = emitFn
end

-- Set the executor tier (1 = hookfunction, 2 = mobile / no hook).
-- Switches the default profile to the tier-specific one.
function Stealth:setExecutorTier(tier)
    if tier ~= 1 and tier ~= 2 then return end
    self._tier = tier
    local p = TIER_DEFAULTS[tier]
    if p then
        self._profile = p
        if self._emit then
            self._emit("milestone", { text = "stealth profile -> " .. p .. " (tier " .. tostring(tier) .. ")" })
        end
    end
end

function Stealth:executorTier() return self._tier end

function Stealth:profile()           return self._profile end
function Stealth:setProfile(name)
    if not PROFILES[name] then return false end
    self._profile = name
    if self._emit then self._emit("milestone", { text = "stealth profile -> " .. name }) end
    return true
end

-- Has the 90s handshake completed?
function Stealth:handshakeComplete() return self._handshakeDone end

-- Force-mark the handshake as complete (e.g. user toggles Stealth On
-- after the wait manually).
function Stealth:markHandshakeComplete()
    if self._handshakeDone then return end
    self._handshakeDone = true
    if self._emit then
        self._emit("milestone", { text = "AC handshake complete" })
    end
end

-- True if the handshake has been "completed" (either by time, or
-- explicitly). Used by guard() to block all remote fires during
-- the 90s window.
function Stealth:handshakeTimeout()
    if self._handshakeDone then return true end
    if (os.clock() - self._bootTime) >= HANDSHAKE_DELAY_SEC then
        self:markHandshakeComplete()
        return true
    end
    return false
end

-- Seconds remaining in the handshake window (0 if done).
function Stealth:handshakeRemaining()
    if self._handshakeDone then return 0 end
    local left = HANDSHAKE_DELAY_SEC - (os.clock() - self._bootTime)
    return math.max(0, left)
end

function Stealth:humanize()
    local p = PROFILES[self._profile]
    if not p or p.maxMs == 0 then return 0 end
    if p.minMs == p.maxMs then return p.minMs end
    return math.random(p.minMs, p.maxMs)
end

function Stealth:guard(remoteName)
    -- Block every remote during the handshake window. This is the
    -- single most important AC defense: don't call anything the
    -- server might observe before the hook-detection window ends.
    if not self:handshakeTimeout() then
        self._stats.handshake = self._stats.handshake + 1
        return false, "handshake"
    end

    local p = PROFILES[self._profile] or PROFILES[PROFILE_BALANCED]
    if self._deny[remoteName] then
        self._stats.denied = self._stats.denied + 1
        return false, "deny-list"
    end
    if p.useAllow and not self._allow[remoteName] then
        self._stats.denied = self._stats.denied + 1
        return false, "allow-list"
    end
    self._stats.allowed = self._stats.allowed + 1
    return true, nil
end

function Stealth:fire(remote, argsTable)
    if not remote then return false, "no remote" end
    argsTable = argsTable or {}
    local remoteName = tostring(remote.Name or "?")
    local ok, err = self:guard(remoteName)
    if not ok then return false, err end

    local now = os.clock()
    local last = self._lastFire[remoteName] or 0
    local minGap = (PROFILES[self._profile] or PROFILES[PROFILE_BALANCED]).minMs / 1000
    local wait = (last + minGap) - now
    if wait > 0 then
        self._stats.throttled = self._stats.throttled + 1
        if task and task.wait then
            pcall(function() task.wait(wait) end)
        end
    end
    self._lastFire[remoteName] = os.clock()

    local fok, ferr = pcall(function() remote:FireServer(table.unpack(argsTable)) end)
    if not fok then return false, "fire-failed" end
    return true, nil
end

function Stealth:allowRemote(name)
    if type(name) == "string" and name ~= "" then
        self._allow[name] = true
        if self._deny[name] then self._deny[name] = nil end
    end
end

function Stealth:denyRemote(name)
    if type(name) == "string" and name ~= "" then
        self._deny[name] = true
        if self._allow[name] then self._allow[name] = nil end
    end
end

function Stealth:listAllowed()
    local out = {}
    for name, _ in pairs(self._allow) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Stealth:listDenied()
    local out = {}
    for name, _ in pairs(self._deny) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Stealth:stats()
    return {
        allowed    = self._stats.allowed,
        denied     = self._stats.denied,
        throttled  = self._stats.throttled,
        handshake  = self._stats.handshake,
    }
end

return Stealth
