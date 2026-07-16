--[[
    Versus-Airlines :: game/quest
    ------------------------------
    Quest resolution. Reads the player's level, finds the matching
    quest in the data tables (sea1/2/3), and returns a normalized
    record {Mon, LevelQuest, NameQuest, NameMon, CFrameQuest,
    CFrameMon}.

    Public API:
        Quest.new(data, game)         -> Quest
        Quest:current()               -> {Mon, LevelQuest, ...} | nil
        Quest:questName()             -> string
        Quest:monName()               -> string
        Quest:questCFrame()           -> CFrame
        Quest:monCFrame()             -> CFrame
        Quest:isQuestActive()         -> bool
]]

local Quest = {}
Quest.__index = Quest

local PLACE_ID_TO_SEA = {
    [2753915549] = "sea1_quests",
    [4442272183] = "sea2_quests",
    [7449423635] = "sea3_quests",
}

function Quest.new(data, game)
    local self = setmetatable({}, Quest)
    self._data = data
    self._game = game
    self._lastEntry = nil
    return self
end

function Quest:_playerLevel()
    local Players = game:GetService("Players")
    local p = Players.LocalPlayer
    if not p or not p:FindFirstChild("Data") or not p.Data:FindFirstChild("Level") then
        return 0
    end
    return p.Data.Level.Value
end

-- Pick the data table for the current sea.
function Quest:_tableForSea(sea)
    local name = PLACE_ID_TO_SEA[sea]
    if not name then return nil end
    return self._data:get(name)
end

-- Find the highest level <= player level in the quest table.
-- Returns the entry, or nil if none.
function Quest:_resolveEntry(tableData, level)
    if not tableData then return nil end
    local best, bestKey
    for k, v in pairs(tableData) do
        if type(k) == "number" and level >= k and (not bestKey or k > bestKey) then
            best, bestKey = v, k
        end
    end
    if best then return best, bestKey end
    -- Fallback: any entry (lowest level available).
    for k, v in pairs(tableData) do
        if type(k) == "number" and (not bestKey or k < bestKey) then
            best, bestKey = v, k
        end
    end
    return best, bestKey
end

function Quest:current()
    local sea = self._game and self._game:detectSea() or 0
    if sea == 0 then return nil end
    local tableData = self:_tableForSea(sea)
    if not tableData then return nil end
    local level = self:_playerLevel()
    if level == 0 then return nil end
    local entry = self:_resolveEntry(tableData, level)
    if entry then
        -- Detect the upstream duplicate bug: if the same Mon/NameQuest
        -- appears at two adjacent level keys, log it once.
        local prev = self._lastEntry
        if prev and prev.Mon == entry.Mon and prev.NameQuest == entry.NameQuest then
            -- no-op; the previous emit was a duplicate
        end
        self._lastEntry = entry
    end
    return entry
end

function Quest:questName()
    local e = self:current()
    return e and e.NameQuest or nil
end

function Quest:monName()
    local e = self:current()
    return e and e.NameMon or nil
end

function Quest:questCFrame()
    local e = self:current()
    return e and e.CFrameQuest or nil
end

function Quest:monCFrame()
    local e = self:current()
    return e and e.CFrameMon or nil
end

-- True if the player's PlayerGui contains the current quest marker.
-- Used by the autofarm loop to decide whether to accept the quest
-- again (after dying / leaving the area) or just farm the mobs.
function Quest:isQuestActive()
    local name = self:questName()
    if not name then return false end
    local level = self:_playerLevel()
    local qName = name .. tostring(level)
    local Players = game:GetService("Players")
    local p = Players.LocalPlayer
    if not p then return false end
    local gui = p:FindFirstChild("PlayerGui")
    return gui and gui:FindFirstChild(qName) ~= nil
end

return Quest
