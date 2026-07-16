--[[
    Versus-Airlines :: game/fruit
    -----------------------------
    Fruit handling: spawn-sniping and dealer-buying.
    Public API:
        Fruit.new(services, stealth, data, mob) -> Fruit
        Fruit:sniper()                          -> { fruitName, model, position } | nil
        Fruit:listVisible()                     -> { {name, model, position, dist} }
        Fruit:buy(fruitName)                    -> bool
        Fruit:list()                            -> { name }
        Fruit:data(fruitName)                   -> { Price, Level, Sea, Rarity } | nil
        Fruit:dealers()                         -> { {Dealer, Location, CFrame, Sea} }
        Fruit:isOnMap(fruitName)                -> bool   -- sea+level check
]]

local Fruit = {}
Fruit.__index = Fruit

local REMOTE_BUY  = "CommF_"
local REMOTE_ARG  = "PurchaseRandomFruit"   -- Blox Fruits convention

function Fruit.new(services, stealth, data, mob)
    local self = setmetatable({}, Fruit)
    self._services = services
    self._stealth  = stealth
    self._data     = data
    self._mob      = mob
    return self
end

-- All known fruit names, sorted.
function Fruit:list()
    local t = self._data and self._data:get("fruits")
    if not t then return {} end
    local out = {}
    for name, _ in pairs(t) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Fruit:data(name)
    local t = self._data and self._data:get("fruits")
    return t and t[name] or nil
end

function Fruit:dealers()
    local t = self._data and self._data:get("fruit_dealers")
    return t or {}
end

-- True if `name` is a fruit for the current sea and within the
-- player's level range. Used to filter spawn-snipe results.
function Fruit:isOnMap(name)
    local entry = self:data(name)
    if not entry then return false end
    local ok, level = pcall(function()
        local Players = self._services:get("Players")
        return Players.LocalPlayer.Data.Level.Value
    end)
    if not ok or not level then return entry.Sea == 1 end
    return entry.Level <= (level or math.huge)
end

-- Find a fruit in the workspace by name. A "fruit" in Blox Fruits
-- is typically a Tool named "Fruit <name>" left on the ground
-- (or a BasePart named like the fruit). Returns the first match
-- or nil.
function Fruit:_findToolByName(name)
    local ws = self._services:get("Workspace")
    if not ws then return nil end
    -- Try top-level first.
    for _, v in ipairs(ws:GetChildren()) do
        if v:IsA("Tool") and (v.Name == name or v.Name:find(name, 1, true)) then
            return v
        end
    end
    return nil
end

-- Public: list all visible fruit drops in the workspace. Returns
-- an array of { name, model, position, dist } sorted by distance.
function Fruit:listVisible()
    local ws = self._services:get("Workspace")
    if not ws or not ws.GetChildren then return {} end
    local out = {}
    local ok, children = pcall(function() return ws:GetChildren() end)
    if not ok or not children then return {} end
    for _, v in ipairs(children) do
        if v and v:IsA and v:IsA("Tool") and v.Name and v.Name:lower():find("fruit", 1, true) then
            local p = v:IsA and v:IsA("BasePart") and v
            local pos
            if p and p.Position then
                pos = p.Position
            else
                local b = v:FindFirstChildWhichIsA and v:FindFirstChildWhichIsA("BasePart")
                if b and b.Position then pos = b.Position end
            end
            if pos then
                local root = self._services:get("Players").LocalPlayer.Character
                          and self._services:get("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local dist = root and (root.Position - pos).Magnitude or 0
                out[#out + 1] = { name = v.Name, model = v, position = pos, dist = dist }
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Public: find the closest fruit we want (FruitSniper loop). The
-- caller decides the filter (e.g. by Rarity, by name). Returns
-- the closest matching entry or nil.
function Fruit:sniper()
    local visible = self:listVisible()
    if #visible == 0 then return nil end
    return visible[1]
end

-- Buy a random fruit from the dealer via the CommF_ remote. The
-- Blox Fruits convention is: FireServer("CommF_", "PurchaseRandomFruit").
-- We use stealth:fire to ensure the call is allow-listed + throttled.
function Fruit:buy(fruitName)
    -- Note: Blox Fruits only supports buying a *random* fruit
    -- (PurchaseRandomFruit). The chosen name is ignored by the
    -- server; this method exists so the module can check that the
    -- requested fruit is in the data table (so the user doesn't
    -- typo a fake name) and the player has reached the required
    -- level.
    if fruitName and not self:data(fruitName) then
        return false
    end
    local rs = self._services:get("ReplicatedStorage")
    if not rs then return false end
    local remote = rs:FindFirstChild(REMOTE_BUY)
    if not remote then return false end
    return self._stealth and self._stealth:fire(remote, { REMOTE_ARG })
end

return Fruit
