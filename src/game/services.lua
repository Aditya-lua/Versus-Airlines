--[[
    Versus-Airlines :: game/services
    ----------------------------------
    Single local cache of every Roblox service the script uses.

    Public API:
        Services.new()                 -> Services
        Services:get(name)             -> service
        Services:has(name)             -> bool
        Services:list()                -> { name }
        Services:init()                -> nil
        Services:reset()               -> nil
]]

local Services = {}
Services.__index = Services

local SERVICE_NAMES = {
    "Players", "ReplicatedStorage", "Workspace", "TweenService",
    "HttpService", "RunService", "UserInputService", "Lighting",
    "VirtualUser", "CoreGui", "MarketplaceService", "TeleportService",
    "Debris", "ContextActionService", "StarterGui", "InsertService",
    "Chat", "Teams", "CollectionService", "LogService", "Stats",
    "PolicyService", "GuiService",
}

function Services.new()
    local self = setmetatable({}, Services)
    self._cache   = {}
    self._touched = {}
    return self
end

function Services:get(name)
    if type(name) ~= "string" or name == "" then return nil end
    self._touched[name] = true
    if self._cache[name] ~= nil then return self._cache[name] end
    local ok, svc = pcall(function() return game:GetService(name) end)
    if not ok or svc == nil then return nil end
    self._cache[name] = svc
    return svc
end

function Services:has(name)
    return self._cache[name] ~= nil
end

function Services:list()
    local out = {}
    for name, _ in pairs(self._touched) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Services:init()
    for _, name in ipairs(SERVICE_NAMES) do self:get(name) end
end

function Services:reset()
    self._cache = {}
    self._touched = {}
end

return Services
