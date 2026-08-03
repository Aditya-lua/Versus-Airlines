--[[
    Versus-Airlines :: game/esp
    ----------------------------
    ESP (extra-sensory perception). Renders labels above Players,
    Mobs, and Fruit drops. Two render backends:
        T1 (canDrawing)  -> Roblox Drawing library (text + boxes).
        T2 (no Drawing)  -> BillboardGui with TextLabel.
    The active backend is picked at construction; the user does not
    choose.

    Public API:
        Esp.new(services, compat)            -> Esp
        Esp:render(visible)                   -> int   -- count drawn
        Esp:clear()                           -> nil
        Esp:isDrawing()                       -> bool
        Esp:setMaxDistance(studs)            -> nil
]]

local Esp = {}
Esp.__index = Esp

function Esp.new(services, compat)
    local self = setmetatable({}, Esp)
    self._services   = services
    self._compat     = compat or {}
    self._drawings   = {}   -- { name = { text, ... } }
    self._billboards = {}   -- { name = BillboardGui }
    self._maxDist    = 1000
    self._useDraw    = compat and compat.canDrawing
    return self
end

function Esp:isDrawing()        return self._useDraw == true end
function Esp:setMaxDistance(d)  if type(d) == "number" and d > 0 then self._maxDist = d end end
function Esp:maxDistance()      return self._maxDist end

-- Pick a colour per kind. Cool palette, no clashing.
local COLORS = {
    player = Color3 and Color3.new(0.2, 0.6, 1.0)  or { 0.2, 0.6, 1.0 },
    mob    = Color3 and Color3.new(1.0, 0.3, 0.3)  or { 1.0, 0.3, 0.3 },
    fruit  = Color3 and Color3.new(0.3, 1.0, 0.4)  or { 0.3, 1.0, 0.4 },
}

-- Drawing-based label (T1).
local function newDrawingText(text, color, position)
    local ok, d = pcall(function()
        if not Drawing then return nil end
        local t = Drawing.new("Text")
        t.Text        = text
        t.Color       = color
        t.Outline     = true
        t.OutlineColor = Color3 and Color3.new(0, 0, 0) or { 0, 0, 0 }
        t.Size        = 18
        t.Font        = 2   -- Drawing.Fonts.UI
        t.Visible     = false
        t.Position    = position or Vector2 and Vector2.new(0, 0) or { 0, 0 }
        return t
    end)
    if not ok then return nil end
    return d
end

-- BillboardGui-based label (T2 fallback).
local function newBillboard(parent, text, color, name)
    if not parent or not parent.FindFirstChild then return nil end
    local ok, bg = pcall(function()
        local g = Instance.new("BillboardGui")
        g.Name            = "VersusESP_" .. (name or "label")
        g.Adornee         = nil
        g.Size            = UDim2 and UDim2.new(0, 200, 0, 50) or { 0, 200, 0, 50 }
        g.StudsOffset     = Vector3 and Vector3.new(0, 2, 0) or { 0, 2, 0 }
        g.AlwaysOnTop     = true
        g.Parent          = parent
        local l = Instance.new("TextLabel")
        l.Size            = UDim2 and UDim2.new(1, 0, 1, 0) or { 1, 0, 1, 0 }
        l.BackgroundTransparency = 1
        l.TextColor3      = color
        l.TextStrokeTransparency = 0
        l.Text            = text
        l.Font            = 2
        l.TextScaled      = true
        l.Parent          = g
        return g
    end)
    if not ok then return nil end
    return bg
end

-- World-to-screen helper. Returns Vector2-like {x,y} or nil.
local function worldToScreen(camera, worldPos)
    if not camera or not worldPos then return nil end
    local ok, sx, sy = pcall(function()
        local v, onScreen = camera:WorldToScreenPoint(worldPos)
        if v and v.X then return v.X, v.Y end
        return nil, nil
    end)
    if not ok or not sx then return nil end
    return { x = sx, y = sy }
end

-- Render one entry. kind is "player" | "mob" | "fruit".
-- The caller already filtered by distance and kind.
function Esp:_renderOne(kind, label, worldPos, screen)
    if not screen then return end
    if self._useDraw then
        local d = self._drawings[label]
        if not d then
            d = newDrawingText(label, COLORS[kind] or COLORS.player, screen)
            self._drawings[label] = d
        end
        if d then
            d.Position = screen
            d.Visible  = true
        end
    else
        local bg = self._billboards[label]
        if not bg then
            local camera = self._services:get("Workspace").CurrentCamera
            local parent = camera and camera:FindFirstChild("ESPParent") or nil
            if not parent and camera then
                local ok, p = pcall(function()
                    local f = Instance.new("Folder")
                    f.Name = "ESPParent"
                    f.Parent = camera
                    return f
                end)
                if ok then parent = p end
            end
            bg = newBillboard(parent, label, COLORS[kind] or COLORS.player, label)
            self._billboards[label] = bg
        end
        if bg and bg.Adornee ~= nil then
            -- BillboardGui position is set by the Adornee.
        end
    end
end

-- Clear all drawings/billboards (used on toggle-off).
function Esp:clear()
    for _, d in pairs(self._drawings) do
        pcall(function() d.Visible = false end)
    end
    for _, bg in pairs(self._billboards) do
        pcall(function() bg:Destroy() end)
    end
    self._billboards = {}
end

-- Render a list of visible entries. Each entry is a table with
-- { kind, label, position }. Returns the count actually drawn.
function Esp:render(visible)
    if type(visible) ~= "table" then return 0 end
    local n = 0
    local camera = self._services:get("Workspace").CurrentCamera
    if not camera then return 0 end
    local root = self._services:get("Players").LocalPlayer.Character
              and self._services:get("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for _, e in ipairs(visible) do
        if e and e.position and e.label and e.kind then
            local d = root and (root.Position - e.position).Magnitude or 0
            if d <= self._maxDist then
                local s = worldToScreen(camera, e.position)
                if s then
                    self:_renderOne(e.kind, e.label, e.position, s)
                    n = n + 1
                end
            end
        end
    end
    return n
end

return Esp
