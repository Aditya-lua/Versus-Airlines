--[[
    Versus-Airlines :: game/teleport
    ----------------------------------
    Teleport to a named island (uses kernel.data:get("islands"))
    or to arbitrary Vector3 / CFrame / Instance targets.

    Public API:
        Teleport.new(services, movement, data) -> Teleport
        Teleport:island(name)                   -> bool
        Teleport:to(target)                     -> bool
        Teleport:islands()                      -> { name }   -- sorted
        Teleport:data(name)                     -> CFrame | nil
]]

local Teleport = {}
Teleport.__index = Teleport

function Teleport.new(services, movement, data)
    local self = setmetatable({}, Teleport)
    self._services = services
    self._movement = movement
    self._data     = data
    return self
end

function Teleport:islands()
    local t = self._data and self._data:get("islands")
    if not t then return {} end
    local out = {}
    for name, _ in pairs(t) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Teleport:data(name)
    local t = self._data and self._data:get("islands")
    return t and t[name] or nil
end

-- Teleport to a target: name (island), CFrame, Vector3, or Instance.
function Teleport:to(target)
    if type(target) == "string" then
        return self:island(target)
    end
    if not self._movement then return false end
    if type(target) == "table" and target.X then
        return self._movement:tween(target)
    end
    if type(target) == "table" and target.Position then
        return self._movement:tween(target)
    end
    return false
end

-- Teleport to a named island. The CFrame is looked up in the
-- islands data table. Returns true on a successful tween start.
function Teleport:island(name)
    if type(name) ~= "string" or name == "" then return false end
    local cf = self:data(name)
    if not cf then return false end
    if not self._movement then return false end
    return self._movement:tween(cf)
end

return Teleport
