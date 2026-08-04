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

-- Platform & Stability
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

                if Flags and (
                    Flags["autoCollect"]
                    or Flags["autoCollectAll"]
                    or Flags["autoPlant"]
                    or Flags["autoSteal"]
                    or Flags["autoBuyPet"]
                    or Flags["autoSprinklerAll"]
                    or Flags["autoWaterAll"]
                ) then
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
        if true then
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

-- ═══════════════════════════════════════════════════════════════
-- Fluent Pro Library Loader
-- ═══════════════════════════════════════════════════════════════
print("Loading Fluent Pro...")
local Fluent = nil
pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"))()
end)

if not Fluent then
    local noop = function() end
    local d = function() return {SetText=noop,SetValue=noop,SetValues=noop} end
    Fluent = {CreateWindow=function()return{AddTab=function()return{AddToggle=function(i,c)if c and c.Default then Flags[i]=c.Default end return d()end,AddDropdown=function(i,c)if c and c.Default then Flags[i]=c.Default end return d()end,AddInput=function(i,c)if c and c.Default then Flags[i]=c.Default end return d()end,AddSlider=function(i,c)if c and c.Default then Flags[i]=c.Default end return d()end,AddButton=function()return d()end,AddParagraph=function()return d()end,AddDivider=noop,AddSpace=noop,AddCollapsibleSection=function()return d()end,AddGroup=function()return{AddToggle=d,AddDropdown=d,AddInput=d,AddSlider=d,AddButton=d,AddParagraph=d}end,AddKeybind=d}end,OnClose={Connect=noop}}end,Notify=noop,SetTheme=noop}
end

local Window = Fluent:CreateWindow({
    Title = "opencode · GAG2",
    SubTitle = "auto-farm · Fluentity",
    TabWidth = 150,
    Size = UDim2.fromOffset(640, 540),
    Acrylic = true,
    Theme = "AMOLED",
    MinimizeKey = Enum.KeyCode.LeftControl,
    Search = true,
})

Window.OnClose:Connect(function()
    Hub.unload()
    if Flags["autoSave"] then saveSettings() end
end)

local UpdateLabels = {}
local TrackedConns = {}
local IntervalTog = {}

local function track(conn) table.insert(TrackedConns, conn) end

local function notify(title, desc, style)
    pcall(function() Fluent:Notify({Title=title, Content=desc, Duration=style=="warning" and 4 or 2}) end)
end

local function intervalToggle(tab, id, flag, cfg)
    local timer = 0
    tab:AddToggle(id, {Title=cfg.Name,Default=cfg.Flag or false,Callback=function(v)Flags[flag]=v;if not v then IntervalTog[flag]=nil end end})
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not Flags[flag] then return end
        timer = timer + dt
        local d = tonumber(Flags[cfg.delayFlag] or tostring(cfg.delay)) or cfg.delay
        if timer >= d and cfg.Step then timer = 0 task.spawn(function() pcall(cfg.Step) end) end
    end)
    IntervalTog[flag] = conn; track(conn)
end


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
    local buf = DebugLogBuf
    if #buf >= 2000 then
        local out = {}
        for i = 1001, #buf do
            out[#out + 1] = buf[i]
        end
        DebugLogBuf = out
        buf = out
    end
    buf[#buf + 1] = line
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
    while Hub.running do
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
    -- packet-less fallback: force-load Packet module first
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
DebugLog(
    "bootstrap",
    "Network resolved",
    "hasPlantSeed=" .. tostring(Network.Plant and Network.Plant.PlantSeed ~= nil),
    "leafType=" .. typeof(Network.Plant and Network.Plant.PlantSeed)
)
mod = tryRequire(function()
    local cm = ReplicatedStorage:FindFirstChild("ClientModules")
        or ReplicatedStorage:WaitForChild("ClientModules", 10)
    local cms = ReplicatedStorage.ClientModules
    return require(
        cm and (cm:FindFirstChild("PlayerStateClient")
            or cm:WaitForChild("PlayerStateClient", 10))
        or (cms and cms.PlayerStateClient)
    )
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
    local sd = ReplicatedStorage:FindFirstChild("SharedData")
        or ReplicatedStorage:WaitForChild("SharedData", 10)
    local rcsd = ReplicatedStorage.SharedData
    return require(
        sd and (
            sd:FindFirstChild("PetData")
            or sd:FindFirstChild("Pets")
            or sd:FindFirstChild("PetCache")
            or sd:WaitForChild("PetData", 5)
        )
        or (rcsd and rcsd.PetData)
    )
end)
if mod then
    PetCache = mod
end
mod = tryRequire(function()
    local sm = ReplicatedStorage:FindFirstChild("SharedModules")
        or ReplicatedStorage:WaitForChild("SharedModules", 10)
    local rcsm = ReplicatedStorage.SharedModules
    return require(
        sm and (sm:FindFirstChild("FruitValueCalc")
            or sm:WaitForChild("FruitValueCalc", 10))
        or (rcsm and rcsm.FruitValueCalc)
    )
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
-- Value engine: mirrors game FruitValueCalc logic
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
local EVENT_NAME = {
    Day = "Day", Sunset = "Sunset", Moon = "Moon", Bloodmoon = "Blood Moon",
    Goldmoon = "Gold Moon", ["Rainbow Moon"] = "Rainbow Moon",
    ["Chained Moon"] = "Chained Moon", ["Pizza Moon"] = "Pizza Moon",
}
local function eventNameOf(r)
    return EVENT_NAME[r] or tostring(r or "-")
end
local function fmtClock(s)
    s = math.max(0, math.floor(s or 0))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
local function currentEvent()
    return workspace:GetAttribute("ActiveWeather"),
        workspace:GetAttribute("ActivePhase"),
        tonumber(workspace:GetAttribute("PhaseDuration"))
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
    if Flags["tpTween"] and not instant then
        local dist = (target - rootPart.Position).Magnitude
        local speed = math.max(10, tonumber(Flags["tpTweenSpeed"]) or 60)
        local dur = math.clamp(dist / speed, 0.1, 2.5)
        pcall(function()
            local tween = TweenService:Create(rootPart, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target) })
            tween:Play()
            tween.Completed:Wait()
        end)
        return
    end

    local restore = not Flags["noClip"]
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

-- tool lookups
local function getToolParents()
    local parents = {}
    local char = client and client.Character
    if char then
        parents[#parents + 1] = char
    end
    local bp = client and client.Backpack
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
        local saved = Flags[savedFlag]
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
-- alias kept for compatibility
local function getAllPetSpecies()
    return getPetList()
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
    local list = {}
    for k in pairs(seen) do
        list[#list + 1] = k
    end
    table.sort(list)
    return list
end

local function getOwnedSprinklers()
    local owned = {}
    for _, parent in ipairs(getToolParents()) do
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local s = tool:GetAttribute("Sprinkler")
                if type(s) == "string" and s ~= "" then
                    owned[s] = (owned[s] or 0) + 1
                end
            end
        end
    end
    return owned
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
    if fType and Flags[fType] then
        if not matchesSelection(Flags[fType], entry.crop) then
            return false
        end
    end

    -- 2. Check rarity selection / minimum order
    local rar = firstValue(Flags[fRarity] or {})
    if rar and rar ~= "" and rar ~= "Any" and rar ~= "All" then
        local entryRar = RARITY_ORDER[entry.rarity or "Common"] or 1
        local minRar = RARITY_ORDER[rar] or 1
        if entryRar < minRar then
            return false
        end
    end

    -- 3. Check mutation status
    local mut = firstValue(Flags[fMutation] or {})
    if mut == "Mutated Only" and not entry.mutation then
        return false
    end
    if mut == "Non-Mutated Only" and entry.mutation then
        return false
    end

    -- 4. Check threshold (Above/Below direction)
    local tm = firstValue(Flags[fThreshMode] or {})
    local thresholdValue = tonumber(Flags[fThreshold]) or 0
    if tm and tm ~= "Disabled" and thresholdValue > 0 then
        local val = entry.weight or entry.value or 0
        if tm == "Above" and val < thresholdValue then
            return false
        end
        if tm == "Below" and val > thresholdValue then
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
                            local wt = tonumber(
                                m:GetAttribute("SizeMultiplier")
                                or m:GetAttribute("SizeMulti")
                                or plant:GetAttribute("SizeMultiplier")
                                or plant:GetAttribute("SizeMulti")
                            ) or 1
                            out[#out + 1] = {
                                model = m,
                                plantId = plantId,
                                fruitId = m:GetAttribute("FruitId") or "",
                                mutation = mut,
                                crop = cropName,
                                weight = (ValueDB.baseWeight[cropName] or 1) * wt,
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

-- snap world XZ to nearest PlantArea soil surface
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
    if sh.Parent == client.Character then
        return sh
    end
    local humanoid = getHumanoid()
    if not humanoid then
        return nil
    end
    pcall(function()
        humanoid:EquipTool(sh)
    end)
    task.wait(0.15)
    if sh.Parent ~= client.Character then
        task.wait(0.15)
    end
    if sh.Parent == client.Character then
        return sh
    end
    return nil
end

-- webhook
local lastWebhook = 0
local function sendWebhook(title, desc, color, fields)
    local url = Flags["webhookUrl"]
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
                username = Flags["whName"] or "GAG2 Bot",
            }),
        })
    end)
end

-- server hop (uses TeleportService directly - no external API needed)
local function serverHop(lowPop)
    notify("Server Hop", "Teleporting to a new server...")
    if Flags["whHop"] then
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
        if Flags["whBigHarvest"] then
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
    local _lastInvDbg = 0
    local _invVerbose = true
    local function computeInvValue()
        local d = getData()
        local invVal = 0
        local count = 0
        local now = os.time()
        local verbose = _invVerbose
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
        local backpackCount = 0
        local firstFew = {}
        local firstFewCount = 0
        for _, tool in ipairs(getFruitTools()) do
            local hasHF = tool:GetAttribute("HarvestedFruit")
            local hasFN = tool:GetAttribute("FruitName")
            local hasFruit = tool:GetAttribute("Fruit")
            local hasSeed = tool:GetAttribute("Seed")
            local fname = tool:GetAttribute("FruitName") or tool:GetAttribute("Fruit") or tool:GetAttribute("Seed") or tool.Name or ""
            local rawW = tonumber(tool:GetAttribute("Weight"))
                or (
                    (tonumber(tool:GetAttribute("SizeMultiplier")
                        or tool:GetAttribute("SizeMulti")) or 1)
                    * (ValueDB.baseWeight[fname] or 1)
                )
            local weight = rawW and rawW > 0 and rawW or 1
            local mname = tool:GetAttribute("Mutation")
            if type(mname) ~= "string" then
                mname = nil
            end
            invVal = invVal + ValueEngine.compute(fname, weight, mname)
            count = count + 1
            backpackCount = backpackCount + 1
            if firstFewCount < 5 then
                firstFewCount = firstFewCount + 1
                local v = ValueEngine.compute(fname, weight, mname)
                local attrStr = string.format(
                    "%s(%s,HF=%s,FN=%s,F=%s,W=%s,Id=%s,M=%s,val=%d)",
                    tool.Name,
                    fname,
                    tostring(hasHF),
                    tostring(hasFN),
                    tostring(hasFruit),
                    tostring(rawW),
                    tostring(tool:GetAttribute("Id")),
                    tostring(mname),
                    v
                )
                firstFew[#firstFew + 1] = attrStr
            end
        end
        if backpackCount > 0 and now ~= _lastInvDbg then
            DebugLog(
                "invValue", "backpackScan",
                "found=" .. backpackCount,
                "totalCount=" .. count,
                "val=" .. invVal,
                "samples=" .. table.concat(firstFew, ";")
            )
        end
        if verbose and backpackCount > 0 then
            _invVerbose = false
            DebugLog(
                "invValue", "verbose",
                "backpackFound=" .. backpackCount,
                "totalTools=" .. tostring(#(getToolParents()[2] and getToolParents()[2]:GetChildren() or {})),
                "samples=" .. table.concat(firstFew, ";")
            )
        end
        if now ~= _lastInvDbg then
            _lastInvDbg = now
            local invKeys = "?"
            if d and d.Inventory and type(d.Inventory) == "table" then
                local ks = {}
                for k in pairs(d.Inventory) do
                    ks[#ks + 1] = tostring(k)
                end
                table.sort(ks)
                invKeys = table.concat(ks, ",")
            end
            local sampleCount = 0
            local sample = ""
            if hf then
                for k, v in pairs(hf) do
                    if sampleCount < 2 then
                        local vstr = type(v) == "table"
                            and (tostring(v.FruitName or v.Name or v.Seed or "?")
                                .. "/" .. tostring(v.SizeMultiplier or v.Weight or "?"))
                            or tostring(v)
                        sample = sample .. " " .. tostring(k) .. "=" .. vstr
                    end
                    sampleCount = sampleCount + 1
                end
            end
            DebugLog(
                "invValue",
                "data=" .. tostring(d ~= nil),
                "inv=" .. tostring(d and d.Inventory ~= nil),
                "hf=" .. tostring(type(hf)),
                "count=" .. tostring(count),
                "val=" .. tostring(invVal),
                "FVC=" .. tostring(FruitValueCalc ~= nil),
                "sellLive=" .. tostring(ValueDB.sellLive ~= nil),
                "invKeys=" .. invKeys,
                "sample[" .. sampleCount .. "]" .. sample
            )
        end
        return invVal, count
    end
    ValueESP = {}
    ValueESP.update = function()
        local onTags = Flags["espFruitValue"] == true
        local onTotal = Flags["espTotalValue"] == true
        local onInv = Flags["espInvValue"] == true
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
        local baseOnly = Flags["espBaseValueOnly"] == true
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

local _harvesting = false
local function doHarvest(forceAll)
    if _harvesting then return end
    _harvesting = true
    local ok, result = pcall(function()
    local collected = 0
    local mode = forceAll and "All" or (firstValue(Flags["collectFilter"] or {}) or "All")
    if Flags["autoCollectAll"] then
        mode = "All"
    elseif Flags["autoCollectBest"] then
        mode = "Best"
    elseif Flags["enableFilters"] and mode ~= "Best" then
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
        if not Flags["collectNoTp"] and ref and rootPart then
            if (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(ref.Position.X, 0, ref.Position.Z)).Magnitude > 16 then
                teleport(ref.Position)
                task.wait(0.12)
            end
        end
        -- fire CollectFruit remote for every ripe fruit
        for _, entry in ipairs(targets) do
            local skip = false
            if mode == "Filtered" then
                if not matchesFilter(entry, "collectFruit", "collectRarity", "collectMutation", "collectThreshMode", "collectThreshold") then
                    skip = true
                end
            end
            if Flags["mutatedOnly"] and not entry.mutation then
                skip = true
            end
            if Flags["stopOnFull"] and isInventoryFull() then
                break
            end
            if not skip then
                netFire("Garden.CollectFruit", entry.plantId, entry.fruitId or "")
                collected = collected + 1
                task.wait(jitter(tonumber(Flags["collectDelay"]) or 0.05, 0.02))
            end
        end
    elseif not forceAll then
        DebugLog("doHarvest", "no targets", "ripe=" .. #targets, "fruitData=" .. tostring(next(fruitData) ~= nil))
    end
    if collected > 0 then
        DebugLog("doHarvest", "collected=" .. collected, "mode=" .. mode)
    end
    return collected
    end)
    _harvesting = false
    return ok and result or 0
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
    if not Flags["plantNoTp"] then
        nearPlot()
    end
    local playerData = getData()
    local seeds = playerData and playerData.Inventory and playerData.Inventory.Seeds
    if not seeds then
        return
    end
    -- resolve which seeds to plant
    local seedFilter = Flags["plantSeeds"]
    local hasFilter = false
    if type(seedFilter) == "table" and next(seedFilter) ~= nil then
        hasFilter = true
    elseif type(seedFilter) == "string" and seedFilter ~= "" then
        hasFilter = true
    end
    if Flags["autoPlantAll"] then
        hasFilter = false -- Auto Plant All ignores the seed dropdown entirely
    end
    local toPlant = {}
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
    if #toPlant == 0 then
        return
    end
    -- seed reserve: filter out seed types below the keep-n threshold
    if Flags["seedReserve"] then
        local keep = math.max(0, tonumber(Flags["reserveCount"]) or 0)
        if keep > 0 then
            local want = {}
            for _, seedName in ipairs(toPlant) do
                want[seedName] = (want[seedName] or 0) + 1
            end
            local reserved = {}
            for seedName, wanted in pairs(want) do
                local owned = seeds[seedName] or 0
                if owned > keep then
                    for _ = 1, wanted do
                        reserved[#reserved + 1] = seedName
                    end
                end
            end
            toPlant = reserved
        end
    end
    if #toPlant == 0 then
        return
    end
    -- resolve plant position via mode dropdown (Random/Saved/Player/Near Fruit/Sprinkler Radius)
    local plantMode = firstValue(Flags["plantPosition"] or {}) or "Random"
    local sortPosition = nil
    if plantMode == "Saved Position" then
        local saved = Flags["savedPlantPos"]
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
    local free = getOpenSlots(plot, firstValue(Flags["plantPattern"]) or "Fill", sortPosition)
    if #free == 0 then
        DebugLog("doPlant", "no free slots")
        return
    end
    local cap = math.min(#free, #toPlant)
    if not Flags["autoPlantAll"] then
        cap = math.min(#free, #toPlant, tonumber(Flags["maxPerCycle"]) or 80)
    end
    local delay = math.max(0.02, tonumber(Flags["plantDelay"]) or 0.05)
    if Flags["autoPlantAll"] then
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
                    if not Flags["autoPlant"] and not Flags["autoPlantAll"] then
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
    local mode = firstValue(Flags["stealFilter"] or {}) or "All"
    if Flags["autoStealBest"] or mode == "Best" then
        table.sort(targets, function(a, b)
            return (a.value or 0) > (b.value or 0)
        end)
    end
    local bestStealValue = (mode == "Best" or Flags["autoStealBest"]) and (targets[1].value or 0) or 0
    local home = getHRP() and getHRP().Position
    local lastPosition
    for _, t in ipairs(targets) do
        local valid = true
        if mode == "Filtered" then
            if not matchesFilter(t, "stealFruit", "stealRarity", "stealMutation", nil, nil) then
                valid = false
            end
        elseif mode == "Best" or Flags["autoStealBest"] then
            if (t.value or 0) < bestStealValue then
                valid = false
            end
        end
        local pos = (t.model and t.model.Parent) and t.model:GetPivot().Position or nil
        if valid and pos and Flags["skipIfOwnerHome"] and isOwnerHome(t.userId) then
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
                    if Flags["stealEvasion"] then
                        for _, pl in ipairs(Players:GetPlayers()) do
                            if pl ~= client and pl.Character
                                and (
                                    t.userId == pl.UserId
                                    or pl.Character:FindFirstChild("Shovel")
                                    or pl.Character:FindFirstChild("Crowbar")
                                )
                            then
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
            local mult = math.max(1, tonumber(Flags["stealMult"]) or 1)
            for _ = 2, mult do
                netFire("Steal.CompleteSteal")
                task.wait(0.05)
            end
            task.wait(jitter(tonumber(Flags["stealDelay"]) or 0.25, 0.05))
            if Flags["autoStealBest"] or mode == "Best" then
                break
            end
        end
    end
    if Flags["stealReturn"] and home then
        teleport(home - Vector3.new(0, 3, 0))
    end
end

local function doSellAll()
    local balBefore = getBalance()
    -- track profit from last sell cycle
    if sellBaseline and balBefore > sellBaseline then
        local profit = balBefore - sellBaseline
        sessionEarned = sessionEarned + profit
        if profit > 100000 and Flags["whBigHarvest"] then
            sendWebhook("BIG Sell", "Sold " .. fmtCash(profit) .. " worth of crops!", 5763719)
        end
    end
    sellBaseline = balBefore
    netFire("NPCS.SellAll")
end

local function doSellSelective()
    local playerData = getData()
    if not (playerData and playerData.Inventory) then
        return
    end
    local fruits = playerData.Inventory.HarvestedFruits
        or playerData.Inventory.Fruits
        or playerData.Inventory.Backpack
        or playerData.Inventory.Harvested
    if not fruits or next(fruits) == nil then
        fruits = {}
        for _, tool in ipairs(getFruitTools()) do
            local uid = getFruitId(tool)
            if uid then
                local cropName = tool:GetAttribute("FruitName") or tool:GetAttribute("Fruit") or tool:GetAttribute("Seed") or tool.Name or ""
                local wt = tonumber(tool:GetAttribute("Weight"))
                    or (
                        (tonumber(tool:GetAttribute("SizeMultiplier")
                            or tool:GetAttribute("SizeMulti")) or 1)
                        * (ValueDB.baseWeight[cropName] or 1)
                    )
                if not wt or wt <= 0 then
                    wt = 1
                end
                local mutName = tool:GetAttribute("Mutation")
                if type(mutName) ~= "string" then mutName = nil end
                fruits[tostring(uid)] = {
                    crop = cropName,
                    mutation = mutName,
                    weight = wt,
                    rarity = tool:GetAttribute("Rarity") or SeedRarity[cropName] or "Common",
                    value = ValueEngine.compute(cropName, wt, mutName),
                    _tool = tool,
                    _uid = tostring(uid),
                }
            end
        end
    end
    if not fruits or next(fruits) == nil then
        return
    end
    for uid, info in pairs(fruits) do
        if type(info) == "table" then
            local cropName = info.crop or info.FruitName or info.CropName or info.SeedName or info.Name or ""
            local wt = info.weight or tonumber(info.SizeMultiplier or info.Weight or info.Size or (ValueDB.baseWeight[cropName] or 1)) or 1
            local mutName = info.mutation or info.Mutation
            local entry = {
                crop = cropName,
                mutation = mutName,
                weight = wt,
                rarity = info.rarity or info.Rarity or SeedRarity[cropName] or "Common",
                value = info.value or ValueEngine.compute(cropName, wt, mutName),
            }
            if matchesFilter(entry, "sellFruit", "sellRarity", "sellMutation", "sellThreshMode", "sellThreshold") then
                local fruitId = info._uid or tostring(uid)
                netFire("NPCS.SellFruit", fruitId)
                task.wait(tonumber(Flags["sellDelay"]) or 0.1)
            end
        end
    end
end

local function doSellPets()
    local playerData = getData()
    if not (playerData and playerData.Inventory and playerData.Inventory.Pets) then
        return
    end
    local target = firstValue(Flags["sellPet"] or {})
    local minRarity = firstValue(Flags["sellPetRarity"] or {}) or "Any"
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
                local wantSize = firstValue(Flags["sellPetSize"] or {})
                if wantSize and wantSize ~= "Any" and info.Size then
                    if info.Size ~= wantSize then
                        rarityOk = false
                    end
                end
            end
            if rarityOk then
                netFire("NPCS.SellPet", tostring(uid))
                task.wait(tonumber(Flags["sellDelay"]) or 0.1)
            end
        end
    end
end

local function getFruitId(tool)
    local id = tool:GetAttribute("Id") or tool:GetAttribute("FruitId")
    if not id and tool.Parent then
        id = tool.Parent:GetAttribute("Id")
    end
    return id
end

local function getFruitTools()
    local list = {}
    for _, parent in ipairs(getToolParents()) do
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("Tool") then
                local isFruit = obj:GetAttribute("HarvestedFruit")
                    or obj:GetAttribute("FruitName")
                    or obj:GetAttribute("Fruit")
                if isFruit then
                    list[#list + 1] = obj
                end
            elseif obj:IsA("Configuration") and obj:GetAttribute("FruitProxy") == true then
                local tool = obj:FindFirstChildWhichIsA("Tool")
                if tool then
                    list[#list + 1] = tool
                end
            end
        end
    end
    return list
end

local function doFavorite(setFav, all)
    local playerData = getData()
    if not (playerData and playerData.Inventory) then
        return
    end
    local fruits = playerData.Inventory.HarvestedFruits
        or playerData.Inventory.Fruits
        or playerData.Inventory.Backpack
        or playerData.Inventory.Harvested
    if not fruits or next(fruits) == nil then
        fruits = {}
        for _, tool in ipairs(getFruitTools()) do
            local uid = getFruitId(tool)
            if uid then
                local cropName = tool:GetAttribute("FruitName") or tool:GetAttribute("Fruit") or tool:GetAttribute("Seed") or tool.Name or ""
                local wt = tonumber(tool:GetAttribute("Weight"))
                    or (
                        (tonumber(tool:GetAttribute("SizeMultiplier")
                            or tool:GetAttribute("SizeMulti")) or 1)
                        * (ValueDB.baseWeight[cropName] or 1)
                    )
                if not wt or wt <= 0 then
                    wt = 1
                end
                local mutName = tool:GetAttribute("Mutation")
                if type(mutName) ~= "string" then mutName = nil end
                fruits[tostring(uid)] = {
                    crop = cropName,
                    mutation = mutName,
                    weight = wt,
                    rarity = tool:GetAttribute("Rarity") or SeedRarity[cropName] or "Common",
                    value = ValueEngine.compute(cropName, wt, mutName),
                    _tool = tool,
                    _uid = tostring(uid),
                }
            end
        end
    end
    if not fruits or next(fruits) == nil then
        return
    end
    for uid, info in pairs(fruits) do
        if type(info) == "table" then
            local match = all == true
            if not match then
                local cropName = info.crop or info.FruitName or info.CropName or info.SeedName or info.Name or ""
                local wt = info.weight or tonumber(info.SizeMultiplier or info.Weight or info.Size or (ValueDB.baseWeight[cropName] or 1)) or 1
                local mutName = info.mutation or info.Mutation
                local entry = {
                    crop = cropName,
                    mutation = mutName,
                    weight = wt,
                    rarity = info.rarity or info.Rarity or SeedRarity[cropName] or "Common",
                    value = info.value or ValueEngine.compute(cropName, wt, mutName),
                }
                match = matchesFilter(entry, "favFruit", "favRarity", "favMutation", "favThreshMode", "favThreshold")
            end
            if match then
                local fruitId = info._uid or tostring(uid)
                netFire("Backpack.SetFruitFavorite", fruitId, setFav)
                task.wait(tonumber(Flags["sellDelay"]) or 0.05)
            end
        end
    end
end

local placeOneSprinkler
local function doSprinkler()
    local owned = getOwnedSprinklers()
    if not next(owned) then
        DebugLog("doSprinkler", "exit: no sprinkler tools in backpack")
        local invKeys = "nil"
        local d = getData()
        if d and d.Inventory and type(d.Inventory) == "table" then
            local ks = {}
            for k in pairs(d.Inventory) do
                ks[#ks + 1] = tostring(k)
            end
            table.sort(ks)
            invKeys = table.concat(ks, ",")
        end
        DebugLog("doSprinkler", "invKeys=" .. invKeys)
    end
    local plot = myPlot()
    if not plot then
        DebugLog("doSprinkler", "exit: no plot")
        return
    end
    if not Flags["sprinklerNoTp"] then
        nearPlot()
    end
    local existing = plot:FindFirstChild("Sprinklers")
    local count = existing and #existing:GetChildren() or 0
    if count >= 4 then
        DebugLog("doSprinkler", "exit: already " .. count .. " sprinklers (>=4)")
        return
    end
    local name = firstValue(Flags["sprinklerSelect"] or {})
    if not name or name == "" then
        for sname in pairs(owned) do
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
    placeOneSprinkler(plot, name, owned[name] or 1)
end

local function doSprinklerAll()
    local owned = getOwnedSprinklers()
    if not next(owned) then
        DebugLog("doSprinklerAll", "exit: no sprinkler tools in backpack")
        return
    end
    local plot = myPlot()
    if not plot then
        return
    end
    if not Flags["sprinklerNoTp"] then
        nearPlot()
    end
    local existing = plot:FindFirstChild("Sprinklers")
    local count = existing and #existing:GetChildren() or 0
    if count >= 4 then
        DebugLog("doSprinklerAll", "exit: already " .. count .. " sprinklers (>=4)")
        return
    end
    local placed = 0
    for sname, sval in pairs(owned) do
        if type(sname) == "string" and placeOneSprinkler(plot, sname, sval) then
            placed = placed + 1
            task.wait(math.max(0.3, tonumber(Flags["sprinklerDelay"]) or 0))
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
        local cand = resolveModePosition(firstValue(Flags["sprinklerPos"] or {}), "savedSprinklerPos", plot)
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
            local minSpacing = tonumber(Flags["sprinklerSpacing"]) or 8
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
    -- Place.PlaceSprinkler:Fire(position, sprinklerAttr, equippedTool, plotId)
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
    DebugLog(
        "doSprinkler", "fire", sAttr,
        "pos=" .. tostring(pos.X) .. "," .. tostring(pos.Z),
        "plotId=" .. tostring(plotId),
        "owned=" .. tostring(ownedCount)
    )
    return true
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
    local canName = firstValue(Flags["wateringCan"] or {})
    local targetCrop = firstValue(Flags["waterPlants"] or {})
    local waterAll = Flags["autoWaterAll"]
    local canTool = nil
    local canWarned = false
    for _, pl in ipairs(plants:GetChildren()) do
        local decaying = pl:GetAttribute("IsDecaying") or pl:GetAttribute("Decaying")
        if decaying then
            local crop = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
            if waterAll or not targetCrop or (type(targetCrop) == "string" and crop and crop:lower() == targetCrop:lower()) then
                local ok, basePos = pcall(function()
                    return pl:GetPivot().Position
                end)
                if ok and basePos then
                    if not canTool then
                        local t = findToolByAttr("WateringCan", canName)
                        canTool = t and equipTool(t) or nil
                        if not canTool then
                            if not canWarned then
                                canWarned = true
                                dumpTools("WateringCan")
                                notify("Auto Water", "Watering can tool not found / equip failed (see console)", "warn")
                            end
                            break
                        end
                    end
                    local surface = soilPositionAt(plot, basePos.X, basePos.Z) or basePos
                    netFire(
                        "WateringCan.UseWateringCan",
                        surface,
                        canTool:GetAttribute("WateringCan") or canName or "",
                        canTool
                    )
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
    local target = firstValue(Flags["shovelFruit"] or {})
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
                        local plantId = pl:GetAttribute("PlantId")
                        if not plantId then
                            --
                        else
                            netFire(
                                "Shovel.UseShovel",
                                plantId,
                                m:GetAttribute("FruitId") or "",
                                shovelAttr,
                                shovel
                            )
                            task.wait(tonumber(Flags["shovelFruitDelay"]) or 0.1)
                        end
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
    local target = firstValue(Flags["shovelTree"] or {})
    for _, pl in ipairs(plants:GetChildren()) do
        local crop = pl:GetAttribute("SeedName") or pl:GetAttribute("CorePartName")
        local entry =
            { crop = crop, mutation = pl:GetAttribute("Mutation"), rarity = pl:GetAttribute("Rarity"), value = 0 }
        if (not target) or (crop and crop:lower() == target:lower()) then
            if matchesFilter(entry, nil, "shovelTreeRarity", "shovelTreeMutation", nil, nil) then
                local plantId = pl:GetAttribute("PlantId")
                if plantId then
                    netFire("Shovel.UseShovel", plantId, "", shovelAttr, shovel)
                    task.wait(tonumber(Flags["shovelTreeDelay"]) or 0.1)
                end
            end
        end
    end
end

local function doMailboxSend()
    local username = Flags["mbUsername"] or ""
    if username == "" then
        return
    end
    local note = Flags["mbNote"] or ""
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
    if Flags["autoSendSeed"] and playerData.Inventory and playerData.Inventory.Seeds then
        local target = firstValue(Flags["sendSeed"] or {})
        local amountStr = tostring(Flags["sendSeedAmount"] or "full"):lower()
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
    if Flags["autoSendPet"] and playerData.Inventory and playerData.Inventory.Pets then
        local equipped = netCall("Pets.GetEquipped")
        if type(equipped) == "table" then
            for _, pet in pairs(equipped) do
                if type(pet) == "table" and pet.Id then
                    netFire("Pets.RequestUnequip", tostring(pet.Id))
                    task.wait(0.25)
                end
            end
        end
        local target = firstValue(Flags["sendPet"] or {})
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

local _packGrabbing = false
local function doPackGrab()
    if _packGrabbing then
        return
    end
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
                local grabGold = Flags["collectGold"]
                local grabRainbow = Flags["collectRainbow"]
                local isGold = loc:GetAttribute("GoldSeed") == true
                local isRainbow = loc:GetAttribute("RainbowSeed") == true
                local valid = true
                if grabGold and grabRainbow then
                    if not isGold and not isRainbow then
                        valid = false
                    end
                elseif grabGold and not isGold then
                    valid = false
                elseif grabRainbow and not isRainbow then
                    valid = false
                end
                if valid then
                    if Flags["rarePackNotify"] and rare then
                        notify("Rare Seed Spawned", packType(loc) or "Rare pack - grabbing!")
                        sendWebhook("Rare Seed", packType(loc) or "Rare pack spawned", 12255232)
                    end
                    _packGrabbing = true
                    task.spawn(function()
                        pcall(grabPackRobust, loc)
                        _packGrabbing = false
                    end)
                    break
                end
            end
        end
    end
end

local function doCollectDropped()
    local droppedFolder = Workspace:FindFirstChild("DroppedItems")
    if not droppedFolder then
        return
    end
    local items = droppedFolder:GetChildren()
    if #items == 0 then
        return
    end
    local rootPart = getHRP()
    if not rootPart then
        return
    end
    local closest, closestDist
    for _, item in ipairs(items) do
        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local dist = (part.Position - rootPart.Position).Magnitude
            if not closestDist or dist < closestDist then
                closestDist = dist
                closest = item
            end
        end
    end
    if not closest then
        return
    end
    if closestDist > 3 then
        local target = closest:IsA("BasePart") and closest.Position
            or (closest:IsA("Model") and closest:GetPivot().Position)
        if target then
            teleport(target)
        end
    end
    local prompt = closest:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then
        for _, d in ipairs(closest:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                prompt = d
                break
            end
        end
    end
    if prompt and prompt.Enabled then
        local oldDist = prompt.MaxActivationDistance
        local oldHold = prompt.HoldDuration
        prompt.MaxActivationDistance = math.huge
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(0.1)
        prompt:InputHoldEnd()
        prompt.MaxActivationDistance = oldDist
        prompt.HoldDuration = oldHold
    end
end

-- ESP (pooled highlights)
local _espPool = {}
local _espLabels = {}
local function clearESP()
    for _, h in ipairs(_espPool) do
        pcall(function()
            h:Destroy()
        end)
    end
    _espPool = {}
    for _, b in ipairs(_espLabels) do
        pcall(function()
            b:Destroy()
        end)
    end
    _espLabels = {}
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
    if Flags["espFruitEnabled"] then
        local target = firstValue(Flags["espFruit"] or {})
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
    if Flags["espPetEnabled"] then
        local target = firstValue(Flags["espPet"] or {})
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

    -- mutation labels on garden plants (BillboardGui text)
    if Flags["espMutationLabels"] then
        local plot = myPlot()
        local plants = plot and plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local mut = plant:GetAttribute("Mutation")
                if type(mut) == "string" and mut ~= "" and mut ~= "None" then
                    local rootPart = plant:FindFirstChildWhichIsA("BasePart")
                    if rootPart then
                        local sn = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName") or "Plant"
                        local col = mut == "Gold" and Color3.fromRGB(255, 215, 0)
                            or mut == "Electric" and Color3.fromRGB(80, 160, 255)
                            or mut == "Rainbow" and Color3.fromRGB(255, 100, 200)
                            or mut == "Frozen" and Color3.fromRGB(100, 210, 255)
                            or Color3.fromRGB(200, 200, 200)
                        local bb = Instance.new("BillboardGui")
                        bb.Adornee = rootPart
                        bb.Size = UDim2.new(0, 200, 0, 30)
                        bb.StudsOffset = Vector3.new(0, 3, 0)
                        bb.AlwaysOnTop = true
                        bb.Parent = CoreGui
                        local tl = Instance.new("TextLabel")
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.Text = "[" .. mut .. "] " .. sn
                        tl.TextColor3 = col
                        tl.TextStrokeColor3 = Color3.new(0, 0, 0)
                        tl.TextStrokeTransparency = 0.5
                        tl.TextSize = 14
                        tl.Font = Enum.Font.GothamBold
                        tl.Parent = bb
                        _espLabels[#_espLabels + 1] = bb
                    end
                end
            end
        end
    end

    -- plant age labels (Age/MaxAge)
    if Flags["espPlantAge"] then
        local plot = myPlot()
        local plants = plot and plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local age = plant:GetAttribute("Age")
                local maxAge = plant:GetAttribute("MaxAge")
                if age and maxAge then
                    local rootPart = plant:FindFirstChildWhichIsA("BasePart")
                    if rootPart then
                        local sn = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName") or "Plant"
                        local ripe = age >= maxAge
                        local bb = Instance.new("BillboardGui")
                        bb.Adornee = rootPart
                        bb.Size = UDim2.new(0, 160, 0, 24)
                        bb.StudsOffset = Vector3.new(0, 1.5, 0)
                        bb.AlwaysOnTop = true
                        bb.Parent = CoreGui
                        local tl = Instance.new("TextLabel")
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.Text = sn .. " " .. tostring(age) .. "/" .. tostring(maxAge)
                        tl.TextColor3 = ripe and Color3.fromRGB(120, 235, 130) or Color3.fromRGB(200, 200, 200)
                        tl.TextStrokeColor3 = Color3.new(0, 0, 0)
                        tl.TextStrokeTransparency = 0.5
                        tl.TextSize = 12
                        tl.Font = Enum.Font.Gotham
                        tl.Parent = bb
                        _espLabels[#_espLabels + 1] = bb
                    end
                end
            end
        end
    end
end

-- instant interact prompt
local function doInstantPrompt()
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled and p.HoldDuration > 0 then
            pcall(function()
                p.HoldDuration = 0
            end)
        end
    end
end

-- bypass gameplay paused
local function doBypassPause()
    for _, container in ipairs({ client.PlayerGui, CoreGui }) do
        if not container then
            --
        else
            for _, g in ipairs(container:GetDescendants()) do
                if g:IsA("ScreenGui") and g.Enabled then
                    local nm = g.Name:lower()
                    if nm:find("pause") or nm:find("modal") or nm:find("gameplay") then
                        pcall(function()
                            g.Enabled = false
                        end)
                    end
                end
            end
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
    if not Flags["petProtection"] then
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
    local code = Flags["redeemCode"] or ""
    if code == "" then
        notify("Code", "Enter a code first", "warning")
        return
    end
    netFire("Settings.SubmitCode", code)
    notify("Code", "Redeeming: " .. code)
end

-- auto buy pet: scan wild pets for Price attribute and buy if affordable
local function doAutoBuyPet()
    if not Flags["autoBuyPet"] then
        return
    end
    local map = Workspace:FindFirstChild("Map")
    local spawns = map and map:FindFirstChild("WildPetSpawns")
    if not spawns then
        return
    end
    local wantSpecies = firstValue(Flags["buyPet"] or {})
    local maxPrice = tonumber(Flags["petBuyMaxPrice"]) or 500
    local balance = getBalance()
    for _, pet in ipairs(spawns:GetChildren()) do
        local skip
        local part = pet:IsA("BasePart") and pet
            or pet:IsA("Model") and (pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart", true))
        if not part then
            skip = true
        end
        local species = part and (part:GetAttribute("PetName") or pet:GetAttribute("PetName"))
        if wantSpecies and species and normName(species) ~= normName(wantSpecies) then
            skip = true
        end
        local price = part and part:GetAttribute("Price")
        if type(price) ~= "number" or price <= 0 or price > maxPrice or price > balance then
            skip = true
        end
        local owner = part and part:GetAttribute("OwnerUserId")
        if owner and owner ~= 0 then
            skip = true
        end
        if skip then
            --
        else
            local pos = part.Position + Vector3.new(0, 3, 0)
            teleport(pos)
            task.wait(0.3)
            local prompt = pet:FindFirstChildWhichIsA("ProximityPrompt")
            if not prompt then
                for _, d in ipairs(pet:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        prompt = d
                        break
                    end
                end
            end
            if prompt and prompt.Enabled then
                local oldDist = prompt.MaxActivationDistance
                local oldHold = prompt.HoldDuration
                prompt.MaxActivationDistance = math.huge
                prompt.HoldDuration = 0
                prompt:InputHoldBegin()
                task.wait(0.15)
                prompt:InputHoldEnd()
                prompt.MaxActivationDistance = oldDist
                prompt.HoldDuration = oldHold
            end
            break
        end
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
    if not Flags["freeFlight"] then
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
    local speed = tonumber(Flags["flightSpeed"]) or 50
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
    local ws = tonumber(Flags["runSpeed"]) or 16
    local jh = tonumber(Flags["jumpHeight"]) or 7.2
    if st.ws ~= ws then
        st.ws = ws
        humanoid.WalkSpeed = ws
    end
    if st.jh ~= jh then
        st.jh = jh
        humanoid.JumpHeight = jh
    end
    if Flags["noClip"] then
        st.wasNoClip = true
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
    -- visual toggles (applied every frame to counter game resets)
    if Flags["fullBright"] then
        if not st.fullBrightWasOn then
            st.origBrightness = LightingService.Brightness
            st.origAmbient = LightingService.Ambient
            st.origOutdoor = LightingService.OutdoorAmbient
        end
        st.fullBrightWasOn = true
        LightingService.Brightness = tonumber(Flags["brightness"]) or 5
        LightingService.Ambient = Color3.fromRGB(255, 255, 255)
        LightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    elseif st.fullBrightWasOn then
        st.fullBrightWasOn = false
        LightingService.Brightness = st.origBrightness or 2
        LightingService.Ambient = st.origAmbient or Color3.new(0, 0, 0)
        LightingService.OutdoorAmbient = st.origOutdoor or Color3.new(0, 0, 0)
    end
    if Flags["noFog"] then
        if not st.noFogWasOn then
            st.origFogEnd = LightingService.FogEnd
            st.origFogStart = LightingService.FogStart
        end
        st.noFogWasOn = true
        LightingService.FogEnd = 100000
        LightingService.FogStart = 100000
    elseif st.noFogWasOn then
        st.noFogWasOn = false
        LightingService.FogEnd = st.origFogEnd or 10000
        LightingService.FogStart = st.origFogStart or 0
    end
    if Flags["noShadows"] then
        if not st.noShadowsWasOn then
            st.origShadows = LightingService.GlobalShadows
        end
        st.noShadowsWasOn = true
        LightingService.GlobalShadows = false
    elseif st.noShadowsWasOn then
        st.noShadowsWasOn = false
        LightingService.GlobalShadows = st.origShadows ~= false and st.origShadows or true
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
    "panicHarvest",
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
    "espMutationLabels",
    "espPlantAge",
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
    "fullBright",
    "brightness",
    "noFog",
    "noShadows",

    "autoTame",
    "autoEquip",
    "equipList",
    "tameAnimals",
    "autoBuyPetSlot",
    "autoHopPet",
    "hopPetSpecies",
    "tpTween",
    "tpTweenSpeed",
    "tpMode",
    "rarePackNotify",
    "espFruitValue",
    "espTotalValue",
    "espBaseValueOnly",
    "rareNotify",
    "autoHopRare",
    "espInvValue",
    "autoSave",
    "autoTPFallHarvest",
}
local function saveSettings()
    if not writefile then
        return
    end
    local data = {}
    for _, flag in ipairs(PERSISTENT_FLAGS) do
        local v = Flags[flag]
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
        if Flags[k] ~= nil then
            Flags[k] = v
        end
    end
end

-- ================================================================
-- SECTIONS (9 tabs)
-- ================================================================

-- ════════════════════════ FLUENT PRO UI ════════════════════════

-- ── Home Tab ──
local HomeTab = Window:AddTab({ Title = "🏠 Home", Icon = "solar/home-bold" })
HomeTab:AddParagraph({ Title = "Quick Stats", Content = "" })
HomeTab:AddParagraph({ Title = "Use Refresh Lists to update all dropdowns", Content = "" })
HomeTab:AddButton({ Title = "Refresh All Lists", Callback = function()
    local fs = {getSeedList, getCropList, getGearList, getCrateList, getPetList, getSprinklerList, getAllPetSpecies, getWildList}
    for _, fn in ipairs(fs) do pcall(fn) end
end })
HomeTab:AddButton({ Title = "Teleport to Garden", Callback = function()
    local p = myPlot() if p then local s = p:FindFirstChild("SpawnPoint") if s then teleport(s.Position) end end
end })
HomeTab:AddDropdown("tpMode", { Title = "Transport Mode", Values = {"Teleport","Tween"}, Default = "Teleport", Callback = function(v) Flags["tpTween"] = (v == "Tween") end })

-- ── Main Tab ──
local MainTab = Window:AddTab({ Title = "🌱 Main", Icon = "solar/leaf-bold" })

local PlantSec = MainTab:AddCollapsibleSection({ Title = "🌿 Plant", Open = true })
PlantSec:AddToggle("plantNoTp", { Title = "Disable Teleport", Default = false, Callback = function(v) Flags["plantNoTp"] = v end })
PlantSec:AddDropdown("plantSeeds", { Title = "Select Seeds", Values = getSeedList(), Default = "All", Multi = true, Callback = function(v) Flags["plantSeeds"] = v end })
PlantSec:AddDropdown("plantPattern", { Title = "Pattern", Values = {"Fill","Checkerboard","Rows","Columns","Diagonal","Spaced"}, Default = "Fill", Callback = function(v) Flags["plantPattern"] = v end })
PlantSec:AddDropdown("plantPosition", { Title = "Position", Values = {"Random","Saved Position","Sprinkler Radius","Player Position","Near Fruit"}, Default = "Random", Callback = function(v) Flags["plantPosition"] = v end })
PlantSec:AddButton({ Title = "Save Position", Callback = function() local r = getHRP() if r then Flags["savedPlantPos"] = r.Position end end })
PlantSec:AddInput("plantDelay", { Title = "Plant Delay", Default = "0", Callback = function(v) Flags["plantDelay"] = v end })
PlantSec:AddSlider("maxPerCycle", { Title = "Max Per Cycle", Min = 1, Max = 200, Default = 80, Suffix = "", Callback = function(v) Flags["maxPerCycle"] = v end })
PlantSec:AddToggle("seedReserve", { Title = "Seed Reserve", Default = false, Callback = function(v) Flags["seedReserve"] = v end })
PlantSec:AddInput("reserveCount", { Title = "Reserve Count", Default = "10", Callback = function(v) Flags["reserveCount"] = v end })
intervalToggle(MainTab, "autoPlant", "autoPlant", { Name = "Auto Plant", Flag = false, delay = 1.2, Step = doPlant })
intervalToggle(MainTab, "autoPlantAll", "autoPlantAll", { Name = "Auto Plant All", Flag = false, delay = 1.2, Step = doPlant })

local CollectSec = MainTab:AddCollapsibleSection({ Title = "🧺 Collect", Open = true })
CollectSec:AddToggle("collectNoTp", { Title = "Disable Teleport", Default = false, Callback = function(v) Flags["collectNoTp"] = v end })
CollectSec:AddToggle("stopOnFull", { Title = "Stop If Backpack Full", Default = false, Callback = function(v) Flags["stopOnFull"] = v end })
CollectSec:AddInput("collectDelay", { Title = "Collect Delay", Default = "0", Callback = function(v) Flags["collectDelay"] = v end })
CollectSec:AddDropdown("collectFilter", { Title = "Select Filter", Values = {"All","Filtered","Best"}, Default = "All", Callback = function(v) Flags["collectFilter"] = v end })
CollectSec:AddDropdown("collectFruit", { Title = "Select Fruit", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["collectFruit"] = v end })
CollectSec:AddDropdown("collectRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["collectRarity"] = v end })
CollectSec:AddDropdown("collectMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["collectMutation"] = v end })
CollectSec:AddDropdown("collectThreshMode", { Title = "Threshold Mode", Values = {"Disabled","Above","Below"}, Default = "Disabled", Callback = function(v) Flags["collectThreshMode"] = v end })
CollectSec:AddInput("collectThreshold", { Title = "Weight Threshold", Default = "0", Callback = function(v) Flags["collectThreshold"] = v end })
CollectSec:AddToggle("autoCollect", { Title = "Auto Collect", Default = false, Callback = function(v) Flags["autoCollect"] = v end })
CollectSec:AddToggle("autoCollectAll", { Title = "Auto Collect All", Default = false, Callback = function(v) Flags["autoCollectAll"] = v end })
CollectSec:AddToggle("enableFilters", { Title = "Enable Filters", Default = false, Callback = function(v) Flags["enableFilters"] = v end })
CollectSec:AddToggle("autoCollectBest", { Title = "Auto Collect Best", Default = false, Callback = function(v) Flags["autoCollectBest"] = v end })
CollectSec:AddToggle("panicHarvest", { Title = "Panic Harvest at Night", Default = false, Callback = function(v) Flags["panicHarvest"] = v end })
CollectSec:AddButton({ Title = "Scan Mutations", Callback = function() doMutationScan() end })
CollectSec:AddButton({ Title = "Harvest Mutated", Callback = function() doHarvestMutated() end })
CollectSec:AddToggle("collectGold", { Title = "Auto Collect Gold Seeds", Default = true, Callback = function(v) Flags["collectGold"] = v end })
CollectSec:AddToggle("collectRainbow", { Title = "Auto Collect Rainbow Seeds", Default = true, Callback = function(v) Flags["collectRainbow"] = v end })
CollectSec:AddToggle("rarePackNotify", { Title = "Rare Pack Alert", Default = false, Callback = function(v) Flags["rarePackNotify"] = v end })
CollectSec:AddToggle("collectDropped", { Title = "Auto Collect Dropped Items", Default = false, Callback = function(v) Flags["collectDropped"] = v end })

local StealSec = MainTab:AddCollapsibleSection({ Title = "🥷 Steal", Open = false })
StealSec:AddDropdown("stealFilter", { Title = "Select Filter", Values = {"All","Filtered","Best"}, Default = "All", Callback = function(v) Flags["stealFilter"] = v end })
StealSec:AddDropdown("stealFruit", { Title = "Select Fruit", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["stealFruit"] = v end })
StealSec:AddDropdown("stealRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["stealRarity"] = v end })
StealSec:AddDropdown("stealMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["stealMutation"] = v end })
StealSec:AddInput("stealDelay", { Title = "Steal Delay", Default = "0.3", Callback = function(v) Flags["stealDelay"] = v end })
StealSec:AddSlider("stealMult", { Title = "Fruits Per Steal", Min = 1, Max = 10, Default = 1, Suffix = "", Callback = function(v) Flags["stealMult"] = v end })
intervalToggle(MainTab, "autoSteal", "autoSteal", { Name = "Auto Steal", Flag = false, delay = 3, Step = doSteal })
StealSec:AddToggle("autoStealBest", { Title = "Auto Steal Best", Default = false, Callback = function(v) Flags["autoStealBest"] = v end })
StealSec:AddToggle("lockNight", { Title = "Lock Garden at Night", Default = true, Callback = function(v) Flags["lockNight"] = v end })
StealSec:AddToggle("hitStolen", { Title = "Hit Stolen Players", Default = false, Callback = function(v) Flags["hitStolen"] = v end })

local SellSec = MainTab:AddCollapsibleSection({ Title = "💰 Sell", Open = false })
SellSec:AddInput("sellDelay", { Title = "Sell Delay", Default = "0", Callback = function(v) Flags["sellDelay"] = v end })
SellSec:AddToggle("sellOnFull", { Title = "Sell When Backpack Full", Default = true, Callback = function(v) Flags["sellOnFull"] = v end })
SellSec:AddToggle("dailyDeal", { Title = "Use Daily Deal", Default = false, Callback = function(v) Flags["dailyDeal"] = v end })
SellSec:AddToggle("autoSell", { Title = "Auto Sell All", Default = false, Callback = function(v) Flags["autoSell"] = v end })
SellSec:AddSlider("sellInterval", { Title = "Sell Interval (s)", Min = 5, Max = 120, Default = 20, Suffix = "s", Callback = function(v) Flags["sellInterval"] = v end })
SellSec:AddButton({ Title = "Sell All Now", Callback = function() doSellAll() end })
SellSec:AddDropdown("sellFruit", { Title = "Select Fruit", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["sellFruit"] = v end })
SellSec:AddDropdown("sellRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["sellRarity"] = v end })
SellSec:AddDropdown("sellMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["sellMutation"] = v end })
SellSec:AddDropdown("sellThreshMode", { Title = "Threshold Mode", Values = {"Disabled","Above","Below"}, Default = "Disabled", Callback = function(v) Flags["sellThreshMode"] = v end })
SellSec:AddInput("sellThreshold", { Title = "Weight Threshold", Default = "0", Callback = function(v) Flags["sellThreshold"] = v end })
SellSec:AddToggle("autoSellSelective", { Title = "Auto Sell Fruits", Default = false, Callback = function(v) Flags["autoSellSelective"] = v end })
SellSec:AddDropdown("sellPet", { Title = "Select Pets", Values = getPetList(), Default = "Any", Callback = function(v) Flags["sellPet"] = v end })
SellSec:AddDropdown("sellPetRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["sellPetRarity"] = v end })
SellSec:AddDropdown("sellPetSize", { Title = "Size", Values = {"Any","Small","Medium","Large","Huge"}, Default = "Any", Callback = function(v) Flags["sellPetSize"] = v end })
SellSec:AddToggle("autoSellPets", { Title = "Auto Sell Pets", Default = false, Callback = function(v) Flags["autoSellPets"] = v end })

local PetSec = MainTab:AddCollapsibleSection({ Title = "🐾 Pets", Open = false })
PetSec:AddToggle("petProtection", { Title = "Pet Protection", Default = false, Callback = function(v) Flags["petProtection"] = v end })
PetSec:AddDropdown("buyPet", { Title = "Select Pet", Values = getAllPetSpecies(), Default = "Any", Callback = function(v) Flags["buyPet"] = v end })
PetSec:AddDropdown("buyPetRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["buyPetRarity"] = v end })
PetSec:AddDropdown("buyPetSize", { Title = "Size", Values = {"Any","Small","Medium","Large","Huge"}, Default = "Any", Callback = function(v) Flags["buyPetSize"] = v end })
PetSec:AddToggle("autoBuyPet", { Title = "Auto Buy Pet", Default = false, Callback = function(v) Flags["autoBuyPet"] = v end })
PetSec:AddSlider("petBuyMaxPrice", { Title = "Max Price", Min = 0, Max = 50000, Default = 500, Suffix = "", Callback = function(v) Flags["petBuyMaxPrice"] = v end })
PetSec:AddDropdown("tameAnimals", { Title = "Tame Animals", Values = getAllPetSpecies(), Default = "All", Multi = true, Callback = function(v) Flags["tameAnimals"] = v end })

-- ── Auto Tab ──
local AutoTab = Window:AddTab({ Title = "⚙️ Auto", Icon = "solar/settings-bold" })

local SprSec = AutoTab:AddCollapsibleSection({ Title = "💧 Sprinkler + Water", Open = true })
SprSec:AddToggle("sprinklerNoTp", { Title = "Disable Teleport", Default = false, Callback = function(v) Flags["sprinklerNoTp"] = v end })
SprSec:AddDropdown("sprinklerSelect", { Title = "Select Sprinkler", Values = getSprinklerList(), Default = "", Callback = function(v) Flags["sprinklerSelect"] = v end })
SprSec:AddDropdown("sprinklerPos", { Title = "Position", Values = {"Saved","Random","Player","Near Fruit"}, Default = "Random", Callback = function(v) Flags["sprinklerPos"] = v end })
SprSec:AddInput("sprinklerSpacing", { Title = "Spacing", Default = "8", Callback = function(v) Flags["sprinklerSpacing"] = v end })
SprSec:AddButton({ Title = "Save Position", Callback = function() local r = getHRP() if r then Flags["savedSprinklerPos"] = r.Position end end })
SprSec:AddInput("sprinklerDelay", { Title = "Place Delay", Default = "0", Callback = function(v) Flags["sprinklerDelay"] = v end })
intervalToggle(AutoTab, "autoSprinkler", "autoSprinkler", { Name = "Auto Place Sprinkler", Flag = false, delay = 20, delayFlag = "sprinklerDelay", Step = doSprinkler })
SprSec:AddToggle("autoSprinklerAll", { Title = "Auto Place All Sprinklers", Default = false, Callback = function(v) Flags["autoSprinklerAll"] = v end })
SprSec:AddToggle("autoWaterAll", { Title = "Auto Water All Plants", Default = false, Callback = function(v) Flags["autoWaterAll"] = v end })

local ShovelSec = AutoTab:AddCollapsibleSection({ Title = "🔧 Shovel", Open = false })
ShovelSec:AddDropdown("shovelTree", { Title = "Select Trees", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["shovelTree"] = v end })
ShovelSec:AddDropdown("shovelTreeRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["shovelTreeRarity"] = v end })
ShovelSec:AddDropdown("shovelTreeMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["shovelTreeMutation"] = v end })
ShovelSec:AddInput("shovelTreeDelay", { Title = "Tree Delay", Default = "0", Callback = function(v) Flags["shovelTreeDelay"] = v end })
intervalToggle(AutoTab, "autoShovelTree", "autoShovelTree", { Name = "Auto Shovel Trees", Flag = false, delay = 3, delayFlag = "shovelTreeDelay", Step = doShovelTree })
ShovelSec:AddDropdown("shovelFruit", { Title = "Select Fruits", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["shovelFruit"] = v end })
ShovelSec:AddDropdown("shovelFruitRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["shovelFruitRarity"] = v end })
ShovelSec:AddDropdown("shovelFruitMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["shovelFruitMutation"] = v end })
ShovelSec:AddDropdown("shovelThreshMode", { Title = "Threshold", Values = {"Disabled","Above","Below"}, Default = "Disabled", Callback = function(v) Flags["shovelThreshMode"] = v end })
ShovelSec:AddInput("shovelThreshold", { Title = "Threshold Value", Default = "0", Callback = function(v) Flags["shovelThreshold"] = v end })
ShovelSec:AddInput("shovelFruitDelay", { Title = "Fruit Delay", Default = "0", Callback = function(v) Flags["shovelFruitDelay"] = v end })
intervalToggle(AutoTab, "autoShovelFruit", "autoShovelFruit", { Name = "Auto Shovel Fruits", Flag = false, delay = 3, delayFlag = "shovelFruitDelay", Step = doShovelFruit })

-- ── Inventory Tab ──
local InvTab = Window:AddTab({ Title = "🎒 Inventory", Icon = "solar/backpack-bold" })
InvTab:AddParagraph({ Title = "Favorite / Unfavorite", Content = "" })
InvTab:AddDropdown("favFruit", { Title = "Select Fruit", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["favFruit"] = v end })
InvTab:AddDropdown("favRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["favRarity"] = v end })
InvTab:AddDropdown("favMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["favMutation"] = v end })
InvTab:AddDropdown("favThreshMode", { Title = "Threshold", Values = {"Disabled","Above","Below"}, Default = "Disabled", Callback = function(v) Flags["favThreshMode"] = v end })
InvTab:AddInput("favThreshold", { Title = "Threshold Value", Default = "0", Callback = function(v) Flags["favThreshold"] = v end })
InvTab:AddToggle("autoFav", { Title = "Auto Favorite", Default = false, Callback = function(v) Flags["autoFav"] = v end })
InvTab:AddToggle("autoUnfav", { Title = "Auto Unfavorite", Default = false, Callback = function(v) Flags["autoUnfav"] = v end })
InvTab:AddToggle("autoUnfavAll", { Title = "Auto Unfavorite All", Default = false, Callback = function(v) Flags["autoUnfavAll"] = v end })

-- ── Shop Tab ──
local ShopTab = Window:AddTab({ Title = "🛒 Shop", Icon = "solar/cart-bold" })
ShopTab:AddParagraph({ Title = "Seeds", Content = "" })
ShopTab:AddDropdown("buySeed", { Title = "Select Seeds", Values = getSeedList(), Default = "All", Multi = true, Callback = function(v) Flags["buySeed"] = v end })
ShopTab:AddToggle("autoBuyAllSeeds", { Title = "Auto Buy All Seeds", Default = false, Callback = function(v) Flags["autoBuyAllSeeds"] = v end })
ShopTab:AddParagraph({ Title = "Gear", Content = "" })
ShopTab:AddDropdown("buyGear", { Title = "Select Gear", Values = getGearList(), Default = "All", Callback = function(v) Flags["buyGear"] = v end })
ShopTab:AddToggle("autoBuyAllGear", { Title = "Auto Buy All Gear", Default = false, Callback = function(v) Flags["autoBuyAllGear"] = v end })
ShopTab:AddParagraph({ Title = "Crates", Content = "" })
ShopTab:AddDropdown("buyCrate", { Title = "Select Crate", Values = getCrateList(), Default = "All", Callback = function(v) Flags["buyCrate"] = v end })
ShopTab:AddToggle("autoBuyAllCrates", { Title = "Auto Buy All Crates", Default = false, Callback = function(v) Flags["autoBuyAllCrates"] = v end })

-- ── Webhook Tab ──
local WebTab = Window:AddTab({ Title = "📡 Webhook", Icon = "solar/link-bold" })
WebTab:AddInput("webhookUrl", { Title = "Webhook URL", Default = "", Callback = function(v) Flags["webhookUrl"] = v end })
WebTab:AddInput("whPing", { Title = "Ping ID", Default = "", Callback = function(v) Flags["whPing"] = v end })
WebTab:AddToggle("whAllowPing", { Title = "Allow Ping", Default = false, Callback = function(v) Flags["whAllowPing"] = v end })
WebTab:AddDropdown("whPetFilter", { Title = "Pet Filter", Values = getPetList(), Default = "Any", Callback = function(v) Flags["whPetFilter"] = v end })
WebTab:AddDropdown("whPetRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["whPetRarity"] = v end })
WebTab:AddDropdown("whPetSize", { Title = "Size", Values = {"Any","Small","Medium","Large","Huge"}, Default = "Any", Callback = function(v) Flags["whPetSize"] = v end })
WebTab:AddToggle("whPetPurchase", { Title = "Pet Purchase", Default = false, Callback = function(v) Flags["whPetPurchase"] = v end })
WebTab:AddDropdown("whEventSeed", { Title = "Event Seed", Values = getSeedList(), Default = "All", Callback = function(v) Flags["whEventSeed"] = v end })
WebTab:AddToggle("whEventSeedEnabled", { Title = "Event Seed Collection", Default = false, Callback = function(v) Flags["whEventSeedEnabled"] = v end })

-- ── Misc Tab ──
local MiscTab = Window:AddTab({ Title = "🧰 Misc", Icon = "solar/widget-bold" })

local ESPGrp = MiscTab:AddGroup("ESP", 2)
ESPGrp:AddDropdown("espFruit", { Title = "Fruit", Values = getCropList(), Default = "All", Multi = true, Callback = function(v) Flags["espFruit"] = v end })
ESPGrp:AddDropdown("espFruitRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["espFruitRarity"] = v end })
ESPGrp:AddDropdown("espFruitMutation", { Title = "Mutation", Values = {"Any","Mutated Only","Non-Mutated Only"}, Default = "Any", Callback = function(v) Flags["espFruitMutation"] = v end })
ESPGrp:AddToggle("espFruitEnabled", { Title = "ESP Fruit", Default = false, Callback = function(v) Flags["espFruitEnabled"] = v end })
ESPGrp:AddDropdown("espPet", { Title = "Pets", Values = getAllPetSpecies(), Default = "Any", Callback = function(v) Flags["espPet"] = v end })
ESPGrp:AddDropdown("espPetRarity", { Title = "Rarity", Values = RARITY_LIST, Default = "Any", Callback = function(v) Flags["espPetRarity"] = v end })
ESPGrp:AddToggle("espPetEnabled", { Title = "ESP Pets", Default = false, Callback = function(v) Flags["espPetEnabled"] = v end })
ESPGrp:AddToggle("espMutationLabels", { Title = "Mutation Labels", Default = false, Callback = function(v) Flags["espMutationLabels"] = v end })
ESPGrp:AddToggle("espPlantAge", { Title = "Plant Age", Default = false, Callback = function(v) Flags["espPlantAge"] = v end })

local ValGrp = MiscTab:AddGroup("Value ESP", 2)
ValGrp:AddToggle("espFruitValue", { Title = "Fruit Value Tags", Default = false, Callback = function(v) Flags["espFruitValue"] = v end })
ValGrp:AddToggle("espTotalValue", { Title = "Total Garden Value", Default = false, Callback = function(v) Flags["espTotalValue"] = v end })
ValGrp:AddToggle("espInvValue", { Title = "Inventory Value", Default = false, Callback = function(v) Flags["espInvValue"] = v end })
ValGrp:AddToggle("espBaseValueOnly", { Title = "Base Value Only", Default = false, Callback = function(v) Flags["espBaseValueOnly"] = v end })
ValGrp:AddToggle("rareNotify", { Title = "Rare Seed Alert", Default = false, Callback = function(v) Flags["rareNotify"] = v end })
ValGrp:AddButton({ Title = "Refresh ESP", Callback = function() pcall(doESP) end })

MiscTab:AddDivider()
local ProtSec = MiscTab:AddCollapsibleSection({ Title = "🔒 Protection", Open = false })
ProtSec:AddToggle("antiFling", { Title = "Anti-Fling", Default = true, Callback = function(v) Flags["antiFling"] = v end })
ProtSec:AddToggle("lessKnockback", { Title = "Less Knockback", Default = false, Callback = function(v) Flags["lessKnockback"] = v end })
ProtSec:AddToggle("instantPrompt", { Title = "Instant Prompt", Default = false, Callback = function(v) Flags["instantPrompt"] = v end })
ProtSec:AddToggle("bypassPause", { Title = "Bypass Pause", Default = true, Callback = function(v) Flags["bypassPause"] = v end })
ProtSec:AddToggle("noclipPlants", { Title = "Noclip Plants", Default = false, Callback = function(v) Flags["noclipPlants"] = v end })

local MoveSec = MiscTab:AddCollapsibleSection({ Title = "🏃 Movement", Open = false })
MoveSec:AddSlider("runSpeed", { Title = "Walk Speed", Min = 16, Max = 250, Default = 16, Suffix = "", Callback = function(v) Flags["runSpeed"] = v end })
MoveSec:AddSlider("jumpHeight", { Title = "Jump Height", Min = 7.2, Max = 100, Default = 7.2, Suffix = "", Callback = function(v) Flags["jumpHeight"] = v end })
MoveSec:AddToggle("multiJump", { Title = "Multi Jump", Default = false, Callback = function(v) Flags["multiJump"] = v end })
MoveSec:AddToggle("infJump", { Title = "Infinite Jump", Default = false, Callback = function(v) Flags["infJump"] = v end })
MoveSec:AddToggle("noClip", { Title = "Noclip", Default = false, Callback = function(v) Flags["noClip"] = v end })
MoveSec:AddToggle("fullBright", { Title = "Full Bright", Default = false, Callback = function(v) Flags["fullBright"] = v end })
MoveSec:AddSlider("brightness", { Title = "Brightness", Min = 1, Max = 10, Default = 5, Suffix = "", Callback = function(v) Flags["brightness"] = v end })
MoveSec:AddToggle("noFog", { Title = "No Fog", Default = false, Callback = function(v) Flags["noFog"] = v end })
MoveSec:AddToggle("noShadows", { Title = "No Shadows", Default = false, Callback = function(v) Flags["noShadows"] = v end })
MoveSec:AddToggle("freeFlight", { Title = "Fly", Default = false, Callback = function(v) Flags["freeFlight"] = v end })
MoveSec:AddSlider("flightSpeed", { Title = "Fly Speed", Min = 10, Max = 200, Default = 50, Suffix = "", Callback = function(v) Flags["flightSpeed"] = v end })
MoveSec:AddButton({ Title = "TP: Seed Shop", Callback = function() local t = Workspace:FindFirstChild("SeedShop", true) if t then teleport(t:GetPivot().Position) end end })
MoveSec:AddButton({ Title = "TP: My Garden", Callback = function() local p = myPlot() if p then local s = p:FindFirstChild("SpawnPoint") if s then teleport(s.Position) end end end })

local ServerSec = MiscTab:AddCollapsibleSection({ Title = "🌐 Server", Open = false })
ServerSec:AddButton({ Title = "Server Hop", Callback = function() serverHop(false) end })
ServerSec:AddButton({ Title = "Low-Pop Hop", Callback = function() serverHop(true) end })
ServerSec:AddButton({ Title = "Rejoin", Callback = function() pcall(function() TeleportService:Teleport(game.PlaceId, client) end) end })

-- ── Visual Tab ──
local VisTab = Window:AddTab({ Title = "👁️ Visual", Icon = "solar/eye-bold" })
VisTab:AddParagraph({ Title = "Client-side visual injections", Content = "" })
VisTab:AddInput("visualMoneyAmount", { Title = "Sheckles Amount", Default = "1000000", Callback = function(v) Flags["visualMoneyAmount"] = v end })
VisTab:AddButton({ Title = "Set Fake Sheckles", Callback = function()
    local v = tonumber(Flags["visualMoneyAmount"]) or 0
    local ls = client:FindFirstChild("leaderstats") if ls then local s = ls:FindFirstChild("Sheckles") if s then s.Value = v end end
end })
VisTab:AddInput("visualSeedName", { Title = "Seed Name", Default = "Gold", Callback = function(v) Flags["visualSeedName"] = v end })
VisTab:AddInput("visualSeedCount", { Title = "Count", Default = "100", Callback = function(v) Flags["visualSeedCount"] = v end })
VisTab:AddButton({ Title = "Add Fake Seed", Callback = function() end })
VisTab:AddInput("visualPetType", { Title = "Pet Type", Default = "Cat", Callback = function(v) Flags["visualPetType"] = v end })
VisTab:AddInput("visualPetCount", { Title = "Count", Default = "5", Callback = function(v) Flags["visualPetCount"] = v end })
VisTab:AddButton({ Title = "Add Fake Pet", Callback = function() end })
VisTab:AddButton({ Title = "Reset All Visuals", Callback = function() end })

-- ── Settings Tab ──
local SetTab = Window:AddTab({ Title = "🔧 Settings", Icon = "solar/settings-minimalistic-bold" })
SetTab:AddToggle("ultraAfkMode", { Title = "Ultra AFK Mode", Default = false, Description = "Disable 3D + 15 FPS", Callback = function(v) StabilityEngine:SetAFKThrottling(v, 15) end })
SetTab:AddToggle("antiStuckWatchdog", { Title = "Anti-Stuck Watchdog", Default = true, Callback = function(v) if v then StabilityEngine:StartAntiStuckWatchdog(2, 20) else StabilityEngine:StopAntiStuckWatchdog() end end })
SetTab:AddToggle("moreFps", { Title = "FPS Optimizer", Default = false, Callback = function(v)
    if v then LightingService.GlobalShadows = false; LightingService.FogEnd = 780
        for _, e in ipairs(LightingService:GetDescendants()) do if e:IsA("Sky") then pcall(function() e.CelestialBodiesShown = false end) end end
    end
end })
SetTab:AddToggle("autoRemoveGardens", { Title = "Auto Remove Gardens", Default = false, Callback = function(v) Flags["autoRemoveGardens"] = v end })
SetTab:AddToggle("autoSave", { Title = "Auto Save Settings", Default = true, Callback = function(v) Flags["autoSave"] = v end })
SetTab:AddButton({ Title = "Save Settings", Callback = function() saveSettings() end })
SetTab:AddButton({ Title = "Load Settings", Callback = function() loadSettings() end })
SetTab:AddButton({ Title = "Reset to Defaults", Callback = function() if writefile then pcall(function() writefile(SAVE_FILE, "{}") end) end end })

-- ── Fall Event Tab ──
if isMainGame then
    local FallTab = Window:AddTab({ Title = "🍂 Fall", Icon = "solar/leaf-bold" })
    FallTab:AddParagraph({ Title = "Fall Harvest Event", Content = "Place ID: 129343810645058" })
    FallTab:AddButton({ Title = "Teleport to Fall Harvest", Callback = function() pcall(function() TeleportService:Teleport(129343810645058) end) end })
    FallTab:AddToggle("autoTPFallHarvest", { Title = "Auto TP to Fall Harvest", Default = false, Callback = function(v) Flags["autoTPFallHarvest"] = v if v then task.wait(3) if Flags["autoTPFallHarvest"] then pcall(function() TeleportService:Teleport(129343810645058) end) end end end })
end

-- live stats (update via 2s loop using labels stored in UpdateLabels)
local function ul(tag, text)
    local lb = UpdateLabels[tag]
    if lb and lb.SetText then pcall(function() lb:SetText(text) end) end
end
local function hl(tag, text)
    local lb = UpdateLabels["home_" .. tag]
    if lb and lb.SetText then pcall(function() lb:SetText(text) end) end
end
-- BACKGROUND LOOPS
-- ================================================================

-- sell on interval (single driver - no more double-mechanism)
local _lastAutoSell = 0
local _lastSellFull = 0
local _lastDailyDeal = 0
track(RunService.Heartbeat:Connect(function()
    local now = os.clock()
    pcall(function()
        if Flags["autoSell"] then
            local si = tonumber(Flags["sellInterval"]) or 20
            if now - _lastAutoSell >= si then
                _lastAutoSell = now
                doSellAll()
            end
        end
        -- sell on full (rate-limited to avoid spamming SellAll every frame)
        if Flags["sellOnFull"] and now - _lastSellFull >= 5 then
            if isInventoryFull() then
                _lastSellFull = now
                doSellAll()
            end
        end
        -- daily deal (rate-limited to ~1/s to avoid spam)
        if Flags["dailyDeal"] and now - _lastDailyDeal >= 1 then
            _lastDailyDeal = now
            netFire("NPCS.UseDailyDealAll")
        end
    end)
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
            if Flags["hitStolen"] then
                doRetaliateShovel()
            end
            if Flags["rareNotify"] then
                doRareNotify()
            end
            if Flags["antiFling"] then
                doAntiFling()
            end
            if Flags["bypassPause"] then
                doBypassPause()
            end
            if Flags["noclipPlants"] then
                doNoclipPlants()
            end
            if Flags["lessKnockback"] then
                doLessKnockback()
            end
            if Flags["petProtection"] then
                doPetProtection()
            end
            if Flags["autoBuyPet"] then
                doAutoBuyPet()
            end
            -- auto sell selective / pets
            if Flags["autoSellSelective"] then
                doSellSelective()
            end
            if Flags["autoSellPets"] then
                doSellPets()
            end
            if Flags["autoBuyAllSeeds"] then
                local stockParent = seedStock()
                if stockParent then
                    for _, stockValue in ipairs(stockParent:GetChildren()) do
                        local qty = stockValue.Value or 0
                        if qty > 0 then
                            netFire("SeedShop.PurchaseSeed", stockValue.Name)
                            task.wait(0.05)
                        end
                    end
                end
            end
            if Flags["autoBuyAllGear"] then
                local stockParent = gearStock()
                if stockParent then
                    for _, stockValue in ipairs(stockParent:GetChildren()) do
                        if (stockValue.Value or 0) > 0 then
                            netFire("GearShop.PurchaseGear", stockValue.Name)
                            task.wait(0.05)
                        end
                    end
                end
            end
            if Flags["autoBuyAllCrates"] then
                local stockParent = crateStock()
                if stockParent then
                    for _, stockValue in ipairs(stockParent:GetChildren()) do
                        if (stockValue.Value or 0) > 0 then
                            netFire("CrateShop.PurchaseCrate", stockValue.Name)
                            task.wait(0.05)
                        end
                    end
                end
            end
            -- auto water all
            if Flags["autoWaterAll"] then
                doWateringCan()
            end
            -- auto place all sprinklers
            if Flags["autoSprinklerAll"] then
                doSprinklerAll()
            end
            -- auto expand garden
            if Flags["autoExpand"] then
                netFire("Actions.ExpandGarden")
            end
            -- auto favorite/unfavorite
            if Flags["autoFav"] then
                doFavorite(true)
            end
            if Flags["autoUnfav"] then
                doFavorite(false)
            end
            if Flags["autoUnfavAll"] then
                doFavorite(false, true)
            end
            -- auto mailbox
            if Flags["autoSendSeed"] or Flags["autoSendPet"] then
                doMailboxSend()
            end
            -- ESP
            if Flags["espFruitEnabled"] or Flags["espPetEnabled"]
                or Flags["espMutationLabels"] or Flags["espPlantAge"] then
                espTimer = espTimer + 1
                if espTimer >= 1 then
                    espTimer = 0
                    doESP()
                end
            elseif next(_espPool) then
                clearESP()
            end
            -- instant prompt
            if Flags["instantPrompt"] then
                promptTimer = promptTimer + 1
                if promptTimer >= 3 then
                    promptTimer = 0
                    doInstantPrompt()
                end
            end
            -- auto remove gardens
            if Flags["autoRemoveGardens"] then
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
            if invVal <= 0 then
                for _, tool in ipairs(getFruitTools()) do
                    local fname = tool:GetAttribute("FruitName") or tool:GetAttribute("Fruit") or tool:GetAttribute("Seed") or tool.Name or ""
                    local rawW = tonumber(tool:GetAttribute("Weight"))
                        or (
                            (tonumber(tool:GetAttribute("SizeMultiplier")
                                or tool:GetAttribute("SizeMulti")) or 1)
                            * (ValueDB.baseWeight[fname] or 1)
                        )
                    local weight = rawW and rawW > 0 and rawW or 1
                    local mname = tool:GetAttribute("Mutation")
                    if type(mname) ~= "string" then
                        mname = nil
                    end
                    invVal = invVal + ValueEngine.compute(fname, weight, mname)
                end
            end
            local invValStr = invVal > 0 and (" ($" .. fmtCash(math.floor(invVal)) .. ")") or ""
            ul("statBalance", "Balance: " .. fmtCash(bal))
            ul("statPerMin", "Per Minute: " .. fmtCash(perMin))
            ul("statSession", "Session Earned: " .. fmtCash(sessionEarned))
            ul("statFruitCount", "Fruit Count: " .. fc .. "/" .. mc .. invValStr)
            ul("statHarvested", "Crops Harvested: " .. sessionHarvests)
            ul("statSessionTime", "Session Time: " .. math.floor(elapsed / 60) .. "m")
            -- weather info
            local weatherTag, phaseTag, phaseDuration = currentEvent()
            ul("statWeather", "Weather: " .. eventNameOf(weatherTag) .. " " .. fmtClock(phaseDuration))
            ul("statPhase", "Phase: " .. eventNameOf(phaseTag))
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
            hl("homeWeather", eventNameOf(weatherTag) .. " " .. fmtClock(phaseDuration))
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
            if Flags["autoCollect"] or Flags["autoCollectAll"] or Flags["autoCollectBest"] then
                doHarvest()
            end
            if Flags["collectGold"] or Flags["collectRainbow"] then
                doPackGrab()
            end
            if Flags["collectDropped"] then
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
            if not wasNight and n and Flags["panicHarvest"] then
                notify("Defense", "Panic Harvesting! Night has fallen.", "warning")
                doHarvest(true) -- harvest everything quickly
            end
            if
                wasNight
                and not n
                and (Flags["autoCollect"] or Flags["collectGold"] or Flags["collectRainbow"])
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
    if Flags["infJump"] then
        local character = client.Character
        local h = character and character:FindFirstChildOfClass("Humanoid")
        if h then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        return
    end
    if not Flags["multiJump"] then
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
                    Vector3.new(hrp.Velocity.X, 50, hrp.Velocity.Z)
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
if Window.OnClose then
    track(Window.OnClose:Connect(function()
        Hub.unload()
        if Flags["autoSave"] then
            saveSettings()
        end
    end))
end

-- ================================================================
-- INIT
-- ================================================================

-- ensure programmatically-set flags exist so loadSettings can populate them
Flags["savedPlantPos"] = Flags["savedPlantPos"] or false
Flags["savedSprinklerPos"] = Flags["savedSprinklerPos"] or false

loadSettings()

-- auto-teleport to Fall Harvest if flag was persisted
if isMainGame and Flags["autoTPFallHarvest"] then
    task.spawn(function()
        task.wait(1)
        if Flags["autoTPFallHarvest"] then
            local tps = game:GetService("TeleportService")
            pcall(function()
                tps:Teleport(FALL_HARVEST_PLACE_ID)
            end)
        end
    end)
end

-- re-apply movement settings on respawn
track(client.CharacterAdded:Connect(function(character)
    task.wait(0.6)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = tonumber(Flags["runSpeed"]) or 16
        humanoid.JumpHeight = tonumber(Flags["jumpHeight"]) or 7.2
        humanoid.UseJumpPower = false
        humanoid.PlatformStand = false
    end
    jumped = 0
    _flyBV, _flyBG = nil, nil
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
