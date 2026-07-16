--[[
    Versus-Airlines :: game/sea_event
    ----------------------------------
    Sea event detection + auto-farm driver. Blox Fruits occasionally
    spawns a "sea event" (Ghost Ship, Sea Beast, etc.) which is a
    rare NPC that drops valuable items. This module finds the event
    spawn in the workspace and (when active) tweens to it.

    Public API:
        SeaEvent.new(services, mob, data) -> SeaEvent
        SeaEvent:list()                     -> { name }
        SeaEvent:find(name)                 -> Model | nil
        SeaEvent:findAny()                  -> { name, model } | nil
        SeaEvent:isActive(name)             -> bool
]]

local SeaEvent = {}
SeaEvent.__index = SeaEvent

function SeaEvent.new(services, mob, data)
    local self = setmetatable({}, SeaEvent)
    self._services = services
    self._mob      = mob
    self._data     = data
    return self
end

function SeaEvent:list()
    local t = self._data and self._data:get("sea_events")
    if not t then return {} end
    local out = {}
    for i, v in ipairs(t) do out[#out + 1] = v end
    return out
end

-- True if a sea event of `name` is currently spawned and alive in
-- the workspace. We look for the model under common parents.
function SeaEvent:isActive(name)
    return self:find(name) ~= nil
end

-- Find the model of a sea event. Sea events typically live in
-- Workspace (root or under map-specific parents); we walk top
-- level and a few known containers.
function SeaEvent:find(name)
    if type(name) ~= "string" or name == "" then return nil end
    local ws = self._services:get("Workspace")
    if type(ws) ~= "table" then return nil end
    if type(ws.GetChildren) ~= "function" then return nil end
    local ok, children = pcall(function() return ws:GetChildren() end)
    if not ok or type(children) ~= "table" then return nil end
    -- Top-level.
    for _, v in ipairs(children) do
        if type(v) == "table" and v.Name == name and self._mob and self._mob:isAlive(v) then
            return v
        end
    end
    return nil
end

-- Find any active sea event. Returns the first one we see, or nil.
function SeaEvent:findAny()
    for _, name in ipairs(self:list()) do
        local m = self:find(name)
        if m then return { name = name, model = m } end
    end
    return nil
end

return SeaEvent
