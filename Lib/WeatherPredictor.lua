-- Weather & Seed Predictor for Grow a Garden 2
-- Standalone script (independent of the main GAG2 auto-farm)
-- Predicts weather phases, moon events (Goldmoon/Bloodmoon/Rainbow Moon/Mega Moon),
-- shop restock timers and rare seed stock. Injects icons into the game's WeatherUI.

-- services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local client = Players.LocalPlayer

local NotificationController
pcall(function() NotificationController = require(game.StarterPlayer.StarterPlayerScripts.Controllers.NotificationController) end)

-- Prevent duplicate script instances on re-execution
if getgenv and type(getgenv().GAG2Weather_unload) == "function" then
    pcall(getgenv().GAG2Weather_unload)
    task.wait(0.1)
end

local Hub = { running = true, conns = {} }
local HubConns = Hub.conns
local function track(conn)
    if conn then
        table.insert(HubConns, conn)
    end
    return conn
end

local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)
    or (typeof(request) == "function" and request)
    or http_request

-- load library (same pattern as the main script)
print("Loading Library...")
local Library
do
    local src
    local ok, s = pcall(function()
        return game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua")
    end)
    if ok and s then
        src = s
    end
    if not src then
        local ok2, s2 = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/versusairlines/scripts/main/NewLibrary.lua")
        end)
        if ok2 and s2 then
            src = s2
        end
    end
    if not src and readfile then
        local ok3, s3 = pcall(function()
            return readfile("Scripts/Lua/NewLibrary.lua")
        end)
        if ok3 and s3 then
            src = s3
        end
    end
    if not src then
        local noop = function() end
        local dummyUpdate = { updateText = noop, updateList = noop, Set = noop }
        local function dummySection()
            return {
                createLabel = noop,
                createToggle = noop,
                createDropdown = noop,
                createSlider = noop,
                createButton = noop,
                createInputBox = noop,
                FindFirstChild = function()
                    return dummyUpdate
                end,
            }
        end
        Library = { Flags = {}, _ElementControllers = {}, _openModalCount = 0, isClosed = false }
        Library.Setup = function()
            return {
                CreateSection = function()
                    return dummySection()
                end,
                UpdateUI = noop,
                OnClose = nil,
            }
        end
        Library.createDisplayMessage = noop
        Library.TrackConnection = noop
        Library.CleanupConnectionsByTag = noop
        Library.CleanupConnections = noop
        Library.CloseAllPopups = noop
        warn("[GAG2 Weather] Could not load UI library - running in headless mode")
    else
        local ls = (getgenv and getgenv().loadstring) or loadstring
        local chunk, err = ls(src)
        if not chunk then
            warn("[GAG2 Weather Library Load Error] " .. tostring(err))
            local noop = function() end
            local dummyUpdate = { updateText = noop, updateList = noop, Set = noop }
            local function dummySection()
                return {
                    createLabel = noop,
                    createToggle = noop,
                    createDropdown = noop,
                    createSlider = noop,
                    createButton = noop,
                    createInputBox = noop,
                    FindFirstChild = function()
                        return dummyUpdate
                    end,
                }
            end
            Library = { Flags = {}, _ElementControllers = {}, _openModalCount = 0, isClosed = false }
            Library.Setup = function()
                return {
                    CreateSection = function()
                        return dummySection()
                    end,
                    UpdateUI = noop,
                    OnClose = nil,
                }
            end
            Library.createDisplayMessage = noop
            Library.TrackConnection = noop
            Library.CleanupConnectionsByTag = noop
            Library.CleanupConnections = noop
            Library.CloseAllPopups = noop
        else
            local okInit, lib = pcall(chunk)
            if okInit and type(lib) == "table" then
                Library = lib
            elseif okInit then
                local g = (getgenv and getgenv()) or _G
                if type(g.Library) == "table" then
                    Library = g.Library
                end
            end
            if not Library then
                warn("[GAG2 Weather Library Init Error] library returned no table - headless mode")
                local noop = function() end
                local dummyUpdate = { updateText = noop, updateList = noop, Set = noop }
                local function dummySection()
                    return {
                        createLabel = noop,
                        createToggle = noop,
                        createDropdown = noop,
                        createSlider = noop,
                        createButton = noop,
                        createInputBox = noop,
                        FindFirstChild = function()
                            return dummyUpdate
                        end,
                    }
                end
                Library = { Flags = {}, _ElementControllers = {}, _openModalCount = 0, isClosed = false }
                Library.Setup = function()
                    return {
                        CreateSection = function()
                            return dummySection()
                        end,
                        UpdateUI = noop,
                        OnClose = nil,
                    }
                end
                Library.createDisplayMessage = noop
                Library.TrackConnection = noop
                Library.CleanupConnectionsByTag = noop
                Library.CleanupConnections = noop
                Library.CloseAllPopups = noop
            end
        end
    end
end

local function notify(title, desc, style)
    local msg = title .. ": " .. desc
    if NotificationController then
        NotificationController:CreateNotification(msg)
    else
        pcall(function()
            Library:createDisplayMessage(title, desc, { { text = "OK" } }, style or "info")
        end)
    end
end

local lastWebhook = 0
local function sendWebhook(title, desc, color, fields)
    local url = Library.Flags["webhookUrl"]
    if not url or url == "" then
        return
    end
    local now = os.clock()
    if now - lastWebhook < 3 then
        return
    end
    lastWebhook = now
    pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                embeds = {
                    {
                        title = tostring(title),
                        description = tostring(desc),
                        color = color or 5763719,
                        fields = fields or {},
                        footer = { text = client.Name .. " | GAG2 Weather" },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    },
                },
                username = Library.Flags["whName"] or "GAG2 Weather Bot",
            }),
        })
    end)
end

local function tryRequire(loader)
    local success, result = pcall(loader)
    return success and result or nil
end

-- ================================================================
-- WEATHER PREDICTOR (deterministic Day/Sunset/Night cycle from the
-- game's own TimeCycleData - no external API, same math as the client)
-- ================================================================
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

-- finds the NEXT occurrence of every weather event (all moons included)
WeatherPredictor.nextMoons = function(horizonCycles)
    local found = {}
    local now = os.time()
    local c0, _, p0 = WeatherPredictor.atTime(now)
    local cIdx, pIdx = c0, p0
    local steps = 0
    local maxSteps = (horizonCycles or 48) * #phases
    while steps < maxSteps do
        if steps > 0 then
            pIdx = pIdx + 1
            if pIdx > #phases then
                pIdx = 1
                cIdx = cIdx + 1
            end
        end
        local p = phases[pIdx]
        local startT = cIdx * cycleLen
        for i2 = 1, pIdx - 1 do
            startT = startT + phases[i2].Lasts
        end
        for wname, w in pairs(p.Weathers or {}) do
            if not w.AdminOnly and startT + p.Lasts >= now and not found[wname] then
                found[wname] = math.max(startT, now)
            end
        end
        steps = steps + 1
    end
    return found
end

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
    Aurora = "Aurora", Sunburst = "Sunburst", Eclipse = "Eclipse",
}
local UPCOMING_MOONS = { "Goldmoon", "Bloodmoon", "Rainbow Moon", "Mega Moon" }
local MOON_ICON_NAMES = {
    ["Goldmoon"] = "Goldmoon",
    ["Bloodmoon"] = "Bloodmoon",
    ["Rainbow Moon"] = "Rainbow",
    ["Mega Moon"] = "MegaMoon",
}
local MOON_IMAGES = {
    Goldmoon = "rbxassetid://84902063004871",
    Bloodmoon = "rbxassetid://140465339393451",
    Rainbow = "rbxassetid://93602895495056",
    MegaMoon = "rbxassetid://107925838920918",
}

local function findWeatherUI()
    local pg = CoreGui
    for _, sg in ipairs(pg:GetChildren()) do
        if sg:IsA("ScreenGui") and sg.Name == "WeatherUI" then
            local frame = sg:FindFirstChild("Frame")
            if frame then
                return frame
            end
            return sg
        end
    end
    local pg2 = client and client:FindFirstChildOfClass("PlayerGui")
    if pg2 then
        for _, sg in ipairs(pg2:GetChildren()) do
            if sg:IsA("ScreenGui") and sg.Name == "WeatherUI" then
                local frame = sg:FindFirstChild("Frame")
                if frame then
                    return frame
                end
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
    icon.LayoutOrder = 2
    icon.Image = MOON_IMAGES[iconName] or ""
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

-- ================================================================
-- WEATHER WATCH (attribute-driven live events + alerts)
-- ================================================================
local WeatherWatch = {
    events = {},
    night = false,
    weather = nil,
    eventList = { "Rain", "Lightning", "Rainbow", "Snowfall", "Starfall", "Aurora", "Sunburst", "Eclipse" },
}
WeatherWatch.alert = function(label, style)
    if Library.Flags["weatherAlerts"] then
        notify("Weather", label, style or "info")
    end
    if Library.Flags["whWeather"] then
        sendWebhook("Weather Alert", label, style == "warning" and 5763719 or 5324800)
    end
end
do
    -- prefer the game's live WeatherData list (self-heals if events are renamed/added)
    local wd = tryRequire(function()
        local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
        return require(sm:FindFirstChild("WeatherData") or sm:WaitForChild("WeatherData", 5))
    end)
    if type(wd) == "table" and type(wd.Data) == "table" then
        local live = {}
        for _, evEntry in ipairs(wd.Data) do
            if type(evEntry) == "table" and type(evEntry.Name) == "string" then
                live[#live + 1] = evEntry.Name
            end
        end
        if #live > 0 then
            WeatherWatch.eventList = live
        end
    end
end
do
    task.defer(function()
        local wv = ReplicatedStorage:FindFirstChild("WeatherValues") or ReplicatedStorage:WaitForChild("WeatherValues", 30)
        if not wv then
            return
        end
        for _, evName in ipairs(WeatherWatch.eventList) do
            WeatherWatch.events[evName] = wv:GetAttribute(evName .. "_Playing") == true
            pcall(function()
                track(wv:GetAttributeChangedSignal(evName .. "_Playing"):Connect(function()
                    local now = wv:GetAttribute(evName .. "_Playing") == true
                    if now ~= WeatherWatch.events[evName] then
                        WeatherWatch.events[evName] = now
                        WeatherWatch.alert(
                            evName .. (now and " started" or " ended"),
                            now and "warning" or "info"
                        )
                    end
                end))
            end)
        end
        local nightObj = ReplicatedStorage:FindFirstChild("Night")
        if nightObj then
            WeatherWatch.night = nightObj.Value == true
            pcall(function()
                track(nightObj.Changed:Connect(function()
                    local now = nightObj.Value == true
                    if now ~= WeatherWatch.night then
                        WeatherWatch.night = now
                        WeatherWatch.alert(now and "Night started - stealing enabled" or "Night ended", "warning")
                    end
                end))
            end)
        end
    end)
end

-- ================================================================
-- SEED PREDICTOR (restock timers + rare seed detection)
-- ================================================================
local SeedPrice = {}
do
    local ok, mod = pcall(function()
        local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
        return require(sm and (sm:FindFirstChild("SeedData") or sm:WaitForChild("SeedData", 10)) or ReplicatedStorage.SharedModules.SeedData)
    end)
    if ok and type(mod) == "table" then
        for _, seedEntry in ipairs(mod) do
            if type(seedEntry) == "table" and seedEntry.SeedName then
                SeedPrice[seedEntry.SeedName] = tonumber(seedEntry.PurchasePrice) or math.huge
            end
        end
    end
end

local function seedStock()
    local sv = ReplicatedStorage:FindFirstChild("StockValues")
    return sv and sv:FindFirstChild("SeedShop") or nil
end

local function nextRestock(shop)
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    stockValues = stockValues and stockValues:FindFirstChild(shop)
    local restockTimestamp = stockValues and stockValues:FindFirstChild("UnixNextRestock")
    return restockTimestamp and math.max(0, restockTimestamp.Value - os.time()) or nil
end

local function fmtCountdown(unixTs)
    local diff = math.max(0, tonumber(unixTs) - os.time())
    local h = math.floor(diff / 3600)
    local m = math.floor((diff % 3600) / 60)
    local s = diff % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end
    if m > 0 then
        return string.format("%dm %02ds", m, s)
    end
    return string.format("%ds", s)
end

local _rareNotified = {}
local function rareSeedInStock()
    local stockParent = seedStock()
    if not stockParent then
        return false
    end
    for _, stockValue in ipairs(stockParent:GetChildren()) do
        if stockValue:IsA("ValueBase") and stockValue.Value > 0 and (SeedPrice[stockValue.Name] or 0) >= 5000 then
            return true, stockValue.Name
        end
    end
    return false
end
local function doRareNotify()
    local stockParent = seedStock()
    if not stockParent then
        return
    end
    for _, stockValue in ipairs(stockParent:GetChildren()) do
        if stockValue:IsA("ValueBase") then
            local inStock = stockValue.Value > 0
            if inStock and not _rareNotified[stockValue.Name] and (SeedPrice[stockValue.Name] or 0) >= 5000 then
                notify("Rare Seed In Stock", stockValue.Name .. " restocked (" .. stockValue.Value .. "x)")
                sendWebhook("Rare Seed In Stock", stockValue.Name .. " (" .. stockValue.Value .. "x)", 12255232)
                _rareNotified[stockValue.Name] = true
            elseif not inStock then
                _rareNotified[stockValue.Name] = nil
            end
        end
    end
end

-- ================================================================
-- LIVE API SYNC (exact server-side predictions from gag2.gg)
-- Uses the same data as the official companion site; falls back to
-- the local deterministic math below when unreachable.
-- ================================================================
local Live = { weather = nil, items = nil, sell = nil, updatedAt = 0 }
local LIVE_TTL = 30
local SHOP_CATEGORY = { SeedShop = "seed", GearShop = "gear", CrateShop = "crate" }

local function httpGet(url)
    -- server defaults to zstd (Roblox can't decode it) - force identity via request()
    if httpRequest then
        local ok0, res0 = pcall(function()
            return httpRequest({
                Url = url,
                Method = "GET",
                Headers = { ["Accept-Encoding"] = "identity" },
            })
        end)
        if ok0 and res0 and res0.StatusCode == 200 and res0.Body then
            local okJ, j = pcall(function()
                return HttpService:JSONDecode(res0.Body)
            end)
            if okJ and type(j) == "table" then
                return j
            end
        end
    end
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok or not body or body == "" then
        return nil
    end
    local ok2, res = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if ok2 and type(res) == "table" then
        return res
    end
    local ok3, decoded = pcall(function()
        if HttpService.Base64Decode then
            return HttpService:Base64Decode(body)
        end
        return nil
    end)
    if ok3 and decoded then
        local ok4, res4 = pcall(function()
            return HttpService:JSONDecode(decoded)
        end)
        if ok4 and type(res4) == "table" then
            return res4
        end
    end
    return nil
end

local function syncLive()
    if not Hub.running or os.clock() - Live.updatedAt < LIVE_TTL then
        return
    end
    Live.updatedAt = os.clock()
    task.spawn(function()
        local w = httpGet("https://api.gag2.gg/api/live/weather")
        if w and w.weather then
            Live.weather = w.weather
        end
        local it = httpGet("https://api.gag2.gg/api/live/predictions/items")
        if it and it.items then
            Live.items = it.items
        end
        local s = httpGet("https://api.gag2.gg/api/live/sell")
        if s and s.sell then
            Live.sell = s.sell
        end
    end)
end

-- live upcoming moon map (first occurrence of each moon) -> name -> unix ts
local function liveMoonMap()
    local map = {}
    local up = Live.weather and Live.weather.upcomingMoons
    if type(up) == "table" then
        for _, m in ipairs(up) do
            if type(m) == "table" and m.name and not map[m.name] then
                local b = tonumber(m.boundary)
                if b then
                    map[m.name] = b
                end
            end
        end
    end
    return map
end

-- prefer live boundaries; fill gaps with the local deterministic scan
local function moonTimes()
    local map = liveMoonMap()
    local hasLive = false
    for _, n in ipairs(UPCOMING_MOONS) do
        if map[n] then
            hasLive = true
            break
        end
    end
    if not hasLive then
        return WeatherPredictor.nextMoons(48), false
    end
    local localMoons = WeatherPredictor.nextMoons(48)
    for _, n in ipairs(UPCOMING_MOONS) do
        if not map[n] and localMoons[n] then
            map[n] = localMoons[n]
        end
    end
    return map, true
end

-- seconds until the shop's next restock (live prediction first)
local function liveRestock(shop)
    local cat = SHOP_CATEGORY[shop]
    local items = cat and Live.items and Live.items[cat]
    local best
    if type(items) == "table" then
        for _, it in ipairs(items) do
            local b = tonumber(it.nextBoundary)
            if b and (not best or b < best) then
                best = b
            end
        end
    end
    return best and math.max(0, best - os.time()) or nil
end

-- currently boosted sell items (tier != normal) -> "Name x2 | Name2 x2" or nil
local function sellBoostInfo()
    local entries = Live.sell and Live.sell.entries
    if type(entries) ~= "table" then
        return nil
    end
    local parts = {}
    for _, e in ipairs(entries) do
        if e.tier and e.tier ~= "normal" then
            local nm = e.name or e.key
            local mult = tonumber(e.multiplier) or 1
            parts[#parts + 1] = nm .. " x" .. tostring(mult)
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " | ")
end

local function serverHop(lowPop)
    notify("Server Hop", "Teleporting to a new server...")
    pcall(function()
        if lowPop then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(
                    game:HttpGet(
                        "https://games.roblox.com/v1/games/"
                            .. game.PlaceId
                            .. "/servers/Public?sortOrder=Asc&limit=100"
                    )
                )
            end)
            if ok and data and data.data then
                local best
                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        if not best or s.playing < best.playing then
                            best = s
                        end
                    end
                end
                if best then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, client)
                    return
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, client)
    end)
end

-- ================================================================
-- UI (Weather tab)
-- ================================================================
local Setup = Library:Setup({ Location = CoreGui, OpenCloseLocation = "Bottom Right" })
local Weather = Setup:CreateSection("Weather")

Weather:createLabel({ Name = "Current: --", flagName = "weatherPhase", Special = true })
Weather:createLabel({ Name = "Next up: --", flagName = "weatherNextMoons", Special = true })
Weather:createLabel({ Name = "Seeds: --", flagName = "weatherSeedRestock", Special = true })
Weather:createLabel({ Name = "Gears: --", flagName = "weatherGearRestock", Special = true })
Weather:createLabel({ Name = "Crates: --", flagName = "weatherCrateRestock", Special = true })
Weather:createLabel({ Name = "All Weathers: --", flagName = "weatherAllEvents", Special = true })
Weather:createLabel({ Name = "Sell Boost: --", flagName = "weatherSellBoost", Special = true })

Weather:createToggle({
    Name = "Weather Alerts",
    Flag = true,
    flagName = "weatherAlerts",
    Description = "Show notifications on weather transitions.",
})
Weather:createToggle({
    Name = "Rare Seed Restock Alert",
    Flag = false,
    flagName = "rareNotify",
    Description = "Notify when a pricey seed hits the shop.",
})
Weather:createToggle({
    Name = "Auto Hop Until Rare Seed",
    Flag = false,
    flagName = "autoHopRare",
    Description = "Hop servers until a rare seed is in stock.",
})
Weather:createInputBox({
    Name = "Webhook URL",
    flagName = "webhookUrl",
    Flag = "",
    Description = "Input your webhook URL for weather/rare-seed alerts.",
})
Weather:createToggle({
    Name = "Weather Webhook",
    Flag = false,
    flagName = "whWeather",
    Description = "Send webhook on weather transitions.",
})

-- ================================================================
-- LOOPS
-- ================================================================
-- predictor / restock / HUD loop (1s; zero external network calls)
task.spawn(function()
    while task.wait(1) do
        if not Hub.running then
            break
        end
        pcall(function()
            syncLive()
            local cur = WeatherPredictor.current()
            -- moon/phase transition alerts
            if WeatherWatch.weather ~= nil and cur.weather ~= WeatherWatch.weather then
                WeatherWatch.alert(
                    tostring(cur.weather)
                        .. " started (about "
                        .. tostring(math.max(0, (cur.endsAt or cur.time) - cur.time))
                        .. "s)",
                    "warning"
                )
            end
            WeatherWatch.weather = cur.weather
            local function ul(tag, text)
                local lb = Weather:FindFirstChild(tag)
                if lb and lb.updateText then
                    lb:updateText(text)
                end
            end
            local remain = math.max(0, (cur.endsAt or cur.time) - cur.time)
            local activeEvents = ""
            local wv = ReplicatedStorage:FindFirstChild("WeatherValues")
            if wv then
                for _, ev in ipairs(WeatherWatch.eventList) do
                    if wv:GetAttribute(ev .. "_Playing") == true then
                        local endT = tonumber(wv:GetAttribute(ev .. "_EndTime")) or 0
                        activeEvents = activeEvents
                            .. " | "
                            .. ev
                            .. (endT > cur.time and (" " .. WeatherPredictor.fmtRel(endT - cur.time)) or "")
                    end
                end
            end
            ul(
                "weatherPhase",
                "Now: "
                    .. tostring(cur.weather)
                    .. " ("
                    .. tostring(cur.phase)
                    .. ", "
                    .. WeatherPredictor.fmtRel(remain)
                    .. " left)"
                    .. activeEvents
            )
            local moons, liveMoons = moonTimes()
            local moonParts = {}
            for _, mname in ipairs({ "Goldmoon", "Bloodmoon", "Rainbow Moon", "Mega Moon" }) do
                local t = moons[mname]
                if t then
                    local nm = (mname == "Goldmoon") and "Gold Moon" or mname
                    moonParts[#moonParts + 1] = nm .. " " .. WeatherPredictor.fmtRel(t - cur.time)
                end
            end
            ul("weatherNextMoons", "Next up: " .. (#moonParts > 0 and table.concat(moonParts, " | ") or "--"))
            if wv then
                WeatherPredictor.updateGameWeatherUI(cur, wv, moons)
            end
            local nxSeed = liveRestock("SeedShop") or nextRestock("SeedShop")
            local nxGear = liveRestock("GearShop") or nextRestock("GearShop")
            local nxCrate = liveRestock("CrateShop") or nextRestock("CrateShop")
            local liveTag = (Live.items and "[live] ") or ""
            ul(
                "weatherSeedRestock",
                "Seeds: " .. liveTag .. (nxSeed and ("restock in " .. WeatherPredictor.fmtRel(nxSeed)) or "waiting for shop")
            )
            ul(
                "weatherGearRestock",
                "Gears: " .. liveTag .. (nxGear and ("restock in " .. WeatherPredictor.fmtRel(nxGear)) or "waiting for shop")
            )
            ul(
                "weatherCrateRestock",
                "Crates: " .. liveTag .. (nxCrate and ("restock in " .. WeatherPredictor.fmtRel(nxCrate)) or "waiting for shop")
            )
            local sb = sellBoostInfo()
            if sb then
                ul("weatherSellBoost", "Sell Boost: " .. sb)
            else
                ul("weatherSellBoost", "Sell Boost: --")
            end
            local allMoons = WeatherPredictor.nextMoons(48)
            local allParts = {}
            for wname, wt in pairs(allMoons) do
                allParts[#allParts + 1] = wname .. " " .. WeatherPredictor.fmtRel(wt - cur.time)
            end
            ul("weatherAllEvents", "All: " .. (#allParts > 0 and table.concat(allParts, " | ") or "--"))
        end)
    end
end)

-- rare seed / auto hop loop (2s)
task.spawn(function()
    while task.wait(2) do
        if not Hub.running then
            break
        end
        pcall(function()
            if Library.Flags["rareNotify"] then
                doRareNotify()
            end
            if Library.Flags["autoHopRare"] and not rareSeedInStock() then
                serverHop(false)
            end
        end)
    end
end)

-- ================================================================
-- LIFECYCLE
-- ================================================================
function Hub.unload()
    if not Hub.running then
        return
    end
    Hub.running = false
    for _, c in ipairs(Hub.conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    Hub.conns = {}
    print("[GAG2 Weather] unloaded.")
end
if getgenv then
    getgenv().GAG2Weather_unload = Hub.unload
end
if Setup.OnClose then
    track(Setup.OnClose:Connect(function()
        Hub.unload()
    end))
end

print("[GAG2 Weather] Loaded successfully (" .. os.date("%H:%M:%S") .. ")")
print(
    "[GAG2 Weather] Predictor cycle: "
        .. tostring(WeatherPredictor.Total or 0)
        .. "s | Phases: "
        .. tostring(#phases)
        .. " | Live API: enabled (30s refresh)"
)
notify("GAG2 Weather", "Predictor loaded - Weather HUD - Seed Restock - Rare Seed Alerts", "info")
