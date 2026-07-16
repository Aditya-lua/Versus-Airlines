--[[
    Versus-Airlines :: game/party
    ------------------------------
    Party helper. Adds/removes members from a "party list" kept
    in memory (not server-side; Roblox Blox Fruits does not expose
    a private party API). The list is used by the "Teleport to
    Party" button to walk to each member in turn.

    Public API:
        Party.new(services, teleport) -> Party
        Party:add(name)               -> bool
        Party:remove(name)            -> bool
        Party:has(name)               -> bool
        Party:list()                  -> { name }
        Party:clear()                 -> int   -- count removed
        Party:teleportAll()           -> int   -- count teleported
        Party:find(name)              -> Player | nil
]]

local Party = {}
Party.__index = Party

function Party.new(services, teleport)
    local self = setmetatable({}, Party)
    self._services = services
    self._teleport = teleport
    self._members  = {}   -- name -> true
    return self
end

function Party:add(name)
    if type(name) ~= "string" or name == "" then return false end
    self._members[name] = true
    return true
end

function Party:remove(name)
    if type(name) ~= "string" or not self._members[name] then return false end
    self._members[name] = nil
    return true
end

function Party:has(name)
    return self._members[name] == true
end

function Party:list()
    local out = {}
    for name, _ in pairs(self._members) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Party:clear()
    local n = 0
    for k in pairs(self._members) do self._members[k] = nil; n = n + 1 end
    return n
end

-- Find a Players entry by display name (case-insensitive prefix match).
function Party:find(name)
    if type(name) ~= "string" or name == "" then return nil end
    local Players = self._services:get("Players")
    if not Players or not Players.GetPlayers then return nil end
    local ok, players = pcall(function() return Players:GetPlayers() end)
    if not ok or not players then return nil end
    local lower = name:lower()
    for _, p in ipairs(players) do
        if p and p.Name and p.Name:lower():sub(1, #lower) == lower then
            return p
        end
    end
    return nil
end

-- Teleport to every member in turn. Returns the number actually
-- teleported. Skips members that aren't in the current server
-- (Players list is server-scoped).
function Party:teleportAll()
    if not self._teleport then return 0 end
    local n = 0
    for name in pairs(self._members) do
        local p = self:find(name)
        if p and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position then
                if self._teleport:to(hrp.Position) then
                    n = n + 1
                end
            end
        end
    end
    return n
end

return Party
