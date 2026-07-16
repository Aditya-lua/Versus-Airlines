--[[
    Versus-Airlines :: game/stat
    -----------------------------
    Stat allocation. Reads the player's stat point pool and the
    per-stat current values from game.Players.LocalPlayer.Data.Stats,
    then allocates points to the chosen priority. The Blox Fruits
    convention is:
        CommF_("AddStat", "Melee", <count>)
    Public API:
        Stat.new(services, data, stealth) -> Stat
        Stat:categories()                  -> { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
        Stat:read(category)                -> { points, max } | nil
        Stat:readAll()                     -> { category = { points, max }, ... }
        Stat:pointsAvailable()             -> int
        Stat:allocate(category, n)         -> bool    -- fires CommF_ stealth
        Stat:allocateByPriority(priority)  -> int     -- count allocated
]]

local Stat = {}
Stat.__index = Stat

local CATEGORIES = { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
local REMOTE_NAME = "CommF_"
local REMOTE_ARG  = "AddStat"

function Stat.new(services, data, stealth)
    local self = setmetatable({}, Stat)
    self._services = services
    self._data     = data
    self._stealth  = stealth
    return self
end

function Stat:categories() return CATEGORIES end

function Stat:_statNode(category)
    local Players = self._services:get("Players")
    if not Players then return nil end
    local p = Players.LocalPlayer
    if not p or not p.FindFirstChild or not p:FindFirstChild("Data") then return nil end
    local stats = p.Data:FindFirstChild("Stats")
    if not stats or not stats.FindFirstChild then return nil end
    return stats:FindFirstChild(category)
end

function Stat:read(category)
    if type(category) ~= "string" then return nil end
    local n = self:_statNode(category)
    if not n then return nil end
    -- Blox Fruits stat nodes are NumberValue with "Point" and "MaxPoint" children.
    local points = n:FindFirstChild("Point")
    local max    = n:FindFirstChild("MaxPoint")
    return {
        points = points and points.Value or 0,
        max    = max and max.Value or 0,
    }
end

function Stat:readAll()
    local out = {}
    for _, cat in ipairs(CATEGORIES) do
        out[cat] = self:read(cat)
    end
    return out
end

-- Total available stat points (the player's "StatPoints" or
-- "Points" attribute on Data, depending on game version). Returns
-- 0 if not found.
function Stat:pointsAvailable()
    local Players = self._services:get("Players")
    if not Players then return 0 end
    local p = Players.LocalPlayer
    if not p or not p.FindFirstChild or not p:FindFirstChild("Data") then return 0 end
    local data = p.Data
    if not data or not data.FindFirstChild then return 0 end
    -- Try common field names.
    for _, name in ipairs({ "StatPoints", "Points", "AvailablePoints" }) do
        local v = data:FindFirstChild(name)
        if v and v.Value then return v.Value end
    end
    return 0
end

-- Allocate `n` points to a category via the CommF_ remote.
-- Routes through stealth (allow-listed, throttled).
function Stat:allocate(category, n)
    if type(category) ~= "string" or type(n) ~= "number" or n <= 0 then
        return false
    end
    local rs = self._services:get("ReplicatedStorage")
    if not rs then return false end
    local remote = rs:FindFirstChild(REMOTE_NAME)
    if not remote then return false end
    if not self._stealth then return false end
    return self._stealth:fire(remote, { REMOTE_ARG, category, n })
end

-- Allocate every available point to the chosen priority, in
-- priority order. Returns the number of calls made.
function Stat:allocateByPriority(priority)
    if type(priority) ~= "string" then priority = CATEGORIES[1] end
    if not self._stealth then return 0 end
    -- The server allocates one point per call.
    local total = self:pointsAvailable()
    if total <= 0 then return 0 end
    local n = 0
    for i = 1, total do
        if self:allocate(priority, 1) then
            n = n + 1
        else
            break
        end
    end
    return n
end

return Stat
