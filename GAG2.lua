-- services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LightingService = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local client = Players.LocalPlayer

local NotificationController
pcall(function() NotificationController = require(game.StarterPlayer.StarterPlayerScripts.Controllers.NotificationController) end)

-- Prevent duplicate script instances & memory leaks on re-execution
if getgenv and type(getgenv().GAG2_unload) == "function" then
    pcall(getgenv().GAG2_unload)
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

-- Platform & Stability Abstractions (High-Stability AFK Engine)
local Platform = {
    Client = client,
    Request = httpRequest,
    SetFPS = (typeof(setfpscap) == "function" and setfpscap) or function(cap) end,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
}

local StabilityEngine = {
    _3DRendering = true,
    _lastPosition = nil,
    _stuckTimer = 0,
    _watchdogConn = nil,

    Set3DRendering = function(self, enabled)
        self._3DRendering = enabled
        pcall(function()
            RunService:Set3dRenderingEnabled(enabled)
        end)
    end,

    SetAFKThrottling = function(self, enabled, targetFPS)
        targetFPS = targetFPS or 15
        self:Set3DRendering(not enabled)
        Platform.SetFPS(enabled and targetFPS or 60)
    end,

    StartAntiStuckWatchdog = function(self, checkInterval, maxStuckTime)
        if self._watchdogConn then
            self._watchdogConn:Disconnect()
            self._watchdogConn = nil
        end
        checkInterval = checkInterval or 2
        maxStuckTime = maxStuckTime or 20
        self._stuckTimer = 0

        self._watchdogConn = RunService.Heartbeat:Connect(function(dt)
            self._stuckTimer = self._stuckTimer + dt
            if self._stuckTimer >= checkInterval then
                self._stuckTimer = 0
                local char = client.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then
                    return
                end

                if Library and Library.Flags and (Library.Flags["autoHarvestAll"] or Library.Flags["autoPlant"] or Library.Flags["autoCollect"] or Library.Flags["autoSteal"] or Library.Flags["autoTame"] or Library.Flags["autoSprinklerAll"] or Library.Flags["autoWaterAll"]) then
                    if self._lastPosition then
                        local dist = (root.Position - self._lastPosition).Magnitude
                        if dist < 1.5 then
                            self._stuckAccumulator = (self._stuckAccumulator or 0) + checkInterval
                            if self._stuckAccumulator >= maxStuckTime then
                                self._stuckAccumulator = 0
                                pcall(function()
                                    local hum = char:FindFirstChildOfClass("Humanoid")
                                    if hum then
                                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                    root.CFrame = root.CFrame + Vector3.new(math.random(-4, 4), 5, math.random(-4, 4))
                                end)
                            end
                        else
                            self._stuckAccumulator = 0
                        end
                    end
                    self._lastPosition = root.Position
                end
            end
        end)
        if Library and Library.TrackConnection then
            Library:TrackConnection(self._watchdogConn, "StabilityWatchdog")
        end
    end,

    StopAntiStuckWatchdog = function(self)
        if self._watchdogConn then
            pcall(function()
                self._watchdogConn:Disconnect()
            end)
            self._watchdogConn = nil
        end
        self._stuckAccumulator = 0
        self._lastPosition = nil
    end,
}

-- load library
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
    if not src and readfile then
        local ok4, s4 = pcall(function()
            return readfile("NewLibrary.lua")
        end)
        if ok4 and s4 then
            src = s4
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
        warn("[GAG2] Could not load UI library - running in headless mode")
    else
        local ls = (getgenv and getgenv().loadstring) or loadstring
        local chunk, err = ls(src)
        if not chunk then
            warn("[GAG2 Library Load Error] " .. tostring(err))
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
                    CreateSection = dummySection,
                    OnClose = { Connect = noop },
                }
            end
            Library.createDisplayMessage = noop
            Library.TrackConnection = noop
            Library.CleanupConnectionsByTag = noop
            Library.CleanupConnections = noop
            Library.CloseAllPopups = noop
        else
            Library = chunk()
        end
    end
end

local Setup = Library:Setup({ Location = CoreGui, OpenCloseLocation = "Bottom Right" })

do -- scoped: CreateSection proxy internals (Delta 200-register limit)
-- CreateSection proxy: captures create* returns + FindFirstChild adapter (updateText->Set)
local _ctrls = {}
local _origCreateSection = Setup.CreateSection
local function _adapt(obj)
    if not obj then
        return nil
    end
    return setmetatable({}, {
        __index = function(_, k)
            if k == "updateText" then
                return function(_, t)
                    if obj.Set then
                        obj:Set(t)
                    elseif obj.updateText then
                        obj:updateText(t)
                    end
                end
            end
            if k == "Set" then
                return function(_, ...)
                    if obj.Set then
                        obj:Set(...)
                    end
                end
            end
            if k == "updateList" then
                return function(_, l)
                    if obj.updateList then
                        obj:updateList(l)
                    end
                end
            end
            local v = obj[k]
            if type(v) == "function" then
                return function(_, ...)
                    return obj[k](obj, ...)
                end
            end
            return v
        end,
    })
end
function Setup:CreateSection(name)
    local sec = _origCreateSection(self, name)
    local proxy = setmetatable({}, {
        __index = function(_, k)
            if k == "FindFirstChild" then
                return function(_, tag)
                    return _adapt(_ctrls[tag])
                end
            end
            return sec[k]
        end,
    })
    for _, m in ipairs({
        "createLabel",
        "createDropdown",
        "createToggle",
        "createSlider",
        "createButton",
        "createInputBox",
    }) do
        proxy[m] = function(_, cfg)
            local ok, obj = pcall(sec[m], sec, cfg)
            if cfg and cfg.flagName and obj then
                _ctrls[cfg.flagName] = obj
            end
            return obj
        end
    end
    return proxy
end
end -- scoped: CreateSection proxy

-- anti-afk
track(client.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end)
    task.wait(1)
    pcall(function()
        VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end)
end))

-- helpers
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
local function firstValue(v)
    if type(v) == "table" then
        for k, val in pairs(v) do
            if type(k) == "number" then
                return val
            end
            if val == true then
                return k
            end
            return k
        end
        return nil
    end
    return v
end
local function matchesSelection(selectedFlagData, targetValue)
    if not selectedFlagData or selectedFlagData == "" or selectedFlagData == "Any" or selectedFlagData == "All" then
        return true
    end
    if not targetValue then
        return false
    end
    if type(selectedFlagData) == "string" then
        return targetValue:lower() == selectedFlagData:lower()
    elseif type(selectedFlagData) == "table" then
        if next(selectedFlagData) == nil then
            return true
        end
        if selectedFlagData[targetValue] == true then
            return true
        end
        for k, v in pairs(selectedFlagData) do
            if type(k) == "string" and v == true and k:lower() == targetValue:lower() then
                return true
            elseif type(v) == "string" and v:lower() == targetValue:lower() then
                return true
            end
        end
        return false
    end
    return true
end
local function getHRP()
    local character = client.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local character = client.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

-- interval helper
local function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    delayTime = math.max(tonumber(delayTime) or 0.1, 0.05)
    if not Library.Flags[flag] then
        return
    end
    local last = 0
    local running = false
    local slowWarnAt = 0
    local spawnFn = task and task.spawn or spawn
    local waitFn = task and task.wait or wait
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end
        local now = os.clock()
        if running or now - last < delayTime then
            return
        end
        last = now
        running = true
        spawnFn(function()
            local startedAt = os.clock()
            local ok, err = pcall(callback)
            local elapsed = os.clock() - startedAt
            if not ok then
                warn("[GAG:" .. tostring(tag) .. "]", err)
            elseif elapsed > 10 and os.clock() - slowWarnAt > 5 then
                slowWarnAt = os.clock()
                warn(string.format("[GAG] slow interval %s took %.3fs", tostring(tag), elapsed))
            end
            waitFn()
            running = false
        end)
    end)
    Library:TrackConnection(conn, tag)
end

local function createIntervalToggle(section, cfg)
    local tag = cfg.tag or cfg.flagName
    section:createToggle({
        Name = cfg.Name,
        Warning = cfg.Warning,
        WarnIf = cfg.WarnIf,
        Flag = cfg.Flag or false,
        flagName = cfg.flagName,
        Callback = function(enabled)
            Library:CleanupConnectionsByTag(tag)
            if not enabled then
                return
            end
            interval(tag, cfg.flagName, cfg.delay or 1, cfg.Step)
        end,
    })
end

-- utility helpers

-- game API bootstrap
-- debug logger: prints to console and appends to a ring buffer so it can
-- be written to a file on demand (Dump Debug Log button in Quick Actions).
local DebugLogBuf = {}
local DebugLogOn = true
local function DebugLog(...)
    if not DebugLogOn then
        return
    end
    local parts = { ... }
    local line = os.time() .. " " .. table.concat(parts, " | ")
    print("[GAG2DBG] " .. line)
    DebugLogBuf[#DebugLogBuf + 1] = line
    if #DebugLogBuf > 2000 then
        table.remove(DebugLogBuf, 1)
    end
end
-- auto-writer: flush the log to a file every few seconds so it can be
-- inspected live from outside the game (Delta writefile).
local LastDebugDump = 0
local function DumpDebugLog()
    if not DebugLogOn or #DebugLogBuf == 0 then
        return
    end
    local ok, err = pcall(function()
        local payload = "GAG2 debug log " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" .. table.concat(DebugLogBuf, "\n") .. "\n"
        writefile("gag2_debug_log.txt", payload)
    end)
    if ok then
        LastDebugDump = #DebugLogBuf
    end
end
task.spawn(function()
    while true do
        task.wait(4)
        if DebugLogOn and #DebugLogBuf ~= LastDebugDump then
            DumpDebugLog()
        end
    end
end)

local Network, PlayerState, SeedData, SeedPrice, PetCache, FruitValueCalc, SeedBaseValue, SeedRarity
local function tryRequire(loader)
    local success, result = pcall(loader)
    return success and result or nil
end
local mod = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm and (sm:FindFirstChild("Networking") or sm:WaitForChild("Networking", 10)) or ReplicatedStorage.SharedModules.Networking)
end)
if not mod then
    -- fallback: scan the gc for the already-loaded Networking table
    -- (resolver fallback; require can fail when Packet isn't in cache yet)
    mod = tryRequire(function()
        local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
        local pkt = sm and (sm:FindFirstChild("Packet") or sm:WaitForChild("Packet", 5))
        if pkt then
            require(pkt)
        end
        return require(sm and (sm:FindFirstChild("Networking") or sm:WaitForChild("Networking", 5)) or ReplicatedStorage.SharedModules.Networking)
    end)
end
if not mod and getgc then
    mod = tryRequire(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" then
                local hasPlant = type(v.Plant) == "table" and type(v.Plant.PlantSeed) ~= "nil"
                local hasGarden = type(v.Garden) == "table" and type(v.Garden.CollectFruit) ~= "nil"
                local hasSeedShop = type(v.SeedShop) == "table" and type(v.SeedShop.PurchaseSeed) ~= "nil"
                if hasPlant and hasGarden and hasSeedShop then
                    return v
                end
            end
        end
        return nil
    end)
end
if not mod then
    warn("[GAG2] Networking module unavailable - aborting")
    return
end
Network = mod
DebugLog("bootstrap", "Network resolved", "hasPlantSeed=" .. tostring(Network.Plant and Network.Plant.PlantSeed ~= nil), "leafType=" .. typeof(Network.Plant and Network.Plant.PlantSeed))
mod = tryRequire(function()
    local cm = ReplicatedStorage:FindFirstChild("ClientModules") or ReplicatedStorage:WaitForChild("ClientModules", 10)
    return require(cm and (cm:FindFirstChild("PlayerStateClient") or cm:WaitForChild("PlayerStateClient", 10)) or ReplicatedStorage.ClientModules.PlayerStateClient)
end)
if mod then
    PlayerState = mod
end
mod = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm and (sm:FindFirstChild("SeedData") or sm:WaitForChild("SeedData", 10)) or ReplicatedStorage.SharedModules.SeedData)
end)
if type(mod) == "table" then
    SeedData = mod
    SeedPrice = {}
    for _, seedEntry in ipairs(SeedData) do
        if type(seedEntry) == "table" and seedEntry.SeedName then
            SeedPrice[seedEntry.SeedName] = tonumber(seedEntry.PurchasePrice) or math.huge
        end
    end
end
SeedRarity = {}
for _, seedEntry in ipairs(SeedData or {}) do
    if type(seedEntry) == "table" and seedEntry.SeedName then
        SeedRarity[seedEntry.SeedName] = seedEntry.Rarity or "Common"
    end
end
mod = tryRequire(function()
    local sd = ReplicatedStorage:FindFirstChild("SharedData") or ReplicatedStorage:WaitForChild("SharedData", 10)
    return require(sd and (sd:FindFirstChild("PetData") or sd:FindFirstChild("Pets") or sd:FindFirstChild("PetCache") or sd:WaitForChild("PetData", 5)) or ReplicatedStorage.SharedData.PetData)
end)
if mod then
    PetCache = mod
end
mod = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm and (sm:FindFirstChild("FruitValueCalc") or sm:WaitForChild("FruitValueCalc", 10)) or ReplicatedStorage.SharedModules.FruitValueCalc)
end)
if type(mod) == "function" then
    FruitValueCalc = mod
end
SeedBaseValue = {}
if FruitValueCalc and SeedData then
    for _, seedEntry in ipairs(SeedData) do
        if type(seedEntry) == "table" and seedEntry.SeedName then
            local okv, v = pcall(FruitValueCalc, seedEntry.SeedName, 1, nil, client, nil)
            SeedBaseValue[seedEntry.SeedName] = (okv and type(v) == "number") and v or 0
        end
    end
end

-- growth-rate data (from the game's Fruits module):
-- GrowRate = weight gained per grow tick; value-per-time ranking uses
-- SeedBaseValue * GrowRate (faster-growing seeds with similar value win).
-- Missing entries (non-tick crops like Mushroom/Tulip) fall back to 1.0.
local SEED_GROW_RATE = {
    Grape = 0.0513, Apple = 0.1167, Strawberry = 0.3, Blueberry = 0.2308,
    Tomato = 0.2667, Coconut = 0.0333, Cactus = 0.0119, Mango = 0.031,
    Cherry = 0.0064, Sunflower = 0.0061, Acorn = 0.0058, Beanstalk = 0.06,
    ["Poison Apple"] = 0.0023, ["Venus Fly Trap"] = 0.0013, ["Thorn Rose"] = 0.5,
    Pomegranate = 0.0064, Lotus = 0.007, Pineapple = 0.01, ["Poison Ivy"] = 0.0095,
    ["Ghost Pepper"] = 0.0088, Romanesco = 0.0119, ["Baby Cactus"] = 0.4067,
    ["Glow Mushroom"] = 0.05, ["Horned Melon"] = 0.0333, Corn = 0.0444,
    Pinetree = 0.5, ["Moon Bloom OLD"] = 0.03, Banana = 0.0413,
    ["Dragon Fruit"] = 0.0061, ["Dragon's Breath"] = 0.0078, ["Moon Bloom"] = 0.0047,
    ["Green Bean"] = 0.06,
}
local function growRateFor(seedName)
    return SEED_GROW_RATE[seedName] or 1.0
end

-- exact game value engine (cloned from the game's own FruitValueCalc module code)
local ValueDB = {
    sellFallback = {
        Carrot = 5, Strawberry = 3, Tomato = 9, Blueberry = 5, Apple = 12, Bamboo = 800,
        Cactus = 40, Pineapple = 30, ["Green Bean"] = 10, Banana = 35, Grape = 45,
        Mushroom = 13000, ["Rocket Pop"] = 22500, Coconut = 60, Mango = 90,
        ["Dragon Fruit"] = 150, Acorn = 200, Cherry = 350, ["Fire Fern"] = 900,
        Sunflower = 1750, ["Venus Fly Trap"] = 3000, Pomegranate = 900,
        ["Poison Apple"] = 900, ["Moon Bloom"] = 8500, ["Sun Bloom"] = 9000,
        ["Dragon's Breath"] = 3400, ["Hypno Bloom"] = 9500, ["Poison Ivy"] = 1700,
        ["Glow Mushroom"] = 700, ["Ghost Pepper"] = 2500, ["Horned Melon"] = 200,
        Corn = 34, ["Baby Cactus"] = 70, Tulip = 60, ["Venom Spitter"] = 3800,
        ["Briar Rose"] = 6500, ["Eclipse Bloom"] = 12000, ["Star Fruit"] = 6000,
    },
    mutPrice = {
        Gold = 10, Rainbow = 30, Electric = 25, Frozen = 14, Bloodlit = 60, Chained = 8,
        Starstruck = 50, Aurora = 1.5, Ignited = 60, Glow = 100, Eclipsed = 80, Veil = 50,
        Solarflare = 5, Pizza = 5,
    },
    sizeExpOverrides = { Mushroom = 1.9, Bamboo = 1.75 },
    sellLive = nil,
    mutLive = nil,
    baseWeight = {},
    singleHarvest = {},
}
mod = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm:FindFirstChild("SellValueData") or sm:WaitForChild("SellValueData", 5))
end)
if type(mod) == "table" then
    ValueDB.sellLive = mod
end
mod = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
    return require(sm:FindFirstChild("MutationData") or sm:WaitForChild("MutationData", 5))
end)
if type(mod) == "table" and type(mod.ReturnPriceMultiplier) == "function" then
    ValueDB.mutLive = mod
end
do
    local pgm = ReplicatedStorage:FindFirstChild("PlantGenerationModules")
    local fruitsFolder = pgm and pgm:FindFirstChild("Fruits")
    for _, seedEntry in ipairs(SeedData or {}) do
        if type(seedEntry) == "table" and seedEntry.SeedName then
            ValueDB.singleHarvest[seedEntry.SeedName] = seedEntry.IsSingleHarvest == true
            if fruitsFolder then
                local fmod = fruitsFolder:FindFirstChild(seedEntry.SeedName)
                local reqd = fmod and tryRequire(function()
                    return require(fmod)
                end)
                local gd = type(reqd) == "table" and reqd.GrowData
                ValueDB.baseWeight[seedEntry.SeedName] = (gd and tonumber(gd.BaseWeight)) or 1
            else
                ValueDB.baseWeight[seedEntry.SeedName] = 1
            end
        end
    end
end
local ValueEngine = {}
-- exact clone of the game's FruitValueCalc(seedName, weightKg, mutationName, player, freshness)
function ValueEngine.compute(crop, weight, mutationName, baseOnly)
    if not crop or crop == "" then
        return 0
    end
    weight = tonumber(weight) or 1
    if weight <= 0 then
        weight = 1
    end
    if type(mutationName) ~= "string" or mutationName == "" then
        mutationName = nil
    end
    if FruitValueCalc then
        local okv, vv = pcall(FruitValueCalc, crop, weight, baseOnly and nil or mutationName, client, nil)
        if okv and type(vv) == "number" and vv >= 0 then
            return vv
        end
    end
    local base = type(ValueDB.sellLive) == "table" and tonumber(ValueDB.sellLive[crop]) or nil
    if not base or base <= 0 then
        base = ValueDB.sellFallback[crop] or (SeedBaseValue and SeedBaseValue[crop]) or 0
    end
    if base <= 0 then
        return 0
    end
    local sizeExp = ValueDB.sizeExpOverrides[crop] or 2.65
    local sizeMult
    if weight > 5 then
        -- diminishing returns: knee at 5kg, tail exponent min(1.5, sizeExp)
        sizeMult = (5 ^ sizeExp) * ((weight / 5) ^ math.min(1.5, sizeExp))
    else
        sizeMult = weight ^ sizeExp
    end
    local mutMult = 1
    if mutationName and not baseOnly then
        if ValueDB.mutLive then
            local okm, mm = pcall(ValueDB.mutLive.ReturnPriceMultiplier, mutationName)
            mutMult = (okm and tonumber(mm)) or 0
        end
        if mutMult <= 1 then
            mutMult = ValueDB.mutPrice[mutationName] or 1
        end
        if ValueDB.singleHarvest[crop] and mutMult > 1 then
            mutMult = 1 + (mutMult - 1) * 0.15
        end
    end
    return math.floor(base * sizeMult * mutMult)
end
-- display weight (kg) of a plant/fruit model: BaseWeight * SizeMulti
function ValueEngine.weightOf(model)
    local crop = model:GetAttribute("SeedName") or model:GetAttribute("CorePartName")
    local sizeMult = tonumber(model:GetAttribute("SizeMulti") or model:GetAttribute("SizeMultiplier")) or 1
    local bw = (crop and ValueDB.baseWeight[crop]) or 1
    return bw * sizeMult, crop
end
local HOP = 70
local RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Super = 7, Divine = 8 }
local RARITY_LIST = { "Any", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Super", "Divine" }

-- jitter helper (anti-pacing randomization: base +/- variance)
local function jitter(base, variance)
    variance = variance or base * 0.25
    return base + (math.random() - 0.5) * 2 * variance
end

-- live-synced fruit/plant tracking (Network event hooks)
local plantData = {}
local fruitData = {}
local _purchasedThisCycle = {}
local _purchasedStockTimestamps = {}
local _purchaseCycleRestocks = {}
local _plantConns = {}
do
    local function safeConnect(node, cb)
        if node ~= nil then
            local ok, conn = pcall(function()
                return node:Connect(cb)
            end)
            if ok and conn then
                return conn
            end
        end
        return nil
    end
    -- Track plants being added/removed so harvest can use direct remotes without workspace scanning
    local function connectGD()
        if not Network then
            return
        end
        local g = Network.Garden
        if not g then
            return
        end
        local function tc(c)
            if c then
                table.insert(_plantConns, c)
                track(c)
            end
        end
        tc(safeConnect(g.PlantAdded, function(gardenId, plantId, seedType)
            plantData[plantId] = plantData[plantId] or { fruitIds = {}, grown = false, seedType = seedType }
        end))
        tc(safeConnect(g.PlantRemoved, function(gardenId, plantId)
            plantData[plantId] = nil
        end))
        tc(safeConnect(g.FruitAdded, function(gardenId, plantId, fruitId, fruitName)
            plantData[plantId] = plantData[plantId] or { fruitIds = {}, grown = false }
            plantData[plantId].fruitIds[fruitId] = true
            fruitData[fruitId] = { plantId = plantId, grown = false, name = fruitName or "" }
        end))
        tc(safeConnect(g.FruitGrowthUpdated, function(gardenId, plantId, fruitId, age, maxAge)
            if fruitData[fruitId] then
                fruitData[fruitId].grown = (age ~= nil and maxAge ~= nil and age >= maxAge)
            end
        end))
        tc(safeConnect(g.FruitRemoved, function(gardenId, plantId, fruitId)
            if plantData[plantId] then
                plantData[plantId].fruitIds[fruitId] = nil
            end
            fruitData[fruitId] = nil
        end))
        tc(safeConnect(g.FruitMutationUpdated, function(gardenId, plantId, fruitId, mutations)
            if fruitData[fruitId] then
                if type(mutations) == "string" then
                    fruitData[fruitId].mutated = mutations ~= ""
                    fruitData[fruitId].mutations = mutations ~= "" and mutations or nil
                elseif type(mutations) == "table" then
                    fruitData[fruitId].mutated = next(mutations) ~= nil
                    fruitData[fruitId].mutations = mutations
                end
            end
        end))
    end
    task.defer(connectGD)
end

-- netFire helper (walks Network by dotted path, spawn-safe for yields).
-- Colon-call style like the working hubs: works whether the leaf is a
-- plain table with a Fire field or a Roblox Instance (type() gate would
-- reject Instances since Luau returns "Instance" for them).
local function netFire(path, ...)
    if not Network then
        DebugLog("netFire", path, "SKIP: Network is nil")
        return
    end
    local node = Network
    for p in string.gmatch(path, "[^%.]+") do
        node = node and node[p]
    end
    if node ~= nil then
        local args = { ... }
        local ok, err = pcall(function()
            node:Fire(table.unpack(args))
        end)
        DebugLog("netFire", path, ok and "OK" or ("ERR: " .. tostring(err)), "leafType=" .. typeof(node))
    else
        DebugLog("netFire", path, "MISSING: node is nil")
    end
end

-- netCall: invoke a RemoteFunction by dotted path (uses InvokeServer, not Fire)
local function netCall(path, ...)
    if not Network then
        DebugLog("netCall", path, "SKIP: Network is nil")
        return nil
    end
    local node = Network
    for p in string.gmatch(path, "[^%.]+") do
        node = node and node[p]
    end
    if node ~= nil then
        local args = { ... }
        local ok, res = pcall(function()
            if node.InvokeServer ~= nil then
                return node:InvokeServer(table.unpack(args))
            end
            return node:Fire(table.unpack(args))
        end)
        if not ok then
            DebugLog("netCall", path, "ERR: " .. tostring(res), "leafType=" .. typeof(node))
        end
        return ok and res or nil
    end
    DebugLog("netCall", path, "MISSING: node is nil")
    return nil
end


-- core data helpers
local function getReplica()
    if not PlayerState then
        return nil
    end
    local ok, r = pcall(function()
        return PlayerState:GetLocalReplica()
    end)
    return ok and r or nil
end
local function getData()
    local replica = getReplica()
    return replica and replica.Data or nil
end
local function getBalance()
    local playerData = getData()
    return playerData and playerData.Sheckles or 0
end
local function myPlot()
    local g = Workspace:FindFirstChild("Gardens")
    if not g then
        return nil
    end
    -- fast path: game stamps PlotId on the local player
    local pid = client:GetAttribute("PlotId")
    if pid then
        local fast = g:FindFirstChild("Plot" .. tostring(pid))
        if fast then
            return fast
        end
    end
    for _, plot in ipairs(g:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == client.UserId then
            return plot
        end
    end
    return nil
end
local function isNight()
    local n = ReplicatedStorage:FindFirstChild("Night")
    return n and n.Value == true
end
local function setCollide(on)
    local character = client.Character
    if not character then
        return
    end
    for _, p in ipairs(character:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.CanCollide = on
            end)
        end
    end
end
local function teleport(pos, instant)
    local rootPart = getHRP()
    if not (rootPart and pos) then
        return
    end
    local target = pos + Vector3.new(0, 3, 0)

    -- optional tween mode (smooth movement; evasion passes instant=true)
    if Library.Flags["tpTween"] and not instant then
        local dist = (target - rootPart.Position).Magnitude
        local speed = math.max(10, tonumber(Library.Flags["tpTweenSpeed"]) or 60)
        local dur = math.clamp(dist / speed, 0.1, 2.5)
        pcall(function()
            local tween = TweenService:Create(rootPart, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target) })
            tween:Play()
            tween.Completed:Wait()
        end)
        return
    end

    local restore = not Library.Flags["noClip"]
    if restore then
        setCollide(false)
    end
    for _ = 1, 60 do
        local cur = rootPart.Position
        local delta = target - cur
        if delta.Magnitude <= HOP then
            rootPart.CFrame = CFrame.new(target)
            break
        end
        rootPart.CFrame = CFrame.new(cur + delta.Unit * HOP)
        RunService.Heartbeat:Wait()
    end
    if restore then
        setCollide(true)
    end
end

-- bring character near own plot (several flows silently failed when this was missing)
local function nearPlot()
    local plot = myPlot()
    if not plot then
        return
    end
    local rootPart = getHRP()
    if not rootPart then
        return
    end
    local marker = plot:FindFirstChild("SpawnPoint") or plot:FindFirstChild("PlotSizeReference")
    if not marker then
        return
    end
    local ok, target = pcall(function()
        if marker:IsA("BasePart") then
            return marker.Position
        end
        return marker:GetPivot().Position
    end)
    if ok and target and (rootPart.Position - target).Magnitude > 12 then
        teleport(target)
    end
end

-- authoritative tool helpers (game client requires the matching tool equipped)
local function getToolParents()
    local parents = {}
    local char = client and client.Character
    if char then
        parents[#parents + 1] = char
    end
    local bp = client and client:FindFirstChild("Backpack")
    if bp then
        parents[#parents + 1] = bp
    end
    return parents
end

local function findToolByAttr(attrName, expectedName)
    local want = type(expectedName) == "string" and expectedName:lower() or nil
    local fuzzyHit, fuzzyAttr = nil, nil
    local function scan(container)
        if not container then
            return nil
        end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                local attr = t:GetAttribute(attrName)
                if type(attr) == "string" then
                    local attrLower = attr:lower()
                    local nameLower = t.Name:lower()
                    if not want or attrLower == want or nameLower == want then
                        return t, attr
                    end
                    if want and not fuzzyHit
                        and (attrLower:find(want, 1, true) or nameLower:find(want, 1, true) or want:find(attrLower, 1, true))
                    then
                        fuzzyHit, fuzzyAttr = t, attr
                    end
                end
            end
        end
        return nil
    end
    local char = client.Character
    local t, a = scan(char)
    if t then
        return t, a
    end
    local bp = client:FindFirstChild("Backpack")
    t, a = scan(bp)
    if t then
        return t, a
    end
    return fuzzyHit, fuzzyAttr
end

local function equipTool(tool)
    local char = client.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not (humanoid and tool and tool.Parent) then
        DebugLog("equipTool", tool and tool.Name or "?", "SKIP: no humanoid/tool")
        return nil
    end
    if tool.Parent == char then
        DebugLog("equipTool", tool.Name, "already equipped")
        return tool
    end
    pcall(function()
        humanoid:EquipTool(tool)
    end)
    task.wait(0.1)
    if tool.Parent ~= char then
        task.wait(0.15)
    end
    local ok = (tool.Parent == char) and tool or nil
    DebugLog("equipTool", tool.Name, ok and "OK" or "FAILED")
    return ok
end

-- position mode resolver
local function resolveModePosition(mode, savedFlag, plot)
    mode = tostring(mode or "Random")
    if mode == "Saved Position" then
        local saved = Library.Flags[savedFlag]
        if type(saved) == "Vector3" then
            return saved
        end
        if type(saved) == "table" and saved.X and saved.Y and saved.Z then
            return Vector3.new(saved.X, saved.Y, saved.Z)
        end
    end
    local rootPart = getHRP()
    if mode == "Player Position" and rootPart then
        return rootPart.Position
    end
    local ref = plot and plot:FindFirstChild("PlotSizeReference")
    if mode == "Random" and ref then
        local size = ref.Size
        return ref.Position
            + Vector3.new((math.random() - 0.5) * size.X * 0.8, 0, (math.random() - 0.5) * size.Z * 0.8)
    end
    return ref and ref.Position
end

-- stock helpers
local function stockItems(shop)
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    stockValues = stockValues and stockValues:FindFirstChild(shop)
    return stockValues and stockValues:FindFirstChild("Items")
end
local function seedStock()
    return stockItems("SeedShop")
end
local function gearStock()
    return stockItems("GearShop")
end
local function crateStock()
    return stockItems("CrateShop")
end
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

-- formatting
local function fmtCash(n)
    n = tonumber(n) or 0
    if n >= 1e9 then
        return string.format("$%.2fB", n / 1e9)
    end
    if n >= 1e6 then
        return string.format("$%.2fM", n / 1e6)
    end
    if n >= 1e3 then
        return string.format("$%.1fK", n / 1e3)
    end
    return "$" .. tostring(math.floor(n))
end

-- list builders
local function getSeedList()
    local seen = {}
    for _, seedEntry in ipairs(SeedData or {}) do
        if seedEntry.SeedName then
            seen[seedEntry.SeedName] = tonumber(seedEntry.SeedShopDisplayOrder) or 900
        end
    end
    local stockParent = seedStock()
    if stockParent then
        for _, stockValue in ipairs(stockParent:GetChildren()) do
            if seen[stockValue.Name] == nil then
                seen[stockValue.Name] = 899
            end
        end
    end
    local list = {}
    for name, ord in pairs(seen) do
        list[#list + 1] = { name, ord }
    end
    table.sort(list, function(a, b)
        if a[2] == b[2] then
            return a[1] < b[1]
        end
        return a[2] < b[2]
    end)
    local names = {}
    for _, x in ipairs(list) do
        names[#names + 1] = x[1]
    end
    return names
end
local function getGearList()
    local stockParent = gearStock()
    local list = {}
    if stockParent then
        for _, stockValue in ipairs(stockParent:GetChildren()) do
            list[#list + 1] = stockValue.Name
        end
    end
    table.sort(list)
    return list
end
local function getCrateList()
    local stockParent = crateStock()
    local list = {}
    if stockParent then
        for _, stockValue in ipairs(stockParent:GetChildren()) do
            list[#list + 1] = stockValue.Name
        end
    end
    table.sort(list)
    return list
end
local function getCropList()
    local seen = {}
    local plot = myPlot()
    if plot then
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, pl in ipairs(plants:GetChildren()) do
                local s = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
                if s then
                    seen[s] = true
                end
            end
        end
    end
    local playerData = getData()
    if playerData and playerData.Inventory and playerData.Inventory.Seeds then
        for n in pairs(playerData.Inventory.Seeds) do
            seen[n] = true
        end
    end
    local list = {}
    for k in pairs(seen) do
        list[#list + 1] = k
    end
    table.sort(list)
    return list
end
local function getPetList()
    local playerData = getData()
    local seen = {}
    if playerData and playerData.Inventory and playerData.Inventory.Pets then
        for _, info in pairs(playerData.Inventory.Pets) do
            local nm = (type(info) == "table" and (info.PetType or info.Name)) or tostring(info)
            if nm and nm ~= "" then
                seen[nm] = true
            end
        end
    end
    local list = {}
    for k in pairs(seen) do
        list[#list + 1] = k
    end
    table.sort(list)
    return list
end
-- all species in the game (PetData catalog), sorted alphabetically
local function getAllPetSpecies()
    local seen, list = {}, {}
    for key, val in pairs(PetCache or {}) do
        if type(key) == "string" and type(val) == "table" and not seen[key] then
            seen[key] = true
            list[#list + 1] = key
        end
    end
    table.sort(list)
    return list
end

-- trowel tool names: tools carrying the "Trowel" attribute (e.g. "Basic Trowel")
local function getTrowelList()
    local seen = {}
    for _, parent in ipairs(getToolParents()) do
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local s = tool:GetAttribute("Trowel")
                if type(s) == "string" and s ~= "" then
                    seen[s] = true
                end
            end
        end
    end
    local list = {}
    for k in pairs(seen) do
        list[#list + 1] = k
    end
    table.sort(list)
    return list
end

-- sprinkler names from the game's SprinklerData module (SprinklerName field);
-- falls back to the tool's "Sprinkler" attribute values seen in inventory.
local function getSprinklerList()
    local seen = {}
    local sprData = tryRequire(function()
        local sm = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:WaitForChild("SharedModules", 10)
        return require(sm:FindFirstChild("SprinklerData") or sm:WaitForChild("SprinklerData", 5))
    end)
    if type(sprData) == "table" then
        for _, entry in ipairs(sprData) do
            if type(entry) == "table" and entry.SprinklerName then
                seen[entry.SprinklerName] = true
            end
        end
    end
    for _, parent in ipairs(getToolParents()) do
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local s = tool:GetAttribute("Sprinkler")
                if type(s) == "string" and s ~= "" then
                    seen[s] = true
                end
            end
        end
    end
    local playerData = getData()
    if playerData and playerData.Inventory and playerData.Inventory.Sprinklers then
        for k in pairs(playerData.Inventory.Sprinklers) do
            seen[tostring(k)] = true
        end
    end
    local list = {}
    for k in pairs(seen) do
        list[#list + 1] = k
    end
    table.sort(list)
    return list
end

-- normalize names for matching: lowercase, strip spaces/punctuation
-- so "Golden Dragonfly" == "GoldenDragonfly" (game mixes DisplayName vs internal keys)
local function normName(name)
    return tostring(name or ""):lower():gsub("[%s%p]+", "")
end

-- rarity lookup per species from PetData (normalized-key map rebuilt lazily)
local _petRarityCache = nil
local function getSpeciesRarity(species)
    if not _petRarityCache then
        _petRarityCache = {}
        for key, val in pairs(PetCache or {}) do
            if type(val) == "table" and type(val.Rarity) == "string" then
                _petRarityCache[normName(key)] = val.Rarity
                if type(val.DisplayName) == "string" then
                    _petRarityCache[normName(val.DisplayName)] = val.Rarity
                end
            end
        end
    end
    return _petRarityCache[normName(species)]
end

local function getWildList()
    local list = {}
    for k, v in pairs(PetCache or {}) do
        if type(v) == "table" and type(k) == "string" then
            list[#list + 1] = k
        end
    end
    table.sort(list)
    return list
end
local function getBestSeed()
    local playerData = getData()
    local seeds = playerData and playerData.Inventory and playerData.Inventory.Seeds
    if not seeds then
        return nil
    end
    local bestSeedName, bestScore
    for name, count in pairs(seeds) do
        if (count or 0) > 0 then
            -- value-per-time: sell value scaled by growth rate so fast crops win
            local val = (SeedBaseValue[name] or 0) * growRateFor(name)
            if not bestScore or val > bestScore then
                bestSeedName, bestScore = name, val
            end
        end
    end
    return bestSeedName, bestScore
end
local function getFruitCount()
    return client:GetAttribute("FruitCount") or 0
end
local function getMaxCapacity()
    return client:GetAttribute("MaxFruitCapacity") or 100
end
local function isInventoryFull()
    return getFruitCount() >= getMaxCapacity()
end
local function getExpansionLevel()
    local plot = myPlot()
    return plot and tonumber(plot:GetAttribute("GardenExpansion")) or 0
end

-- filter quintet matcher: checks fruit against rarity/mutation/threshold filters
local function matchesFilter(entry, fType, fRarity, fMutation, fThreshMode, fThreshold)
    -- 1. Check crop type selection (multi-select supported)
    if fType and Library.Flags[fType] then
        if not matchesSelection(Library.Flags[fType], entry.crop) then
            return false
        end
    end

    -- 2. Check rarity selection / minimum order
    local rar = firstValue(Library.Flags[fRarity] or {})
    if rar and rar ~= "" and rar ~= "Any" and rar ~= "All" then
        local entryRar = RARITY_ORDER[entry.rarity or "Common"] or 1
        local minRar = RARITY_ORDER[rar] or 1
        if entryRar < minRar then
            return false
        end
    end

    -- 3. Check mutation status
    local mut = firstValue(Library.Flags[fMutation] or {})
    if mut == "Mutated Only" and not entry.mutation then
        return false
    end
    if mut == "Non-Mutated Only" and entry.mutation then
        return false
    end

    -- 4. Check threshold mode (Weight or Value)
    local tm = firstValue(Library.Flags[fThreshMode] or {})
    local thresholdValue = tonumber(Library.Flags[fThreshold]) or 0
    if tm and tm ~= "Disabled" and thresholdValue > 0 then
        if tm == "Weight" and (entry.weight or 0) < thresholdValue then
            return false
        end
        if tm == "Value" and (entry.value or 0) < thresholdValue then
            return false
        end
    end
    return true
end

local PLANT_PATTERNS = { "Fill", "Checkerboard", "Rows", "Columns", "Diagonal", "Spaced" }
local function isRipe(m)
    if not m then
        return false
    end
    local age = tonumber(m:GetAttribute("Age"))
    local mx = tonumber(m:GetAttribute("MaxAge"))
    if age and mx then
        return age >= mx - 0.001
    end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("ProximityPrompt") and CollectionService:HasTag(d, "HarvestPrompt") then
            return true
        end
    end
    return false
end

-- get ripe crops with full metadata for filtering
local function getRipeCrops()
    local out = {}
    local plot = myPlot()
    if not plot then
        return out
    end
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return out
    end
    for _, plant in ipairs(plants:GetChildren()) do
        local fr = plant:FindFirstChild("Fruits")
        local fruits = fr and fr:GetChildren() or {}
        if #fruits > 0 then
            for _, m in ipairs(fruits) do
                if isRipe(m) then
                    local plantId = m:GetAttribute("PlantId") or plant:GetAttribute("PlantId")
                    if plantId then
                        local cropName = m:GetAttribute("CorePartName") or m:GetAttribute("SeedName") or ""
                            local mut = m:GetAttribute("Mutation") or plant:GetAttribute("Mutation")
                            local wt = tonumber(m:GetAttribute("SizeMultiplier") or m:GetAttribute("SizeMulti") or plant:GetAttribute("SizeMultiplier") or plant:GetAttribute("SizeMulti")) or 1
                            out[#out + 1] = {
                                model = m,
                                plantId = plantId,
                                fruitId = m:GetAttribute("FruitId") or "",
                                mutation = mut,
                                crop = cropName,
                                weight = wt,
                                rarity = m:GetAttribute("Rarity") or plant:GetAttribute("Rarity") or SeedRarity[cropName] or "Common",
                                value = ValueEngine.compute(cropName, (ValueDB.baseWeight[cropName] or 1) * wt, mut),
                            }
                    end
                end
            end
        elseif isRipe(plant) then
            local plantId = plant:GetAttribute("PlantId")
            if plantId then
                local cropName = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName") or ""
                local mut = plant:GetAttribute("Mutation")
                local wt = tonumber(plant:GetAttribute("SizeMultiplier") or plant:GetAttribute("SizeMulti")) or 1
                out[#out + 1] = {
                    model = plant,
                    plantId = plantId,
                    fruitId = "",
                    mutation = mut,
                    crop = cropName,
                    weight = wt,
                    rarity = plant:GetAttribute("Rarity") or SeedRarity[cropName] or "Common",
                    value = ValueEngine.compute(cropName, (ValueDB.baseWeight[cropName] or 1) * wt, mut),
                }
            end
        end
    end
    return out
end

-- get steal targets with full metadata
local function getStealTargets()
    local out = {}
    for _, p in ipairs(CollectionService:GetTagged("StealPrompt")) do
        local m = p.Parent and p.Parent:FindFirstAncestorWhichIsA("Model")
        if m then
            local ownerUserId = tonumber(m:GetAttribute("UserId"))
            if ownerUserId and ownerUserId ~= client.UserId and m:GetAttribute("PlantId") then
                local cropName = m:GetAttribute("SeedName") or m:GetAttribute("CorePartName") or ""
                out[#out + 1] = {
                    model = m,
                    plantId = m:GetAttribute("PlantId"),
                    fruitId = m:GetAttribute("FruitId") or "",
                    userId = ownerUserId,
                    hold = tonumber(p.HoldDuration) or 0,
                    crop = cropName,
                    mutation = m:GetAttribute("Mutation"),
                    weight = tonumber(m:GetAttribute("SizeMulti")) or 1,
                    rarity = m:GetAttribute("Rarity"),
                    value = ValueEngine.compute(
                        cropName,
                        (ValueDB.baseWeight[cropName] or 1) * (tonumber(m:GetAttribute("SizeMulti")) or 1),
                        m:GetAttribute("Mutation")
                    ),
                }
            end
        end
    end
    table.sort(out, function(a, b)
        return (a.value or 0) > (b.value or 0)
    end)
    return out
end

-- filter quintet matcher: checks fruit against rarity/mutation/threshold filters

-- soil/plant slot helpers
local function getSoilAreas(plot)
    local areas = {}
    for _, p in ipairs(CollectionService:GetTagged("PlantArea")) do
        if p:IsA("BasePart") and p:IsDescendantOf(plot) then
            areas[#areas + 1] = p
        end
    end
    if #areas == 0 then
        for _, desc in ipairs(plot:GetDescendants()) do
            if desc:IsA("BasePart") and desc:GetAttribute("PlantArea") then
                areas[#areas + 1] = desc
            end
        end
    end
    if #areas == 0 then
        for _, p in ipairs(CollectionService:GetTagged("GardenTotalArea")) do
            if p:IsA("BasePart") and p:IsDescendantOf(plot) then
                areas[#areas + 1] = p
            end
        end
    end
    if #areas == 0 then
        local ref = plot:FindFirstChild("PlotSizeReference")
        if ref then
            areas = { ref }
        end
    end
    return areas
end

-- snap a world XZ to the nearest PlantArea soil surface (mirrors the game client's TryPlant/TryWater raycast hit)
local function soilPositionAt(plot, x, z)
    if not plot then
        return nil
    end
    local best, bestDist = nil, math.huge
    for _, area in ipairs(getSoilAreas(plot)) do
        local ok, surface, dist = pcall(function()
            local localPos = area.CFrame:PointToObjectSpace(Vector3.new(x, area.Position.Y, z))
            local clampX = math.clamp(localPos.X, -area.Size.X / 2 + 0.5, area.Size.X / 2 - 0.5)
            local clampZ = math.clamp(localPos.Z, -area.Size.Z / 2 + 0.5, area.Size.Z / 2 - 0.5)
            local s = (area.CFrame * CFrame.new(clampX, area.Size.Y / 2 + 0.05, clampZ)).Position
            return s, (Vector2.new(s.X - x, s.Z - z)).Magnitude
        end)
        if ok and surface then
            if dist < 0.05 then
                return surface
            end
            if dist < bestDist then
                bestDist = dist
                best = surface
            end
        end
    end
    return best
end

-- dump backpack/character tools carrying attrName to console (diagnostics for tool-matching issues)
local function dumpTools(attrName)
    local seen = {}
    local function scanTools(container)
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") then
                    seen[#seen + 1] = tostring(t.Name) .. " [" .. tostring(attrName) .. "=" .. tostring(t:GetAttribute(attrName)) .. "]"
                end
            end
        end
    end
    scanTools(client.Character)
    scanTools(client:FindFirstChild("Backpack"))
    print("[GAG2] tools(" .. tostring(attrName) .. "): " .. (#seen > 0 and table.concat(seen, ", ") or "NONE"))
end

local function getPlantSlots(plot, pattern)
    pattern = pattern or "Fill"
    local stepSpacing = 3
    local seen, list = {}, {}
    for _, area in ipairs(getSoilAreas(plot)) do
        local cf = area.CFrame
        local size = area.Size
        local topY = area.Position.Y + size.Y / 2 + 0.3
        local halfExtentX = size.X / 2 - 1.5
        local halfExtentZ = size.Z / 2 - 1.5
        local gridCountX = math.max(0, math.floor((2 * halfExtentX) / stepSpacing))
        local gridCountZ = math.max(0, math.floor((2 * halfExtentZ) / stepSpacing))
        for ix = 0, gridCountX do
            for iz = 0, gridCountZ do
                local w = (cf * CFrame.new(-halfExtentX + ix * stepSpacing, 0, -halfExtentZ + iz * stepSpacing)).Position
                local gx, gz = math.floor(w.X / stepSpacing + 0.5), math.floor(w.Z / stepSpacing + 0.5)
                local keep = true
                if pattern == "Checkerboard" then
                    keep = (gx + gz) % 2 == 0
                elseif pattern == "Rows" then
                    keep = gz % 2 == 0
                elseif pattern == "Columns" then
                    keep = gx % 2 == 0
                elseif pattern == "Diagonal" then
                    keep = (gx - gz) % 3 == 0
                elseif pattern == "Spaced" then
                    keep = gx % 2 == 0 and gz % 2 == 0
                end
                if keep then
                    local key = math.floor(w.X / stepSpacing + 0.5) .. "," .. math.floor(w.Z / stepSpacing + 0.5)
                    if not seen[key] then
                        seen[key] = true
                        list[#list + 1] = Vector3.new(w.X, topY, w.Z)
                    end
                end
            end
        end
    end
    return list
end

local _slotCache = { plot = nil, pattern = nil, time = 0, grid = {} }
local function getOpenSlots(plot, pattern, sortPos)
    local now = os.time()
    local plants = plot:FindFirstChild("Plants")
    local plantCount = plants and #plants:GetChildren() or 0
    if _slotCache.plot ~= plot or _slotCache.pattern ~= pattern or _slotCache.time < now - 10 or _slotCache.plantCount ~= plantCount then
        local grid = getPlantSlots(plot, pattern)
        local occupiedPositions = {}
        if plants then
            for _, pl in ipairs(plants:GetChildren()) do
                local ok, pv = pcall(function()
                    return pl:GetPivot().Position
                end)
                if ok then
                    occupiedPositions[#occupiedPositions + 1] = pv
                end
            end
        end
        local free = {}
        for _, pos in ipairs(grid) do
            local clear = true
            for _, occ in ipairs(occupiedPositions) do
                if (Vector3.new(occ.X, 0, occ.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 2.5 then
                    clear = false
                    break
                end
            end
            if clear then
                free[#free + 1] = pos
            end
        end
        _slotCache = { plot = plot, pattern = pattern, time = now, plantCount = plantCount, grid = free }
    end
    local free = _slotCache.grid
    if sortPos and #free > 0 then
        table.sort(free, function(a, b)
            return (Vector3.new(a.X, 0, a.Z) - Vector3.new(sortPos.X, 0, sortPos.Z)).Magnitude
                < (Vector3.new(b.X, 0, b.Z) - Vector3.new(sortPos.X, 0, sortPos.Z)).Magnitude
        end)
    end
    return free
end

-- pack grabber helpers
local function packType(loc)
    if loc:GetAttribute("GoldSeed") == true then
        return "Gold Seed"
    end
    if loc:GetAttribute("RainbowSeed") == true then
        return "Rainbow Seed"
    end
    if loc:GetAttribute("SeedPack") ~= nil then
        return tostring(loc:GetAttribute("SeedPack"))
    end
    return nil
end

local function isRareSeedPack(loc)
    if loc:GetAttribute("GoldSeed") == true or loc:GetAttribute("RainbowSeed") == true then
        return true
    end
    local sp = loc:GetAttribute("SeedPack")
    return type(sp) == "string" and (sp:lower():find("gold") ~= nil or sp:lower():find("rainbow") ~= nil)
end

local function holdSeedPrompts(pos)
    local map = Workspace:FindFirstChild("Map")
    for _, cont in ipairs({
        map and map:FindFirstChild("SeedPackSpawnServerLocations"),
        map and map:FindFirstChild("SeedPackSpawnClient"),
        Workspace:FindFirstChild("Temporary"),
    }) do
        if cont then
            for _, d in ipairs(cont:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    local p = d.Parent
                    local ok, pp = pcall(function()
                        return p.Position
                    end)
                    if (not ok) or (pp - pos).Magnitude <= 35 then
                        pcall(function()
                            local hold = tonumber(d.HoldDuration) or 0
                            if fireproximityprompt then
                                fireproximityprompt(d, math.max(hold, 0))
                            else
                                d:InputHoldBegin()
                                task.wait(hold + 0.1)
                                d:InputHoldEnd()
                            end
                        end)
                    end
                end
            end
        end
    end
end

local function locPos(loc)
    if loc:IsA("BasePart") then
        return loc.Position
    end
    local ok, cf = pcall(function()
        return loc:GetPivot()
    end)
    if ok then
        return cf.Position
    end
    local bp = loc:IsA("BasePart") and loc or loc:FindFirstChildWhichIsA("BasePart", true)
    return bp and bp.Position or nil
end

local function grabPackRobust(loc)
    local landed = false
    for _ = 1, 90 do
        if not (loc and loc.Parent) then
            break
        end
        local pos = locPos(loc)
        if not pos then
            break
        end
        local rootPart = getHRP()
        if not rootPart then
            break
        end
        if (not landed) or ((rootPart.Position - pos).Magnitude > 6) then
            teleport(pos)
            landed = true
        end
        for _, d in ipairs(loc:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                pcall(function()
                    local h = tonumber(d.HoldDuration) or 0
                    if fireproximityprompt then
                        fireproximityprompt(d, math.max(h, 0))
                    else
                        d:InputHoldBegin()
                        task.wait(h + 0.1)
                        d:InputHoldEnd()
                    end
                end)
            end
        end
        holdSeedPrompts(pos)
        local part = loc:IsA("BasePart") and loc or loc:FindFirstChildWhichIsA("BasePart", true)
        if firetouchinterest and part then
            pcall(function()
                firetouchinterest(rootPart, part, 0)
                firetouchinterest(rootPart, part, 1)
            end)
        end
        task.wait(0.12)
    end
end

-- shovel helpers
local function findShovel()
    local function scan(cont)
        if cont then
            for _, c in ipairs(cont:GetChildren()) do
                if c:IsA("Tool") and (c:GetAttribute("Shovel") ~= nil or c.Name:lower():find("shovel")) then
                    return c
                end
            end
        end
    end
    return scan(client.Character) or scan(client:FindFirstChild("Backpack"))
end

local function equipShovel()
    local sh = findShovel()
    if not sh then
        return nil
    end
    local humanoid = getHumanoid()
    if humanoid and sh.Parent ~= client.Character then
        pcall(function()
            humanoid:EquipTool(sh)
        end)
        task.wait(0.3)
    end
    return sh
end

-- webhook
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
                        footer = { text = client.Name .. " | GAG2" },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    },
                },
                username = Library.Flags["whName"] or "GAG2 Bot",
            }),
        })
    end)
end

-- server hop (uses TeleportService directly - no external API needed)
local function serverHop(lowPop)
    notify("Server Hop", "Teleporting to a new server...")
    if Library.Flags["whHop"] then
        sendWebhook("Server Hop", "Hopped to new server", 5763719)
    end
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
                    notify("Server Hop", "Hopping to server with " .. best.playing .. " players.")
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, client)
                    return
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, client)
    end)
end

local function removeOtherGardens()
    local g = Workspace:FindFirstChild("Gardens")
    if not g then
        return 0
    end
    local me = client.UserId
    local n = 0
    for _, plot in ipairs(g:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") ~= me then
            pcall(function()
                plot.Parent = nil
            end)
            n = n + 1
        end
    end
    return n
end

-- sell preview: shows what your inventory would sell for without actually selling
local function doSellPreview()
    local ok, val = pcall(function()
        return netCall("NPCS.PreviewSellAll")
    end)
    if ok and type(val) == "table" then
        local total = tonumber(val.TotalSellValue) or tonumber(val.TotalValue) or tonumber(val.TotalBaseValue) or 0
        local n = tonumber(val.FruitCount) or 0
        notify("Sell Preview", ("Worth %s across %d fruits"):format(fmtCash(total), n))
    elseif ok then
        notify("Sell Preview", "Estimated value: " .. fmtCash(tonumber(val) or 0))
    else
        notify("Sell Preview", "Could not get preview", "warning")
    end
end

-- mutation scanner: logs all mutated fruits in tracked fruitData
local function doMutationScan()
    local found = 0
    local list = {}
    for fid, fd in pairs(fruitData) do
        if fd.mutated then
            found = found + 1
            print("[MUTATION] Fruit:", fid, "Name:", fd.name, "Plant:", fd.plantId)
            list[#list + 1] = fd.name or "?"
        end
    end
    if found > 0 then
        notify("Mutation Scanner", "Found " .. found .. " mutated fruits: " .. table.concat(list, ", "))
        if Library.Flags["whBigHarvest"] then
            sendWebhook(
                "Mutations Found",
                "Found " .. found .. " mutated fruits",
                12255232,
                { { name = "Fruits", value = table.concat(list, ", ") } }
            )
        end
    else
        notify("Mutation Scanner", "No mutations found yet.")
    end
end

-- harvest only mutated fruits (direct-remote via fruitData)
local function doHarvestMutated()
    local used = 0
    for fid, fd in pairs(fruitData) do
        if fd.mutated and fd.grown then
            netFire("Garden.CollectFruit", fd.plantId, fid)
            used = used + 1
            task.wait(jitter(0.05, 0.015))
        end
    end
    if used > 0 then
        notify("Harvest Mutated", "Collected " .. used .. " mutated fruits!")
        sessionHarvests = sessionHarvests + used
    else
        notify("Harvest Mutated", "No mutated fruits ready", "warning")
    end
end



-- ================================================================
-- VALUE ESP (world-space price tags using the exact sell value engine)
-- ================================================================
do
    local _vPool = {}
    local _vTotal = nil
    local _vTotalLabel = nil
    local _vSubLabel = nil
    local _vInvTotal = nil
    local _vInvLabel = nil
    local _vInvSubLabel = nil
    local function clearValuePool()
        for model, entry in pairs(_vPool) do
            pcall(function()
                entry.bb:Destroy()
            end)
        end
        _vPool = {}
    end
    local function anchorPart(model)
        if model:IsA("BasePart") then
            return model
        end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end
    local function newTag(part)
        local bb = Instance.new("BillboardGui")
        bb.Name = "GAG2ValueESP"
        bb.Adornee = part
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(160, 42)
        bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
        bb.MaxDistance = 180
        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Size = UDim2.new(1, 0, 0.55, 0)
        val.Font = Enum.Font.GothamBold
        val.TextSize = 15
        val.TextColor3 = Color3.fromRGB(120, 235, 130)
        val.Text = ""
        local stk = Instance.new("UIStroke")
        stk.Thickness = 1.5
        stk.Color = Color3.fromRGB(0, 0, 0)
        stk.Parent = val
        val.Parent = bb
        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1
        sub.Size = UDim2.new(1, 0, 0.45, 0)
        sub.Position = UDim2.new(0, 0, 0.55, 0)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextColor3 = Color3.fromRGB(235, 235, 235)
        sub.Text = ""
        local stk2 = Instance.new("UIStroke")
        stk2.Thickness = 1.2
        stk2.Color = Color3.fromRGB(0, 0, 0)
        stk2.Parent = sub
        sub.Parent = bb
        bb.Parent = CoreGui
        return { bb = bb, val = val, sub = sub, lastVal = "", lastSub = "" }
    end
    local function ensureTotalPanel()
        if _vTotal and _vTotal.Parent then
            return true
        end
        local ok = pcall(function()
            local host = (gethui and gethui()) or CoreGui
            local sg = Instance.new("ScreenGui")
            sg.Name = "GAG2ValueHUD"
            sg.ResetOnSpawn = false
            sg.IgnoreGuiInset = true
            sg.DisplayOrder = 59
            local f = Instance.new("Frame")
            f.Name = "Main"
            f.AnchorPoint = Vector2.new(0, 1)
            f.Position = UDim2.new(0, 12, 1, -160)
            f.Size = UDim2.fromOffset(190, 56)
            f.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
            f.BackgroundTransparency = 0.22
            f.BorderSizePixel = 0
            f.Parent = sg
            local cr = Instance.new("UICorner")
            cr.CornerRadius = UDim.new(0, 8)
            cr.Parent = f
            local st = Instance.new("UIStroke")
            st.Color = Color3.fromRGB(60, 60, 72)
            st.Thickness = 1
            st.Transparency = 0.4
            st.Parent = f
            local t1 = Instance.new("TextLabel")
            t1.BackgroundTransparency = 1
            t1.Size = UDim2.new(1, -12, 0, 24)
            t1.Position = UDim2.new(0, 6, 0, 6)
            t1.Font = Enum.Font.GothamBold
            t1.TextSize = 15
            t1.TextColor3 = Color3.fromRGB(120, 235, 130)
            t1.TextXAlignment = Enum.TextXAlignment.Left
            t1.Text = "Garden Value: -"
            t1.Parent = f
            local t2 = Instance.new("TextLabel")
            t2.BackgroundTransparency = 1
            t2.Size = UDim2.new(1, -12, 0, 16)
            t2.Position = UDim2.new(0, 6, 0, 30)
            t2.Font = Enum.Font.Gotham
            t2.TextSize = 11
            t2.TextColor3 = Color3.fromRGB(200, 200, 205)
            t2.TextXAlignment = Enum.TextXAlignment.Left
            t2.Text = "exact sell math"
            t2.Parent = f
            sg.Parent = host
            _vTotal, _vTotalLabel, _vSubLabel = sg, t1, t2
        end)
        return ok and _vTotal ~= nil
    end
    local function ensureInvPanel()
        if _vInvTotal and _vInvTotal.Parent then
            return true
        end
        local ok = pcall(function()
            local host = (gethui and gethui()) or CoreGui
            local sg = Instance.new("ScreenGui")
            sg.Name = "GAG2InvValueHUD"
            sg.ResetOnSpawn = false
            sg.IgnoreGuiInset = true
            sg.DisplayOrder = 58
            local f = Instance.new("Frame")
            f.Name = "Main"
            f.AnchorPoint = Vector2.new(1, 1)
            f.Position = UDim2.new(1, -12, 1, -12)
            f.Size = UDim2.fromOffset(190, 56)
            f.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
            f.BackgroundTransparency = 0.22
            f.BorderSizePixel = 0
            f.Parent = sg
            local cr = Instance.new("UICorner")
            cr.CornerRadius = UDim.new(0, 8)
            cr.Parent = f
            local st = Instance.new("UIStroke")
            st.Color = Color3.fromRGB(60, 60, 72)
            st.Thickness = 1
            st.Transparency = 0.4
            st.Parent = f
            local t1 = Instance.new("TextLabel")
            t1.BackgroundTransparency = 1
            t1.Size = UDim2.new(1, -12, 0, 24)
            t1.Position = UDim2.new(0, 6, 0, 6)
            t1.Font = Enum.Font.GothamBold
            t1.TextSize = 15
            t1.TextColor3 = Color3.fromRGB(255, 200, 100)
            t1.TextXAlignment = Enum.TextXAlignment.Left
            t1.Text = "Inventory Value: -"
            t1.Parent = f
            local t2 = Instance.new("TextLabel")
            t2.BackgroundTransparency = 1
            t2.Size = UDim2.new(1, -12, 0, 16)
            t2.Position = UDim2.new(0, 6, 0, 30)
            t2.Font = Enum.Font.Gotham
            t2.TextSize = 11
            t2.TextColor3 = Color3.fromRGB(200, 200, 205)
            t2.TextXAlignment = Enum.TextXAlignment.Left
            t2.Text = "inventory fruit value"
            t2.Parent = f
            sg.Parent = host
            _vInvTotal, _vInvLabel, _vInvSubLabel = sg, t1, t2
        end)
        return ok and _vInvTotal ~= nil
    end
    local function computeInvValue()
        local d = getData()
        local invVal = 0
        local count = 0
        local hf = d and d.Inventory and d.Inventory.HarvestedFruits
        if hf then
            for _, finfo in pairs(hf) do
                if type(finfo) == "table" then
                    local fname = finfo.FruitName or finfo.Seed or finfo.Name or ""
                    local weight = tonumber(finfo.SizeMultiplier or finfo.Weight or finfo.SizeMulti or 1) or 1
                    local mname = type(finfo.Mutation) == "string" and finfo.Mutation or nil
                    invVal = invVal + ValueEngine.compute(fname, weight, mname)
                    count = count + 1
                elseif type(finfo) == "number" then
                    invVal = invVal + finfo
                    count = count + 1
                end
            end
        end
        -- fruits live in the player's backpack as Tools (game grid renders from there)
        if count == 0 then
            for _, parent in ipairs(getToolParents()) do
                for _, tool in ipairs(parent:GetChildren()) do
                    if tool:IsA("Tool") and (tool:GetAttribute("HarvestedFruit") or tool:GetAttribute("FruitName")) then
                        local fname = tool:GetAttribute("FruitName") or tool:GetAttribute("Seed") or tool.Name or ""
                        local weight = tonumber(tool:GetAttribute("SizeMultiplier") or tool:GetAttribute("Weight") or 1) or 1
                        local mname = tool:GetAttribute("Mutation")
                        if type(mname) ~= "string" then
                            mname = nil
                        end
                        invVal = invVal + ValueEngine.compute(fname, weight, mname)
                        count = count + 1
                    end
                end
            end
        end
        local now = os.time()
        if now ~= _lastInvDbg then
            _lastInvDbg = now
            local sample = ""
            if hf then
                local n = 0
                for k, v in pairs(hf) do
                    if n < 2 then
                        sample = sample .. " " .. tostring(k) .. "="
                            .. (type(v) == "table" and (tostring(v.FruitName or v.Name or v.Seed or "?") .. "/" .. tostring(v.SizeMultiplier or v.Weight or "?")) or tostring(v))
                    end
                    n = n + 1
                end
            end
            DebugLog("invValue", "data=" .. tostring(d ~= nil), "inv=" .. tostring(d and d.Inventory ~= nil),
                "hf=" .. tostring(type(hf)), "count=" .. tostring(count), "val=" .. tostring(invVal),
                "FVC=" .. tostring(FruitValueCalc ~= nil), "sellLive=" .. tostring(ValueDB.sellLive ~= nil),
                "invKeys=" .. (d and d.Inventory and type(d.Inventory) == "table" and (function()
                    local ks = {}
                    for k in pairs(d.Inventory) do
                        ks[#ks + 1] = tostring(k)
                    end
                    table.sort(ks)
                    return table.concat(ks, ",")
                end)() or "?") ..
                " sample[" .. tostring(hf and (function()
                    local c = 0
                    for _ in pairs(hf) do
                        c = c + 1
                    end
                    return c
                end)() or 0) .. "]" .. sample)
        end
        return invVal, count
    end
    ValueESP = {}
    local _lastInvDbg = 0
    ValueESP.update = function()
        local onTags = Library.Flags["espFruitValue"] == true
        local onTotal = Library.Flags["espTotalValue"] == true
        local onInv = Library.Flags["espInvValue"] == true
        if not onTags and not onTotal and not onInv then
            if next(_vPool) then
                clearValuePool()
            end
            if _vTotal then
                _vTotal.Enabled = false
            end
            if _vInvTotal then
                _vInvTotal.Enabled = false
            end
            return
        end
        local baseOnly = Library.Flags["espBaseValueOnly"] == true
        local garden = myPlot()
        local seen = {}
        local total, count = 0, 0
        local function tagModel(model)
            if seen[model] then
                return
            end
            seen[model] = true
            local w, crop = ValueEngine.weightOf(model)
            if not crop or crop == "" then
                return
            end
            local mut = model:GetAttribute("Mutation")
            local v = ValueEngine.compute(crop, w, mut, baseOnly)
            if v <= 0 then
                return
            end
            total = total + v
            count = count + 1
            if not onTags then
                return
            end
            local part = anchorPart(model)
            if not part then
                return
            end
            local valText = fmtCash(v)
                .. ((type(mut) == "string" and mut ~= "" and not baseOnly) and (" [" .. mut .. "]") or "")
            local subText = tostring(crop) .. "  "
                .. (baseOnly and "base" or string.format("%.2fkg", w))
            local entry = _vPool[model]
            if not entry then
                entry = newTag(part)
                _vPool[model] = entry
            end
            if entry.lastVal ~= valText then
                entry.val.Text = valText
                entry.lastVal = valText
                entry.val.TextColor3 = (type(mut) == "string" and mut ~= "" and not baseOnly)
                        and Color3.fromRGB(255, 215, 100)
                    or Color3.fromRGB(120, 235, 130)
            end
            if entry.lastSub ~= subText then
                entry.sub.Text = subText
                entry.lastSub = subText
            end
        end
        local plants = garden and garden:FindFirstChild("Plants")
        if plants then
            for _, plantModel in ipairs(plants:GetChildren()) do
                if plantModel:GetAttribute("PlantId") then
                    tagModel(plantModel)
                end
                local fruitsFolder = plantModel:FindFirstChild("Fruits")
                if fruitsFolder then
                    for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                        if fruitModel:GetAttribute("FruitId") then
                            tagModel(fruitModel)
                        end
                    end
                end
            end
        end
        -- cleanup: dead models or entries not seen this cycle
        for model, entry in pairs(_vPool) do
            if (not model.Parent) or (onTags and not seen[model]) or not onTags then
                pcall(function()
                    entry.bb:Destroy()
                end)
                _vPool[model] = nil
            end
        end
        if onTotal then
            if ensureTotalPanel() then
                _vTotal.Enabled = true
                _vTotalLabel.Text = "Garden Value: " .. fmtCash(total)
                _vSubLabel.Text = tostring(count) .. " plants & fruits" .. (baseOnly and " (base)" or "")
            end
        elseif _vTotal then
            _vTotal.Enabled = false
        end
        if onInv then
            local invVal, invCount = computeInvValue()
            if ensureInvPanel() then
                _vInvTotal.Enabled = true
                _vInvLabel.Text = "Inventory Value: " .. fmtCash(invVal)
                _vInvSubLabel.Text = tostring(invCount) .. " fruits" .. (baseOnly and " (base)" or "")
            end
        elseif _vInvTotal then
            _vInvTotal.Enabled = false
        end
    end
    ValueESP.destroy = function()
        clearValuePool()
        pcall(function()
            if _vTotal then
                _vTotal:Destroy()
            end
        end)
        _vTotal, _vTotalLabel, _vSubLabel = nil, nil, nil
        pcall(function()
            if _vInvTotal then
                _vInvTotal:Destroy()
            end
        end)
        _vInvTotal, _vInvLabel, _vInvSubLabel = nil, nil, nil
    end
end -- scoped: value ESP

-- ================================================================
-- FEATURE FUNCTIONS
-- ================================================================

local function doHarvest(forceAll)
    local collected = 0
    local mode = forceAll and "All" or (firstValue(Library.Flags["collectFilter"] or {}) or "All")
    if Library.Flags["autoCollectAll"] then
        mode = "All"
    elseif Library.Flags["autoCollectBest"] then
        mode = "Best"
    elseif Library.Flags["enableFilters"] and mode ~= "Best" then
        mode = "Filtered"
    end
    local targets = getRipeCrops()
    if #targets == 0 and next(fruitData) then
        DebugLog("doHarvest", "no ripe crop models, fallback fruitData=" .. tostring(next(fruitData) ~= nil))
        for fruitId, fd in pairs(fruitData) do
            if fd.grown and fd.plantId then
                local cropName = fd.name or ""
                local mutName = nil
                if fd.mutated then
                    if type(fd.mutations) == "string" then
                        mutName = fd.mutations
                    elseif type(fd.mutations) == "table" then
                        mutName = next(fd.mutations)
                    end
                end
                local wt = tonumber(fd.weight) or (ValueDB.baseWeight[cropName] or 1)
                targets[#targets + 1] = {
                    model = nil,
                    plantId = fd.plantId,
                    fruitId = fruitId,
                    crop = cropName,
                    mutation = mutName,
                    value = ValueEngine.compute(cropName, wt, mutName),
                    weight = wt,
                    rarity = SeedRarity[cropName] or "Common",
                }
            end
        end
    end

    if mode == "Best" and #targets > 0 then
        table.sort(targets, function(a, b)
            return (a.value or 0) > (b.value or 0)
        end)
        local bestVal = targets[1].value or 0
        local filtered = {}
        for _, t in ipairs(targets) do
            if (t.value or 0) >= bestVal then
                filtered[#filtered + 1] = t
            end
        end
        targets = filtered
    end

    if #targets > 0 then
        DebugLog("doHarvest", "mode=" .. mode, "targets=" .. #targets)
        local plot = myPlot()
        local ref = plot and plot:FindFirstChild("PlotSizeReference")
        local rootPart = getHRP()
        if not Library.Flags["collectNoTp"] and ref and rootPart then
            if (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(ref.Position.X, 0, ref.Position.Z)).Magnitude > 16 then
                teleport(ref.Position)
                task.wait(0.12)
            end
        end
        -- fire the real CollectFruit remote for every ripe fruit
        -- no prompt simulation - the server validates the request itself
        for _, entry in ipairs(targets) do
            local skip = false
            if mode == "Filtered" then
                if not matchesFilter(entry, "collectFruit", "collectRarity", "collectMutation", "collectThreshMode", "collectThreshold") then
                    skip = true
                end
            end
            if Library.Flags["mutatedOnly"] and not entry.mutation then
                skip = true
            end
            if Library.Flags["stopOnFull"] and isInventoryFull() then
                break
            end
            if not skip then
                netFire("Garden.CollectFruit", entry.plantId, entry.fruitId or "")
                collected = collected + 1
                task.wait(jitter(tonumber(Library.Flags["collectDelay"]) or 0.05, 0.02))
            end
        end
    elseif not forceAll then
        DebugLog("doHarvest", "no targets", "ripe=" .. #targets, "fruitData=" .. tostring(next(fruitData) ~= nil))
    end
    if collected > 0 then
        DebugLog("doHarvest", "collected=" .. collected, "mode=" .. mode)
    end
    return collected
end

local function findSeedTool(seedName)
    local bp = client and client:FindFirstChild("Backpack")
    local scan = function(parent)
        if not parent then
            return nil
        end
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local sn = tool:GetAttribute("SeedTool")
                if sn and (not seedName or sn == seedName) then
                    return tool
                end
            end
        end
        return nil
    end
    local tool = scan(bp)
    if tool then
        return tool
    end
    local char = client and client.Character
    return scan(char)
end

local function getEquippedSeedName()
    local char = client and client.Character
    local tool = char and char:FindFirstChildWhichIsA("Tool")
    if tool then
        return tool:GetAttribute("SeedTool"), tool
    end
    return nil, nil
end

local function doPlant()
    local plot = myPlot()
    if not plot then
        return
    end
    if not Library.Flags["plantNoTp"] then
        nearPlot()
    end
    local playerData = getData()
    local seeds = playerData and playerData.Inventory and playerData.Inventory.Seeds
    if not seeds then
        return
    end
    -- resolve which seeds to plant
    local seedFilter = Library.Flags["plantSeeds"]
    local hasFilter = false
    if type(seedFilter) == "table" and next(seedFilter) ~= nil then
        hasFilter = true
    elseif type(seedFilter) == "string" and seedFilter ~= "" then
        hasFilter = true
    end
    if Library.Flags["autoPlantAll"] then
        hasFilter = false -- Auto Plant All ignores the seed dropdown entirely
    end
    local toPlant = {}
    if Library.Flags["smartReplant"] then
        -- plant only the most profitable seed you own
        local best = getBestSeed()
        if best then
            local keep = Library.Flags["seedReserve"] and (tonumber(Library.Flags["reserveCount"]) or 0) or 0
            for _ = 1, math.max(0, (seeds[best] or 0) - keep) do
                toPlant[#toPlant + 1] = best
            end
        end
    else
        for name, count in pairs(seeds) do
            if hasFilter then
                local match = false
                if type(seedFilter) == "table" then
                    for key, val in pairs(seedFilter) do
                        local filterName = type(key) == "number" and val or key
                        if type(filterName) == "string" and name:lower() == filterName:lower() then
                            match = true
                            break
                        end
                    end
                elseif type(seedFilter) == "string" then
                    if name:lower() == seedFilter:lower() then
                        match = true
                    end
                end
                if match then
                    for _ = 1, count or 0 do
                        toPlant[#toPlant + 1] = name
                    end
                end
            else
                for _ = 1, count or 0 do
                    toPlant[#toPlant + 1] = name
                end
            end
        end
    end
    if #toPlant == 0 then
        return
    end
    -- seed reserve: filter out seed types below the keep-n threshold
    if Library.Flags["seedReserve"] then
        local keep = math.max(0, tonumber(Library.Flags["reserveCount"]) or 0)
        if keep > 0 then
            local reserved = {}
            for _, seedName in ipairs(toPlant) do
                local owned = (seeds[seedName] or 0)
                if owned > keep then
                    reserved[#reserved + 1] = seedName
                end
            end
            toPlant = reserved
        end
    end
    if #toPlant == 0 then
        return
    end
    -- resolve plant position via mode dropdown (Random/Saved/Player/Near Fruit/Sprinkler Radius)
    local plantMode = firstValue(Library.Flags["plantPosition"] or {}) or "Random"
    local sortPosition = nil
    if plantMode == "Saved Position" then
        local saved = Library.Flags["savedPlantPos"]
        if type(saved) == "Vector3" then
            sortPosition = saved
        elseif type(saved) == "table" and saved.X and saved.Y and saved.Z then
            sortPosition = Vector3.new(saved.X, saved.Y, saved.Z)
        end
    elseif plantMode == "Player Position" then
        sortPosition = getHRP() and getHRP().Position
    elseif plantMode == "Near Fruit" then
        local ripe = getRipeCrops()
        if #ripe > 0 and ripe[1].model then
            sortPosition = ripe[1].model:GetPivot().Position
        end
    elseif plantMode == "Sprinkler Radius" then
        local sprinklers = plot:FindFirstChild("Sprinklers")
        if sprinklers and #sprinklers:GetChildren() > 0 then
            sortPosition = sprinklers:GetChildren()[1]:GetPivot().Position
        end
    end
    -- find open soil slots
    local free = getOpenSlots(plot, firstValue(Library.Flags["plantPattern"]) or "Fill", sortPosition)
    if #free == 0 then
        DebugLog("doPlant", "no free slots")
        return
    end
    local cap = math.min(#free, #toPlant)
    if not Library.Flags["autoPlantAll"] then
        cap = math.min(#free, #toPlant, tonumber(Library.Flags["maxPerCycle"]) or 80)
    end
    local delay = math.max(0.02, tonumber(Library.Flags["plantDelay"]) or 0.05)
    if Library.Flags["autoPlantAll"] then
        delay = math.max(0.01, delay * 0.5)
    end
    -- group toPlant by seed name so we equip each seed tool only once
    local grouped = {}
    local order = {}
    for i = 1, cap do
        local seedName = toPlant[i]
        if not grouped[seedName] then
            grouped[seedName] = { seed = seedName, slots = {} }
            order[#order + 1] = grouped[seedName]
        end
        grouped[seedName].slots[#grouped[seedName].slots + 1] = free[i]
    end
    local planted = 0
    DebugLog("doPlant", "slots=" .. #free, "groups=" .. #order, "cap=" .. cap)
    for _, group in ipairs(order) do
        local seedName = group.seed
        -- find the seed tool (backpack first, then character)
        local tool = findSeedTool(seedName)
        if tool then
            -- equip it; server-side PlantController validates the tool instance
            local equipped, equippedTool = getEquippedSeedName()
            if equipped ~= seedName then
                if equipTool(tool) then
                    equipped, equippedTool = getEquippedSeedName()
                end
            end
            if equippedTool then
                for _, pos in ipairs(group.slots) do
                    if not Library.Flags["autoPlant"] and not Library.Flags["autoPlantAll"] then
                        break
                    end
                    -- verify still equipped before each fire, re-equip if consumed
                    local curSn, curTool = getEquippedSeedName()
                    if not curTool then
                        tool = findSeedTool(seedName)
                        if not tool then
                            break
                        end
                        if not equipTool(tool) then
                            break
                        end
                        curSn, curTool = getEquippedSeedName()
                    end
                    if not curTool then
                        break
                    end
                    netFire("Plant.PlantSeed", pos, seedName, curTool)
                    planted = planted + 1
                    task.wait(jitter(delay, delay * 0.15))
                end
            end
        end
    end
    DebugLog("doPlant", "cycle done, planted=" .. planted)
    return planted
end

local function isOwnerHome(userId)
    if not userId then
        return false
    end
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then
        return false
    end
    for _, plot in ipairs(gardens:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == userId then
            local pg = client and client:FindFirstChildOfClass("PlayerGui")
            if pg then
                for _, bg in ipairs(pg:GetChildren()) do
                    if bg:IsA("BillboardGui") and bg.Adornee and bg.Adornee:IsDescendantOf(plot) then
                        local pf = bg:FindFirstChild("PlayerFrame")
                        local unlocked = pf and pf:FindFirstChild("Unlocked")
                        if unlocked and unlocked:IsA("ImageButton") then
                            return not unlocked.Visible
                        end
                        return false
                    end
                end
            end
            return false
        end
    end
    return false
end

local function doSteal()
    -- steal is night-only: the game client itself checks ReplicatedStorage.Night == true before BeginSteal
    if not isNight() then
        return
    end
    local targets = getStealTargets()
    if #targets == 0 then
        return
    end
    local mode = firstValue(Library.Flags["stealFilter"] or {}) or "All"
    if Library.Flags["autoStealBest"] or mode == "Best" then
        table.sort(targets, function(a, b)
            return (a.value or 0) > (b.value or 0)
        end)
    end
    local bestStealValue = (mode == "Best" or Library.Flags["autoStealBest"]) and (targets[1].value or 0) or 0
    local home = getHRP() and getHRP().Position
    local lastPosition
    for _, t in ipairs(targets) do
        local valid = true
        if mode == "Filtered" then
            if not matchesFilter(t, "stealFruit", "stealRarity", "stealMutation", nil, nil) then
                valid = false
            end
        elseif mode == "Best" or Library.Flags["autoStealBest"] then
            if (t.value or 0) < bestStealValue then
                valid = false
            end
        end
        local pos = (t.model and t.model.Parent) and t.model:GetPivot().Position or nil
        if valid and pos and Library.Flags["skipIfOwnerHome"] and isOwnerHome(t.userId) then
            valid = false
        end
        if valid and pos then
            if not lastPosition or (pos - lastPosition).Magnitude > 12 then
                teleport(pos)
                lastPosition = pos
                task.wait(0.22) -- settle: let the new position replicate to the server before firing
            end
            netFire("Steal.BeginSteal", t.userId, t.plantId, t.fruitId)
            -- game client fires CompleteSteal immediately for HoldDuration==0 prompts;
            -- only hold-type prompts need the hold window (with evasion) before completing
            local holdTime = tonumber(t.hold) or 0
            if holdTime > 0 then
                local elapsed = 0
                while elapsed < holdTime + 0.1 and Hub.running do
                    task.wait(0.08)
                    elapsed = elapsed + 0.08
                    if Library.Flags["stealEvasion"] then
                        for _, pl in ipairs(Players:GetPlayers()) do
                            if pl ~= client and pl.Character and (t.userId == pl.UserId or pl.Character:FindFirstChild("Shovel") or pl.Character:FindFirstChild("Crowbar")) then
                                local phrp = pl.Character:FindFirstChild("HumanoidRootPart")
                                local myhrp = getHRP()
                                if phrp and myhrp and (phrp.Position - myhrp.Position).Magnitude < 18 then
                                    teleport(myhrp.Position + Vector3.new(0, 35, 0), true)
                                    break
                                end
                            end
                        end
                    end
                end
            end
            netFire("Steal.CompleteSteal")
            -- multi-carry: fire CompleteSteal N times so the server registers several fruits
            -- in the same steal session (server counts each completion)
            local mult = math.max(1, tonumber(Library.Flags["stealMult"]) or 1)
            for _ = 2, mult do
                netFire("Steal.CompleteSteal")
                task.wait(0.05)
            end
            task.wait(jitter(tonumber(Library.Flags["stealDelay"]) or 0.25, 0.05))
            if Library.Flags["autoStealBest"] or mode == "Best" then
                break
            end
        end
    end
    if Library.Flags["stealReturn"] and home then
        teleport(home - Vector3.new(0, 3, 0))
    end
end

local function doSellAll()
    -- smart sell: respect daily deal toggle for bonus
    if Library.Flags["dailyDeal"] then
        netFire("NPCS.UseDailyDealAll")
    else
        netFire("NPCS.SellAll")
    end
    -- track profit from sell: snapshot balance before next cycle
    local balNow = getBalance()
    if not sellBaseline then
        sellBaseline = balNow
    end
    local profit = balNow - sellBaseline
    if profit > 5000 then
        sessionEarned = sessionEarned + profit
        if profit > 100000 and Library.Flags["whBigHarvest"] then
            sendWebhook("BIG Sell", "Sold " .. fmtCash(profit) .. " worth of crops!", 5763719)
        end
    end
    sellBaseline = nil
end

local function doSellSelective()
    local playerData = getData()
    if not (playerData and playerData.Inventory) then
        return
    end
    local fruits = playerData.Inventory.HarvestedFruits or playerData.Inventory.Fruits or playerData.Inventory.Backpack or playerData.Inventory.Harvested
    if not fruits then
        return
    end
    for uid, info in pairs(fruits) do
        if type(info) == "table" then
            local cropName = info.FruitName or info.CropName or info.SeedName or info.Name or ""
            local wt = tonumber(info.SizeMultiplier or info.Weight or info.Size or (ValueDB.baseWeight[cropName] or 1)) or 1
            local mutName = info.Mutation
            local entry = {
                crop = cropName,
                mutation = mutName,
                weight = wt,
                rarity = info.Rarity or SeedRarity[cropName] or "Common",
                value = ValueEngine.compute(cropName, wt, mutName),
            }
            if matchesFilter(entry, "sellFruit", "sellRarity", "sellMutation", "sellThreshMode", "sellThreshold") then
                netFire("NPCS.SellFruit", tostring(uid))
                task.wait(0.1)
            end
        end
    end
end

local function doSellPets()
    local playerData = getData()
    if not (playerData and playerData.Inventory and playerData.Inventory.Pets) then
        return
    end
    local target = firstValue(Library.Flags["sellPet"] or {})
    local minRarity = firstValue(Library.Flags["sellPetRarity"] or {}) or "Any"
    local rRank = RARITY_ORDER[minRarity] or 0
    for uid, info in pairs(playerData.Inventory.Pets) do
        if type(info) == "table" then
            local nm = info.PetType or info.Name
            local rarityOk = (not target) or (nm and nm:lower() == target:lower())
            if rarityOk then
                if rRank > 0 and (RARITY_ORDER[info.Rarity or "Common"] or 0) < rRank then
                    rarityOk = false
                end
            end
            if rarityOk then
                netFire("NPCS.SellPet", tostring(uid))
                task.wait(0.1)
            end
        end
    end
end

local function doFavorite(setFav, all)
    local playerData = getData()
    if not (playerData and playerData.Inventory) then
        return
    end
    local fruits = playerData.Inventory.HarvestedFruits or playerData.Inventory.Fruits or playerData.Inventory.Backpack or playerData.Inventory.Harvested
    if not fruits then
        return
    end
    for uid, info in pairs(fruits) do
        if type(info) == "table" then
            local match = all == true
            if not match then
                local cropName = info.FruitName or info.CropName or info.SeedName or info.Name or ""
                local wt = tonumber(info.SizeMultiplier or info.Weight or info.Size or (ValueDB.baseWeight[cropName] or 1)) or 1
                local mutName = info.Mutation
                local entry = {
                    crop = cropName,
                    mutation = mutName,
                    weight = wt,
                    rarity = info.Rarity or SeedRarity[cropName] or "Common",
                    value = ValueEngine.compute(cropName, wt, mutName),
                }
                match = matchesFilter(entry, "favFruit", "favRarity", "favMutation", "favThreshMode", "favThreshold")
            end
            if match then
                netFire("Backpack.SetFruitFavorite", tostring(uid), setFav)
                task.wait(0.05)
            end
        end
    end
end

local placeOneSprinkler
local function doSprinkler()
    local playerData = getData()
    if not (playerData and playerData.Inventory and playerData.Inventory.Sprinklers) then
        DebugLog("doSprinkler", "exit: no Inventory.Sprinklers data", "invKeys=" .. (playerData and playerData.Inventory and type(playerData.Inventory) == "table" and (function()
            local ks = {}
            for k in pairs(playerData.Inventory) do
                ks[#ks + 1] = tostring(k)
            end
            table.sort(ks)
            return table.concat(ks, ",")
        end)() or "nil"))
        return
    end
    local plot = myPlot()
    if not plot then
        DebugLog("doSprinkler", "exit: no plot")
        return
    end
    if not Library.Flags["sprinklerNoTp"] then
        nearPlot()
    end
    local existing = plot:FindFirstChild("Sprinklers")
    local count = existing and #existing:GetChildren() or 0
    if count >= 4 then
        DebugLog("doSprinkler", "exit: already " .. count .. " sprinklers (>=4)")
        return
    end
    local name = firstValue(Library.Flags["sprinklerSelect"] or {})
    if not name or name == "" then
        for sname, sval in pairs(playerData.Inventory.Sprinklers) do
            if type(sname) == "string" then
                name = sname
                break
            end
        end
    end
    if not name then
        DebugLog("doSprinkler", "exit: no sprinkler name found")
        return
    end
    placeOneSprinkler(plot, name, playerData.Inventory.Sprinklers[name])
end

local function doSprinklerAll()
    local playerData = getData()
    if not (playerData and playerData.Inventory and playerData.Inventory.Sprinklers) then
        return
    end
    local plot = myPlot()
    if not plot then
        return
    end
    if not Library.Flags["sprinklerNoTp"] then
        nearPlot()
    end
    local existing = plot:FindFirstChild("Sprinklers")
    local count = existing and #existing:GetChildren() or 0
    if count >= 4 then
        DebugLog("doSprinklerAll", "exit: already " .. count .. " sprinklers (>=4)")
        return
    end
    local placed = 0
    for sname, sval in pairs(playerData.Inventory.Sprinklers) do
        if type(sname) == "string" and placeOneSprinkler(plot, sname, sval) then
            placed = placed + 1
            task.wait(tonumber(Library.Flags["sprinklerDelay"]) or 0)
            local re = plot:FindFirstChild("Sprinklers")
            if re and #re:GetChildren() >= 4 then
                break
            end
        end
    end
    DebugLog("doSprinklerAll", "done", "placed=" .. placed)
end

-- place a single sprinkler of the given name inside the plot; returns true on fire
placeOneSprinkler = function(plot, name, ownedCount)
    local existing = plot:FindFirstChild("Sprinklers")
    local existingPts = {}
    if existing then
        for _, sp in ipairs(existing:GetChildren()) do
            local ok3, spos = pcall(function()
                return sp:GetPivot().Position
            end)
            if ok3 and spos then
                existingPts[#existingPts + 1] = spos
            end
        end
    end
    local plants = plot:FindFirstChild("Plants")
    local pos = nil
    for _ = 1, 8 do
        local cand = resolveModePosition(firstValue(Library.Flags["sprinklerPos"] or {}), "savedSprinklerPos", plot)
        if not cand and plants then
            local kids = plants:GetChildren()
            if #kids > 0 then
                local ok3, ppos = pcall(function()
                    return kids[math.random(#kids)]:GetPivot().Position
                end)
                if ok3 then
                    cand = ppos
                end
            end
        end
        if not cand then
            break
        end
        cand = cand + Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6)
        cand = soilPositionAt(plot, cand.X, cand.Z) or cand
        local tooClose = false
        for _, spos in ipairs(existingPts) do
            local minSpacing = tonumber(Library.Flags["sprinklerSpacing"]) or 8
            if (Vector2.new(spos.X - cand.X, spos.Z - cand.Z)).Magnitude < minSpacing then
                tooClose = true
                break
            end
        end
        if not tooClose then
            pos = cand
            break
        end
    end
    if not pos then
        DebugLog("doSprinkler", "exit: no position resolved", "name=" .. tostring(name))
        return false
    end
    -- authoritative signature (from game dump SprinklerController.TryPlace):
    -- Place.PlaceSprinkler:Fire(position, tool:SprinklerAttr, equippedTool, plotId)
    -- requires the sprinkler tool to be equipped (server validates via equipped tool)
    local sTool, sAttr = findToolByAttr("Sprinkler", name)
    if not sTool then
        DebugLog("doSprinkler", "exit: no sprinkler tool found", "want=" .. tostring(name))
        return false
    end
    sTool = equipTool(sTool)
    if not sTool then
        DebugLog("doSprinkler", "exit: sprinkler equip failed", tostring(sAttr))
        return false
    end
    sAttr = sTool:GetAttribute("Sprinkler") or sAttr
    local plotId = tonumber(tostring(plot.Name):match("%d+"))
    netFire("Place.PlaceSprinkler", pos, sAttr, sTool, plotId or 0)
    DebugLog("doSprinkler", "fire", sAttr, "pos=" .. tostring(pos.X) .. "," .. tostring(pos.Z), "plotId=" .. tostring(plotId), "owned=" .. tostring(ownedCount))
    return true
end

local function doTrowel()
    local plot = myPlot()
    if not plot then
        DebugLog("doTrowel", "exit: no plot")
        return
    end
    nearPlot()
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        DebugLog("doTrowel", "exit: no Plants folder")
        return
    end
    local target = firstValue(Library.Flags["trowelPlant"] or {})
    local pos = resolveModePosition(firstValue(Library.Flags["trowelPos"] or {}), "savedTrowelPos", plot)
    if not pos then
        local ok, ppos = pcall(function()
            return plants:GetChildren()[1] and plants:GetChildren()[1]:GetPivot().Position
        end)
        if ok then
            pos = ppos
        end
    end
    if not pos then
        DebugLog("doTrowel", "exit: no position resolved")
        return
    end
    local moved = 0
    -- server rejects MovePlant unless a trowel tool is equipped (SpeedHub X confirmed)
    local trowelTool = findToolByAttr("Trowel", firstValue(Library.Flags["trowelSelect"] or {}))
    if trowelTool then
        trowelTool = equipTool(trowelTool)
    end
    if not trowelTool then
        DebugLog("doTrowel", "exit: no trowel tool equipped")
        return
    end
    for _, pl in ipairs(plants:GetChildren()) do
        local crop = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
        if (not target) or (crop and crop:lower() == target:lower()) then
            -- game dump: Trowel.MovePlant:Fire(plantModelName, position, rotationDeg)
            -- (GetPlantTarget returns model, model.Name - the first arg is the model Name)
            netFire("Trowel.MovePlant", tostring(pl.Name), pos, 0)
            moved = moved + 1
            task.wait(tonumber(Library.Flags["trowelDelay"]) or 0.1)
        end
    end
    DebugLog("doTrowel", "done", "moved=" .. moved)
end

local function doWateringCan()
    local plot = myPlot()
    if not plot then
        return
    end
    nearPlot()
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return
    end
    local canName = firstValue(Library.Flags["wateringCan"] or {})
    local targetCrop = firstValue(Library.Flags["waterPlants"] or {})
    local waterAll = Library.Flags["autoWaterAll"]
    local canTool = nil
    local canWarned = false
    for _, pl in ipairs(plants:GetChildren()) do
        local decaying = pl:GetAttribute("IsDecaying") or pl:GetAttribute("Decaying")
        if decaying then
            local crop = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
            if waterAll or not targetCrop or (crop and crop:lower() == targetCrop:lower()) then
                local ok, basePos = pcall(function()
                    return pl:GetPivot().Position
                end)
                if ok and basePos then
                    if not canTool then
                        local t = findToolByAttr("WateringCan", canName)
                        canTool = t and equipTool(t) or nil
                        if not canTool and not canWarned then
                            canWarned = true
                            dumpTools("WateringCan")
                            notify("Auto Water", "Watering can tool not found / equip failed (see console)", "warn")
                        end
                    end
                    if canTool then
                        -- game client raycasts onto a PlantArea-tagged soil part and fires the hit surface pos
                        local surface = soilPositionAt(plot, basePos.X, basePos.Z) or basePos
                        netFire("WateringCan.UseWateringCan", surface - Vector3.new(0, 0.3, 0), canTool:GetAttribute("WateringCan") or canName or "", canTool)
                    end
                    task.wait(0.2)
                end
            end
        end
    end
end

local function doShovelFruit()
    local plot = myPlot()
    if not plot then
        return
    end
    nearPlot()
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return
    end
    local shovel = equipShovel()
    if not shovel then
        return
    end
    local shovelAttr = shovel:GetAttribute("Shovel")
    local target = firstValue(Library.Flags["shovelFruit"] or {})
    for _, pl in ipairs(plants:GetChildren()) do
        local fr = pl:FindFirstChild("Fruits")
        if fr then
            for _, m in ipairs(fr:GetChildren()) do
                local crop = m:GetAttribute("CorePartName") or m:GetAttribute("SeedName")
                local entry = {
                    crop = crop,
                    mutation = m:GetAttribute("Mutation"),
                    weight = tonumber(m:GetAttribute("SizeMulti")),
                    rarity = m:GetAttribute("Rarity"),
                    value = 0,
                }
                if (not target) or (crop and crop:lower() == target:lower()) then
                    if
                        matchesFilter(
                            entry,
                            nil,
                            "shovelFruitRarity",
                            "shovelFruitMutation",
                            "shovelThreshMode",
                            "shovelThreshold"
                        )
                    then
                        -- verified: Shovel.UseShovel(plantId, fruitId, shovelAttr, toolInstance)
                        netFire(
                            "Shovel.UseShovel",
                            pl:GetAttribute("PlantId"),
                            m:GetAttribute("FruitId") or "",
                            shovelAttr,
                            shovel
                        )
                        task.wait(tonumber(Library.Flags["shovelFruitDelay"]) or 0.1)
                    end
                end
            end
        end
    end
end

local function doShovelTree()
    local plot = myPlot()
    if not plot then
        return
    end
    nearPlot()
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return
    end
    local shovel = equipShovel()
    if not shovel then
        return
    end
    local shovelAttr = shovel:GetAttribute("Shovel")
    local target = firstValue(Library.Flags["shovelTree"] or {})
    for _, pl in ipairs(plants:GetChildren()) do
        local crop = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
        local entry =
            { crop = crop, mutation = pl:GetAttribute("Mutation"), rarity = pl:GetAttribute("Rarity"), value = 0 }
        if (not target) or (crop and crop:lower() == target:lower()) then
            if matchesFilter(entry, nil, "shovelTreeRarity", "shovelTreeMutation", nil, nil) then
                netFire("Shovel.UseShovel", pl:GetAttribute("PlantId"), "", shovelAttr, shovel)
                task.wait(tonumber(Library.Flags["shovelTreeDelay"]) or 0.1)
            end
        end
    end
end

local function doMailboxSend()
    local username = Library.Flags["mbUsername"] or ""
    if username == "" then
        return
    end
    local note = Library.Flags["mbNote"] or ""
    local playerData = getData()
    if not playerData then
        return
    end
    -- lookup userId by username (synchronous RemoteFunction call)
    local res = netCall("Mailbox.LookupPlayer", username)
    if not res then
        return
    end
    local userId = type(res) == "table" and res[1] or res
    if not userId then
        return
    end
    -- game client format (StarterPlayerScripts): { Category, ItemKey, Count } entries,
    -- SendBatch:Fire(userId, entries, note) -> (success:boolean, message:string)
    local items = {}
    -- seeds: respect sendSeed dropdown and sendSeedAmount
    if Library.Flags["autoSendSeed"] and playerData.Inventory and playerData.Inventory.Seeds then
        local target = firstValue(Library.Flags["sendSeed"] or {})
        local amountStr = tostring(Library.Flags["sendSeedAmount"] or "full"):lower()
        for name, count in pairs(playerData.Inventory.Seeds) do
            if (count or 0) > 0 and (not target or name:lower() == target:lower()) then
                local amt = count
                if amountStr ~= "full" then
                    amt = math.min(count, math.max(0, tonumber(amountStr) or 0))
                end
                if amt > 0 then
                    items[#items + 1] = { Category = "Seeds", ItemKey = name, Count = amt }
                end
            end
        end
    end
    -- pets: respect sendPet dropdown (equipped pets cannot be mailed - unequip first)
    if Library.Flags["autoSendPet"] and playerData.Inventory and playerData.Inventory.Pets then
        local equipped = netCall("Pets.GetEquipped")
        if type(equipped) == "table" then
            for _, pet in pairs(equipped) do
                if type(pet) == "table" and pet.Id then
                    netFire("Pets.RequestUnequip", tostring(pet.Id))
                    task.wait(0.25)
                end
            end
        end
        local target = firstValue(Library.Flags["sendPet"] or {})
        for uid, info in pairs(playerData.Inventory.Pets) do
            if type(info) == "table" then
                local nm = info.PetType or info.Name
                if not target or (nm and nm:lower() == target:lower()) then
                    items[#items + 1] = { Category = "Pets", ItemKey = uid, Count = 1 }
                end
            end
        end
    end
    -- send in chunks of 20 (matches game client pacing), check the response
    for i = 1, #items, 20 do
        local chunk = {}
        for j = i, math.min(i + 19, #items) do
            chunk[#chunk + 1] = items[j]
        end
        local res = netCall("Mailbox.SendBatch", userId, chunk, note)
        if type(res) == "table" and res[1] == false then
            notify("Mail", "Send failed: " .. tostring(res[2] or "unknown"), "warn")
            return
        end
        task.wait(1)
    end
end

local function doMailboxClaim()
    -- new game packet: one-call claim-all (2026-07-28 update); per-id loop below is the cleanup
    netFire("Mailbox.ClaimAll")
    task.wait(2)
    local list = netCall("Mailbox.List")
    if not (type(list) == "table") then
        return
    end
    for _, mail in ipairs(list) do
        if mail.Id or mail.id then
            -- verified: Mailbox.Claim(mailId)
            netFire("Mailbox.Claim", tostring(mail.Id or mail.id))
            task.wait(0.2)
        end
    end
end

local function doRetaliateShovel()
    local plot = myPlot()
    local ref = plot and plot:FindFirstChild("PlotSizeReference")
    if not ref then
        return
    end
    local center, size = ref.Position, ref.Size
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= client and pl.Character then
            local r = pl.Character:FindFirstChild("HumanoidRootPart")
            if
                r
                and math.abs(r.Position.X - center.X) < size.X / 2 + 16
                and math.abs(r.Position.Z - center.Z) < size.Z / 2 + 16
            then
                netFire("Shovel.HitPlayer", pl.UserId)
                netFire("Crowbar.HitPlayer", pl.UserId)
            end
        end
    end
end

local function doPackGrab()
    local spawns = Workspace:FindFirstChild("Map")
    spawns = spawns and spawns:FindFirstChild("SeedPackSpawnServerLocations")
    if not spawns then
        return
    end
    for _, loc in ipairs(spawns:GetChildren()) do
        if loc.Parent then
            local has = loc:GetAttribute("SeedPack") ~= nil
                or loc:GetAttribute("GoldSeed") == true
                or loc:GetAttribute("RainbowSeed") == true
            if has then
                local rare = isRareSeedPack(loc)
                local grabGold = Library.Flags["collectGold"]
                local grabRainbow = Library.Flags["collectRainbow"]
                local isGold = loc:GetAttribute("GoldSeed") == true
                local isRainbow = loc:GetAttribute("RainbowSeed") == true
                local valid = true
                if grabGold and not grabRainbow and not isGold then
                    valid = false
                elseif grabRainbow and not grabGold and not isRainbow then
                    valid = false
                elseif not (grabGold or grabRainbow) and Library.Flags["rareSeedOnly"] and not rare then
                    valid = false
                end
                if valid then
                    if Library.Flags["rarePackNotify"] and rare then
                        notify("Rare Seed Spawned", packType(loc) or "Rare pack - grabbing!")
                        sendWebhook("Rare Seed", packType(loc) or "Rare pack spawned", 12255232)
                    end
                    task.spawn(function()
                        pcall(grabPackRobust, loc)
                    end)
                    break
                end
            end
        end
    end
end

local function doCollectDropped()
    local rootPart = getHRP()
    if not rootPart then
        return
    end
    local dropped = Workspace:FindFirstChild("DroppedItems") or Workspace:FindFirstChild("Temporary")
    if not dropped then
        return
    end
    for _, d in ipairs(dropped:GetChildren()) do
        if d:IsA("Tool") or (d:IsA("Model") and d:GetAttribute("Fruit")) then
            local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
            if part then
                if firetouchinterest then
                    pcall(function()
                        firetouchinterest(rootPart, part, 0)
                        firetouchinterest(rootPart, part, 1)
                    end)
                else
                    pcall(function()
                        part.CFrame = rootPart.CFrame
                    end)
                end
            end
        end
    end
end

-- ESP (pooled highlights)
local _espPool = {}
local function clearESP()
    for _, h in ipairs(_espPool) do
        pcall(function()
            h:Destroy()
        end)
    end
    _espPool = {}
end

local function doESP()
    clearESP()
    local function esp(model, col)
        if not (model and model.Parent) then
            return
        end
        local h = Instance.new("Highlight")
        h.Adornee = model
        h.FillColor = col
        h.FillTransparency = 0.4
        h.OutlineColor = col
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = CoreGui
        _espPool[#_espPool + 1] = h
    end
    if Library.Flags["espFruitEnabled"] then
        local target = firstValue(Library.Flags["espFruit"] or {})
        for _, p in ipairs(CollectionService:GetTagged("StealPrompt")) do
            local m = p.Parent and p.Parent:FindFirstAncestorWhichIsA("Model")
            if m and m:GetAttribute("PlantId") then
                local crop = m:GetAttribute("SeedName") or m:GetAttribute("CorePartName")
                if (not target) or (crop and crop:lower() == target:lower()) then
                    esp(m, Color3.fromRGB(0, 200, 255))
                end
            end
        end
    end
    if Library.Flags["espPetEnabled"] then
        local target = firstValue(Library.Flags["espPet"] or {})
        local wilds = Workspace:FindFirstChild("Map")
        wilds = wilds and (wilds:FindFirstChild("WildPetSpawns") or wilds:FindFirstChild("WildPetRef"))
        if wilds then
            for _, pet in ipairs(wilds:GetChildren()) do
                local nm = pet:GetAttribute("PetName") or pet:GetAttribute("Type") or pet.Name
                if (not target) or (nm and nm:lower() == target:lower()) then
                    esp(pet, Color3.fromRGB(255, 100, 200))
                end
            end
        end
    end
end

-- instant interact prompt
local function doInstantPrompt()
    for _, p in ipairs(CollectionService:GetTagged("ProximityPrompt")) do
        pcall(function()
            if p:IsA("ProximityPrompt") and p.HoldDuration > 0 then
                p.HoldDuration = 0
            end
        end)
    end
end

-- bypass gameplay paused
local function doBypassPause()
    for _, g in ipairs(client.PlayerGui:GetChildren()) do
        if
            g:IsA("ScreenGui")
            and (g.Name:lower():find("pause") or g.Name:lower():find("modal") or g.Name:lower():find("gameplay"))
        then
            pcall(function()
                g.Enabled = false
            end)
        end
    end
end

-- rare seed restock notify
local _rareNotified = {}
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

-- anti-fling
local function doAntiFling()
    local rootPart = getHRP()
    if not rootPart then
        return
    end
    local velocity = rootPart.Velocity
    if math.abs(velocity.X) > 200 or math.abs(velocity.Y) > 300 or math.abs(velocity.Z) > 200 then
        pcall(function()
            rootPart.Velocity = Vector3.new(0, math.min(velocity.Y, 50), 0)
        end)
    end
end

-- noclip plants
local function doNoclipPlants()
    local plot = myPlot()
    if not plot then
        return
    end
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return
    end
    for _, pl in ipairs(plants:GetChildren()) do
        for _, d in ipairs(pl:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then
                pcall(function()
                    d.CanCollide = false
                end)
            end
        end
    end
end

-- fly system (with proper off-state)

-- less knockback
local function doLessKnockback()
    local rootPart = getHRP()
    if rootPart then
        local velocity = rootPart.Velocity
        if velocity.Magnitude > 50 then
            pcall(function()
                rootPart.Velocity = velocity.Unit * math.min(velocity.Magnitude, 50)
            end)
        end
    end
end

-- pet purchase protection: disable ProximityPrompts on wild pets so no one can buy them
local function doPetProtection()
    if not Library.Flags["petProtection"] then
        return
    end
    local wilds = Workspace:FindFirstChild("Map")
    wilds = wilds and (wilds:FindFirstChild("WildPetSpawns") or wilds:FindFirstChild("WildPetRef"))
    if not wilds then
        return
    end
    for _, pet in ipairs(wilds:GetChildren()) do
        for _, child in ipairs(pet:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                pcall(function()
                    child.Enabled = false
                end)
            end
        end
    end
    -- also scan CollectionService for tagged wild pets
    for _, tag in ipairs({ "WildPet", "WildPetModel", "Pets" }) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do
            for _, child in ipairs(obj:GetDescendants()) do
                if child:IsA("ProximityPrompt") then
                    pcall(function()
                        child.Enabled = false
                    end)
                end
            end
        end
    end
end

-- remove all plants (shovel every plant on your plot)
local BUILD_FOLDERS = { "Props", "Sprinklers", "Gnomes", "PottedPlants", "Pots", "Objects", "Decor" }
local function removeAllPlants()
    local plot = myPlot()
    if not plot then
        return 0
    end
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return 0
    end
    local shovel = equipShovel()
    if not shovel then
        return 0
    end
    local shovelAttr = shovel:GetAttribute("Shovel")
    local count = 0
    for _, plant in ipairs(plants:GetChildren()) do
        local plantId = plant:GetAttribute("PlantId")
        if plantId then
            netFire("Shovel.UseShovel", plantId, "", shovelAttr, shovel)
            count = count + 1
            task.wait(0.05)
        end
    end
    return count
end

-- remove selected plants only (by crop type filter)
local function removeSelectedPlants(selectedCrops)
    local plot = myPlot()
    if not plot then
        return 0
    end
    local plants = plot:FindFirstChild("Plants")
    if not plants then
        return 0
    end
    local shovel = equipShovel()
    if not shovel then
        return 0
    end
    local shovelAttr = shovel:GetAttribute("Shovel")
    local count = 0
    for _, plant in ipairs(plants:GetChildren()) do
        local plantId = plant:GetAttribute("PlantId")
        local crop = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName")
        if plantId and crop and selectedCrops[crop] then
            netFire("Shovel.UseShovel", plantId, "", shovelAttr, shovel)
            count = count + 1
            task.wait(0.05)
        end
    end
    return count
end

-- remove all buildings (pick up props, pots, gnomes, etc.)
local function removeAllBuildings()
    local plot = myPlot()
    if not plot then
        return 0
    end
    local count = 0
    for _, folderName in ipairs(BUILD_FOLDERS) do
        local folder = plot:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                pcall(function()
                    netFire("Prop.PickupProp", child.Name)
                    netFire("PotPlacement.PickUpPottedPlant", child.Name)
                    if folderName == "Gnomes" then
                        netFire("Place.RemoveGnome", child)
                    end
                end)
                count = count + 1
                task.wait(0.06)
            end
        end
    end
    return count
end

-- redeem a promo code
local function doRedeemCode()
    local code = Library.Flags["redeemCode"] or ""
    if code == "" then
        notify("Code", "Enter a code first", "warning")
        return
    end
    netFire("Settings.SubmitCode", code)
    notify("Code", "Redeeming: " .. code)
end

-- auto buy pet: scan wild pets for Price attribute and buy if affordable
local function doAutoBuyPet()
    if not Library.Flags["autoBuyPet"] then
        return
    end
    local maxPrice = tonumber(Library.Flags["petBuyMaxPrice"]) or 500
    local balance = getBalance()
    local map = Workspace:FindFirstChild("Map")
    local spawns = map and (map:FindFirstChild("WildPetSpawns") or map:FindFirstChild("WildPetRef"))
    if not spawns then
        return
    end
    local bought = 0
    local wantSpecies = firstValue(Library.Flags["buyPet"] or {})
    local wantRarity = firstValue(Library.Flags["buyPetRarity"] or {})
    local wantRarityIdx = (wantRarity and wantRarity ~= "Any") and (RARITY_ORDER[wantRarity] or 0) or 0
    for _, pet in ipairs(spawns:GetChildren()) do
        local part = pet:IsA("BasePart") and pet or pet:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local species = part:GetAttribute("PetName") or part.Parent and part.Parent:GetAttribute("PetName")
            local price = part:GetAttribute("Price")
            local owner = part:GetAttribute("OwnerUserId")
            local pass = true
            if wantSpecies and species and normName(species) ~= normName(wantSpecies) then
                pass = false
            end
            if pass and wantRarityIdx > 0 and species then
                local rarity = getSpeciesRarity(species)
                if rarity and (RARITY_ORDER[rarity] or 0) < wantRarityIdx then
                    pass = false
                end
            end
            local state = part:GetAttribute("State")
            if pass and type(price) == "number" and price > 0 and price <= maxPrice and price <= balance then
                if (not owner or owner == 0) and (not state or state == "idle") then
                    netFire("Pets.WildPetTame", pet)
                    balance = balance - price
                    bought = bought + 1
                    task.wait(0.3)
                end
            end
        end
    end
    if bought > 0 then
        notify("Pet Buyer", "Purchased " .. bought .. " pet(s)")
    end
end

local _flyBV, _flyBG
local function stopFly()
    if _flyBV then
        pcall(function()
            _flyBV:Destroy()
        end)
        _flyBV = nil
    end
    if _flyBG then
        pcall(function()
            _flyBG:Destroy()
        end)
        _flyBG = nil
    end
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.PlatformStand = false
    end
end

local function doFlySystem(dt)
    if not Library.Flags["freeFlight"] then
        if _flyBV then
            stopFly()
        end
        return
    end
    local character = client.Character
    if not character then
        return
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not _flyBV then
        _flyBV = Instance.new("BodyVelocity")
        _flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
        _flyBV.Velocity = Vector3.zero
        _flyBV.Parent = hrp
        _flyBG = Instance.new("BodyGyro")
        _flyBG.MaxTorque = Vector3.new(1, 1, 1) * 9e9
        _flyBG.P = 1e5
        _flyBG.CFrame = hrp.CFrame
        _flyBG.Parent = hrp
    end
    if humanoid then
        humanoid.PlatformStand = true
    end
    local speed = tonumber(Library.Flags["flightSpeed"]) or 50
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        dir = dir + cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        dir = dir - cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        dir = dir - cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        dir = dir + cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        dir = dir + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        dir = dir - Vector3.new(0, 1, 0)
    end
    if _flyBV then
        _flyBV.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * speed
    end
    if _flyBG then
        _flyBG.CFrame = cam.CFrame
    end
end

-- movement loop (cached)
local _moveCache = {}
local function doMoveLoop()
    local character = client.Character
    if not character then
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    local st = _moveCache[character]
    if not st then
        st = {}
        _moveCache[character] = st
    end
    local ws = tonumber(Library.Flags["runSpeed"]) or 16
    local jh = tonumber(Library.Flags["jumpHeight"]) or 7.2
    if st.ws ~= ws then
        st.ws = ws
        humanoid.WalkSpeed = ws
    end
    if st.jh ~= jh then
        st.jh = jh
        humanoid.JumpHeight = jh
    end
    if Library.Flags["noClip"] then
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    elseif st.wasNoClip then
        st.wasNoClip = false
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.CanCollide = true
                end)
            end
        end
    end
end

-- stats tracking
local sessionEarned = 0
local sessionHarvests = 0
local sessionStart = os.clock()
local sessionStartBal = getBalance()
local profitWindow = {}
local sellBaseline = nil

-- ================================================================
function gardenNearPlayer()
    local gardensFolder = Workspace:FindFirstChild("Gardens")
    local rootPart = getHRP()
    if not (gardensFolder and rootPart) then
        return nil
    end
    local closestPlot, closestDist
    for _, plot in ipairs(gardensFolder:GetChildren()) do
        local ref = plot:FindFirstChild("PlotSizeReference")
        if ref then
            local dist = (Vector3.new(ref.Position.X, 0, ref.Position.Z) - Vector3.new(
                rootPart.Position.X,
                0,
                rootPart.Position.Z
            )).Magnitude
            if not closestDist or dist < closestDist then
                closestPlot, closestDist = plot, dist
            end
        end
    end
    return closestPlot
end

-- settings persistence
local SAVE_FILE = "GAG2_Settings.json"
local PERSISTENT_FLAGS = {
    "autoPlant",
    "autoPlantAll",
    "smartReplant",
    "plantNoTp",
    "plantSeeds",
    "plantPattern",
    "plantDelay",
    "maxPerCycle",
    "plantPosition",
    "savedPlantPos",
    "autoExpand",

    "autoCollect",
    "autoCollectAll",
    "autoCollectBest",
    "enableFilters",
    "collectNoTp",
    "stopOnFull",
    "collectDelay",
    "collectFilter",
    "mutatedOnly",
    "collectFruit",
    "collectRarity",
    "collectMutation",
    "collectThreshMode",
    "collectThreshold",
    "collectGold",
    "collectRainbow",
    "collectDropped",
    "autoSteal",
    "autoStealBest",
    "stealFilter",
    "stealFruit",
    "stealRarity",
    "stealMutation",
    "stealDelay",
    "stealMult",
    "stealReturn",
    "lockNight",
    "hitStolen",
    "autoSell",
    "sellOnFull",
    "sellDelay",
    "dailyDeal",
    "sellInterval",
    "sellFruit",
    "sellRarity",
    "sellMutation",
    "sellThreshMode",
    "sellThreshold",
    "autoSellSelective",
    "sellPet",
    "sellPetRarity",
    "sellPetSize",
    "autoSellPets",
    "buyPet",
    "buyPetRarity",
    "buyPetSize",
    "autoSprinkler",
    "autoSprinklerAll",
    "sprinklerNoTp",
    "sprinklerSelect",
    "sprinklerPos",
    "sprinklerSpacing",
    "sprinklerDelay",
    "savedSprinklerPos",
    "autoTrowel",
    "trowelPlant",
    "trowelPos",
    "trowelDelay",
    "savedTrowelPos",
    "autoShovelTree",
    "shovelTree",
    "shovelTreeRarity",
    "shovelTreeMutation",
    "shovelTreeDelay",
    "autoShovelFruit",
    "shovelFruit",
    "shovelFruitRarity",
    "shovelFruitMutation",
    "shovelThreshMode",
    "shovelThreshold",
    "shovelFruitDelay",
    "autoWaterAll",
    "waterPlants",
    "wateringCan",
    "mbUsername",
    "mbNote",
    "autoSendSeed",
    "autoSendSeedPack",
    "autoSendPet",
    "autoSendFruit",
    "autoClaimMail",
    "sendSeed",
    "sendSeedAmount",
    "sendPet",
    "autoFav",
    "autoUnfav",
    "autoUnfavAll",
    "favFruit",
    "favRarity",
    "favMutation",
    "favThreshMode",
    "favThreshold",
    "autoEggs",
    "autoCrates",
    "autoPacks",
    "autoBuySeed",
    "autoBuyAllSeeds",
    "buySeed",
    "autoBuyGear",
    "autoBuyAllGear",
    "buyGear",
    "autoBuyCrate",
    "autoBuyAllCrates",
    "buyCrate",
    "buySprees",
    "webhookUrl",
    "whName",
    "whPing",
    "whAllowPing",
    "whRareSeed",
    "whBigHarvest",
    "whStealReturn",
    "whHop",
    "whPetPurchase",
    "whEventSeed",
    "whEventSeedEnabled",
    "petProtection",
    "whPetFilter",
    "whPetRarity",
    "whPetSize",
    "redeemCode",
    "autoBuyPet",
    "petBuyMaxPrice",
    "removeCrops",

    "seedReserve",
    "reserveCount",
    "antiFling",
    "lessKnockback",
    "instantPrompt",
    "bypassPause",
    "petProtection",
    "espFruitEnabled",
    "espFruit",
    "espFruitRarity",
    "espFruitMutation",
    "espPetEnabled",
    "espPet",
    "espPetRarity",
    "espPetSize",
    "noclipPlants",
    "moreFps",
    "autoRemoveGardens",
    "runSpeed",
    "jumpHeight",
    "multiJump",
    "infJump",
    "noClip",
    "freeFlight",
    "flightSpeed",

    "autoTame",
    "autoEquip",
    "equipList",
    "tameAnimals",
    "autoBuyPetSlot",
    "autoHopPet",
    "hopPetSpecies",
    "tpTween",
    "tpTweenSpeed",
    "rarePackNotify",
    "espFruitValue",
    "espTotalValue",
    "espBaseValueOnly",
    "rareNotify",
    "autoHopRare",
    "espInvValue",
    "autoSave",
}
local function saveSettings()
    if not writefile then
        return
    end
    local data = {}
    for _, flag in ipairs(PERSISTENT_FLAGS) do
        local v = Library.Flags[flag]
        if v ~= nil then
            data[flag] = v
        end
    end
    pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end)
end
local function loadSettings()
    if not (readfile and isfile) then
        return
    end
    local ok, raw = pcall(function()
        return isfile(SAVE_FILE) and readfile(SAVE_FILE) or nil
    end)
    if not (ok and raw) then
        return
    end
    local good, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not (good and type(data) == "table") then
        return
    end
    for k, v in pairs(data) do
        if Library.Flags[k] ~= nil then
            Library.Flags[k] = v
        end
    end
end

-- stats tracking
local sessionEarned = 0
local sessionHarvests = 0
local sessionStart = os.clock()
local sessionStartBal = getBalance()
local profitWindow = {}

-- ================================================================
-- SECTIONS (9 tabs)
-- ================================================================

local Home = Setup:CreateSection("🏠 Home")
local Main = Setup:CreateSection("🌱 Main")
local Automatically = Setup:CreateSection("⚙️ Automatically")
local Inventory = Setup:CreateSection("🎒 Inventory")
local Shop = Setup:CreateSection("🛒 Shop")
local Webhook = Setup:CreateSection("📡 Webhook")
local Misc = Setup:CreateSection("🧰 Misc")
local Visual = Setup:CreateSection("👁️ Visual")
local DevTools = Setup:CreateSection("🐞 Dev Tools")
local Settings = Setup:CreateSection("🔧 Settings")

-- ================================================================
-- HOME TAB (Dashboard)
-- ================================================================

Home:createLabel({ Name = "Quick Stats", Special = true })
Home:createLabel({ Name = "Balance: $0", flagName = "homeBalance", Special = true })
Home:createLabel({ Name = "Session Earned: $0", flagName = "homeEarned", Special = true })
Home:createLabel({ Name = "Crops Harvested: 0", flagName = "homeHarvested", Special = true })
Home:createLabel({ Name = "Fruit: 0/0", flagName = "homeFruit", Special = true })
Home:createLabel({ Name = "Time: 0m", flagName = "homeTime", Special = true })

Home:createLabel({ Name = "Quick Actions", Special = true })
Home:createButton({
    Name = "Refresh Lists",
    Description = "Update all dropdown lists across all tabs.",
    Callback = function()
        local function upd(section, tag, list)
            local dd = section:FindFirstChild(tag)
            if dd and dd.updateList then
                dd:updateList(list)
            end
        end
        upd(Main, "plantSeeds", getSeedList())
        upd(Main, "collectFruit", getCropList())
        upd(Main, "stealFruit", getCropList())
        upd(Main, "sellFruit", getCropList())
        upd(Main, "sellPet", getPetList())
        upd(Main, "buyPet", getAllPetSpecies())
        upd(Shop, "buySeed", getSeedList())
        upd(Shop, "buyGear", getGearList())
        upd(Shop, "buyCrate", getCrateList())
        upd(Misc, "espFruit", getCropList())
        upd(Misc, "espPet", getAllPetSpecies())
        notify("Lists", "All dropdowns refreshed")
    end,
})

Home:createButton({
    Name = "Teleport to Garden",
    Description = "Return to your own plot.",
    Callback = function()
        local plot = myPlot()
        local sp = plot and plot:FindFirstChild("SpawnPoint")
        if sp then
            teleport(sp.Position)
            notify("Home", "Went to your garden")
        else
            notify("Home", "Garden not found", "warning")
        end
    end,
})
Home:createDropdown({
    Name = "Transport Mode",
    flagName = "tpMode",
    List = { "Teleport", "Tween" },
    Flag = { "Teleport" },
    Description = "Teleport: instant. Tween: smooth movement.",
    Callback = function(selected)
        Library.Flags["tpTween"] = (selected == "Tween")
    end,
})

-- ================================================================
-- MAIN TAB
-- ================================================================

-- Automation Plants
Main:createLabel({ Name = "Automation Plants", Special = true })

Main:createLabel({ Name = "- [ Config ] -", Special = true })
Main:createToggle({
    Name = "Disable Teleport",
    Flag = false,
    flagName = "plantNoTp",
    Description = "Walk instead of teleporting to planting spots.",
})

Main:createLabel({ Name = "- [ Plants ] -", Special = true })
Main:createDropdown({
    Name = "Select Seeds",
    flagName = "plantSeeds",
    List = getSeedList(),
    multi = true,
    Description = "Which seeds to plant. Leave empty for all.",
})
Main:createDropdown({
    Name = "Plant Pattern",
    flagName = "plantPattern",
    List = { "Fill", "Checkerboard", "Rows", "Columns", "Diagonal", "Spaced" },
    Flag = { "Fill" },
    Description = "Visual layout pattern for planting seeds.",
})
Main:createDropdown({
    Name = "Select Position",
    flagName = "plantPosition",
    List = { "Random", "Saved Position", "Sprinkler Radius", "Player Position", "Near Fruit" },
    Flag = { "Random" },
    Description = "Where to plant seeds.",
})
Main:createButton({
    Name = "Save Position",
    Description = "Save current position for planting.",
    Callback = function()
        local rootPart = getHRP()
        if rootPart then
            Library.Flags["savedPlantPos"] = rootPart.Position
            notify("Plant", "Position saved")
        end
    end,
})
Main:createInputBox({
    Name = "Delay To Plant",
    flagName = "plantDelay",
    Flag = "0",
    Description = "Delay in seconds between each seed planted.",
})
Main:createSlider({
    Name = "Max Per Cycle",
    flagName = "maxPerCycle",
    value = 80,
    minValue = 1,
    maxValue = 200,
    Description = "Max seeds to plant per cycle.",
})
Main:createToggle({
    Name = "Seed Reserve",
    Flag = false,
    flagName = "seedReserve",
    Description = "Keep a reserve of seeds in inventory.",
})
Main:createInputBox({
    Name = "Reserve Count",
    flagName = "reserveCount",
    Flag = "10",
    Description = "How many seeds to keep as reserve.",
})
createIntervalToggle(
    Main,
    { Name = "Auto Plant Seed", flagName = "autoPlant", tag = "autoPlant", delay = 1.2, Step = doPlant }
)
createIntervalToggle(
    Main,
    { Name = "Auto Plant All Seeds", flagName = "autoPlantAll", tag = "autoPlantAll", delay = 1.2, Step = doPlant }
)
Main:createToggle({
    Name = "Smart Replant",
    Flag = false,
    flagName = "smartReplant",
    Description = "Plant only the most profitable seed you own.",
})

-- Automation Collection
Main:createLabel({ Name = "Automation Collection", Special = true })

Main:createLabel({ Name = "- [ Config ] -", Special = true })
Main:createToggle({
    Name = "Disable Teleport",
    Flag = false,
    flagName = "collectNoTp",
    Description = "Walk instead of teleporting to crops.",
})
Main:createToggle({
    Name = "Stop Collect If Backpack Is Full Max",
    Flag = false,
    flagName = "stopOnFull",
    Description = "Pause collecting when backpack is full.",
})
Main:createInputBox({
    Name = "Delay To Collect",
    flagName = "collectDelay",
    Flag = "0",
    Description = "Extra delay (seconds) before each collect.",
})

Main:createLabel({ Name = "- [ Collects ] -", Special = true })
Main:createDropdown({
    Name = "Select Filter",
    flagName = "collectFilter",
    List = { "All", "Filtered", "Best" },
    Flag = { "All" },
    Description = "Which collection mode to use.",
})
Main:createDropdown({
    Name = "Select Fruit",
    flagName = "collectFruit",
    List = getCropList(),
    multi = true,
    Description = "Specific fruit to collect (with Filtered mode).",
})
Main:createDropdown({
    Name = "Select Rarity",
    flagName = "collectRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity to collect.",
})
Main:createDropdown({
    Name = "Select Mutation",
    flagName = "collectMutation",
    List = { "Any", "Mutated Only", "Non-Mutated Only" },
    Flag = { "Any" },
    Description = "Mutation filter for collecting.",
})
Main:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "collectThreshMode",
    List = { "Disabled", "Weight", "Value" },
    Flag = { "Disabled" },
    Description = "How to filter by threshold.",
})
Main:createInputBox({
    Name = "Weight Threshold",
    flagName = "collectThreshold",
    Flag = "0",
    Description = "Minimum weight/value to collect (0 = disabled).",
})
Main:createToggle({
    Name = "Auto Collect Fruit",
    Flag = false,
    flagName = "autoCollect",
    Description = "Run the harvest loop every 0.6s using the selected filter mode.",
})
Main:createToggle({
    Name = "Auto Collect All Fruit",
    Flag = false,
    flagName = "autoCollectAll",
    Description = "Collect all fruit regardless of filters.",
})
Main:createToggle({
    Name = "Enable Filters",
    Flag = false,
    flagName = "enableFilters",
    Description = "Apply rarity/mutation/threshold filters (forces Filtered mode).",
})
Main:createToggle({
    Name = "Auto Collect Best Fruit",
    Flag = false,
    flagName = "autoCollectBest",
    Description = "Only collect the highest-value fruit.",
})

Main:createLabel({ Name = "- [ Mutation Scanner ] -", Special = true })
Main:createButton({
    Name = "Scan Mutations",
    Description = "List all mutated fruits in your garden.",
    Callback = function()
        doMutationScan()
    end,
})
Main:createButton({
    Name = "Harvest Mutated",
    Description = "Collect all ripe mutated fruits now.",
    Callback = function()
        doHarvestMutated()
    end,
})

Main:createLabel({ Name = "- [ Collect Gold / Rainbow Seed ] -", Special = true })
Main:createToggle({
    Name = "Auto Collect Gold Seed",
    Flag = true,
    flagName = "collectGold",
    Description = "Auto-collect gold seed packs from map.",
})
Main:createToggle({
    Name = "Auto Collect Rainbow Seed",
    Flag = true,
    flagName = "collectRainbow",
    Description = "Auto-collect rainbow seed packs from map.",
})
Main:createToggle({
    Name = "Rare Pack Spawn Alert",
    Flag = false,
    flagName = "rarePackNotify",
    Description = "Notify when a rare seed pack spawns on the map.",
})

Main:createLabel({ Name = "- [ Collect Dropped Item ] -", Special = true })
Main:createToggle({
    Name = "Auto Collect Dropped Item",
    Flag = false,
    flagName = "collectDropped",
    Description = "Auto-collect dropped fruit/items on ground.",
})

-- Automation Steal
Main:createLabel({ Name = "Automation Steal", Special = true })

Main:createLabel({ Name = "- [ Steal Fruits ] -", Special = true })
Main:createDropdown({
    Name = "Select Filter",
    flagName = "stealFilter",
    List = { "All", "Filtered", "Best" },
    Flag = { "All" },
    Description = "Which steal mode to use.",
})
Main:createDropdown({
    Name = "Select Fruit",
    flagName = "stealFruit",
    List = getCropList(),
    multi = true,
    Description = "Specific fruit to steal (with Filtered mode).",
})
Main:createDropdown({
    Name = "Select Rarity",
    flagName = "stealRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity to steal.",
})
Main:createDropdown({
    Name = "Select Mutation",
    flagName = "stealMutation",
    List = { "Any", "Mutated Only", "Non-Mutated" },
    Flag = { "Any" },
    Description = "Mutation filter for stealing.",
})
Main:createInputBox({
    Name = "Steal Delay",
    flagName = "stealDelay",
    Flag = "0.3",
    Description = "Seconds between BeginSteal and CompleteSteal.",
})
Main:createSlider({
    Name = "Fruits Per Steal",
    flagName = "stealMult",
    Flag = 1,
    Min = 1,
    Max = 10,
    Description = "Fire CompleteSteal N times to carry multiple fruits per steal.",
})
createIntervalToggle(
    Main,
    { Name = "Auto Steal Fruit", flagName = "autoSteal", tag = "autoSteal", delay = 3, Step = doSteal }
)

Main:createLabel({ Name = "- [ Steal Best Fruit ] -", Special = true })
Main:createToggle({
    Name = "Auto Steal Best Fruit",
    Flag = false,
    flagName = "autoStealBest",
    Description = "Only steal the highest-value fruit available instantly.",
})

Main:createLabel({ Name = "- [ Locks Garden ] -", Special = true })
Main:createToggle({
    Name = "Auto Lock Garden At Night",
    Flag = true,
    flagName = "lockNight",
    Description = "Wait for nightfall to begin stealing (safest method).",
})

Main:createLabel({ Name = "- [ Hit Players ] -", Special = true })
Main:createToggle({
    Name = "Auto Hit Player Stolen",
    Flag = false,
    flagName = "hitStolen",
    Description = "Shovel and crowbar players who come onto your plot or try to steal.",
})

-- Automation Sell
Main:createLabel({ Name = "Automation Sell", Special = true })

Main:createLabel({ Name = "- [ Config ] -", Special = true })
Main:createInputBox({
    Name = "Delay To Sell Inventory",
    flagName = "sellDelay",
    Flag = "0",
    Description = "Extra delay (seconds) before each auto-sell.",
})
Main:createToggle({
    Name = "Allow Sell If Backpack Is Max",
    Flag = true,
    flagName = "sellOnFull",
    Description = "Auto-sell the moment your backpack is full.",
})

Main:createToggle({
    Name = "Use Daily Deal",
    Flag = false,
    flagName = "dailyDeal",
    Description = "Sell to daily deal vendor for bonus.",
})

Main:createLabel({ Name = "- [ Sell All ] -", Special = true })
Main:createToggle({
    Name = "Auto Sell All",
    Flag = false,
    flagName = "autoSell",
    Description = "Auto-sell everything on an interval.",
})
Main:createSlider({
    Name = "Sell Interval (seconds)",
    flagName = "sellInterval",
    value = 20,
    minValue = 5,
    maxValue = 120,
    Description = "How often to auto-sell.",
})
Main:createButton({
    Name = "Sell All",
    Description = "Sell all harvested fruit.",
    Callback = function()
        doSellAll()
        notify("Sell", "Sold all fruit")
    end,
})

Main:createLabel({ Name = "- [ Sell Fruits ] -", Special = true })
Main:createDropdown({
    Name = "Select Sell Fruit",
    flagName = "sellFruit",
    List = getCropList(),
    Description = "Which fruit type to selectively sell.",
})
Main:createDropdown({
    Name = "Select Sell Rarity",
    flagName = "sellRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity to sell.",
})
Main:createDropdown({
    Name = "Select Sell Mutation",
    flagName = "sellMutation",
    List = { "Any", "Mutated Only", "Non-Mutated" },
    Flag = { "Any" },
    Description = "Mutation filter for selling.",
})
Main:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "sellThreshMode",
    List = { "Disabled", "Weight", "Value" },
    Flag = { "Disabled" },
    Description = "Threshold mode for selective selling.",
})
Main:createInputBox({
    Name = "Weight Threshold",
    flagName = "sellThreshold",
    Flag = "0",
    Description = "Minimum weight/value to sell (0 = disabled).",
})
Main:createToggle({
    Name = "Auto Sell Fruit",
    Flag = false,
    flagName = "autoSellSelective",
    Description = "Auto-sell fruits matching the above filters.",
})

Main:createLabel({ Name = "- [ Sell Pets ] -", Special = true })
Main:createDropdown({
    Name = "Select Pets",
    flagName = "sellPet",
    List = getPetList(),
    Description = "Which pet type to sell.",
})
Main:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "sellPetRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity for pet selling.",
})
Main:createDropdown({
    Name = "Select Size Pets",
    flagName = "sellPetSize",
    List = { "Any", "Small", "Medium", "Large", "Huge" },
    Flag = { "Any" },
    Description = "Size filter for pet selling.",
})
Main:createToggle({
    Name = "Auto Sell Pets",
    Flag = false,
    flagName = "autoSellPets",
    Description = "Auto-sell pets matching the above filters.",
})

-- Automation Pets
Main:createLabel({ Name = "Automation Pets", Special = true })

Main:createToggle({
    Name = "Pet Purchase Protection",
    Flag = false,
    flagName = "petProtection",
    Description = "Disable ProximityPrompts on wild pets so no one can buy them.",
})

Main:createLabel({ Name = "- [ Buys Pets ] -", Special = true })
Main:createDropdown({
    Name = "Select Pets",
    flagName = "buyPet",
    List = getAllPetSpecies(),
    Description = "Which pet type to auto-purchase.",
})
Main:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "buyPetRarity",
    List = RARITY_LIST,
    multi = true,
    Description = "Minimum rarity for pet purchases.",
})
Main:createDropdown({
    Name = "Select Size Pets",
    flagName = "buyPetSize",
    List = { "Any", "Small", "Medium", "Large", "Huge" },
    Flag = { "Any" },
    Description = "Size filter for pet purchases.",
})
Main:createToggle({
    Name = "Auto Buy Pet",
    Flag = false,
    flagName = "autoBuyPet",
    Description = "Scan wild pets and buy if price is within budget.",
})
Main:createSlider({
    Name = "Max Pet Price",
    flagName = "petBuyMaxPrice",
    value = 500,
    minValue = 0,
    maxValue = 50000,
    Description = "Maximum price to spend on a single pet.",
})

Main:createDropdown({
    Name = "Equip List",
    flagName = "equipList",
    List = {},
    Description = "Specific pet to equip (leave empty for best).",
})
Main:createDropdown({
    Name = "Tame Animals",
    flagName = "tameAnimals",
    List = {},
    Description = "Which animal types to tame.",
})

-- ================================================================
-- AUTOMATICALLY TAB
-- ================================================================

-- Automation Sprinkler
Automatically:createLabel({ Name = "Automation Sprinkler", Special = true })

Automatically:createLabel({ Name = "- [ Config ] -", Special = true })
Automatically:createToggle({
    Name = "Disable Teleport",
    Flag = false,
    flagName = "sprinklerNoTp",
    Description = "Walk instead of teleporting when placing sprinklers.",
})

Automatically:createLabel({ Name = "- [ Sprinkler ] -", Special = true })
Automatically:createDropdown({
    Name = "Select Sprinkler",
    flagName = "sprinklerSelect",
    List = getSprinklerList(),
    Description = "Which sprinkler type to place.",
})
Automatically:createDropdown({
    Name = "Select Position",
    flagName = "sprinklerPos",
    List = { "Saved Position", "Random", "Player Position", "Near Fruit" },
    Flag = { "Random" },
    Description = "Where to place sprinklers.",
})
Automatically:createInputBox({
    Name = "Sprinkler Spacing",
    flagName = "sprinklerSpacing",
    Flag = "8",
    Description = "Offset distance between sprinklers when using 'Near Fruit'.",
})
Automatically:createButton({
    Name = "Save Position",
    Description = "Save current position for sprinkler placement.",
    Callback = function()
        local rootPart = getHRP()
        if rootPart then
            Library.Flags["savedSprinklerPos"] = rootPart.Position
            notify("Sprinkler", "Position saved")
        end
    end,
})
Automatically:createInputBox({
    Name = "Delay To Sprinkler",
    flagName = "sprinklerDelay",
    Flag = "0",
    Description = "Delay in seconds between sprinkler placements.",
})
createIntervalToggle(
    Automatically,
    { Name = "Auto Place Sprinkler", flagName = "autoSprinkler", tag = "autoSprinkler", delay = 20, Step = doSprinkler }
)
Automatically:createToggle({
    Name = "Auto Place All Sprinkler",
    Flag = false,
    flagName = "autoSprinklerAll",
    Description = "Place all owned sprinklers at once.",
})

-- Automation Trowel
Automatically:createLabel({ Name = "Automation Trowel", Special = true })

Automatically:createDropdown({
    Name = "Select Plant",
    flagName = "trowelPlant",
    List = getCropList(),
    Description = "Which plant type to trowel/dig up.",
})
Automatically:createDropdown({
    Name = "Select Trowel",
    flagName = "trowelSelect",
    List = getTrowelList(),
    Description = "Which trowel tool to equip (server rejects moves without one).",
})
Automatically:createDropdown({
    Name = "Select Position",
    flagName = "trowelPos",
    List = { "Saved Position", "Random", "Player Position" },
    Flag = { "Saved Position" },
    Description = "Where to use trowel.",
})
Automatically:createButton({
    Name = "Save Position",
    Description = "Save current position for trowel use.",
    Callback = function()
        local rootPart = getHRP()
        if rootPart then
            Library.Flags["savedTrowelPos"] = rootPart.Position
            notify("Trowel", "Position saved")
        end
    end,
})
Automatically:createInputBox({
    Name = "Delay To Trowel",
    flagName = "trowelDelay",
    Flag = "0",
    Description = "Delay between trowel uses.",
})
createIntervalToggle(
    Automatically,
    { Name = "Auto Trowel Plant", flagName = "autoTrowel", tag = "autoTrowel", delay = 3, Step = doTrowel }
)

-- Automation Shovel
Automatically:createLabel({ Name = "Automation Shovel", Special = true })

Automatically:createLabel({ Name = "- [ Tree Shovel ] -", Special = true })
Automatically:createDropdown({
    Name = "Select Tree",
    flagName = "shovelTree",
    List = getCropList(),
    Description = "Which tree type to shovel.",
})
Automatically:createDropdown({
    Name = "Select Rarity Tree",
    flagName = "shovelTreeRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity to shovel trees.",
})
Automatically:createDropdown({
    Name = "Select Mutation Tree",
    flagName = "shovelTreeMutation",
    List = { "Any", "Mutated Only", "Non-Mutated" },
    Flag = { "Any" },
    Description = "Mutation filter for tree shoveling.",
})
Automatically:createInputBox({
    Name = "Delay To Shovel Tree",
    flagName = "shovelTreeDelay",
    Flag = "0",
    Description = "Delay between tree shovel uses.",
})
createIntervalToggle(
    Automatically,
    {
        Name = "Auto Shovel Tree",
        flagName = "autoShovelTree",
        tag = "autoShovelTree",
        delay = 3,
        Step = doShovelTree,
    }
)

Automatically:createLabel({ Name = "- [ Fruits Shovel ] -", Special = true })
Automatically:createDropdown({
    Name = "Select Fruit",
    flagName = "shovelFruit",
    List = getCropList(),
    Description = "Which fruit type to shovel.",
})
Automatically:createDropdown({
    Name = "Select Rarity",
    flagName = "shovelFruitRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity to shovel fruits.",
})
Automatically:createDropdown({
    Name = "Select Mutation",
    flagName = "shovelFruitMutation",
    List = { "Any", "Mutated Only", "Non-Mutated" },
    Flag = { "Any" },
    Description = "Mutation filter for fruit shoveling.",
})
Automatically:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "shovelThreshMode",
    List = { "Disabled", "Weight", "Value" },
    Flag = { "Disabled" },
    Description = "Threshold mode for shoveling.",
})
Automatically:createInputBox({
    Name = "Weight Threshold",
    flagName = "shovelThreshold",
    Flag = "0",
    Description = "Minimum weight/value to shovel (0 = disabled).",
})
Automatically:createInputBox({
    Name = "Delay To Shovel Fruit",
    flagName = "shovelFruitDelay",
    Flag = "0",
    Description = "Delay between fruit shovel uses.",
})
createIntervalToggle(
    Automatically,
    {
        Name = "Auto Shovel Fruit",
        flagName = "autoShovelFruit",
        tag = "autoShovelFruit",
        delay = 3,
        Step = doShovelFruit,
    }
)

-- ================================================================
-- INVENTORY TAB
-- ================================================================

-- Automation Favorite
Inventory:createLabel({ Name = "Automation Favorite", Special = true })

Inventory:createDropdown({
    Name = "Select Favorite Fruit",
    flagName = "favFruit",
    List = getCropList(),
    Description = "Which fruit type to favorite.",
})
Inventory:createDropdown({
    Name = "Select Favorite Rarity",
    flagName = "favRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity for auto-favorite.",
})
Inventory:createDropdown({
    Name = "Select Favorite Mutation",
    flagName = "favMutation",
    List = { "Any", "Mutated Only", "Non-Mutated" },
    Flag = { "Any" },
    Description = "Mutation filter for auto-favorite.",
})
Inventory:createDropdown({
    Name = "Select Threshold Mode",
    flagName = "favThreshMode",
    List = { "Disabled", "Weight", "Value" },
    Flag = { "Disabled" },
    Description = "Threshold mode for auto-favorite.",
})
Inventory:createInputBox({
    Name = "Weight Threshold",
    flagName = "favThreshold",
    Flag = "0",
    Description = "Minimum weight/value to favorite (0 = disabled).",
})
Inventory:createToggle({
    Name = "Auto Favorite Fruit",
    Flag = false,
    flagName = "autoFav",
    Description = "Auto-favorite fruits matching filters.",
})
Inventory:createToggle({
    Name = "Auto UnFavorite Fruit",
    Flag = false,
    flagName = "autoUnfav",
    Description = "Auto-unfavorite fruits that don't match filters.",
})
Inventory:createToggle({
    Name = "Auto UnFavorite All Fruit",
    Flag = false,
    flagName = "autoUnfavAll",
    Description = "Remove all favorites from inventory.",
})

-- ================================================================
-- SHOP TAB
-- ================================================================

-- Shop Seeds
Shop:createLabel({ Name = "Shop Seeds", Special = true })

Shop:createDropdown({
    Name = "Select Seed",
    flagName = "buySeed",
    List = getSeedList(),
    multi = true,
    Description = "Which seed to auto-purchase.",
})
Shop:createToggle({
    Name = "Auto Buy Seeds",
    Flag = false,
    flagName = "autoBuySeed",
    Description = "Auto-purchase the selected seed.",
})
Shop:createToggle({
    Name = "Auto Buy All Seeds",
    Flag = false,
    flagName = "autoBuyAllSeeds",
    Description = "Buy every available seed in stock.",
})

-- Shop Gear
Shop:createLabel({ Name = "Shop Gear", Special = true })

Shop:createDropdown({
    Name = "Select Gear",
    flagName = "buyGear",
    List = getGearList(),
    Description = "Which gear item to auto-purchase.",
})
Shop:createToggle({
    Name = "Auto Buy Gear",
    Flag = false,
    flagName = "autoBuyGear",
    Description = "Auto-purchase the selected gear.",
})
Shop:createToggle({
    Name = "Auto Buy All Gear",
    Flag = false,
    flagName = "autoBuyAllGear",
    Description = "Buy every available gear item.",
})

-- Shop Crate
Shop:createLabel({ Name = "Shop Crate", Special = true })

Shop:createDropdown({
    Name = "Select Crate",
    flagName = "buyCrate",
    List = getCrateList(),
    Description = "Which crate to auto-purchase.",
})
Shop:createToggle({
    Name = "Auto Buy Crate",
    Flag = false,
    flagName = "autoBuyCrate",
    Description = "Auto-purchase the selected crate.",
})
Shop:createToggle({
    Name = "Auto Buy All Crate",
    Flag = false,
    flagName = "autoBuyAllCrates",
    Description = "Buy every available crate type.",
})

Shop:createSlider({
    Name = "Buy Sprees Per Cycle",
    flagName = "buySprees",
    value = 5,
    minValue = 1,
    maxValue = 25,
    Description = "How many of each to buy per cycle.",
})

-- ================================================================
-- WEBHOOK TAB
-- ================================================================

-- Config Webhook
Webhook:createLabel({ Name = "Config Webhook", Special = true })

Webhook:createInputBox({
    Name = "Webhook URL",
    flagName = "webhookUrl",
    Flag = "",
    Description = "Input your webhook URL.",
})
Webhook:createInputBox({
    Name = "Ping Message/ID",
    flagName = "whPing",
    Flag = "",
    Description = "Ping message or ID for notifications.",
})
Webhook:createToggle({
    Name = "Allow Ping On Ping Message/ID",
    Flag = false,
    flagName = "whAllowPing",
    Description = "Allow pings on the specified message/ID.",
})

-- Pets Purchase Webhook
Webhook:createLabel({ Name = "Pets Purchase Webhook", Special = true })

Webhook:createDropdown({
    Name = "Select Pets",
    flagName = "whPetFilter",
    List = getPetList(),
    Description = "Only notify for these pet types.",
})
Webhook:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "whPetRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum pet rarity to notify.",
})
Webhook:createDropdown({
    Name = "Select Size Pets",
    flagName = "whPetSize",
    List = { "Any", "Small", "Medium", "Large", "Huge" },
    Flag = { "Any" },
    Description = "Pet size filter for notifications.",
})
Webhook:createToggle({
    Name = "Pets Purchase Webhook",
    Flag = false,
    flagName = "whPetPurchase",
    Description = "Send webhook when a matching pet is purchased or tamed.",
})

-- Webhook Collection Event Seed
Webhook:createLabel({ Name = "Webhook Collection Event Seed", Special = true })

Webhook:createDropdown({
    Name = "Select Event Seed",
    flagName = "whEventSeed",
    List = getSeedList(),
    Description = "Which event/rare seeds to notify about.",
})
Webhook:createToggle({
    Name = "Webhook Collection Event Seed",
    Flag = false,
    flagName = "whEventSeedEnabled",
    Description = "Send webhook when a matching event seed is collected.",
})

-- ================================================================
-- MISC TAB
-- ================================================================

-- ESP
Misc:createLabel({ Name = "ESP", Special = true })

Misc:createLabel({ Name = "- [ ESP Fruit ] -", Special = true })
Misc:createDropdown({
    Name = "Select ESP Fruit",
    flagName = "espFruit",
    List = getCropList(),
    Description = "Which fruit type to highlight with ESP.",
})
Misc:createDropdown({
    Name = "Select ESP Rarity",
    flagName = "espFruitRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity for ESP.",
})
Misc:createDropdown({
    Name = "Select ESP Mutation",
    flagName = "espFruitMutation",
    List = { "Any", "Mutated Only", "Non-Mutated" },
    Flag = { "Any" },
    Description = "Mutation filter for ESP.",
})
Misc:createToggle({
    Name = "ESP Fruit",
    Flag = false,
    flagName = "espFruitEnabled",
    Description = "Highlight fruits matching filters through walls.",
})

Misc:createLabel({ Name = "- [ ESP Spawned Pets ] -", Special = true })
Misc:createDropdown({
    Name = "Select Pets",
    flagName = "espPet",
    List = getAllPetSpecies(),
    Description = "Which spawned pet type to ESP.",
})
Misc:createDropdown({
    Name = "Select Rarity Pets",
    flagName = "espPetRarity",
    List = RARITY_LIST,
    Flag = { "Any" },
    Description = "Minimum rarity for pet ESP.",
})
Misc:createDropdown({
    Name = "Select Size Pets",
    flagName = "espPetSize",
    List = { "Any", "Small", "Medium", "Large", "Huge" },
    Flag = { "Any" },
    Description = "Size filter for pet ESP.",
})
Misc:createToggle({
    Name = "ESP Spawned Pets",
    Flag = false,
    flagName = "espPetEnabled",
    Description = "Highlight spawned pets matching filters through walls.",
})

-- Misc
Misc:createLabel({ Name = "Misc", Special = true })

Misc:createLabel({ Name = "- [ Fling ] -", Special = true })
Misc:createToggle({
    Name = "Anti-Fling",
    Flag = true,
    flagName = "antiFling",
    Description = "Prevent other players from flinging you.",
})

Misc:createLabel({ Name = "- [ Knockback ] -", Special = true })
Misc:createToggle({
    Name = "Less Knockback",
    Flag = false,
    flagName = "lessKnockback",
    Description = "Reduce physical knockback from attacks and tools.",
})

Misc:createLabel({ Name = "- [ Prompt ] -", Special = true })
Misc:createToggle({
    Name = "Instant Interact Prompt",
    Flag = false,
    flagName = "instantPrompt",
    Description = "Skip proximity prompt hold timer.",
})

Misc:createLabel({ Name = "- [ Gameplay Paused ] -", Special = true })
Misc:createToggle({
    Name = "Bypass Gameplay Paused",
    Flag = true,
    flagName = "bypassPause",
    Description = "Prevent the gameplay paused screen from appearing.",
})

-- Misc Garden
Misc:createLabel({ Name = "Misc Garden", Special = true })

Misc:createLabel({ Name = "- [ Plants ] -", Special = true })
Misc:createToggle({
    Name = "Noclip Plants",
    Flag = false,
    flagName = "noclipPlants",
    Description = "Disable collision on plants for easy movement.",
})

-- Server
Misc:createLabel({ Name = "Server", Special = true })

Misc:createButton({
    Name = "Hop Server",
    Description = "Teleport to a different server.",
    Callback = function()
        serverHop(false)
    end,
})
Misc:createButton({
    Name = "Low-Pop Server Hop",
    Description = "Teleport to the emptiest server.",
    Callback = function()
        serverHop(true)
    end,
})
Misc:createButton({
    Name = "Rejoin Server",
    Description = "Rejoin this same server.",
    Callback = function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, client)
        end)
    end,
})
Misc:createLabel({ Name = "ESP Inventory", Special = true })
Misc:createToggle({
    Name = "ESP Fruit Value",
    Flag = false,
    flagName = "espFruitValue",
    Description = "World-space price tags above your crops and fruits (exact game sell math).",
})
Misc:createToggle({
    Name = "ESP Total Value",
    Flag = false,
    flagName = "espTotalValue",
    Description = "Small in-game panel with your garden's total sell value.",
})
Misc:createToggle({
    Name = "ESP Inventory Value",
    Flag = false,
    flagName = "espInvValue",
    Description = "Small panel showing your inventory's total sell value.",
})
Misc:createToggle({
    Name = "Only Use Base Value For ESP Fruit",
    Flag = false,
    flagName = "espBaseValueOnly",
    Description = "Value ESP shows base price only (ignores weight and mutations).",
})
Misc:createToggle({
    Name = "Rare Seed Restock Alert",
    Flag = false,
    flagName = "rareNotify",
    Description = "Notify when a pricey seed hits the shop.",
})
Misc:createButton({
    Name = "Refresh ESP Lists",
    Description = "Update ESP dropdowns.",
    Callback = function()
        local function upd(tag, list)
            local dd = Misc:FindFirstChild(tag)
            if dd and dd.updateList then
                dd:updateList(list)
            end
        end
        upd("espFruit", getCropList())
        upd("espPet", getAllPetSpecies())
        notify("ESP", "Lists refreshed")
    end,
})

Misc:createLabel({ Name = "Player & Account", Special = true })

Misc:createInputBox({
    Name = "Promo Code",
    flagName = "redeemCode",
    Flag = "",
    Description = "Enter a promo code to redeem.",
})
Misc:createButton({
    Name = "Redeem Code",
    Description = "Redeem the entered promo code.",
    Callback = function()
        task.spawn(doRedeemCode)
    end,
})


Misc:createLabel({ Name = "Movement", Special = true })
Misc:createSlider({
    Name = "Walk Speed",
    flagName = "runSpeed",
    value = 16,
    minValue = 16,
    maxValue = 250,
    Description = "Override character walk speed.",
})
Misc:createSlider({
    Name = "Jump Height",
    flagName = "jumpHeight",
    value = 7.2,
    minValue = 7.2,
    maxValue = 100,
    Description = "Override character jump power.",
})
Misc:createToggle({
    Name = "Multi Jump",
    Flag = false,
    flagName = "multiJump",
    Description = "Allow multiple jumps in the air (capped at 3).",
})
Misc:createToggle({
    Name = "Infinite Jump",
    Flag = false,
    flagName = "infJump",
    Description = "Unlimited jump by forcing Jumping state.",
})
Misc:createToggle({
    Name = "Noclip",
    Flag = false,
    flagName = "noClip",
    Description = "Walk through walls and fences.",
    Callback = function(enabled)
        if not enabled then
            local character = client.Character
            if character then
                for _, p in ipairs(character:GetDescendants()) do
                    if p:IsA("BasePart") then
                        pcall(function()
                            p.CanCollide = true
                        end)
                    end
                end
            end
        end
    end,
})
Misc:createToggle({
    Name = "Fly",
    Flag = false,
    flagName = "freeFlight",
    Description = "Free-fly with WASD, Space up, Shift down.",
    Callback = function(enabled)
        if not enabled then
            stopFly()
        end
    end,
})
Misc:createSlider({
    Name = "Fly Speed",
    flagName = "flightSpeed",
    value = 50,
    minValue = 10,
    maxValue = 200,
    Description = "How fast flight mode moves.",
})

local function tpBtn(label, pad)
    Misc:createButton({
        Name = label,
        Description = "Travel to the " .. label .. ".",
        Callback = function()
            local t = Workspace:FindFirstChild("Teleports")
            local d = t and t:FindFirstChild(pad)
            if d and d:IsA("BasePart") then
                teleport(d.Position)
                notify("Teleport", "Went to " .. label)
            else
                notify("Teleport", label .. " not found", "warning")
            end
        end,
    })
end
tpBtn("Seed Shop", "Seeds")
tpBtn("Gear Shop", "Gears")
tpBtn("Sell NPC", "Sell")
tpBtn("Props Shop", "Props")
Misc:createButton({
    Name = "My Garden",
    Description = "Return to your own plot.",
    Callback = function()
        local plot = myPlot()
        local sp = plot and plot:FindFirstChild("SpawnPoint")
        if sp then
            teleport(sp.Position)
            notify("Teleport", "Went to your garden")
        else
            notify("Teleport", "Garden not found", "warning")
        end
    end,
})

Misc:createLabel({ Name = "Stats", Special = true })
Misc:createLabel({ Name = "Balance: $0", flagName = "statBalance", Special = true })
Misc:createLabel({ Name = "Per Minute: $0", flagName = "statPerMin", Special = true })
Misc:createLabel({ Name = "Session Earned: $0", flagName = "statSession", Special = true })
Misc:createLabel({ Name = "Fruit Count: 0/0", flagName = "statFruitCount", Special = true })
Misc:createLabel({ Name = "Crops Harvested: 0", flagName = "statHarvested", Special = true })
Misc:createLabel({ Name = "Session Time: 0m", flagName = "statSessionTime", Special = true })
Misc:createButton({
    Name = "Reset Session Stats",
    Description = "Zero out the profit tracker.",
    Callback = function()
        sessionEarned = 0
        sessionHarvests = 0
        sessionStart = os.clock()
        notify("Stats", "Session stats reset")
    end,
})

-- ================================================================
-- DEV TOOLS TAB
-- ================================================================

DevTools:createLabel({ Name = "Debug", Special = true })
DevTools:createToggle({
    Name = "Debug Logging",
    Flag = true,
    flagName = "debugLogging",
    Description = "Log every remote fire, equip and error to console + gag2_debug_log.txt.",
    Callback = function(v)
        DebugLogOn = v and true or false
    end,
})
DevTools:createButton({
    Name = "Dump Debug Log",
    Description = "Save the live action log (fires, equips, errors) to gag2_debug_log.txt.",
    Callback = function()
        if #DebugLogBuf == 0 then
            notify("Debug", "No log entries yet - enable toggles first", "warning")
            return
        end
        local ok, err = pcall(function()
            local payload = "GAG2 debug log " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" .. table.concat(DebugLogBuf, "\n") .. "\n"
            writefile("gag2_debug_log.txt", payload)
        end)
        if ok then
            LastDebugDump = #DebugLogBuf
            notify("Debug", "Saved " .. #DebugLogBuf .. " entries to gag2_debug_log.txt")
        else
            notify("Debug", "writefile failed: " .. tostring(err), "warning")
        end
    end,
})
DevTools:createButton({
    Name = "Dump Packet Names",
    Description = "Print all real remote packet names + IDs from the game's Packet module to console.",
    Callback = function()
        local pk = ReplicatedStorage and ReplicatedStorage:FindFirstChild("SharedModules")
            and ReplicatedStorage.SharedModules:FindFirstChild("Packet")
        local ev = pk and pk:FindFirstChild("RemoteEvent")
        if not (ev and ev.GetAttributes) then
            notify("Packets", "Packet module / RemoteEvent not found", "warning")
            return
        end
        local attrs = pcall(function()
            return ev:GetAttributes()
        end)
        if not attrs then
            notify("Packets", "Failed to read packet attributes", "warning")
            return
        end
        local count = 0
        local lines = {}
        for name, id in pairs(ev:GetAttributes()) do
            if type(name) == "string" then
                count = count + 1
                lines[#lines + 1] = string.format("[%s] id=%s", name, tostring(id))
            end
        end
        table.sort(lines)
        local text = table.concat(lines, "\n")
        for _, line in ipairs(lines) do
            print("[GAG2] packet " .. line)
        end
        local okClip, errClip = pcall(function()
            setclipboard(text)
        end)
        local filePath = nil
        if writefile then
            pcall(function()
                filePath = "gag2_packets_" .. tostring(os.date("%Y%m%d_%H%M%S")) .. ".txt"
                writefile(filePath, text)
            end)
        end
        local extras = {}
        if okClip then
            extras[#extras + 1] = "copied to clipboard"
        else
            extras[#extras + 1] = "clipboard failed: " .. tostring(errClip)
        end
        if filePath then
            extras[#extras + 1] = "saved to " .. filePath
        end
        notify("Packets", count .. " packet names dumped - " .. table.concat(extras, ", "))
    end,
})

-- ================================================================
-- SETTINGS TAB
-- ================================================================

Settings:createLabel({ Name = "High-Stability AFK & Protections", Special = true })
Settings:createToggle({
    Name = "Ultra AFK Mode (Disable 3D Rendering + 15 FPS)",
    Flag = false,
    flagName = "ultraAfkMode",
    Description = "Turn off viewport 3D rendering and cap FPS to 15 to prevent crashes and mobile overheating overnight.",
    Callback = function(enabled)
        StabilityEngine:SetAFKThrottling(enabled, 15)
        notify("AFK Mode", enabled and "3D Rendering Disabled (Ultra AFK Active)" or "3D Rendering & FPS Restored")
    end,
})
Settings:createToggle({
    Name = "Anti-Stuck & Auto-Respawn Watchdog",
    Flag = true,
    flagName = "antiStuckWatchdog",
    Description = "Automatically detect if character is stuck while farming and perform unstuck jump/teleport.",
    Callback = function(enabled)
        if not enabled then
            StabilityEngine:StopAntiStuckWatchdog()
            return
        end
        if enabled then
            StabilityEngine:StartAntiStuckWatchdog(2, 20)
        elseif StabilityEngine._watchdogConn then
            StabilityEngine._watchdogConn:Disconnect()
            StabilityEngine._watchdogConn = nil
        end
    end,
})

Settings:createToggle({
    Name = "VersusAI Pathing",
    flagName = "UseVersusAI",
    Flag = false,
    Warning = function()
        return "Placeholder - only smooths teleport interpolation"
    end,
    WarnIf = function()
        return true
    end,
    Description = "Smooth interpolation fallback until a real pathing backend is wired.",
})

Settings:createLabel({ Name = "Performance", Special = true })
local optConns
local function optimizeInstance(o)
    pcall(function()
        if o:IsA("BasePart") then
            o.Material = Enum.Material.SmoothPlastic
            o.Reflectance = 0
            o.CastShadow = false
        elseif o:IsA("Decal") or o:IsA("Texture") then
            o.Transparency = 1
        elseif
            o:IsA("ParticleEmitter")
            or o:IsA("Trail")
            or o:IsA("Beam")
            or o:IsA("Smoke")
            or o:IsA("Fire")
            or o:IsA("Sparkles")
            or o:IsA("PostEffect")
        then
            o.Enabled = false
        end
    end)
end
Settings:createToggle({
    Name = "Extreme FPS Optimizer",
    Flag = false,
    flagName = "moreFps",
    Description = "Aggressive FPS boost (flat textures, grey sky, no effects).",
    Callback = function(enabled)
        if enabled then
            pcall(function()
                LightingService.GlobalShadows = false
                LightingService.FogColor = Color3.fromRGB(131, 133, 139)
                LightingService.FogStart = 220
                LightingService.FogEnd = 780
                LightingService.OutdoorAmbient = Color3.fromRGB(140, 140, 146)
            end)
            for _, e in ipairs(LightingService:GetDescendants()) do
                if e:IsA("Atmosphere") or e:IsA("Clouds") or e:IsA("PostEffect") then
                    pcall(function()
                        e.Enabled = false
                    end)
                end
                if e:IsA("Sky") then
                    pcall(function()
                        e.CelestialBodiesShown = false
                    end)
                end
            end
            pcall(function()
                Workspace.Terrain.Decoration = false
            end)
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            for _, o in ipairs(Workspace:GetDescendants()) do
                optimizeInstance(o)
            end
            local function onAdd(o)
                if Library.Flags["moreFps"] then
                    task.defer(optimizeInstance, o)
                end
            end
            optConns = { Workspace.DescendantAdded:Connect(onAdd), LightingService.DescendantAdded:Connect(onAdd) }
        else
            if optConns then
                for _, c in ipairs(optConns) do
                    pcall(function()
                        c:Disconnect()
                    end)
                end
                optConns = nil
            end
            notify("FPS", "Optimizer disabled. Rejoin to restore all textures.")
        end
    end,
})
Settings:createButton({
    Name = "Remove Other Players' Gardens",
    Description = "Hide every other garden (client-side) for FPS. Rejoin to restore.",
    Callback = function()
        local n = removeOtherGardens()
        notify("FPS", "Removed " .. n .. " other gardens (client-side)")
    end,
})
Settings:createToggle({
    Name = "Auto Remove Other Gardens",
    Flag = false,
    flagName = "autoRemoveGardens",
    Description = "Auto-remove other players' gardens when new ones stream in.",
})

Settings:createLabel({ Name = "Server", Special = true })
Settings:createButton({
    Name = "Server Hop",
    Description = "Teleport to a different server.",
    Callback = function()
        serverHop(false)
    end,
})
Settings:createButton({
    Name = "Low-Pop Server Hop",
    Description = "Teleport to the emptiest server.",
    Callback = function()
        serverHop(true)
    end,
})
Settings:createButton({
    Name = "Rejoin Server",
    Description = "Rejoin this same server.",
    Callback = function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, client)
        end)
    end,
})
createIntervalToggle(Settings, {
    Name = "Auto Hop Until Rare Seed",
    flagName = "autoHopRare",
    tag = "autoHopRare",
    delay = 20,
    Step = function()
        if not rareSeedInStock() then
            serverHop(false)
        end
    end,
})
Settings:createLabel({ Name = "Configuration", Special = true })
Settings:createButton({
    Name = "Save Settings",
    Description = "Save current settings to file.",
    Callback = function()
        saveSettings()
        notify("Settings", "Saved to " .. SAVE_FILE)
    end,
})
Settings:createButton({
    Name = "Load Settings",
    Description = "Load settings from file.",
    Callback = function()
        loadSettings()
        notify("Settings", "Loaded from " .. SAVE_FILE)
    end,
})
Settings:createButton({
    Name = "Reset to Defaults",
    Description = "Clear all saved settings.",
    Callback = function()
        if writefile then
            pcall(function()
                writefile(SAVE_FILE, "{}")
            end)
        end
        notify("Settings", "Defaults restored")
    end,
})
Settings:createToggle({
    Name = "Auto Save on Changes",
    Flag = false,
    flagName = "autoSave",
    Description = "Automatically save settings when toggles change.",
})
Settings:createLabel({ Name = "Config: " .. SAVE_FILE, Special = true })

-- ================================================================
-- VISUAL TAB (client-side only - fake inventory preview)
-- ================================================================

-- These mutate the LOCAL PlayerState replica only. The server ignores
-- them and overwrites on the next sync - purely visual previews.
local fakeInjected = {}

local function localReplicaData()
    local replica = getReplica()
    if not replica then
        return nil
    end
    local ok, data = pcall(function()
        return replica.Data
    end)
    return ok and data or nil
end

local function ensureInventoryPath()
    local data = localReplicaData()
    if not data then
        return nil
    end
    data.Inventory = data.Inventory or {}
    return data
end

local function visualNotify(msg)
    notify("Visual", msg, "info")
end

Visual:createLabel({ Name = "Fake Money", Special = true })
Visual:createInputBox({
    Name = "Fake Sheckles Amount",
    flagName = "visualMoneyAmount",
    Flag = "1000000",
    Description = "Amount shown in the local balance (client-side only).",
})
Visual:createButton({
    Name = "Set Fake Sheckles",
    Description = "Overwrite the local balance display.",
    Callback = function()
        local data = localReplicaData()
        if not data then
            visualNotify("Player state not ready yet")
            return
        end
        local amount = tonumber(Library.Flags["visualMoneyAmount"]) or 0
        pcall(function()
            if fakeInjected["sheckles"] == nil then
                fakeInjected["sheckles"] = data.Sheckles or 0
            end
            data.Sheckles = amount
        end)
        visualNotify("Fake Sheckles set to $" .. amount)
    end,
})

Visual:createLabel({ Name = "Fake Seeds", Special = true })
Visual:createInputBox({
    Name = "Seed Name",
    flagName = "visualSeedName",
    Flag = "Gold",
    Description = "Seed to add to the local inventory.",
})
Visual:createInputBox({
    Name = "Seed Count",
    flagName = "visualSeedCount",
    Flag = "100",
    Description = "How many to show (client-side only).",
})
Visual:createButton({
    Name = "Add Fake Seed",
    Description = "Inject a seed into the local inventory view.",
    Callback = function()
        local data = ensureInventoryPath()
        if not data then
            visualNotify("Player state not ready yet")
            return
        end
        local name = tostring(Library.Flags["visualSeedName"] or "")
        local count = tonumber(Library.Flags["visualSeedCount"]) or 1
        if name == "" then
            visualNotify("Enter a seed name first")
            return
        end
        pcall(function()
            data.Inventory.Seeds = data.Inventory.Seeds or {}
            data.Inventory.Seeds[name] = (data.Inventory.Seeds[name] or 0) + count
        end)
        fakeInjected["seed:" .. name] = true
        visualNotify("Fake seed added: " .. name .. " x" .. count)
    end,
})

Visual:createLabel({ Name = "Fake Pets", Special = true })
Visual:createInputBox({
    Name = "Pet Type",
    flagName = "visualPetType",
    Flag = "Cat",
    Description = "Pet species to add to the local inventory.",
})
Visual:createInputBox({
    Name = "Pet Count",
    flagName = "visualPetCount",
    Flag = "5",
    Description = "How many to show (client-side only).",
})
Visual:createButton({
    Name = "Add Fake Pet",
    Description = "Inject pets into the local inventory view.",
    Callback = function()
        local data = ensureInventoryPath()
        if not data then
            visualNotify("Player state not ready yet")
            return
        end
        local ptype = tostring(Library.Flags["visualPetType"] or "")
        local count = tonumber(Library.Flags["visualPetCount"]) or 1
        if ptype == "" then
            visualNotify("Enter a pet type first")
            return
        end
        pcall(function()
            data.Inventory.Pets = data.Inventory.Pets or {}
            for _ = 1, count do
                data.Inventory.Pets[#data.Inventory.Pets + 1] = { PetType = ptype, Name = ptype }
            end
        end)
        fakeInjected["pet:" .. ptype] = true
        visualNotify("Fake pet added: " .. ptype .. " x" .. count)
    end,
})

Visual:createLabel({ Name = "Reset", Special = true })
Visual:createButton({
    Name = "Reset All Visuals",
    Description = "Clear injected fake values (server sync would do it anyway).",
    Callback = function()
        local data = localReplicaData()
        if data then
            pcall(function()
                data.Sheckles = fakeInjected["sheckles"] or 0
            end)
        end
        fakeInjected = {}
        visualNotify("Visuals reset - waiting for server sync")
    end,
})

-- ================================================================
-- BACKGROUND LOOPS
-- ================================================================

-- sell on interval (single driver - no more double-mechanism)
local _lastSell = 0
local _lastDailyDeal = 0
track(RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if Library.Flags["autoSell"] then
        local si = tonumber(Library.Flags["sellInterval"]) or 20
        if now - _lastSell >= si then
            _lastSell = now
            doSellAll()
        end
    end
    -- sell on full
    if Library.Flags["sellOnFull"] and isInventoryFull() then
        doSellAll()
    end
    -- daily deal (rate-limited to ~1/s to avoid spam)
    if Library.Flags["dailyDeal"] and now - _lastDailyDeal >= 1 then
        _lastDailyDeal = now
        netFire("NPCS.UseDailyDealAll")
    end
end))

-- consolidated 2s loop: defense, notify, ESP, highlights, passives
task.spawn(function()
    local espTimer = 0
    local promptTimer = 0
    local weatherTimerCnt = 0
    while task.wait(2) do
        if not Hub.running then
            break
        end
        pcall(function()
            if Library.Flags["hitStolen"] then
                doRetaliateShovel()
            end
            if Library.Flags["rareNotify"] then
                doRareNotify()
            end
            if Library.Flags["antiFling"] then
                doAntiFling()
            end            if Library.Flags["bypassPause"] then
                doBypassPause()
            end
            if Library.Flags["noclipPlants"] then
                doNoclipPlants()
            end
            if Library.Flags["lessKnockback"] then
                doLessKnockback()
            end
            if Library.Flags["petProtection"] then
                doPetProtection()
            end
            if Library.Flags["autoBuyPet"] then
                doAutoBuyPet()
            end
            -- auto sell selective / pets
            if Library.Flags["autoSellSelective"] then
                doSellSelective()
            end
            if Library.Flags["autoSellPets"] then
                doSellPets()
            end
            -- auto buy all (with dedup: only buy each item once per restock)
            local function clearPurchaseTracking(stockParent, shopKey)
                local lastRestock = _purchaseCycleRestocks[shopKey]
                local curRestock = stockParent and stockParent:FindFirstChild("UnixNextRestock")
                local curRestockVal = curRestock and curRestock.Value
                if lastRestock and curRestockVal and curRestockVal ~= lastRestock then
                    _purchasedThisCycle[shopKey] = {}
                end
                if curRestockVal then
                    _purchaseCycleRestocks[shopKey] = curRestockVal
                end
            end
            if Library.Flags["autoBuyAllSeeds"] then
                local stockParent = seedStock()
                if stockParent then
                    clearPurchaseTracking(stockParent, "SeedShop")
                    _purchasedThisCycle["SeedShop"] = _purchasedThisCycle["SeedShop"] or {}
                    for _, stockValue in ipairs(stockParent:GetChildren()) do
                        if
                            stockValue:IsA("ValueBase")
                            and stockValue.Value > 0
                            and not _purchasedThisCycle["SeedShop"][stockValue.Name]
                            and getBalance() >= (SeedPrice[stockValue.Name] or 0)
                        then
                            netFire("SeedShop.PurchaseSeed", stockValue.Name)
                            _purchasedThisCycle["SeedShop"][stockValue.Name] = true
                            task.wait(0.08)
                        end
                    end
                end
            end
            if Library.Flags["autoBuyAllGear"] then
                local stockParent = gearStock()
                if stockParent then
                    clearPurchaseTracking(stockParent, "GearShop")
                    _purchasedThisCycle["GearShop"] = _purchasedThisCycle["GearShop"] or {}
                    for _, stockValue in ipairs(stockParent:GetChildren()) do
                        if
                            stockValue:IsA("ValueBase")
                            and stockValue.Value > 0
                            and not _purchasedThisCycle["GearShop"][stockValue.Name]
                        then
                            netFire("GearShop.PurchaseGear", stockValue.Name)
                            _purchasedThisCycle["GearShop"][stockValue.Name] = true
                            task.wait(0.08)
                        end
                    end
                end
            end
            if Library.Flags["autoBuyAllCrates"] then
                local stockParent = crateStock()
                if stockParent then
                    clearPurchaseTracking(stockParent, "CrateShop")
                    _purchasedThisCycle["CrateShop"] = _purchasedThisCycle["CrateShop"] or {}
                    for _, stockValue in ipairs(stockParent:GetChildren()) do
                        if
                            stockValue:IsA("ValueBase")
                            and stockValue.Value > 0
                            and not _purchasedThisCycle["CrateShop"][stockValue.Name]
                        then
                            netFire("CrateShop.PurchaseCrate", stockValue.Name)
                            _purchasedThisCycle["CrateShop"][stockValue.Name] = true
                            task.wait(0.08)
                        end
                    end
                end
            end
            -- auto water all
            if Library.Flags["autoWaterAll"] then
                doWateringCan()
            end
            -- auto place all sprinklers
            if Library.Flags["autoSprinklerAll"] then
                doSprinklerAll()
            end
            -- auto expand garden
            if Library.Flags["autoExpand"] then
                netFire("Actions.ExpandGarden")
            end
            -- auto favorite/unfavorite
            if Library.Flags["autoFav"] then
                doFavorite(true)
            end
            if Library.Flags["autoUnfav"] then
                doFavorite(false)
            end
            if Library.Flags["autoUnfavAll"] then
                doFavorite(false, true)
            end
            -- auto mailbox
            if Library.Flags["autoSendSeed"] or Library.Flags["autoSendPet"] then
                doMailboxSend()
            end
            -- ESP
            if Library.Flags["espFruitEnabled"] or Library.Flags["espPetEnabled"] then
                espTimer = espTimer + 1
                if espTimer >= 1 then
                    espTimer = 0
                    doESP()
                end
            elseif next(_espPool) then
                clearESP()
            end
            -- instant prompt
            if Library.Flags["instantPrompt"] then
                promptTimer = promptTimer + 1
                if promptTimer >= 3 then
                    promptTimer = 0
                    doInstantPrompt()
                end
            end
            -- auto remove gardens
            if Library.Flags["autoRemoveGardens"] then
                removeOtherGardens()
            end
            -- stats update
            local bal = getBalance()
            local elapsed = os.clock() - sessionStart
            local earned = bal - (sessionStartBal or bal)
            if earned > sessionEarned then
                sessionEarned = earned
            end

            -- Rolling 60s profit window
            local now = os.clock()
            table.insert(profitWindow, { t = now, s = bal })
            while #profitWindow > 1 and (now - profitWindow[1].t) > 60 do
                table.remove(profitWindow, 1)
            end
            local perMin = 0
            if #profitWindow > 1 then
                local dt = now - profitWindow[1].t
                if dt > 2 then
                    perMin = (bal - profitWindow[1].s) / dt * 60
                end
            end

            local fc = getFruitCount()
            local mc = getMaxCapacity()
            local function ul(tag, text)
                local lb = Misc:FindFirstChild(tag)
                if lb and lb.updateText then
                    lb:updateText(text)
                end
            end
            local invVal = 0
            local d = getData()
            if d and d.Inventory and d.Inventory.HarvestedFruits then
                for _, finfo in pairs(d.Inventory.HarvestedFruits) do
                    if type(finfo) == "table" then
                        local fname = finfo.FruitName or finfo.Seed or finfo.Name or ""
                        local weight = tonumber(finfo.SizeMultiplier or finfo.Weight or finfo.SizeMulti or 1) or 1
                        local mname = type(finfo.Mutation) == "string" and finfo.Mutation or nil
                        invVal = invVal + ValueEngine.compute(fname, weight, mname)
                    elseif type(finfo) == "number" then
                        invVal = invVal + finfo
                    end
                end
            end
            local invValStr = invVal > 0 and (" ($" .. fmtCash(math.floor(invVal)) .. ")") or ""
            ul("statBalance", "Balance: " .. fmtCash(bal))
            ul("statPerMin", "Per Minute: " .. fmtCash(perMin))
            ul("statSession", "Session Earned: " .. fmtCash(sessionEarned))
            ul("statFruitCount", "Fruit Count: " .. fc .. "/" .. mc .. invValStr)
            ul("statHarvested", "Crops Harvested: " .. sessionHarvests)
            ul("statSessionTime", "Session Time: " .. math.floor(elapsed / 60) .. "m")
            -- home tab live stats
            local function hl(tag, text)
                local lb = Home:FindFirstChild(tag)
                if lb and lb.updateText then
                    lb:updateText(text)
                end
            end
            hl("homeBalance", "Balance: " .. fmtCash(bal))
            hl("homeEarned", "Session Earned: " .. fmtCash(sessionEarned))
            hl("homeHarvested", "Crops Harvested: " .. sessionHarvests)
            hl("homeFruit", "Fruit: " .. fc .. "/" .. mc .. invValStr)
            hl("homeTime", "Time: " .. math.floor(elapsed / 60) .. "m")
            ValueESP.update()
        end, function(err)
            DebugLog("mainLoop", "error", tostring(err))
        end)
    end
end)

-- pack grab + collect loop (faster - 0.6s)
task.spawn(function()
    while task.wait(0.6) do
        if not Hub.running then
            break
        end
        pcall(function()
            if Library.Flags["autoCollect"] or Library.Flags["autoCollectAll"] or Library.Flags["autoCollectBest"] then
                doHarvest()
            end
            if Library.Flags["collectGold"] or Library.Flags["collectRainbow"] then
                doPackGrab()
            end
            if Library.Flags["collectDropped"] then
                doCollectDropped()
            end
        end)
    end
end)

-- pack return & panic harvest
task.spawn(function()
    local wasNight = false
    while task.wait(1) do
        if not Hub.running then
            break
        end
        pcall(function()
            local n = isNight()
            if not wasNight and n and Library.Flags["panicHarvest"] then
                notify("Defense", "Panic Harvesting! Night has fallen.", "warning")
                doHarvest(true) -- harvest everything quickly
            end
            if
                wasNight
                and not n
                and (Library.Flags["autoCollect"] or Library.Flags["collectGold"] or Library.Flags["collectRainbow"])
            then
                local plot = myPlot()
                local sp = plot and plot:FindFirstChild("SpawnPoint")
                if sp then
                    teleport(sp.Position)
                    notify("Event", "Event over - returned to garden")
                end
            end
            wasNight = n
        end)
    end
end)

-- movement + fly (RenderStepped)
track(RunService.RenderStepped:Connect(function(dt)
    pcall(function()
        doMoveLoop()
        doFlySystem(dt)
    end)
end))

-- multi-jump (fixed precedence)
local jumped = 0
track(UserInputService.JumpRequest:Connect(function()
    if Library.Flags["infJump"] then
        local character = client.Character
        local h = character and character:FindFirstChildOfClass("Humanoid")
        if h then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        return
    end
    if not Library.Flags["multiJump"] then
        return
    end
    local character = client.Character
    if not character then
        return
    end
    local h = character:FindFirstChildOfClass("Humanoid")
    if not h then
        return
    end
    if h.FloorMaterial == Enum.Material.Air then
        jumped = jumped + 1
        if jumped <= 3 then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Velocity =
                    Vector3.new(hrp.Velocity.X, (tonumber(Library.Flags["jumpHeight"]) or 7.2) * 50, hrp.Velocity.Z)
            end
        end
    else
        jumped = 0
    end
end))

-- harvest tracking
task.spawn(function()
    local last = getFruitCount()
    while task.wait(1) do
        if not Hub.running then
            break
        end
        pcall(function()
            local cur = getFruitCount()
            if cur > last then
                sessionHarvests = sessionHarvests + (cur - last)
            end
            last = cur
        end)
    end
end)

-- lifecycle tracking + unload
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
    pcall(function()
        ValueESP.destroy()
    end)
    if optConns then
        for _, c in ipairs(optConns) do
            pcall(function()
                c:Disconnect()
            end)
        end
        optConns = nil
    end
    if _plantConns then
        for _, c in ipairs(_plantConns) do
            pcall(function()
                c:Disconnect()
            end)
        end
        _plantConns = {}
    end

    clearESP()
    stopFly()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.PlatformStand = false
    end
    setCollide(true)
    StabilityEngine:StopAntiStuckWatchdog()
    StabilityEngine:SetAFKThrottling(false)
    print("[GAG2] unloaded.")
end
if getgenv then
    getgenv().GAG2_unload = Hub.unload
end

-- cleanup on close
if Setup.OnClose then
    track(Setup.OnClose:Connect(function()
        Hub.unload()
        if Library.Flags["autoSave"] then
            saveSettings()
        end
    end))
end

-- ================================================================
-- INIT
-- ================================================================

-- ensure programmatically-set flags exist so loadSettings can populate them
Library.Flags["savedPlantPos"] = Library.Flags["savedPlantPos"] or false
Library.Flags["savedSprinklerPos"] = Library.Flags["savedSprinklerPos"] or false
Library.Flags["savedTrowelPos"] = Library.Flags["savedTrowelPos"] or false

loadSettings()

-- re-apply movement settings on respawn
track(client.CharacterAdded:Connect(function(character)
    task.wait(0.6)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = tonumber(Library.Flags["runSpeed"]) or 16
        humanoid.UseJumpPower = true
        humanoid.JumpHeight = tonumber(Library.Flags["jumpHeight"]) or 7.2
    end
end))

print("[GAG2] Loaded successfully (" .. os.date("%H:%M:%S") .. ")")
print("[GAG2] Player: " .. client.Name .. " | UserId: " .. client.UserId)
print(
    "[GAG2] Network: "
        .. tostring(Network ~= nil)
        .. " | SeedData: "
        .. tostring(SeedData ~= nil)
        .. " | PetCache: "
        .. tostring(PetCache ~= nil)
        .. " | FruitCalc: "
        .. tostring(FruitValueCalc ~= nil)
)
notify("GAG2", "9 tabs loaded - Value ESP", "info")
