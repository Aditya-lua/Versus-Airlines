--[[
    Versus-Airlines :: game/combat
    ------------------------------
    Combat primitives. Equips a weapon, attacks a target.

    Public API:
        Combat.new(services, stealth)  -> Combat
        Combat:equip(weaponType)       -> bool   -- "Melee" | "Sword" | "Blox Fruit" | "Gun"
        Combat:attack(target)           -> bool
        Combat:isAlive(target)          -> bool
]]

local Combat = {}
Combat.__index = Combat

function Combat.new(services, stealth)
    local self = setmetatable({}, Combat)
    self._services = services
    self._stealth  = stealth
    return self
end

function Combat:_root()
    local p = self._services:get("Players").LocalPlayer
    if not p then return nil end
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart") or nil
end

function Combat:isAlive(target)
    if not target then return false end
    local hum = target:FindFirstChild("Humanoid") or target:FindFirstChildWhichIsA("Humanoid")
    return hum and hum.Health > 0
end

-- Equip a tool from Backpack that matches the weapon type. If no
-- match, equip the first available tool.
function Combat:equip(weaponType)
    local Players = self._services:get("Players")
    local p = Players and Players.LocalPlayer
    if not p then return false end
    local backpack = p:FindFirstChild("Backpack")
    local character = p.Character
    if not (backpack and character) then return false end
    local hum = character:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end

    local choice
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") then
            local tip = t.ToolTip or ""
            if weaponType == "Melee"      and (tip:find("Melee") or t:FindFirstChild("Melee")) then choice = t; break end
            if weaponType == "Sword"      and (tip:find("Sword") or t:FindFirstChild("Handle")) then choice = t; break end
            if weaponType == "Blox Fruit" and (tip:find("Fruit") or t:FindFirstChild("Fruit")) then choice = t; break end
            if weaponType == "Gun"        and (tip:find("Gun") or t:FindFirstChild("Gun")) then choice = t; break end
        end
    end
    if not choice then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then choice = t; break end
        end
    end
    if choice then
        pcall(function() hum:EquipTool(choice) end)
        return true
    end
    return false
end

-- Attack: equip best weapon, click. No actual combat math — this is
-- a thin wrapper. The real "do damage" happens client-side when the
-- tool is activated and the server validates.
function Combat:attack(target)
    if not self:isAlive(target) then return false end
    local Players = self._services:get("Players")
    local VirtualUser = self._services:get("VirtualUser")
    if Players and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new())
        end)
    end
    return true
end

return Combat
