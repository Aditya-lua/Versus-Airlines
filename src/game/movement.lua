--[[
    Versus-Airlines :: game/movement
    ----------------------------------
    Movement primitives. Three modes:
        BTP(target)        — health-zero teleport for long distances.
        TweenTP(target)    — TweenService for mid-range.
        walk(target, dist) — Humanoid:MoveTo for short range.
    Plus:
        isStuck()          — true if the player hasn't moved in
                             STUCK_TIMEOUT_SEC.
        unstick()          — small random offset, then retry.

    Public API:
        Movement.new(services, stealth)  -> Movement
        Movement:btp(target)              -> bool
        Movement:tween(target)            -> bool
        Movement:walk(target)             -> bool
        Movement:moveTo(target)           -> bool   (auto-selects mode by distance)
        Movement:isStuck()                -> bool
        Movement:unstick()                -> nil
        Movement:pos()                    -> Vector3
        Movement:onMoved(callback, tag?)   -> rbxConn
]]

local Movement = {}
Movement.__index = Movement

local BTP_MIN_DISTANCE       = 2000   -- beyond this, BTP
local TWEEN_MIN_DISTANCE     = 100    -- beyond this, tween
local STUCK_TIMEOUT_SEC      = 5.0
local STUCK_MIN_DISTANCE     = 3.0    -- if moved less than this in timeout, stuck
local TWEEN_SPEED_DEFAULT    = 300    -- studs/sec
local BTP_RESPAWN_WAIT_SEC   = 1.5

function Movement.new(services, stealth, conn)
    local self = setmetatable({}, Movement)
    self._services = services
    self._stealth  = stealth
    self._conn     = conn    -- optional; only needed for onMoved()
    self._lastPos   = nil
    self._lastT     = nil
    return self
end

function Movement:_root()
    local char = self._services:get("Players").LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

function Movement:_humanoid()
    local char = self._services:get("Players").LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Humanoid")
end

function Movement:pos()
    local root = self:_root()
    if not root then return Vector3.new(0, 0, 0) end
    return root.Position
end

-- Convert a target to a Vector3 if it's a CFrame, BasePart, or Model.
function Movement:_toVec3(target)
    if typeof(target) == "Vector3" then return target end
    if typeof(target) == "CFrame" then return target.Position end
    if typeof(target) == "Instance" then
        if target:IsA("BasePart") then return target.Position end
        if target:IsA("Model") then
            local p = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
            if p then return p.Position end
        end
    end
    return nil
end

-- BTP: health-zero teleport. For distances > BTP_MIN_DISTANCE.
function Movement:btp(target)
    local dest = self:_toVec3(target)
    local hum  = self:_humanoid()
    local root = self:_root()
    if not (dest and hum and root) then return false end

    if (root.Position - dest).Magnitude < BTP_MIN_DISTANCE then
        return self:tween(target)
    end

    hum.Health = 0
    -- Wait for respawn (max 5s).
    local t0 = os.clock()
    while os.clock() - t0 < 5 do
        if self:_root() and (self:_root().Position - dest).Magnitude < 50 then break end
        if task and task.wait then task.wait(0.2) end
    end
    -- After respawn, tween to the actual target.
    return self:tween(target)
end

-- Tween: for mid-range. Uses TweenService if available; falls back
-- to Humanoid:MoveTo.
function Movement:tween(target)
    local dest = self:_toVec3(target)
    local root = self:_root()
    if not (dest and root) then return false end

    local TweenService = self._services:get("TweenService")
    if TweenService then
        local dist = (root.Position - dest).Magnitude
        local info = TweenInfo.new(dist / TWEEN_SPEED_DEFAULT, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(root, info, { CFrame = CFrame.new(dest) })
        tween:Play()
        -- Poll for arrival. task.wait keeps the heartbeat running
        -- and is the canonical way to wait for a tween in Luau
        -- (no connection needed).
        local deadline = os.clock() + (dist / TWEEN_SPEED_DEFAULT + 2)
        while os.clock() < deadline do
            if (root.Position - dest).Magnitude < 5 then
                return true
            end
            if task and task.wait then task.wait(0.1) end
        end
        return (root.Position - dest).Magnitude < 5
    end

    return self:walk(target)
end

-- Walk: Humanoid:MoveTo for short range.
function Movement:walk(target)
    local dest = self:_toVec3(target)
    local hum  = self:_humanoid()
    if not (dest and hum) then return false end
    hum:MoveTo(dest)
    return true
end

-- moveTo: auto-select btp/tween/walk by distance.
function Movement:moveTo(target)
    local dest = self:_toVec3(target)
    local root = self:_root()
    if not (dest and root) then return false end
    local dist = (root.Position - dest).Magnitude
    if dist > BTP_MIN_DISTANCE then
        return self:btp(target)
    elseif dist > TWEEN_MIN_DISTANCE then
        return self:tween(target)
    else
        return self:walk(target)
    end
end

function Movement:isStuck()
    local root = self:_root()
    if not root then return false end
    local pos = root.Position
    local now = os.clock()
    if self._lastPos and self._lastT then
        if (now - self._lastT) > STUCK_TIMEOUT_SEC then
            local moved = (pos - self._lastPos).Magnitude
            self._lastPos = pos
            self._lastT  = now
            return moved < STUCK_MIN_DISTANCE
        end
    end
    self._lastPos = pos
    self._lastT  = now
    return false
end

function Movement:unstick()
    local root = self:_root()
    if not root then return end
    local offset = Vector3.new(math.random(-30, 30), 0, math.random(-30, 30))
    root.CFrame = root.CFrame + offset
    if task and task.wait then task.wait(0.3) end
end

-- Subscribe to per-frame movement tracking. Used by modules that
-- need a "player moved" signal (e.g. ESP, anti-stuck watchdog).
-- Returns the connection (caller can disconnect) or nil.
function Movement:onMoved(callback, tag)
    if not self._conn then return nil end
    local lastPos = self:pos()
    return self._conn:bindHeartbeat(function()
        local p = self:pos()
        if (p - lastPos).Magnitude > 1 then
            lastPos = p
            pcall(function() callback(p) end)
        end
    end, tag or "movement:onMoved")
end

return Movement
