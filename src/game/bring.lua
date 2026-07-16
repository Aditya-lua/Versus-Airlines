--[[
    Versus-Airlines :: game/bring
    -----------------------------
    Bring mobs to the player. Used by the autofarm-bring module to
    keep the player stationary while still farming. The mechanic
    is simple: every N ticks, find all live mobs within
    BRING_RADIUS studs and snap their HumanoidRootPart to a position
    in front of the player.

    Public API:
        Bring.new(services, mob)  -> Bring
        Bring:tick(targetName, radius) -> int   -- returns count moved
]]

local Bring = {}
Bring.__index = Bring

local BRING_RADIUS_DEFAULT = 150
local BRING_OFFSET         = Vector3.new(0, 0, -8)  -- in front of the player

function Bring.new(services, mob)
    local self = setmetatable({}, Bring)
    self._services = services
    self._mob      = mob
    return self
end

function Bring:_root()
    local p = self._services:get("Players").LocalPlayer
    if not p or not p.Character then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart")
end

function Bring:_enemies()
    local ws = self._services:get("Workspace")
    if not ws then return {} end
    return ws:FindFirstChild("Enemies") or {}
end

-- Pull every live mob within `radius` studs to BRING_OFFSET from
-- the player. Returns the number of mobs moved.
function Bring:tick(targetName, radius)
    local root = self:_root()
    if not root then return 0 end
    radius = radius or BRING_RADIUS_DEFAULT
    local moved = 0
    for _, v in ipairs(self:_enemies():GetChildren()) do
        if self._mob:isAlive(v) then
            if not targetName or v.Name == targetName then
                local p = v:FindFirstChild("HumanoidRootPart")
                if p then
                    local d = (root.Position - p.Position).Magnitude
                    if d <= radius then
                        pcall(function()
                            p.CFrame = root.CFrame * CFrame.new(BRING_OFFSET)
                        end)
                        moved = moved + 1
                    end
                end
            end
        end
    end
    return moved
end

return Bring
