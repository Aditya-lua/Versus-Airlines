--[[
    Versus-Airlines :: game/enhance
    ---------------------------------
    Sword enhancement. Reads the player's equipped sword name and
    the enhancement tier, and (when AutoEnhance is on) re-rolls
    the enhancement via CommF_("EnhanceWeapon", ...).

    Public API:
        Enhance.new(services, data, stealth) -> Enhance
        Enhance:equippedSword()                -> string | nil
        Enhance:tier()                        -> int | nil
        Enhance:roll()                        -> bool     -- fires CommF_ stealth
        Enhance:list()                        -> { name }
        Enhance:data(name)                    -> { Level, Sea, ... } | nil
]]

local Enhance = {}
Enhance.__index = Enhance

local REMOTE_NAME = "CommF_"
local REMOTE_ARG  = "EnhanceWeapon"

function Enhance.new(services, data, stealth)
    local self = setmetatable({}, Enhance)
    self._services = services
    self._data     = data
    self._stealth  = stealth
    return self
end

function Enhance:list()
    local t = self._data and self._data:get("swords")
    if not t then return {} end
    local out = {}
    for name, _ in pairs(t) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Enhance:data(name)
    local t = self._data and self._data:get("swords")
    return t and t[name] or nil
end

-- The player's equipped sword (Backpack + Character scan).
function Enhance:equippedSword()
    local Players = self._services:get("Players")
    if not Players then return nil end
    local p = Players.LocalPlayer
    if not p then return nil end
    local function findSword(parent)
        if not parent or not parent.GetChildren then return nil end
        local ok, kids = pcall(function() return parent:GetChildren() end)
        if not ok or type(kids) ~= "table" then return nil end
        for _, v in ipairs(kids) do
            if type(v) == "table" and v.IsA then
                local isTool = v:IsA("Tool")
                if isTool and v:FindFirstChild("BladeMastery") then
                    return v
                end
            end
        end
        return nil
    end
    local char = p.Character
    local r1 = findSword(char)
    if r1 then return r1 end
    if not p.FindFirstChild then return nil end
    return findSword(p:FindFirstChild("Backpack"))
end

-- The current enhancement tier (number, or nil if not found).
function Enhance:tier()
    local sword = self:equippedSword()
    if not sword then return nil end
    local t = sword:FindFirstChild("EnhanceTier") or sword:FindFirstChild("Tier")
    return t and t.Value or nil
end

-- Fire the enhancement roll.
function Enhance:roll()
    local rs = self._services:get("ReplicatedStorage")
    if not rs then return false end
    local remote = rs:FindFirstChild(REMOTE_NAME)
    if not remote then return false end
    if not self._stealth then return false end
    return self._stealth:fire(remote, { REMOTE_ARG })
end

return Enhance
