local request = (syn and syn.request) or (http and http.request) or http_request;

-- Essential services
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LightingService = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.Camera

local client = Players.LocalPlayer

-- Load UI
print("Loading Library...")

local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()

local Setup = Library:Setup({
    Location = client.PlayerGui,
    OpenCloseLocation = "Bottom Right" -- Top Right, Bottom Left, Center Left, Etc
})

-- Prevent player from being idled out
client.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-----------------------------------------------------------------

function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    delayTime = math.max(tonumber(delayTime) or 0.1, 0.05)
    if not Library.Flags[flag] then
        return
    end

    local last = 0
    local running = false
    local slowWarnAt = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end

        local current = os.clock()
        if running or current - last < delayTime then
            return
        end

        last = current
        running = true

        local spawnFn = task and task.spawn or spawn
        spawnFn(function()
            local startedAt = os.clock()
            local ok, err = pcall(callback)
            local elapsed = os.clock() - startedAt

            if not ok then
                warn("[interval:" .. tostring(tag) .. "]", err)
            elseif elapsed > 10 and os.clock() - slowWarnAt > 5 then -- 10 is if the interval took longer than 10 seconds to work.
                slowWarnAt = os.clock()
                warn(string.format("[Versus] slow interval %s took %.3fs", tostring(tag), elapsed))
            end

            local waitFn = task and task.wait or wait
            waitFn()
            running = false
        end)
    end)

    Library:TrackConnection(conn, tag)
end

function notify(title, desc, style) -- style examples: "info" | "warning" | "danger"
    Library:createDisplayMessage(title, desc, {
        { text = "OK" },
    }, style or "info")
end

function prettyPrint(data, indent)
    indent = indent or 0
    local prefix = string.rep("    ", indent)
    if type(data) ~= "table" then
        print(prefix .. tostring(data))
        return
    end
    for k, v in pairs(data) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. " = {")
            prettyPrint(v, indent + 1)
            print(prefix .. "}")
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

----------------------------------------------------------------- https://versusairlines.top/developers.html

----------------------------------------------------------------------
-- Core game bootstrap / safe wrappers
----------------------------------------------------------------------

unpackArgs = table.unpack or unpack
Shared = ReplicatedStorage:WaitForChild("Shared", 15)
SharedList = Shared and Shared:FindFirstChild("List")
SharedUtil = Shared and Shared:FindFirstChild("Util")
SharedFunctions = Shared and Shared:FindFirstChild("Functions")
SharedVariables = Shared and Shared:FindFirstChild("Variables")
SharedValues = Shared and Shared:FindFirstChild("Values")

DataController = nil
MapList = nil
function safeRequire(module, label)
    if not module then
        warn("[RCU] Missing module:", tostring(label or module))
        return nil
    end

    local ok, result = pcall(require, module)
    if not ok then
        warn("[RCU] Failed to require", tostring(label or module), result)
        return nil
    end

    return result
end

function findPath(root, path)
    local node = root
    for _, name in ipairs(path) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

function safeRequirePath(root, path, label)
    return safeRequire(findPath(root, path), label or table.concat(path, "."))
end

Knit_Framework = nil
knitStart = os.clock()
repeat
    local ok, result = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
    end)
    if ok and result and result.GetService and result.GetController then
        Knit_Framework = result
    else
        task.wait(0.25)
    end
until Knit_Framework or os.clock() - knitStart > 15

function safeGetKnitService(name)
    if not Knit_Framework then return nil end
    local ok, result = pcall(function()
        return Knit_Framework.GetService(name)
    end)
    if not ok then
        warn("[RCU] Missing Knit service:", name, result)
        return nil
    end
    return result
end

function safeGetKnitController(name)
    if not Knit_Framework then return nil end
    local ok, result = pcall(function()
        return Knit_Framework.GetController(name)
    end)
    if not ok then
        warn("[RCU] Missing Knit controller:", name, result)
        return nil
    end
    return result
end

function safeServiceCall(service, methodName, ...)
    if not service then return nil, "missing_service" end
    local member = service[methodName]
    if member == nil then return nil, "missing_method:" .. tostring(methodName) end

    local args = { ... }
    local ok, result = pcall(function()
        if type(member) == "function" then
            return member(service, unpackArgs(args))
        end
        if member.Fire then
            return member:Fire(unpackArgs(args))
        end
        if member.Invoke then
            return member:Invoke(unpackArgs(args))
        end
        if member.FireServer then
            return member:FireServer(unpackArgs(args))
        end
        if member.InvokeServer then
            return member:InvokeServer(unpackArgs(args))
        end
    end)

    if not ok then
        warn("[RCU] service call failed:", tostring(methodName), result)
        return nil, result
    end

    return result
end

function safeControllerCall(controller, methodName, ...)
    if not controller then return nil, "missing_controller" end
    local member = controller[methodName]
    if type(member) ~= "function" then return nil, "missing_method:" .. tostring(methodName) end

    local args = { ... }
    local ok, result = pcall(function()
        return member(controller, unpackArgs(args))
    end)
    if not ok then
        warn("[RCU] controller call failed:", tostring(methodName), result)
        return nil, result
    end
    return result
end

function firstValue(v)
    if type(v) == "table" then
        return v[1]
    end
    return v
end

function addUnique(list, value)
    if value == nil then return end
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    table.insert(list, value)
end

function getCharacter()
    return client.Character or client.CharacterAdded:Wait()
end

function getHumanoid()
    local character = client.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

function getHRP()
    local character = client.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function getPart(inst)
    if not inst or typeof(inst) ~= "Instance" then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    if inst.FindFirstChildWhichIsA then
        return inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function moveToPosition(position)
    local humanoid = getHumanoid()
    if humanoid then
        humanoid:MoveTo(position)
    end
end

function teleportNear(inst, yOffset)
    local part = typeof(inst) == "Vector3" and nil or getPart(inst)
    local hrp = getHRP()
    if not hrp then return false end

    local pos = typeof(inst) == "Vector3" and inst or (part and part.Position)
    if not pos then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOffset or 4, 0))
    return true
end

function getData()
    if not DataController then return nil end
    local ok, data = pcall(function()
        if DataController.getData then
            return DataController:getData()
        end
        return DataController.data
    end)
    if ok and data then return data end
    return DataController.data
end

function isArrayLike(tbl)
    if type(tbl) ~= "table" then return false end
    return #tbl > 0
end

function hasValue(tbl, value)
    if type(tbl) ~= "table" then return false end
    if tbl[value] then return true end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function countTable(tbl)
    local n = 0
    if type(tbl) == "table" then
        for _ in pairs(tbl) do
            n = n + 1
        end
    end
    return n
end

function getCurrency(data, name)
    if not data then return 0 end
    if type(data[name]) == "number" then return data[name] end
    if type(data.currencies) == "table" and type(data.currencies[name]) == "number" then return data.currencies[name] end
    if type(data.stats) == "table" and type(data.stats[name]) == "number" then return data.stats[name] end
    return 0
end

function isMapUnlocked(mapId)
    local data = getData()
    if not data then return false end
    if not mapId then return true end
    if MapList and MapList[mapId] and MapList[mapId].alwaysUnlocked then return true end
    if type(data.maps) == "table" and hasValue(data.maps, mapId) then return true end
    if type(data.mapId) == "number" and data.mapId >= mapId then return true end
    return mapId <= 1
end

function createIntervalToggle(section, cfg)
    section:createToggle({
        Name = cfg.Name,
        Warning = cfg.Warning,
        WarnIf = cfg.WarnIf,
        Flag = cfg.Flag or false,
        flagName = cfg.flagName,
        Callback = function(enabled)
            local tag = cfg.tag or cfg.flagName
            Library:CleanupConnectionsByTag(tag)
            if not enabled then return end
            interval(tag, cfg.flagName, cfg.delay or 1, cfg.Step)
        end,
    })
end

function createTodoToggle(section, name, flagName, note)
    section:createToggle({
        Name = tostring(name) .. " (TODO)",
        Flag = false,
        flagName = flagName,
        Callback = function(enabled)
            Library:CleanupConnectionsByTag(flagName)
            if not enabled then return end
            interval(flagName, flagName, 5, function()
                -- blank
            end)
        end,
    })
end

----------------------------------------------------------------------
-- Knit services/controllers grounded from the current rbxmx scripts
----------------------------------------------------------------------

-- Services
CodesService = safeGetKnitService("CodesService")
EggService = safeGetKnitService("EggService")
PetService = safeGetKnitService("PetService")
ClickService = safeGetKnitService("ClickService")
RebirthService = safeGetKnitService("RebirthService")
UpgradeService = safeGetKnitService("UpgradeService")
RewardService = safeGetKnitService("RewardService")
ClanService = safeGetKnitService("ClanService")
ClanController = safeGetKnitController("ClanController")
IndexService = safeGetKnitService("IndexService")
PrestigeService = safeGetKnitService("PrestigeService")
MountService = safeGetKnitService("MountService")
PlayerService = safeGetKnitService("PlayerService")
FarmService = safeGetKnitService("FarmService")
GardenService = safeGetKnitService("GardenService")
InventoryService = safeGetKnitService("InventoryService")
AuraService = safeGetKnitService("AuraService")
BuildingService = safeGetKnitService("BuildingService")
WeatherService = safeGetKnitService("WeatherService")
TreeService = safeGetKnitService("TreeService")
DungeonService = safeGetKnitService("DungeonService")
QuestService = safeGetKnitService("QuestService")
RingService = safeGetKnitService("RingService")
EventService = safeGetKnitService("EventService")
ShopService = safeGetKnitService("ShopService")
FallingStarsService = safeGetKnitService("FallingStarsService")
OrbService = safeGetKnitService("OrbService")
OreService = safeGetKnitService("OreService")
SkillTreeService = safeGetKnitService("SkillTreeService")
MapService = safeGetKnitService("MapService")
AxeService = safeGetKnitService("AxeService")
PickaxeService = safeGetKnitService("PickaxeService")
LumberjackService = safeGetKnitService("LumberjackService")
ClassicService = safeGetKnitService("ClassicService")
FishingRodService = safeGetKnitService("FishingRodService")
HiveService = safeGetKnitService("HiveService")
BackpackService = safeGetKnitService("BackpackService")
FishingService = safeGetKnitService("FishingService")
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 425-426)
ThanksgivingService = safeGetKnitService("ThanksgivingService")
SeasonService = safeGetKnitService("SeasonService")
TapSkinService = safeGetKnitService("TapSkinService")
SupremeAltarService = safeGetKnitService("SupremeAltarService")
AdminAbuseService = safeGetKnitService("AdminAbuseService")
SettingsService = safeGetKnitService("SettingsService")
TitleService = safeGetKnitService("TitleService")
TotemService = safeGetKnitService("TotemService")

-- Controllers
DataController = safeGetKnitController("DataController")
ClickController = safeGetKnitController("ClickController")
EggController = safeGetKnitController("EggController")
HatchingController = safeGetKnitController("HatchingController")
PetController = safeGetKnitController("PetController")
MapController = safeGetKnitController("MapController")
ItemController = safeGetKnitController("ItemController")
FarmController = safeGetKnitController("FarmController")
GardenController = safeGetKnitController("GardenController")
AuraController = safeGetKnitController("AuraController")
UIController = safeGetKnitController("UIController")
OrbController = safeGetKnitController("OrbController")
WeatherController = safeGetKnitController("WeatherController")
TreeController = safeGetKnitController("TreeController")
DungeonController = safeGetKnitController("DungeonController")
OreController = safeGetKnitController("OreController")
FallingStarsController = safeGetKnitController("FallingStarsController")
MountController = safeGetKnitController("MountController")
SkillTreeController = safeGetKnitController("SkillTreeController")
AdminAbuseController = safeGetKnitController("AdminAbuseController")
FishingController = safeGetKnitController("FishingController")
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 456-457)
InventoryController = safeGetKnitController("InventoryController")
TotemController = safeGetKnitController("TotemController")
SeasonController = safeGetKnitController("SeasonController")
ExclusiveEggController = safeGetKnitController("ExclusiveEggController")

TeleportFrameComponent = nil

----------------------------------------------------------------------
-- Current module lists
----------------------------------------------------------------------

RebirthList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Rebirths" }, "Rebirths") or {}
chestList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Chests" }, "Chests") or {}
miniChestList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "MiniChests" }, "MiniChests") or {}
achievements = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Achievements" }, "Achievements") or {}
playtimeRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "PlaytimeRewards" }, "PlaytimeRewards") or {}
dailyRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "DailyRewards" }, "DailyRewards") or {}
indexRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "IndexRewards" }, "IndexRewards") or {}
prestigeList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Prestige", "Prestiges" }, "Prestige.Prestiges") or {}
farmsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Farms" }, "Farms") or {}
GardenPlants = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Skylands", "Plants" }, "Skylands.Plants") or {}
GardenSeeds = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Skylands", "Seeds" }, "Skylands.Seeds") or {}
MapList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Maps" }, "Maps") or {}
EggsModule = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Pets", "Eggs" }, "Pets.Eggs") or {}
PetsModule = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Pets", "Pets" }, "Pets.Pets") or {}
BuildingsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Buildings" }, "Buildings") or {}
upgradesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Upgrades" }, "Upgrades") or {}
SpaceUpgrades = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Space", "Upgrades" }, "Space.Upgrades") or upgradesList or {}
shopList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "AncientShop" }, "AncientShop") or {}
AxesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Axes" }, "Axes") or {}
TreesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Trees" }, "Trees") or {}
AngelQuests = safeRequirePath(ReplicatedStorage, { "Shared", "List", "AngelQuests" }, "AngelQuests") or {}
MinerQuests = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Mine", "MinerQuests" }, "Mine.MinerQuests") or {}
RingsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Rings" }, "Items.Rings") or {}
MountsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Mounts" }, "Items.Mounts") or {}
SmoothiesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Smoothies" }, "Items.Smoothies") or {}
TotemsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Totems" }, "Items.Totems") or {}
PotionsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Potions" }, "Items.Potions") or {}
SkillTreeList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "SkillTree" }, "SkillTree") or {}
HiveUpgrades = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Hive", "HiveUpgrades" }, "Hive.HiveUpgrades") or {}
HoneyShopList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Hive", "HoneyShop" }, "Hive.HoneyShop") or {}
HoneyMerchantList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Hive", "HoneyMerchant" }, "Hive.HoneyMerchant") or {}
BeedexRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Hive", "BeedexRewards" }, "Hive.BeedexRewards") or {}
BeeTypes = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Hive", "BeeTypes" }, "Hive.BeeTypes") or {}
BackpackItems = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "BackpackItems" }, "Items.BackpackItems") or {}
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 502-507)
FishingUpgrades = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Fishing", "FishingUpgrades" }, "Fishing.FishingUpgrades") or {}
FishingWorlds = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Fishing", "FishingWorlds" }, "Fishing.FishingWorlds") or {}
FishingRodUpgrader = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Fishing", "FishingRodUpgrader" }, "Fishing.FishingRodUpgrader") or {}
FishdexRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Fishing", "FishdexRewards" }, "Fishing.FishdexRewards") or {}
FishList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Fish" }, "Items.Fish") or {}
BeeItemsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Bees" }, "Items.Bees") or {}
ExclusiveItemsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Exclusive" }, "Items.Exclusive") or {}
ThanksgivingWheel = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Thanksgiving", "ThanksgivingWheel" }, "Thanksgiving.Wheel") or {}
CookingMachine = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Thanksgiving", "CookingMachine" }, "Thanksgiving.CookingMachine") or {}
HalloweenRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Halloween", "HalloweenRewards" }, "Halloween.Rewards") or {}
HalloweenShop = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Halloween", "HalloweenShop" }, "Halloween.Shop") or {}
ValentinesRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Valentines", "LovelyRewards" }, "Valentines.Rewards") or {}
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (line 520)
EasterRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Easter", "BunnyRewards" }, "Easter.BunnyRewards") or {}
ChristmasRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Christmas", "ChristmasRewards" }, "Christmas.Rewards") or {}
DungeonGamemodes = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Dungeon", "DungeonGamemodes" }, "Dungeon.DungeonGamemodes") or {}
DungeonPowerups = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Dungeon", "Powerups" }, "Dungeon.Powerups") or {}
DungeonShopList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Dungeon", "Shop" }, "Dungeon.Shop") or {}
DungeonUpgradesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Dungeon", "Upgrades" }, "Dungeon.Upgrades") or {}
DungeonRewardsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Dungeon", "Rewards" }, "Dungeon.Rewards") or {}

Functions = safeRequire(SharedFunctions, "Shared.Functions") or {}
Variables = safeRequire(SharedVariables, "Shared.Variables") or {}
Values = safeRequire(SharedValues, "Shared.Values") or {}
Util = safeRequire(SharedUtil, "Shared.Util") or {}
itemUtils = Util.itemUtils or {}
indexUtils = Util.indexUtils or {}
petUtils = Util.petUtils or {}
UpgradeUtils = safeRequirePath(ReplicatedStorage, { "Shared", "Util", "UpgradeUtils" }, "Util.UpgradeUtils") or Util.UpgradeUtils or {}
Items = safeRequirePath(ReplicatedStorage, { "Shared", "Items" }, "Shared.Items") or {}
CurrentSeasonNumber = tonumber(Variables and Variables.season) or 9
CurrentSeasonFolder = "Season" .. tostring(CurrentSeasonNumber)
CurrentSeasonTiers = safeRequirePath(ReplicatedStorage, { "Shared", "List", CurrentSeasonFolder, "Tiers" }, CurrentSeasonFolder .. ".Tiers") or {}
CurrentSeasonQuests = safeRequirePath(ReplicatedStorage, { "Shared", "List", CurrentSeasonFolder, "Quests" }, CurrentSeasonFolder .. ".Quests") or {}
CurrentSeasonRestartRewards = safeRequirePath(ReplicatedStorage, { "Shared", "List", CurrentSeasonFolder, "RestartRewards" }, CurrentSeasonFolder .. ".RestartRewards") or {}
RaritiesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Pets", "Rarities" }, "Pets.Rarities") or {}
ItemRaritiesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "Rarities" }, "Items.Rarities") or {}
MineUpgrades = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Mine", "MineUpgrades" }, "Mine.MineUpgrades") or {}
PetEquipTeams = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Pets", "PetEquipTeams" }, "Pets.PetEquipTeams") or {}

if Variables then
    Variables.clickCooldown = 0
end

----------------------------------------------------------------------
-- Feature helpers
----------------------------------------------------------------------

function getEggPart(egg)
    if not egg then return nil end
    local eggModel = egg:FindFirstChild("Egg")
    if eggModel and eggModel.PrimaryPart then return eggModel.PrimaryPart end
    return getPart(egg)
end

function getEggNames(includeLocked)
    local list = {}
    for eggName, eggData in pairs(EggsModule) do
        if includeLocked or isMapUnlocked(eggData.requiredMap) then
            addUnique(list, eggName)
        end
    end
    for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
        if egg and egg.Name and egg.Name ~= "" then
            addUnique(list, egg.Name)
        end
    end
    table.sort(list)
    if #list == 0 then table.insert(list, "None") end
    return list
end

function canAffordEgg(eggName)
    local data = getData()
    local eggData = EggsModule and EggsModule[eggName]
    if not data or not eggName or eggName == "None" then return false end

    -- Event/global eggs are often spawned models with attributes instead of normal list prices.
    -- Let EggController/EggService do the exact server-side affordability check for those.
    if not eggData then
        return true
    end

    if eggData.requiredMap and not isMapUnlocked(eggData.requiredMap) then return false end
    local currency = eggData.currency or "clicks"
    return getCurrency(data, currency) >= (eggData.cost or 0)
end

function getBestEggName()
    local bestName, bestCost = nil, -math.huge
    for eggName, eggData in pairs(EggsModule) do
        local cost = tonumber(eggData.cost) or 0
        if (not eggData.requiredMap or isMapUnlocked(eggData.requiredMap)) and canAffordEgg(eggName) and cost > bestCost then
            bestName = eggName
            bestCost = cost
        end
    end
    return bestName
end

function getNearestEggModel()
    local hrp = getHRP()
    if not hrp then return nil end
    local bestEgg, bestDist
    for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
        local part = getEggPart(egg)
        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if not bestDist or dist < bestDist then
                bestDist = dist
                bestEgg = egg
            end
        end
    end
    return bestEgg, bestDist
end

function getNearestEggName()
    local egg = getNearestEggModel()
    return egg and egg.Name or nil, egg
end

closestEggLabel = closestEggLabel or nil
lastClosestEggLabelText = lastClosestEggLabelText or nil

function getEggDisplayName(eggName, eggModel)
    local display = eggName or "None"
    local eggData = eggName and EggsModule and EggsModule[eggName]
    if type(eggData) == "table" and eggData.name then
        display = tostring(eggData.name)
    end
    if typeof(eggModel) == "Instance" then
        local attrName = eggModel:GetAttribute("displayName") or eggModel:GetAttribute("eggName") or eggModel:GetAttribute("name")
        if attrName then display = tostring(attrName) end
    end
    return display
end

function normalizeEggLookupKey(value)
    return tostring(value or ""):lower():gsub("[^%w]+", "")
end

function resolveEggSelection(eggValue, eggModel)
    if not eggValue or eggValue == "None" then return nil, nil end
    local selected = tostring(eggValue)

    if type(EggsModule) == "table" and EggsModule[selected] then
        return selected, eggModel or getEggModelByName(selected)
    end

    local wanted = normalizeEggLookupKey(selected)
    if wanted == "" then return selected, eggModel end

    for eggName, eggData in pairs(EggsModule or {}) do
        if normalizeEggLookupKey(eggName) == wanted then
            return eggName, eggModel or getEggModelByName(eggName)
        end
        if type(eggData) == "table" and eggData.name and normalizeEggLookupKey(eggData.name) == wanted then
            return eggName, eggModel or getEggModelByName(eggName)
        end
    end

    for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
        local modelName = tostring(egg.Name or "")
        local displayName = tostring(egg:GetAttribute("displayName") or egg:GetAttribute("eggName") or egg:GetAttribute("name") or "")
        if normalizeEggLookupKey(modelName) == wanted or normalizeEggLookupKey(displayName) == wanted then
            return modelName, egg
        end
    end

    return selected, eggModel or getEggModelByName(selected)
end

function isGlobalLuckEggModel(egg)
    if typeof(egg) ~= "Instance" then return false end
    if egg:GetAttribute("globalEggId") == nil then return false end
    if not egg:IsDescendantOf(Workspace) then return false end

    -- The game spawns boosted global eggs into Workspace.Debris, but keep the
    -- fallback loose in case Roblox streams the model before the parent finishes updating.
    local debris = Workspace:FindFirstChild("Debris")
    return not debris or egg:IsDescendantOf(debris)
end

function getBestGlobalLuckEggModel(targetEggName)
    local hrp = getHRP()
    local targetKey = normalizeEggLookupKey(targetEggName)
    local exactMatches = {}
    local allGlobalEggs = {}

    for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
        if isGlobalLuckEggModel(egg) then
            local part = getEggPart(egg)
            local dist = (hrp and part) and (part.Position - hrp.Position).Magnitude or 0
            local entry = { model = egg, distance = dist }
            table.insert(allGlobalEggs, entry)

            if targetKey == "" or normalizeEggLookupKey(egg.Name) == targetKey then
                table.insert(exactMatches, entry)
            end
        end
    end

    local candidates = #exactMatches > 0 and exactMatches or allGlobalEggs
    table.sort(candidates, function(a, b)
        return (a.distance or math.huge) < (b.distance or math.huge)
    end)

    return candidates[1] and candidates[1].model or nil
end

function resolveGlobalLuckEggOverride(eggName, eggModel)
    if not Library.Flags["OnlyHatchGlobalLuckEggs"] then
        return eggName, eggModel, false
    end

    if isGlobalLuckEggModel(eggModel) then
        return eggModel.Name, eggModel, true
    end

    local globalEgg = getBestGlobalLuckEggModel(eggName)
    if not globalEgg then
        return nil, nil, true
    end

    return globalEgg.Name, globalEgg, true
end

function setVersusLabelText(labelObject, text)
    if not labelObject then return false end
    local methods = { "Set", "set", "SetText", "setText", "SetName", "setName" }
    for _, methodName in ipairs(methods) do
        if type(labelObject[methodName]) == "function" then
            local ok = pcall(function()
                labelObject[methodName](labelObject, text)
            end)
            if ok then return true end
        end
    end
    for _, methodName in ipairs({ "Update", "update" }) do
        if type(labelObject[methodName]) == "function" then
            local ok = pcall(function()
                labelObject[methodName](labelObject, { Name = text })
            end)
            if ok then return true end
        end
    end
    pcall(function()
        local direct = labelObject.TextLabel or labelObject.Label or labelObject.Title
        if typeof(direct) == "Instance" and direct:IsA("TextLabel") then
            direct.Text = text
            return
        end
        local root = labelObject.Main or labelObject.Frame or labelObject.Object or labelObject.Instance
        if typeof(root) == "Instance" then
            local textLabel = root:FindFirstChildWhichIsA("TextLabel", true)
            if textLabel then textLabel.Text = text end
        end
    end)
    return false
end

function getClosestEggLabelText()
    local eggName, eggModel = getNearestEggName()
    if not eggName then return "Closest Egg: none found" end
    local _, distance = getNearestEggModel()
    local distanceText = distance and (" • " .. tostring(math.floor(distance)) .. " studs") or ""
    return "Closest Egg: " .. getEggDisplayName(eggName, eggModel) .. distanceText
end

function refreshClosestEggLabel()
    local text = getClosestEggLabelText()
    if text ~= lastClosestEggLabelText then
        lastClosestEggLabelText = text
        setVersusLabelText(closestEggLabel, text)
    end
end

function startClosestEggLabelUpdater()
    Library:CleanupConnectionsByTag("RCU_ClosestEggLabel")
    local lastUpdate = 0
    local conn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastUpdate < 1 then return end
        lastUpdate = now
        refreshClosestEggLabel()
    end)
    Library:TrackConnection(conn, "RCU_ClosestEggLabel")
    refreshClosestEggLabel()
end

function applyEggModelOpenParams(eggModel)
    if not EggController then return end

    EggController._globalEggId = nil
    EggController._luckyEggHuntId = nil
    EggController.isBestEgg = nil
    EggController.isMazeEgg = nil
    EggController.isBuildASnowman = nil
    EggController.adminEggLuck = nil
    EggController.isRNGEgg = nil
    EggController.isGiantEgg = nil
    EggController.isBunnyCave = nil

    if not eggModel then return end
    EggController._globalEggId = eggModel:GetAttribute("globalEggId")
    EggController._luckyEggHuntId = eggModel:GetAttribute("luckyEggHuntId")
    EggController.isBestEgg = eggModel:GetAttribute("isBestEgg")
    EggController.isMazeEgg = eggModel:GetAttribute("isMazeEgg")
    EggController.isBuildASnowman = eggModel:GetAttribute("isBuildASnowman")
    EggController.adminEggLuck = eggModel:GetAttribute("adminEggLuck")
    EggController.isRNGEgg = eggModel:GetAttribute("isRNGEgg")
    EggController.isGiantEgg = eggModel:GetAttribute("isGiantEgg")
    EggController.isBunnyCave = eggModel:GetAttribute("isBunnyCave")
end

function getEggOpenParams()
    if EggController and EggController.getOpenParams then
        local ok, params = pcall(function()
            return EggController:getOpenParams()
        end)
        if ok then return params or {} end
    end
    return {}
end

function getEggModelByName(eggName)
    if not eggName or eggName == "None" then return nil end
    local hrp = getHRP()
    local bestEgg, bestDist

    for _, egg in ipairs(CollectionService:GetTagged("Egg")) do
        if egg.Name == eggName then
            local part = getEggPart(egg)
            local dist = (hrp and part) and (part.Position - hrp.Position).Magnitude or 0
            if not bestDist or dist < bestDist then
                bestEgg, bestDist = egg, dist
            end
        end
    end

    return bestEgg
end

function openEgg(eggName, eggModel)
    eggName, eggModel = resolveEggSelection(eggName, eggModel)
    if not eggName or eggName == "None" then return end

    eggName, eggModel = resolveGlobalLuckEggOverride(eggName, eggModel)
    if not eggName or eggName == "None" then return false end

    eggModel = eggModel or getEggModelByName(eggName)

    if EggController then
        EggController._currentEgg = eggName
        applyEggModelOpenParams(eggModel)
    end

    local amountMode = Library.Flags["OpenTripleEggs"] and 2 or 1
    local params = getEggOpenParams()

    -- This is the exact endpoint used by the game's EggController after it checks affordability.
    -- Calling the service directly avoids selected eggs silently failing when the UI's current-egg state is not updating.
    local result, err = safeServiceCall(EggService, "openEgg", eggName, amountMode, params)
    if result ~= nil or not err then
        return result
    end

    if EggController and EggController.openEgg then
        local ok, controllerResult = pcall(function()
            return EggController:openEgg(amountMode)
        end)
        if ok then return controllerResult end
    end
end

function getBestRebirthIndex()
    local data = getData()
    if not data then return 0 end
    local clicks = getCurrency(data, "clicks")
    local currentRebirths = tonumber(data.rebirths) or 0
    local basePrice = tonumber(Variables.rebirthPrice) or 100
    local priceMultiplier = tonumber(Variables.rebirthPriceMultiplier) or 100
    local bestIndex = 0

    for index, amount in ipairs(RebirthList) do
        amount = tonumber(amount) or 0
        local price = (basePrice + currentRebirths * priceMultiplier) * amount + priceMultiplier * (amount * (amount - 1) / 2)
        if amount > 0 and price <= clicks then
            bestIndex = index
        end
    end

    return bestIndex
end

function collectOrbIds()
    local ids = {}
    local debris = Workspace:FindFirstChild("Debris")
    local orbs = debris and debris:FindFirstChild("Orbs")
    if not orbs then return ids end
    for _, orb in ipairs(orbs:GetChildren()) do
        table.insert(ids, orb.Name)
    end
    return ids
end

function claimAllChests()
    for chestId in pairs(chestList) do
        safeServiceCall(RewardService, "claimChest", chestId, true)
        task.wait(0.1)
    end
end

function hasMiniChestRestartUnlocked(data)
    data = data or getData() or {}
    if not UpgradeUtils or type(UpgradeUtils.getMasteryMultiplier) ~= "function" then return false end

    local ok, amount = pcall(function()
        return UpgradeUtils.getMasteryMultiplier(data, "restartMiniChests")
    end)

    return ok and (tonumber(amount) or 0) > 0
end

function canClaimMiniChestByName(groupName, chestName, data)
    if groupName == nil or chestName == nil then return false end

    data = data or getData() or {}
    local miniChests = type(data.miniChests) == "table" and data.miniChests or {}
    local lastClaim = miniChests[chestName]

    if not lastClaim then
        return true
    end

    if not hasMiniChestRestartUnlocked(data) then
        return false
    end

    local lastClaimTime = typeof(lastClaim) == "boolean" and 0 or (tonumber(lastClaim) or 0)
    local now = (Knit_Framework and Knit_Framework.serverTimeNow) or os.time()
    return now - lastClaimTime >= 86400
end

function canClaimMiniChest(chest, data)
    if typeof(chest) ~= "Instance" then return false end

    local groupName = chest:GetAttribute("miniChestId")
    local chestName = chest:GetAttribute("miniChestName")
    return canClaimMiniChestByName(groupName, chestName, data)
end

function markMiniChestClaimedLocally(chestName, data)
    if not chestName then return end
    data = data or getData()
    if type(data) ~= "table" then return end
    data.miniChests = type(data.miniChests) == "table" and data.miniChests or {}
    data.miniChests[chestName] = (Knit_Framework and Knit_Framework.serverTimeNow) or os.time()
end

function claimMiniChestByIds(groupName, chestName, data)
    if not canClaimMiniChestByName(groupName, chestName, data) then return false end

    local result = safeServiceCall(RewardService, "claimMiniChest", groupName, chestName)
    if result == "success" or result == true then
        markMiniChestClaimedLocally(chestName, data)
        return true
    end

    return false
end

function claimMiniChestModel(chest, data)
    if typeof(chest) ~= "Instance" then return false end
    return claimMiniChestByIds(chest:GetAttribute("miniChestId"), chest:GetAttribute("miniChestName"), data)
end

function claimAllMiniChests()
    local data = getData() or {}
    local claimed = 0
    local seen = {}

    -- Mini chests do not need proximity: the game's prompt only calls
    -- RewardService:claimMiniChest(miniChestId, miniChestName), so we can claim by IDs from anywhere.
    for groupId, chestGroup in pairs(miniChestList or {}) do
        if type(chestGroup) == "table" and (not chestGroup.requiredMap or isMapUnlocked(chestGroup.requiredMap)) then
            local groupName = chestGroup.miniChestId or chestGroup.id or groupId
            for _, chestName in ipairs(chestGroup.names or {}) do
                seen[tostring(groupName) .. ":" .. tostring(chestName)] = true
                if claimMiniChestByIds(groupName, chestName, data) then
                    claimed = claimed + 1
                    task.wait(0.08)
                end
            end
        end
    end

    -- Fallback for any live/temporary mini chest models that are not in the module list yet.
    for _, chest in ipairs(CollectionService:GetTagged("MiniChest")) do
        local groupName = chest:GetAttribute("miniChestId")
        local chestName = chest:GetAttribute("miniChestName")
        local key = tostring(groupName) .. ":" .. tostring(chestName)
        if not seen[key] and claimMiniChestByIds(groupName, chestName, data) then
            claimed = claimed + 1
            task.wait(0.08)
        end
    end

    return claimed
end

function claimPlaytimeRewards()
    local data = getData()
    if not data then return end
    for rewardId, info in pairs(playtimeRewards) do
        local already = type(data.claimedPlaytimeRewards) == "table" and table.find(data.claimedPlaytimeRewards, rewardId)
        if not already then
            local required = tonumber(info.required) or 0
            if (tonumber(data.playtimeRewardTimer) or 0) >= required then
                safeServiceCall(RewardService, "claimPlaytimeReward", rewardId, true)
                task.wait(0.05)
            end
        end
    end
end

function claimAchievements()
    for achievementId in pairs(achievements) do
        safeServiceCall(RewardService, "claimAchievement", achievementId)
        task.wait(0.05)
    end
end

function claimIndexRewards(maxClaims)
    return claimIndexRewardsStep(maxClaims or 8)
end


function tableContainsValue(list, value)
    if type(list) ~= "table" then return false end
    return table.find(list, value) ~= nil or table.find(list, tostring(value)) ~= nil
end

function getClaimedRewardSet(data, key)
    local set = {}
    local claimed = data and data[key]
    if type(claimed) == "table" then
        for _, rewardId in ipairs(claimed) do
            set[rewardId] = true
            set[tostring(rewardId)] = true
        end
        for rewardId, owned in pairs(claimed) do
            if owned == true then
                set[rewardId] = true
                set[tostring(rewardId)] = true
            end
        end
    end
    return set
end

function readRewardRequired(rewardInfo)
    if type(rewardInfo) ~= "table" then return 0 end
    return tonumber(rewardInfo.required or rewardInfo.Required or rewardInfo.amount or rewardInfo.Amount or 0) or 0
end

function indexClaimSucceeded(result, err)
    if err ~= nil then return false end
    if result == true or result == "success" then return true end
    if type(result) == "string" then
        local lowered = result:lower()
        return lowered == "success" or lowered == "claimed" or lowered == "ok"
    end
    return false
end

function tableHasTruthyKey(tbl, key)
    if type(tbl) ~= "table" or key == nil then return false end
    local direct = tbl[key]
    if direct ~= nil and direct ~= false then return true end
    local stringKey = tostring(key)
    local stringValue = tbl[stringKey]
    return stringValue ~= nil and stringValue ~= false
end

function getAmountInIndexTable(tbl)
    if type(tbl) ~= "table" then return 0 end

    if Functions and type(Functions.getAmountInTable) == "function" then
        local ok, amount = pcall(function()
            return Functions.getAmountInTable(tbl)
        end)
        if ok and tonumber(amount) then
            return tonumber(amount)
        end
    end

    local amount = 0
    for _, owned in pairs(tbl) do
        if owned ~= nil and owned ~= false then
            amount = amount + 1
        end
    end
    return amount
end

function getPetExistTableSafe()
    if PetController and type(PetController.getExistTable) == "function" then
        local ok, existTable = pcall(function()
            return PetController:getExistTable()
        end)
        if ok and type(existTable) == "table" then
            return existTable
        end
    end
    return nil
end

function getPetIndexCollectedCount(data)
    data = data or getData()
    if not data then return 0 end

    if indexUtils and type(indexUtils.countIndex) == "function" then
        local ok, amount = pcall(function()
            return indexUtils.countIndex(data, getPetExistTableSafe())
        end)
        if ok and tonumber(amount) then
            return tonumber(amount)
        end
    end

    return getAmountInIndexTable(data.index)
end

function claimIndexRewardsStep(maxClaims)
    local data = getData()
    if not data then return 0 end

    local collected = getPetIndexCollectedCount(data)
    local claimed = getClaimedRewardSet(data, "claimedIndexRewards")
    local rewardIds = {}
    for rewardId in pairs(indexRewards or {}) do
        table.insert(rewardIds, rewardId)
    end
    table.sort(rewardIds, function(a, b)
        local ra = readRewardRequired(indexRewards[a])
        local rb = readRewardRequired(indexRewards[b])
        if ra == rb then return tostring(a) < tostring(b) end
        return ra < rb
    end)

    local claimedCount = 0
    local limit = tonumber(maxClaims) or 8
    for _, rewardId in ipairs(rewardIds) do
        if claimedCount >= limit then break end
        local required = readRewardRequired(indexRewards[rewardId])
        if not claimed[rewardId] and collected >= required then
            local result, err = safeServiceCall(IndexService, "claimIndexReward", rewardId)
            if indexClaimSucceeded(result, err) then
                claimedCount = claimedCount + 1
                claimed[rewardId] = true
                claimed[tostring(rewardId)] = true
                task.wait(0.1)
                data = getData() or data
                collected = getPetIndexCollectedCount(data)
            end
        end
    end

    return claimedCount
end

function getPetIndexDescriptorSafe(petName, tier)
    local descriptor = tostring(petName or "")
    if descriptor == "" then return descriptor end

    if Items and type(Items.pet) == "function" then
        local ok, result = pcall(function()
            local pet = Items.pet(petName)
            if pet and pet.setTier then
                pet = pet:setTier(tier or 1)
            end
            if petUtils and type(petUtils.getPetDescriptor) == "function" then
                return petUtils.getPetDescriptor(pet)
            end
            return petName
        end)
        if ok and result then
            descriptor = tostring(result):gsub(":s", "")
        end
    end

    return descriptor
end

function hasIndexedPetName(data, petName)
    if not data or type(data.index) ~= "table" or not petName then return false end

    for tier = 1, 4 do
        local descriptor = getPetIndexDescriptorSafe(petName, tier)
        if descriptor ~= "" then
            if data.index[descriptor] ~= nil or (indexUtils and type(indexUtils.hasIndex) == "function" and indexUtils.hasIndex(data, descriptor)) then
                return true
            end
        end
    end

    if data.index[petName] ~= nil or data.index[tostring(petName)] ~= nil then return true end

    local wanted = tostring(petName):lower()
    for descriptor in pairs(data.index) do
        if tostring(descriptor):lower():find(wanted, 1, true) then
            return true
        end
    end

    return false
end

function getBestIndexEggTarget()
    local data = getData()
    if not data or type(data.index) ~= "table" then return nil end

    local best = nil
    for eggName, eggData in pairs(EggsModule or {}) do
        if type(eggData) == "table" and type(eggData.pets) == "table" and canAffordEgg(eggName) then
            for petName, chance in pairs(eggData.pets) do
                local numericChance = tonumber(chance) or 0
                if numericChance > 0 and not hasIndexedPetName(data, petName) then
                    local cost = tonumber(eggData.cost) or 0
                    local candidate = {
                        eggName = eggName,
                        petName = petName,
                        chance = numericChance,
                        cost = cost,
                    }
                    if not best
                        or candidate.chance > best.chance
                        or (candidate.chance == best.chance and candidate.cost < best.cost)
                        or (candidate.chance == best.chance and candidate.cost == best.cost and tostring(candidate.eggName) < tostring(best.eggName)) then
                        best = candidate
                    end
                end
            end
        end
    end

    return best and best.eggName, best
end

function autoHatchIndexPetsStep()
    local eggName = getBestIndexEggTarget()
    if eggName then
        openEgg(eggName, getEggModelByName(eggName))
        return true
    end
    return false
end

function makeFishObjectForTier(fishName, tier)
    if not Items or type(Items.fish) ~= "function" then return nil end
    local ok, result = pcall(function()
        local fish = Items.fish(fishName)
        if fish and fish.setTier then
            fish = fish:setTier(tier or 1)
        end
        return fish
    end)
    if ok then return result end
    return nil
end

function getFishDescriptorAndWorld(fishName, tier)
    local fish = makeFishObjectForTier(fishName, tier)
    local descriptor = nil
    local worldName = nil

    if fish then
        pcall(function()
            if fish.getWorldName then
                local rawWorld = fish:getWorldName()
                if rawWorld ~= nil then worldName = tostring(rawWorld) end
            end
        end)
        pcall(function()
            if Util and Util.fishUtils and type(Util.fishUtils.getFishDescriptor) == "function" then
                local rawDescriptor = Util.fishUtils.getFishDescriptor(fish)
                if rawDescriptor ~= nil then descriptor = tostring(rawDescriptor) end
            end
        end)
        if not descriptor then
            pcall(function()
                if fish.getName then descriptor = tostring(fish:getName()) .. ":" .. tostring(tier or 1) end
            end)
        end
    end

    return descriptor or tostring(fishName or ""), worldName
end

function getFishdexCollectedCount(data, worldName)
    if not data or type(data.fishdex) ~= "table" then return 0, 0 end

    worldName = worldName and tostring(worldName) or nil

    if type(FishList) ~= "table" or countTable(FishList) <= 0 then
        local fallback = getAmountInIndexTable(data.fishdex)
        return fallback, fallback
    end

    local collected = 0
    local total = 0
    local seenDescriptors = {}

    for fishName in pairs(FishList) do
        for tier = 1, 4 do
            local descriptor, fishWorldName = getFishDescriptorAndWorld(fishName, tier)
            local descriptorWorld = fishWorldName and tostring(fishWorldName) or nil
            if descriptor and descriptor ~= "" and not seenDescriptors[descriptor] then
                if not worldName or descriptorWorld == worldName then
                    seenDescriptors[descriptor] = true
                    total = total + 1
                    if tableHasTruthyKey(data.fishdex, descriptor) then
                        collected = collected + 1
                    end
                end
            end
        end
    end

    if total <= 0 and not worldName then
        local fallback = getAmountInIndexTable(data.fishdex)
        return fallback, fallback
    end

    return collected, total
end

function claimFishIndexRewardsStep(maxClaims)
    local data = getData()
    if not data then return 0 end

    local claimed = getClaimedRewardSet(data, "claimedFishdexRewards")
    local rewardIds = {}
    for rewardId in pairs(FishdexRewards or {}) do
        table.insert(rewardIds, rewardId)
    end
    table.sort(rewardIds, function(a, b)
        local ra = readRewardRequired(FishdexRewards[a])
        local rb = readRewardRequired(FishdexRewards[b])
        if ra == rb then return tostring(a) < tostring(b) end
        return ra < rb
    end)

    local claimedCount = 0
    local limit = tonumber(maxClaims) or 8
    for _, rewardId in ipairs(rewardIds) do
        if claimedCount >= limit then break end
        local rewardInfo = FishdexRewards[rewardId]
        local required = readRewardRequired(rewardInfo)
        local worldName = type(rewardInfo) == "table" and (rewardInfo.world or rewardInfo.World or rewardInfo.worldName or rewardInfo.WorldName) or nil
        local collected = getFishdexCollectedCount(data, worldName)
        if not claimed[rewardId] and required > 0 and collected >= required then
            local result, err = safeServiceCall(FishingService, "claimFishdexdexReward", rewardId)
            if not indexClaimSucceeded(result, err) then
                result, err = safeServiceCall(FishingService, "claimFishdexReward", rewardId)
            end
            if indexClaimSucceeded(result, err) then
                claimedCount = claimedCount + 1
                claimed[rewardId] = true
                claimed[tostring(rewardId)] = true
                task.wait(0.1)
                data = getData() or data
            end
        end
    end

    return claimedCount
end

function claimBeeIndexRewardsStep(maxClaims)
    local data = getData()
    if not data then return 0 end

    local beedexCount = getAmountInIndexTable(data.beedex)
    local claimed = getClaimedRewardSet(data, "claimedBeedexRewards")
    local rewardIds = {}
    for rewardId in pairs(BeedexRewards or {}) do
        table.insert(rewardIds, rewardId)
    end
    table.sort(rewardIds, function(a, b)
        local ra = readRewardRequired(BeedexRewards[a])
        local rb = readRewardRequired(BeedexRewards[b])
        if ra == rb then return tostring(a) < tostring(b) end
        return ra < rb
    end)

    local claimedCount = 0
    local limit = tonumber(maxClaims) or 8
    for _, rewardId in ipairs(rewardIds) do
        if claimedCount >= limit then break end
        local required = readRewardRequired(BeedexRewards[rewardId])
        if not claimed[rewardId] and required > 0 and beedexCount >= required then
            local result, err = safeServiceCall(HiveService, "claimBeedexReward", rewardId)
            if indexClaimSucceeded(result, err) then
                claimedCount = claimedCount + 1
                claimed[rewardId] = true
                claimed[tostring(rewardId)] = true
                task.wait(0.1)
                data = getData() or data
                beedexCount = getAmountInIndexTable(data.beedex)
            end
        end
    end

    return claimedCount
end

function getBeeMaxEquipped(data)
    data = data or getData() or {}
    if Values and type(Values.beesMaxEquip) == "function" then
        local ok, result = pcall(function()
            return Values.beesMaxEquip(client, data)
        end)
        if ok and tonumber(result) then return math.max(1, math.floor(tonumber(result))) end
    end

    local equipped = type(data.equippedBees) == "table" and data.equippedBees or {}
    local current = 0
    for _, amount in pairs(equipped) do
        current = current + (tonumber(amount) or 1)
    end
    return math.max(3, current)
end

function getBeeObject(data, beeId, rawBee)
    if itemUtils and type(itemUtils.getItemFromId) == "function" then
        local ok, result = pcall(function()
            return itemUtils.getItemFromId(data, beeId)
        end)
        if ok and result then return result end
    end

    if itemUtils and type(itemUtils.createItemFromData) == "function" and type(rawBee) == "table" then
        local ok, result = pcall(function()
            return itemUtils.createItemFromData(rawBee)
        end)
        if ok and result then return result end
    end

    return nil
end

function getBeeAmount(bee, rawBee)
    local amount = 1
    pcall(function()
        if bee and bee.getAmount then amount = tonumber(bee:getAmount()) or amount end
    end)
    if type(rawBee) == "table" then
        amount = tonumber(rawBee.am or rawBee.amount or rawBee.Amount or rawBee.value or rawBee.Value) or amount
    elseif type(rawBee) == "number" then
        amount = rawBee
    end
    return math.max(1, math.floor(tonumber(amount) or 1))
end

function getBeeMultiplierScore(bee)
    local score = 0
    pcall(function()
        if bee and bee.getMultiplier then score = tonumber(bee:getMultiplier()) or score end
    end)
    pcall(function()
        if score == 0 and bee and bee.getSpecialMultiplierAmount then score = tonumber(bee:getSpecialMultiplierAmount()) or score end
    end)
    return tonumber(score) or 0
end

function buildBestBeeCounts(data)
    if not data or not data.inventory or type(data.inventory.bee) ~= "table" then return {} end

    local maxEquipped = getBeeMaxEquipped(data)
    local candidates = {}
    for beeId, rawBee in pairs(data.inventory.bee) do
        local bee = getBeeObject(data, beeId, rawBee)
        local amount = getBeeAmount(bee, rawBee)
        local score = getBeeMultiplierScore(bee)
        if amount > 0 and score > 0 then
            table.insert(candidates, {
                id = beeId,
                amount = amount,
                score = score,
                name = tostring(beeId),
            })
        end
    end

    table.sort(candidates, function(a, b)
        if a.score == b.score then return tostring(a.name) < tostring(b.name) end
        return a.score > b.score
    end)

    local desired = {}
    local used = 0
    for _, candidate in ipairs(candidates) do
        if used >= maxEquipped then break end
        local take = math.min(candidate.amount, maxEquipped - used)
        if take > 0 then
            desired[candidate.id] = (desired[candidate.id] or 0) + take
            used = used + take
        end
    end

    return desired
end

function beeCountTablesMatch(a, b)
    a = type(a) == "table" and a or {}
    b = type(b) == "table" and b or {}
    for beeId, amount in pairs(a) do
        if (tonumber(amount) or 0) ~= (tonumber(b[beeId]) or 0) then return false end
    end
    for beeId, amount in pairs(b) do
        if (tonumber(amount) or 0) ~= (tonumber(a[beeId]) or 0) then return false end
    end
    return true
end

function autoPutBestBeesInHiveStep()
    local data = getData()
    if not data or not data.inventory or type(data.inventory.bee) ~= "table" then return false end

    local desired = buildBestBeeCounts(data)
    if countTable(desired) <= 0 then return false end

    local current = type(data.equippedBees) == "table" and data.equippedBees or {}
    if beeCountTablesMatch(current, desired) then return false end

    for beeId, amount in pairs(current) do
        for _ = 1, math.max(1, tonumber(amount) or 1) do
            safeServiceCall(HiveService, "unequipBee", beeId)
            task.wait(0.08)
        end
    end

    task.wait(0.2)

    for beeId, amount in pairs(desired) do
        for _ = 1, math.max(1, tonumber(amount) or 1) do
            safeServiceCall(HiveService, "equipBee", beeId)
            task.wait(0.08)
        end
    end

    return true
end

function getMapNames(onlyLumberjack)
    local list = {}
    for mapId, mapInfo in pairs(MapList) do
        if type(mapInfo) == "table" and mapInfo.name then
            if not onlyLumberjack or mapInfo.lumberjack then
                table.insert(list, mapInfo.name)
            end
        end
    end
    table.sort(list)
    if #list == 0 then table.insert(list, "None") end
    return list
end

function getMapByName(name)
    for mapId, mapInfo in pairs(MapList) do
        if type(mapInfo) == "table" and mapInfo.name == name then
            return mapId, mapInfo
        end
    end
end

function getTreeGroups()
    local list = { "Nearest" }
    for groupId in pairs(TreesList) do
        table.insert(list, tostring(groupId))
    end
    table.sort(list, function(a, b)
        if a == "Nearest" then return true end
        if b == "Nearest" then return false end
        return a < b
    end)
    return list
end

function treeIsAlive(tree)
    local data = getData()
    local groupId = tree:GetAttribute("groupId") or tree:GetAttribute("group") or tree:GetAttribute("map")
    local treeId = tree:GetAttribute("treeId") or tree:GetAttribute("id")
    if data and groupId ~= nil and treeId ~= nil and data.trees and data.trees[groupId] and data.trees[groupId][treeId] then
        return (tonumber(data.trees[groupId][treeId].hp) or 0) > 0
    end
    return tree.Parent ~= nil
end

function pickNearestTree(groupFilter)
    local hrp = getHRP()
    if not hrp then return nil end

    local bestTree, bestDist
    for _, tree in ipairs(CollectionService:GetTagged("Tree")) do
        local groupId = tree:GetAttribute("groupId") or tree:GetAttribute("group") or tree:GetAttribute("map")
        local wanted = not groupFilter or groupFilter == "Nearest" or tostring(groupId) == tostring(groupFilter)
        local part = getPart(tree)
        if wanted and part and treeIsAlive(tree) then
            local dist = (part.Position - hrp.Position).Magnitude
            if not bestDist or dist < bestDist then
                bestTree = tree
                bestDist = dist
            end
        end
    end
    return bestTree, bestDist
end

function farmTree(useTeleport, groupOverride)
    local group = groupOverride or firstValue(Library.Flags["TreeGroup"])
    local tree = pickNearestTree(group)
    if not tree then return end

    if Library.Flags["UseVersusAI"] and not useTeleport then
        -- TODO: whenever I add versus ai to this
    end

    if useTeleport then
        teleportNear(tree, 4)
    end

    if TreeController and TreeController.moveToTree then
        safeControllerCall(TreeController, "moveToTree", tree)
    else
        local part = getPart(tree)
        if part then moveToPosition(part.Position) end
    end
end

function getOreRooms()
    local rooms = { "Any" }
    local data = getData()
    if data and type(data.ores) == "table" then
        for roomId in pairs(data.ores) do
            addUnique(rooms, tostring(roomId))
        end
    end
    for _, ore in ipairs(CollectionService:GetTagged("Ore")) do
        local roomId = ore:GetAttribute("roomId")
        if roomId ~= nil then addUnique(rooms, tostring(roomId)) end
    end
    for _, ore in ipairs(CollectionService:GetTagged("OreRoomSpawn")) do
        local roomId = ore:GetAttribute("roomId") or ore:GetAttribute("id")
        if roomId ~= nil then addUnique(rooms, tostring(roomId)) end
    end
    table.sort(rooms, function(a, b)
        if a == "Any" then return true end
        if b == "Any" then return false end
        return a < b
    end)
    return rooms
end

function oreIsAlive(ore)
    local data = getData()
    if not data then return ore.Parent ~= nil end
    if ore:HasTag("AfkOre") then
        local oreId = ore:GetAttribute("ore")
        return not data.afkOres or data.afkOres[oreId] ~= nil
    end

    local roomId = ore:GetAttribute("roomId")
    local id = ore:GetAttribute("id")
    if data.ores and roomId ~= nil and id ~= nil and data.ores[roomId] and data.ores[roomId][id] then
        local info = data.ores[roomId][id]
        local damage = tonumber(info.damage) or 0
        local oreData = nil
        if info.oreId and TreesList then
            oreData = TreesList[info.oreId]
        end
        if oreData and oreData.hp then
            return damage < oreData.hp
        end
        return true
    end
    return ore.Parent ~= nil
end

function pickNearestOre(roomFilter)
    local hrp = getHRP()
    if not hrp then return nil end
    local bestOre, bestDist

    function consider(ore)
        local roomId = ore:GetAttribute("roomId")
        local wanted = roomFilter == nil or roomFilter == "Any" or tostring(roomId) == tostring(roomFilter) or ore:HasTag("AfkOre")
        local part = getPart(ore)
        if wanted and part and oreIsAlive(ore) then
            local dist = (part.Position - hrp.Position).Magnitude
            if not bestDist or dist < bestDist then
                bestOre = ore
                bestDist = dist
            end
        end
    end

    for _, ore in ipairs(CollectionService:GetTagged("Ore")) do consider(ore) end
    for _, ore in ipairs(CollectionService:GetTagged("AfkOre")) do consider(ore) end
    return bestOre, bestDist
end

function mineOre(useTeleport)
    local room = firstValue(Library.Flags["MineRoom"])
    local ore = pickNearestOre(room)
    if not ore then return end

    if Library.Flags["UseVersusAI"] and not useTeleport then
        -- TODO: Hook this branch into the VersusAI server route request when the mining route endpoint is ready.
        -- For now, we still use the game's OreController movement/damage logic.
    end

    if useTeleport then
        teleportNear(ore, 4)
    end

    if OreController and OreController.moveToOre then
        safeControllerCall(OreController, "moveToOre", ore)
    else
        local part = getPart(ore)
        if part then moveToPosition(part.Position) end
    end
end

function getMineRoomTeleportTarget(roomFilter)
    if not roomFilter or roomFilter == "Any" or roomFilter == "None" then return nil end
    local wanted = tostring(roomFilter)

    for _, spawn in ipairs(CollectionService:GetTagged("OreRoomSpawn")) do
        local roomId = spawn:GetAttribute("roomId") or spawn:GetAttribute("id")
        if roomId ~= nil and tostring(roomId) == wanted then
            return spawn
        end
    end

    for _, ore in ipairs(CollectionService:GetTagged("Ore")) do
        local roomId = ore:GetAttribute("roomId")
        if roomId ~= nil and tostring(roomId) == wanted then
            return ore
        end
    end

    local data = getData()
    if data and type(data.ores) == "table" and data.ores[roomFilter] then
        for _, ore in ipairs(CollectionService:GetTagged("Ore")) do
            return ore
        end
    end
end

function teleportToSelectedMineRoom()
    local selected = firstValue(Library.Flags["MineRoom"])
    if not selected or selected == "Any" or selected == "None" then
        notify("Select a Mine Room", "Choose a specific mine room first, then press the teleport button.", "warning")
        return false
    end

    local target = getMineRoomTeleportTarget(selected)
    local part = getPart(target)
    if not part then
        notify("Mine Room Missing", "I couldn't find a streamed room spawn/ore for room " .. tostring(selected) .. ".", "warning")
        return false
    end

    pcall(function()
        client:RequestStreamAroundAsync(part.Position, 1)
    end)

    return teleportNear(part.Position + Vector3.new(0, 0, 6), 4)
end

function autoFarmMeteorsStep()
    local meteors = CollectionService:GetTagged("Meteor")
    if #meteors == 0 then return false end

    local fired = 0
    for _, meteor in ipairs(meteors) do
        local meteorId = meteor:GetAttribute("meteorId") or meteor:GetAttribute("id") or meteor.Name
        if meteorId ~= nil and tostring(meteorId) ~= "" then
            local _, err = safeServiceCall(EventService, "damageMeteorFastDenRiktiga", meteorId)
            if err == nil then
                fired = fired + 1
                task.wait(0.035)
            end
        end
        if fired >= 15 then break end
    end

    return fired > 0
end

SupplyDropRuntimeState = SupplyDropRuntimeState or {
    Drops = {},
    WatcherReady = false,
    LastPromptFallback = 0,
}

function getSupplyDropId(info)
    if type(info) ~= "table" then return nil end
    return info.supplyDropId or info.supplyDropID or info.id or info.Id or info.dropId or info.DropId
end

function rememberSupplyDrop(info)
    local supplyDropId = getSupplyDropId(info)
    if supplyDropId == nil or tostring(supplyDropId) == "" then return false end

    local key = tostring(supplyDropId)
    SupplyDropRuntimeState.Drops[key] = SupplyDropRuntimeState.Drops[key] or {}
    SupplyDropRuntimeState.Drops[key].Id = supplyDropId
    SupplyDropRuntimeState.Drops[key].ReadyAt = os.clock() + 181
    SupplyDropRuntimeState.Drops[key].LastAttempt = 0
    SupplyDropRuntimeState.Drops[key].Claimed = false
    return true
end

function setupSupplyDropWatcher()
    if SupplyDropRuntimeState.WatcherReady then return true end
    if not EventService or not EventService.spawnSupplyDrop or not EventService.spawnSupplyDrop.Connect then
        return false
    end

    Library:CleanupConnectionsByTag("RCU_SupplyDropWatcher")
    local conn = EventService.spawnSupplyDrop:Connect(function(info)
        rememberSupplyDrop(info)
    end)
    Library:TrackConnection(conn, "RCU_SupplyDropWatcher")
    SupplyDropRuntimeState.WatcherReady = true
    return true
end

function isSupplyDropClaimSuccess(result)
    if result == "success" or result == true then return true end
    if type(result) == "table" then
        local status = tostring(result.status or result.result or result[1] or ""):lower()
        return status == "success" or status == "ok" or status == "claimed"
    end
    return false
end

function fireSupplyDropPromptFallback()
    if type(fireproximityprompt) ~= "function" then return 0 end
    if os.clock() - (SupplyDropRuntimeState.LastPromptFallback or 0) < 3 then return 0 end
    SupplyDropRuntimeState.LastPromptFallback = os.clock()

    local fired = 0
    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return fired end

    for _, inst in ipairs(debris:GetDescendants()) do
        if inst:IsA("ProximityPrompt") and (inst.ObjectText == "Supply Drop" or inst:FindFirstAncestor("SupplyDropEvent")) then
            pcall(function()
                inst.HoldDuration = 0
                fireproximityprompt(inst)
            end)
            fired = fired + 1
            task.wait(0.1)
        end
    end

    return fired
end

function autoOpenSupplyDropsStep()
    setupSupplyDropWatcher()

    local opened = 0
    local now = os.clock()

    for key, drop in pairs(SupplyDropRuntimeState.Drops) do
        if type(drop) ~= "table" or drop.Claimed then
            SupplyDropRuntimeState.Drops[key] = nil
        elseif now >= (drop.ReadyAt or 0) and now - (drop.LastAttempt or 0) >= 3 then
            drop.LastAttempt = now
            local result, err = safeServiceCall(EventService, "claimSupplyDrop", drop.Id)
            if err == nil and isSupplyDropClaimSuccess(result) then
                drop.Claimed = true
                SupplyDropRuntimeState.Drops[key] = nil
                opened = opened + 1
            end
        end
    end

    opened = opened + fireSupplyDropPromptFallback()
    return opened > 0
end

function getInventoryItemsByKind(kindNames)
    local data = getData()
    local ids = {}
    if not data then return ids end

    local kinds = {}
    for _, kind in ipairs(kindNames or {}) do
        table.insert(kinds, tostring(kind):lower())
    end
    if #kinds == 0 then return ids end

    local seen = {}

    local function readItemObject(itemId, rawItem)
        local itemObject = nil
        if itemUtils and itemUtils.getItemFromId then
            local ok, result = pcall(function()
                return itemUtils.getItemFromId(data, itemId)
            end)
            if ok then itemObject = result end
        end
        if not itemObject and itemUtils and itemUtils.createItemFromData and type(rawItem) == "table" then
            local ok, result = pcall(function()
                return itemUtils.createItemFromData(rawItem)
            end)
            if ok then itemObject = result end
        end
        return itemObject
    end

    local function readItemAmount(itemObject, rawItem)
        if itemObject and itemObject.getAmount then
            local ok, amount = pcall(function() return itemObject:getAmount() end)
            if ok and tonumber(amount) then return tonumber(amount) end
        end
        if type(rawItem) == "number" then return rawItem end
        if type(rawItem) == "table" then
            return tonumber(rawItem.amount or rawItem.Amount or rawItem.a or rawItem.am or rawItem.qty or rawItem.quantity or rawItem.Count) or 1
        end
        return 1
    end

    local function matchesItem(itemId, rawItem, containerName)
        local itemObject = readItemObject(itemId, rawItem)
        local parts = {
            tostring(itemId or ""),
            tostring(containerName or ""),
        }

        if itemObject then
            pcall(function() table.insert(parts, tostring(itemObject:getClass())) end)
            pcall(function() table.insert(parts, tostring(itemObject:getName())) end)
            pcall(function()
                if itemObject.getRealName then table.insert(parts, tostring(itemObject:getRealName())) end
            end)
        end

        if type(rawItem) == "table" then
            table.insert(parts, tostring(rawItem.cl or rawItem.class or rawItem.Class or rawItem.type or rawItem.Type or rawItem.category or rawItem.kind or ""))
            table.insert(parts, tostring(rawItem.nm or rawItem.name or rawItem.Name or rawItem.id or rawItem.itemId or rawItem.item or ""))
        end

        local blob = table.concat(parts, " "):lower()
        for _, kind in ipairs(kinds) do
            if blob:find(kind, 1, true) then
                return itemObject, readItemAmount(itemObject, rawItem)
            end
        end
        return nil, 0
    end

    local function addItem(itemId, rawItem, containerName)
        if itemId == nil or seen[itemId] then return end
        local _, amount = matchesItem(itemId, rawItem, containerName)
        if amount and amount > 0 then
            seen[itemId] = true
            table.insert(ids, itemId)
        end
    end

    local function scan(container, containerName, depth)
        if type(container) ~= "table" or depth > 3 then return end
        for itemId, rawItem in pairs(container) do
            if type(rawItem) == "table" then
                if rawItem.cl or rawItem.class or rawItem.Class or rawItem.nm or rawItem.name or rawItem.Name or rawItem.amount or rawItem.Amount or rawItem.a or rawItem.am then
                    addItem(itemId, rawItem, containerName)
                else
                    scan(rawItem, tostring(itemId), depth + 1)
                end
            else
                addItem(itemId, rawItem, containerName)
            end
        end
    end

    scan(data.inventory, "inventory", 1)
    scan(data.items, "items", 1)
    scan(data.backpack, "backpack", 1)
    return ids
end

function useInventoryItems(kindNames, maxUses, extraParams)
    local used = 0
    maxUses = tonumber(maxUses) or 1
    for _, itemId in ipairs(getInventoryItemsByKind(kindNames)) do
        if used >= maxUses then break end
        local params = extraParams or { use = 1, mapId = getCurrentMapIdForItemUse() }
        local result, err = safeServiceCall(InventoryService, "useItem", itemId, params)
        if result == "success" or result == true or (result == nil and err == nil) then
            used = used + 1
            task.wait(0.1)
        end
    end
    return used
end

function getPotionTierRank(potionName)
    local lower = tostring(potionName or ""):lower()
    if lower:find("colossal", 1, true) then return 5 end
    if lower:find("giant", 1, true) then return 4 end
    if lower:find("ultra", 1, true) then return 3 end
    if lower:find("mega", 1, true) then return 2 end
    return 1
end

function getPotionQuestRequiredTier(questType)
    local lower = tostring(questType or ""):lower()
    if lower:find("colossal", 1, true) then return 5 end
    if lower:find("giant", 1, true) then return 4 end
    if lower:find("ultra", 1, true) then return 3 end
    if lower:find("mega", 1, true) then return 2 end
    return 1
end

function getPotionInventoryEntriesForQuest()
    local data = getData()
    local entries = {}
    if not data then return entries end

    for _, itemId in ipairs(getInventoryItemsByKind({ "potion" })) do
        local potionName = tostring(itemId)
        local amount = 1
        local rarity = "Common"
        local multiplier = 0
        local seconds = 0
        local layoutOrder = 999999

        if itemUtils and itemUtils.getItemFromId then
            local ok, itemObject = pcall(function() return itemUtils.getItemFromId(data, itemId) end)
            if ok and itemObject then
                pcall(function() potionName = tostring(itemObject:getName()) end)
                pcall(function() if itemObject.getAmount then amount = tonumber(itemObject:getAmount()) or amount end end)
                pcall(function() if itemObject.getRarity then rarity = tostring(itemObject:getRarity()) end end)
                pcall(function() if itemObject.getMultiplier then multiplier = tonumber(itemObject:getMultiplier()) or multiplier end end)
                pcall(function() if itemObject.getSeconds then seconds = tonumber(itemObject:getSeconds()) or seconds end end)
                pcall(function() if itemObject.getLayoutOrder then layoutOrder = tonumber(itemObject:getLayoutOrder()) or layoutOrder end end)
            end
        end

        local directory = type(PotionsList) == "table" and PotionsList[potionName]
        if type(directory) == "table" then
            rarity = directory.rarity or rarity
            multiplier = tonumber(directory.multiplier) or multiplier
            seconds = tonumber(directory.seconds) or seconds
            layoutOrder = tonumber(directory.layoutOrder) or layoutOrder
        end

        if amount > 0 then
            table.insert(entries, {
                id = itemId,
                name = potionName,
                amount = amount,
                tier = getPotionTierRank(potionName),
                rarityRank = getRarityRankFromName(rarity),
                multiplier = multiplier,
                seconds = seconds,
                layoutOrder = layoutOrder,
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.rarityRank ~= b.rarityRank then return a.rarityRank < b.rarityRank end
        if a.multiplier ~= b.multiplier then return a.multiplier < b.multiplier end
        if a.seconds ~= b.seconds then return a.seconds < b.seconds end
        return tostring(a.name) < tostring(b.name)
    end)

    return entries
end

function useLowestPotionForQuest(quest)
    local questType = getQuestType(quest)
    local requiredTier = getPotionQuestRequiredTier(questType)
    for _, potion in ipairs(getPotionInventoryEntriesForQuest()) do
        if potion.tier == requiredTier then
            local result, err = safeServiceCall(InventoryService, "useItem", potion.id, {
                use = 1,
                mapId = getCurrentMapIdForItemUse(),
            })
            return serviceCallSucceeded(result, err)
        end
    end
    return false
end

function getMountNames()
    local list = { "None" }
    for mountId in pairs(MountsList or {}) do
        table.insert(list, tostring(mountId))
    end
    table.sort(list)
    return list
end

lastEquippedClientMount = lastEquippedClientMount or nil

function equipClientMount(mountName)
    if not mountName or mountName == "None" then return false end
    if MountController then
        safeControllerCall(MountController, "despawnMount", client)
        safeControllerCall(MountController, "spawnMount", client, { cl = "mount", nm = mountName })
        lastEquippedClientMount = mountName
        return true
    end
    return false
end

function spoofAllMountsIntoInventory()
    local data = getData()
    if not data then return 0 end
    data.inventory = type(data.inventory) == "table" and data.inventory or {}
    data.inventory.mount = type(data.inventory.mount) == "table" and data.inventory.mount or {}

    local count = 0
    for mountName in pairs(MountsList or {}) do
        local fakeId = "RCU_ClientMount_" .. tostring(mountName)
        if not data.inventory.mount[fakeId] then
            data.inventory.mount[fakeId] = { cl = "mount", nm = mountName }
            count = count + 1
        end
    end

    return count
end

function getSmoothieNames()
    local list = { "None" }
    for smoothieId, smoothieData in pairs(SmoothiesList or {}) do
        if type(smoothieData) ~= "table" or smoothieData.canCraft ~= false then
            table.insert(list, tostring(smoothieId))
        end
    end
    table.sort(list)
    return list
end

function getTotemNames()
    local list = { "None" }
    for totemId in pairs(TotemsList or {}) do
        table.insert(list, tostring(totemId))
    end
    table.sort(list)
    return list
end

function getItemObjectName(itemObject)
    local name = ""
    if itemObject then
        pcall(function() name = tostring(itemObject:getName()) end)
        pcall(function()
            if itemObject.getRealName then
                local realName = itemObject:getRealName()
                if realName and tostring(realName) ~= "" then
                    name = name .. " " .. tostring(realName)
                end
            end
        end)
    end
    return name
end

function findInventoryItemByClassAndName(className, wantedName)
    local data = getData()
    if not data or type(data.inventory) ~= "table" or not itemUtils then return nil end
    local classLower = tostring(className or ""):lower()
    local wantedLower = tostring(wantedName or ""):lower()

    local function inspectItem(itemId, rawItem)
        local itemObject
        if itemUtils.getItemFromId then
            local ok, result = pcall(function() return itemUtils.getItemFromId(data, itemId) end)
            if ok then itemObject = result end
        end
        if not itemObject and itemUtils.createItemFromData then
            local ok, result = pcall(function() return itemUtils.createItemFromData(rawItem) end)
            if ok then itemObject = result end
        end

        if itemObject then
            local itemClass, itemName = "", getItemObjectName(itemObject)
            pcall(function() itemClass = tostring(itemObject:getClass()) end)
            if itemClass:lower() == classLower and itemName:lower():find(wantedLower, 1, true) then
                return itemId, itemObject
            end
            local rawName = tostring(rawItem and (rawItem.nm or rawItem.name or rawItem.Name) or "")
            if itemClass:lower() == classLower and rawName:lower() == wantedLower then
                return itemId, itemObject
            end
        elseif type(rawItem) == "table" then
            local rawClass = tostring(rawItem.cl or rawItem.class or rawItem.Class or ""):lower()
            local rawName = tostring(rawItem.nm or rawItem.name or rawItem.Name or ""):lower()
            if rawClass == classLower and rawName == wantedLower then
                return itemId, nil
            end
        end
    end

    for _, container in pairs(data.inventory) do
        if type(container) == "table" then
            for itemId, rawItem in pairs(container) do
                local foundId, foundObject = inspectItem(itemId, rawItem)
                if foundId then return foundId, foundObject end
            end
        end
    end

    return nil
end

function getCurrentMapIdForItemUse()
    if MapController and MapController.getCurrentMap then
        local ok, mapId = pcall(function() return MapController:getCurrentMap(true) end)
        if ok and mapId ~= nil then return mapId end
    end
    local data = getData() or {}
    return data.currentMap or data.map or data.mapId or 1
end

function selectedTotemAlreadyActive(totemName)
    local currentTotems = nil
    if TotemController and TotemController.getCurrentTotems then
        local ok, result = pcall(function() return TotemController:getCurrentTotems() end)
        if ok then currentTotems = result end
    end
    if not currentTotems and TotemService and TotemService.getCurrentTotems then
        local ok, result = pcall(function() return TotemService:getCurrentTotems() end)
        if ok then currentTotems = result end
    end

    if type(currentTotems) ~= "table" then return false end
    for _, totemData in pairs(currentTotems) do
        local rawItem = type(totemData) == "table" and totemData.item or nil
        local itemObject
        if rawItem and itemUtils and itemUtils.createItemFromData then
            local ok, result = pcall(function() return itemUtils.createItemFromData(rawItem) end)
            if ok then itemObject = result end
        end
        local activeName = itemObject and getItemObjectName(itemObject) or tostring(rawItem and (rawItem.nm or rawItem.name) or "")
        if activeName:lower():find(tostring(totemName):lower(), 1, true) or tostring(rawItem and rawItem.nm or ""):lower() == tostring(totemName):lower() then
            return true
        end
    end

    return false
end

function craftSelectedSmoothie()
    local smoothieId = firstValue(Library.Flags["SelectedSmoothie"] or "None")
    if not smoothieId or smoothieId == "None" then return false end
    local result = safeServiceCall(RewardService, "craftSmoothie", smoothieId)
    return result == "success" or result == true
end

function placeSelectedTotemIfNeeded()
    local totemId = firstValue(Library.Flags["SelectedTotem"] or "None")
    if not totemId or totemId == "None" then return false end
    if selectedTotemAlreadyActive(totemId) then return false end

    local itemId = findInventoryItemByClassAndName("totem", totemId)
    if not itemId then return false end

    local result = safeServiceCall(InventoryService, "useItem", itemId, {
        mapId = getCurrentMapIdForItemUse(),
        use = 1,
    })

    return result == "success" or result == true
end

function getUpgradeLevelForAutoBuy(data, upgradeId)
    local upgrades = type(data.upgrades) == "table" and data.upgrades or {}
    local value = upgrades[upgradeId]
    if type(value) == "number" then return value end
    if type(value) == "table" then return tonumber(value.level or value.amount or value.value or value.Level or value.Amount) or 0 end
    return 0
end

function getNextNormalUpgrade(upgradeId, upgradeInfo, data)
    if type(upgradeInfo) ~= "table" or type(upgradeInfo.upgrades) ~= "table" then return nil end
    local level = getUpgradeLevelForAutoBuy(data, upgradeId)
    local nextUpgrade = upgradeInfo.upgrades[level + 1]
    if not nextUpgrade and level == 0 then
        nextUpgrade = upgradeInfo.upgrades[0]
    end
    return nextUpgrade
end

function buyNormalUpgradesBatch(maxBuys)
    local data = getData()
    if not data then return 0 end
    local bought = 0
    local gems = tonumber(data.gems) or getCurrency(data, "gems")
    local priority = {
        freeAutoClicker = 1,
        rebirthButtons = 2,
        clicksMultiplier = 3,
        gemsMultiplier = 4,
        luckMultiplier = 5,
        hatchSpeed = 6,
        extraEggs = 7,
        goldenPetsLuck = 8,
        toxicPetsLuck = 9,
    }

    local ids = {}
    for upgradeId in pairs(upgradesList or {}) do table.insert(ids, upgradeId) end
    table.sort(ids, function(a, b)
        local pa, pb = priority[a] or 999, priority[b] or 999
        if pa == pb then return tostring(a) < tostring(b) end
        return pa < pb
    end)

    for _, upgradeId in ipairs(ids) do
        if bought >= (tonumber(maxBuys) or 5) then break end
        local upgradeInfo = upgradesList[upgradeId]
        local nextUpgrade = getNextNormalUpgrade(upgradeId, upgradeInfo, data)
        local cost = nextUpgrade and tonumber(nextUpgrade.cost)
        if cost and cost <= gems and (not upgradeInfo.requiredMap or isMapUnlocked(upgradeInfo.requiredMap)) then
            local result, err = safeServiceCall(UpgradeService, "upgrade", upgradeId)
            if result == "success" or result == true or (result == nil and not err) then
                bought = bought + 1
                gems = math.max(0, gems - cost)
                task.wait(0.12)
                data = getData() or data
            end
        end
    end

    return bought
end


function getUpgradeLevelFromData(data, tableName, upgradeId)
    if type(data) ~= "table" then return 0 end
    local container = type(data[tableName]) == "table" and data[tableName] or {}
    local value = container[upgradeId] or container[tostring(upgradeId)]
    if type(value) == "number" then return value end
    if type(value) == "table" then
        return tonumber(value.level or value.Level or value.amount or value.Amount or value.value or value.Value) or 0
    end
    return 0
end

function getNextUpgradeEntryForData(list, data, tableName, upgradeId)
    local info = type(list) == "table" and (list[upgradeId] or list[tostring(upgradeId)]) or nil
    if type(info) ~= "table" then return nil, info end
    local upgrades = info.upgrades or info.Upgrades
    if type(upgrades) ~= "table" then return nil, info end

    local level = getUpgradeLevelFromData(data, tableName, upgradeId)
    local nextEntry = upgrades[level + 1] or upgrades[tostring(level + 1)]
    if not nextEntry and level == 0 then
        nextEntry = upgrades[0] or upgrades["0"]
    end
    return nextEntry, info, level
end

function readCostAmount(cost)
    if type(cost) == "number" then return cost end

    if type(cost) == "table" then
        local raw = tonumber(cost.amount or cost.Amount or cost.value or cost.Value or cost.cost or cost.Cost or cost[2])
        if raw then return raw end
    end

    if cost ~= nil then
        local amount
        pcall(function()
            if cost.getAmount then amount = cost:getAmount() end
        end)
        if tonumber(amount) then return tonumber(amount) end
    end

    return 0
end

function readCostName(cost)
    if type(cost) == "table" then
        local raw = cost.name or cost.Name or cost.item or cost.Item or cost.itemId or cost.id or cost[1]
        if raw then return raw end
    end

    if cost ~= nil then
        local name
        pcall(function()
            if cost.getName then name = cost:getName() end
        end)
        if name then return name end
    end

    return nil
end

function getItemAmountByNameForAutoBuy(data, itemName)
    if not itemName or not data then return 0 end

    if itemUtils and type(itemUtils.getItemFromName) == "function" then
        local ok, itemObject = pcall(function()
            return itemUtils.getItemFromName(data, itemName)
        end)
        if ok and itemObject then
            local amount = 0
            pcall(function()
                if itemObject.getAmount then amount = itemObject:getAmount() end
            end)
            if tonumber(amount) then return tonumber(amount) end
        end
    end

    local inv = type(data.inventory) == "table" and data.inventory or {}
    for _, container in pairs(inv) do
        if type(container) == "table" then
            for itemId, raw in pairs(container) do
                local amount = 0
                local rawName = tostring(itemId)
                if type(raw) == "number" then
                    amount = raw
                elseif type(raw) == "table" then
                    amount = tonumber(raw.am or raw.amount or raw.Amount or raw.value or raw.Value or 1) or 1
                    rawName = tostring(raw.nm or raw.name or raw.Name or raw.item or raw.itemId or itemId)
                end
                if tostring(rawName):lower() == tostring(itemName):lower() then
                    return amount
                end
            end
        end
    end

    return 0
end

function canAffordUpgradeCost(data, cost, currencyName)
    if not cost then return true end

    if type(cost) == "number" then
        return (getCurrency(data, currencyName or "gems") or 0) >= cost
    end

    local costName = readCostName(cost)
    local costAmount = readCostAmount(cost)
    if costName and tostring(costName) ~= "" and costAmount > 0 then
        return getItemAmountByNameForAutoBuy(data, costName) >= costAmount
    end

    return true
end

function purchaseCallSucceeded(result, err)
    if err ~= nil then return false end
    if result == nil or result == true or result == "success" then return true end
    if type(result) == "string" then return result:lower() == "success" end
    return false
end

function callUpgradePurchaseMethod(methodNames, upgradeId)
    for _, methodName in ipairs(methodNames or {}) do
        local result, err = safeServiceCall(UpgradeService, methodName, upgradeId)
        if purchaseCallSucceeded(result, err) then
            return true, result, methodName
        end
    end
    return false
end

function buyUpgradeListBatch(config)
    local data = getData()
    if not data then return 0 end

    local list = config.List or {}
    local dataKey = config.DataKey
    local methods = config.Methods or {}
    local currencyName = config.Currency or "gems"
    local maxBuys = tonumber(config.MaxBuys) or 8
    local bought = 0
    local ids = {}

    for upgradeId in pairs(list) do
        table.insert(ids, upgradeId)
    end

    table.sort(ids, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, upgradeId in ipairs(ids) do
        if bought >= maxBuys then break end

        local nextEntry, upgradeInfo = getNextUpgradeEntryForData(list, data, dataKey, upgradeId)
        if nextEntry and (not upgradeInfo.requiredMap or isMapUnlocked(upgradeInfo.requiredMap)) then
            local cost = nextEntry.cost or nextEntry.Cost
            if canAffordUpgradeCost(data, cost, currencyName) then
                local ok = callUpgradePurchaseMethod(methods, upgradeId)
                if ok then
                    bought = bought + 1
                    task.wait(0.12)
                    data = getData() or data
                end
            end
        end
    end

    return bought
end

function buySpaceUpgradesBatch(maxBuys)
    return buyUpgradeListBatch({
        List = SpaceUpgrades or {},
        DataKey = "spaceUpgrades",
        Methods = { "upgradeSpace" },
        Currency = "gems",
        MaxBuys = maxBuys or 8,
    })
end

function buyMineUpgradesBatch(maxBuys)
    return buyUpgradeListBatch({
        List = MineUpgrades or {},
        DataKey = "mineUpgrades",
        Methods = { "upgradeMine" },
        MaxBuys = maxBuys or 8,
    })
end

function buyFishingUpgradesBatch(maxBuys)
    local bought = buyUpgradeListBatch({
        List = FishingUpgrades or {},
        DataKey = "fishingUpgrades",
        Methods = { "upgradeFishing" },
        MaxBuys = maxBuys or 8,
    })

    safeServiceCall(FishingRodService, "upgradeFishingRod")
    return bought
end

function ownsRingByName(data, ringId)
    if not data or not ringId then return false end
    if itemUtils and type(itemUtils.getItemFromName) == "function" then
        local ok, itemObject = pcall(function()
            return itemUtils.getItemFromName(data, ringId)
        end)
        if ok and itemObject then return true end
    end

    local inv = type(data.inventory) == "table" and data.inventory or {}
    for _, container in pairs(inv) do
        if type(container) == "table" then
            for itemId, raw in pairs(container) do
                local rawName = tostring(itemId)
                if type(raw) == "table" then
                    rawName = tostring(raw.nm or raw.name or raw.Name or raw.item or raw.itemId or itemId)
                end
                if rawName == tostring(ringId) then return true end
            end
        end
    end
    return false
end

function craftRingWithGameChoice(ringId, allowReroll)
    if not ringId or not RingService then return false end
    local data = getData() or {}

    if ownsRingByName(data, ringId) and not allowReroll then
        return false
    end

    local result, err = safeServiceCall(RingService, "craftRing", ringId, 1)
    if purchaseCallSucceeded(result, err) then return true end

    -- Very old game copies accepted this without the choice argument; keep it only as a fallback.
    result, err = safeServiceCall(RingService, "craftRing", ringId)
    return purchaseCallSucceeded(result, err)
end

function autoCraftRingsBatch(maxCrafts, allowReroll)
    local crafted = 0
    local ringIds = {}

    for ringId, ringData in pairs(RingsList or {}) do
        if type(ringData) ~= "table" or ringData.expired ~= true then
            table.insert(ringIds, ringId)
        end
    end

    table.sort(ringIds, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, ringId in ipairs(ringIds) do
        if crafted >= (tonumber(maxCrafts) or 3) then break end
        if craftRingWithGameChoice(ringId, allowReroll == true) then
            crafted = crafted + 1
            task.wait(0.25)
        end
    end

    return crafted
end


----------------------------------------------------------------------

----------------------------------------------------------------------
-- Skill tree helpers
----------------------------------------------------------------------

function isSkillTreeNodeOwned(data, categoryId, skillId, index)
    data = data or getData() or {}
    local tree = type(data.skillTree) == "table" and data.skillTree or {}
    local categoryData = type(tree[categoryId]) == "table" and tree[categoryId] or {}
    return categoryData[tostring(skillId) .. "_" .. tostring(index)] == true
end

function buySkillTreeBatch(maxBuys)
    maxBuys = tonumber(maxBuys) or 15
    local data = getData() or {}
    local bought = 0

    for categoryId, category in pairs(SkillTreeList) do
        local categoryList = type(category) == "table" and category.list or nil
        if type(categoryList) == "table" then
            for skillId, skillInfo in pairs(categoryList) do
                local levels = type(skillInfo) == "table" and skillInfo.list or nil
                if type(levels) == "table" then
                    for index = 1, #levels do
                        if not isSkillTreeNodeOwned(data, categoryId, skillId, index) then
                            local result = safeServiceCall(SkillTreeService, "buySkillTree", categoryId, skillId, index)
                            if result == "success" or result == true then
                                bought = bought + 1
                                task.wait(0.15)
                                data = getData() or data
                                if bought >= maxBuys then return bought end
                            else
                                task.wait(0.03)
                            end
                        end
                    end
                end
            end
        end
    end

    return bought
end

function findInventoryItemByNameMatch(matchText)
    local data = getData()
    if not data or type(data.inventory) ~= "table" or not itemUtils or not itemUtils.createItemFromData then return nil end
    matchText = tostring(matchText or ""):lower()

    for _, classItems in pairs(data.inventory) do
        if type(classItems) == "table" then
            for itemId, rawItem in pairs(classItems) do
                local ok, itemObject = pcall(function()
                    return itemUtils.createItemFromData(rawItem)
                end)
                if ok and itemObject then
                    local name = ""
                    pcall(function() name = tostring(itemObject:getName()) end)
                    pcall(function()
                        if itemObject.getRealName then
                            local realName = tostring(itemObject:getRealName())
                            if realName ~= "" and realName ~= "nil" then name = name .. " " .. realName end
                        end
                    end)
                    if name:lower():find(matchText, 1, true) then
                        return itemId, itemObject
                    end
                end
            end
        end
    end

    return nil
end

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 2706-2794)

-- Webhook helpers
----------------------------------------------------------------------

WEBHOOK_BACKEND_URL = "https://test.versusairlines.top/versusLauncher/game/webhook"
RCU_WEBHOOK_VERSION = "rcu-v2-rcu-specific-webhooks"
lastWebhookSend = lastWebhookSend or {}
webhookStats = webhookStats or {
    SessionStarted = os.time(),
    EggsOpened = 0,
    PetsHatched = 0,
    Hatches = 0,
    GoodPets = 0,
    GoodItems = 0,
    RarePets = 0,
    RareItems = 0,
    Rebirths = 0,
    TreesFarmed = 0,
    OresMined = 0,
    EventEggsOpened = 0,
    EventPetsHatched = 0,
    EventFightActions = 0,
    EventDrops = 0,
    SessionPetCounts = {},
    SessionPetRarityCounts = {},
    HatchedPets = {},
    LastEvents = {},
}

function trimString(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function compactWebhookText(value, maxLen)
    value = trimString(value):gsub("%s+", " ")
    maxLen = tonumber(maxLen) or 900
    if #value > maxLen then
        return value:sub(1, math.max(1, maxLen - 3)) .. "..."
    end
    return value
end

function discordText(value, maxLen)
    value = compactWebhookText(value, maxLen or 900)
    value = value:gsub("@everyone", "@\226\128\139everyone"):gsub("@here", "@\226\128\139here")
    if value == "" then return "None" end
    return value
end

function discordColorFromHex(hex)
    hex = tostring(hex or "#B66DFF"):gsub("#", "")
    if not hex:match("^[%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F]$") then
        hex = "B66DFF"
    end
    return tonumber(hex, 16) or 11955711
end

function getWebhookUrl()
    local value = trimString(Library.Flags.RCUWebhookUrl or Library.Flags.WebhookUrl or "")
    if value == "" then return nil end
    return value
end

function hasWebhookUrl()
    return getWebhookUrl() ~= nil
end

function getSessionDurationText()
    local seconds = math.max(0, os.time() - (tonumber(webhookStats.SessionStarted) or os.time()))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then return string.format("%dh %dm %ds", hours, minutes, secs) end
    if minutes > 0 then return string.format("%dm %ds", minutes, secs) end
    return tostring(secs) .. "s"
end

function formatWebhookNumber(value)
    local n = tonumber(value)
    if not n then return tostring(value or 0) end
    local abs = math.abs(n)
    if abs >= 1e12 then return string.format("%.2fT", n / 1e12):gsub("%.00", "") end
    if abs >= 1e9 then return string.format("%.2fB", n / 1e9):gsub("%.00", "") end
    if abs >= 1e6 then return string.format("%.2fM", n / 1e6):gsub("%.00", "") end
    if abs >= 1e3 then return string.format("%.2fK", n / 1e3):gsub("%.00", "") end
    return tostring(math.floor(n))
end

function addWebhookRecentEvent(text)
    text = compactWebhookText(text, 160)
    if text == "" then return end
    table.insert(webhookStats.LastEvents, 1, os.date("%H:%M:%S") .. " - " .. text)
    while #webhookStats.LastEvents > 12 do
        table.remove(webhookStats.LastEvents)
    end
end

function incrementWebhookStat(name, amount)
    webhookStats[name] = (tonumber(webhookStats[name]) or 0) + (tonumber(amount) or 1)
end

function getAnyNumberFromData(data, keys)
    if not data then return 0 end
    for _, key in ipairs(keys or {}) do
        if type(data[key]) == "number" then return data[key] end
        if type(data.stats) == "table" and type(data.stats[key]) == "number" then return data.stats[key] end
        if type(data.currencies) == "table" and type(data.currencies[key]) == "number" then return data.currencies[key] end
    end
    return 0
end

function copyNumberCurrencies(source, target)
    if type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if type(key) == "string" and type(value) == "number" then
            target[key] = value
        end
    end
end

function addKnownCurrency(data, currencies, key, aliases)
    local value = getAnyNumberFromData(data, aliases or { key })
    if tonumber(value) and tonumber(value) ~= 0 then
        currencies[key] = value
    end
end

function getInventoryItemAmountByName(itemName, className)
    local data = getData()
    if not data or not itemUtils then return 0 end
    local ok, itemObject = pcall(function()
        if className and itemUtils.getItemFromNameAndClass then
            return itemUtils.getItemFromNameAndClass(data, itemName, className)
        end
        if itemUtils.getItemFromName then
            return itemUtils.getItemFromName(data, itemName)
        end
    end)
    if ok and itemObject and itemObject.getAmount then
        local okAmount, amount = pcall(function() return itemObject:getAmount() end)
        if okAmount and tonumber(amount) then return tonumber(amount) end
    end
    return 0
end

function getUpgradeAmount(upgradeId)
    local data = getData() or {}
    local upgrades = data.upgrades or data.Upgrades or {}
    local value = upgrades[upgradeId]
    if type(value) == "number" then return value end
    if type(value) == "table" then
        return tonumber(value.amount or value.level or value.value or value.Amount or value.Level) or 0
    end
    return 0
end

function getRCUCurrencySnapshot()
    local data = getData() or {}
    local currencies = {}

    copyNumberCurrencies(data.currencies, currencies)
    addKnownCurrency(data, currencies, "clicks", { "clicks", "Clicks" })
    addKnownCurrency(data, currencies, "gems", { "gems", "Gems" })
    addKnownCurrency(data, currencies, "rebirths", { "rebirths", "Rebirths" })
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 2959-2960)
    addKnownCurrency(data, currencies, "spaceCoins", { "spaceCoins", "SpaceCoins" })
    addKnownCurrency(data, currencies, "honey", { "honey", "Honey" })
    addKnownCurrency(data, currencies, "fishCoins", { "fishCoins", "FishingCoins", "fishingCoins" })
    addKnownCurrency(data, currencies, "compasses", { "compasses", "Compasses" })

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 2965-2967)

    return {
        Clicks = getCurrency(data, "clicks"),
        Gems = getCurrency(data, "gems"),
        Rebirths = tonumber(data.rebirths or (data.stats and data.stats.rebirths)) or 0,
        World = tostring(data.mapId or data.currentMap or "unknown"),
        Currencies = currencies,
    }
end

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 2978-2986)

function getRCUEventStatsSnapshot()
    local data = getData() or {}
    local season = getCurrentSeasonNumber()
    local level = getCurrentSeasonPassLevel(data)
    local xp = tonumber(data[getSeasonDataKey("PassXp")]) or 0
    local restarts = tonumber(data[getSeasonDataKey("PassRestarts")]) or 0
    local premium = data[getSeasonDataKey("PassPremium")] == true
    local claimedRewards = countSeasonClaimedRewards(data)
    local seasonTierIds = getSortedSeasonTierIds()
    local totalRewards = #seasonTierIds * (premium and 2 or 1)

    if webhookStats.EventStartSeasonXp == nil then
        webhookStats.EventStartSeasonXp = xp
    end

    return {
        EventName = "Season " .. tostring(season),
        EventCurrencyName = "Season XP",
        Season = season,
        SeasonXp = xp,
        SeasonXpThisSession = math.max(0, xp - (tonumber(webhookStats.EventStartSeasonXp) or 0)),
        SeasonLevel = level,
        SeasonRestarts = restarts,
        SeasonPremium = premium,
        ClaimedRewards = claimedRewards,
        TotalRewards = totalRewards,
        EventEggsOpened = tonumber(webhookStats.EventEggsOpened) or 0,
        EventPetsHatched = tonumber(webhookStats.EventPetsHatched) or 0,
        EventDrops = tonumber(webhookStats.EventDrops) or 0,
        GoodDrops = (tonumber(webhookStats.GoodPets) or 0) + (tonumber(webhookStats.GoodItems) or 0),
    }
end

function buildCurrencyLines(currencies, maxLines)
    local lines = {}
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3023-3024)
    local priority = { "clicks", "rebirths", "gems", "spaceCoins", "honey", "fishCoins", "compasses" }
    local used = {}
    maxLines = maxLines or 8

    for _, key in ipairs(priority) do
        local value = currencies and currencies[key]
        if tonumber(value) and tonumber(value) ~= 0 and #lines < maxLines then
            used[key] = true
            table.insert(lines, tostring(key:gsub("^%l", string.upper)) .. ": " .. formatWebhookNumber(value))
        end
    end

    if type(currencies) == "table" then
        for key, value in pairs(currencies) do
            if not used[key] and tonumber(value) and tonumber(value) ~= 0 and #lines < maxLines then
                table.insert(lines, tostring(key) .. ": " .. formatWebhookNumber(value))
            end
        end
    end

    if #lines == 0 then table.insert(lines, "None detected") end
    return lines
end

function buildSessionPetLines()
    local lines = {}
    local aggregated = {}

    if type(webhookStats.HatchedPets) == "table" then
        for _, entry in ipairs(webhookStats.HatchedPets) do
            local name = tostring(entry.Name or "Unknown")
            local rarity = tostring(entry.Rarity or "?")
            local key = name .. "|" .. rarity
            local amount = tonumber(entry.Amount) or 1
            if not aggregated[key] then
                aggregated[key] = { Name = name, Rarity = rarity, Amount = 0 }
            end
            aggregated[key].Amount = aggregated[key].Amount + amount
        end
    end

    local sorted = {}
    for _, entry in pairs(aggregated) do
        table.insert(sorted, entry)
    end
    table.sort(sorted, function(a, b)
        local ar = getRarityRankFromName(a.Rarity)
        local br = getRarityRankFromName(b.Rarity)
        if ar == br then return tostring(a.Name) < tostring(b.Name) end
        return ar > br
    end)

    local hidden = 0
    for i, entry in ipairs(sorted) do
        if i <= 6 then
            table.insert(lines, tostring(entry.Name) .. " [" .. tostring(entry.Rarity) .. "] x" .. tostring(entry.Amount or 1))
        else
            hidden = hidden + 1
        end
    end
    if hidden > 0 then table.insert(lines, "+" .. tostring(hidden) .. " more") end
    if #lines == 0 then table.insert(lines, "None yet") end
    return lines
end

function buildRarityCountLine()
    local parts = {}
    if type(webhookStats.SessionPetRarityCounts) == "table" then
        for rarity, amount in pairs(webhookStats.SessionPetRarityCounts) do
            table.insert(parts, tostring(rarity) .. ": " .. tostring(amount))
            if #parts >= 6 then break end
        end
    end
    if #parts == 0 then return "None yet" end
    return table.concat(parts, " | ")
end

function buildRCUSummaryFields()
    local currency = getRCUCurrencySnapshot()
    local eventStats = getRCUEventStatsSnapshot()
    local currencyLines = buildCurrencyLines(currency.Currencies, 8)
    local eventLines = {
        "Event: " .. tostring(eventStats.EventName),
        "Season XP: " .. formatWebhookNumber(eventStats.SeasonXp),
        "Season XP gained: " .. formatWebhookNumber(eventStats.SeasonXpThisSession),
        "Level: " .. tostring(eventStats.SeasonLevel or 0),
        "Restarts: " .. tostring(eventStats.SeasonRestarts or 0),
        "Claimed rewards: " .. tostring(eventStats.ClaimedRewards or 0) .. "/" .. tostring(eventStats.TotalRewards or 0),
        "Good drops: " .. tostring(eventStats.GoodDrops or eventStats.EventDrops or 0),
    }

    return {
        { Name = "Current Progress", Value = table.concat(currencyLines, "\n"), Inline = true },
        { Name = "Session", Value = "Session time: " .. getSessionDurationText() .. "\nEggs opened: " .. tostring(webhookStats.EggsOpened or webhookStats.Hatches or 0) .. "\nPets hatched: " .. tostring(webhookStats.PetsHatched or webhookStats.Hatches or 0) .. "\nGood pets: " .. tostring(webhookStats.GoodPets or webhookStats.RarePets or 0) .. "\nGood items: " .. tostring(webhookStats.GoodItems or webhookStats.RareItems or 0), Inline = true },
        { Name = "New Pets Hatched", Value = table.concat(buildSessionPetLines(), "\n"), Inline = false },
        { Name = "Pet Rarities", Value = buildRarityCountLine(), Inline = false },
        { Name = "Current Event", Value = table.concat(eventLines, "\n"), Inline = false },
        { Name = "Recent Events", Value = #webhookStats.LastEvents > 0 and table.concat(webhookStats.LastEvents, "\n") or "None yet", Inline = false },
    }
end

function shouldSendRCUWebhookEvent(eventType)
    if not hasWebhookUrl() then return false end
    if eventType == "rcu_daily_summary" then return Library.Flags.RCUWebhookDailySummary ~= false end
    if eventType == "rcu_super_rare_pet" then return true end
    if eventType == "rcu_rare_item" then return true end
    if eventType == "rcu_normal_drop" then return true end
    if eventType == "rcu_egg_info" then return true end
    return false
end

function usesRCUBackendArt(eventType, force)
    local backendEvents = {
        rcu_daily_summary = true,
        rcu_super_rare_pet = true,
        rcu_rare_item = true,
    }
    if not backendEvents[tostring(eventType or "")] then return false end
    if force == true then return true end
    if Library.Flags.RCUWebhookBackendArt == false then return false end
    return true
end

function webhookEventIcon(eventType)
    if eventType == "rcu_super_rare_pet" then return "✨" end
    if eventType == "rcu_rare_item" then return "💎" end
    if eventType == "rcu_daily_summary" then return "📊" end
    if eventType == "rcu_egg_info" then return "🥚" end
    return "🌌"
end

function buildRCUBackendWebhookBody(webhookUrl, eventType, title, fields, extra, force)
    local currency = getRCUCurrencySnapshot()
    local eventStats = getRCUEventStatsSnapshot()
    local body = {
        WebhookUrl = webhookUrl,
        Event = eventType or "rcu_event",
        Title = title or "RCU Update",
        Game = "Rebirth Champions: Ultimate",
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        User = {
            Username = client.Name,
            DisplayName = client.DisplayName,
            UserId = client.UserId,
        },
        Fields = fields or {},
        EventStats = eventStats,
        Stats = {
            Version = RCU_WEBHOOK_VERSION,
            Runtime = getSessionDurationText(),
            SessionTime = getSessionDurationText(),
            SessionStarted = webhookStats.SessionStarted,
            Clicks = currency.Clicks,
            Gems = currency.Gems,
            Rebirths = currency.Rebirths,
            World = currency.World,
            Currencies = eventType == "rcu_daily_summary" and currency.Currencies or nil,
            EggsOpened = webhookStats.EggsOpened or webhookStats.Hatches or 0,
            PetsHatched = webhookStats.PetsHatched or webhookStats.Hatches or 0,
            NewPetsHatched = webhookStats.HatchedPets,
            PetRarities = webhookStats.SessionPetRarityCounts,
            GoodPets = webhookStats.GoodPets or webhookStats.RarePets,
            GoodItems = webhookStats.GoodItems or webhookStats.RareItems,
            RarePets = webhookStats.GoodPets or webhookStats.RarePets,
            RareItems = webhookStats.GoodItems or webhookStats.RareItems,
            TreesFarmed = webhookStats.TreesFarmed,
            OresMined = webhookStats.OresMined,
            EventStats = eventStats,
            LastEvents = webhookStats.LastEvents,
        },
        Art = {
            Enabled = true,
            Theme = "enchanted_rebirth",
            Template = "enchanted",
            Title = title or "Enchanted RCU Drop",
            Subtitle = "Rebirth Champions: Ultimate enchanted webhook card",
            Footer = "VERSUS AIRLINES • RCU Enchanted Report",
            AccentColor = trimString(Library.Flags.RCUWebhookAccentColor or "#B66DFF"),
            SecondaryColor = trimString(Library.Flags.RCUWebhookSecondaryColor or "#EEDCFF"),
            ShowAvatar = Library.Flags.RCUWebhookShowAvatar ~= false,
            TemplateName = "dev_cammy enchanted RCU",
        },
        Extra = extra or {},
        WebhookFilters = {
            ExcludedItemRarities = getWebhookExcludedRarityList("RCUWebhookExcludedItemRarities"),
            ExcludedPetRarities = getWebhookExcludedRarityList("RCUWebhookExcludedPetRarities"),
        },
        BackendTest = force == true,
        Timestamp = os.time(),
    }

    if type(extra) == "table" then
        if type(extra.Art) == "table" then
            for key, value in pairs(extra.Art) do body.Art[key] = value end
        end
        if type(extra.Stats) == "table" then
            for key, value in pairs(extra.Stats) do body.Stats[key] = value end
        end
        if type(extra.EventStats) == "table" then
            body.EventStats = extra.EventStats
            body.Stats.EventStats = extra.EventStats
        end
        if type(extra.Description) == "string" then body.Description = extra.Description end
        if extra.Icon then body.Icon = extra.Icon end
    end

    return body
end

function buildRCUDirectDiscordWebhookBody(eventType, title, fields, extra)
    local embedFields = {
        {
            name = "Player",
            value = "Username: " .. discordText(client.Name, 80) .. "\nDisplay: " .. discordText(client.DisplayName, 80) .. "\nUserId: " .. tostring(client.UserId),
            inline = true,
        },
        {
            name = "Server",
            value = "PlaceId: " .. tostring(game.PlaceId) .. "\nJobId: " .. discordText(game.JobId, 80),
            inline = true,
        },
    }

    for _, field in ipairs(fields or {}) do
        if #embedFields >= 12 then break end
        table.insert(embedFields, {
            name = discordText(field.Name or field.name or "Update", 256),
            value = discordText(field.Value or field.value or "None", 900),
            inline = field.Inline == true or field.inline == true,
        })
    end

    local icon = type(extra) == "table" and (extra.Icon or (type(extra.Drop) == "table" and extra.Drop.Icon) or (type(extra.Art) == "table" and extra.Art.Icon)) or nil
    local thumbnailUrl = iconToDiscordThumbnailUrl(icon)
    local embed = {
        title = webhookEventIcon(eventType) .. " RCU • " .. discordText(title or "Game Update", 180),
        description = type(extra) == "table" and extra.Description and discordText(extra.Description, 350) or nil,
        color = discordColorFromHex("#B66DFF"),
        fields = embedFields,
        footer = { text = "VERSUS AIRLINES • RCU" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    if thumbnailUrl then
        embed.thumbnail = { url = thumbnailUrl }
    end

    return {
        username = discordText(Library.Flags.RCUWebhookBotUsername or "Versus Airlines", 80),
        embeds = { embed },
        allowed_mentions = { parse = {} },
    }
end

function sendRCUWebhook(eventType, title, fields, extra, force)
    local webhookUrl = getWebhookUrl()
    if not webhookUrl then
        if force then notify("Webhook Missing", "Paste a Discord webhook URL first.", "warning") end
        return false
    end
    if not force and not shouldSendRCUWebhookEvent(eventType) then return false end
    if not request then
        if force then notify("Webhook Unsupported", "Your executor does not expose an HTTP request function.", "warning") end
        return false
    end

    local throttleKey = tostring(eventType or "event") .. ":" .. tostring(title or "")
    local current = os.clock()
    if not force and lastWebhookSend[throttleKey] and current - lastWebhookSend[throttleKey] < 1.25 then
        return false
    end
    lastWebhookSend[throttleKey] = current

    local useBackend = usesRCUBackendArt(eventType, force)
    local targetUrl = useBackend and WEBHOOK_BACKEND_URL or webhookUrl
    local body = useBackend
        and buildRCUBackendWebhookBody(webhookUrl, eventType, title, fields, extra, force)
        or buildRCUDirectDiscordWebhookBody(eventType, title, fields, extra)

    task.spawn(function()
        pcall(function()
            request({
                Url = targetUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = useBackend and "VersusAirlines-RCU-BackendArt" or "VersusAirlines-RCU-DirectWebhook",
                },
                Body = HttpService:JSONEncode(body),
            })
        end)
    end)

    return true
end

function getRarityRankFromName(rarityName)
    local order = {
        common = 1,
        uncommon = 2,
        rare = 3,
        epic = 4,
        event = 4,
        legendary = 5,
        mythical = 6,
        eternal = 7,
        mysterious = 8,
        global = 9,
        exclusive = 10,
        secret = 11,
        divine = 12,
        supreme = 13,
        ultimate = 14,
        permanent = 14,
        temporary = 2,
    }
    return order[tostring(rarityName or ""):lower()] or 0
end

WEBHOOK_RARITY_OPTIONS = WEBHOOK_RARITY_OPTIONS or {
    "Common", "Uncommon", "Rare", "Epic", "Event", "Legendary", "Mythical", "Eternal", "Mysterious", "Global", "Exclusive", "Secret", "Divine", "Supreme", "Ultimate", "Permanent", "Temporary",
}
WEBHOOK_DEFAULT_EXCLUDED_RARITIES = WEBHOOK_DEFAULT_EXCLUDED_RARITIES or { "Common", "Uncommon", "Rare" }

function normalizeWebhookRarityName(value)
    return tostring(value or ""):lower():gsub("[^%w]+", "")
end

function readSelectedDropdownValues(selected)
    local out = {}

    if type(selected) == "table" then
        if selected[1] ~= nil then
            for _, value in ipairs(selected) do
                table.insert(out, value)
            end
        else
            for key, value in pairs(selected) do
                if value == true then
                    table.insert(out, key)
                elseif type(value) == "string" or type(value) == "number" then
                    table.insert(out, value)
                end
            end
        end
    elseif selected ~= nil then
        table.insert(out, selected)
    end

    return out
end

function getFirstSelectedDropdownValue(selected, fallback)
    local values = readSelectedDropdownValues(selected)
    return values[1] or fallback
end

function getWebhookExcludedRaritySet(flagName)
    local set = {}

    for _, rarity in ipairs(readSelectedDropdownValues(Library.Flags[flagName])) do
        local key = normalizeWebhookRarityName(rarity)
        if key ~= "" then set[key] = true end
    end

    return set
end

function getWebhookExcludedRarityList(flagName)
    local out = {}
    local seen = {}

    for _, rarity in ipairs(readSelectedDropdownValues(Library.Flags[flagName])) do
        local text = tostring(rarity or "")
        local key = normalizeWebhookRarityName(text)
        if key ~= "" and not seen[key] then
            seen[key] = true
            table.insert(out, text)
        end
    end

    return out
end

function isWebhookDropRarityExcluded(info, isPet, force)
    if force == true or type(info) ~= "table" then return false end
    local rarityKey = normalizeWebhookRarityName(info.Rarity)
    if rarityKey == "" then return false end

    local flagName = isPet and "RCUWebhookExcludedPetRarities" or "RCUWebhookExcludedItemRarities"
    local excluded = getWebhookExcludedRaritySet(flagName)
    return excluded[rarityKey] == true
end

function normalizeIconValue(icon)
    if icon == nil then return nil end
    local value = tostring(icon)
    if value == "" or value == "0" or value == "nil" or value == "None" then return nil end
    return value
end

function robloxAssetIdFromIcon(icon)
    local value = tostring(icon or "")
    if value == "" then return nil end
    local direct = value:match("^rbxassetid://(%d+)$")
    if direct then return direct end
    local query = value:match("[?&]id=(%d+)") or value:match("[?&]assetId=(%d+)")
    if query then return query end
    local catalog = value:match("roblox%.com/.*/(%d+)")
    if catalog then return catalog end
    if value:match("^%d%d%d%d%d+$") then return value end
    return nil
end

function iconToDiscordThumbnailUrl(icon)
    local value = normalizeIconValue(icon)
    if not value then return nil end
    if value:match("^https://") then return value end

    local assetId = robloxAssetIdFromIcon(value)
    if assetId then
        return "https://www.roblox.com/asset-thumbnail/image?assetId=" .. tostring(assetId) .. "&width=420&height=420&format=png"
    end

    return nil
end

function readDirectoryValue(itemObject, key)
    local value
    pcall(function()
        local directory = itemObject:directory()
        local name = itemObject:getName()
        local entry = directory and directory[name]
        if type(entry) == "table" then
            value = entry[key]
        end
    end)
    return value
end

function getBestIconFromItemObject(itemObject)
    local icon
    pcall(function() icon = itemObject:getIcon() end)
    if not icon then pcall(function() if itemObject.getImage then icon = itemObject:getImage() end end) end
    if not icon then icon = readDirectoryValue(itemObject, "icon") end
    if not icon then icon = readDirectoryValue(itemObject, "image") end

    if not icon then
        local images = readDirectoryValue(itemObject, "images")
        if type(images) == "table" then
            local tier = 1
            pcall(function() tier = tonumber(itemObject:getTier()) or 1 end)
            icon = images[tier] or images[1] or firstValue(images)
        end
    end

    if not icon then
        local evolutionImages = readDirectoryValue(itemObject, "evolutionImages")
        if type(evolutionImages) == "table" then
            local evolution
            pcall(function() evolution = itemObject:getEvolution() end)
            icon = evolutionImages[evolution] or firstValue(evolutionImages)
        end
    end

    return normalizeIconValue(icon)
end

function getItemWebhookInfo(itemObject, amount)
    if not itemObject then return nil end
    local info = { Amount = tonumber(amount) or 1 }

    pcall(function() info.Class = itemObject:getClass() end)
    pcall(function() info.Name = itemObject:getName() end)
    pcall(function()
        if itemObject.getRealName then
            local realName = itemObject:getRealName()
            if realName and tostring(realName) ~= "" then
                info.DisplayName = tostring(realName)
            end
        end
    end)
    pcall(function() info.Rarity = itemObject:getRarity() end)
    pcall(function() info.Description = itemObject:getDescription() end)
    pcall(function() info.Icon = getBestIconFromItemObject(itemObject) end)

    local classLower = tostring(info.Class or ""):lower()
    if classLower == "pet" then
        pcall(function() info.Multiplier = itemObject:getMultiplier(getData(), { ignoreServer = true }) end)
        pcall(function() info.Power = itemObject:getMultiplier(getData(), { ignoreServer = true }) end)
        pcall(function() info.Tier = itemObject:getTier() end)
        pcall(function() if itemObject.isShiny and itemObject:isShiny() then info.Mutation = "Shiny" end end)
        pcall(function() if itemObject.getEvolution then info.Evolution = itemObject:getEvolution() end end)
        pcall(function() if itemObject.getSpecialPercentage then info.Special = itemObject:getSpecialPercentage(getData()) end end)
    else
        pcall(function() info.Effect = info.Description or itemObject:getDescription() end)
        pcall(function() info.Tier = readDirectoryValue(itemObject, "tier") end)
        pcall(function() info.Value = readDirectoryValue(itemObject, "value") end)
        pcall(function() info.Duration = readDirectoryValue(itemObject, "duration") end)
    end

    info.Class = tostring(info.Class or "item")
    info.Name = tostring(info.DisplayName or info.Name or "Unknown")
    info.Rarity = tostring(info.Rarity or "Unknown")
    info.RarityRank = getRarityRankFromName(info.Rarity)
    info.Icon = normalizeIconValue(info.Icon)
    info.Description = compactWebhookText(info.Description or "", 180)
    return info
end

function getItemWebhookInfoFromId(itemId, amount)
    local data = getData()
    if not data or not itemUtils or not itemUtils.getItemFromId then return nil end
    local ok, itemObject = pcall(function()
        return itemUtils.getItemFromId(data, itemId)
    end)
    if not ok or not itemObject then return nil end
    local info = getItemWebhookInfo(itemObject, amount)
    if info then info.ItemId = itemId end
    return info
end

function rememberHatchedPet(info)
    if type(info) ~= "table" then return end
    webhookStats.SessionPetCounts = webhookStats.SessionPetCounts or {}
    webhookStats.SessionPetRarityCounts = webhookStats.SessionPetRarityCounts or {}
    webhookStats.HatchedPets = webhookStats.HatchedPets or {}

    local key = tostring(info.Name or "Unknown") .. "|" .. tostring(info.Rarity or "Unknown")
    webhookStats.SessionPetCounts[key] = (tonumber(webhookStats.SessionPetCounts[key]) or 0) + (tonumber(info.Amount) or 1)
    webhookStats.SessionPetRarityCounts[tostring(info.Rarity or "Unknown")] = (tonumber(webhookStats.SessionPetRarityCounts[tostring(info.Rarity or "Unknown")]) or 0) + (tonumber(info.Amount) or 1)

    table.insert(webhookStats.HatchedPets, 1, {
        Name = tostring(info.Name or "Unknown"),
        Rarity = tostring(info.Rarity or "Unknown"),
        Amount = tonumber(info.Amount) or 1,
        Egg = info.Egg,
        Icon = info.Icon,
    })
    while #webhookStats.HatchedPets > 15 do
        table.remove(webhookStats.HatchedPets)
    end
end

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3570-3574)

function buildDropStats(info, source)
    return {
        DropName = info.Name,
        DropClass = info.Class,
        Rarity = info.Rarity,
        RarityRank = info.RarityRank,
        Source = source,
        Egg = info.Egg,
        ItemId = info.ItemId,
        Icon = info.Icon,
        Description = info.Description,
        Multiplier = info.Multiplier,
        Power = info.Power,
        Damage = info.Damage,
        Tier = info.Tier,
        Mutation = info.Mutation,
        Evolution = info.Evolution,
        Special = info.Special,
        Effect = info.Effect,
        Value = info.Value,
        Duration = info.Duration,
        Chance = info.Chance,
    }
end

function normalizeWebhookDropKey(value)
    return tostring(value or ""):lower():gsub("[^%w]+", "")
end

function isCurrencyLikeWebhookDrop(info)
    if type(info) ~= "table" then return false end

    local classLower = tostring(info.Class or ""):lower()
    if classLower == "pet" then return false end
    if classLower == "currency" or classLower:find("currency", 1, true) then return true end

    local exactCurrencyNames = {
        clicks = true, click = true,
        gems = true, gem = true,
        rebirths = true, rebirth = true,
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3616-3617)
        coins = true, coin = true,
        spacecoins = true, spacecoin = true,
        fishcoins = true, fishcoin = true, fishingcoins = true, fishingcoin = true,
        dungeoncoins = true, dungeoncoin = true,
        spacestones = true, spacestone = true,
        snowflakes = true, snowflake = true,
        honey = true,
        ancientticket = true, dungeonticket = true, circusticket = true, frozenticket = true,
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3626-3627)
        mysticshard = true, shard = true, shards = true,
    }

    local candidates = { info.Name, info.DisplayName, info.ItemId, info.Description, info.Effect }
    for _, value in pairs(candidates) do
        local key = normalizeWebhookDropKey(value)
        if exactCurrencyNames[key] then return true end
        if key ~= "" and (
            key:find("currency", 1, true) or
            key:find("ticket", 1, true) or
            key:find("token", 1, true) or
            key:find("coin", 1, true) or
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3640-3641)
            key:find("snowflake", 1, true) or
            key:find("spacestone", 1, true) or
            key:find("dungeoncoin", 1, true) or
            key:find("mysticshard", 1, true)
        ) then
            return true
        end
    end

    return false
end

function isOreLikeWebhookDrop(info, source)
    if type(info) ~= "table" then return false end
    local classLower = tostring(info.Class or ""):lower()
    local sourceLower = tostring(source or ""):lower()
    local nameKey = normalizeWebhookDropKey(info.Name or info.DisplayName or info.ItemId)
    local descKey = normalizeWebhookDropKey(info.Description or info.Effect)

    if classLower == "pet" then return false end
    if classLower == "ore" or classLower:find("ore", 1, true) then return true end
    if sourceLower:find("ore", 1, true) or sourceLower:find("mining", 1, true) or sourceLower:find("mine", 1, true) then
        if nameKey:find("ore", 1, true) or descKey:find("ore", 1, true) then return true end
    end
    if nameKey:find("ore", 1, true) and (
        nameKey:find("iron", 1, true) or nameKey:find("gold", 1, true) or nameKey:find("ruby", 1, true) or
        nameKey:find("emerald", 1, true) or nameKey:find("sapphire", 1, true) or nameKey:find("diamond", 1, true) or
        nameKey:find("titanium", 1, true) or nameKey:find("uranium", 1, true)
    ) then
        return true
    end

    return false
end

function sendRareDropWebhook(info, source, force)
    if type(info) ~= "table" then return false end

    local classLower = tostring(info.Class or ""):lower()
    local isPet = classLower == "pet"
    if not isPet and (isCurrencyLikeWebhookDrop(info) or isOreLikeWebhookDrop(info, source)) then return false end
    if isWebhookDropRarityExcluded(info, isPet, force) then return false end

    local rarityRank = tonumber(info.RarityRank) or getRarityRankFromName(info.Rarity)
    local imageCard = force == true or rarityRank >= 5 -- Legendary and above get backend image cards. Common/Uncommon/Rare/Epic stay normal embeds.

    if imageCard then
        if isPet then
            incrementWebhookStat("GoodPets", tonumber(info.Amount) or 1)
            webhookStats.RarePets = webhookStats.GoodPets
        else
            incrementWebhookStat("GoodItems", tonumber(info.Amount) or 1)
            webhookStats.RareItems = webhookStats.GoodItems
        end
    end

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3698-3701)

    addWebhookRecentEvent((isPet and "Pet" or "Item") .. ": " .. tostring(info.Name) .. " [" .. tostring(info.Rarity) .. "]")

    local eventType = imageCard and (isPet and "rcu_super_rare_pet" or "rcu_rare_item") or "rcu_normal_drop"
    local fields = {
        { Name = isPet and "Pet" or "Item", Value = tostring(info.Name), Inline = true },
        { Name = "Rarity", Value = tostring(info.Rarity), Inline = true },
        { Name = "Source", Value = tostring(source or "Unknown"), Inline = false },
    }

    if info.Description and info.Description ~= "" then
        table.insert(fields, { Name = "Description", Value = tostring(info.Description), Inline = false })
    end
    if info.Egg then table.insert(fields, { Name = "Egg", Value = tostring(info.Egg), Inline = true }) end
    if info.ItemId then table.insert(fields, { Name = "Item Id", Value = tostring(info.ItemId), Inline = true }) end

    local titlePrefix = imageCard and (isPet and "Good Pet" or "Good Item") or (isPet and "Pet Hatch" or "Item Drop")
    return sendRCUWebhook(eventType, titlePrefix .. " • " .. tostring(info.Name), fields, {
        Description = tostring(info.Description ~= "" and info.Description or (imageCard and "An enchanted drop was detected by the RCU script." or "A drop was detected by the RCU script.")),
        Icon = info.Icon,
        Drop = {
            Name = info.Name,
            Class = info.Class,
            Rarity = info.Rarity,
            Source = source,
            Icon = info.Icon,
            Description = info.Description,
        },
        DropStats = buildDropStats(info, source),
        Stats = buildDropStats(info, source),
        Art = {
            Title = tostring(info.Name),
            Subtitle = tostring(info.Rarity) .. " " .. (isPet and "pet hatch" or "item drop"),
            Description = tostring(info.Description or ""),
            Template = "enchanted",
            Icon = info.Icon,
        },
    }, force)
end

function processHatchedPetWebhooks(eggName, pets)
    if type(pets) ~= "table" then return end

    local hatchCount = math.max(1, #pets)
    incrementWebhookStat("Hatches", hatchCount)
    incrementWebhookStat("EggsOpened", hatchCount)
    incrementWebhookStat("PetsHatched", #pets)
    webhookStats.Hatches = webhookStats.PetsHatched

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 3751-3755)

    for _, petData in ipairs(pets) do
        local itemObject
        if itemUtils and itemUtils.createItemFromData then
            local ok, result = pcall(function()
                return itemUtils.createItemFromData(petData)
            end)
            if ok then itemObject = result end
        end
        local info = getItemWebhookInfo(itemObject, 1)
        if info then
            info.Egg = eggName
            rememberHatchedPet(info)
            sendRareDropWebhook(info, "Egg: " .. tostring(eggName), false)
        end
    end
end

function hookRarePetWebhooks(enabled)
    Library:CleanupConnectionsByTag("RCU_WebhookRarePets")
    if not enabled then return end
    if not EggService or not EggService.openEgg or not EggService.openEgg.Connect then
        notify("Webhook Hook Missing", "EggService.openEgg was not available yet. Re-toggle rare pet webhooks after loading.", "warning")
        return
    end

    local conn = EggService.openEgg:Connect(function(eggName, pets)
        if Library.Flags.RCUWebhookRarePets or Library.Flags.RCUWebhookNormalDrops or Library.Flags.RCUWebhookDailySummary then
            processHatchedPetWebhooks(eggName, pets)
        end
    end)
    Library:TrackConnection(conn, "RCU_WebhookRarePets")
end

function hookRareItemWebhooks(enabled)
    Library:CleanupConnectionsByTag("RCU_WebhookRareItems")
    if not ItemController then return end
    if not ItemController._RCUOriginalDisplayNewItem then
        ItemController._RCUOriginalDisplayNewItem = ItemController.displayNewItem
    end

    if not enabled then
        ItemController.displayNewItem = ItemController._RCUOriginalDisplayNewItem
        return
    end

    ItemController.displayNewItem = function(self, itemId, amount, options)
        local result
        if ItemController._RCUOriginalDisplayNewItem then
            result = ItemController._RCUOriginalDisplayNewItem(self, itemId, amount, options)
        end
        if Library.Flags.RCUWebhookRareItems or Library.Flags.RCUWebhookNormalDrops or Library.Flags.RCUWebhookDailySummary then
            local info = getItemWebhookInfoFromId(itemId, amount)
            if info then sendRareDropWebhook(info, "New item popup", false) end
        end
        return result
    end
end


function refreshRCUWebhookTrackingHooks()
    local shouldTrack = hasWebhookUrl() or Library.Flags.RCUWebhookDailySummary ~= false
    hookRarePetWebhooks(shouldTrack)
    hookRareItemWebhooks(shouldTrack)
end

function setupRCUDailySummaryInterval(enabled)
    Library:CleanupConnectionsByTag("RCU_WebhookDailySummaryInterval")
    refreshRCUWebhookTrackingHooks()
    if not enabled then return end
    local minutes = tonumber(Library.Flags.RCUWebhookDailySummaryMinutes) or 30
    minutes = math.clamp(minutes, 5, 120)
    interval("RCU_WebhookDailySummaryInterval", "RCUWebhookDailySummary", minutes * 60, function()
        sendRCUDailySummaryWebhook(false)
    end)
end

function sendRCUDailySummaryWebhook(force)
    local eventStats = getRCUEventStatsSnapshot()
    return sendRCUWebhook("rcu_daily_summary", "RCU Daily Summary", buildRCUSummaryFields(), {
        Description = "Current Rebirth Champions: Ultimate session summary.",
        EventStats = eventStats,
        Art = {
            Title = "RCU Session Summary",
            Subtitle = "Enchanted farming progress report",
            Template = "enchanted",
        },
    }, force == true)
end

function formatEggChance(value)
    local n = tonumber(value)
    if not n then return tostring(value or "?") end
    if n < 0.001 then return string.format("%.9f%%", n):gsub("0+$", ""):gsub("%.$", "") end
    if n < 1 then return string.format("%.6f%%", n):gsub("0+$", ""):gsub("%.$", "") end
    if n < 10 then return string.format("%.3f%%", n):gsub("0+$", ""):gsub("%.$", "") end
    return string.format("%.2f%%", n):gsub("%.00", "")
end


function formatEggPlainNumber(value)
    local n = tonumber(value)
    if not n then return tostring(value or "?") end
    if math.abs(n) >= 1000 then return formatWebhookNumber(n) end
    if math.abs(n) < 1 then return string.format("%.4f", n):gsub("0+$", ""):gsub("%.$", "") end
    return string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
end

function formatEggAttributeValue(value)
    local valueType = typeof(value)
    if valueType == "Vector3" then
        return string.format("%.1f, %.1f, %.1f", value.X, value.Y, value.Z)
    elseif valueType == "CFrame" then
        local pos = value.Position
        return string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
    elseif valueType == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(value.R * 255), math.floor(value.G * 255), math.floor(value.B * 255))
    end
    return tostring(value)
end

function addClosestEggWebhookField(fields, name, value, inline)
    value = compactWebhookText(value or "", 900)
    if value == "" then return end
    table.insert(fields, {
        Name = tostring(name),
        Value = value,
        Inline = inline == true,
    })
end

function getShortInstancePath(instance)
    if typeof(instance) ~= "Instance" then return "unknown" end
    local names = {}
    local node = instance
    while node and node ~= Workspace and node ~= game do
        table.insert(names, 1, node.Name)
        node = node.Parent
        if #names >= 6 and node ~= Workspace then
            table.insert(names, 1, "...")
            break
        end
    end
    return "Workspace." .. table.concat(names, ".")
end

function getEggMapName(requiredMap)
    if not requiredMap then return "None" end
    local mapData = MapList and MapList[requiredMap]
    if type(mapData) == "table" then
        return tostring(mapData.name or mapData.displayName or requiredMap)
    end
    return tostring(requiredMap)
end

function readDescendantText(root, descendantName)
    if typeof(root) ~= "Instance" then return nil end
    local found = root:FindFirstChild(descendantName, true)
    if found and (found:IsA("TextLabel") or found:IsA("TextButton") or found:IsA("TextBox")) then
        local text = tostring(found.Text or "")
        if text ~= "" then return text end
    end
    return nil
end

function getEggModelAttributes(eggModel)
    local attributes = {}
    if typeof(eggModel) ~= "Instance" then return attributes end
    local ok, result = pcall(function()
        return eggModel:GetAttributes()
    end)
    if ok and type(result) == "table" then
        attributes = result
    end
    return attributes
end

function buildEggAttributeLines(eggModel, maxLines)
    local attributes = getEggModelAttributes(eggModel)
    local keys = {}
    for key, value in pairs(attributes) do
        if value ~= nil then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)

    local lines = {}
    local shown = 0
    for _, key in ipairs(keys) do
        shown = shown + 1
        if shown > (maxLines or 14) then break end
        table.insert(lines, tostring(key) .. ": " .. formatEggAttributeValue(attributes[key]))
    end

    if #keys > #lines then
        table.insert(lines, "+" .. tostring(#keys - #lines) .. " more attributes")
    end

    return lines, attributes
end

function buildEggOpenParamLinesFromAttributes(attributes)
    attributes = attributes or {}
    local mapping = {
        { "globalEggId", "Global egg id" },
        { "luckyEggHuntId", "Lucky egg hunt id" },
        { "isBestEgg", "Best egg override" },
        { "isMazeEgg", "Maze egg" },
        { "isBuildASnowman", "Build-a-snowman egg" },
        { "adminEggLuck", "Admin egg luck" },
        { "isRNGEgg", "RNG egg" },
        { "isGiantEgg", "Giant egg" },
        { "isBunnyCave", "Bunny cave egg" },
    }

    local lines = {}
    for _, item in ipairs(mapping) do
        local key, label = item[1], item[2]
        local value = attributes[key]
        if value ~= nil and value ~= false then
            table.insert(lines, label .. ": " .. formatEggAttributeValue(value))
        end
    end
    return lines
end

function getGlobalEggKnownVariantLines()
    local lines = {}
    for _, itemId in ipairs({ "globalLuckyEgg", "globalFriendsEgg" }) do
        local itemData = ExclusiveItemsList and ExclusiveItemsList[itemId]
        if type(itemData) == "table" then
            local name = tostring(itemData.name or itemId)
            local desc = tostring(itemData.description or "")
            if desc ~= "" then
                table.insert(lines, name .. ": " .. desc)
            else
                table.insert(lines, name)
            end
        end
    end
    return lines
end

function getGlobalEggLuckEstimateLine()
    if not Values or type(Values.globalLuckyEggLuck) ~= "function" then return nil end
    local data = getData()
    if not data then return nil end
    local ok, amount = pcall(function()
        return Values.globalLuckyEggLuck(client, data)
    end)
    if ok and tonumber(amount) then
        return "Estimated upgraded global lucky egg bonus: +" .. formatEggPlainNumber(tonumber(amount) * 100) .. "% Luck"
    end
    return nil
end

function buildGlobalEggInfoLines(eggModel, attributes)
    local lines = {}
    if typeof(eggModel) ~= "Instance" then return lines end

    local isGlobal = isGlobalLuckEggModel(eggModel)
    if not isGlobal then return lines end

    table.insert(lines, "Type: Global egg spawn")
    if attributes and attributes.globalEggId ~= nil then
        table.insert(lines, "Global egg id: " .. tostring(attributes.globalEggId))
    end

    local spawnedText = readDescendantText(eggModel, "Spawned")
    local luckText = readDescendantText(eggModel, "Luck")
    local timerText = readDescendantText(eggModel, "Timer")

    if spawnedText then table.insert(lines, spawnedText) end
    if luckText then table.insert(lines, "Displayed luck: " .. luckText:gsub("!$", "")) end
    if timerText then table.insert(lines, timerText) end

    local estimated = getGlobalEggLuckEstimateLine()
    if estimated and not luckText then table.insert(lines, estimated) end

    local id = attributes and attributes.globalEggId
    if id ~= nil and EggController and type(EggController._globalEggs) == "table" then
        table.insert(lines, "Local global spawn cache: " .. tostring(EggController._globalEggs[id] == true and "active" or "not cached"))
    end

    return lines
end

function getEggFlagSummary(attributes)
    attributes = attributes or {}
    local flags = {}
    local flagLabels = {
        isBestEgg = "Best Egg",
        isMazeEgg = "Maze",
        isBuildASnowman = "Build A Snowman",
        isRNGEgg = "RNG",
        isGiantEgg = "Giant",
        isBunnyCave = "Bunny Cave",
    }
    for key, label in pairs(flagLabels) do
        if attributes[key] then table.insert(flags, label) end
    end
    if attributes.globalEggId ~= nil then table.insert(flags, "Global") end
    if attributes.luckyEggHuntId ~= nil then table.insert(flags, "Lucky Egg Hunt") end
    if attributes.adminEggLuck ~= nil then table.insert(flags, "Admin Luck +" .. tostring(attributes.adminEggLuck)) end
    table.sort(flags)
    if #flags == 0 then return "Normal map egg" end
    return table.concat(flags, ", ")
end

function buildEggDataExtraLines(eggName, eggData, eggModel, attributes)
    local lines = {}
    local part = getEggPart(eggModel)

    table.insert(lines, "Flags: " .. getEggFlagSummary(attributes))
    table.insert(lines, "Path: " .. getShortInstancePath(eggModel))

    if part then
        table.insert(lines, "Position: " .. formatEggAttributeValue(part.Position))
    end

    if type(eggData) == "table" then
        table.insert(lines, "Required map: " .. getEggMapName(eggData.requiredMap))
        if eggData.requiredMap then
            table.insert(lines, "Map unlocked: " .. tostring(isMapUnlocked(eggData.requiredMap)))
        end
        if eggData.isAdmin ~= nil then table.insert(lines, "Admin egg: " .. tostring(eggData.isAdmin)) end
        if eggData.stock ~= nil then table.insert(lines, "Stock: " .. tostring(eggData.stock)) end
        if eggData.order ~= nil or eggData.layoutOrder ~= nil then table.insert(lines, "Order: " .. tostring(eggData.order or eggData.layoutOrder)) end
    end

    return lines
end

function buildEggPetSummaryLines(pets)
    local lines = {}
    if type(pets) ~= "table" or #pets == 0 then return lines end

    table.insert(lines, "Total hatchable pets: " .. tostring(#pets))

    local rarest = pets[1]
    if rarest then
        table.insert(lines, "Rarest/highest rarity shown: " .. rarest.Name .. " [" .. rarest.Rarity .. "] - " .. formatEggChance(rarest.Chance))
    end

    local bestPower
    for _, pet in ipairs(pets) do
        if tonumber(pet.Multiplier) and (not bestPower or tonumber(pet.Multiplier) > tonumber(bestPower.Multiplier)) then
            bestPower = pet
        end
    end
    if bestPower then
        table.insert(lines, "Highest listed power: " .. bestPower.Name .. " - " .. formatWebhookNumber(bestPower.Multiplier) .. "x")
    end

    return lines
end

function buildClosestEggInfoFields()
    local eggName, eggModel = getNearestEggName()
    local displayName = getEggDisplayName(eggName, eggModel)
    local eggData = eggName and EggsModule and EggsModule[eggName]
    local fields = {}

    if not eggName then
        return {
            { Name = "Closest Egg", Value = "No egg model was found near the player.", Inline = false },
        }, "Closest Egg Info"
    end

    local part = getEggPart(eggModel)
    local hrp = getHRP()
    local distanceText = "unknown"
    if part and hrp then distanceText = tostring(math.floor((part.Position - hrp.Position).Magnitude)) .. " studs" end

    local attributeLines, attributes = buildEggAttributeLines(eggModel, 14)
    local openParamLines = buildEggOpenParamLinesFromAttributes(attributes)
    local globalLines = buildGlobalEggInfoLines(eggModel, attributes)

    addClosestEggWebhookField(fields, "Closest Egg", "Name: " .. tostring(displayName) .. "\nId: " .. tostring(eggName) .. "\nDistance: " .. distanceText, false)
    addClosestEggWebhookField(fields, "Egg Source", table.concat(buildEggDataExtraLines(eggName, eggData, eggModel, attributes), "\n"), false)

    if #globalLines > 0 then
        addClosestEggWebhookField(fields, "Global Egg Info", table.concat(globalLines, "\n"), false)
        local knownVariants = getGlobalEggKnownVariantLines()
        if #knownVariants > 0 then
            addClosestEggWebhookField(fields, "Known Global Egg Variants", table.concat(knownVariants, "\n"), false)
        end
    end

    if #openParamLines > 0 then
        addClosestEggWebhookField(fields, "Hatch Open Params", table.concat(openParamLines, "\n"), false)
    end

    if #attributeLines > 0 then
        addClosestEggWebhookField(fields, "Model Attributes", table.concat(attributeLines, "\n"), false)
    end

    if type(eggData) == "table" then
        local cost = eggData.cost and formatWebhookNumber(eggData.cost) or "unknown"
        local currency = tostring(eggData.currency or "clicks")
        local costLines = {
            "Cost: " .. cost .. " " .. currency,
            "Currency: " .. currency,
        }
        if eggData.requiredMap then
            table.insert(costLines, "Required map: " .. getEggMapName(eggData.requiredMap))
        end
        if attributes.globalEggId ~= nil then
            table.insert(costLines, "Note: global eggs use this base egg with boosted luck.")
        end
        addClosestEggWebhookField(fields, "Egg Cost", table.concat(costLines, "\n"), true)

        local pets = {}
        for petName, chance in pairs(eggData.pets or {}) do
            local petData = PetsModule and PetsModule[petName] or {}
            table.insert(pets, {
                Name = tostring(petData.name or petName),
                Id = tostring(petName),
                Chance = chance,
                Rarity = tostring(petData.rarity or "Unknown"),
                Rank = getRarityRankFromName(petData.rarity),
                Multiplier = petData.multiplier,
            })
        end
        table.sort(pets, function(a, b)
            if a.Rank == b.Rank then
                return (tonumber(a.Chance) or math.huge) < (tonumber(b.Chance) or math.huge)
            end
            return a.Rank > b.Rank
        end)

        local petSummary = buildEggPetSummaryLines(pets)
        if #petSummary > 0 then
            addClosestEggWebhookField(fields, "Pet Summary", table.concat(petSummary, "\n"), false)
        end

        local lines = {}
        for _, pet in ipairs(pets) do
            local line = pet.Name .. " [" .. pet.Rarity .. "] - " .. formatEggChance(pet.Chance)
            if pet.Id and pet.Id ~= pet.Name then
                line = line .. " • id: " .. pet.Id
            end
            if tonumber(pet.Multiplier) then
                line = line .. " • " .. formatWebhookNumber(pet.Multiplier) .. "x"
            end
            table.insert(lines, line)
        end

        local chunk = {}
        local fieldIndex = 1
        for _, line in ipairs(lines) do
            table.insert(chunk, line)
            if #chunk >= 8 then
                addClosestEggWebhookField(fields, fieldIndex == 1 and "Hatchable Pets" or ("Hatchable Pets " .. tostring(fieldIndex)), table.concat(chunk, "\n"), false)
                chunk = {}
                fieldIndex = fieldIndex + 1
            end
        end
        if #chunk > 0 then
            addClosestEggWebhookField(fields, fieldIndex == 1 and "Hatchable Pets" or ("Hatchable Pets " .. tostring(fieldIndex)), table.concat(chunk, "\n"), false)
        end
    else
        addClosestEggWebhookField(fields, "Egg Data", "This closest egg was found in Workspace, but it was not present in Shared.List.Pets.Eggs. The model/attribute fields above are still shown so global or special egg spawns can be identified.", false)
    end

    return fields, "Closest Egg Info • " .. tostring(displayName)
end



----------------------------------------------------------------------
-- Sections / UI
----------------------------------------------------------------------



----------------------------------------------------------------------
-- Game teleport helpers
----------------------------------------------------------------------

function getTeleportFrameComponent()
    if TeleportFrameComponent ~= nil then return TeleportFrameComponent end
    local playerScripts = client:FindFirstChild("PlayerScripts")
    local module = findPath(playerScripts, { "Client", "Components", "UI", "Frames", "TeleportFrame" })
    TeleportFrameComponent = safeRequire(module, "Client.Components.UI.Frames.TeleportFrame")
    return TeleportFrameComponent
end

function getSpawnMapId()
    for mapId, mapData in pairs(MapList or {}) do
        if type(mapData) == "table" and tostring(mapData.name or ""):lower() == "spawn" then
            return mapId
        end
    end
    return 1
end

function getCurrentMapId()
    if MapController and MapController.getCurrentMap then
        local ok, mapId = pcall(function() return MapController:getCurrentMap(true) end)
        if ok and mapId ~= nil then return mapId end
    end
    local data = getData()
    if data and data.currentMap then return data.currentMap end
    return nil
end

function teleportToMapUsingGameController(mapId)
    mapId = tonumber(mapId) or mapId
    local mapData = MapList and MapList[mapId]
    if type(mapData) ~= "table" or typeof(mapData.cframe) ~= "CFrame" then return false end

    local teleportFrame = getTeleportFrameComponent()
    if teleportFrame and type(teleportFrame.teleportToPosition) == "function" then
        local ok = pcall(function()
            return teleportFrame:teleportToPosition(mapId, mapData.cframe)
        end)
        if ok then return true end
    end

    return false
end

function teleportToSpawnForQuest()
    local spawnMapId = getSpawnMapId()
    if tostring(getCurrentMapId() or "") == tostring(spawnMapId) then return true end

    if os.clock() - (QuestRuntimeState and QuestRuntimeState.lastSpawnTeleport or 0) < 18 then
        return false
    end

    QuestRuntimeState.lastSpawnTeleport = os.clock()
    return teleportToMapUsingGameController(spawnMapId)
end

----------------------------------------------------------------------
-- Quest automation helpers
----------------------------------------------------------------------

QuestListCache = QuestListCache or nil
QuestRuntimeState = QuestRuntimeState or {
    lastWallTouch = 0,
    lastQuestScan = 0,
    lastSpawnTeleport = 0,
}

function serviceCallSucceeded(result, err)
    if err ~= nil then return false end
    if result == nil then return true end
    if result == true or result == "success" then return true end
    if result == false then return false end
    if type(result) == "string" and result:lower():find("fail", 1, true) then return false end
    return true
end

function callFirstQuestMethod(service, methodNames, ...)
    for _, methodName in ipairs(methodNames or {}) do
        local result, err = safeServiceCall(service, methodName, ...)
        if serviceCallSucceeded(result, err) then
            return result, nil, methodName
        end
    end
    return nil, "missing_quest_method"
end

function getQuestType(quest)
    if type(quest) ~= "table" then return "" end
    return tostring(quest.quest or quest.type or quest.Type or quest.id or "")
end

function getQuestName(quest)
    if type(quest) ~= "table" then return nil end
    return quest.name or quest.Name or quest.target or quest.Target or quest.egg or quest.Egg or quest.item or quest.Item
end

function getQuestRequired(quest)
    if type(quest) ~= "table" then return 1 end
    local amount = quest.amount or quest.Amount or quest.required or quest.Required or quest.total or quest.Total
    if type(amount) == "table" then
        amount = amount[2] or amount[1]
    end
    return tonumber(amount) or 1
end

function getQuestProgress(container, questId, questData)
    if type(questData) == "table" then
        local direct = questData.progress or questData.Progress or questData.current or questData.Current or questData.amountDone or questData.AmountDone
        if tonumber(direct) then return tonumber(direct) end
    end
    if type(container) == "table" then
        local raw = container[questId] or container[tostring(questId)]
        if type(raw) == "number" then return raw end
        if type(raw) == "table" then
            return tonumber(raw.progress or raw.Progress or raw.current or raw.Current or raw.amountDone or raw.AmountDone) or 0
        end
    end
    return 0
end

function getCurrentMapQuest()
    local data = getData()
    if not data or type(data.maps) ~= "table" or type(MapList) ~= "table" then return nil end

    local nextMapId = #data.maps + 1
    local mapData = MapList[nextMapId]
    if not mapData or type(mapData.quests) ~= "table" then return nil, nil, mapData, nextMapId, false end
    if mapData.unlocksAt and os.time() < mapData.unlocksAt then return nil, nil, mapData, nextMapId, false end

    local allComplete = true
    for questId, quest in pairs(mapData.quests) do
        local progress = getQuestProgress(data.mapQuests, questId)
        if progress < getQuestRequired(quest) then
            allComplete = false
            return quest, questId, mapData, nextMapId, false, progress
        end
    end

    return nil, nil, mapData, nextMapId, allComplete
end

function findMapWallForMap(mapId)
    for _, wall in ipairs(CollectionService:GetTagged("MapWall")) do
        if wall:GetAttribute("mapId") == mapId then
            return wall
        end
    end

    -- Fallback for executors/games where CollectionService tags are late to replicate.
    local checked = 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        checked = checked + 1
        if checked > 3500 then break end
        if inst:GetAttribute("mapId") == mapId and inst:FindFirstChild("UnlockGui") then
            return inst
        end
    end
    return nil
end

function touchMapWall(mapId)
    if os.clock() - (QuestRuntimeState.lastWallTouch or 0) < 3 then return false end
    QuestRuntimeState.lastWallTouch = os.clock()

    local wall = findMapWallForMap(mapId)
    if not wall then return false end
    local hrp = getHRP()
    local wallPart = getPart(wall)
    if not hrp or not wallPart then return false end

    local previousMapId = tonumber(mapId) and math.max(1, tonumber(mapId) - 1) or getSpawnMapId()
    if (hrp.Position - wallPart.Position).Magnitude > 90 then
        teleportToMapUsingGameController(previousMapId)
    end

    moveToPosition(wallPart.Position)

    local touchPart = wall:FindFirstChild("Touch", true) or wallPart
    if touchPart and firetouchinterest and (hrp.Position - wallPart.Position).Magnitude <= 14 then
        pcall(function()
            firetouchinterest(hrp, touchPart, 0)
            task.wait(0.05)
            firetouchinterest(hrp, touchPart, 1)
        end)
    end

    return true
end

function getPetRarityName(petName)
    local petData = type(PetsModule) == "table" and PetsModule[petName]
    if type(petData) == "table" and petData.rarity then
        return tostring(petData.rarity)
    end
    if petUtils and petUtils.getRarity then
        local ok, rarity = pcall(function() return petUtils.getRarity(petName) end)
        if ok and rarity then return tostring(rarity) end
    end
    return nil
end

function getEggForPetName(petName)
    if not petName or petName == "" then return nil end
    local bestEgg, bestCost = nil, -math.huge
    for eggName, eggData in pairs(EggsModule or {}) do
        if type(eggData) == "table" and type(eggData.pets) == "table" and eggData.pets[petName] then
            local cost = tonumber(eggData.cost) or 0
            if canAffordEgg(eggName) and cost > bestCost then
                bestEgg, bestCost = eggName, cost
            end
        end
    end
    return bestEgg
end

function getEggForPetRarity(rarityName)
    if not rarityName or rarityName == "" then return nil end
    local wanted = tostring(rarityName):lower()
    local bestEgg, bestCost = nil, -math.huge

    for eggName, eggData in pairs(EggsModule or {}) do
        if type(eggData) == "table" and type(eggData.pets) == "table" and canAffordEgg(eggName) then
            for petName in pairs(eggData.pets) do
                local rarity = getPetRarityName(petName)
                if rarity and rarity:lower() == wanted then
                    local cost = tonumber(eggData.cost) or 0
                    if cost > bestCost then
                        bestEgg, bestCost = eggName, cost
                    end
                    break
                end
            end
        end
    end

    return bestEgg
end

function questTypeToRarity(questType)
    local lower = tostring(questType or ""):lower()
    local rarities = {
        "common", "uncommon", "rare", "epic", "legendary", "mythical", "eternal", "mysterious", "exclusive", "secret", "divine", "supreme", "ultimate",
    }
    for _, rarity in ipairs(rarities) do
        if lower:find(rarity, 1, true) then
            return rarity:gsub("^%l", string.upper)
        end
    end
    return nil
end

function openQuestEgg(quest)
    local questType = getQuestType(quest)
    local targetName = getQuestName(quest)
    local eggName = nil

    if questType == "hatchPet" and targetName then
        eggName = getEggForPetName(tostring(targetName))
    elseif targetName and type(EggsModule) == "table" and EggsModule[targetName] then
        eggName = tostring(targetName)
    elseif tostring(questType):lower():find("hatch", 1, true) then
        eggName = getEggForPetRarity(questTypeToRarity(questType))
    end

    eggName = eggName or getBestEggName() or getNearestEggName()
    if not eggName then return false end

    openEgg(eggName, getEggModelByName(eggName))
    return true
end

function claimReadyFarmsForQuest(maxClaims)
    local claimed = 0
    for _, farm in ipairs(CollectionService:GetTagged("Farm")) do
        if claimed >= (maxClaims or 3) then break end
        local farmId = farm:GetAttribute("farmId") or farm:GetAttribute("id")
        if farmId then
            local result, err = safeServiceCall(FarmService, "claim", farmId)
            if serviceCallSucceeded(result, err) then
                claimed = claimed + 1
                task.wait(0.1)
            end
        end
    end
    return claimed
end

function buildQuestBuilding(quest)
    local data = getData() or {}
    local target = tostring(getQuestName(quest) or ""):lower()
    for buildingId, info in pairs(BuildingsList or {}) do
        local display = tostring(type(info) == "table" and (info.name or info.Name) or buildingId):lower()
        local wanted = target == "" or display == target or tostring(buildingId):lower() == target
        local alreadyBuilt = type(data.buildings) == "table" and data.buildings[buildingId]
        if wanted and not alreadyBuilt then
            local result, err = safeServiceCall(BuildingService, "build", buildingId)
            return serviceCallSucceeded(result, err)
        end
    end
    return false
end

function useFirstAuraDiceForQuest()
    local data = getData()
    if not data or type(data.inventory) ~= "table" then return false end
    local auraDice = data.inventory.auraDice or data.inventory.dice or data.inventory.aura
    if type(auraDice) == "table" then
        for itemId, rawItem in pairs(auraDice) do
            local itemName = tostring(itemId)
            local amount = 1
            if itemUtils and itemUtils.getItemFromId then
                local ok, itemObject = pcall(function() return itemUtils.getItemFromId(data, itemId) end)
                if ok and itemObject then
                    pcall(function() itemName = tostring(itemObject:getName()) end)
                    pcall(function() amount = tonumber(itemObject:getAmount()) or amount end)
                end
            elseif type(rawItem) == "table" then
                itemName = tostring(rawItem.nm or rawItem.name or itemId)
                amount = tonumber(rawItem.amount or rawItem.a or rawItem.am) or amount
            elseif type(rawItem) == "number" then
                amount = rawItem
            end

            if amount > 0 then
                local result, err = callFirstQuestMethod(AuraService, { "roll", "rollAura", "useDice" }, itemName)
                if serviceCallSucceeded(result, err) then return true end
            end
        end
    end

    local result, err = callFirstQuestMethod(AuraService, { "roll", "rollAura" })
    return serviceCallSucceeded(result, err)
end

function craftAnyPetsForQuest(maxCrafts)
    local data = getData()
    if not data then return false end
    local petContainer = (type(data.inventory) == "table" and data.inventory.pet) or data.pets
    if type(petContainer) ~= "table" then return false end

    local petIds = {}
    for petId in pairs(petContainer) do
        table.insert(petIds, petId)
        if #petIds >= 20 then break end
    end
    if #petIds == 0 then return false end

    local result, err = safeServiceCall(PetService, "craft", petIds, true)
    return serviceCallSucceeded(result, err)
end

function craftAnyRingForQuest()
    return autoCraftRingsBatch(1, false) > 0
end

function craftAnySmoothieForQuest()
    local selected = firstValue(Library.Flags["SelectedSmoothie"])
    if selected and selected ~= "None" and craftSelectedSmoothie() then return true end
    for smoothieId in pairs(SmoothiesList or {}) do
        local result, err = safeServiceCall(RewardService, "craftSmoothie", smoothieId)
        if serviceCallSucceeded(result, err) then return true end
    end
    return false
end

function placeAnyTotemForQuest()
    if placeSelectedTotemIfNeeded() then return true end
    local data = getData()
    if not data or type(data.inventory) ~= "table" then return false end
    local totems = data.inventory.totem or data.inventory.totems
    if type(totems) ~= "table" then return false end

    for itemId in pairs(totems) do
        local result, err = safeServiceCall(InventoryService, "useItem", itemId, {
            mapId = getCurrentMapIdForItemUse(),
            use = 1,
        })
        if serviceCallSucceeded(result, err) then return true end
    end
    return false
end

function claimStarsForQuest()
    local claimed = 0
    for _, star in ipairs(CollectionService:GetTagged("FallingStar")) do
        local result, err = safeServiceCall(FallingStarsService, "claimStar", star.Name)
        if serviceCallSucceeded(result, err) then
            claimed = claimed + 1
            task.wait(0.05)
        end
    end
    return claimed > 0
end

function runQuestAction(quest, source)
    if type(quest) ~= "table" then return false end
    local questType = getQuestType(quest)
    local lower = tostring(questType):lower()

    if lower == "rebirths" or lower:find("rebirth", 1, true) then
        local best = getBestRebirthIndex()
        if best and best > 0 then
            safeServiceCall(RebirthService, "rebirth", best)
            return true
        end
        return false
    end

    if lower == "hatchpet" or (lower:find("hatch", 1, true) and lower:find("pet", 1, true)) or lower == "openegg" or lower == "openanyegg" or (lower:find("open", 1, true) and lower:find("egg", 1, true)) then
        return openQuestEgg(quest)
    end

    if lower == "building" then
        return buildQuestBuilding(quest)
    end

    if lower:find("tree", 1, true) then
        teleportToSpawnForQuest()
        farmTree(false, getSpawnMapId())
        return true
    end

    if lower:find("ore", 1, true) then
        mineOre(false)
        return true
    end

    if lower:find("potion", 1, true) or lower == "useitem" then
        return useLowestPotionForQuest(quest)
    end

    if lower:find("auradice", 1, true) or lower:find("dice", 1, true) or lower:find("aura", 1, true) then
        return useFirstAuraDiceForQuest()
    end

    if lower:find("fruit", 1, true) or lower:find("plant", 1, true) then
        if useInventoryItems({ "fruit" }, 1) > 0 then return true end
        return claimReadyFarmsForQuest(3) > 0
    end

    if lower:find("honey", 1, true) then
        callFirstQuestMethod(HiveService, { "claimHoney", "collectHoney", "claim" })
        return true
    end

    if lower:find("box", 1, true) or lower:find("crate", 1, true) then
        return useInventoryItems({ "box", "crate" }, 1) > 0
    end

    if lower:find("chest", 1, true) then
        claimAllChests()
        claimAllMiniChests()
        return true
    end

    if lower:find("ring", 1, true) then
        return craftAnyRingForQuest()
    end

    if lower:find("smoothie", 1, true) then
        return craftAnySmoothieForQuest()
    end

    if lower:find("craft", 1, true) then
        if lower:find("golden", 1, true) or lower:find("toxic", 1, true) or lower:find("galaxy", 1, true) or lower:find("pet", 1, true) then
            return craftAnyPetsForQuest(1)
        end
        return craftAnyRingForQuest() or craftAnySmoothieForQuest()
    end

    if lower:find("totem", 1, true) then
        return placeAnyTotemForQuest()
    end

    if lower:find("playtime", 1, true) then
        claimPlaytimeRewards()
        return true
    end

    if lower:find("star", 1, true) or lower:find("meteor", 1, true) then
        return claimStarsForQuest()
    end

    if lower:find("dungeon", 1, true) then
        return startSelectedDungeon()
    end

    return false
end

function runMapQuestStep()
    local quest, questId, mapData, nextMapId, allComplete = getCurrentMapQuest()
    if allComplete and nextMapId then
        touchMapWall(nextMapId)
        return
    end
    if not quest then return end
    runQuestAction(quest, "map")
end

function runAngelQuestStep()
    local data = getData()
    if not data then return end
    local tier = tonumber(data.angelQuestTier) or 1
    local info = AngelQuests and AngelQuests[tier]
    if type(info) ~= "table" or type(info.quest) ~= "table" then return end

    local quest = info.quest
    local progress = tonumber(data.angelQuestProgress) or 0
    if progress >= getQuestRequired(quest) then
        callFirstQuestMethod(QuestService, { "claimAngelQuest" })
        return
    end

    runQuestAction(quest, "angel")
end

function runMinerQuestStep()
    local data = getData()
    if not data then return end
    local tier = tonumber(data.minerQuestTier) or 1
    local info = MinerQuests and MinerQuests[tier]
    if type(info) ~= "table" or type(info.quest) ~= "table" then return end

    local quest = info.quest
    local progress = tonumber(data.minerQuestProgress) or 0
    if progress >= getQuestRequired(quest) then
        callFirstQuestMethod(QuestService, { "claimMinerQuest" })
        return
    end

    runQuestAction(quest, "miner")
end

function getQuestListCache()
    if QuestListCache then return QuestListCache end
    QuestListCache = {}
    if not SharedList then return QuestListCache end

    for _, inst in ipairs(SharedList:GetDescendants()) do
        if inst:IsA("ModuleScript") and inst.Name:lower():find("quest", 1, true) then
            local ok, result = pcall(require, inst)
            if ok and type(result) == "table" then
                table.insert(QuestListCache, result)
            end
        end
    end

    return QuestListCache
end

function resolveQuestDefinition(storedQuest)
    if type(storedQuest) ~= "table" then return nil end
    if type(storedQuest.quest) == "table" then return storedQuest.quest end
    if type(storedQuest.quest) == "string" then return storedQuest end

    local difficulty = storedQuest.questDifficulty or storedQuest.difficulty or storedQuest.Difficulty
    local questId = storedQuest.questId or storedQuest.id or storedQuest.Id
    if questId == nil then return nil end

    for _, questList in ipairs(getQuestListCache()) do
        local entry = nil
        if difficulty ~= nil and type(questList[difficulty]) == "table" then
            entry = questList[difficulty][questId] or questList[difficulty][tostring(questId)]
        end
        entry = entry or questList[questId] or questList[tostring(questId)]
        if type(entry) == "table" then
            if type(entry.quest) == "table" then return entry.quest end
            if type(entry.quest) == "string" then return entry end
        end
    end

    return nil
end

function runGenericEventQuestStep()
    local data = getData()
    if not data then return end

    for dataKey, questTable in pairs(data) do
        local keyLower = tostring(dataKey):lower()
        local isEventQuestTable = keyLower:find("quest", 1, true)
            and keyLower ~= "mapquests"
            and keyLower ~= "classicquests"
            and type(questTable) == "table"

        if isEventQuestTable then
            for questId, storedQuest in pairs(questTable) do
                if type(storedQuest) == "table" and not storedQuest.claimed and not storedQuest.isPremium then
                    local quest = resolveQuestDefinition(storedQuest)
                    if quest then
                        local progress = getQuestProgress(questTable, questId, storedQuest)
                        if progress < getQuestRequired(quest) then
                            runQuestAction(quest, "event")
                            return
                        end
                    end
                end
            end
        end
    end
end


----------------------------------------------------------------------
-- Season helpers
----------------------------------------------------------------------

function getCurrentSeasonNumber()
    return tonumber(Variables and Variables.season) or CurrentSeasonNumber or 9
end

function getSeasonDataKey(suffix)
    return "season" .. tostring(getCurrentSeasonNumber()) .. tostring(suffix or "")
end

function getSortedSeasonTierIds()
    local ids = {}
    for tierId in pairs(CurrentSeasonTiers or {}) do
        table.insert(ids, tierId)
    end
    table.sort(ids, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)
    return ids
end

function getCurrentSeasonPassLevel(data)
    data = data or getData() or {}
    if Util and Util.seasonUtils and type(Util.seasonUtils.getPassLevel) == "function" then
        local ok, level = pcall(function()
            return Util.seasonUtils.getPassLevel(data)
        end)
        if ok then return tonumber(level) or 0 end
    end
    return 0
end

function getCurrentSeasonRestartPrice(data)
    data = data or getData() or {}
    if Util and Util.seasonUtils and type(Util.seasonUtils.getRestartPrice) == "function" then
        local ok, price = pcall(function()
            return Util.seasonUtils.getRestartPrice(data)
        end)
        if ok then return tonumber(price) or math.huge end
    end
    return math.huge
end

function countSeasonClaimedRewards(data)
    data = data or getData() or {}
    local claimed = data[getSeasonDataKey("PassClaimed")]
    if type(claimed) ~= "table" then return 0 end

    local count = 0
    for _, value in pairs(claimed) do
        if value then count = count + 1 end
    end
    return count
end

function claimCurrentSeasonPassRewardsStep(maxClaims)
    local data = getData()
    if not data then return 0 end

    local season = getCurrentSeasonNumber()
    local level = getCurrentSeasonPassLevel(data)
    local claimedTable = data[getSeasonDataKey("PassClaimed")]
    if type(claimedTable) ~= "table" then return 0 end

    local premium = data[getSeasonDataKey("PassPremium")] == true
    local claimed = 0
    local limit = tonumber(maxClaims) or 10

    for _, tierId in ipairs(getSortedSeasonTierIds()) do
        local tierNumber = tonumber(tierId) or tierId
        if (tonumber(tierNumber) or 0) <= level then
            for passType = 1, (premium and 2 or 1) do
                local claimKey = tostring(passType) .. tostring(tierId)
                if not claimedTable[claimKey] then
                    local result, err = safeServiceCall(SeasonService, "claimTier", tierNumber, passType, true)
                    if serviceCallSucceeded(result, err) then
                        claimedTable[claimKey] = true
                        claimed = claimed + 1
                        task.wait(0.08)
                        if claimed >= limit then return claimed end
                    end
                end
            end
        end
    end

    return claimed
end

function resetCurrentSeasonPassStep()
    local data = getData()
    if not data then return false end

    local premium = data[getSeasonDataKey("PassPremium")] == true
    local seasonTierIds = getSortedSeasonTierIds()
    local requiredClaims = #seasonTierIds * (premium and 2 or 1)
    if requiredClaims <= 0 then return false end
    if countSeasonClaimedRewards(data) < requiredClaims then return false end

    local restarts = tonumber(data[getSeasonDataKey("PassRestarts")]) or 0
    local restartLimit = tonumber(Variables and Variables.seasonRestartLimit) or 100
    if restarts >= restartLimit then return false end

    local price = getCurrentSeasonRestartPrice(data)
    if price ~= math.huge and getCurrency(data, "gems") < price then return false end

    local result, err = safeServiceCall(SeasonService, "resetPass", true)
    return serviceCallSucceeded(result, err)
end

function runCurrentSeasonQuestStep()
    local data = getData()
    if not data then return false end

    local questTable = data[getSeasonDataKey("Quests")]
    if type(questTable) ~= "table" then return false end

    for questId, storedQuest in pairs(questTable) do
        if type(storedQuest) == "table" and not storedQuest.claimed then
            local quest = resolveQuestDefinition(storedQuest)
            if not quest then
                local difficulty = storedQuest.questDifficulty or storedQuest.difficulty or storedQuest.Difficulty
                local definitionId = storedQuest.questId or storedQuest.id or storedQuest.Id
                local entry = difficulty and CurrentSeasonQuests[difficulty] and CurrentSeasonQuests[difficulty][definitionId]
                entry = entry or CurrentSeasonQuests[definitionId]
                if type(entry) == "table" then
                    quest = type(entry.quest) == "table" and entry.quest or entry
                end
            end

            if quest then
                local progress = getQuestProgress(questTable, questId, storedQuest)
                if progress < getQuestRequired(quest) then
                    return runQuestAction(quest, "season")
                end
            end
        end
    end

    return false
end

----------------------------------------------------------------------
-- Quest Machine helpers
----------------------------------------------------------------------

function claimQuestMachineRewardsStep()
    local data = getData()
    if not data or type(data.questMachineRewards) ~= "table" then return end
    local rewardsList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "QuestMachine", "QuestMachineRewards" }, "QuestMachine.Rewards") or {}
    local xp = tonumber(data.questMachineXp) or 0
    for index, tier in ipairs(rewardsList) do
        if type(tier) == "table" and tonumber(tier.required) and xp >= tonumber(tier.required) then
            if not table.find(data.questMachineRewards, index) then
                safeServiceCall(QuestService, "claimQuestMachineReward", index)
                task.wait(0.3)
            end
        end
    end
end


----------------------------------------------------------------------
-- Clan helpers
----------------------------------------------------------------------

function getClanAchievementOptions()
    local options, map = {}, {}
    local achievements = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Clans", "ClanAchievements" }, "Clans.ClanAchievements") or {}
    for questId, entry in pairs(achievements) do
        if type(entry) == "table" and type(entry.list) == "table" and #entry.list > 0 then
            local display = tostring(entry.name or questId) .. " (" .. tostring(questId) .. ")"
            table.insert(options, display)
            map[display] = questId
        end
    end
    table.sort(options)
    return options, map
end

function getAchievementProgress(data, questId)
    local progress = 0
    pcall(function()
        local values = data and data.achievements and data.achievements[questId]
        if type(values) == "table" then
            for _, value in values do
                progress = progress + (tonumber(value) or 0)
            end
        elseif type(values) == "number" then
            progress = values
        end
    end)
    return progress
end

function autoClaimClanAchievementsStep()
    local selected = readSelectedDropdownValues(Library.Flags["SelectedClanAchievements"])
    if #selected == 0 then return end
    local _, achievementMap = getClanAchievementOptions()
    local achievements = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Clans", "ClanAchievements" }, "Clans.ClanAchievements") or {}
    local data = getData()
    if not data then return end

    for _, displayName in ipairs(selected) do
        local questId = achievementMap[displayName]
        local entry = questId and achievements[questId]
        if type(entry) == "table" then
            local firstTier = type(entry.list) == "table" and entry.list[1]
            local required = tonumber(firstTier and firstTier.amount) or 0
            if required > 0 and getAchievementProgress(data, questId) >= required then
                local result, err = safeServiceCall(ClanService, "claimAchievement", questId)
                if serviceCallSucceeded(result, err) then
                    task.wait(0.3)
                end
            end
        end
    end
end

function autoClaimClanPrestigeStep()
    local data = getData()
    if not data or not data.clanId then return end
    local ok, clanData = pcall(function()
        return ClanService and ClanService:getClanData(data.clanId)
    end)
    if not ok or type(clanData) ~= "table" then return end
    local prestiges = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Clans", "ClanPrestiges" }, "Clans.ClanPrestiges") or {}
    local current = tonumber(clanData.prestige) or 0
    local nextTier = prestiges[current + 1]
    if type(nextTier) == "table" and tonumber(nextTier.required) then
        local xp = tonumber(clanData.prestigeXp) or 0
        if xp >= tonumber(nextTier.required) then
            safeServiceCall(ClanService, "claimPrestige")
        end
    end
end

function activateClanWeatherStep()
    local ok, cache = pcall(function()
        return ClanController and ClanController:getClanCache()
    end)
    if not ok or type(cache) ~= "table" then return end
    local lastActivation = tonumber(cache.events and cache.events.weather) or 0
    if getServerTimeNowSafe() - lastActivation < 86400 then return end
    local result, err = safeServiceCall(ClanService, "activateClanWeather")
    if serviceCallSucceeded(result, err) then
        pcall(function()
            ClanController:setClanCache({ ["update"] = false })
        end)
    end
end

function claimGrowYourTutelPetStep()
    local data = getData()
    if not data then return end
    local given = false
    pcall(function() given = data.growYourTutelGivenPet == true end)
    if not given then
        safeServiceCall(RewardService, "claimGrowYourTutelPet")
    end
end

function autoSpinClanBoostWheelStep()
    local data = getData()
    if not data then return end
    local lastSpin = tonumber(data.clanBoostWheelSpin) or 0
    if getServerTimeNowSafe() - lastSpin < 86400 then return end
    safeServiceCall(ClanService, "clanBoostWheelSpin")
end

----------------------------------------------------------------------
-- Dungeon helpers
----------------------------------------------------------------------

DungeonRuntimeState = DungeonRuntimeState or {
    lastJoinAttempt = 0,
    lastDamageAt = 0,
    lastShopBuyAt = 0,
    lastUpgradeAt = 0,
}

dungeonTicketLabel = dungeonTicketLabel or nil
lastDungeonTicketLabelText = lastDungeonTicketLabelText or nil
dungeonModeDropdown = dungeonModeDropdown or nil
dungeonShopDropdown = dungeonShopDropdown or nil
dungeonUpgradeDropdown = dungeonUpgradeDropdown or nil

function toDisplayName(value)
    local text = tostring(value or "")
    if Functions and type(Functions.toPascal) == "function" then
        local ok, result = pcall(function() return Functions.toPascal(text) end)
        if ok and result then return tostring(result) end
    end
    text = text:gsub("([a-z])([A-Z])", "%1 %2"):gsub("[_%-]+", " ")
    text = text:gsub("^%l", string.upper)
    return text
end

function formatShortNumber(value)
    if Functions and type(Functions.suffixes) == "function" then
        local ok, result = pcall(function() return Functions.suffixes(value) end)
        if ok and result then return tostring(result) end
    end
    local n = tonumber(value)
    if not n then return tostring(value or 0) end
    local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
    local tier = 1
    while math.abs(n) >= 1000 and tier < #suffixes do
        n = n / 1000
        tier = tier + 1
    end
    if tier == 1 then return tostring(math.floor(n)) end
    return string.format("%.2f%s", n, suffixes[tier]):gsub("%.00", "")
end

function getDungeonServiceSignal(signalName)
    if not DungeonService then return nil end
    return DungeonService[signalName]
end

function fireDungeonSignal(signalName)
    local signal = getDungeonServiceSignal(signalName)
    if signal then
        local ok = pcall(function()
            if signal.Fire then
                signal:Fire()
            elseif signal.FireServer then
                signal:FireServer()
            elseif signal._re and signal._re.FireServer then
                signal._re:FireServer()
            end
        end)
        if ok then return true end
    end

    local result, err = safeServiceCall(DungeonService, signalName)
    return serviceCallSucceeded(result, err)
end

function isPlayerInDungeon()
    if DungeonController then
        local ok, result = pcall(function()
            if type(DungeonController.isInDungeon) == "function" then
                return DungeonController:isInDungeon()
            end
        end)
        if ok and result ~= nil then return result == true end
    end

    local data = getData()
    if data and data.isInDungeon ~= nil then return data.isInDungeon == true end
    return #CollectionService:GetTagged("DungeonRoom") > 0
end

function getDungeonTicketCount()
    local data = getData()
    if not data then return 0 end

    if itemUtils and type(itemUtils.getItemFromName) == "function" then
        local ok, item = pcall(function() return itemUtils.getItemFromName(data, "dungeonTicket") end)
        if ok and item then
            local amount = 1
            pcall(function()
                if item.getAmount then amount = tonumber(item:getAmount()) or amount end
            end)
            return amount
        end
    end

    local inventory = data.inventory or {}
    for _, containerName in ipairs({ "exclusive", "exclusives", "item", "items", "mapItem", "mapItems", "potion", "potions" }) do
        local container = inventory[containerName]
        if type(container) == "table" then
            for itemId, raw in pairs(container) do
                local key = tostring(itemId):lower()
                if key:find("dungeonticket", 1, true) or key == "dungeon_ticket" then
                    if type(raw) == "number" then return raw end
                    if type(raw) == "table" then return tonumber(raw.amount or raw.Amount or raw[1]) or 1 end
                    return 1
                end
            end
        end
    end

    return 0
end

function getDungeonTicketLabelText()
    local tickets = getDungeonTicketCount()
    local coins = getCurrency(getData(), "dungeonCoins")
    local inDungeon = isPlayerInDungeon() and "Yes" or "No"
    return "Dungeon Tickets: " .. tostring(tickets) .. " • Coins: " .. formatShortNumber(coins) .. " • In Dungeon: " .. inDungeon
end

function refreshDungeonTicketLabel()
    local text = getDungeonTicketLabelText()
    if text ~= lastDungeonTicketLabelText then
        lastDungeonTicketLabelText = text
        setVersusLabelText(dungeonTicketLabel, text)
    end
end

function startDungeonTicketLabelUpdater()
    Library:CleanupConnectionsByTag("RCU_DungeonTicketLabel")
    local lastUpdate = 0
    local conn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastUpdate < 2 then return end
        lastUpdate = now
        refreshDungeonTicketLabel()
    end)
    Library:TrackConnection(conn, "RCU_DungeonTicketLabel")
    refreshDungeonTicketLabel()
end

function getDungeonGamemodeOptions()
    local list = {}
    for index, gamemode in ipairs(DungeonGamemodes or {}) do
        local name = tostring(type(gamemode) == "table" and (gamemode.name or gamemode.Name) or ("Mode " .. tostring(index)))
        local price = tonumber(type(gamemode) == "table" and (gamemode.price or gamemode.Price)) or 0
        table.insert(list, string.format("%d. %s (%s tickets)", index, name, formatShortNumber(price)))
    end
    if #list == 0 then table.insert(list, "1. Basic (1 tickets)") end
    return list
end

function selectedDungeonGamemodeId()
    local selected = firstValue(Library.Flags["SelectedDungeonMode"])
    local id = tonumber(tostring(selected or ""):match("^(%d+)"))
    if id and DungeonGamemodes[id] then return id end
    return 1
end

function startSelectedDungeon()
    if os.clock() - (DungeonRuntimeState.lastJoinAttempt or 0) < 2.5 then return false end
    DungeonRuntimeState.lastJoinAttempt = os.clock()

    if isPlayerInDungeon() then return false end
    if getDungeonTicketCount() <= 0 then return false end

    local modeId = selectedDungeonGamemodeId()
    safeControllerCall(DungeonController, "setGamemodeId", modeId)
    local result, err = safeServiceCall(DungeonService, "startDungeon", modeId)
    if serviceCallSucceeded(result, err) then
        task.wait(0.35)
        safeControllerCall(DungeonController, "teleportToRoom")
        return true
    end
    return false
end

function applyDungeonCrashFixes()
    local dc = DungeonController
    if not dc then return false end

    if type(dc.getPowerupPosition) == "function" and not dc._RCUOriginalGetPowerupPosition then
        dc._RCUOriginalGetPowerupPosition = dc.getPowerupPosition
        dc.getPowerupPosition = function(self, ...)
            local args = { ... }
            local spawns = CollectionService:GetTagged("DungeonPowerupSpawn")
            if #spawns == 0 then return CFrame.new(0, -1000, 0) end
            local ok, result = pcall(function()
                return dc._RCUOriginalGetPowerupPosition(self, unpackArgs(args))
            end)
            if ok and result then return result end
            return spawns[1].CFrame
        end
    end

    if type(dc.spawnBoss) == "function" and not dc._RCUOriginalSpawnBoss then
        dc._RCUOriginalSpawnBoss = dc.spawnBoss
        dc.spawnBoss = function(self, ...)
            local args = { ... }
            local room = nil
            pcall(function()
                if type(self.getDungeonRoom) == "function" then room = self:getDungeonRoom() end
            end)
            if not room or not room:FindFirstChild("BossSpawn") then return nil end
            local ok, result = pcall(function()
                return dc._RCUOriginalSpawnBoss(self, unpackArgs(args))
            end)
            if ok then return result end
            return nil
        end
    end

    return true
end

function setDungeonHudVisibleOverride(enabled)
    if not UIController or type(UIController.hideHUD) ~= "function" then return false end
    if enabled then
        UIController._RCUOriginalHideHUD = UIController._RCUOriginalHideHUD or UIController.hideHUD
        UIController.hideHUD = function(self, hide, exceptions)
            return UIController._RCUOriginalHideHUD(self, false, exceptions or { bottom = true })
        end
    elseif UIController._RCUOriginalHideHUD then
        UIController.hideHUD = UIController._RCUOriginalHideHUD
        UIController._RCUOriginalHideHUD = nil
    end
    return true
end

function setDungeonScreenShakeOverride(enabled)
    local dc = DungeonController
    if not dc then return false end
    if enabled then
        if type(dc.shakeScreen) == "function" then dc._RCUOriginalShakeScreen = dc._RCUOriginalShakeScreen or dc.shakeScreen end
        if type(dc.criticalTap) == "function" then dc._RCUOriginalVisualCriticalTap = dc._RCUOriginalVisualCriticalTap or dc.criticalTap end
        dc.shakeScreen = function() end
        dc.criticalTap = function() end
    else
        if dc._RCUOriginalShakeScreen then dc.shakeScreen = dc._RCUOriginalShakeScreen; dc._RCUOriginalShakeScreen = nil end
        if dc._RCUOriginalVisualCriticalTap then dc.criticalTap = dc._RCUOriginalVisualCriticalTap; dc._RCUOriginalVisualCriticalTap = nil end
    end
    return true
end

function setDungeonEndTeleportOverride(enabled)
    local dc = DungeonController
    if not dc or type(dc.teleportFromRoom) ~= "function" then return false end
    if enabled then
        dc._RCUOriginalTeleportFromRoom = dc._RCUOriginalTeleportFromRoom or dc.teleportFromRoom
        dc.teleportFromRoom = function() return nil end
    elseif dc._RCUOriginalTeleportFromRoom then
        dc.teleportFromRoom = dc._RCUOriginalTeleportFromRoom
        dc._RCUOriginalTeleportFromRoom = nil
    end
    return true
end

function setDungeonPetVisualOverride(enabled)
    local dc = DungeonController
    if not dc or type(dc.createPets) ~= "function" then return false end
    if enabled then
        dc._RCUOriginalCreatePets = dc._RCUOriginalCreatePets or dc.createPets
        dc.createPets = function() return nil end
    elseif dc._RCUOriginalCreatePets then
        dc.createPets = dc._RCUOriginalCreatePets
        dc._RCUOriginalCreatePets = nil
    end
    return true
end

function autoDungeonDamageStep()
    if not isPlayerInDungeon() then return end
    if #CollectionService:GetTagged("dungeonBoss") <= 0 then return end
    fireDungeonSignal("damage")
    fireDungeonSignal("criticalTap")
end

function getNormalizedDungeonPowerupNames()
    local names = {}
    for key, info in pairs(DungeonPowerups or {}) do
        local keyText = tostring(key or "")
        names[keyText:lower()] = true
        names[keyText:gsub("%s+", ""):lower()] = true
        if type(info) == "table" and info.name then
            local displayName = tostring(info.name or "")
            names[displayName:lower()] = true
            names[displayName:gsub("%s+", ""):lower()] = true
        end
    end
    return names
end

function touchDungeonPowerup(instance, hrp)
    if not instance or not hrp or not firetouchinterest then return false end

    local function firePart(part)
        if not part or not part:IsA("BasePart") then return false end
        if not part:FindFirstChild("TouchInterest") then return false end
        pcall(function()
            firetouchinterest(hrp, part, 0)
            firetouchinterest(hrp, part, 1)
        end)
        return true
    end

    for _, part in ipairs(instance:GetChildren()) do
        if firePart(part) then return true end
    end

    return firePart(instance)
end

function autoPickupDungeonPowerupsStep()
    if not isPlayerInDungeon() then return end
    local hrp = getHRP()
    if not hrp then return end

    local powerupNames = getNormalizedDungeonPowerupNames()
    local debris = Workspace:FindFirstChild("Debris") or workspace:FindFirstChild("Debris")
    if not debris then return end

    local picked = 0
    for _, child in ipairs(debris:GetChildren()) do
        local childName = tostring(child.Name or "")
        local childKey = childName:gsub("%s+", ""):lower()
        if powerupNames[childKey] or powerupNames[childName:lower()] then
            if touchDungeonPowerup(child, hrp) then
                picked = picked + 1
                task.wait(0.25)
            end
        end
        if picked >= 8 then break end
    end
end

function getDungeonMaxEquippable(data)
    if Functions and type(Functions.dungeonMaxEquip) == "function" then
        local ok, result = pcall(function() return Functions.dungeonMaxEquip(client, data) end)
        if ok and tonumber(result) then return tonumber(result) end
    end

    local ok, label = pcall(function()
        return client.PlayerGui.MainUI.Menus.DungeonJoinFrame.Main.Default.YourTeamLabel
    end)
    if ok and label and label.Text then
        local max = tostring(label.Text):match("/%s*(%d+)")
        if tonumber(max) then return tonumber(max) end
    end

    return 3
end

function getDungeonPetInfo(data, petId)
    if not itemUtils or type(itemUtils.getItemFromId) ~= "function" then return nil end
    local ok, pet = pcall(function() return itemUtils.getItemFromId(data, petId) end)
    if not ok or not pet then return nil end

    local specialName, multiplier, amount = nil, 0, 1
    pcall(function() if pet.getSpecialMultiplierName then specialName = pet:getSpecialMultiplierName() end end)
    pcall(function() if pet.getSpecialMultiplierAmount then multiplier = tonumber(pet:getSpecialMultiplierAmount()) or 0 end end)
    pcall(function() if pet.getAmount then amount = tonumber(pet:getAmount()) or 1 end end)
    if specialName ~= "dungeonDamage" then return nil end

    return { id = petId, multiplier = multiplier, amount = amount }
end

AUTO_EQUIP_PET_TEAM_OPTIONS = {
    "All Teams",
    "Normal Click Pets",
    "Dungeon Pets",
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5361-5362)
    "Mining Pets",
    "Fishing Pets",
}

function getPetObjectFromId(data, petId)
    if not itemUtils or type(itemUtils.getItemFromId) ~= "function" then return nil end
    local ok, pet = pcall(function() return itemUtils.getItemFromId(data, petId) end)
    if ok then return pet end
    return nil
end

function getPetStackAmountFromObject(pet, rawData)
    local amount = 1
    pcall(function()
        if pet and pet.getAmount then amount = tonumber(pet:getAmount()) or amount end
    end)
    if type(rawData) == "table" then
        amount = tonumber(rawData.am or rawData.amount or rawData.Amount) or amount
    end
    return math.max(1, math.floor(tonumber(amount) or 1))
end

function getPetMultiplierScore(data, pet)
    local averageMultiplier = nil
    pcall(function()
        if petUtils and type(petUtils.getAverageMultiplier) == "function" then
            averageMultiplier = petUtils.getAverageMultiplier(data)
        end
    end)

    local score = 0
    pcall(function()
        if pet and pet.getMultiplier then
            score = tonumber(pet:getMultiplier(data, {
                ignoreServer = true,
                averageMultiplier = averageMultiplier,
            })) or score
        end
    end)
    return score
end

function getPetSpecialMultiplierInfo(data, pet)
    local specialName, amount = nil, 0
    pcall(function() if pet and pet.getSpecialMultiplierName then specialName = pet:getSpecialMultiplierName() end end)
    pcall(function() if pet and pet.getSpecialMultiplierAmount then amount = tonumber(pet:getSpecialMultiplierAmount(data)) or 0 end end)
    pcall(function() if amount == 0 and pet and pet.getSpecialMultiplierAmount then amount = tonumber(pet:getSpecialMultiplierAmount()) or 0 end end)
    return specialName, amount
end

function getAutoEquipModeFromSelection(selection)
    local value = tostring(getFirstSelectedDropdownValue(selection, "All Teams") or "All Teams"):lower():gsub("[^%w]+", "")
    if value == "all" or value == "allteams" then return "all" end
    if value:find("dungeon", 1, true) then return "dungeon" end
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5417-5418)
    if value:find("mine", 1, true) or value:find("mining", 1, true) then return "mine" end
    if value:find("fish", 1, true) then return "fishing" end
    return "normal"
end

function getUpgradeMultiplierTotal(data, upgradeName)
    if UpgradeUtils and type(UpgradeUtils.getAllUpgradeMultipliers) == "function" then
        local ok, result = pcall(function()
            return UpgradeUtils.getAllUpgradeMultipliers(data or {}, upgradeName)
        end)
        if ok and tonumber(result) then return tonumber(result) end
    end
    return 0
end

function getUpgradeListValue(list, upgradeName, level)
    if not list or not upgradeName or level == nil then return 0 end
    local entry = list[upgradeName]
    if type(entry) ~= "table" then return 0 end

    local upgrades = entry.upgrades or entry.Upgrades
    if type(upgrades) ~= "table" then return tonumber(entry.value or entry.Value or 0) or 0 end

    local levelEntry = upgrades[level] or upgrades[tostring(level)]
    if type(levelEntry) ~= "table" then return 0 end
    return tonumber(levelEntry.value or levelEntry.Value or levelEntry.amount or levelEntry.Amount or 0) or 0
end

function callGamePetEquipFunction(data, mode)
    local functionNamesByMode = {
        normal = { "petsEquipped", "PetsEquipped" },
        mine = { "minePetsEquipped", "MinePetsEquipped" },
        fishing = { "fishingPetsEquipped", "FishingPetsEquipped" },
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5452-5453)
    }

    for _, fnName in ipairs(functionNamesByMode[mode or "normal"] or functionNamesByMode.normal) do
        local fn = Functions and Functions[fnName]
        if type(fn) == "function" then
            local ok, result = pcall(function() return fn(client, data) end)
            if ok and tonumber(result) then return tonumber(result) end
        end
    end

    return nil
end

function getPetEquipMaxForMode(data, mode)
    data = data or getData() or {}
    mode = mode or "normal"
    if mode == "dungeon" then return getDungeonMaxEquippable(data) end

    local fromGameFunction = callGamePetEquipFunction(data, mode)
    if tonumber(fromGameFunction) then return math.max(1, math.floor(tonumber(fromGameFunction))) end

    local passes = type(data.passes) == "table" and data.passes or {}
    local upgrades = type(data.upgrades) == "table" and data.upgrades or {}
    local mineUpgrades = type(data.mineUpgrades) == "table" and data.mineUpgrades or {}
    local fishingUpgradesData = type(data.fishingUpgrades) == "table" and data.fishingUpgrades or {}

    local maxEquipped = 3

    if mode == "mine" then
        maxEquipped = 3
            + getUpgradeMultiplierTotal(data, "minePetEquip")
            + getUpgradeListValue(MineUpgrades, "minePetEquip", mineUpgrades.minePetEquip)
    elseif mode == "fishing" then
        maxEquipped = 5 + getUpgradeMultiplierTotal(data, "fishingPetEquip")
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5488-5490)
    else
        maxEquipped = 3
            + getUpgradeMultiplierTotal(data, "petsEquipped")
            + (passes.petEquip2 and 2 or 0)
            + (passes.petEquip3 and 3 or 0)
            + getUpgradeListValue(upgradesList, "petEquip", upgrades.petEquip)
            + getUpgradeListValue(FishingUpgrades, "petEquip", fishingUpgradesData.petEquip)
    end

    return math.max(1, math.floor(tonumber(maxEquipped) or 1))
end

function getPetEquipTableNameForMode(mode)
    if mode == "mine" then return "mineEquippedPets" end
    if mode == "fishing" then return "fishingPetsEquipped" end
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5506-5507)
    if mode == "dungeon" then return "dungeonTeam" end
    return "equippedPets"
end

function getPetSpecialNameForMode(mode)
    if mode == "mine" then return "pickaxeDamage" end
    if mode == "fishing" then return "fishCoins" end
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5515-5516)
    if mode == "dungeon" then return "dungeonDamage" end
    return nil
end

function getPetModeScore(data, pet, mode)
    mode = mode or "normal"

    if mode == "normal" then
        return getPetMultiplierScore(data, pet)
    end

    local wantedSpecial = getPetSpecialNameForMode(mode)
    if wantedSpecial then
        local specialName, specialAmount = getPetSpecialMultiplierInfo(data, pet)
        if tostring(specialName or "") == wantedSpecial then
            return tonumber(specialAmount) or 0
        end
        return 0
    end

    return getPetMultiplierScore(data, pet)
end

function getBestPetCandidatesForMode(data, mode, reservedCounts)
    if not data or not data.inventory or type(data.inventory.pet) ~= "table" then return {} end

    reservedCounts = reservedCounts or {}
    local candidates = {}

    for petId, rawData in pairs(data.inventory.pet) do
        local pet = getPetObjectFromId(data, petId)
        if pet then
            local totalAmount = getPetStackAmountFromObject(pet, rawData)
            local reservedAmount = tonumber(reservedCounts[petId]) or 0
            local availableAmount = math.max(0, totalAmount - reservedAmount)
            local score = getPetModeScore(data, pet, mode)

            if availableAmount > 0 and score > 0 then
                table.insert(candidates, {
                    id = petId,
                    pet = pet,
                    score = score,
                    amount = availableAmount,
                    totalAmount = totalAmount,
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        if (a.score or 0) == (b.score or 0) then
            local ar, br = 0, 0
            pcall(function() ar = getRarityRankFromName(a.pet:getRarity()) end)
            pcall(function() br = getRarityRankFromName(b.pet:getRarity()) end)
            if ar == br then
                local an, bn = "", ""
                pcall(function() an = tostring(a.pet:getName()) end)
                pcall(function() bn = tostring(b.pet:getName()) end)
                return an < bn
            end
            return ar > br
        end
        return (a.score or 0) > (b.score or 0)
    end)

    return candidates
end

function buildDesiredPetIdListForMode(data, mode, reservedCounts)
    local maxEquipped = math.max(1, math.floor(tonumber(getPetEquipMaxForMode(data, mode)) or 1))
    local desired = {}

    for _, candidate in ipairs(getBestPetCandidatesForMode(data, mode, reservedCounts)) do
        if #desired >= maxEquipped then break end
        local amount = math.min(tonumber(candidate.amount) or 1, maxEquipped - #desired)
        for _ = 1, amount do
            table.insert(desired, candidate.id)
            if #desired >= maxEquipped then break end
        end
    end

    return desired
end

function addReservedPetIdsFromList(reservedCounts, petIdList)
    for _, petId in ipairs(petIdList or {}) do
        reservedCounts[petId] = (tonumber(reservedCounts[petId]) or 0) + 1
    end
end

function addReservedPetIdsFromEquippedTable(reservedCounts, equipped)
    if type(equipped) ~= "table" then return end
    for petId, rawValue in pairs(equipped) do
        local amount = 1
        if type(rawValue) == "table" then
            amount = tonumber(rawValue.am or rawValue.amount or rawValue.Amount) or 1
        elseif type(rawValue) == "number" then
            amount = math.max(1, math.floor(rawValue))
        end
        reservedCounts[petId] = (tonumber(reservedCounts[petId]) or 0) + amount
    end
end

function buildReservedPetCountsForOtherModes(data, currentMode)
    local reservedCounts = {}
    if not data then return reservedCounts end

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5624-5625)
    for _, mode in ipairs({ "normal", "mine", "fishing", "dungeon" }) do
        if mode ~= currentMode then
            local tableName = getPetEquipTableNameForMode(mode)
            addReservedPetIdsFromEquippedTable(reservedCounts, data[tableName])
        end
    end

    return reservedCounts
end

function getCurrentEquippedPetIds(data, mode)
    local tableName = getPetEquipTableNameForMode(mode)
    local equipped = data and data[tableName]
    local ids = {}

    if type(equipped) == "table" then
        for petId in pairs(equipped) do
            table.insert(ids, petId)
        end
    end

    return ids
end

function equipBestDungeonPetsFromDesired(data, desiredList)
    local maxEquipped = getPetEquipMaxForMode(data, "dungeon")
    local desired = {}
    local total = 0

    for _, petId in ipairs(desiredList) do
        if total >= maxEquipped then break end
        desired[petId] = (desired[petId] or 0) + 1
        total = total + 1
    end

    local changed = 0
    local currentTeam = type(data.dungeonTeam) == "table" and data.dungeonTeam or {}

    for petId, equippedAmount in pairs(currentTeam) do
        local wanted = desired[petId] or 0
        local removeCount = (tonumber(equippedAmount) or 0) - wanted
        for _ = 1, math.max(0, removeCount) do
            safeServiceCall(DungeonService, "removePetFromTeam", petId)
            changed = changed + 1
            task.wait(0.08)
            if changed >= 20 then return true end
        end
    end

    for petId, wantedAmount in pairs(desired) do
        local currentAmount = tonumber(currentTeam[petId]) or 0
        local addCount = wantedAmount - currentAmount
        for _ = 1, math.max(0, addCount) do
            safeServiceCall(DungeonService, "addPetToTeam", petId)
            changed = changed + 1
            task.wait(0.08)
            if changed >= 20 then return true end
        end
    end

    return changed > 0
end

function equipBestPetsForMode(mode, desiredList)
    local data = getData()
    if not data or not data.inventory or type(data.inventory.pet) ~= "table" then return false end

    desiredList = desiredList or buildDesiredPetIdListForMode(data, mode, buildReservedPetCountsForOtherModes(data, mode))
    if #desiredList == 0 then return false end

    if mode == "dungeon" then
        return equipBestDungeonPetsFromDesired(data, desiredList)
    end

    local currentIds = getCurrentEquippedPetIds(data, mode)
    local options = {}
    if mode and mode ~= "normal" then options[mode] = true end

    if #currentIds > 0 then
        safeServiceCall(PetService, "unequipPet", currentIds, options)
        task.wait(0.15)
    end

    safeServiceCall(PetService, "equipPet", desiredList, options)
    return true
end

function getAutoEquipModeOrder(selectedMode)
    if selectedMode == "all" then
        -- Main/basic team gets first pick by click multiplier. The other teams then use only pets that
        -- were not already planned for another team, preventing cross-team equip conflicts.
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 5717-5718)
        return { "normal", "dungeon", "mine", "fishing" }
    end
    return { selectedMode }
end

function autoEquipBestPetsStep()
    local selectedMode = getAutoEquipModeFromSelection(Library.Flags.SelectedAutoEquipPetTeam)
    local modes = getAutoEquipModeOrder(selectedMode)
    local data = getData()
    if not data or not data.inventory or type(data.inventory.pet) ~= "table" then return false end

    local reservedCounts = {}
    if selectedMode ~= "all" then
        reservedCounts = buildReservedPetCountsForOtherModes(data, selectedMode)
    end

    local desiredByMode = {}
    for _, mode in ipairs(modes) do
        local desired = buildDesiredPetIdListForMode(data, mode, reservedCounts)
        desiredByMode[mode] = desired
        addReservedPetIdsFromList(reservedCounts, desired)
    end

    local didAny = false
    for _, mode in ipairs(modes) do
        if equipBestPetsForMode(mode, desiredByMode[mode]) then didAny = true end
        task.wait(0.2)
    end

    return didAny
end

function autoEquipBestDungeonPetsStep()
    return equipBestPetsForMode("dungeon")
end

----------------------------------------------------------------------
-- Pet Adventure helpers
----------------------------------------------------------------------

function getPetAdventureDurationsList()
    return safeRequirePath(ReplicatedStorage, { "Shared", "List", "PetAdventureDurations" }, "PetAdventureDurations") or {}
end

function getPetAdventureTimeLeft(adventure)
    if type(adventure) ~= "table" then return math.huge end
    local durations = getPetAdventureDurationsList()
    local durationDef = durations[adventure.durationId] or durations[tonumber(adventure.durationId)]
    if not durationDef or not tonumber(durationDef.duration) then return math.huge end
    local startedAt = (adventure.petAdventureData and adventure.petAdventureData.startedAt) or adventure.startedAt
    if not tonumber(startedAt) then return 0 end
    return tonumber(durationDef.duration) - (getServerTimeNowSafe() - tonumber(startedAt))
end

function canPetBeUsedInAdventure(petObject)
    if not petObject then return false end
    local utils = Util and Util.petAdventureUtils
    if utils and type(utils.canUsePet) == "function" then
        local ok, result = pcall(function() return utils.canUsePet(petObject) end)
        if ok and result == false then return false end
    end
    return true
end

function getPetAdventureMaxPets()
    local data = getData()
    if Values and type(Values.adventureMaxPetsAmount) == "function" then
        local ok, amount = pcall(function() return Values.adventureMaxPetsAmount(client, data) end)
        if ok and tonumber(amount) then return math.max(1, math.floor(tonumber(amount))) end
    end
    return 5
end

function buildPetAdventurePetsTable(data)
    local pets = {}
    local maxPets = getPetAdventureMaxPets()
    local used = {}
    if type(data.petAdventures2) == "table" then
        for _, adventure in pairs(data.petAdventures2) do
            if type(adventure) == "table" and type(adventure.pets) == "table" then
                for petId, amount in pairs(adventure.pets) do
                    used[petId] = (used[petId] or 0) + (tonumber(amount) or 0)
                end
            end
        end
    end

    local candidates = {}
    if type(data.inventory) == "table" and type(data.inventory.pet) == "table" then
        for petId, rawPet in pairs(data.inventory.pet) do
            local petObject = getPetObjectFromId(data, petId)
            if petObject and canPetBeUsedInAdventure(petObject) then
                local available = (tonumber(getPetStackAmountFromObject(petObject, rawPet)) or 0) - (used[petId] or 0)
                if available > 0 then
                    table.insert(candidates, {
                        id = petId,
                        score = getPetMultiplierScore(data, petObject),
                        available = available,
                    })
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.score > b.score end)

    local total = 0
    for _, candidate in ipairs(candidates) do
        if total >= maxPets then break end
        local count = math.min(candidate.available, maxPets - total)
        pets[candidate.id] = (pets[candidate.id] or 0) + count
        total = total + count
    end
    return pets
end

function getUnlockedPetAdventureDuration(data)
    local durations = getPetAdventureDurationsList()
    local upgrades = type(data.petAdventureUpgrades) == "table" and data.petAdventureUpgrades or {}
    local unlockedMax = 1 + (tonumber(upgrades.adventureDuration) or 0)
    local best = 1
    for id, def in ipairs(durations) do
        if id <= unlockedMax and def then best = id end
    end
    return best
end

function autoClaimPetAdventuresStep()
    local data = getData()
    if not data or type(data.petAdventures2) ~= "table" then return end
    for adventureId, adventure in pairs(data.petAdventures2) do
        if type(adventure) == "table" and getPetAdventureTimeLeft(adventure) <= 0 then
            safeServiceCall(PetService, "claimPetAdventure", adventureId)
            task.wait(0.3)
        end
    end
end

function autoStartPetAdventureStep()
    local data = getData()
    if not data or not data.inventory then return end
    autoClaimPetAdventuresStep()

    local slots = 1
    local upgrades = type(data.petAdventureUpgrades) == "table" and data.petAdventureUpgrades or {}
    if upgrades.adventureSlots then slots = slots + (tonumber(upgrades.adventureSlots) or 0) end
    if Util and Util.masteryUtils and type(Util.masteryUtils.getTier) == "function" then
        local ok, tier = pcall(function() return Util.masteryUtils.getTier(data, "paradoxMastery") end)
        if ok and tonumber(tier) and tonumber(tier) >= 300 then slots = slots + 1 end
    end

    local currentCount = 0
    if type(data.petAdventures2) == "table" then
        for _ in pairs(data.petAdventures2) do currentCount = currentCount + 1 end
    end
    if currentCount >= slots then return end

    local pets = buildPetAdventurePetsTable(data)
    if next(pets) == nil then return end
    safeServiceCall(PetService, "startPetAdventure", getUnlockedPetAdventureDuration(data), pets)
end

function cancelAllPetAdventuresStep()
    local data = getData()
    if not data or type(data.petAdventures2) ~= "table" then return end
    for adventureId in pairs(data.petAdventures2) do
        safeServiceCall(PetService, "cancelPetAdventure", adventureId)
        task.wait(0.3)
    end
end

function buyPetAdventureUpgradesStep()
    local data = getData()
    if not data then return end
    local upgradesList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "PetAdventureUpgrades" }, "PetAdventureUpgrades") or {}
    local owned = type(data.petAdventureUpgrades) == "table" and data.petAdventureUpgrades or {}
    for upgradeKey, def in pairs(upgradesList) do
        if type(def) == "table" and type(def.upgrades) == "table" then
            local level = tonumber(owned[upgradeKey]) or 0
            local nextUpgrade = def.upgrades[level + 1]
            if nextUpgrade and nextUpgrade.cost then
                local costAmount = 0
                pcall(function() costAmount = tonumber(nextUpgrade.cost:getAmount()) or 0 end)
                if costAmount > 0 then
                    local costName = ""
                    pcall(function() costName = tostring(nextUpgrade.cost:getName()) end)
                    if costName ~= "" and getAnyNumberFromData(data, { costName }) >= costAmount then
                        safeServiceCall(PetService, "buyPetAdventureUpgrade", upgradeKey)
                        task.wait(0.3)
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Tap Skins / Tap Orbs helpers
----------------------------------------------------------------------

function getTapOrbOptions()
    local options = {}
    local orbs = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "TapOrbs" }, "Items.TapOrbs") or {}
    for orbId, def in pairs(orbs) do
        if type(def) == "table" then
            table.insert(options, tostring(def.name or orbId) .. " (" .. tostring(orbId) .. ")")
        end
    end
    table.sort(options)
    return options
end

function getOwnedTapOrbs(data)
    local owned = {}
    if not data or type(data.inventory) ~= "table" then return owned end
    local orbs = data.inventory.tapOrb or data.inventory.tapOrbs
    if type(orbs) ~= "table" then return owned end
    for itemId, rawItem in pairs(orbs) do
        local amount = 1
        if type(rawItem) == "table" then
            amount = tonumber(rawItem.am or rawItem.amount or rawItem.Amount) or 1
        end
        if amount > 0 then owned[itemId] = amount end
    end
    return owned
end

function openOwnedTapOrbsStep()
    local owned = getOwnedTapOrbs(getData())
    for orbId in pairs(owned) do
        safeServiceCall(TapSkinService, "openTapOrb", orbId)
        task.wait(0.3)
    end
end

function getTapSkinOptions()
    local options, map = {}, {}
    local skins = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "TapSkins" }, "Items.TapSkins") or {}
    for skinId, def in pairs(skins) do
        if type(def) == "table" then
            local display = tostring(def.name or skinId) .. " (" .. tostring(def.rarity or "?") .. ")"
            table.insert(options, display)
            map[display] = skinId
        end
    end
    table.sort(options)
    return options, map
end

function forgeSelectedTapSkinsStep()
    local selected = readSelectedDropdownValues(Library.Flags["SelectedTapSkinsToForge"])
    if #selected == 0 then return end
    local _, skinMap = getTapSkinOptions()
    local skins = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "TapSkins" }, "Items.TapSkins") or {}
    local data = getData()
    if not data then return end
    local equippedId = data.equippedTapSkin

    for _, displayName in ipairs(selected) do
        local skinId = skinMap[displayName]
        if skinId and skinId ~= equippedId then
            local def = skins[skinId]
            local forgePoints = tonumber(def and def.forgePoints) or 0
            if forgePoints > 0 then
                local owned = getInventoryItemAmountByName(skinId, "tapSkin")
                if owned <= 0 then owned = getInventoryItemAmountByName(tostring(def and def.name or ""), "tapSkin") end
                local amount = math.floor(owned * forgePoints / 10)
                if amount >= 1 then
                    local result, err = safeServiceCall(TapSkinService, "forgeTapSkin", skinId, amount)
                    if serviceCallSucceeded(result, err) then
                        task.wait(0.5)
                    end
                end
            end
        end
    end
end

function equipBestTapSkinStep()
    local data = getData()
    if not data then return end
    local equippedId = data.equippedTapSkin
    local skins = safeRequirePath(ReplicatedStorage, { "Shared", "List", "Items", "TapSkins" }, "Items.TapSkins") or {}
    local bestId, bestScore = nil, 0
    for skinId, def in pairs(skins) do
        if skinId ~= equippedId and type(def) == "table" then
            local score = tonumber(def.multipliers and def.multipliers.clicks) or 0
            if score > bestScore then
                local itemId = findInventoryItemByNameMatch(tostring(def.name or skinId))
                if itemId then bestId, bestScore = itemId, score end
            end
        end
    end
    if bestId then
        safeServiceCall(InventoryService, "useItem", bestId, { use = 1 })
    end
end

----------------------------------------------------------------------
-- Supreme Altar helpers
----------------------------------------------------------------------

function sacrificeSupremeAltarPetsStep()
    local data = getData()
    if not data or not data.inventory or type(data.inventory.pet) ~= "table" then return 0 end
    local reserved = buildReservedPetCountsForOtherModes(data, nil)
    local sacrificed = 0

    for petId in pairs(data.inventory.pet) do
        if (tonumber(reserved[petId]) or 0) <= 0 then
            local petObject = getPetObjectFromId(data, petId)
            if petObject then
                local special = nil
                pcall(function() special = petObject.getSpecial and petObject:getSpecial() end)
                local untradeable = false
                pcall(function() untradeable = petObject.isUntradeable and petObject:isUntradeable() == true end)
                if (special == 1 or special == 1.1) and not untradeable then
                    local result, err = safeServiceCall(SupremeAltarService, "sacrificePet", petId)
                    if serviceCallSucceeded(result, err) then
                        sacrificed = sacrificed + 1
                        task.wait(0.5)
                        if sacrificed >= 5 then return sacrificed end
                    end
                end
            end
        end
    end

    return sacrificed
end

----------------------------------------------------------------------
-- Exclusive egg helpers
----------------------------------------------------------------------

function openOwnedExclusiveEggsStep()
    local data = getData()
    if not data or type(data.inventory) ~= "table" or type(data.inventory.exclusiveEgg) ~= "table" then return end

    local limit = 0
    pcall(function()
        limit = ExclusiveEggController and ExclusiveEggController._playersExclusiveEggs and ExclusiveEggController._playersExclusiveEggs[client] or 0
    end)
    if tonumber(limit) > 32 then return end

    local opened = 0
    for eggItemId, rawItem in pairs(data.inventory.exclusiveEgg) do
        local amount = 1
        if type(rawItem) == "table" then
            amount = tonumber(rawItem.am or rawItem.amount or rawItem.Amount) or 1
        end
        if amount > 0 then
            local amountToOpen = 1
            if amount >= 8 then amountToOpen = 8 elseif amount >= 3 then amountToOpen = 3 end
            safeServiceCall(EggService, "openExclusiveEgg", eggItemId, amountToOpen)
            opened = opened + 1
            task.wait(0.3)
            if opened >= 3 then return end
        end
    end
end

function readDungeonShopItemInfo(shopItem, index)
    if type(shopItem) ~= "table" then return nil end
    local item = shopItem.item or shopItem.Item
    local price = tonumber(shopItem.price or shopItem.Price) or 0
    local itemName = "Unknown Item"
    local amount = 1
    local className = "item"

    if item then
        pcall(function()
            if item.getName then itemName = tostring(item:getName()) end
        end)
        pcall(function()
            if (not itemName or itemName == "Unknown Item") and item.getRealName then itemName = tostring(item:getRealName()) end
        end)
        pcall(function()
            if item.getAmount then amount = tonumber(item:getAmount()) or amount end
        end)
        pcall(function()
            if item.getClass then className = tostring(item:getClass()) end
        end)
    end

    local display = (amount > 1 and (tostring(amount) .. "x ") or "") .. itemName .. " - " .. formatShortNumber(price) .. " coins"
    return {
        index = index,
        item = item,
        itemName = itemName,
        amount = amount,
        price = price,
        className = className,
        display = display,
    }
end

function getDungeonShopOptions()
    local options = { "Any Affordable" }
    DungeonShopDisplayMap = {}
    for index, shopItem in ipairs(DungeonShopList or {}) do
        local info = readDungeonShopItemInfo(shopItem, index)
        if info then
            addUnique(options, info.display)
            DungeonShopDisplayMap[info.display] = info
        end
    end
    return options
end

function getDungeonCurrentShopSlots()
    local slots = {}
    if not Functions or type(Functions.getRandom) ~= "function" then return slots end

    local serverTime = (Knit_Framework and Knit_Framework.serverTimeNow) or os.time()
    local timeData = DateTime.fromUnixTimestamp(serverTime + 3600):ToUniversalTime()
    for slot = 1, 3 do
        local seed = timeData.Year * 222 + timeData.Month * 333 + timeData.Day * 444444 + timeData.Hour * 33333 + client.UserId + slot
        local shopItem = DungeonShopList[Functions.getRandom(DungeonShopList, seed)]
        local info = readDungeonShopItemInfo(shopItem, slot)
        if info then
            info.seed = seed
            table.insert(slots, info)
        end
    end
    return slots
end

function dungeonShopItemMatchesSelection(info, selected)
    if selected == "Any Affordable" then return true end
    if not info or not selected then return false end
    local chosen = DungeonShopDisplayMap and DungeonShopDisplayMap[selected]
    if not chosen then return info.display == selected end
    return info.itemName == chosen.itemName and info.amount == chosen.amount and info.price == chosen.price
end

function buySelectedDungeonShopItemStep()
    if os.clock() - (DungeonRuntimeState.lastShopBuyAt or 0) < 1.5 then return false end
    local data = getData()
    if not data then return false end
    local selected = firstValue(Library.Flags["SelectedDungeonShopItem"]) or "Any Affordable"
    local coins = tonumber(data.dungeonCoins or getCurrency(data, "dungeonCoins")) or 0
    local bought = type(data.dungeonShopBought) == "table" and data.dungeonShopBought or {}

    for _, info in ipairs(getDungeonCurrentShopSlots()) do
        local boughtKey = tostring(info.seed or info.index)
        if not bought[boughtKey] and coins >= (info.price or 0) and dungeonShopItemMatchesSelection(info, selected) then
            DungeonRuntimeState.lastShopBuyAt = os.clock()
            local result, err = safeServiceCall(DungeonService, "buyShop", info.index)
            if serviceCallSucceeded(result, err) then return true end
        end
    end
    return false
end

function getDungeonUpgradeOptions()
    local options = { "Cheapest Affordable" }
    DungeonUpgradeDisplayMap = {}
    for upgradeId, upgradeData in pairs(DungeonUpgradesList or {}) do
        local display = toDisplayName(upgradeId)
        if type(upgradeData) == "table" and type(upgradeData.upgrades) == "table" then
            display = display .. " (" .. tostring(#upgradeData.upgrades) .. " levels)"
        end
        addUnique(options, display)
        DungeonUpgradeDisplayMap[display] = upgradeId
    end
    table.sort(options, function(a, b)
        if a == "Cheapest Affordable" then return true end
        if b == "Cheapest Affordable" then return false end
        return a < b
    end)
    return options
end

function getNextDungeonUpgradeInfo(data, upgradeId)
    local upgradeData = DungeonUpgradesList and DungeonUpgradesList[upgradeId]
    if type(upgradeData) ~= "table" or type(upgradeData.upgrades) ~= "table" then return nil end
    local levels = type(data.dungeonUpgrades) == "table" and data.dungeonUpgrades or {}
    local currentLevel = tonumber(levels[upgradeId]) or 0
    local nextLevel = currentLevel + 1
    local nextData = upgradeData.upgrades[nextLevel]
    if type(nextData) ~= "table" then return nil end
    return {
        id = upgradeId,
        level = nextLevel,
        cost = tonumber(nextData.cost) or 0,
        value = nextData.value,
    }
end

function buySelectedDungeonUpgradeStep()
    if os.clock() - (DungeonRuntimeState.lastUpgradeAt or 0) < 1 then return false end
    local data = getData()
    if not data then return false end
    local coins = tonumber(data.dungeonCoins or getCurrency(data, "dungeonCoins")) or 0
    local selected = firstValue(Library.Flags["SelectedDungeonUpgrade"]) or "Cheapest Affordable"
    local chosenUpgradeId = DungeonUpgradeDisplayMap and DungeonUpgradeDisplayMap[selected]
    local candidate = nil

    if selected == "Cheapest Affordable" then
        for upgradeId in pairs(DungeonUpgradesList or {}) do
            local info = getNextDungeonUpgradeInfo(data, upgradeId)
            if info and coins >= info.cost and (not candidate or info.cost < candidate.cost) then
                candidate = info
            end
        end
    elseif chosenUpgradeId then
        candidate = getNextDungeonUpgradeInfo(data, chosenUpgradeId)
        if candidate and coins < candidate.cost then candidate = nil end
    end

    if not candidate then return false end
    DungeonRuntimeState.lastUpgradeAt = os.clock()
    local result, err = safeServiceCall(DungeonService, "upgrade", candidate.id)
    return serviceCallSucceeded(result, err)
end


----------------------------------------------------------------------
-- Gardening / Fishing helpers
----------------------------------------------------------------------

GardenRuntimeState = GardenRuntimeState or {
    lastPlantAt = 0,
    lastClaimAt = 0,
}

FishingRuntimeState = FishingRuntimeState or {
    lastFishRequestAt = 0,
    lastCatchAt = 0,
    lastSellAt = 0,
}

GardenSeedPriority = GardenSeedPriority or {
    basicSeed = 1,
    epicSeed = 2,
    ultraSeed = 3,
    insaneSeed = 4,
}

GardenPlantPriority = GardenPlantPriority or {
    dandelion = 1,
    marigold = 2,
    rose = 3,
    sunflower = 4,
    crystalBloom = 5,
    elderTree = 6,
    astralWillow = 7,
}

function getServerTimeNowSafe()
    if Knit_Framework then
        if type(Knit_Framework.serverTimeNow) == "number" then
            return Knit_Framework.serverTimeNow
        end
        if type(Knit_Framework.serverTimeNow) == "function" then
            local ok, value = pcall(function()
                return Knit_Framework.serverTimeNow()
            end)
            if ok and tonumber(value) then return tonumber(value) end
        end
    end
    return os.time()
end

function getGardenGrowthReduction(data)
    local utils = (Util and Util.upgradeUtils) or UpgradeUtils
    if utils and type(utils.getAllUpgradeMultipliers) == "function" then
        local ok, value = pcall(function()
            return utils.getAllUpgradeMultipliers(data, "plantGrowingTime")
        end)
        if ok and tonumber(value) then
            return math.clamp(tonumber(value), 0, 0.95)
        end
    end
    return 0
end

function getGardenPlantData(data, gardenId)
    if not data or type(data.gardenPlants) ~= "table" then return nil end
    return data.gardenPlants[gardenId] or data.gardenPlants[tostring(gardenId)]
end

function getGardenSlotIds()
    local ids = {}
    local seen = {}

    local function addId(id)
        if id == nil then return end
        local key = tostring(id)
        if key == "" or seen[key] then return end
        seen[key] = true
        table.insert(ids, tonumber(id) or id)
    end

    for i = 1, 6 do addId(i) end

    local data = getData()
    if data and type(data.gardenPlants) == "table" then
        for gardenId in pairs(data.gardenPlants) do
            addId(gardenId)
        end
    end

    for _, garden in ipairs(CollectionService:GetTagged("garden")) do
        addId(garden:GetAttribute("gardenId") or garden:GetAttribute("id") or garden.Name)
    end

    table.sort(ids, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        return tostring(a) < tostring(b)
    end)

    return ids
end

function getGardenSeedScore(seedName, seedInfo)
    local priority = GardenSeedPriority[tostring(seedName or "")]
    if priority then return priority * 100000 end

    local score = 0
    if type(seedInfo) == "table" then
        for plantName, chance in pairs(seedInfo) do
            local plantInfo = GardenPlants and GardenPlants[plantName]
            local plantScore = GardenPlantPriority[tostring(plantName)] or 1
            if type(plantInfo) == "table" then
                plantScore = plantScore + ((tonumber(plantInfo.rewardsAmount) or 0) * 2) + ((tonumber(plantInfo.duration) or 0) / 60)
            end
            score = score + ((tonumber(chance) or 0) * plantScore)
        end
    end
    return score
end

function getAvailableGardenSeedNames()
    local names = {}
    for seedName in pairs(GardenSeeds or {}) do
        if getInventoryItemAmountByName(seedName) > 0 then
            table.insert(names, seedName)
        end
    end
    table.sort(names, function(a, b)
        return getGardenSeedScore(a, GardenSeeds[a]) > getGardenSeedScore(b, GardenSeeds[b])
    end)
    return names
end

function getBestGardenSeedName()
    local names = getAvailableGardenSeedNames()
    return names[1]
end

function gardenPlantIsReady(data, gardenId)
    local plant = getGardenPlantData(data, gardenId)
    if not plant then return false end

    local plantName = plant.plantName or plant.name or plant.Name
    local plantInfo = GardenPlants and GardenPlants[plantName]
    if type(plantInfo) ~= "table" then
        return true
    end

    local plantedAt = tonumber(plant.plantedAt or plant.PlantedAt or plant.time or plant.Time) or 0
    local duration = tonumber(plantInfo.duration) or 0
    local growthReduction = getGardenGrowthReduction(data)
    local effectiveDuration = duration * math.max(0.05, 1 - growthReduction)

    return getServerTimeNowSafe() >= plantedAt + effectiveDuration
end

function autoPlantGardenSeedsStep(maxPlants)
    if os.clock() - (GardenRuntimeState.lastPlantAt or 0) < 0.4 then return 0 end
    local data = getData()
    if not data then return 0 end

    local planted = 0
    local limit = tonumber(maxPlants) or 6

    for _, gardenId in ipairs(getGardenSlotIds()) do
        if planted >= limit then break end
        if not getGardenPlantData(data, gardenId) then
            local seedName = getBestGardenSeedName()
            if not seedName then return planted end

            GardenRuntimeState.lastPlantAt = os.clock()
            local result, err = safeServiceCall(GardenService, "plantSeed", seedName, gardenId)
            if serviceCallSucceeded(result, err) then
                planted = planted + 1
                task.wait(0.2)
                data = getData() or data
            end
        end
    end

    return planted
end

function claimReadyGardenPlantsStep(maxClaims)
    if os.clock() - (GardenRuntimeState.lastClaimAt or 0) < 0.4 then return 0 end
    local data = getData()
    if not data or type(data.gardenPlants) ~= "table" then return 0 end

    local claimed = 0
    local limit = tonumber(maxClaims) or 6
    local ids = getGardenSlotIds()

    for _, gardenId in ipairs(ids) do
        if claimed >= limit then break end
        if gardenPlantIsReady(data, gardenId) then
            GardenRuntimeState.lastClaimAt = os.clock()
            local result, err = safeServiceCall(GardenService, "claimPlant", gardenId, true)
            if not serviceCallSucceeded(result, err) then
                result, err = safeServiceCall(GardenService, "claimPlant", gardenId)
            end
            if serviceCallSucceeded(result, err) then
                claimed = claimed + 1
                task.wait(0.2)
                data = getData() or data
            end
        end
    end

    return claimed
end

function getFishingBayOptions()
    local options = {}
    FishingWorldDisplayMap = {}

    for worldId, worldInfo in pairs(FishingWorlds or {}) do
        local display = tostring((type(worldInfo) == "table" and worldInfo.name) or toDisplayName(worldId)) .. " (" .. tostring(worldId) .. ")"
        addUnique(options, display)
        FishingWorldDisplayMap[display] = worldId
    end

    table.sort(options)
    if #options == 0 then table.insert(options, "None") end
    return options
end

function getFishingWorldIdFromSelection(selection)
    local selected = getFirstSelectedDropdownValue(selection or Library.Flags["SelectedFishingBay"], "None")
    if not selected or selected == "None" then return nil end
    return (FishingWorldDisplayMap and FishingWorldDisplayMap[selected]) or selected:match("%((.-)%)") or selected
end

function setSelectedFishingBay()
    local worldId = getFishingWorldIdFromSelection()
    if not worldId then
        notify("Select a Fishing Bay", "Choose a fishing bay first, then press the button.", "warning")
        return false
    end

    local result, err = safeServiceCall(FishingService, "setFishingWorld", worldId)
    if serviceCallSucceeded(result, err) then
        if FishingController and FishingController.reloadFishingWorld then
            safeControllerCall(FishingController, "reloadFishingWorld")
        end
        return true
    end

    notify("Fishing Bay Locked", "That fishing bay may still be locked or missing required unlock items.", "warning")
    return false
end

function fishingWorldUnlocked(data, worldId, worldInfo)
    if type(worldInfo) == "table" and worldInfo.alwaysUnlocked then return true end
    if not data then return false end
    local unlocked = data.fishingWorlds or data.fishingWorldsUnlocked or data.unlockedFishingWorlds
    if type(unlocked) == "table" then
        return unlocked[worldId] == true or unlocked[tostring(worldId)] == true or hasValue(unlocked, worldId)
    end
    return data.currentFishingWorld == worldId
end

function autoUnlockFishingBaysStep(maxUnlocks)
    local data = getData()
    if not data then return 0 end

    local unlocked = 0
    local ids = {}
    for worldId in pairs(FishingWorlds or {}) do table.insert(ids, worldId) end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)

    for _, worldId in ipairs(ids) do
        if unlocked >= (tonumber(maxUnlocks) or 1) then break end
        local worldInfo = FishingWorlds[worldId]
        if not fishingWorldUnlocked(data, worldId, worldInfo) then
            local result, err = safeServiceCall(FishingService, "unlockFishingWorld", worldId)
            if serviceCallSucceeded(result, err) then
                unlocked = unlocked + 1
                task.wait(0.25)
                data = getData() or data
                if data.currentFishingWorld ~= worldId then
                    safeServiceCall(FishingService, "setFishingWorld", worldId)
                    if FishingController and FishingController.reloadFishingWorld then
                        safeControllerCall(FishingController, "reloadFishingWorld")
                    end
                end
            end
        end
    end

    return unlocked
end

function getNearestFishingZone()
    local hrp = getHRP()
    if not hrp then return nil end

    local bestZone, bestDist
    for _, zone in ipairs(CollectionService:GetTagged("fishingZone")) do
        local part = getPart(zone)
        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if not bestDist or dist < bestDist then
                bestZone = zone
                bestDist = dist
            end
        end
    end
    return bestZone, bestDist
end

function moveNearFishingZone()
    local zone, dist = getNearestFishingZone()
    local part = getPart(zone)
    if not part then return false end

    if dist and dist > 14 then
        if dist > 80 then
            teleportNear(part.Position + Vector3.new(0, 0, 8), 4)
        else
            moveToPosition(part.Position)
        end
    end

    return true
end

function autoFishStep()
    local now = os.clock()
    moveNearFishingZone()

    if FishingController and FishingController.isFishing then
        local isFishing = safeControllerCall(FishingController, "isFishing")
        if not isFishing and FishingController.startFishing then
            safeControllerCall(FishingController, "startFishing")
        end
    end

    if now - (FishingRuntimeState.lastFishRequestAt or 0) > 1.2 then
        FishingRuntimeState.lastFishRequestAt = now
        safeServiceCall(FishingService, "setIsAutoFishing", true)
        safeServiceCall(FishingService, "fishRequest")
    end

    if now - (FishingRuntimeState.lastCatchAt or 0) > 0.35 then
        FishingRuntimeState.lastCatchAt = now
        safeServiceCall(FishingService, "fishCatched")
    end
end

function getFishingSellRarityOptions()
    local options = {}

    if type(ItemRaritiesList) == "table" then
        for _, rarityInfo in pairs(ItemRaritiesList) do
            if type(rarityInfo) == "table" and rarityInfo.name then
                addUnique(options, tostring(rarityInfo.name))
            end
        end
    end

    for _, rarityName in ipairs(WEBHOOK_RARITY_OPTIONS or {}) do
        addUnique(options, rarityName)
    end

    table.sort(options, function(a, b)
        local ar, br = getRarityRankFromName(a), getRarityRankFromName(b)
        if ar ~= br then return ar < br end
        return tostring(a) < tostring(b)
    end)

    return options
end

function getSelectedFishSellRaritySet()
    local set = {}
    for _, rarityName in ipairs(readSelectedDropdownValues(Library.Flags["AutoSellFishRarities"])) do
        set[tostring(rarityName):lower()] = true
    end
    return set
end


function getCurrentFishingRodIndexFromInventory(data)
    data = data or getData()
    if not data or not data.inventory or type(data.inventory.exclusive) ~= "table" then return nil end

    for _, rawItem in pairs(data.inventory.exclusive) do
        local itemObject = nil
        if itemUtils and type(itemUtils.createItemFromData) == "function" and type(rawItem) == "table" then
            local ok, result = pcall(function()
                return itemUtils.createItemFromData(rawItem)
            end)
            if ok then itemObject = result end
        end
        if itemObject then
            local itemName = nil
            pcall(function() if itemObject.getName then itemName = tostring(itemObject:getName()) end end)
            if itemName and itemName:lower():find("fishingrod", 1, true) then
                local directory = nil
                pcall(function() if itemObject.directory then directory = itemObject:directory() end end)
                local entry = directory and directory[itemName]
                if type(entry) == "table" and tonumber(entry.index) then
                    return tonumber(entry.index)
                end
                local fallback = ExclusiveItemsList and ExclusiveItemsList[itemName]
                if type(fallback) == "table" and tonumber(fallback.index) then
                    return tonumber(fallback.index)
                end
            end
        end
    end

    return nil
end

function getFishingRodNameFromIndex(index)
    if type(ExclusiveItemsList) ~= "table" then return nil end
    for itemName, itemInfo in pairs(ExclusiveItemsList) do
        if tostring(itemName):lower():find("fishingrod", 1, true) and type(itemInfo) == "table" and tonumber(itemInfo.index) == tonumber(index) then
            return itemName
        end
    end
    return nil
end

function getRequiredFishingRodFishSet(data)
    local protect = {}
    data = data or getData()
    local currentIndex = getCurrentFishingRodIndexFromInventory(data)
    if not currentIndex then return protect end

    local maxIndex = currentIndex + 1
    for itemName, itemInfo in pairs(ExclusiveItemsList or {}) do
        if tostring(itemName):lower():find("fishingrod", 1, true) and type(itemInfo) == "table" and tonumber(itemInfo.index) then
            maxIndex = math.max(maxIndex, tonumber(itemInfo.index))
        end
    end

    for rodIndex = currentIndex + 1, maxIndex do
        local rodName = getFishingRodNameFromIndex(rodIndex)
        local upgradeInfo = rodName and FishingRodUpgrader and FishingRodUpgrader[rodName]
        local required = type(upgradeInfo) == "table" and upgradeInfo.required or nil
        if type(required) == "table" then
            for _, itemObject in ipairs(required) do
                local requiredName = nil
                pcall(function()
                    if itemObject and itemObject.getName then requiredName = tostring(itemObject:getName()) end
                end)
                if requiredName and requiredName ~= "" then
                    protect[requiredName:lower()] = true
                end
            end
        end
    end

    return protect
end

function getFishItemNameForSelling(data, itemId, rawItem, itemObject)
    local itemName = nil
    if itemObject then
        pcall(function() if itemObject.getName then itemName = tostring(itemObject:getName()) end end)
    end
    if type(rawItem) == "table" then
        itemName = itemName or tostring(rawItem.nm or rawItem.name or rawItem.Name or rawItem.item or rawItem.itemId or "")
    end
    if not itemName or itemName == "" then itemName = tostring(itemId or "") end
    return itemName
end

function getFishItemObject(data, itemId, rawItem)
    local itemObject = nil
    if itemUtils and itemUtils.getItemFromId then
        local ok, result = pcall(function()
            return itemUtils.getItemFromId(data, itemId)
        end)
        if ok then itemObject = result end
    end
    if not itemObject and itemUtils and itemUtils.createItemFromData and type(rawItem) == "table" then
        local ok, result = pcall(function()
            return itemUtils.createItemFromData(rawItem)
        end)
        if ok then itemObject = result end
    end
    return itemObject
end

function shouldSellFishItem(data, itemId, rawItem, raritySet, protectedFishSet)
    local itemObject = getFishItemObject(data, itemId, rawItem)
    local itemClass = "fish"
    local rarity = nil
    local locked = false
    local itemName = getFishItemNameForSelling(data, itemId, rawItem, itemObject)

    if itemObject then
        pcall(function() itemClass = tostring(itemObject:getClass() or itemClass) end)
        pcall(function() rarity = tostring(itemObject:getRarity()) end)
        pcall(function()
            if itemObject.getLocked then locked = itemObject:getLocked() == true end
        end)
    end

    if type(rawItem) == "table" then
        rarity = rarity or tostring(rawItem.rarity or rawItem.Rarity or rawItem.rare or rawItem.tier or rawItem.Tier or "")
        locked = locked or rawItem.locked == true or rawItem.Locked == true or rawItem.lk == true
        itemClass = tostring(rawItem.cl or rawItem.class or rawItem.Class or itemClass)
    end

    if locked then return false end
    if tostring(itemClass):lower() ~= "fish" then return false end
    if protectedFishSet and protectedFishSet[tostring(itemName or ""):lower()] then return false end
    if not rarity or rarity == "" then return false end

    return raritySet[tostring(rarity):lower()] == true
end

function autoSellSelectedFishRaritiesStep(maxSell)
    if os.clock() - (FishingRuntimeState.lastSellAt or 0) < 0.75 then return 0 end

    local data = getData()
    if not data or type(data.inventory) ~= "table" or type(data.inventory.fish) ~= "table" then return 0 end

    local raritySet = getSelectedFishSellRaritySet()
    if countTable(raritySet) <= 0 then return 0 end

    local toSell = {}
    local amount = 0
    local limit = tonumber(maxSell) or 80
    local protectedFishSet = Library.Flags["ProtectFishingRodUpgradeFish"] == false and nil or getRequiredFishingRodFishSet(data)

    for itemId, rawItem in pairs(data.inventory.fish) do
        if amount >= limit then break end
        if shouldSellFishItem(data, itemId, rawItem, raritySet, protectedFishSet) then
            toSell[itemId] = true
            amount = amount + 1
        end
    end

    if amount <= 0 then return 0 end

    FishingRuntimeState.lastSellAt = os.clock()
    local result, err = safeServiceCall(FishingService, "sellFish", toSell)
    if serviceCallSucceeded(result, err) then
        return amount
    end
    return 0
end

applyDungeonCrashFixes()

----------------------------------------------------------------------
-- Paradox Merchant helpers
----------------------------------------------------------------------

function getParadoxMerchantOptions()
    local options, map = {}, {}
    local merchantList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "ParadoxMerchant" }, "ParadoxMerchant") or {}
    for i, offer in ipairs(merchantList) do
        local name = offer.item and offer.item.nm or "Unknown"
        local amount = offer.item and offer.item.am or 1
        local price = offer.price or 0
        local display = (amount > 1 and (amount .. "x " .. name) or name) .. " - " .. tostring(price) .. " compasses"
        table.insert(options, display)
        map[display] = { name = name, amount = amount, price = price, index = i }
    end
    table.sort(options)
    return options, map
end

function getParadoxMerchantSeed(userId, slot)
    local serverTime = getServerTimeNowSafe()
    local hours = math.floor(serverTime / 3600) - 495000
    return hours * math.floor((userId or 0) * 0.5) + (tonumber(slot) or 1)
end

function autoBuyParadoxMerchantStep()
    local selected = readSelectedDropdownValues(Library.Flags["SelectedParadoxMerchantItems"])
    if #selected == 0 then return end
    local _, itemMap = getParadoxMerchantOptions()
    local merchantList = safeRequirePath(ReplicatedStorage, { "Shared", "List", "ParadoxMerchant" }, "ParadoxMerchant") or {}
    local data = getData()
    if not data then return end
    local bought = type(data.paradoxMerchantBought) == "table" and data.paradoxMerchantBought or {}
    local userId = client and client.UserId or 0
    for slot = 1, 4 do
        local seed = getParadoxMerchantSeed(userId, slot)
        local itemData = merchantList[Functions.getRandom and Functions.getRandom(merchantList, seed) or 1]
        if itemData and itemData.item then
            local merchantName = itemData.item.nm or ""
            local merchantAmount = itemData.item.am or 1
            for _, displayName in ipairs(selected) do
                local selectedItem = itemMap[displayName]
                if selectedItem and merchantName == selectedItem.name and merchantAmount == selectedItem.amount then
                local key = tostring(seed)
                if not bought[key] then
                    local result, err = safeServiceCall(RewardService, "buyParadoxMerchant", slot)
                    if serviceCallSucceeded(result, err) then
                        task.wait(0.5)
                    end
                end
                end
            end
        end
    end
end

Main = Setup:CreateSection("⚡ Main")
Events = Setup:CreateSection("🎉 Events")
Worlds = Setup:CreateSection("🌍 Worlds")
Trees = Setup:CreateSection("🌳 Trees")
Mining = Setup:CreateSection("⛏️ Mining")
Gardening = Setup:CreateSection("🌱 Gardening")
Fishing = Setup:CreateSection("🎣 Fishing")
Dungeon = Setup:CreateSection("🏰 Dungeon")
Eggs = Setup:CreateSection("🥚 Eggs & Pets")
Rewards = Setup:CreateSection("🎁 Rewards")
Inventory = Setup:CreateSection("🎒 Inventory")
Hive = Setup:CreateSection("🐝 Hive")
Mounts = Setup:CreateSection("🐎 Mounts")
Misc = Setup:CreateSection("⚙️ Misc")
Webhooks = Setup:CreateSection("🔔 Webhooks")
DevTools = Setup:CreateSection("🛠️ Developer Tools")
Paradox = Setup:CreateSection("🧭 Paradox")

Main:createButton({
    Name = "VersusAI Pathing",
    VersusAI = true,
    flagName = "UseVersusAI",
    Callback = function(enabled)
        print("VersusAI Pathing:", enabled and "allowed" or "disabled")
    end,
})

Main:createLabel({
    Name = "RCU v2 rebuild",
    Special = true,
})

createIntervalToggle(Main, {
    Name = "Auto Click",
    flagName = "AutoClick",
    tag = "RCU_AutoClick",
    delay = 0.05,
    Step = function()
        if ClickController and ClickController.canClick then
            local canClick = true
            pcall(function() canClick = ClickController:canClick() end)
            if canClick then
                pcall(function() ClickController:setLastClickType(1) end)
                pcall(function() ClickController:setDebounce() end)
            end
        end

        if ClickController and ClickController.doClick then
            safeControllerCall(ClickController, "doClick")
        else
            safeServiceCall(ClickService, "click")
        end
    end,
})

createIntervalToggle(Main, {
    Name = "Auto Rebirth (Best)",
    flagName = "AutoRebirth",
    tag = "RCU_AutoRebirth",
    delay = 1,
    Step = function()
        local best = getBestRebirthIndex()
        if best and best > 0 then
            safeServiceCall(RebirthService, "rebirth", best)
        end
    end,
})

createIntervalToggle(Main, {
    Name = "Auto Buy Upgrades",
    flagName = "AutoBuyUpgrades",
    tag = "RCU_AutoBuyUpgrades",
    delay = 1.5,
    Step = function()
        buyNormalUpgradesBatch(5)
    end,
})


createIntervalToggle(Main, {
    Name = "Auto Buy Skill Tree",
    flagName = "AutoBuySkillTree",
    tag = "RCU_AutoBuySkillTree",
    delay = 6,
    Step = function()
        buySkillTreeBatch(20)
    end,
})

createIntervalToggle(Main, {
    Name = "Auto Collect Orbs",
    flagName = "AutoCollectOrbs",
    tag = "RCU_AutoCollectOrbs",
    delay = 1.25,
    Step = function()
        local ids = collectOrbIds()
        if #ids == 0 then return end
        if OrbController and OrbController.collectOrbs then
            safeControllerCall(OrbController, "collectOrbs", ids)
        else
            safeServiceCall(OrbService, "collectOrbs", ids)
        end
    end,
})

createIntervalToggle(Main, {
    Name = "Auto Build Buildings",
    flagName = "AutoBuildBuildings",
    tag = "RCU_AutoBuildBuildings",
    delay = 4,
    Step = function()
        local data = getData()
        if not data then return end
        for buildingId in pairs(BuildingsList) do
            if not data.buildings or not data.buildings[buildingId] then
                safeServiceCall(BuildingService, "build", buildingId)
                task.wait(0.2)
            end
        end
    end,
})

createIntervalToggle(Main, {
    Name = "Auto Quests (Unlock Next Area)",
    flagName = "AutoQuests",
    tag = "RCU_AutoQuests",
    delay = 1.5,
    Step = runMapQuestStep,
})
createIntervalToggle(Main, {
    Name = "Auto Angel Quests",
    flagName = "AutoAngelQuests",
    tag = "RCU_AutoAngelQuests",
    delay = 1.5,
    Step = runAngelQuestStep,
})

----------------------------------------------------------------------
-- Worlds
----------------------------------------------------------------------

worldDropdown = Worlds:createDropdown({
    Name = "World / Area",
    flagName = "SelectedWorld",
    List = getMapNames(false),
    Flag = { "Spawn" },
    Callback = function(value)
        print("Selected world:", firstValue(value))
    end,
})

Worlds:createButton({
    Name = "Refresh Worlds",
    Callback = function()
        worldDropdown:updateList(getMapNames(false))
    end,
})

Worlds:createButton({
    Name = "Teleport to Selected World",
    Callback = function()
        local selected = firstValue(Library.Flags["SelectedWorld"])
        local mapId, mapInfo = getMapByName(selected)
        if mapInfo and mapInfo.cframe then
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = mapInfo.cframe + Vector3.new(0, 4, 0)
            end
            safeServiceCall(MapService, "setCurrentMap", mapId)
        else
            notify("World not found", "I couldn't find a CFrame for that world in the current map list.", "warning")
        end
    end,
})

createIntervalToggle(Worlds, {
    Name = "Auto Unlock / Purchase Space Worlds",
    flagName = "AutoUnlockWorlds",
    tag = "RCU_AutoUnlockWorlds",
    delay = 5,
    Step = function()
        for mapId in pairs(MapList) do
            if not isMapUnlocked(mapId) then
                safeServiceCall(MapService, "purchaseSpaceWorld", mapId)
                task.wait(0.25)
            end
        end
    end,
})


createIntervalToggle(Worlds, {
    Name = "Auto Buy Space Upgrades",
    flagName = "AutoBuySpaceUpgrades",
    tag = "RCU_AutoBuySpaceUpgrades",
    delay = 4,
    Step = function()
        buySpaceUpgradesBatch(10)
    end,
})

----------------------------------------------------------------------
-- Trees / VersusAI placeholder integration
----------------------------------------------------------------------

treeGroupDropdown = Trees:createDropdown({
    Name = "Tree Group",
    flagName = "TreeGroup",
    List = getTreeGroups(),
    Flag = { "Nearest" },
    Callback = function(value)
        print("Tree group:", firstValue(value))
    end,
})

Trees:createButton({
    Name = "Refresh Tree Groups",
    Callback = function()
        treeGroupDropdown:updateList(getTreeGroups())
    end,
})

createIntervalToggle(Trees, {
    Name = "Auto Farm Trees (Walking / Controller)",
    flagName = "AutoFarmTrees",
    tag = "RCU_AutoFarmTrees",
    delay = 0.35,
    Step = function()
        farmTree(false)
    end,
})

createIntervalToggle(Trees, {
    Name = "Auto Farm Trees (Teleport, Risky)",
    Warning = function()
        return "Teleport farming can be obvious to other players. Use walking/VersusAI mode when possible."
    end,
    WarnIf = function() return true end,
    flagName = "AutoFarmTreesTeleport",
    tag = "RCU_AutoFarmTreesTeleport",
    delay = 0.5,
    Step = function()
        farmTree(true)
    end,
})

createIntervalToggle(Trees, {
    Name = "Auto Upgrade Axe",
    flagName = "AutoUpgradeAxe",
    tag = "RCU_AutoUpgradeAxe",
    delay = 4,
    Step = function()
        safeServiceCall(AxeService, "upgradeAxe")
    end,
})

createIntervalToggle(Trees, {
    Name = "Auto Lumberjack Claim",
    flagName = "AutoLumberjackClaim",
    tag = "RCU_AutoLumberjackClaim",
    delay = 5,
    Step = function()
        safeServiceCall(LumberjackService, "claim")
    end,
})

createIntervalToggle(Trees, {
    Name = "Auto Lumberjack Upgrade / Buy",
    flagName = "AutoLumberjackUpgrade",
    tag = "RCU_AutoLumberjackUpgrade",
    delay = 6,
    Step = function()
        safeServiceCall(LumberjackService, "upgrade")
        task.wait(0.2)
        safeServiceCall(LumberjackService, "buyLumberjack")
    end,
})

----------------------------------------------------------------------
-- Mining / Ores
----------------------------------------------------------------------

Mining:createLabel({
    Name = "Mine Rooms",
    Special = true,
})

mineRoomDropdown = Mining:createDropdown({
    Name = "Mine Room",
    flagName = "MineRoom",
    List = getOreRooms(),
    Flag = { "Any" },
    Callback = function(value)
        print("Mine room:", firstValue(value))
    end,
})

Mining:createButton({
    Name = "Refresh Mine Rooms",
    Callback = function()
        mineRoomDropdown:updateList(getOreRooms())
    end,
})

Mining:createButton({
    Name = "Teleport to Selected Mine Room",
    Callback = function()
        teleportToSelectedMineRoom()
    end,
})

Mining:createLabel({
    Name = "Ore Farming",
    Special = true,
})

createIntervalToggle(Mining, {
    Name = "Auto Mine Ores (Walking / Controller)",
    flagName = "AutoMineOres",
    tag = "RCU_AutoMineOres",
    delay = 0.35,
    Step = function()
        mineOre(false)
    end,
})

createIntervalToggle(Mining, {
    Name = "Auto Mine Ores (Teleport, Risky)",
    Warning = function()
        return "Teleport mining can be obvious. Use walking/VersusAI mode when possible."
    end,
    WarnIf = function() return true end,
    flagName = "AutoMineOresTeleport",
    tag = "RCU_AutoMineOresTeleport",
    delay = 0.5,
    Step = function()
        mineOre(true)
    end,
})

Mining:createLabel({
    Name = "Tools / Quests",
    Special = true,
})

createIntervalToggle(Mining, {
    Name = "Auto Upgrade Pickaxe",
    flagName = "AutoUpgradePickaxe",
    tag = "RCU_AutoUpgradePickaxe",
    delay = 4,
    Step = function()
        safeServiceCall(PickaxeService, "upgradePickaxe")
    end,
})


createIntervalToggle(Mining, {
    Name = "Auto Buy Mine Upgrades",
    flagName = "AutoBuyMineUpgrades",
    tag = "RCU_AutoBuyMineUpgrades",
    delay = 4,
    Step = function()
        buyMineUpgradesBatch(10)
    end,
})

createIntervalToggle(Mining, {
    Name = "Auto Use Pickaxe Rune",
    flagName = "AutoUsePickaxeRune",
    tag = "RCU_AutoUsePickaxeRune",
    delay = 8,
    Step = function()
        safeServiceCall(PickaxeService, "usePickaxeRune")
    end,
})

createIntervalToggle(Mining, {
    Name = "Auto Miner Quests",
    flagName = "AutoMinerQuests",
    tag = "RCU_AutoMinerQuests",
    delay = 1.5,
    Step = runMinerQuestStep,
})


----------------------------------------------------------------------
-- Gardening
----------------------------------------------------------------------

Gardening:createLabel({
    Name = "Planting",
    Special = true,
})

createIntervalToggle(Gardening, {
    Name = "Auto Plant Seeds",
    flagName = "AutoPlantGardenSeeds",
    tag = "RCU_AutoPlantGardenSeeds",
    delay = 2,
    Step = function()
        autoPlantGardenSeedsStep(6)
    end,
})

Gardening:createLabel({
    Name = "Ready Plants",
    Special = true,
})

createIntervalToggle(Gardening, {
    Name = "Auto Claim Ready Plants",
    flagName = "AutoClaimReadyGardenPlants",
    tag = "RCU_AutoClaimReadyGardenPlants",
    delay = 2,
    Step = function()
        claimReadyGardenPlantsStep(6)
    end,
})


----------------------------------------------------------------------
-- Fishing
----------------------------------------------------------------------

Fishing:createLabel({
    Name = "Fishing Bays",
    Special = true,
})

fishingBayDropdown = Fishing:createDropdown({
    Name = "Fishing Bay",
    flagName = "SelectedFishingBay",
    List = getFishingBayOptions(),
    Flag = { getFishingBayOptions()[1] or "None" },
    Callback = function(value)
        print("Fishing bay:", getFirstSelectedDropdownValue(value, "None"))
    end,
})

Fishing:createButton({
    Name = "Refresh Fishing Bays",
    Callback = function()
        fishingBayDropdown:updateList(getFishingBayOptions())
    end,
})

Fishing:createButton({
    Name = "Set Selected Fishing Bay",
    Callback = function()
        setSelectedFishingBay()
    end,
})

Fishing:createButton({
    Name = "Teleport to Nearest Fishing Zone",
    Callback = function()
        if not moveNearFishingZone() then
            notify("Fishing Zone Missing", "I couldn't find a streamed fishing zone in the current area.", "warning")
        end
    end,
})

createIntervalToggle(Fishing, {
    Name = "Auto Unlock Fishing Bay",
    flagName = "AutoUnlockFishingBay",
    tag = "RCU_AutoUnlockFishingBay",
    delay = 8,
    Step = function()
        autoUnlockFishingBaysStep(1)
    end,
})

Fishing:createLabel({
    Name = "Rod / Catching",
    Special = true,
})

Fishing:createToggle({
    Name = "Auto Fish",
    Flag = false,
    flagName = "AutoFish",
    Callback = function(enabled)
        Library:CleanupConnectionsByTag("RCU_AutoFish")
        safeServiceCall(FishingService, "setIsAutoFishing", enabled == true)
        if not enabled then
            if FishingController and FishingController.stopFishing then
                safeControllerCall(FishingController, "stopFishing")
            else
                safeServiceCall(FishingService, "stopFishing")
            end
            return
        end
        interval("RCU_AutoFish", "AutoFish", 0.35, autoFishStep)
    end,
})

createIntervalToggle(Fishing, {
    Name = "Auto Upgrade Fishing Rod",
    flagName = "AutoUpgradeFishingRod",
    tag = "RCU_AutoUpgradeFishingRod",
    delay = 5,
    Step = function()
        safeServiceCall(FishingRodService, "upgradeFishingRod")
    end,
})


createIntervalToggle(Fishing, {
    Name = "Auto Buy Fishing Upgrades",
    flagName = "AutoBuyFishingUpgrades",
    tag = "RCU_AutoBuyFishingUpgrades",
    delay = 5,
    Step = function()
        buyFishingUpgradesBatch(10)
    end,
})

Fishing:createLabel({
    Name = "Fish Index",
    Special = true,
})

createIntervalToggle(Fishing, {
    Name = "Auto Claim Fish Index Rewards",
    flagName = "AutoClaimFishIndexRewards",
    tag = "RCU_AutoClaimFishIndexRewards",
    delay = 15,
    Step = function()
        claimFishIndexRewardsStep(8)
    end,
})

Fishing:createLabel({
    Name = "Fish Selling",
    Special = true,
})

fishSellRarityDropdown = Fishing:createDropdown({
    Name = "Auto Sell Fish Rarities",
    flagName = "AutoSellFishRarities",
    List = getFishingSellRarityOptions(),
    Flag = { "Common" },
    multi = true,
    Callback = function(value)
        print("Auto sell fish rarities:", table.concat(readSelectedDropdownValues(value), ", "))
    end,
})

Fishing:createToggle({
    Name = "Don't Sell Fishing Rod Upgrade Fish",
    Flag = true,
    flagName = "ProtectFishingRodUpgradeFish",
    Callback = function(enabled)
        print("Protect fishing rod upgrade fish:", enabled)
    end,
})

createIntervalToggle(Fishing, {
    Name = "Auto Sell Selected Fish Rarities",
    flagName = "AutoSellSelectedFishRarities",
    tag = "RCU_AutoSellSelectedFishRarities",
    delay = 4,
    Step = function()
        autoSellSelectedFishRaritiesStep(80)
    end,
})


----------------------------------------------------------------------
-- Dungeon
----------------------------------------------------------------------

Dungeon:createLabel({
    Name = "Dungeon",
    Special = true,
})

dungeonTicketLabel = Dungeon:createLabel({
    Name = "Dungeon Tickets: scanning...",
    Special = true,
})
startDungeonTicketLabelUpdater()

local dungeonModeOptions = getDungeonGamemodeOptions()
dungeonModeDropdown = Dungeon:createDropdown({
    Name = "Dungeon Mode",
    flagName = "SelectedDungeonMode",
    List = dungeonModeOptions,
    Flag = { dungeonModeOptions[1] or "1. Basic (1 tickets)" },
    Callback = function(value)
        print("Selected dungeon mode:", firstValue(value))
    end,
})

Dungeon:createButton({
    Name = "Refresh Dungeon Modes",
    Callback = function()
        dungeonModeDropdown:updateList(getDungeonGamemodeOptions())
    end,
})

Dungeon:createButton({
    Name = "Start Selected Dungeon",
    Callback = function()
        if startSelectedDungeon() then
            notify("Dungeon Started", "Started the selected dungeon mode.", "info")
        else
            notify("Dungeon Not Started", "You may already be in a dungeon, have no tickets, or the service rejected the start request.", "warning")
        end
    end,
})

createIntervalToggle(Dungeon, {
    Name = "Auto Join Dungeon",
    flagName = "AutoJoinDungeon",
    tag = "RCU_AutoJoinDungeon",
    delay = 3,
    Step = startSelectedDungeon,
})

createIntervalToggle(Dungeon, {
    Name = "Auto Critical Tap / Damage",
    flagName = "AutoDungeonDamage",
    tag = "RCU_AutoDungeonDamage",
    delay = 0.15,
    Step = autoDungeonDamageStep,
})

createIntervalToggle(Dungeon, {
    Name = "Auto Pickup Dungeon Powerups",
    flagName = "AutoDungeonPowerups",
    tag = "RCU_AutoDungeonPowerups",
    delay = 2,
    Step = autoPickupDungeonPowerupsStep,
})

createIntervalToggle(Dungeon, {
    Name = "Auto Equip Best Dungeon Pets",
    flagName = "AutoEquipBestDungeonPets",
    tag = "RCU_AutoEquipBestDungeonPets",
    delay = 5,
    Step = autoEquipBestDungeonPetsStep,
})

local dungeonShopOptions = getDungeonShopOptions()
dungeonShopDropdown = Dungeon:createDropdown({
    Name = "Dungeon Shop Item",
    flagName = "SelectedDungeonShopItem",
    List = dungeonShopOptions,
    Flag = { "Any Affordable" },
    Callback = function(value)
        print("Selected dungeon shop item:", firstValue(value))
    end,
})

Dungeon:createButton({
    Name = "Refresh Dungeon Shop Items",
    Callback = function()
        dungeonShopDropdown:updateList(getDungeonShopOptions())
    end,
})

createIntervalToggle(Dungeon, {
    Name = "Auto Buy Dungeon Shop Item",
    flagName = "AutoBuyDungeonShopItem",
    tag = "RCU_AutoBuyDungeonShopItem",
    delay = 5,
    Step = buySelectedDungeonShopItemStep,
})

local dungeonUpgradeOptions = getDungeonUpgradeOptions()
dungeonUpgradeDropdown = Dungeon:createDropdown({
    Name = "Dungeon Upgrade",
    flagName = "SelectedDungeonUpgrade",
    List = dungeonUpgradeOptions,
    Flag = { "Cheapest Affordable" },
    Callback = function(value)
        print("Selected dungeon upgrade:", firstValue(value))
    end,
})

Dungeon:createButton({
    Name = "Refresh Dungeon Upgrades",
    Callback = function()
        dungeonUpgradeDropdown:updateList(getDungeonUpgradeOptions())
    end,
})

createIntervalToggle(Dungeon, {
    Name = "Auto Buy Dungeon Upgrade",
    flagName = "AutoBuyDungeonUpgrade",
    tag = "RCU_AutoBuyDungeonUpgrade",
    delay = 3,
    Step = buySelectedDungeonUpgradeStep,
})

Dungeon:createButton({
    Name = "Apply Dungeon Crash Fixes",
    Callback = function()
        if applyDungeonCrashFixes() then
            notify("Dungeon Fixes Applied", "Powerup and boss-spawn crash guards are active.", "info")
        else
            notify("Dungeon Fix Failed", "DungeonController is not loaded yet.", "warning")
        end
    end,
})

Dungeon:createToggle({
    Name = "Keep HUD Visible In Dungeon",
    Flag = false,
    flagName = "KeepDungeonHUDVisible",
    Callback = function(enabled)
        setDungeonHudVisibleOverride(enabled)
    end,
})

Dungeon:createToggle({
    Name = "Stop Dungeon Screen Shakes",
    Flag = false,
    flagName = "StopDungeonScreenShakes",
    Callback = function(enabled)
        setDungeonScreenShakeOverride(enabled)
    end,
})

Dungeon:createToggle({
    Name = "Prevent Dungeon End Teleport",
    Warning = function()
        return "Only use this with Auto Join Dungeon, otherwise you can stay stuck in the dungeon room after it ends."
    end,
    WarnIf = function() return true end,
    Flag = false,
    flagName = "PreventDungeonEndTeleport",
    Callback = function(enabled)
        setDungeonEndTeleportOverride(enabled)
    end,
})

Dungeon:createToggle({
    Name = "Visually Hide Dungeon Pets",
    Flag = false,
    flagName = "HideDungeonPetsVisual",
    Callback = function(enabled)
        setDungeonPetVisualOverride(enabled)
    end,
})

----------------------------------------------------------------------
-- Eggs & Pets
----------------------------------------------------------------------

closestEggLabel = Eggs:createLabel({
    Name = "Closest Egg: scanning...",
    Special = true,
})
startClosestEggLabelUpdater()

eggDropdown = Eggs:createDropdown({
    Name = "Selected Egg",
    flagName = "SelectedEgg",
    List = getEggNames(false),
    Flag = { "Basic" },
    Callback = function(value)
        print("Selected egg:", getFirstSelectedDropdownValue(value, "None"))
    end,
})

Eggs:createButton({
    Name = "Refresh Eggs",
    Callback = function()
        eggDropdown:updateList(getEggNames(false))
    end,
})

Eggs:createToggle({
    Name = "Disable Hatch Animation",
    Flag = false,
    flagName = "NoHatchAnimation",
    Callback = function(enabled)
        if not HatchingController then return end
        HatchingController._RCUOriginalPlayEggAnimation = HatchingController._RCUOriginalPlayEggAnimation or HatchingController.playEggAnimation
        if enabled then
            HatchingController.playEggAnimation = function() end
        elseif HatchingController._RCUOriginalPlayEggAnimation then
            HatchingController.playEggAnimation = HatchingController._RCUOriginalPlayEggAnimation
        end
    end,
})

Eggs:createToggle({
    Name = "Use Triple Hatch Mode",
    Flag = true,
    flagName = "OpenTripleEggs",
    Callback = function() end,
})

Eggs:createToggle({
    Name = "Only Hatch Global Luck Egg Variants",
    Warning = function()
        return "When enabled, auto hatch will ignore normal eggs and only hatch the spawned global lucky egg variants. If no global luck egg is active, hatching pauses instead of buying the normal selected egg.\n\nYou will still need to toggle on an auto egg, as this is just an option."
    end,
    WarnIf = function() return true end,
    Flag = false,
    flagName = "OnlyHatchGlobalLuckEggs",
    Callback = function() end,
})

createIntervalToggle(Eggs, {
    Name = "Auto Hatch Selected Egg",
    flagName = "AutoHatchSelectedEgg",
    tag = "RCU_AutoHatchSelectedEgg",
    delay = 0.35,
    Step = function()
        local selectedEgg = getFirstSelectedDropdownValue(Library.Flags["SelectedEgg"], "None")
        local eggName, eggModel = resolveEggSelection(selectedEgg)
        if eggName and eggName ~= "None" then
            openEgg(eggName, eggModel)
        end
    end,
})

createIntervalToggle(Eggs, {
    Name = "Auto Hatch Best Affordable Egg",
    flagName = "AutoHatchBestEgg",
    tag = "RCU_AutoHatchBestEgg",
    delay = 0.5,
    Step = function()
        local eggName = getBestEggName()
        if eggName then openEgg(eggName) end
    end,
})


createIntervalToggle(Eggs, {
    Name = "Auto Hatch Index Pets / Eggs",
    flagName = "AutoHatchIndexPets",
    tag = "RCU_AutoHatchIndexPets",
    delay = 0.5,
    Step = autoHatchIndexPetsStep,
})

createIntervalToggle(Eggs, {
    Name = "Auto Hatch Nearest Egg",
    flagName = "AutoHatchNearestEgg",
    tag = "RCU_AutoHatchNearestEgg",
    delay = 0.5,
    Step = function()
        local eggName, eggModel = getNearestEggName()
        if eggName then openEgg(eggName, eggModel) end
    end,
})

petAutoEquipTeamDropdown = Eggs:createDropdown({
    Name = "Auto Equip Pets Team",
    flagName = "SelectedAutoEquipPetTeam",
    List = AUTO_EQUIP_PET_TEAM_OPTIONS,
    Flag = { "All Teams" },
    Callback = function(value)
        print("Selected auto equip team:", getFirstSelectedDropdownValue(value, "All Teams"))
    end,
})

createIntervalToggle(Eggs, {
    Name = "Auto Equip Best Pets (every 5 minutes)",
    flagName = "AutoEquipBestPets",
    tag = "RCU_AutoEquipBestPets",
    delay = 300,
    Step = autoEquipBestPetsStep,
})

createIntervalToggle(Eggs, {
    Name = "Auto Craft Pets",
    flagName = "AutoCraftPets",
    tag = "RCU_AutoCraftPets",
    delay = 6,
    Step = function()
        local data = getData()
        if not data or type(data.pets) ~= "table" then return end
        local done = 0
        for petId in pairs(data.pets) do
            safeServiceCall(PetService, "craft", { petId }, true)
            done = done + 1
            task.wait(0.1)
            if done >= 20 then break end
        end
    end,
})

Eggs:createLabel({
    Name = "Pet Adventures",
    Special = true,
})

createIntervalToggle(Eggs, {
    Name = "Auto Claim Pet Adventures",
    flagName = "AutoClaimPetAdventures",
    tag = "RCU_AutoClaimPetAdventures",
    delay = 10,
    Step = autoClaimPetAdventuresStep,
})

createIntervalToggle(Eggs, {
    Name = "Auto Start Pet Adventures (best pets)",
    flagName = "AutoStartPetAdventures",
    tag = "RCU_AutoStartPetAdventures",
    delay = 30,
    Step = autoStartPetAdventureStep,
})

createIntervalToggle(Eggs, {
    Name = "Auto Buy Pet Adventure Upgrades (compasses)",
    flagName = "AutoBuyPetAdventureUpgrades",
    tag = "RCU_AutoBuyPetAdventureUpgrades",
    delay = 15,
    Step = buyPetAdventureUpgradesStep,
})

Eggs:createButton({
    Name = "Cancel All Pet Adventures",
    Warning = function() return "Cancels every running Pet Adventure. Rewards are lost." end,
    WarnIf = function() return true end,
    Callback = cancelAllPetAdventuresStep,
})

Eggs:createLabel({
    Name = "Tap Skins & Orbs",
    Special = true,
})

tapOrbDropdown = Eggs:createDropdown({
    Name = "Tap Orbs to Open",
    flagName = "SelectedTapOrbs",
    List = getTapOrbOptions(),
    Flag = {},
    multi = true,
    Callback = function() end,
})

Eggs:createButton({
    Name = "Refresh Tap Orbs",
    Callback = function()
        tapOrbDropdown:updateList(getTapOrbOptions())
    end,
})

createIntervalToggle(Eggs, {
    Name = "Auto Open Tap Orbs",
    flagName = "AutoOpenTapOrbs",
    tag = "RCU_AutoOpenTapOrbs",
    delay = 6,
    Step = openOwnedTapOrbsStep,
})

tapSkinForgeDropdown = Eggs:createDropdown({
    Name = "Tap Skins to Forge",
    flagName = "SelectedTapSkinsToForge",
    List = getTapSkinOptions(),
    Flag = {},
    multi = true,
    Callback = function() end,
})

Eggs:createButton({
    Name = "Refresh Tap Skins",
    Callback = function()
        tapSkinForgeDropdown:updateList(getTapSkinOptions())
    end,
})

createIntervalToggle(Eggs, {
    Name = "Auto Forge Selected Tap Skins",
    flagName = "AutoForgeTapSkins",
    tag = "RCU_AutoForgeTapSkins",
    delay = 15,
    Step = forgeSelectedTapSkinsStep,
})

createIntervalToggle(Eggs, {
    Name = "Auto Equip Best Tap Skin",
    flagName = "AutoEquipBestTapSkin",
    tag = "RCU_AutoEquipBestTapSkin",
    delay = 60,
    Step = equipBestTapSkinStep,
})

Eggs:createLabel({
    Name = "Supreme Altar",
    Special = true,
})

createIntervalToggle(Eggs, {
    Name = "Auto Sacrifice Special Pets",
    Warning = function() return "Permanently sacrifices special (non-tradeable-protected) pets to the Supreme Altar for trade tokens. Equipped pets are skipped." end,
    WarnIf = function() return true end,
    flagName = "AutoSacrificeSpecialPets",
    tag = "RCU_AutoSacrificeSpecialPets",
    delay = 20,
    Step = sacrificeSupremeAltarPetsStep,
})

Eggs:createLabel({
    Name = "Exclusive Eggs",
    Special = true,
})

createIntervalToggle(Eggs, {
    Name = "Auto Open Exclusive Eggs",
    flagName = "AutoOpenExclusiveEggs",
    tag = "RCU_AutoOpenExclusiveEggs",
    delay = 15,
    Step = openOwnedExclusiveEggsStep,
})

----------------------------------------------------------------------
-- Rewards
----------------------------------------------------------------------

createIntervalToggle(Rewards, {
    Name = "Auto Claim Chests",
    flagName = "AutoClaimChests",
    tag = "RCU_AutoClaimChests",
    delay = 15,
    Step = claimAllChests,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Mini Chests",
    flagName = "AutoClaimMiniChests",
    tag = "RCU_AutoClaimMiniChests",
    delay = 10,
    Step = claimAllMiniChests,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Playtime Rewards",
    flagName = "AutoClaimPlaytime",
    tag = "RCU_AutoClaimPlaytime",
    delay = 8,
    Step = claimPlaytimeRewards,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Daily Reward",
    flagName = "AutoClaimDailyReward",
    tag = "RCU_AutoClaimDailyReward",
    delay = 30,
    Step = function()
        safeServiceCall(RewardService, "claimDailyReward")
    end,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Supporter Pack",
    flagName = "AutoClaimSupporterPack",
    tag = "RCU_AutoClaimSupporterPack",
    delay = 10,
    Step = function()
        safeServiceCall(RewardService, "claimSupporterPack")
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 7390-7391)
    end,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Achievements",
    flagName = "AutoClaimAchievements",
    tag = "RCU_AutoClaimAchievements",
    delay = 20,
    Step = claimAchievements,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Index Rewards",
    flagName = "AutoClaimIndexRewards",
    tag = "RCU_AutoClaimIndexRewards",
    delay = 25,
    Step = claimIndexRewards,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Prestige",
    flagName = "AutoClaimPrestige",
    tag = "RCU_AutoClaimPrestige",
    delay = 30,
    Step = function()
        safeServiceCall(PrestigeService, "claim")
    end,
})

createIntervalToggle(Rewards, {
    Name = "Auto Claim Classic Quests",
    flagName = "AutoClaimClassicQuests",
    tag = "RCU_AutoClaimClassicQuests",
    delay = 15,
    Step = function()
        local data = getData()
        local quests = data and (data.classicQuests or data.quests or data.mapQuests)
        if type(quests) ~= "table" then return end
        for questId in pairs(quests) do
            safeServiceCall(ClassicService, "claimQuest", questId)
            task.wait(0.1)
        end
    end,
})

----------------------------------------------------------------------
-- Inventory
----------------------------------------------------------------------

createIntervalToggle(Inventory, {
    Name = "Auto Use Boxes / Crates",
    flagName = "AutoUseBoxes",
    tag = "RCU_AutoUseBoxes",
    delay = 6,
    Step = function()
        useInventoryItems({ "box", "crate" }, 12)
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Use Fruits",
    flagName = "AutoUseFruits",
    tag = "RCU_AutoUseFruits",
    delay = 8,
    Step = function()
        useInventoryItems({ "fruit", "apple", "carrot", "grape", "strawberry" }, 12)
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Use Potions",
    flagName = "AutoUsePotions",
    tag = "RCU_AutoUsePotions",
    delay = 10,
    Step = function()
        useInventoryItems({ "potion" }, 10)
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Use Aura Dice",
    flagName = "AutoUseAuraDice",
    tag = "RCU_AutoUseAuraDice",
    delay = 8,
    Step = function()
        useInventoryItems({ "dice", "aura" }, 10)
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Roll Auras",
    flagName = "AutoRollAuras",
    tag = "RCU_AutoRollAuras",
    delay = 0.8,
    Step = function()
        safeServiceCall(AuraService, "roll")
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Craft Aura Dice",
    flagName = "AutoCraftAuraDice",
    tag = "RCU_AutoCraftAuraDice",
    delay = 10,
    Step = function()
        safeServiceCall(AuraService, "craftDice")
    end,
})

smoothieDropdown = Inventory:createDropdown({
    Name = "Selected Smoothie",
    flagName = "SelectedSmoothie",
    List = getSmoothieNames(),
    Flag = { "insaneSmoothie" },
    Callback = function(value)
        print("Selected smoothie:", firstValue(value))
    end,
})

Inventory:createButton({
    Name = "Refresh Smoothies",
    Callback = function()
        smoothieDropdown:updateList(getSmoothieNames())
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Craft Selected Smoothie",
    flagName = "AutoCraftSelectedSmoothie",
    tag = "RCU_AutoCraftSelectedSmoothie",
    delay = 5,
    Step = craftSelectedSmoothie,
})


createIntervalToggle(Inventory, {
    Name = "Auto Craft Rings",
    flagName = "AutoCraftRings",
    tag = "RCU_AutoCraftRings",
    delay = 8,
    Step = function()
        autoCraftRingsBatch(3, true)
    end,
})

totemDropdown = Inventory:createDropdown({
    Name = "Selected Totem",
    flagName = "SelectedTotem",
    List = getTotemNames(),
    Flag = { "insaneTotem" },
    Callback = function(value)
        print("Selected totem:", firstValue(value))
    end,
})

Inventory:createButton({
    Name = "Refresh Totems",
    Callback = function()
        totemDropdown:updateList(getTotemNames())
    end,
})

createIntervalToggle(Inventory, {
    Name = "Auto Place Selected Totem",
    flagName = "AutoPlaceSelectedTotem",
    tag = "RCU_AutoPlaceSelectedTotem",
    delay = 12,
    Step = placeSelectedTotemIfNeeded,
})

----------------------------------------------------------------------
-- Hive
----------------------------------------------------------------------

createIntervalToggle(Hive, {
    Name = "Auto Collect Honey",
    flagName = "AutoCollectHoney",
    tag = "RCU_AutoCollectHoney",
    delay = 5,
    Step = function()
        safeServiceCall(HiveService, "collectHoney")
    end,
})

createIntervalToggle(Hive, {
    Name = "Auto Buy Hive Upgrades",
    flagName = "AutoBuyHiveUpgrades",
    tag = "RCU_AutoBuyHiveUpgrades",
    delay = 6,
    Step = function()
        for upgradeId in pairs(HiveUpgrades) do
            safeServiceCall(HiveService, "buyHiveUpgrade", upgradeId)
            task.wait(0.1)
        end
    end,
})

createIntervalToggle(Hive, {
    Name = "Auto Buy Honey Shop",
    flagName = "AutoBuyHoneyShop",
    tag = "RCU_AutoBuyHoneyShop",
    delay = 8,
    Step = function()
        for itemId in pairs(HoneyShopList) do
            safeServiceCall(HiveService, "buyHoneyShop", itemId)
            task.wait(0.1)
        end
    end,
})

createIntervalToggle(Hive, {
    Name = "Auto Buy Honey Merchant",
    flagName = "AutoBuyHoneyMerchant",
    tag = "RCU_AutoBuyHoneyMerchant",
    delay = 10,
    Step = function()
        for itemId in pairs(HoneyMerchantList) do
            safeServiceCall(HiveService, "buyHoneyMerchant", itemId)
            task.wait(0.1)
        end
    end,
})

createIntervalToggle(Hive, {
    Name = "Auto Open Bee Capsules",
    flagName = "AutoOpenBeeCapsules",
    tag = "RCU_AutoOpenBeeCapsules",
    delay = 3,
    Step = function()
        for capsuleId in pairs(BeeTypes) do
            safeServiceCall(HiveService, "openCapsule", capsuleId)
            task.wait(0.1)
        end
    end,
})

createIntervalToggle(Hive, {
    Name = "Auto Claim Bee Index Rewards",
    flagName = "AutoClaimBeedex",
    tag = "RCU_AutoClaimBeedex",
    delay = 15,
    Step = function()
        claimBeeIndexRewardsStep(8)
    end,
})

createIntervalToggle(Hive, {
    Name = "Auto Put Best Bees In Hive",
    flagName = "AutoPutBestBeesInHive",
    tag = "RCU_AutoPutBestBeesInHive",
    delay = 15,
    Step = autoPutBestBeesInHiveStep,
})

----------------------------------------------------------------------
-- Events / rotating content
----------------------------------------------------------------------

Events:createLabel({
    Name = "Season " .. tostring(getCurrentSeasonNumber()),
    Special = true,
})

createIntervalToggle(Events, {
    Name = "Auto Claim Season " .. tostring(getCurrentSeasonNumber()) .. " Pass Rewards",
    flagName = "AutoClaimSeason9PassRewards",
    tag = "RCU_AutoClaimSeason9PassRewards",
    delay = 5,
    Step = function()
        claimCurrentSeasonPassRewardsStep(12)
    end,
})

createIntervalToggle(Events, {
    Name = "Auto Reset Season " .. tostring(getCurrentSeasonNumber()) .. " Pass",
    flagName = "AutoResetSeason9Pass",
    tag = "RCU_AutoResetSeason9Pass",
    delay = 8,
    Step = resetCurrentSeasonPassStep,
})

createIntervalToggle(Events, {
    Name = "Auto Season " .. tostring(getCurrentSeasonNumber()) .. " Quests",
    flagName = "AutoSeason9Quests",
    tag = "RCU_AutoSeason9Quests",
    delay = 2,
    Step = runCurrentSeasonQuestStep,
})

Events:createLabel({
    Name = "Quest Machine",
    Special = true,
})

createIntervalToggle(Events, {
    Name = "Auto Claim Quest Machine Rewards",
    flagName = "AutoClaimQuestMachineRewards",
    tag = "RCU_AutoClaimQuestMachineRewards",
    delay = 10,
    Step = claimQuestMachineRewardsStep,
})

Events:createLabel({
    Name = "Clan",
    Special = true,
})

clanAchievementDropdown = Events:createDropdown({
    Name = "Clan Achievements to Claim",
    flagName = "SelectedClanAchievements",
    List = getClanAchievementOptions(),
    Flag = {},
    multi = true,
    Callback = function() end,
})

Events:createButton({
    Name = "Refresh Clan Achievements",
    Callback = function()
        clanAchievementDropdown:updateList(getClanAchievementOptions())
    end,
})

createIntervalToggle(Events, {
    Name = "Auto Claim Clan Achievements",
    flagName = "AutoClaimClanAchievements",
    tag = "RCU_AutoClaimClanAchievements",
    delay = 60,
    Step = autoClaimClanAchievementsStep,
})

createIntervalToggle(Events, {
    Name = "Auto Claim Clan Prestige",
    flagName = "AutoClaimClanPrestige",
    tag = "RCU_AutoClaimClanPrestige",
    delay = 60,
    Step = autoClaimClanPrestigeStep,
})

createIntervalToggle(Events, {
    Name = "Auto Activate Clan Weather",
    flagName = "AutoActivateClanWeather",
    tag = "RCU_AutoActivateClanWeather",
    delay = 3600,
    Step = activateClanWeatherStep,
})

createIntervalToggle(Events, {
    Name = "Auto Spin Clan Boost Wheel",
    flagName = "AutoSpinClanBoostWheel",
    tag = "RCU_AutoSpinClanBoostWheel",
    delay = 3600,
    Step = autoSpinClanBoostWheelStep,
})

createIntervalToggle(Events, {
    Name = "Auto Claim Grow Your Tutel Pet",
    flagName = "AutoClaimGrowYourTutelPet",
    tag = "RCU_AutoClaimGrowYourTutelPet",
    delay = 60,
    Step = claimGrowYourTutelPetStep,
})

Events:createLabel({
    Name = "Game's hourly events",
    Special = true,
})

createIntervalToggle(Events, {
    Name = "Auto Falling Stars",
    flagName = "AutoFallingStars",
    tag = "RCU_AutoFallingStars",
    delay = 1.5,
    Step = function()
        for _, star in ipairs(CollectionService:GetTagged("FallingStar")) do
            safeServiceCall(FallingStarsService, "claimStar", star.Name)
            task.wait(0.05)
        end
    end,
})

createIntervalToggle(Events, {
    Name = "Auto Farm Meteors",
    flagName = "AutoFarmMeteors",
    tag = "RCU_AutoFarmMeteors",
    delay = 0.25,
    Step = autoFarmMeteorsStep,
})

createIntervalToggle(Events, {
    Name = "Auto Open Supply Drops",
    flagName = "AutoOpenSupplyDrops",
    tag = "RCU_AutoOpenSupplyDrops",
    delay = 1,
    Step = autoOpenSupplyDropsStep,
})

----------------------------------------------------------------------
-- Webhooks
----------------------------------------------------------------------

Library.Flags.RCUWebhookRarePets = true
Library.Flags.RCUWebhookRareItems = true
Library.Flags.RCUWebhookDailySummary = true
Library.Flags.RCUWebhookNormalDrops = true
Library.Flags.RCUWebhookBackendArt = true
Library.Flags.RCUWebhookMinPetRarity = 5
Library.Flags.RCUWebhookMinItemRarity = 5
Library.Flags.RCUWebhookExcludedItemRarities = Library.Flags.RCUWebhookExcludedItemRarities or { "Common", "Uncommon", "Rare" }
Library.Flags.RCUWebhookExcludedPetRarities = Library.Flags.RCUWebhookExcludedPetRarities or { "Common", "Uncommon", "Rare" }
Library.Flags.RCUWebhookFooter = "VERSUS AIRLINES • RCU Report"

Webhooks:createInputBox({
    Name = "Discord Webhook URL",
    flagName = "RCUWebhookUrl",
    Flag = "",
    Callback = function()
        refreshRCUWebhookTrackingHooks()
        setupRCUDailySummaryInterval(true)
    end,
})

Webhooks:createDropdown({
    Name = "Exclude Item Embed Rarities",
    flagName = "RCUWebhookExcludedItemRarities",
    multi = true,
    List = WEBHOOK_RARITY_OPTIONS,
    Flag = WEBHOOK_DEFAULT_EXCLUDED_RARITIES,
    Callback = function(value)
        Library.Flags.RCUWebhookExcludedItemRarities = value
    end,
})

Webhooks:createDropdown({
    Name = "Exclude Pet Embed Rarities",
    flagName = "RCUWebhookExcludedPetRarities",
    multi = true,
    List = WEBHOOK_RARITY_OPTIONS,
    Flag = WEBHOOK_DEFAULT_EXCLUDED_RARITIES,
    Callback = function(value)
        Library.Flags.RCUWebhookExcludedPetRarities = value
    end,
})

Webhooks:createButton({
    Name = "Send Daily Summary Test",
    Callback = function()
        if sendRCUDailySummaryWebhook(true) then
            notify("Webhook Sent", "RCU daily summary test sent.", "info")
        end
    end,
})

-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 7771-7790)

Webhooks:createButton({
    Name = "Send Insane Smoothie Image Test",
    Callback = function()
        sendRareDropWebhook({
            Class = "smoothie",
            Name = "Insane Smoothie",
            Rarity = "Eternal",
            RarityRank = getRarityRankFromName("Eternal"),
            Amount = 1,
            ItemId = "insaneSmoothie",
            Icon = "rbxassetid://115038451135501",
            Description = "+100% Clicks, Luck, Gems; +15% Hatch; +1% Golden; +0.75% Shiny; +0.2% Toxic; +1 Egg Open",
            Effect = "+100% Clicks/Luck/Gems",
            Duration = "30m",
            Tier = "Insane",
        }, "Webhook test", true)
    end,
})

Webhooks:createButton({
    Name = "Send Closest Egg Info Webhook",
    Callback = function()
        local fields, title = buildClosestEggInfoFields()
        if sendRCUWebhook("rcu_egg_info", title, fields, {
            Description = "Closest visible egg, global/special spawn metadata, model attributes, cost, and hatchable pet table.",
        }, false) then
            notify("Webhook Sent", "Closest egg info sent.", "info")
        else
            notify("Webhook Not Sent", "Paste a Discord webhook URL first.", "warning")
        end
    end,
})

refreshRCUWebhookTrackingHooks()
setupRCUDailySummaryInterval(true)

----------------------------------------------------------------------
-- Mounts
----------------------------------------------------------------------

Mounts:createLabel({
    Name = "Mounts",
    Special = true,
})

mountDropdown = Mounts:createDropdown({
    Name = "Selected Mount",
    flagName = "SelectedMount",
    List = getMountNames(),
    Flag = { "None" },
    Callback = function(value)
        print("Selected mount:", firstValue(value))
    end,
})

Mounts:createButton({
    Name = "Refresh Mounts",
    Callback = function()
        mountDropdown:updateList(getMountNames())
    end,
})

Mounts:createButton({
    Name = "Equip Selected Mount (Client Only)",
    Callback = function()
        local selected = firstValue(Library.Flags["SelectedMount"])
        if equipClientMount(selected) then
            notify("Mount Equipped", "Spawned " .. tostring(selected) .. " locally.", "info")
        else
            notify("Mount Missing", "Select a mount first, or wait for MountController to load.", "warning")
        end
    end,
})

Mounts:createButton({
    Name = "Spoof Player Mounts (Client Only)",
    Callback = function()
        local count = spoofAllMountsIntoInventory()
        notify("Mounts Spoofed", "Added " .. tostring(count) .. " client-side mount entries to local data.", "info")
    end,
})

Mounts:createButton({
    Name = "Dismount",
    Callback = function()
        safeServiceCall(MountService, "despawnMount")
        safeControllerCall(MountController, "despawnMount", client)
        safeControllerCall(MountController, "toggleMount")
    end,
})

----------------------------------------------------------------------
-- Misc
----------------------------------------------------------------------

Misc:createButton({
    Name = "Redeem Known Codes",
    Callback = function()
        local knownCodes = {
            "release",
            "Roksek",
            "cave",
            "volcano",
            "heaven",
            "mastery",
            "circus",
            "monkey",
            "gear",
            "sakura",
            "pirate",
            "kraken",
            "lab",
            "rocket",
            "alien",
            "tech",
            "nebula",
            "magic",
            "halloween",
            "thanksgiving",
            "christmas",
            "valentines",
            "easter",
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (line 7914)
            "party",
            "pinata",
            "miner",
            "comet",
            "fall",
            "starfactory",
            "glacier",
            "spider",
            "starfall",
            "blackhole",
            "fishing",
            "garden",
            "cloud",
            "ashwind",
            "forest",
            "ruins",
            "monochrome",
            "heart",
            "lovely",
            "bee",
            "neon",
            "sparkle",
            "thunder",
            "temple",
            "frog",
            "crystal",
            "blossom",
            "tower",
            "mystic",
            "aurora"
        }
        for _, code in ipairs(knownCodes) do
            safeServiceCall(CodesService, "redeem", code)
            task.wait(0.15)
        end
        notify("Codes sent", "Finished trying the local known-code list.", "info")
    end,
})

createIntervalToggle(Misc, {
    Name = "Disable Weather VFX",
    flagName = "DisableWeatherVFX",
    tag = "RCU_DisableWeatherVFX",
    delay = 5,
    Step = function()
        safeControllerCall(WeatherController, "disableWeatherFog")
        safeControllerCall(WeatherController, "toggleParticles", false)
    end,
})

Misc:createButton({
    Name = "Open Skill Tree",
    Callback = function()
        safeControllerCall(SkillTreeController, "openSkillTree")
    end,
})

----------------------------------------------------------------------
-- Developer tools
----------------------------------------------------------------------

DevTools:createButton({
    Name = "Print RCU Data Keys",
    Callback = function()
        local data = getData()
        if not data then
            warn("[RCU] No DataController.data yet")
            return
        end
        print("======== RCU DATA KEYS ========")
        for key, value in pairs(data) do
            print(key, typeof(value), type(value) == "table" and countTable(value) or value)
        end
        print("================================")
    end,
})

DevTools:createButton({
    Name = "Print Visible Tree/Ore Counts",
    Callback = function()
        print("[RCU] Trees:", #CollectionService:GetTagged("Tree"))
        print("[RCU] Ores:", #CollectionService:GetTagged("Ore"))
        print("[RCU] AFK Ores:", #CollectionService:GetTagged("AfkOre"))
        print("[RCU] Ore Rooms:", table.concat(getOreRooms(), ", "))
    end,
})

DevTools:createButton({
    Name = "Print Services Loaded",
    Callback = function()
        local loaded = {
            ClickService = ClickService ~= nil,
            EggService = EggService ~= nil,
            RebirthService = RebirthService ~= nil,
            TreeService = TreeService ~= nil,
            OreService = OreService ~= nil,
            DungeonService = DungeonService ~= nil,
            RewardService = RewardService ~= nil,
            UpgradeService = UpgradeService ~= nil,
            HiveService = HiveService ~= nil,
-- RCU ARCHIVE: moved to old_rcu_stuff.lua (lines 8015-8016)
            TotemService = TotemService ~= nil,
            DataController = DataController ~= nil,
            TreeController = TreeController ~= nil,
            OreController = OreController ~= nil,
            DungeonController = DungeonController ~= nil,
            TotemController = TotemController ~= nil,
        }
        prettyPrint(loaded)
    end,
})

----------------------------------------------------------------------
-- Paradox
----------------------------------------------------------------------

paradoxMerchantDropdown = Paradox:createDropdown({
    Name = "Compass Items",
    flagName = "SelectedParadoxMerchantItems",
    List = getParadoxMerchantOptions(),
    Flag = {},
    multi = true,
    Callback = function() end,
})

Paradox:createButton({
    Name = "Refresh Compass Items",
    Callback = function()
        paradoxMerchantDropdown:updateList(getParadoxMerchantOptions())
    end,
})

createIntervalToggle(Paradox, {
    Name = "Auto Buy Compass Items",
    flagName = "AutoBuyParadoxMerchant",
    tag = "RCU_AutoBuyParadoxMerchant",
    delay = 6,
    Step = autoBuyParadoxMerchantStep,
})

Paradox:createLabel({
    Name = "Compasses are collected by Auto Click (no separate toggle needed).",
})