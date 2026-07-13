-- Ported from a single source into Versus Airlines UI
-- Clean, working, no merged code from multiple sources

local request = (syn and syn.request) or (http and http.request) or http_request

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Camera = Workspace.CurrentCamera

local client = Players.LocalPlayer
local Sec = 0.1
local shouldTween = false
local SoulGuitar = false
local MousePos = Vector3.new()

print("Loading Library...")

local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()

local ui = Library:Setup({
    Location = client.PlayerGui,
    OpenCloseLocation = "Bottom Right"
})

client.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

----------------------------------------------------------------- https://versusairlines.top/developers.html

function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    delayTime = math.max(tonumber(delayTime) or 0.1, 0.05)
    if not Library.Flags[flag] then return end

    local last = 0
    local running = false
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end

        local current = os.clock()
        if running or current - last < delayTime then return end

        last = current
        running = true

        task.spawn(function()
            pcall(callback)
            task.wait()
            running = false
        end)
    end)

    Library:TrackConnection(conn, tag)
end

function notify(title, desc, style)
    Library:createDisplayMessage(title, desc, {
        { text = "OK" },
    }, style or "info")
end

-----------------------------------------------------------------

World1 = game.PlaceId == 2753915549
World2 = game.PlaceId == 4442272183
World3 = game.PlaceId == 7449423635

local function getRoot()
    local char = client.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        return char.HumanoidRootPart
    end
    return nil
end

local function getChar()
    return client.Character
end

local function getHum()
    local char = client.Character
    if char and char:FindFirstChild("Humanoid") then
        return char.Humanoid
    end
    return nil
end

-----------------------------------------------------------------
-- Core utilities
-----------------------------------------------------------------

EquipWeapon = function(text)
    if not text then return end
    if client.Backpack:FindFirstChild(text) then
        local hum = getHum()
        if hum then hum:EquipTool(client.Backpack:FindFirstChild(text)) end
    end
end

weaponSc = function(weapon)
    for _, v in pairs(client.Backpack:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == weapon then
            EquipWeapon(v.Name)
        end
    end
end

GetBP = function(v)
    return client.Backpack:FindFirstChild(v) or (client.Character and client.Character:FindFirstChild(v))
end

GetM = function(Name)
    local result = ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
    if type(result) == "table" then
        for _, tab in pairs(result) do
            if type(tab) == "table" and tab.Type == "Material" and tab.Name == Name then
                return tab.Count
            end
        end
    end
    return 0
end

GetIn = function(Name)
    local result = ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
    if type(result) == "table" then
        for _, v1 in pairs(result) do
            if type(v1) == "table" then
                if v1.Name == Name or (client.Character and client.Character:FindFirstChild(Name)) or client.Backpack:FindFirstChild(Name) then
                    return true
                end
            end
        end
    end
    return false
end

GetWP = function(nametool)
    local result = ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
    if type(result) == "table" then
        for _, v4 in pairs(result) do
            if type(v4) == "table" and v4.Type == "Sword" then
                if v4.Name == nametool or (client.Character and client.Character:FindFirstChild(nametool)) or client.Backpack:FindFirstChild(nametool) then
                    return true
                end
            end
        end
    end
    return false
end

-----------------------------------------------------------------
-- Anti-detection (minimal, safe)
-----------------------------------------------------------------

pcall(function()
    hookfunction(require(ReplicatedStorage.Effect.Container.Death), function() end)
    hookfunction(require(ReplicatedStorage:WaitForChild("GuideModule")).ChangeDisplayedNPC, function() end)
end)

-----------------------------------------------------------------
-- Tween / Teleport
-----------------------------------------------------------------

local block
local function setupBlock()
    local char = getChar()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if not root:FindFirstChild("BodyClip") then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "BodyClip"
        bv.Parent = root
        bv.MaxForce = Vector3.new(100000, 100000, 100000)
        bv.Velocity = Vector3.new(0, 0, 0)
    end
    block = root:FindFirstChild("BodyClip")
end

_tp = function(target)
    local char = getChar()
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = char.HumanoidRootPart
    if not block then setupBlock() end
    if not block then return end
    local distance = (target.Position - rootPart.Position).Magnitude
    local tweenInfo = TweenInfo.new(distance / 300, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(block, tweenInfo, { CFrame = target })
    if char.Humanoid.Sit == true then
        block.CFrame = CFrame.new(block.Position.X, target.Y, block.Position.Z)
    end
    tween:Play()
    task.spawn(function()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if not shouldTween then tween:Cancel(); break end
            task.wait(0.1)
        end
    end)
end

notween = function(p)
    local root = getRoot()
    if root then root.CFrame = p end
end

TeleportToTarget = function(targetCFrame)
    _tp(targetCFrame)
end

-----------------------------------------------------------------
-- Combat system
-----------------------------------------------------------------

local Attack = {}
Attack.Alive = function(model)
    if not model then return end
    local Humanoid = model:FindFirstChild("Humanoid")
    return Humanoid and Humanoid.Health > 0
end

BringEnemy = function()
    if not _B then return end
    local root = getRoot()
    if not root or not PosMon then return end
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v:FindFirstChild("HumanoidRootPart") then
            if (v.HumanoidRootPart.Position - PosMon).Magnitude <= 300 then
                v.HumanoidRootPart.CFrame = CFrame.new(PosMon)
                v.HumanoidRootPart.CanCollide = true
                v.Humanoid.WalkSpeed = 0
                v.Humanoid.JumpPower = 0
                if v.Humanoid:FindFirstChild("Animator") then
                    v.Humanoid.Animator:Destroy()
                end
                pcall(function() client.SimulationRadius = math.huge end)
            end
        end
    end
end

Attack.Kill = function(model, Succes)
    if model and Succes then
        if not model:GetAttribute("Locked") then
            model:SetAttribute("Locked", model.HumanoidRootPart.CFrame)
        end
        PosMon = model:GetAttribute("Locked").Position
        BringEnemy()
        EquipWeapon(Library.Flags.SelectWeapon or "Melee")
        local Equipped = client.Character and client.Character:FindFirstChildOfClass("Tool")
        local ToolTip = Equipped and Equipped.ToolTip or ""
        if ToolTip == "Blox Fruit" then
            _tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(90), 0))
        else
            _tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0) * CFrame.Angles(0, math.rad(180), 0))
        end
    end
end

Attack.Kill2 = function(model, Succes)
    if model and Succes then
        if not model:GetAttribute("Locked") then
            model:SetAttribute("Locked", model.HumanoidRootPart.CFrame)
        end
        PosMon = model:GetAttribute("Locked").Position
        BringEnemy()
        EquipWeapon(Library.Flags.SelectWeapon or "Melee")
        _tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 8) * CFrame.Angles(0, math.rad(180), 0))
    end
end

Attack.KillSea = function(model, Succes)
    if model and Succes then
        if not model:GetAttribute("Locked") then
            model:SetAttribute("Locked", model.HumanoidRootPart.CFrame)
        end
        PosMon = model:GetAttribute("Locked").Position
        BringEnemy()
        EquipWeapon(Library.Flags.SelectWeapon or "Melee")
        local Equipped = client.Character and client.Character:FindFirstChildOfClass("Tool")
        local ToolTip = Equipped and Equipped.ToolTip or ""
        if ToolTip == "Blox Fruit" then
            _tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(90), 0))
        else
            notween(model.HumanoidRootPart.CFrame * CFrame.new(0, 50, 8))
            task.wait(0.85)
            notween(model.HumanoidRootPart.CFrame * CFrame.new(0, 400, 0))
            task.wait(1)
        end
    end
end

Useskills = function(weapon, skill)
    if weapon == "Melee" then
        weaponSc("Melee")
    elseif weapon == "Sword" then
        weaponSc("Sword")
    elseif weapon == "Blox Fruit" then
        weaponSc("Blox Fruit")
    elseif weapon == "Gun" then
        weaponSc("Gun")
    end
    if weapon == "nil" and skill == "Y" then
        VirtualInputManager:SendKeyEvent(true, "Y", false, game)
        VirtualInputManager:SendKeyEvent(false, "Y", false, game)
        return
    end
    VirtualInputManager:SendKeyEvent(true, skill, false, game)
    VirtualInputManager:SendKeyEvent(false, skill, false, game)
end

GetConnectionEnemies = function(a)
    for _, v in pairs(ReplicatedStorage:GetChildren()) do
        if v:IsA("Model") and ((typeof(a) == "table" and table.find(a, v.Name)) or v.Name == a) and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            return v
        end
    end
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v:IsA("Model") and ((typeof(a) == "table" and table.find(a, v.Name)) or v.Name == a) and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            return v
        end
    end
end

CheckF = function()
    if GetBP("Dragon-Dragon") or GetBP("Gas-Gas") or GetBP("Yeti-Yeti") or GetBP("Kitsune-Kitsune") or GetBP("T-Rex-T-Rex") then
        return true
    end
end

-----------------------------------------------------------------
-- Sea event checkers
-----------------------------------------------------------------

CheckBoat = function()
    for _, v in pairs(Workspace.Boats:GetChildren()) do
        if v:FindFirstChild("Owner") and tostring(v.Owner.Value) == tostring(client.Name) then
            return v
        end
    end
    return false
end

CheckEnemiesBoat = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == "FishBoat" and v:FindFirstChild("Health") and v.Health.Value > 0 then return true end
    end
    return false
end

CheckPirateGrandBrigade = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if (v.Name == "PirateGrandBrigade" or v.Name == "PirateBrigade") and v:FindFirstChild("Health") and v.Health.Value > 0 then return true end
    end
    return false
end

CheckShark = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == "Shark" and Attack.Alive(v) then return true end
    end
    return false
end

CheckTerrorShark = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == "Terrorshark" and Attack.Alive(v) then return true end
    end
    return false
end

CheckPiranha = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == "Piranha" and Attack.Alive(v) then return true end
    end
    return false
end

CheckFishCrew = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if (v.Name == "Fish Crew Member" or v.Name == "Haunted Crew Member") and Attack.Alive(v) then return true end
    end
    return false
end

CheckHauntedCrew = function()
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == "Haunted Crew Member" and Attack.Alive(v) then return true end
    end
    return false
end

CheckSeaBeast = function()
    return Workspace:FindFirstChild("SeaBeasts") and Workspace.SeaBeasts:FindFirstChild("SeaBeast1") ~= nil
end

CheckLeviathan = function()
    return Workspace:FindFirstChild("SeaBeasts") and Workspace.SeaBeasts:FindFirstChild("Leviathan") ~= nil
end

-----------------------------------------------------------------
-- Quest data
-----------------------------------------------------------------

local PosMsList = {
    ["Pirate Millionaire"] = CFrame.new(-712.83, 98.58, 5711.95),
    ["Pistol Billionaire"] = CFrame.new(-723.43, 147.43, 5931.99),
    ["Dragon Crew Warrior"] = CFrame.new(7021.50, 55.76, -730.13),
    ["Dragon Crew Archer"] = CFrame.new(6625, 378, 244),
    ["Female Islander"] = CFrame.new(4692.79, 797.98, 858.85),
    ["Venomous Assailant"] = CFrame.new(4902, 670, 39),
    ["Marine Commodore"] = CFrame.new(2401, 123, -7589),
    ["Marine Rear Admiral"] = CFrame.new(3588, 229, -7085),
    ["Fishman Raider"] = CFrame.new(-10941, 332, -8760),
    ["Fishman Captain"] = CFrame.new(-11035, 332, -9087),
    ["Forest Pirate"] = CFrame.new(-13446, 413, -7760),
    ["Mythological Pirate"] = CFrame.new(-13510, 584, -6987),
    ["Jungle Pirate"] = CFrame.new(-11778, 426, -10592),
    ["Musketeer Pirate"] = CFrame.new(-13282, 496, -9565),
    ["Reborn Skeleton"] = CFrame.new(-8764, 142, 5963),
    ["Living Zombie"] = CFrame.new(-10227, 421, 6161),
    ["Demonic Soul"] = CFrame.new(-9579, 6, 6194),
    ["Posessed Mummy"] = CFrame.new(-9579, 6, 6194),
    ["Peanut Scout"] = CFrame.new(-1993, 187, -10103),
    ["Peanut President"] = CFrame.new(-2215, 159, -10474),
    ["Ice Cream Chef"] = CFrame.new(-877, 118, -11032),
    ["Ice Cream Commander"] = CFrame.new(-877, 118, -11032),
    ["Cookie Crafter"] = CFrame.new(-2021, 38, -12028),
    ["Cake Guard"] = CFrame.new(-2024, 38, -12026),
    ["Baking Staff"] = CFrame.new(-1932, 38, -12848),
    ["Head Baker"] = CFrame.new(-1932, 38, -12848),
    ["Cocoa Warrior"] = CFrame.new(95, 73, -12309),
    ["Chocolate Bar Battler"] = CFrame.new(647, 42, -12401),
    ["Sweet Thief"] = CFrame.new(116, 36, -12478),
    ["Candy Rebel"] = CFrame.new(47, 61, -12889),
    ["Ghost"] = CFrame.new(5251, 5, 1111),
}

-----------------------------------------------------------------
-- CheckQuest (level progression)
-----------------------------------------------------------------

Mon = ""
LevelQuest = 1
NameQuest = ""
NameMon = ""
CFrameQuest = CFrame.new()
CFrameMon = CFrame.new()

function CheckQuest()
    local MyLevel = client.Data.Level.Value
    if World1 then
        if MyLevel <= 9 then
            Mon, LevelQuest, NameQuest, NameMon = "Bandit", 1, "BanditQuest1", "Bandit"
            CFrameQuest = CFrame.new(1059.37, 15.45, 1550.42)
            CFrameMon = CFrame.new(1040.54, 27.0, 1576.12)
        elseif MyLevel <= 14 then
            Mon, LevelQuest, NameQuest, NameMon = "Monkey", 1, "JungleQuest", "Monkey"
            CFrameQuest = CFrame.new(-1603.5, 36.85, 155.5)
            CFrameMon = CFrame.new(-1450.0, 50.0, 65.0)
        elseif MyLevel <= 29 then
            Mon, LevelQuest, NameQuest, NameMon = "Gorilla", 2, "JungleQuest", "Gorilla"
            CFrameQuest = CFrame.new(-1603.5, 36.85, 155.5)
            CFrameMon = CFrame.new(-1145.0, 40.0, -515.0)
        elseif MyLevel <= 59 then
            Mon, LevelQuest, NameQuest, NameMon = "Pirate", 1, "BuggyQuest1", "Pirate"
            CFrameQuest = CFrame.new(-1140.0, 4.5, 3827.0)
            CFrameMon = CFrame.new(-1200.0, 40.0, 3857.0)
        elseif MyLevel <= 74 then
            Mon, LevelQuest, NameQuest, NameMon = "Brute", 2, "BuggyQuest1", "Brute"
            CFrameQuest = CFrame.new(-1140.0, 4.5, 3827.0)
            CFrameMon = CFrame.new(-1385.0, 24.0, 4100.0)
        elseif MyLevel <= 89 then
            Mon, LevelQuest, NameQuest, NameMon = "Desert Bandit", 1, "DesertQuest", "Desert Bandit"
            CFrameQuest = CFrame.new(896.0, 6.4, 4390.0)
            CFrameMon = CFrame.new(985.0, 16.0, 4418.0)
        elseif MyLevel <= 99 then
            Mon, LevelQuest, NameQuest, NameMon = "Desert Officer", 2, "DesertQuest", "Desert Officer"
            CFrameQuest = CFrame.new(896.0, 6.4, 4390.0)
            CFrameMon = CFrame.new(1547.0, 14.0, 4382.0)
        elseif MyLevel <= 119 then
            Mon, LevelQuest, NameQuest, NameMon = "Snow Bandit", 1, "SnowQuest", "Snow Bandit"
            CFrameQuest = CFrame.new(1386.0, 87.0, -1298.0)
            CFrameMon = CFrame.new(1358.0, 105.0, -1328.0)
        elseif MyLevel <= 149 then
            Mon, LevelQuest, NameQuest, NameMon = "Snowman", 2, "SnowQuest", "Snowman"
            CFrameQuest = CFrame.new(1386.0, 87.0, -1298.0)
            CFrameMon = CFrame.new(1220.0, 138.0, -1488.0)
        elseif MyLevel <= 174 then
            Mon, LevelQuest, NameQuest, NameMon = "Chief Petty Officer", 1, "MarineQuest2", "Chief Petty Officer"
            CFrameQuest = CFrame.new(-5035.0, 28.5, 4324.0)
            CFrameMon = CFrame.new(-4932.0, 65.0, 4122.0)
        elseif MyLevel <= 189 then
            Mon, LevelQuest, NameQuest, NameMon = "Sky Bandit", 1, "SkyQuest", "Sky Bandit"
            CFrameQuest = CFrame.new(-4842.0, 717.5, -2623.0)
            CFrameMon = CFrame.new(-4955.0, 365.0, -2908.0)
        elseif MyLevel <= 209 then
            Mon, LevelQuest, NameQuest, NameMon = "Dark Master", 2, "SkyQuest", "Dark Master"
            CFrameQuest = CFrame.new(-4842.0, 717.5, -2623.0)
            CFrameMon = CFrame.new(-5148.0, 439.0, -2332.0)
        elseif MyLevel <= 249 then
            Mon, LevelQuest, NameQuest, NameMon = "Prisoner", 1, "PrisonerQuest", "Prisoner"
            CFrameQuest = CFrame.new(5310.5, 0.3, 475.0)
            CFrameMon = CFrame.new(4937.0, 0.3, 649.5)
        elseif MyLevel <= 274 then
            Mon, LevelQuest, NameQuest, NameMon = "Dangerous Prisoner", 2, "PrisonerQuest", "Dangerous Prisoner"
            CFrameQuest = CFrame.new(5310.5, 0.3, 475.0)
            CFrameMon = CFrame.new(5100.0, 0.3, 1055.5)
        elseif MyLevel <= 299 then
            Mon, LevelQuest, NameQuest, NameMon = "Toga Warrior", 1, "ColosseumQuest", "Toga Warrior"
            CFrameQuest = CFrame.new(-1578.0, 7.4, -2984.0)
            CFrameMon = CFrame.new(-1872.0, 49.0, -2913.0)
        elseif MyLevel <= 324 then
            Mon, LevelQuest, NameQuest, NameMon = "Gladiator", 2, "ColosseumQuest", "Gladiator"
            CFrameQuest = CFrame.new(-1578.0, 7.4, -2984.0)
            CFrameMon = CFrame.new(-1521.0, 81.0, -3066.0)
        elseif MyLevel <= 374 then
            Mon, LevelQuest, NameQuest, NameMon = "Military Soldier", 1, "MagmaQuest", "Military Soldier"
            CFrameQuest = CFrame.new(-5316.0, 12.0, 8517.0)
            CFrameMon = CFrame.new(-5369.0, 61.0, 8556.0)
        elseif MyLevel <= 399 then
            Mon, LevelQuest, NameQuest, NameMon = "Military Spy", 2, "MagmaQuest", "Military Spy"
            CFrameQuest = CFrame.new(-5316.0, 12.0, 8517.0)
            CFrameMon = CFrame.new(-5787.0, 75.0, 8651.5)
        elseif MyLevel <= 449 then
            Mon, LevelQuest, NameQuest, NameMon = "Fishman Warrior", 1, "FishmanQuest", "Fishman Warrior"
            CFrameQuest = CFrame.new(61122.0, 18.0, 1569.0)
            CFrameMon = CFrame.new(60844.0, 98.0, 1298.0)
        elseif MyLevel <= 474 then
            Mon, LevelQuest, NameQuest, NameMon = "Fishman Commando", 2, "FishmanQuest", "Fishman Commando"
            CFrameQuest = CFrame.new(61122.0, 18.0, 1569.0)
            CFrameMon = CFrame.new(61738.0, 64.0, 1433.5)
        elseif MyLevel <= 524 then
            Mon, LevelQuest, NameQuest, NameMon = "God's Guard", 1, "SkyExp1Quest", "God's Guard"
            CFrameQuest = CFrame.new(-4722.0, 845.0, -1954.0)
            CFrameMon = CFrame.new(-4628.0, 866.0, -1931.0)
        elseif MyLevel <= 549 then
            Mon, LevelQuest, NameQuest, NameMon = "Shanda", 2, "SkyExp1Quest", "Shanda"
            CFrameQuest = CFrame.new(-7863.0, 5545.0, -378.0)
            CFrameMon = CFrame.new(-7685.0, 5601.0, -441.0)
        elseif MyLevel <= 624 then
            Mon, LevelQuest, NameQuest, NameMon = "Royal Squad", 1, "SkyExp2Quest", "Royal Squad"
            CFrameQuest = CFrame.new(-7903.0, 5636.0, -1411.0)
            CFrameMon = CFrame.new(-7654.0, 5637.0, -1407.5)
        elseif MyLevel <= 649 then
            Mon, LevelQuest, NameQuest, NameMon = "Royal Soldier", 2, "SkyExp2Quest", "Royal Soldier"
            CFrameQuest = CFrame.new(-7903.0, 5636.0, -1411.0)
            CFrameMon = CFrame.new(-7760.0, 5680.0, -1884.0)
        elseif MyLevel <= 999 then
            Mon, LevelQuest, NameQuest, NameMon = "Galley Pirate", 1, "FountainQuest", "Galley Pirate"
            CFrameQuest = CFrame.new(5258.0, 38.5, 4050.0)
            CFrameMon = CFrame.new(5557.0, 152.0, 3998.5)
        end
    elseif World2 then
        if MyLevel <= 724 then
            Mon, LevelQuest, NameQuest, NameMon = "Raider", 1, "Area1Quest", "Raider"
            CFrameQuest = CFrame.new(-428.0, 73.0, 1836.0)
            CFrameMon = CFrame.new(69.0, 93.5, 2430.0)
        elseif MyLevel <= 774 then
            Mon, LevelQuest, NameQuest, NameMon = "Mercenary", 2, "Area1Quest", "Mercenary"
            CFrameQuest = CFrame.new(-428.0, 73.0, 1836.0)
            CFrameMon = CFrame.new(-865.0, 122.0, 1453.0)
        elseif MyLevel <= 799 then
            Mon, LevelQuest, NameQuest, NameMon = "Swan Pirate", 1, "Area2Quest", "Swan Pirate"
            CFrameQuest = CFrame.new(635.5, 73.0, 918.0)
            CFrameMon = CFrame.new(1065.0, 137.5, 1324.0)
        elseif MyLevel <= 874 then
            Mon, LevelQuest, NameQuest, NameMon = "Factory Staff", 2, "Area2Quest", "Factory Staff"
            CFrameQuest = CFrame.new(635.5, 73.0, 918.0)
            CFrameMon = CFrame.new(533.0, 128.0, 356.0)
        elseif MyLevel <= 899 then
            Mon, LevelQuest, NameQuest, NameMon = "Marine Lieutenant", 1, "MarineQuest3", "Marine Lieutenant"
            CFrameQuest = CFrame.new(-2441.0, 73.0, -3218.0)
            CFrameMon = CFrame.new(-2489.0, 84.5, -3152.0)
        elseif MyLevel <= 949 then
            Mon, LevelQuest, NameQuest, NameMon = "Marine Captain", 2, "MarineQuest3", "Marine Captain"
            CFrameQuest = CFrame.new(-2441.0, 73.0, -3218.0)
            CFrameMon = CFrame.new(-2335.0, 79.5, -3246.0)
        elseif MyLevel <= 974 then
            Mon, LevelQuest, NameQuest, NameMon = "Zombie", 1, "ZombieQuest", "Zombie"
            CFrameQuest = CFrame.new(-5494.0, 48.5, -795.0)
            CFrameMon = CFrame.new(-5536.0, 101.0, -835.5)
        elseif MyLevel <= 999 then
            Mon, LevelQuest, NameQuest, NameMon = "Vampire", 2, "ZombieQuest", "Vampire"
            CFrameQuest = CFrame.new(-5494.0, 48.5, -795.0)
            CFrameMon = CFrame.new(-5806.0, 16.5, -1164.0)
        elseif MyLevel <= 1049 then
            Mon, LevelQuest, NameQuest, NameMon = "Snow Trooper", 1, "SnowMountainQuest", "Snow Trooper"
            CFrameQuest = CFrame.new(607.0, 401.0, -5370.5)
            CFrameMon = CFrame.new(535.0, 432.5, -5485.0)
        elseif MyLevel <= 1099 then
            Mon, LevelQuest, NameQuest, NameMon = "Winter Warrior", 2, "SnowMountainQuest", "Winter Warrior"
            CFrameQuest = CFrame.new(607.0, 401.0, -5370.5)
            CFrameMon = CFrame.new(1234.0, 456.5, -5174.0)
        elseif MyLevel <= 1124 then
            Mon, LevelQuest, NameQuest, NameMon = "Lab Subordinate", 1, "IceSideQuest", "Lab Subordinate"
            CFrameQuest = CFrame.new(-6062.0, 15.9, -4902.0)
            CFrameMon = CFrame.new(-5720.5, 63.0, -4784.5)
        elseif MyLevel <= 1174 then
            Mon, LevelQuest, NameQuest, NameMon = "Horned Warrior", 2, "IceSideQuest", "Horned Warrior"
            CFrameQuest = CFrame.new(-6062.0, 15.9, -4902.0)
            CFrameMon = CFrame.new(-6292.5, 91.0, -5502.5)
        elseif MyLevel <= 1199 then
            Mon, LevelQuest, NameQuest, NameMon = "Magma Ninja", 1, "FireSideQuest", "Magma Ninja"
            CFrameQuest = CFrame.new(-5429.0, 15.9, -5298.0)
            CFrameMon = CFrame.new(-5462.0, 130.0, -5836.0)
        elseif MyLevel <= 1249 then
            Mon, LevelQuest, NameQuest, NameMon = "Lava Pirate", 2, "FireSideQuest", "Lava Pirate"
            CFrameQuest = CFrame.new(-5429.0, 15.9, -5298.0)
            CFrameMon = CFrame.new(-5251.0, 55.0, -4774.0)
        elseif MyLevel <= 1274 then
            Mon, LevelQuest, NameQuest, NameMon = "Ship Deckhand", 1, "ShipQuest1", "Ship Deckhand"
            CFrameQuest = CFrame.new(1040.0, 125.0, 32911.0)
            CFrameMon = CFrame.new(921.0, 126.0, 33088.0)
        elseif MyLevel <= 1299 then
            Mon, LevelQuest, NameQuest, NameMon = "Ship Engineer", 2, "ShipQuest1", "Ship Engineer"
            CFrameQuest = CFrame.new(1040.0, 125.0, 32911.0)
            CFrameMon = CFrame.new(886.0, 40.0, 32801.0)
        elseif MyLevel <= 1324 then
            Mon, LevelQuest, NameQuest, NameMon = "Ship Steward", 1, "ShipQuest2", "Ship Steward"
            CFrameQuest = CFrame.new(971.0, 125.0, 33245.5)
            CFrameMon = CFrame.new(944.0, 129.5, 33444.0)
        elseif MyLevel <= 1349 then
            Mon, LevelQuest, NameQuest, NameMon = "Ship Officer", 2, "ShipQuest2", "Ship Officer"
            CFrameQuest = CFrame.new(971.0, 125.0, 33245.5)
            CFrameMon = CFrame.new(955.0, 181.0, 33332.0)
        elseif MyLevel <= 1374 then
            Mon, LevelQuest, NameQuest, NameMon = "Arctic Warrior", 1, "FrostQuest", "Arctic Warrior"
            CFrameQuest = CFrame.new(5668.0, 28.0, -6484.5)
            CFrameMon = CFrame.new(5935.0, 77.0, -6472.5)
        elseif MyLevel <= 1424 then
            Mon, LevelQuest, NameQuest, NameMon = "Snow Lurker", 2, "FrostQuest", "Snow Lurker"
            CFrameQuest = CFrame.new(5668.0, 28.0, -6484.5)
            CFrameMon = CFrame.new(5628.0, 57.5, -6618.0)
        elseif MyLevel <= 1449 then
            Mon, LevelQuest, NameQuest, NameMon = "Sea Soldier", 1, "ForgottenQuest", "Sea Soldier"
            CFrameQuest = CFrame.new(-3054.5, 237.0, -10148.0)
            CFrameMon = CFrame.new(-3185.0, 58.5, -9663.5)
        else
            Mon, LevelQuest, NameQuest, NameMon = "Water Fighter", 2, "ForgottenQuest", "Water Fighter"
            CFrameQuest = CFrame.new(-3054.5, 237.0, -10148.0)
            CFrameMon = CFrame.new(-3263.0, 298.5, -10552.5)
        end
    elseif World3 then
        if MyLevel <= 1524 then
            Mon, LevelQuest, NameQuest, NameMon = "Pirate Millionaire", 1, "PiratePortQuest", "Pirate Millionaire"
            CFrameQuest = CFrame.new(-290.0, 43.8, 5580.0)
            CFrameMon = CFrame.new(-435.5, 189.5, 5551.0)
        elseif MyLevel <= 1574 then
            Mon, LevelQuest, NameQuest, NameMon = "Pistol Billionaire", 2, "PiratePortQuest", "Pistol Billionaire"
            CFrameQuest = CFrame.new(-290.0, 43.8, 5580.0)
            CFrameMon = CFrame.new(-236.5, 217.0, 6006.0)
        elseif MyLevel <= 1599 then
            Mon, LevelQuest, NameQuest, NameMon = "Dragon Crew Warrior", 1, "AmazonQuest", "Dragon Crew Warrior"
            CFrameQuest = CFrame.new(5833.0, 51.5, -1103.0)
            CFrameMon = CFrame.new(6302.0, 104.5, -1082.5)
        elseif MyLevel <= 1649 then
            Mon, LevelQuest, NameQuest, NameMon = "Dragon Crew Archer", 2, "AmazonQuest", "Dragon Crew Archer"
            CFrameQuest = CFrame.new(5833.0, 51.5, -1103.0)
            CFrameMon = CFrame.new(6831.0, 441.5, 446.5)
        elseif MyLevel <= 1674 then
            Mon, LevelQuest, NameQuest, NameMon = "Female Islander", 1, "AmazonQuest2", "Female Islander"
            CFrameQuest = CFrame.new(5447.0, 601.5, 749.0)
            CFrameMon = CFrame.new(5792.5, 848.0, 1084.0)
        elseif MyLevel <= 1699 then
            Mon, LevelQuest, NameQuest, NameMon = "Giant Islander", 2, "AmazonQuest2", "Giant Islander"
            CFrameQuest = CFrame.new(5447.0, 601.5, 749.0)
            CFrameMon = CFrame.new(5010.0, 664.0, -41.0)
        elseif MyLevel <= 1724 then
            Mon, LevelQuest, NameQuest, NameMon = "Marine Commodore", 1, "MarineTreeIsland", "Marine Commodore"
            CFrameQuest = CFrame.new(2180.0, 28.7, -6740.0)
            CFrameMon = CFrame.new(2198.0, 128.5, -7109.0)
        elseif MyLevel <= 1774 then
            Mon, LevelQuest, NameQuest, NameMon = "Marine Rear Admiral", 2, "MarineTreeIsland", "Marine Rear Admiral"
            CFrameQuest = CFrame.new(2180.0, 28.7, -6740.0)
            CFrameMon = CFrame.new(3294.0, 385.0, -7048.5)
        elseif MyLevel <= 1799 then
            Mon, LevelQuest, NameQuest, NameMon = "Fishman Raider", 1, "DeepForestIsland3", "Fishman Raider"
            CFrameQuest = CFrame.new(-10583.0, 331.5, -8758.0)
            CFrameMon = CFrame.new(-10553.0, 521.0, -8177.0)
        elseif MyLevel <= 1824 then
            Mon, LevelQuest, NameQuest, NameMon = "Fishman Captain", 2, "DeepForestIsland3", "Fishman Captain"
            CFrameQuest = CFrame.new(-10583.0, 331.5, -8758.0)
            CFrameMon = CFrame.new(-10789.0, 427.0, -9131.0)
        elseif MyLevel <= 1849 then
            Mon, LevelQuest, NameQuest, NameMon = "Forest Pirate", 1, "DeepForestIsland", "Forest Pirate"
            CFrameQuest = CFrame.new(-13233.0, 332.0, -7626.5)
            CFrameMon = CFrame.new(-13489.0, 400.0, -7770.0)
        elseif MyLevel <= 1899 then
            Mon, LevelQuest, NameQuest, NameMon = "Mythological Pirate", 2, "DeepForestIsland", "Mythological Pirate"
            CFrameQuest = CFrame.new(-13233.0, 332.0, -7626.5)
            CFrameMon = CFrame.new(-13508.5, 582.0, -6985.0)
        elseif MyLevel <= 1924 then
            Mon, LevelQuest, NameQuest, NameMon = "Jungle Pirate", 1, "DeepForestIsland2", "Jungle Pirate"
            CFrameQuest = CFrame.new(-12682.0, 390.5, -9902.0)
            CFrameMon = CFrame.new(-12267.0, 459.5, -10277.0)
        elseif MyLevel <= 1974 then
            Mon, LevelQuest, NameQuest, NameMon = "Musketeer Pirate", 2, "DeepForestIsland2", "Musketeer Pirate"
            CFrameQuest = CFrame.new(-12682.0, 390.5, -9902.0)
            CFrameMon = CFrame.new(-13291.5, 520.0, -9904.5)
        elseif MyLevel <= 1999 then
            Mon, LevelQuest, NameQuest, NameMon = "Reborn Skeleton", 1, "HauntedQuest1", "Reborn Skeleton"
            CFrameQuest = CFrame.new(-9481.0, 142.0, 5566.0)
            CFrameMon = CFrame.new(-8762.0, 183.0, 6168.0)
        elseif MyLevel <= 2024 then
            Mon, LevelQuest, NameQuest, NameMon = "Living Zombie", 2, "HauntedQuest1", "Living Zombie"
            CFrameQuest = CFrame.new(-9481.0, 142.0, 5566.0)
            CFrameMon = CFrame.new(-10104.0, 238.5, 6180.0)
        elseif MyLevel <= 2049 then
            Mon, LevelQuest, NameQuest, NameMon = "Demonic Soul", 1, "HauntedQuest2", "Demonic Soul"
            CFrameQuest = CFrame.new(-9517.0, 178.0, 6078.0)
            CFrameMon = CFrame.new(-9712.0, 204.5, 6193.0)
        elseif MyLevel <= 2074 then
            Mon, LevelQuest, NameQuest, NameMon = "Posessed Mummy", 2, "HauntedQuest2", "Posessed Mummy"
            CFrameQuest = CFrame.new(-9517.0, 178.0, 6078.0)
            CFrameMon = CFrame.new(-9553.0, 65.6, 6041.0)
        elseif MyLevel <= 2099 then
            Mon, LevelQuest, NameQuest, NameMon = "Peanut Scout", 1, "NutsQuest", "Peanut Scout"
            CFrameQuest = CFrame.new(-2394, 318, -7000)
            CFrameMon = CFrame.new(-1993, 187, -10103)
        elseif MyLevel <= 2124 then
            Mon, LevelQuest, NameQuest, NameMon = "Peanut President", 2, "NutsQuest", "Peanut President"
            CFrameQuest = CFrame.new(-2394, 318, -7000)
            CFrameMon = CFrame.new(-2215, 159, -10474)
        elseif MyLevel <= 2149 then
            Mon, LevelQuest, NameQuest, NameMon = "Ice Cream Chef", 1, "IceCreamQuest", "Ice Cream Chef"
            CFrameQuest = CFrame.new(-840, 182, -7000)
            CFrameMon = CFrame.new(-877, 118, -11032)
        elseif MyLevel <= 2174 then
            Mon, LevelQuest, NameQuest, NameMon = "Ice Cream Commander", 2, "IceCreamQuest", "Ice Cream Commander"
            CFrameQuest = CFrame.new(-840, 182, -7000)
            CFrameMon = CFrame.new(-877, 118, -11032)
        elseif MyLevel <= 2199 then
            Mon, LevelQuest, NameQuest, NameMon = "Cookie Crafter", 1, "CakeQuest1", "Cookie Crafter"
            CFrameQuest = CFrame.new(-2022, 37, -12031)
            CFrameMon = CFrame.new(-2021, 38, -12028)
        elseif MyLevel <= 2224 then
            Mon, LevelQuest, NameQuest, NameMon = "Cake Guard", 2, "CakeQuest1", "Cake Guard"
            CFrameQuest = CFrame.new(-2022, 37, -12031)
            CFrameMon = CFrame.new(-2024, 38, -12026)
        elseif MyLevel <= 2249 then
            Mon, LevelQuest, NameQuest, NameMon = "Baking Staff", 1, "CakeQuest2", "Baking Staff"
            CFrameQuest = CFrame.new(-1928, 38, -12840)
            CFrameMon = CFrame.new(-1932, 38, -12848)
        elseif MyLevel <= 2274 then
            Mon, LevelQuest, NameQuest, NameMon = "Head Baker", 2, "CakeQuest2", "Head Baker"
            CFrameQuest = CFrame.new(-1928, 38, -12840)
            CFrameMon = CFrame.new(-1932, 38, -12848)
        elseif MyLevel <= 2299 then
            Mon, LevelQuest, NameQuest, NameMon = "Cocoa Warrior", 1, "ChocQuest1", "Cocoa Warrior"
            CFrameQuest = CFrame.new(150, 38, -12700)
            CFrameMon = CFrame.new(95, 73, -12309)
        elseif MyLevel <= 2324 then
            Mon, LevelQuest, NameQuest, NameMon = "Chocolate Bar Battler", 2, "ChocQuest1", "Chocolate Bar Battler"
            CFrameQuest = CFrame.new(150, 38, -12700)
            CFrameMon = CFrame.new(647, 42, -12401)
        elseif MyLevel <= 2349 then
            Mon, LevelQuest, NameQuest, NameMon = "Sweet Thief", 1, "ChocQuest2", "Sweet Thief"
            CFrameQuest = CFrame.new(150, 38, -12700)
            CFrameMon = CFrame.new(116, 36, -12478)
        elseif MyLevel <= 2374 then
            Mon, LevelQuest, NameQuest, NameMon = "Candy Rebel", 2, "ChocQuest2", "Candy Rebel"
            CFrameQuest = CFrame.new(150, 38, -12700)
            CFrameMon = CFrame.new(47, 61, -12889)
        else
            Mon, LevelQuest, NameQuest, NameMon = "Cocoa Warrior", 1, "ChocQuest1", "Cocoa Warrior"
            CFrameQuest = CFrame.new(150, 38, -12700)
            CFrameMon = CFrame.new(95, 73, -12309)
        end
    end
end

-----------------------------------------------------------------
-- Hop function
-----------------------------------------------------------------

function Hop()
    local PlaceID = game.PlaceId
    local servers = {}
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if success and result and result.data then
        for _, v in pairs(result.data) do
            if v.playing < v.maxPlayers and v.id ~= game.JobId then
                table.insert(servers, v.id)
            end
        end
    end
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceID, servers[math.random(1, #servers)], client)
    end
end

-----------------------------------------------------------------
-- UI Tabs
-----------------------------------------------------------------

local MainTab = ui:CreateSection("Main")
local SeaTab = ui:CreateSection("Sea Events")
local MirageTab = ui:CreateSection("Mirage + RaceV4")
local ShopTab = ui:CreateSection("Shop")
local TravelTab = ui:CreateSection("Travel")
local MiscTab = ui:CreateSection("Misc")

-----------------------------------------------------------------
-- Main Tab: Auto Farm
-----------------------------------------------------------------

MainTab:createToggle({
    Name = "Auto Farm Level",
    Flag = false,
    flagName = "FarmLevel",
    Callback = function(v)
        shouldTween = v
    end,
})

MainTab:createDropdown({
    Name = "Select Weapon",
    flagName = "SelectWeapon",
    Flag = "Melee",
    List = {"Melee", "Sword", "Blox Fruit", "Gun"},
})

MainTab:createToggle({
    Name = "Bring Enemies",
    Flag = false,
    flagName = "BringMob",
    Callback = function(v) _B = v end,
})

interval("FarmLevel", "FarmLevel", 0.1, function()
    CheckQuest()
    local root = getRoot()
    if not root then return end
    local questName = NameQuest .. tostring(LevelQuest)
    local questUI = client.PlayerGui:FindFirstChild("Main") and client.PlayerGui.Main:FindFirstChild("Quest")
    if questUI and not questUI.Visible then
        _tp(CFrameQuest)
        task.wait(0.5)
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", NameQuest, LevelQuest)
        end)
        task.wait(0.3)
    end
    local v = GetConnectionEnemies(NameMon)
    if v and Attack.Alive(v) then
        MousePos = v.HumanoidRootPart.Position
        Attack.Kill(v, Library.Flags.FarmLevel)
    else
        if PosMsList[NameMon] then
            _tp(PosMsList[NameMon])
        else
            _tp(CFrameMon)
        end
    end
end)

-----------------------------------------------------------------
-- Sea Events Tab
-----------------------------------------------------------------

SeaTab:createToggle({
    Name = "Auto Sail Boat",
    Flag = false,
    flagName = "SailBoats",
})

SeaTab:createDropdown({
    Name = "Sea Danger Level",
    flagName = "DangerSc",
    Flag = "Lv 1",
    List = {"Lv 1", "Lv 2", "Lv 3", "Lv 4", "Lv 5", "Lv 6", "Lv Infinite"},
})

SeaTab:createToggle({ Name = "Auto Shark", Flag = false, flagName = "Shark" })
SeaTab:createToggle({ Name = "Auto Piranha", Flag = false, flagName = "Piranha" })
SeaTab:createToggle({ Name = "Auto Terror Shark", Flag = false, flagName = "TerrorShark" })
SeaTab:createToggle({ Name = "Auto Fish Crew", Flag = false, flagName = "MobCrew" })
SeaTab:createToggle({ Name = "Auto Haunted Crew", Flag = false, flagName = "HCM" })
SeaTab:createToggle({ Name = "Auto Pirate Brigade", Flag = false, flagName = "PGB" })
SeaTab:createToggle({ Name = "Auto Fish Boat", Flag = false, flagName = "FishBoat" })
SeaTab:createToggle({ Name = "Auto Sea Beast", Flag = false, flagName = "SeaBeast1" })
SeaTab:createToggle({ Name = "Auto Leviathan", Flag = false, flagName = "Leviathan1" })

local DangerZones = {
    ["Lv 1"] = CFrame.new(-28525.69, 30.2, -4678.42),
    ["Lv 2"] = CFrame.new(-30920.02, 30.22, -3718.61),
    ["Lv 3"] = CFrame.new(-32426.83, 30.24, -3133.03),
    ["Lv 4"] = CFrame.new(-34054.69, 30.22, -2560.12),
    ["Lv 5"] = CFrame.new(-38887.56, 30, -2162.99),
    ["Lv 6"] = CFrame.new(-44541.76, 30, -1244.86),
    ["Lv Infinite"] = CFrame.new(-10000000, 31, 37016.25),
}

interval("SailBoats", "SailBoats", 0.1, function()
    local myBoat = CheckBoat()
    if not myBoat then
        local buyBoatCFrame = CFrame.new(-16927.451, 9.086, 433.864)
        TeleportToTarget(buyBoatCFrame)
        if (buyBoatCFrame.Position - getRoot().Position).Magnitude <= 10 then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyBoat", "Guardian")
        end
    else
        local hum = getHum()
        if hum and not hum.Sit then
            _tp(myBoat.VehicleSeat.CFrame * CFrame.new(0, 1, 0))
        else
            local dz = DangerZones[Library.Flags.DangerSc or "Lv 1"]
            if CheckEnemiesBoat() or CheckTerrorShark() or CheckPirateGrandBrigade() then
                _tp(dz * CFrame.new(0, 150, 0))
            else
                _tp(dz)
            end
        end
    end
end)

local function SeaEntityLoop(flag, name, checker, useKillSea)
    interval("SeaEntity_" .. flag, flag, 0.1, function()
        if not checker() then return end
        for _, v in pairs(Workspace.Enemies:GetChildren()) do
            if v.Name == name and Attack.Alive(v) then
                if useKillSea then
                    Attack.KillSea(v, Library.Flags[flag])
                else
                    Attack.Kill(v, Library.Flags[flag])
                end
            end
        end
    end)
end

SeaEntityLoop("Shark", "Shark", CheckShark, false)
SeaEntityLoop("TerrorShark", "Terrorshark", CheckTerrorShark, true)
SeaEntityLoop("Piranha", "Piranha", CheckPiranha, false)
SeaEntityLoop("MobCrew", "Fish Crew Member", CheckFishCrew, false)
SeaEntityLoop("HCM", "Haunted Crew Member", CheckHauntedCrew, false)

interval("PGB", "PGB", 0.1, function()
    if not CheckPirateGrandBrigade() then return end
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if (v.Name == "PirateBrigade" or v.Name == "PirateGrandBrigade") and v:FindFirstChild("Health") and v.Health.Value > 0 then
            if v:FindFirstChild("VehicleSeat") then
                _tp(v.Engine.CFrame * CFrame.new(0, -50, -50))
                EquipWeapon(Library.Flags.SelectWeapon or "Melee")
            end
        end
    end
end)

interval("FishBoat", "FishBoat", 0.1, function()
    if not CheckEnemiesBoat() then return end
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == "FishBoat" and v:FindFirstChild("Health") and v.Health.Value > 0 and v:FindFirstChild("VehicleSeat") then
            _tp(v.Engine.CFrame * CFrame.new(0, -50, -25))
            EquipWeapon(Library.Flags.SelectWeapon or "Melee")
        end
    end
end)

interval("SeaBeast1", "SeaBeast1", 0.1, function()
    if not CheckSeaBeast() then return end
    for _, v in pairs(Workspace.SeaBeasts:GetChildren()) do
        if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Health") and v.Health.Value > 0 then
            _tp(CFrame.new(v.HumanoidRootPart.Position.X, Workspace.Map["WaterBase-Plane"].Position.Y + 200, v.HumanoidRootPart.Position.Z))
            MousePos = v.HumanoidRootPart.Position
            if CheckF() then
                Useskills("Blox Fruit", "Z"); Useskills("Blox Fruit", "X"); Useskills("Blox Fruit", "C")
            else
                Useskills("Melee", "Z"); Useskills("Melee", "X"); Useskills("Melee", "C")
                task.wait(0.1)
                Useskills("Sword", "Z"); Useskills("Sword", "X")
                task.wait(0.1)
                Useskills("Blox Fruit", "Z"); Useskills("Blox Fruit", "X"); Useskills("Blox Fruit", "C")
                task.wait(0.1)
                Useskills("Gun", "Z"); Useskills("Gun", "X")
            end
        end
    end
end)

interval("Leviathan1", "Leviathan1", 0.1, function()
    if not CheckLeviathan() then return end
    for _, v in pairs(Workspace.SeaBeasts:GetChildren()) do
        if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Leviathan Segment") and v:FindFirstChild("Health") and v.Health.Value > 0 then
            _tp(v.HumanoidRootPart.CFrame * CFrame.new(0, 300, 0))
            MousePos = v.HumanoidRootPart.Position
            if CheckF() then
                Useskills("Blox Fruit", "Z"); Useskills("Blox Fruit", "X"); Useskills("Blox Fruit", "C")
            else
                Useskills("Melee", "Z"); Useskills("Melee", "X"); Useskills("Melee", "C")
                task.wait(0.1)
                Useskills("Sword", "Z"); Useskills("Sword", "X")
            end
        end
    end
end)

-----------------------------------------------------------------
-- Kitsune Island
-----------------------------------------------------------------

SeaTab:createLabel({ Name = "--- Kitsune Island ---" })
SeaTab:createToggle({ Name = "Auto Find Kitsune Island", Flag = false, flagName = "AutofindKitIs" })
SeaTab:createToggle({ Name = "Auto Teleport to Shrine", Flag = false, flagName = "tweenShrine" })
SeaTab:createToggle({ Name = "Auto Collect Azure Ember", Flag = false, flagName = "Collect_Ember" })
SeaTab:createToggle({ Name = "Auto Trade Azure Ember", Flag = false, flagName = "Trade_Ember" })

interval("AutofindKitIs", "AutofindKitIs", 0.1, function()
    if not Workspace:FindFirstChild("_WorldOrigin") then return end
    if not Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island", true) then
        local myBoat = CheckBoat()
        if not myBoat then
            local buyBoatCFrame = CFrame.new(-16927.451, 9.086, 433.864)
            TeleportToTarget(buyBoatCFrame)
            if (buyBoatCFrame.Position - getRoot().Position).Magnitude <= 10 then
                ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyBoat", "Guardian")
            end
        else
            local hum = getHum()
            if hum and not hum.Sit then
                _tp(myBoat.VehicleSeat.CFrame * CFrame.new(0, 1, 0))
            else
                local target = CFrame.new(-10000000, 31, 37016.25)
                if CheckEnemiesBoat() or CheckTerrorShark() or CheckPirateGrandBrigade() then
                    _tp(CFrame.new(-10000000, 150, 37016.25))
                else
                    _tp(target)
                end
            end
        end
    else
        _tp(Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island").CFrame * CFrame.new(0, 500, 0))
    end
end)

interval("tweenShrine", "tweenShrine", 0.1, function()
    local kit_is = Workspace.Map:FindFirstChild("KitsuneIsland") or (Workspace._WorldOrigin and Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island"))
    if not kit_is then return end
    local shrineActive = kit_is:FindFirstChild("ShrineActive")
    if shrineActive then
        for _, v in pairs(shrineActive:GetDescendants()) do
            if v:IsA("BasePart") and v.Name:find("NeonShrinePart") then
                pcall(function() ReplicatedStorage.Modules.Net:FindFirstChild("RE/TouchKitsuneStatue"):FireServer() end)
                _tp(v.CFrame * CFrame.new(0, 2, 0))
            end
        end
    else
        _tp(kit_is.CFrame * CFrame.new(0, 500, 0))
    end
end)

interval("Collect_Ember", "Collect_Ember", 0.1, function()
    local ember = Workspace:FindFirstChild("AttachedAzureEmber") or Workspace:FindFirstChild("EmberTemplate")
    if ember then
        local part = ember:FindFirstChild("Part")
        if part then notween(part.CFrame) end
    elseif Workspace._WorldOrigin and Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island") then
        _tp(Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island").CFrame * CFrame.new(0, 500, 0))
        pcall(function() ReplicatedStorage.Modules.Net["RF/KitsuneStatuePray"]:InvokeServer() end)
    end
end)

interval("Trade_Ember", "Trade_Ember", 0.1, function()
    if Workspace._WorldOrigin and Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island", true) then
        pcall(function() ReplicatedStorage.Modules.Net:FindFirstChild("RF/KitsuneStatuePray"):InvokeServer() end)
    end
end)

-----------------------------------------------------------------
-- Mirage Island
-----------------------------------------------------------------

MirageTab:createLabel({ Name = "--- Mirage Island ---" })
MirageTab:createToggle({ Name = "Auto Find Mirage Island", Flag = false, flagName = "FindMirage" })
MirageTab:createToggle({ Name = "Auto Tween Highest Point", Flag = false, flagName = "HighestMirage" })
MirageTab:createToggle({ Name = "Auto Collect Gear", Flag = false, flagName = "TPGEAR" })
MirageTab:createToggle({ Name = "Auto Fruit Dealer", Flag = false, flagName = "Addealer" })
MirageTab:createToggle({ Name = "Auto Mirage Chest", Flag = false, flagName = "FarmChestM" })

interval("FindMirage", "FindMirage", 0.1, function()
    if not Workspace:FindFirstChild("_WorldOrigin") then return end
    if not Workspace._WorldOrigin.Locations:FindFirstChild("Mirage Island", true) then
        local myBoat = CheckBoat()
        if not myBoat then
            local buyBoatCFrame = CFrame.new(-16927.451, 9.086, 433.864)
            TeleportToTarget(buyBoatCFrame)
            if (buyBoatCFrame.Position - getRoot().Position).Magnitude <= 10 then
                ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyBoat", "Guardian")
            end
        else
            local hum = getHum()
            if hum and not hum.Sit then
                _tp(myBoat.VehicleSeat.CFrame * CFrame.new(0, 1, 0))
            else
                local target = CFrame.new(-10000000, 31, 37016.25)
                if CheckEnemiesBoat() or CheckTerrorShark() or CheckPirateGrandBrigade() then
                    _tp(CFrame.new(-10000000, 150, 37016.25))
                else
                    _tp(target)
                end
            end
        end
    else
        if Workspace.Map:FindFirstChild("MysticIsland") and Workspace.Map.MysticIsland:FindFirstChild("Center") then
            _tp(Workspace.Map.MysticIsland.Center.CFrame * CFrame.new(0, 300, 0))
        end
    end
end)

interval("HighestMirage", "HighestMirage", Sec, function()
    if Workspace._WorldOrigin and Workspace._WorldOrigin.Locations:FindFirstChild("Mirage Island", true) then
        if Workspace.Map:FindFirstChild("MysticIsland") and Workspace.Map.MysticIsland:FindFirstChild("Center") then
            _tp(Workspace.Map.MysticIsland.Center.CFrame * CFrame.new(0, 400, 0))
        end
    end
end)

interval("TPGEAR", "TPGEAR", 0.1, function()
    local mi = Workspace.Map:FindFirstChild("MysticIsland")
    if not mi then return end
    for _, v in pairs(mi:GetChildren()) do
        if v.Name == "Part" and v.ClassName == "MeshPart" then
            _tp(v.CFrame)
        end
    end
end)

interval("Addealer", "Addealer", 0.1, function()
    for _, v in pairs(ReplicatedStorage.NPCs:GetChildren()) do
        if v.Name == "Advanced Fruit Dealer" and v:FindFirstChild("HumanoidRootPart") then
            _tp(v.HumanoidRootPart.CFrame)
        end
    end
end)

interval("FarmChestM", "FarmChestM", 0.2, function()
    local mi = Workspace.Map:FindFirstChild("MysticIsland")
    if not mi or not mi:FindFirstChild("Chests") then return end
    if mi.Chests:FindFirstChild("DiamondChest") or mi.Chests:FindFirstChild("FragChest") then
        local tagged = CollectionService:GetTagged("_ChestTagged")
        local best, bestDist = nil, math.huge
        local pos = getRoot().Position
        for _, chest in ipairs(tagged) do
            if not chest:GetAttribute("IsDisabled") then
                local d = (chest:GetPivot().Position - pos).Magnitude
                if d < bestDist then best, bestDist = chest, d end
            end
        end
        if best then _tp(best:GetPivot()) end
    end
end)

-----------------------------------------------------------------
-- Race V4 Trials
-----------------------------------------------------------------

MirageTab:createLabel({ Name = "--- Race V4 ---" })
MirageTab:createToggle({ Name = "Auto Complete Trial Race", Flag = false, flagName = "Complete_Trials" })
MirageTab:createToggle({ Name = "Auto Train V4", Flag = false, flagName = "AcientOne" })
MirageTab:createButton({
    Name = "Talk With Stone",
    Callback = function()
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Begin") end)
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Check") end)
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Teleport") end)
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Continue") end)
    end,
})

local RaceDoors = {
    Mink = CFrame.new(29020.66, 14889.43, -379.27),
    Fishman = CFrame.new(28224.06, 14889.43, -210.59),
    Cyborg = CFrame.new(28492.41, 14894.43, -422.11),
    Skypiea = CFrame.new(28967.41, 14918.08, 234.31),
    Ghoul = CFrame.new(28672.72, 14889.13, 454.60),
    Human = CFrame.new(29237.29, 14889.43, -206.95),
}

interval("Complete_Trials", "Complete_Trials", Sec, function()
    local race = tostring(client.Data.Race.Value)
    if race == "Human" or race == "Ghoul" then
        local mobs = {"Ancient Vampire", "Ancient Zombie"}
        local v = GetConnectionEnemies(mobs)
        if v then Attack.Kill(v, Library.Flags.Complete_Trials) end
    elseif race == "Mink" then
        if Workspace.Map:FindFirstChild("MinkTrial") and Workspace.Map.MinkTrial:FindFirstChild("Ceiling") then
            notween(Workspace.Map.MinkTrial.Ceiling.CFrame * CFrame.new(0, -20, 0))
        end
    elseif race == "Fishman" then
        if Workspace:FindFirstChild("SeaBeasts") then
            for _, v in pairs(Workspace.SeaBeasts:GetChildren()) do
                if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Health") and v.Health.Value > 0 then
                    _tp(CFrame.new(v.HumanoidRootPart.Position.X, Workspace.Map["WaterBase-Plane"].Position.Y + 300, v.HumanoidRootPart.Position.Z))
                    MousePos = v.HumanoidRootPart.Position
                    Useskills("Melee", "Z"); Useskills("Melee", "X"); Useskills("Melee", "C")
                    task.wait(0.1)
                    Useskills("Sword", "Z"); Useskills("Sword", "X")
                    task.wait(0.1)
                    Useskills("Blox Fruit", "Z"); Useskills("Blox Fruit", "X"); Useskills("Blox Fruit", "C")
                    task.wait(0.1)
                    Useskills("Gun", "Z"); Useskills("Gun", "X")
                end
            end
        end
    elseif race == "Cyborg" then
        if Workspace.Map:FindFirstChild("CyborgTrial") and Workspace.Map.CyborgTrial:FindFirstChild("Floor") then
            _tp(Workspace.Map.CyborgTrial.Floor.CFrame * CFrame.new(0, 500, 0))
        end
    elseif race == "Skypiea" then
        if Workspace.Map:FindFirstChild("SkyTrial") and Workspace.Map.SkyTrial:FindFirstChild("Model") then
            notween(Workspace.Map.SkyTrial.Model.FinishPart.CFrame)
        end
    end
end)

interval("AcientOne", "AcientOne", Sec, function()
    local char = getChar()
    if not char then return end
    local raceEnergy = char:FindFirstChild("RaceEnergy")
    if raceEnergy and raceEnergy.Value == 1 then
        Useskills("nil", "Y")
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Buy") end)
        _tp(CFrame.new(-8987.04, 215.86, 5886.71))
        return
    end
    local bones = {"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"}
    local v = GetConnectionEnemies(bones)
    if v then
        Attack.Kill(v, Library.Flags.AcientOne)
    else
        _tp(CFrame.new(-9495.68, 453.59, 5977.35))
    end
end)

-----------------------------------------------------------------
-- Cake Prince + Dough King
-----------------------------------------------------------------

MainTab:createLabel({ Name = "--- Boss Farm ---" })
MainTab:createToggle({ Name = "Auto Cake Prince", Flag = false, flagName = "Auto_Cake_Prince" })
MainTab:createToggle({ Name = "Auto Dough King", Flag = false, flagName = "AutoMiror" })

interval("Auto_Cake_Prince", "Auto_Cake_Prince", 0.1, function()
    local root = getRoot()
    if not root then return end
    local bigMirror = Workspace.Map.CakeLoaf.BigMirror
    if not bigMirror:FindFirstChild("Other") then
        _tp(CFrame.new(-2077, 252, -12373))
        return
    end
    if bigMirror.Other.Transparency == 0 or Workspace.Enemies:FindFirstChild("Cake Prince") then
        local v = GetConnectionEnemies("Cake Prince")
        if v then
            Attack.Kill2(v, Library.Flags.Auto_Cake_Prince)
        else
            if bigMirror.Other.Transparency == 0 and (CFrame.new(-1990.67, 4533, -14973.67).Position - root.Position).Magnitude >= 2000 then
                _tp(CFrame.new(-2151.82, 149.32, -12404.91))
            end
        end
    else
        local cakeMobs = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}
        local v = GetConnectionEnemies(cakeMobs)
        if v then
            Attack.Kill(v, Library.Flags.Auto_Cake_Prince)
        else
            _tp(CFrame.new(-2077, 252, -12373))
        end
    end
end)

interval("AutoMiror", "AutoMiror", Sec, function()
    local v = GetConnectionEnemies("Dough King")
    if v then
        Attack.Kill(v, Library.Flags.AutoMiror)
    else
        _tp(CFrame.new(-1943.68, 251.51, -12337.88))
    end
end)

-----------------------------------------------------------------
-- Elite Hunter
-----------------------------------------------------------------

MainTab:createToggle({ Name = "Auto Elite Hunter", Flag = false, flagName = "FarmEliteHunt" })

interval("FarmEliteHunt", "FarmEliteHunt", Sec, function()
    local questUI = client.PlayerGui:FindFirstChild("Main") and client.PlayerGui.Main:FindFirstChild("Quest")
    if questUI and questUI.Visible then
        local title = questUI.Container.QuestTitle.Title.Text
        if string.find(title, "Diablo") or string.find(title, "Urban") or string.find(title, "Deandre") then
            for _, v in pairs(Workspace.Enemies:GetChildren()) do
                if (string.find(v.Name, "Diablo") or string.find(v.Name, "Urban") or string.find(v.Name, "Deandre")) and Attack.Alive(v) then
                    Attack.Kill(v, Library.Flags.FarmEliteHunt)
                end
            end
        end
    else
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("EliteHunter") end)
    end
end)

-----------------------------------------------------------------
-- Shop Tab
-----------------------------------------------------------------

ShopTab:createToggle({ Name = "Auto Store Fruits", Flag = false, flagName = "StoreF" })

interval("StoreF", "StoreF", Sec, function()
    for _, x in pairs(client.Backpack:GetChildren()) do
        local storeFruit = x:FindFirstChild("EatRemote", true)
        if storeFruit then
            pcall(function()
                ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", storeFruit.Parent:GetAttribute("OriginalName"), client.Backpack:FindFirstChild(x.Name))
            end)
        end
    end
end)

-----------------------------------------------------------------
-- Travel Tab
-----------------------------------------------------------------

local Islands = {
    ["Start Island"] = CFrame.new(1059.75, 15.95, 1550.75),
    ["Marine Start"] = CFrame.new(-2630, 8, 2005),
    ["Jungle"] = CFrame.new(-1603.5, 36.85, 155.5),
    ["Buggy Island"] = CFrame.new(-1140, 4.5, 3827),
    ["Desert"] = CFrame.new(896, 6.4, 4390),
    ["Snow Island"] = CFrame.new(1386, 87, -1298),
    ["Marine Ford"] = CFrame.new(-5035, 28.5, 4324),
    ["Sky Island"] = CFrame.new(-4842, 717.5, -2623),
    ["Prison"] = CFrame.new(5310.5, 0.3, 475),
    ["Colosseum"] = CFrame.new(-1578, 7.4, -2984),
    ["Magma Village"] = CFrame.new(-5316, 12, 8517),
    ["Underwater City"] = CFrame.new(61122, 18, 1569),
    ["Fountain City"] = CFrame.new(5258, 38.5, 4050),
    ["Kingdom of Rose"] = CFrame.new(-428, 73, 1836),
    ["Mansion"] = CFrame.new(-260, 48, -10500),
    ["Castle on Sea"] = CFrame.new(-5170, 50, 7470),
    ["Ice Castle"] = CFrame.new(6410, 18, -6710),
    ["Forgotten Island"] = CFrame.new(-3054.5, 237, -10148),
    ["Port Town"] = CFrame.new(-290, 43.8, 5580),
    ["Hydra Island"] = CFrame.new(5447, 601.5, 749),
    ["Great Tree"] = CFrame.new(2180, 28.7, -6740),
    ["Floating Turtle"] = CFrame.new(-10583, 331.5, -8758),
    ["Haunted Castle"] = CFrame.new(-9481, 142, 5566),
    ["Cake Island"] = CFrame.new(-2022, 37, -12031),
    ["Tiki Island"] = CFrame.new(-16665, 104.5, 1580),
}

local islandNames = {}
for name, _ in pairs(Islands) do table.insert(islandNames, name) end
table.sort(islandNames)

ShopTab:createDropdown({
    Name = "Select Island",
    flagName = "SelectIsland",
    Flag = "Start Island",
    List = islandNames,
})

ShopTab:createButton({
    Name = "Teleport to Island",
    Callback = function()
        local island = Islands[Library.Flags.SelectIsland]
        if island then _tp(island) end
    end,
})

-----------------------------------------------------------------
-- Misc Tab
-----------------------------------------------------------------

MiscTab:createToggle({ Name = "Auto Click", Flag = false, flagName = "AutoClick" })

interval("AutoClick", "AutoClick", 0.05, function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton1(Vector2.new())
end)

MiscTab:createButton({
    Name = "Server Hop",
    Callback = function() Hop() end,
})

MiscTab:createButton({
    Name = "Rejoin Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, client)
    end,
})

MiscTab:createButton({
    Name = "Reset Character",
    Callback = function()
        local char = getChar()
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.Health = 0
        end
    end,
})

-----------------------------------------------------------------
-- Auto stat
-----------------------------------------------------------------

MainTab:createLabel({ Name = "--- Auto Stats ---" })
MainTab:createToggle({ Name = "Auto Melee", Flag = false, flagName = "AutoMelee" })
MainTab:createToggle({ Name = "Auto Defense", Flag = false, flagName = "AutoDefense" })
MainTab:createToggle({ Name = "Auto Sword", Flag = false, flagName = "AutoSword" })
MainTab:createToggle({ Name = "Auto Gun", Flag = false, flagName = "AutoGun" })
MainTab:createToggle({ Name = "Auto Devil Fruit", Flag = false, flagName = "AutoDevil" })

interval("AutoMelee", "AutoMelee", 1, function()
    if client.Data.Points.Value > 0 then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", "Melee", 1)
    end
end)

interval("AutoDefense", "AutoDefense", 1, function()
    if client.Data.Points.Value > 0 then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", "Defense", 1)
    end
end)

interval("AutoSword", "AutoSword", 1, function()
    if client.Data.Points.Value > 0 then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", "Sword", 1)
    end
end)

interval("AutoGun", "AutoGun", 1, function()
    if client.Data.Points.Value > 0 then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", "Gun", 1)
    end
end)

interval("AutoDevil", "AutoDevil", 1, function()
    if client.Data.Points.Value > 0 then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", "Demon Fruit", 1)
    end
end)

-----------------------------------------------------------------
-- Boat collision disable while sailing
-----------------------------------------------------------------

task.spawn(function()
    while task.wait(Sec) do
        pcall(function()
            for _, b in pairs(Workspace.Boats:GetChildren()) do
                for _, d in pairs(b:GetDescendants()) do
                    if d:IsA("BasePart") then
                        if Library.Flags.SailBoats or Library.Flags.FindMirage or Library.Flags.AutofindKitIs then
                            d.CanCollide = false
                        else
                            d.CanCollide = true
                        end
                    end
                end
            end
        end)
    end
end)

-----------------------------------------------------------------
-- Noclip + highlight when farming
-----------------------------------------------------------------

task.spawn(function()
    while task.wait() do
        pcall(function()
            if Library.Flags.FarmLevel or Library.Flags.SailBoats or Library.Flags.FindMirage or Library.Flags.AutofindKitIs then
                shouldTween = true
                local char = getChar()
                if char and char:FindFirstChild("HumanoidRootPart") then
                    if not char.HumanoidRootPart:FindFirstChild("BodyClip") then
                        local bv = Instance.new("BodyVelocity")
                        bv.Name = "BodyClip"
                        bv.Parent = char.HumanoidRootPart
                        bv.MaxForce = Vector3.new(100000, 100000, 100000)
                        bv.Velocity = Vector3.new(0, 0, 0)
                    end
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            else
                shouldTween = false
                local char = getChar()
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local bc = char.HumanoidRootPart:FindFirstChild("BodyClip")
                    if bc then bc:Destroy() end
                end
            end
        end)
    end
end)

-----------------------------------------------------------------

print("Ultimate Blox Fruits Hub — Loaded successfully")
notify("Loaded", "Ultimate Blox Fruits Hub is ready to use.", "info")
