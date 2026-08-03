--[[
    Versus-Airlines :: game/v4_trial
    ---------------------------------
    V4 (race) trial helper. The "V4" trial is unlocked after
    completing three sub-trials for a given race. This module
    surfaces the trial list and CFrame of the trial-giver NPC.

    Public API:
        V4Trial.new(data) -> V4Trial
        V4Trial:list()     -> { race }
        V4Trial:data(race) -> { Trial1, Trial2, Trial3, CFrame } | nil
        V4Trial:trials(race) -> { trial1, trial2, trial3 }
        V4Trial:isComplete(race) -> bool   -- best-effort: requires PlayerGui inspection
]]

local V4Trial = {}
V4Trial.__index = V4Trial

function V4Trial.new(data)
    local self = setmetatable({}, V4Trial)
    self._data = data
    return self
end

function V4Trial:list()
    local t = self._data and self._data:get("race_v4")
    if not t then return {} end
    local out = {}
    for race, _ in pairs(t) do out[#out + 1] = race end
    table.sort(out)
    return out
end

function V4Trial:data(race)
    local t = self._data and self._data:get("race_v4")
    return t and t[race] or nil
end

function V4Trial:trials(race)
    local e = self:data(race)
    if not e then return {} end
    return { e.Trial1, e.Trial2, e.Trial3 }
end

-- Best-effort completion check: looks in the player's PlayerGui
-- for a "V4Status" or "V4Trials" frame. Returns false on miss
-- (the user will need to verify manually).
function V4Trial:isComplete(race)
    -- The actual UI is not modelled in our data; we return nil
    -- to mean "unknown" so the caller can treat it as in-progress.
    return nil
end

return V4Trial
