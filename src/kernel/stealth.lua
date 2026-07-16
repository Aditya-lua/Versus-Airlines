--[[
    Versus-Airlines :: kernel/stealth
    -----------------------------------
    Stealth layer (D17, D7). Until AC research (slice 11) is done, the
    default profile is "balanced" — every Remote call is routed through
    a throttle, an allow-list filters game remotes, and a deny-list
    blocks the known AC remote names. No hookfunction is used for
    remote spying (we use the event-listener model on T2).

    Public API:
        Stealth.new()                     -> Stealth
        Stealth:profile()                 -> "safe" | "balanced" | "permissive" | "off"
        Stealth:setProfile(name)          -> bool
        Stealth:humanize()                -> number
        Stealth:guard(remoteName)         -> bool, err
        Stealth:fire(remote, argsTable)   -> bool, err
        Stealth:allowRemote(name)         -> nil
        Stealth:denyRemote(name)          -> nil
        Stealth:listAllowed()             -> { name }
        Stealth:listDenied()              -> { name }
        Stealth:stats()                   -> { allowed, denied, throttled }
        Stealth:setEmitter(emitFn)         -> nil
]]

local Stealth = {}
Stealth.__index = Stealth

local PROFILE_SAFE       = "safe"
local PROFILE_BALANCED   = "balanced"
local PROFILE_PERMISSIVE = "permissive"
local PROFILE_OFF        = "off"

local PROFILES = {
    [PROFILE_SAFE]       = { minMs = 200, maxMs = 500, useAllow = true,  useDeny = false },
    [PROFILE_BALANCED]   = { minMs = 100, maxMs = 300, useAllow = true,  useDeny = true  },
    [PROFILE_PERMISSIVE] = { minMs =  50, maxMs = 150, useAllow = false, useDeny = true  },
    [PROFILE_OFF]        = { minMs =   0, maxMs =   0, useAllow = false, useDeny = false },
}

local DEFAULT_DENY_LIST = {
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
}

local DEFAULT_ALLOW_LIST = {
    CommF_ = true,
}

function Stealth.new()
    local self = setmetatable({}, Stealth)
    self._profile    = PROFILE_BALANCED
    self._allow      = {}
    self._deny       = {}
    self._lastFire   = {}
    self._stats      = { allowed = 0, denied = 0, throttled = 0 }
    self._emit       = nil
    for name, _ in pairs(DEFAULT_ALLOW_LIST) do self._allow[name] = true end
    for name, _ in pairs(DEFAULT_DENY_LIST)  do self._deny[name]  = true end
    return self
end

function Stealth:setEmitter(emitFn)
    self._emit = emitFn
end

function Stealth:profile()           return self._profile end
function Stealth:setProfile(name)
    if not PROFILES[name] then return false end
    self._profile = name
    if self._emit then self._emit("milestone", { text = "stealth profile -> " .. name }) end
    return true
end

function Stealth:humanize()
    local p = PROFILES[self._profile]
    if not p or p.maxMs == 0 then return 0 end
    if p.minMs == p.maxMs then return p.minMs end
    return math.random(p.minMs, p.maxMs)
end

function Stealth:guard(remoteName)
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
        allowed   = self._stats.allowed,
        denied    = self._stats.denied,
        throttled = self._stats.throttled,
    }
end

return Stealth
