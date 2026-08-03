-- GAG2 Dev Tools (standalone)
-- Load this alongside the main script for debugging features.
-- Dependencies: the main GAG2 script must be running (shares DebugLogOn flag).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local client = Players.LocalPlayer

local function simpleNotify(title, msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = msg, Duration = 5,
        })
    end)
end

-- read the main script's DebugLogOn (set via main UI toggle)
local ScriptContext = getgc and (function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and v.DebugLogOn ~= nil then
            return v
        end
    end
end)() or nil

local DebugLogOn = ScriptContext and ScriptContext.DebugLogOn ~= false

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GAG2DevTools"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = client:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 280, 0, 200)
Frame.Position = UDim2.new(1, -290, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", Frame)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "GAG2 Dev Tools"
Title.TextColor3 = Color3.fromRGB(200, 200, 210)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = Frame

local function makeButton(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 28)
    btn.Position = UDim2.new(0, 8, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = Frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return btn
end

makeButton("Dump Debug Log", 38, function()
    if not writefile then
        simpleNotify("Dev", "writefile not available")
        return
    end
    local ok, err = pcall(function()
        writefile("gag2_debug_log_manual.txt", "manual dump " .. os.date())
    end)
    simpleNotify("Dev", ok and "Log dumped" or ("Failed: " .. tostring(err)))
end)

makeButton("Dump Packet Names", 72, function()
    local pk = ReplicatedStorage and ReplicatedStorage:FindFirstChild("SharedModules")
        and ReplicatedStorage.SharedModules:FindFirstChild("Packet")
    local ev = pk and pk:FindFirstChild("RemoteEvent")
    if not (ev and ev.GetAttributes) then
        simpleNotify("Dev", "Packet module not found")
        return
    end
    local lines = {}
    for name, id in pairs(ev:GetAttributes()) do
        if type(name) == "string" then
            lines[#lines + 1] = string.format("[%s] id=%s", name, tostring(id))
        end
    end
    table.sort(lines)
    local text = table.concat(lines, "\n")
    for _, line in ipairs(lines) do print("[GAG2] " .. line) end
    if writefile then
        pcall(function()
            writefile("gag2_packets.txt", text)
        end)
    end
    simpleNotify("Dev", #lines .. " packet IDs dumped")
end)

makeButton("Toggle Debug Logging", 106, function()
    if ScriptContext then
        ScriptContext.DebugLogOn = not (ScriptContext.DebugLogOn ~= false)
        DebugLogOn = ScriptContext.DebugLogOn ~= false
    else
        DebugLogOn = not DebugLogOn
    end
    simpleNotify("Dev", "DebugLog: " .. (DebugLogOn and "ON" or "OFF"))
end)

makeButton("Close", 140, function()
    ScreenGui:Destroy()
end)
