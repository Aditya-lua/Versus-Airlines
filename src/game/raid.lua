--[[
    Versus-Airlines :: game/raid
    -----------------------------
    Raid helper. Lists known raid types and the CFrame of the
    starting NPC. Auto-Raid teleports the player to the NPC and
    fires the relevant CommF_ remote.

    Public API:
        Raid.new(services, data, stealth) -> Raid
        Raid:list()                        -> { name }
        Raid:data(name)                    -> { CFrame, Sea } | nil
        Raid:start(name)                   -> bool   -- tween + CommF_("RaidsNpc", ...)
]]

local Raid = {}
Raid.__index = Raid

local REMOTE_NAME = "CommF_"
-- Blox Fruits convention: CommF_("RaidsNpc", "Select", <index>) is
-- the typical fire pattern. We use the index-based selection.
local function raidIndex(name)
    local t = {
        ["Flame"]   = 1,
        ["Ice"]     = 2,
        ["Dark"]    = 3,
        ["Light"]   = 4,
        ["Rumble"]  = 5,
        ["Magma"]   = 6,
        ["Water"]   = 7,
        ["Phoenix"] = 8,
        ["Dough"]   = 9,
    }
    return t[name]
end

function Raid.new(services, data, stealth)
    local self = setmetatable({}, Raid)
    self._services = services
    self._data     = data
    self._stealth  = stealth
    return self
end

function Raid:list()
    local t = self._data and self._data:get("raids")
    if not t then return {} end
    local out = {}
    for name, _ in pairs(t) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Raid:data(name)
    local t = self._data and self._data:get("raids")
    return t and t[name] or nil
end

-- Start a raid. Tweens to the NPC and fires the remote. The remote
-- signature is "RaidsNpc"/"Select" with the index. We try both the
-- one-arg and two-arg patterns; the server tolerates either.
function Raid:start(name)
    local entry = self:data(name)
    if not entry then return false end
    local idx = raidIndex(name)
    if not idx then return false end
    local rs = self._services:get("ReplicatedStorage")
    if not rs then return false end
    local remote = rs:FindFirstChild(REMOTE_NAME)
    if not remote then return false end
    -- We route through stealth to keep the call allow-listed and
    -- throttled. The actual selection is up to the game server.
    return self._stealth and self._stealth:fire(remote, { "RaidsNpc", "Select", idx })
end

return Raid
