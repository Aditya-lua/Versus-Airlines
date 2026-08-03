--[[
    Versus-Airlines :: game/boss
    ----------------------------
    Boss finder. Looks up the configured boss in the bosses data
    table, finds a live instance in Workspace.Enemies, and provides
    position/level helpers.

    Public API:
        Boss.new(services, mob, data)  -> Boss
        Boss:find(bossName)            -> Model | nil
        Boss:findLive(bossName)        -> Model | nil
        Boss:data(bossName)            -> {Level, Location, Sea, ...} | nil
        Boss:list()                    -> { name }
        Boss:byLevel(minLevel)         -> { name }   -- sea1 bosses <= minLevel
]]

local Boss = {}
Boss.__index = Boss

function Boss.new(services, mob, data)
    local self = setmetatable({}, Boss)
    self._services = services
    self._mob      = mob
    self._data     = data
    return self
end

function Boss:data(bossName)
    local t = self._data and self._data:get("bosses")
    return t and t[bossName] or nil
end

function Boss:find(bossName)
    -- First check Workspace.Enemies (a live instance has its name
    -- matching the boss data name).
    if not self._mob then return nil end
    local enemies = self._services:get("Workspace"):FindFirstChild("Enemies")
    if not enemies then return nil end
    for _, v in ipairs(enemies:GetChildren()) do
        if v.Name == bossName and self._mob:isAlive(v) then
            return v
        end
    end
    return nil
end

-- Alias kept for naming consistency with other modules.
Boss.findLive = Boss.find

function Boss:list()
    local t = self._data and self._data:get("bosses")
    if not t then return {} end
    local out = {}
    for name, _ in pairs(t) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Boss:byLevel(maxLevel)
    local t = self._data and self._data:get("bosses")
    if not t then return {} end
    local out = {}
    for name, data in pairs(t) do
        if type(data.Level) == "number" and data.Level <= maxLevel then
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b)
        return t[a].Level < t[b].Level
    end)
    return out
end

return Boss
