--[[
    Versus-Airlines :: game/mastery
    --------------------------------
    Weapon mastery grinding. The mastery of a weapon is increased
    by hitting mobs with it; the player is the bottleneck. This
    module equips a chosen weapon category and (with the autofarm
    already running) lets hits accumulate. It does not fire any
    remotes itself; the equip just routes through Combat.

    Public API:
        Mastery.new(services, data, combat) -> Mastery
        Mastery:categories()                 -> { "Melee", "Sword", "Blox Fruit", "Gun" }
        Mastery:read(category)               -> { level, exp, max } | nil
        Mastery:readAll()                    -> { category = { ... }, ... }
        Mastery:equip(category)              -> bool
        Mastery:target()                     -> string | nil   -- category from flags
]]

local Mastery = {}
Mastery.__index = Mastery

local CATEGORIES = { "Melee", "Sword", "Blox Fruit", "Gun" }

function Mastery.new(services, data, combat)
    local self = setmetatable({}, Mastery)
    self._services = services
    self._data     = data
    self._combat   = combat
    return self
end

function Mastery:categories() return CATEGORIES end

function Mastery:_node(category)
    local Players = self._services:get("Players")
    if not Players then return nil end
    local p = Players.LocalPlayer
    if not p or not p.FindFirstChild or not p:FindFirstChild("Data") then return nil end
    -- The mastery node is conventionally under Data.<Category>Mastery
    -- (e.g. Data.MeleeMastery, Data.SwordMastery).
    local node = p.Data:FindFirstChild(category .. "Mastery")
    if not node or not node.FindFirstChild then return nil end
    return node
end

function Mastery:read(category)
    if type(category) ~= "string" then return nil end
    local n = self:_node(category)
    if not n then return nil end
    local function safe(node, name)
        if not node or not node.FindFirstChild then return nil end
        return node:FindFirstChild(name)
    end
    local level = safe(n, "Level")
    local exp   = safe(n, "Exp") or safe(n, "Experience")
    local max   = safe(n, "MaxExp") or safe(n, "MaxExperience")
    return {
        level = level and level.Value or 0,
        exp   = exp   and exp.Value   or 0,
        max   = max   and max.Value   or 0,
    }
end

function Mastery:readAll()
    local out = {}
    for _, cat in ipairs(CATEGORIES) do
        out[cat] = self:read(cat)
    end
    return out
end

-- Equip the chosen weapon category. The Combat.equip() helper
-- already inspects the Backpack, so this is a thin wrapper.
function Mastery:equip(category)
    if not self._combat then return false end
    return self._combat:equip(category)
end

return Mastery
