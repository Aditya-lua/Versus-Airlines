--[[
    Versus-Airlines :: game/mob
    ----------------------------
    Mob scanner. Finds the closest live mob matching a name in
    Workspace.Enemies (Blox Fruits convention).

    Public API:
        Mob.new(services)              -> Mob
        Mob:find(name)                 -> Model | nil
        Mob:findClosest()              -> Model | nil   -- any live mob
        Mob:isAlive(model)             -> bool
        Mob:position(model)            -> Vector3
        Mob:count(name)                 -> int   -- live mob count
]]

local Mob = {}
Mob.__index = Mob

local ENEMY_PARENT = "Enemies"
local HUMAN_PROP   = "Humanoid"
local ROOT_PROP    = "HumanoidRootPart"

function Mob.new(services)
    local self = setmetatable({}, Mob)
    self._services = services
    return self
end

function Mob:_root()
    local p = self._services:get("Players").LocalPlayer
    if not p then return nil end
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart") or nil
end

function Mob:_enemies()
    local ws = self._services:get("Workspace")
    if not ws then return {} end
    return ws:FindFirstChild(ENEMY_PARENT) or {}
end

function Mob:isAlive(model)
    if not model then return false end
    local hum = model:FindFirstChild(HUMAN_PROP) or model:FindFirstChildWhichIsA(HUMAN_PROP)
    return hum and hum.Health > 0
end

function Mob:position(model)
    if not model then return Vector3.new(0, 0, 0) end
    local p = model:FindFirstChild(ROOT_PROP)
    if p then return p.Position end
    return model:GetPivot().Position
end

function Mob:find(name)
    if type(name) ~= "string" or name == "" then return nil end
    for _, v in ipairs(self:_enemies():GetChildren()) do
        if v.Name == name and self:isAlive(v) then
            return v
        end
    end
    return nil
end

function Mob:findClosest()
    local root = self:_root()
    if not root then return nil end
    local closest, dist = nil, math.huge
    for _, v in ipairs(self:_enemies():GetChildren()) do
        if self:isAlive(v) then
            local d = (root.Position - self:position(v)).Magnitude
            if d < dist then
                closest, dist = v, d
            end
        end
    end
    return closest
end

function Mob:count(name)
    local n = 0
    for _, v in ipairs(self:_enemies():GetChildren()) do
        if v.Name == name and self:isAlive(v) then
            n = n + 1
        end
    end
    return n
end

return Mob
