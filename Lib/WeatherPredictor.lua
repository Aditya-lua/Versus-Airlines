-- Weather Predictor Module for Grow a Garden 2
-- Extracted from main script for better maintainability
-- Uses the game's own TimeCycleData for deterministic weather prediction

local WeatherPredictor = {}

local FALLBACK_PHASES = {
    {
        Name = "Day",
        Lasts = 450,
        Order = 1,
        Weathers = { Day = { Chance = 100, Image = "rbxassetid://100486757307207" } },
    },
    {
        Name = "Sunset",
        Lasts = 30,
        Order = 2,
        Weathers = { Sunset = { Chance = 100, Image = "rbxassetid://86217612022586" } },
    },
    {
        Name = "Night",
        Lasts = 120,
        Order = 3,
        Weathers = {
            Moon = { Chance = 79, Image = "rbxassetid://91446334780160" },
            Bloodmoon = { Chance = 2, Image = "rbxassetid://140465339393451" },
            Goldmoon = { Chance = 13, Image = "rbxassetid://84902063004871" },
            ["Rainbow Moon"] = { Chance = 6, Image = "rbxassetid://93602895495056" },
            ["Mega Moon"] = { Chance = 2, Image = "rbxassetid://107925838920918" },
        },
    },
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local function tryRequire(loader)
    local success, result = pcall(loader)
    return success and result or nil
end

local phases = FALLBACK_PHASES
local cycleLen = 600
local moonGating = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm:FindFirstChild("MoonGating") or sm:WaitForChild("MoonGating", 5))
end)
local tcd = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm:FindFirstChild("TimeCycleData") or sm:WaitForChild("TimeCycleData", 5))
end)
if type(tcd) == "table" and type(tcd.Data) == "table" then
    local built = {}
    for pname, pdata in pairs(tcd.Data) do
        built[#built + 1] = {
            Name = pname,
            Lasts = tonumber(pdata.Lasts) or 60,
            Order = tonumber(pdata.StartOrder) or 99,
            Weathers = pdata.Weathers,
        }
    end
    if #built > 0 then
        table.sort(built, function(a, b)
            return a.Order < b.Order
        end)
        phases = built
    end
end
local total = 0
for _, p in ipairs(phases) do
    total = total + p.Lasts
end
if total > 0 then
    cycleLen = total
end

WeatherPredictor.Phases = phases
WeatherPredictor.Total = cycleLen

local function isSpawnable(wname)
    if type(moonGating) == "table" and type(moonGating.IsNaturallySpawnable) == "function" then
        local ok, res = pcall(moonGating.IsNaturallySpawnable, wname)
        if ok then
            return res == true
        end
    end
    return true
end

local function pickWeather(phase, seed)
    local sum = 0
    for wname, w in pairs(phase.Weathers or {}) do
        if not w.AdminOnly and isSpawnable(wname) then
            sum = sum + (tonumber(w.Chance) or 0)
        end
    end
    if sum <= 0 then
        for wname in pairs(phase.Weathers or {}) do
            return wname
        end
        return phase.Name
    end
    local roll = Random.new(seed):NextNumber() * sum
    local acc = 0
    for wname, w in pairs(phase.Weathers or {}) do
        if not w.AdminOnly and isSpawnable(wname) then
            acc = acc + (tonumber(w.Chance) or 0)
            if roll <= acc then
                return wname
            end
        end
    end
    for wname in pairs(phase.Weathers or {}) do
        return wname
    end
end
WeatherPredictor.pick = pickWeather

WeatherPredictor.atTime = function(t)
    local cycleIdx = math.floor(t / cycleLen)
    local cycleStart = cycleIdx * cycleLen
    local elapsed = t - cycleStart
    local acc = 0
    for idx, p in ipairs(phases) do
        acc = acc + p.Lasts
        if elapsed < acc then
            local pStart = cycleStart + (acc - p.Lasts)
            local pEnd = cycleStart + acc
            return cycleIdx, p, idx, pStart, pEnd, pickWeather(p, cycleIdx * 1000 + idx)
        end
    end
    local lastIdx = #phases
    local pEnd = cycleStart + acc
    return cycleIdx, phases[lastIdx], lastIdx, pEnd - phases[lastIdx].Lasts, pEnd, pickWeather(
        phases[lastIdx],
        cycleIdx * 1000 + lastIdx
    )
end

WeatherPredictor.current = function()
    local now = os.time()
    local cycleIdx, phase, idx, pStart, pEnd, predicted = WeatherPredictor.atTime(now)
    local weather = predicted
    local aw = Workspace:GetAttribute("ActiveWeather")
    if type(aw) == "string" and phase.Weathers and phase.Weathers[aw] then
        weather = aw
    end
    local ap = Workspace:GetAttribute("ActivePhase")
    return {
        time = now,
        phase = (type(ap) == "string" and ap) or phase.Name,
        weather = weather,
        predicted = predicted,
        endsAt = pEnd,
        cycleIndex = cycleIdx,
    }
end

WeatherPredictor.nextMoons = function(horizonCycles)
    local found = {}
    local now = os.time()
    local c0, _, p0 = WeatherPredictor.atTime(now)
    local cIdx, pIdx = c0, p0
    local steps = 0
    local maxSteps = (horizonCycles or 48) * #phases
    while steps <= maxSteps do
        if steps > 0 then
            pIdx = pIdx + 1
            if pIdx > #phases then
                pIdx = 1
                cIdx = cIdx + 1
            end
        end
        local p = phases[pIdx]
        local wcount = 0
        for _ in pairs(p.Weathers or {}) do
            wcount = wcount + 1
        end
        if wcount > 1 then
            local startT = cIdx * cycleLen
            for i2 = 1, pIdx - 1 do
                startT = startT + phases[i2].Lasts
            end
            local wname = pickWeather(p, cIdx * 1000 + pIdx)
            if startT + p.Lasts >= now and not found[wname] then
                found[wname] = math.max(startT, now)
            end
        end
        steps = steps + 1
    end
    return found
end

-- formatting helper
local function fmtLeft(secs)
    secs = math.max(0, math.floor(tonumber(secs) or 0))
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end
    if m > 0 then
        return string.format("%dm %02ds", m, s)
    end
    return string.format("%ds", s)
end
WeatherPredictor.fmtRel = fmtLeft

-- Game WeatherUI integration
local GAME_WEATHER_ICONS = {
    Rain = "Rain", Lightning = "Lightning", Bloodmoon = "Bloodmoon",
    Snowfall = "Snowfall", Night = "Night", Starfall = "Starfall",
    Rainbow = "Rainbow", Goldmoon = "Goldmoon",
}
local UPCOMING_MOONS = { "Goldmoon", "Bloodmoon", "Rainbow Moon", "Mega Moon" }
local MOON_ICON_NAMES = {
    ["Goldmoon"] = "Goldmoon",
    ["Bloodmoon"] = "Bloodmoon",
    ["Rainbow Moon"] = "Rainbow",
    ["Mega Moon"] = "MegaMoon",
}

local function findWeatherUI()
    local pg = CoreGui
    for _, sg in ipairs(pg:GetChildren()) do
        if sg:IsA("ScreenGui") and sg.Name == "WeatherUI" then
            return sg
        end
    end
    local lp = Players.LocalPlayer
    if lp then
        for _, sg in ipairs(lp:FindFirstChildOfClass("PlayerGui"):GetChildren()) do
            if sg:IsA("ScreenGui") and sg.Name == "WeatherUI" then
                return sg
            end
        end
    end
    return nil
end

local function ensureMoonIcon(ui, iconName, weatherName)
    local icon = ui:FindFirstChild(iconName)
    if icon then
        return icon
    end
    icon = Instance.new("ImageLabel")
    icon.Name = iconName
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel = 0
    icon.Size = UDim2.new(0, 34, 0, 34)
    icon.Position = UDim2.new(0.5, -17, 0.5, -17)
    icon.Visible = false
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "Time"
    timeLabel.BackgroundTransparency = 1
    timeLabel.Size = UDim2.new(1, 0, 1, 0)
    timeLabel.Font = Enum.Font.GothamBold
    timeLabel.TextSize = 12
    timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timeLabel.Text = ""
    timeLabel.Parent = icon
    local weatherLabel = Instance.new("TextLabel")
    weatherLabel.Name = "Weather"
    weatherLabel.BackgroundTransparency = 1
    weatherLabel.Size = UDim2.new(1, 0, 0, 14)
    weatherLabel.Position = UDim2.new(0, 0, 0, 0)
    weatherLabel.Font = Enum.Font.GothamBold
    weatherLabel.TextSize = 10
    weatherLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    weatherLabel.Text = weatherName
    weatherLabel.Parent = icon
    icon.Parent = ui
    return icon
end

WeatherPredictor.updateGameWeatherUI = function(cur, wv, moons)
    local ui = findWeatherUI()
    if not ui then
        return
    end
    for iconName, weatherName in pairs(GAME_WEATHER_ICONS) do
        local icon = ui:FindFirstChild(iconName)
        if icon then
            local playing = wv and wv:GetAttribute(weatherName .. "_Playing") == true
            local endT = wv and tonumber(wv:GetAttribute(weatherName .. "_EndTime")) or 0
            local timeLabel = icon:FindFirstChild("Time")
            if playing then
                icon.Visible = true
                if timeLabel then
                    timeLabel.Text = endT > cur.time and WeatherPredictor.fmtRel(endT - cur.time) or "active"
                end
            else
                icon.Visible = false
            end
        end
    end
    if moons then
        for _, moonName in ipairs(UPCOMING_MOONS) do
            local iconName = MOON_ICON_NAMES[moonName] or moonName
            local t = moons[moonName]
            local icon = ui:FindFirstChild(iconName) or ensureMoonIcon(ui, iconName, moonName)
            local timeLabel = icon:FindFirstChild("Time")
            if t then
                local remaining = t - cur.time
                if remaining <= 1 then
                    icon.Visible = true
                    if timeLabel then
                        timeLabel.Text = "LIVE"
                    end
                else
                    icon.Visible = true
                    if timeLabel then
                        timeLabel.Text = "in " .. WeatherPredictor.fmtRel(remaining)
                    end
                end
            else
                icon.Visible = false
            end
        end
    end
end

WeatherPredictor.update = function() end
WeatherPredictor.destroy = function() end

return WeatherPredictor