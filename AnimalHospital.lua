--[[
    Versus Airlines - Animal Hospital Ultra
    Version: v3.0 (The Ultimate In-Game Autopilot)
    PlaceId: 104522435597696 / Lobby: 78515283254292
    
    Architected by Senior Roblox Software Engineering Assistant
    - Ultra-optimized event-driven caches (PromptCache & MonsterCache)
    - Full Hospital Autopilot (Handles Rooms 1 to 8: X-Ray, Surgery, Heart Monitor, Medical)
    - Auto Reject Skinwalkers (Detection via custom meshes & attributes, shutter auto-shut)
    - Combat Suite & Extinguisher Exploit (Instantly cleans slime and fires from range)
    - Silent Anti-Jumpscare Hook
    - Dual-Mode Infinite Sanity (Silent local intercept vs Server-side NaN freeze)
]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Library
local client = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local LOBBY_ID = 78515283254292
local MAIN_ID = 104522435597696
local IS_LOBBY = game.PlaceId == LOBBY_ID
local IS_MAIN = game.PlaceId == MAIN_ID
local PLACE = IS_LOBBY and "Lobby" or (IS_MAIN and "Main Game" or "?")

local WORKFLOW_AT = {
    ["Scan Identity"] = true,
    ["Take Photo"] = true,
    ["Take UV Photo"] = true,
    ["Print Badge"] = true,
    ["Take"] = true,
    ["Take Badge"] = true,
    ["Register"] = true,
    ["Analyze Sample"] = true,
    ["Inspect"] = true,
    ["Process Results"] = true,
    ["Complete Analysis"] = true,
    ["Begin X-Ray"] = true,
    ["Collect"] = true,
    ["Collect Results"] = true,
    ["Take Sample"] = true,
    ["Take DNA"] = true,
    ["Set Up"] = true,
    ["Turn On"] = true,
    ["Begin"] = true,
    ["Prepare Patient"] = true,
    ["Apply Treatment"] = true,
    ["Stamp Forms"] = true,
    ["Stamp the form"] = true,
    ["Security Cams"] = true,
    ["Talk"] = true,
    ["Ask to Leave"] = true,
    ["Clean Slime"] = true,
    ["Put out"] = true,
    ["Un-jam button."] = true,
    ["Trash Item"] = true,
    ["Coffee"] = true,
    ["Buy"] = true,
    ["Buy Run Fast Cola"] = true,
    ["Reroll Shop"] = true,
    ["Take Key"] = true,
    ["Accept Gift"] = true,
}

local DANGEROUS_AT = {
    ["Jumpscare All"] = true,
    ["Buy Gun"] = true,
}

local MEDICINE_PRIORITY = {"Eye Drops", "IV Drops", "Medicine", "Herbs", "Antibiotics", "Bandages", "Ointment", "Medkit", "Thermo", "Cough Syrup", "Maple Syrup"}

local OBJECTIVE_TO_AT = {
    ["scan identity"] = {"Scan Identity"},
    ["check in"] = {"Scan Identity"},
    ["register"] = {"Register"},
    ["register in pc"] = {"Register"},
    ["print badge"] = {"Print Badge"},
    ["take badge"] = {"Take Badge", "Take"},
    ["take sample"] = {"Take Sample", "Take DNA", "Collect Sample"},
    ["take sample from patient"] = {"Take Sample", "Take DNA", "Collect Sample"},
    ["analyze the sample"] = {"Analyze Sample"},
    ["analyze sample"] = {"Analyze Sample"},
    ["analyze"] = {"Analyze Sample"},
    ["inspect"] = {"Inspect"},
    ["process results"] = {"Process Results"},
    ["complete analysis"] = {"Process Results", "Complete Analysis"},
    ["complete analysis on pc"] = {"Process Results", "Complete Analysis"},
    ["xray"] = {"Begin X-Ray"},
    ["begin xray"] = {"Begin X-Ray"},
    ["begin scan"] = {"Begin"},
    ["begin"] = {"Begin"},
    ["set up"] = {"Set Up"},
    ["turn on"] = {"Turn On"},
    ["prepare patient"] = {"Prepare Patient"},
    ["prepare"] = {"Prepare Patient"},
    ["apply treatment"] = {"Apply Treatment"},
    ["apply the treatment"] = {"Apply Treatment"},
    ["treat"] = {"Apply Treatment"},
    ["treatment"] = {"Apply Treatment"},
    ["treat the patient"] = {"Apply Treatment"},
    ["collect"] = {"Collect"},
    ["collect results"] = {"Collect"},
    ["take photo"] = {"Take Photo", "Take UV Photo"},
    ["take a photo"] = {"Take Photo", "Take UV Photo"},
    ["photo"] = {"Take Photo", "Take UV Photo"},
    ["stamp forms"] = {"Stamp Forms", "Stamp the form"},
    ["stamp the forms"] = {"Stamp Forms", "Stamp the form"},
    ["stamp form"] = {"Stamp Forms", "Stamp the form"},
    ["stamp the form"] = {"Stamp Forms", "Stamp the form"},
    ["finish the check in"] = {"Talk", "Finish the check-in"},
    ["finish check in"] = {"Talk", "Finish the check-in"},
    ["finish the check-in"] = {"Talk", "Finish the check-in"},
    ["security cams"] = {"Security Cams"},
    ["talk"] = {"Talk"},
    ["ask to leave"] = {"Ask to Leave"},
    ["take key"] = {"Take Key"},
    ["put out"] = {"Put out"},
    ["put out fire"] = {"Put out"},
    ["clean slime"] = {"Clean Slime"},
    ["unjam"] = {"Un-jam button."},
    ["accept gift"] = {"Accept Gift"},
    ["help liz"] = {"Accept Gift", "Help Liz"},
    ["buy"] = {"Buy"},
    ["reroll"] = {"Reroll Shop"},
}

-----------------------------------------------------------------
-- CUSTOM BULLETPROOF JANITOR
-----------------------------------------------------------------
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({ _tasks = {} }, Janitor)
end

function Janitor:Add(task)
    table.insert(self._tasks, task)
    return task
end

function Janitor:Cleanup()
    for _, task in ipairs(self._tasks) do
        if type(task) == "function" then
            pcall(task)
        elseif typeof(task) == "RBXScriptConnection" then
            if task.Connected then task:Disconnect() end
        elseif type(task) == "table" and task.Disconnect then
            pcall(task.Disconnect, task)
        elseif type(task) == "table" and task.destroy then
            pcall(task.destroy, task)
        elseif type(task) == "table" and task.Destroy then
            pcall(task.Destroy, task)
        elseif typeof(task) == "Instance" then
            pcall(task.Destroy, task)
        end
    end
    table.clear(self._tasks)
end

local GlobalJanitor = Janitor.new()

-----------------------------------------------------------------
-- STATE
-----------------------------------------------------------------
State = {
    Running = false,
    CurrentObjective = nil,
    CurrentTarget = nil,
    CheckedInPatients = 0,
    MaxCheckIns = 2,
    ShiftCount = 0,
    Cooldowns = {},
    LastReplayVote = 0,
    LastFlyToggle = false,
    LastNoclipToggle = false,
    ESPObjects = {},
    ActiveTweens = {},
    SessionHealed = 0,
    SessionRejected = 0,
    SessionKilled = 0,
}

-----------------------------------------------------------------
-- PROXIMITY PROMPT CACHE (O(1) lookups instead of loops)
-----------------------------------------------------------------
local PromptCache = {
    _prompts = {},
    _byActionText = {},
    _byModelName = {},
}

function PromptCache:Start()
    local function addPrompt(pp)
        if not pp:IsA("ProximityPrompt") then return end
        self._prompts[pp] = true
        
        local at = pp.ActionText
        if not self._byActionText[at] then self._byActionText[at] = {} end
        self._byActionText[at][pp] = true
        
        local model = pp:FindFirstAncestorWhichIsA("Model")
        local mName = model and model.Name or ""
        if mName ~= "" then
            if not self._byModelName[mName] then self._byModelName[mName] = {} end
            self._byModelName[mName][pp] = true
        end
        
        local atConn = pp:GetPropertyChangedSignal("ActionText"):Connect(function()
            local oldAt = at
            local newAt = pp.ActionText
            if self._byActionText[oldAt] then self._byActionText[oldAt][pp] = nil end
            if not self._byActionText[newAt] then self._byActionText[newAt] = {} end
            self._byActionText[newAt][pp] = true
            at = newAt
        end)
        
        local parentConn = pp:GetPropertyChangedSignal("Parent"):Connect(function()
            local oldMName = mName
            local newModel = pp:FindFirstAncestorWhichIsA("Model")
            local newMName = newModel and newModel.Name or ""
            if oldMName ~= "" and self._byModelName[oldMName] then
                self._byModelName[oldMName][pp] = nil
            end
            if newMName ~= "" then
                if not self._byModelName[newMName] then self._byModelName[newMName] = {} end
                self._byModelName[newMName][pp] = true
            end
            mName = newMName
        end)
        
        GlobalJanitor:Add(atConn)
        GlobalJanitor:Add(parentConn)
    end

    local function removePrompt(pp)
        if not pp:IsA("ProximityPrompt") then return end
        self._prompts[pp] = nil
        for _, list in pairs(self._byActionText) do list[pp] = nil end
        for _, list in pairs(self._byModelName) do list[pp] = nil end
    end

    for _, pp in ipairs(Workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then addPrompt(pp) end
    end

    local addConn = Workspace.DescendantAdded:Connect(addPrompt)
    local removeConn = Workspace.DescendantRemoving:Connect(removePrompt)
    GlobalJanitor:Add(addConn)
    GlobalJanitor:Add(removeConn)
    
    print("[PromptCache] Loaded prompts: " .. #self:GetAllPrompts())
end

function PromptCache:GetAllPrompts()
    local list = {}
    for pp in pairs(self._prompts) do table.insert(list, pp) end
    return list
end

function PromptCache:GetPromptsByActionText(actionText)
    return self._byActionText[actionText] or {}
end

function PromptCache:GetNearestPrompt(actionText, maxDistance)
    local root = getRoot()
    if not root then return nil, nil end
    
    maxDistance = maxDistance or math.huge
    local bestPrompt, bestModel, bestDist = nil, nil, maxDistance
    
    local candidates = self:GetPromptsByActionText(actionText)
    for pp in pairs(candidates) do
        if pp.Enabled then
            local model = pp:FindFirstAncestorWhichIsA("Model")
            if model then
                local dist = (root.Position - model:GetPivot().Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPrompt = pp
                    bestModel = model
                end
            end
        end
    end
    return bestModel, bestPrompt, bestDist
end

function PromptCache:GetNearestWorkflowPrompt()
    local root = getRoot()
    if not root then return nil, nil end

    local bestPrompt, bestModel, bestDist = nil, nil, math.huge
    for pp in pairs(self._prompts) do
        if pp.Enabled and WORKFLOW_AT[pp.ActionText] and not DANGEROUS_AT[pp.ActionText] then
            local model = pp:FindFirstAncestorWhichIsA("Model")
            if model then
                local dist = (root.Position - model:GetPivot().Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPrompt = pp
                    bestModel = model
                end
            end
        end
    end
    return bestModel, bestPrompt
end

-----------------------------------------------------------------
-- MONSTER CACHE (Saves CPU during flee checks)
-----------------------------------------------------------------
local MonsterCache = {
    _monsters = {},
    _tags = {"Shadow", "TallMonsterHead", "TallMonsterSpawn", "Zombie", "Skinwalker", "StalkerJumpscare", "EyeMass"},
    _names = {"shadow", "tallmonster", "monsterbed", "hider", "ghost", "skinwalker", "zombie", "stalker", "hollow", "eyemass"}
}

function MonsterCache:Start()
    local function checkAndAdd(obj)
        if not obj:IsA("Model") then return end
        local name = obj.Name:lower()
        local isMonster = false
        for _, pat in ipairs(self._names) do
            if name:find(pat) then isMonster = true; break end
        end
        if not isMonster then
            for _, tag in ipairs(self._tags) do
                if CollectionService:HasTag(obj, tag) then isMonster = true; break end
            end
        end
        if isMonster then self._monsters[obj] = true end
    end

    local function checkAndRemove(obj)
        self._monsters[obj] = nil
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do checkAndAdd(obj) end

    local addConn = Workspace.DescendantAdded:Connect(checkAndAdd)
    local removeConn = Workspace.DescendantRemoving:Connect(checkAndRemove)
    GlobalJanitor:Add(addConn)
    GlobalJanitor:Add(removeConn)
end

function MonsterCache:GetMonsters()
    local list = {}
    for m in pairs(self._monsters) do
        if m.Parent then table.insert(list, m) end
    end
    return list
end

-----------------------------------------------------------------
-- SKINWALKER DETECTION & AUTO REJECT ENGINE
-----------------------------------------------------------------
function isSkinwalker(npc)
    if not npc or not npc:IsA("Model") then return false end
    if npc:GetAttribute("CameraEffect") or npc:GetAttribute("PhotoEffect") or npc:GetAttribute("DisguiseReveal") then
        return true
    end
    -- Scan hidden anatomy subparts (specific to skinwalkers)
    for _, partName in ipairs({"Gulp", "Tooth", "TongueMesh", "Spit", "Teeth"}) do
        if npc:FindFirstChild(partName, true) then
            return true
        end
    end
    if npc.Name:lower():find("skinwalker") then
        return true
    end
    return false
end

function checkAndRejectSkinwalker()
    if not Library.Flags["AutoRejectSkinwalkers"] then return false end
    
    local scanList = PromptCache:GetPromptsByActionText("Scan Identity")
    for pp in pairs(scanList) do
        if pp.Enabled then
            local model = pp:FindFirstAncestorWhichIsA("Model")
            if model and isSkinwalker(model) then
                print("[Ultra Control] Detected Skinwalker at front desk!")
                
                local shutterModel = Workspace:FindFirstChild("ShutterButton", true) or Workspace:FindFirstChild("Shutters", true)
                if shutterModel then
                    local shutterPP = shutterModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if shutterPP and shutterPP.Enabled then
                        safeMoveToModel(shutterModel, function()
                            pcall(function()
                                shutterPP.HoldDuration = 0
                                if fireproximityprompt then
                                    fireproximityprompt(shutterPP, 1)
                                else
                                    shutterPP:InputHoldBegin()
                                    task.wait(0.1)
                                    shutterPP:InputHoldEnd()
                                end
                                State.SessionRejected = State.SessionRejected + 1
                                notify("Anti-Skinwalker", "Rejected Disguised Skinwalker!")
                            end)
                        end)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-----------------------------------------------------------------
-- HEART AND MONITOR TEXT BOARD PARSER (Rooms 1 to 8)
-----------------------------------------------------------------
function getTreatmentOrIllness(roomModel)
    if not roomModel then return nil end
    local minigame = roomModel:FindFirstChild("Minigame", true)
    if not minigame then return nil end
    
    -- Try Monitor (Illnesses)
    local monitor = minigame:FindFirstChild("Monitor", true)
    if monitor then
        local screen = monitor:FindFirstChild("Screen", true)
        local ui = screen and screen:FindFirstChild("UI", true)
        local report = ui and ui:FindFirstChild("Report", true)
        local illnesses = report and report:FindFirstChild("illnesses", true)
        if illnesses and illnesses.Text ~= "" then
            return illnesses.Text
        end
    end
    
    -- Try TV (Treatment)
    local tv = minigame:FindFirstChild("TV", true)
    if tv then
        local screen = tv:FindFirstChild("Screen", true)
        local ui = screen and screen:FindFirstChild("UI", true)
        local report = ui and ui:FindFirstChild("Report", true)
        local treatment = report and report:FindFirstChild("treatment", true)
        if treatment and treatment.Text ~= "" then
            return treatment.Text
        end
    end
    
    return nil
end

-----------------------------------------------------------------
-- UI LIBRARY LOADER
-----------------------------------------------------------------
print("Loading Versus Library...")

    local loadOk, loadErr = pcall(function()
        Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
    end)
    if not loadOk or not Library then
        warn("[Versus] Failed to load library:", loadErr)
        return
    end

local ui = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Top Center"
})

-----------------------------------------------------------------
-- ANTI IDLE
-----------------------------------------------------------------
local antiIdleConn = client.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
    end)
end)
GlobalJanitor:Add(antiIdleConn)

-----------------------------------------------------------------
-- CORE UTILS
-----------------------------------------------------------------
function notify(title, desc, style)
    pcall(function()
        Library:createDisplayMessage(tostring(title), tostring(desc), {{ text = "OK" }}, style or "info")
    end)
end

local activeIntervals = {}
function interval(tag, flag, delayTime, callback)
    if activeIntervals[tag] then
        activeIntervals[tag]:Disconnect()
        activeIntervals[tag] = nil
    end
    delayTime = math.max(tonumber(delayTime) or 1, 0.05)

    local last = 0
    local running = false
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags or not Library.Flags[flag] then return end
        local now = tick()
        if running or (now - last) < delayTime then return end
        last = now
        running = true
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then warn("[interval:" .. tostring(tag) .. "]", err) end
            task.wait()
            running = false
        end)
    end)

    activeIntervals[tag] = conn
    GlobalJanitor:Add(conn)
end

function getChar() return client.Character end

function getRoot()
    local char = getChar()
    if char then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    end
    return nil
end

function getHumanoid()
    local char = getChar()
    if char then return char:FindFirstChildOfClass("Humanoid") end
    return nil
end

function distanceTo(pos)
    local root = getRoot()
    if root and pos then return (root.Position - pos).Magnitude end
    return math.huge
end

function isCooldown(key, duration)
    duration = duration or 1.2
    local now = tick()
    if State.Cooldowns[key] and (now - State.Cooldowns[key]) < duration then
        return true
    end
    State.Cooldowns[key] = now
    return false
end

function clearActiveTweens()
    for _, tw in ipairs(State.ActiveTweens) do pcall(function() tw:Cancel() end) end
    table.clear(State.ActiveTweens)
end

function safeMoveToModel(model, callback)
    local root = getRoot()
    if not root or not model then return end
    
    local pivot = model:GetPivot()
    local targetPos = (pivot * CFrame.new(0, 0, 3.2)).Position
    local dist = (root.Position - targetPos).Magnitude
    
    if dist < 4 then
        if callback then callback() end
        return
    end
    
    clearActiveTweens()
    
    if Library.Flags["MovementMode"] == "Tween" then
        local speed = Library.Flags["TweenSpeed"] or 65
        local duration = dist / speed
        local twInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(root, twInfo, { CFrame = CFrame.new(targetPos) })
        table.insert(State.ActiveTweens, tween)
        
        local conn
        conn = tween.Completed:Connect(function()
            if conn then conn:Disconnect() end
            if callback then callback() end
        end)
        tween:Play()
    else
        root.CFrame = CFrame.new(targetPos)
        task.wait(0.12)
        if callback then callback() end
    end
end

-----------------------------------------------------------------
-- NETWORK COMMUNICATIONS
-----------------------------------------------------------------
local NetworkObj = (function()
    local ok, util = pcall(function() return ReplicatedStorage:WaitForChild("Util", 5) end)
    if ok and util then
        local ok2, net = pcall(function() return util:WaitForChild("Net", 5) end)
        if ok2 and net then
            local ok3, netMod = pcall(require, net)
            if ok3 and netMod then return netMod.Network or netMod end
        end
    end
    local ok2, lib = pcall(function() return require(ReplicatedStorage:WaitForChild("Lib", 5)) end)
    if ok2 and lib then return lib.Network end
    return nil
end)()

function fireRemote(name, ...)
    local args = {...}
    local baseName = name
    if baseName:sub(1, 3) == "RE/" then baseName = baseName:sub(4) end

    if NetworkObj then
        pcall(function()
            if NetworkObj.FireServer then
                NetworkObj:FireServer(baseName, unpack(args))
            elseif NetworkObj.fireServer then
                NetworkObj:fireServer(baseName, unpack(args))
            end
        end)
        return
    end

    pcall(function()
        local rem = ReplicatedStorage.Util.RE:FindFirstChild(baseName)
        if rem and rem:IsA("RemoteEvent") then
            rem:FireServer(unpack(args))
        end
    end)
end

function connectRemote(name, callback)
    local baseName = name
    if baseName:sub(1, 3) == "RE/" then baseName = baseName:sub(4) end

    if NetworkObj and NetworkObj.Connect then
        pcall(function() NetworkObj:Connect(baseName, callback) end)
        return true
    end

    pcall(function()
        local rem = ReplicatedStorage.Util.RE:FindFirstChild(baseName)
        if rem and rem:IsA("RemoteEvent") then
            local conn = rem.OnClientEvent:Connect(callback)
            GlobalJanitor:Add(conn)
        end
    end)
    return true
end

-----------------------------------------------------------------
-- DUAL-MODE INFINITE SANITY & BYPASS SYSTEMS
-----------------------------------------------------------------
local originalPlayerLostSanity = nil

function setupSanityHook()
    local ok, Lib = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Lib", 10))
    end)
    if ok and Lib then
        originalPlayerLostSanity = Lib.PlayerLostSanity
        Lib.PlayerLostSanity = function(amount, reason, suppressRemote)
            -- Mode 1: Silent Hook
            if Library.Flags["SanityMode"] == "Silent Local Hook" then
                pcall(function() client:SetAttribute("Sanity", 100) end)
                return
            end
            
            if originalPlayerLostSanity then
                return originalPlayerLostSanity(amount, reason, suppressRemote)
            end
        end
    end
end

-- Mode 2: Server-side NaN Exploit
function triggerServerNaNFreeze()
    if Library.Flags["SanityMode"] == "Server NaN Exploit" then
        pcall(function()
            local args = { math.huge / math.huge, "Job Stress", true }
            fireRemote("RE/PlayerLostSanity", unpack(args))
        end)
    end
end

-- Silent Anti-Jumpscare
local function setupJumpscareBypass()
    local ok, Net = pcall(function() return require(ReplicatedStorage.Util.Net) end)
    if ok and Net then
        local originalConnect = Net.Connect
        Net.Connect = function(self, name, callback)
            if Library.Flags["AntiJumpscare"] then
                if name:lower():find("jumpscare") or name:lower():find("cutscene") then
                    print("[Anti-Jumpscare] Intercepted network connection to:", name)
                    return { Disconnect = function() end }
                end
            end
            return originalConnect(self, name, callback)
        end
    end
end

-----------------------------------------------------------------
-- COMBAT SUITE EXPLOITS (Direct Range Cleaning & Attacks)
-----------------------------------------------------------------
function cleanAllSlime()
    if not Library.Flags["AutoCleanSlime"] then return end
    for _, grime in ipairs(CollectionService:GetTagged("Grime")) do
        fireRemote("ExtinguisherBubbleHitGrime", grime)
    end
end

function extinguishAllFires()
    if not Library.Flags["AutoExtinguishFires"] then return end
    for _, part in ipairs(CollectionService:GetTagged("OnFire")) do
        fireRemote("ExtinguisherBubbleHit", part)
    end
    for _, npc in ipairs(CollectionService:GetTagged("NPC")) do
        if npc:HasTag("OnFire") then fireRemote("ExtinguisherBubbleHitFireNPC", npc) end
    end
    local char = getChar()
    if char and char:HasTag("OnFire") then fireRemote("ExtinguisherBubbleHitFireNPC", char) end
end

function autoFightAnomaliesAndGhosts()
    if not Library.Flags["AutoFightAnomalies"] then return end
    for _, m in ipairs(MonsterCache:GetMonsters()) do
        if m:HasTag("GhostAnomaly") or m.Name:lower():find("ghost") then
            fireRemote("ExtinguisherBubbleHitGhost", m)
            fireRemote("ScannerKillGhost", m)
            State.SessionKilled = State.SessionKilled + 1
        end
    end
end

function zombieAura()
    if not Library.Flags["ZombieAura"] then return end
    local char = getChar()
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle then return end
    
    local zombies = {}
    for _, z in ipairs(CollectionService:GetTagged("Zombie")) do
        if z:IsA("Model") and z.PrimaryPart then
            local dist = distanceTo(z.PrimaryPart.Position)
            if dist < (Library.Flags["CombatRange"] or 25) then
                local hum = z:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    table.insert(zombies, z)
                end
            end
        end
    end
    
    if #zombies > 0 then
        fireRemote("HitMultipleZombies", zombies, handle)
    end
end

-----------------------------------------------------------------
-- PROMPT TRIGGERS & AUTOPILOT ENGINE
-----------------------------------------------------------------
function fireModelPrompt(model, expectAT)
    if not model then return false end
    
    local pp = nil
    if expectAT then
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("ProximityPrompt") and child.ActionText == expectAT then
                pp = child
                break
            end
        end
    end
    
    if not pp then
        pp = model:FindFirstChild("PP") or model:FindFirstChild("ProximityPrompt") or model:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    
    if not pp or not pp.Enabled then return false end
    if DANGEROUS_AT[pp.ActionText] then return false end

    local cooldownKey = tostring(model) .. "|" .. tostring(pp.ActionText)
    if isCooldown(cooldownKey, 1.1) then return false end

    safeMoveToModel(model, function()
        if pp.ActionText == "Apply Treatment" then
            equipMedicine()
        end

        pcall(function()
            pp.HoldDuration = 0
            pp.MaxActivationDistance = 22
            if fireproximityprompt then
                fireproximityprompt(pp, 1)
            elseif firesignal then
                firesignal(pp.Triggered, client)
            else
                pp:InputHoldBegin()
                task.wait(0.1)
                pp:InputHoldEnd()
            end
        end)
    end)
    
    return true
end

function getToolCount()
    local count = 0
    local backpack = client:FindFirstChild("Backpack")
    local char = getChar()
    if backpack then
        for _, v in ipairs(backpack:GetChildren()) do if v:IsA("Tool") then count = count + 1 end end
    end
    if char then
        for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then count = count + 1 end end
    end
    return count
end

function equipTool(toolName)
    local backpack = client:FindFirstChild("Backpack")
    local char = getChar()
    local hum = getHumanoid()
    if not backpack or not char or not hum then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:find(toolName) or toolName:find(tool.Name)) then
            pcall(function() hum:EquipTool(tool) end)
            return tool
        end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:find(toolName) or toolName:find(tool.Name)) then return tool end
    end
    return nil
end

function buyTool(toolName)
    local model, pp = PromptCache:GetNearestPrompt(toolName)
    if model then fireModelPrompt(model) return true end
    return false
end

function trashItems()
    local trash = Workspace:FindFirstChild("Trash")
    if trash then fireModelPrompt(trash) end
end

function equipMedicine()
    for _, name in ipairs(MEDICINE_PRIORITY) do
        local tool = equipTool(name)
        if tool then return tool end
    end
    for _, name in ipairs({"Eye Drops", "Medicine", "Herbs"}) do
        if buyTool(name) then
            task.wait(0.3)
            local tool = equipTool(name)
            if tool then return tool end
        end
    end
    return nil
end

function isPatientOwned(model)
    if not Library.Flags["MultiFarm"] then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= client and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root and model then
                if (root.Position - model:GetPivot().Position).Magnitude < 12 then return true end
            end
        end
    end
    return false
end

function getExpectedATs(text)
    if type(text) ~= "string" then return nil end
    local key = text:lower():gsub("[^%a%s]", "")
    local direct = OBJECTIVE_TO_AT[key]
    if direct then return direct end
    for k, v in pairs(OBJECTIVE_TO_AT) do
        local nk = k:lower():gsub("[^%a%s]", "")
        if key:find(nk, 1, true) or nk:find(key, 1, true) then return v end
    end
    return nil
end

-----------------------------------------------------------------
-- SERVER ROUND EVENT REGISTER
-----------------------------------------------------------------
function hookServerEvents()
    connectRemote("SetObjective", function(...)
        local args = {...}
        local text, target
        if type(args[1]) == "table" then
            text = args[1][1]
            target = args[1][3]
        else
            text = args[1]
            target = args[3]
        end
        if type(text) == "string" and text ~= "" then
            State.CurrentObjective = text
            State.CurrentTarget = target
        else
            State.CurrentObjective = nil
            State.CurrentTarget = nil
        end
    end)

    connectRemote("StartHeartbeatMinigame", function(id)
        if Library.Flags["AutoHeartbeat"] then
            task.wait(0.25)
            fireRemote("RE/HeartbeatMinigameComplete", id, true)
        end
    end)

    connectRemote("PlayCutscene", function(name)
        if name == "ThreePatientsDiedEnding" and Library.Flags["AutoReplay"] then
            task.wait(3)
            fireRemote("RE/PlayAgainVote")
        end
    end)

    connectRemote("DisplayRoundStats", function()
        State.CheckedInPatients = 0
        State.ShiftCount = State.ShiftCount + 1
        local maxShifts = Library.Flags["ReplayShifts"] or 1
        if Library.Flags["AutoReplay"] and State.ShiftCount < maxShifts and (tick() - State.LastReplayVote) > 10 then
            State.LastReplayVote = tick()
            task.wait(2)
            fireRemote("RE/PlayAgainVote")
        end
    end)
end

-----------------------------------------------------------------
-- COMPLETE AUTOPILOT FARM LOOP (Rooms 1 to 8)
-----------------------------------------------------------------
function followObjective()
    if not State.CurrentObjective then return false end
    
    local objLower = State.CurrentObjective:lower()
    if objLower:find("follow") or objLower:find("wait") then return true end

    local expected = getExpectedATs(State.CurrentObjective)
    local expectAT = expected and expected[1] or nil

    local targetModel = nil
    if State.CurrentTarget then
        pcall(function()
            if State.CurrentTarget:IsA("Model") then
                targetModel = State.CurrentTarget
            else
                targetModel = State.CurrentTarget:FindFirstAncestorWhichIsA("Model")
            end
        end)
    end
    
    if targetModel then
        if not isPatientOwned(targetModel) then
            return fireModelPrompt(targetModel, expectAT)
        end
    end

    if expected then
        for _, at in ipairs(expected) do
            local model, pp = PromptCache:GetNearestPrompt(at)
            if model and not isPatientOwned(model) then
                return fireModelPrompt(model, at)
            end
        end
    end
    return false
end

function scanIdentity()
    if not Library.Flags["AutoCheckIn"] then return end
    if State.CheckedInPatients >= State.MaxCheckIns then return end
    
    -- Safety skinwalker intercept before checking in
    if checkAndRejectSkinwalker() then return end
    
    local model, pp = PromptCache:GetNearestPrompt("Scan Identity")
    if model then
        if fireModelPrompt(model, "Scan Identity") then
            State.CheckedInPatients = State.CheckedInPatients + 1
        end
    end
end

function handleVisitorFlow()
    if not Library.Flags["VisitorFlow"] then return end
    local obj = State.CurrentObjective
    if obj and (obj:lower():find("follow") or obj:lower():find("wait")) then return end
    
    local order = {"Stamp Forms", "Stamp the form", "Take Photo", "Take UV Photo", "Register", "Print Badge", "Take Badge", "Take", "Talk", "Finish the check-in"}
    for _, at in ipairs(order) do
        local model, pp = PromptCache:GetNearestPrompt(at)
        if model then fireModelPrompt(model, at) return end
    end
end

function handleRoomTreatment()
    if not Library.Flags["RoomTreatment"] then return end
    
    local treatmentATs = {
        "Prepare Patient", "Analyze Sample", "Process Results", "Apply Treatment",
        "Ask to Leave", "Complete Analysis", "Take Sample", "Collect Results", "Treat", "Give Medicine"
    }
    
    local candidates = {}
    for _, at in ipairs(treatmentATs) do
        local list = PromptCache:GetPromptsByActionText(at)
        for pp in pairs(list) do
            if pp.Enabled then
                local model = pp:FindFirstAncestorWhichIsA("Model")
                if model and not isPatientOwned(model) then
                    table.insert(candidates, { Model = model, Text = at, PP = pp })
                end
            end
        end
    end
    
    table.sort(candidates, function(a, b)
        return distanceTo(a.Model:GetPivot().Position) < distanceTo(b.Model:GetPivot().Position)
    end)
    
    local c = candidates[1]
    if c then
        if c.Text == "Apply Treatment" then
            -- TV and Monitor screen illness detection (Generic Rooms 1 to 8 support!)
            local room = c.Model:FindFirstAncestorWhichIsA("Model")
            local illness = getTreatmentOrIllness(room)
            
            if illness then
                local cure = getCureForIllness(illness)
                if cure then equipTool(cure) end
            else
                equipMedicine()
            end
        end
        fireModelPrompt(c.Model, c.Text)
    end
end

function handleEmergency()
    if not Library.Flags["EmergencyRooms"] then return end
    
    for pp, model in pairs(PromptCache._prompts) do
        if pp.Enabled and not isPatientOwned(model) then
            local name = model.Name
            if name:find("Ambulance") or name:find("Critical") or name:find("Emergency") then
                fireModelPrompt(model)
                return
            end
        end
    end
end

function startShift()
    if not Library.Flags["AutoShift"] then return end
    
    local desk = Workspace:FindFirstChild("Misc") and Workspace.Misc:FindFirstChild("StartShift")
    if desk then
        local pp = desk:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pp and pp.Enabled then fireModelPrompt(desk) return end
    end
    
    for pp, model in pairs(PromptCache._prompts) do
        if pp.Enabled then
            local name = model.Name
            if name:find("StartShift") or name:find("ShiftButton") or name:find("Computer") then
                fireModelPrompt(model)
                return
            end
        end
    end
end

function handleFainted()
    if not Library.Flags["CarryFainted"] then return end
    local root = getRoot()
    if not root then return end
    
    for _, tag in ipairs({"Downed", "DeadPlayer"}) do
        for _, m in ipairs(CollectionService:GetTagged(tag)) do
            if m:IsA("Model") then
                local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m:FindFirstChildWhichIsA("BasePart")
                if p and distanceTo(p.Position) < 40 then
                    root.CFrame = p.CFrame + Vector3.new(0, 5, 0)
                    task.wait(0.2)
                    local hum = getHumanoid()
                    if hum then pcall(function() hum:MoveTo(root.Position + Vector3.new(40, 0, 0)) end) end
                    return
                end
            end
        end
    end
end

function handlePeopleOnFire()
    if not Library.Flags["PutOutFire"] then return end
    if Library.Flags["FireStrat"] and Library.Flags["AutoShift"] then return end
    
    local fireModel, firePrompt = PromptCache:GetNearestPrompt("Put out")
    if fireModel then fireModelPrompt(fireModel, "Put out") return end
end

function handleEyeMass()
    if not Library.Flags["AvoidEyeMass"] then return end
    local root = getRoot()
    if not root then return end
    
    for pp, model in pairs(PromptCache._prompts) do
        if pp.Enabled then
            local name = model.Name:lower()
            if name:find("eyemass") or name:find("eye mass") then
                local pivot = model:GetPivot()
                local dist = (root.Position - pivot.Position).Magnitude
                if dist < 40 then
                    equipTool("Eye Drops")
                    if dist > 10 then safeMoveToModel(model) end
                    fireModelPrompt(model, "Apply Treatment")
                    return
                end
            end
        end
    end
end

function fleeMonsters()
    if not Library.Flags["AvoidMonsters"] then return end
    local root = getRoot()
    if not root then return end
    
    local monsters = MonsterCache:GetMonsters()
    for _, m in ipairs(monsters) do
        local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m:FindFirstChildWhichIsA("BasePart")
        if p then
            local dist = (root.Position - p.Position).Magnitude
            if dist < 32 then
                local dir = (root.Position - p.Position).Unit
                pcall(function() root.CFrame = CFrame.new(root.Position + dir * 55) end)
                clearActiveTweens()
                return
            end
        end
    end
end

function handleFixCams()
    if not Library.Flags["FixCams"] then return end
    for pp, model in pairs(PromptCache._prompts) do
        if pp.Enabled and model.Name:lower():find("camera") then
            fireModelPrompt(model)
            task.wait(2)
            return
        end
    end
end

function handleTakeDNA()
    if not Library.Flags["TakeDNA"] then return end
    for pp, model in pairs(PromptCache._prompts) do
        if pp.Enabled and (model.Name:lower():find("dna") or model.Name:lower():find("sample")) then
            fireModelPrompt(model)
            return
        end
    end
end

function helpLiz()
    if not Library.Flags["HelpLiz"] then return end
    local lizModel, lizPrompt = PromptCache:GetNearestPrompt("Help Liz")
    if lizModel then fireModelPrompt(lizModel, "Help Liz") return end
    
    local giftModel, giftPrompt = PromptCache:GetNearestPrompt("Accept Gift")
    if giftModel then fireModelPrompt(giftModel, "Accept Gift") return end
end

function stalkerHandler()
    if not Library.Flags["StalkerHandler"] then return end
    for _, m in ipairs(MonsterCache:GetMonsters()) do
        if m.Name:lower():find("stalker") then
            local p = m:FindFirstChildWhichIsA("BasePart")
            if p and distanceTo(p.Position) < 60 then
                fleeMonsters()
                return
            end
        end
    end
end

function autoBuyItems()
    if not Library.Flags["AutoBuyItems"] then return end
    local item = Library.Flags["AutoBuyItemName"]
    if not item then return end
    
    if getToolCount() >= 3 then
        trashItems()
        task.wait(0.5)
    end
    local model, pp = PromptCache:GetNearestPrompt(item)
    if model then fireModelPrompt(model) end
end

function handleInventory()
    if not Library.Flags["AutoTrash"] then return end
    if getToolCount() >= 3 then trashItems() end
end

function autoTaseCritical()
    if not Library.Flags["AutoTaseCritical"] then return end
    local mode = Library.Flags["TaseCriticalRoom"] or "All"
    
    for _, m in ipairs(Workspace:GetDescendants()) do
        if m:IsA("Model") and m.Name:lower():find("critical") then
            local roomOk = (mode == "All") or (m.Name:find(tostring(mode)))
            if roomOk then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
                    if p and distanceTo(p.Position) < 30 then
                        fireRemote("RE/TaserFired", p.Position, m)
                        task.wait(0.3)
                    end
                end
            end
        end
    end
end

function infiniteTaseAll()
    if not Library.Flags["InfiniteTaseAll"] then return end
    local taser = equipTool("Taser") or equipTool("X-Taser")
    if not taser then return end
    
    for pp, m in pairs(PromptCache._prompts) do
        if m:GetAttribute("IsPatient") or m.Name:lower():find("patient") or m.Name:lower():find("visitor") then
            local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
            if p and distanceTo(p.Position) < 50 then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    fireRemote("RE/TaserFired", p.Position, m)
                    task.wait(0.1)
                end
            end
        end
    end
end

function coinFarm()
    if not Library.Flags["CoinFarm"] then return end
    for pp, model in pairs(PromptCache._prompts) do
        if pp.Enabled then
            local name = model.Name:lower()
            if name:find("coin") or name:find("cash") or name:find("shutter") then
                fireModelPrompt(model)
                return
            end
        end
    end
end

function infiniteLives()
    if not Library.Flags["InfiniteLives"] then return end
    local hum = getHumanoid()
    if hum and hum.Health <= 0 then fireRemote("RE/ReviveOther", client) end
end

function autoRevive()
    if not Library.Flags["AutoRevive"] then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= client and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if (hum and hum.Health <= 0) or plr.Character:GetAttribute("Downed") then
                fireRemote("RE/ReviveOther", plr)
                task.wait(0.5)
            end
        end
    end
end

function instantPP()
    if not Library.Flags["InstantPP"] then return end
    for pp in pairs(PromptCache._prompts) do pcall(function() pp.HoldDuration = 0 end) end
end

-----------------------------------------------------------------
-- EMERGENCY UTILITIES (Candles, Safes, etc.)
-----------------------------------------------------------------
function autoBlowCandles()
    if not Library.Flags["AutoBlowCandles"] then return end
    local m, pp = PromptCache:GetNearestPrompt("Blow out")
    if m then fireModelPrompt(m, "Blow out") end
end

function autoOpenSafes()
    if not Library.Flags["AutoOpenSafes"] then return end
    local m, pp = PromptCache:GetNearestPrompt("Open")
    if m and m.Name:lower():find("safe") then fireModelPrompt(m, "Open") end
end

-----------------------------------------------------------------
-- MOVEMENT SYSTEMS
-----------------------------------------------------------------
function applyMovement()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = Library.Flags["WalkSpeed"] or 16
        hum.UseJumpPower = true
        hum.JumpPower = Library.Flags["JumpPower"] or 50
    end
end

local flyBV, flyBG, flyConn
function toggleFly(enabled)
    State.LastFlyToggle = enabled
    local root = getRoot()
    if enabled then
        if not root then return end
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
        
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
        
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxForce = Vector3.new(1, 1, 1) * 9e9
        flyBG.P = 9e4
        flyBG.Parent = root
        
        local hum = getHumanoid()
        if hum then hum.PlatformStand = true end
        
        if flyConn then flyConn:Disconnect() end
        flyConn = RunService.RenderStepped:Connect(function()
            if not Library.Flags["Fly"] then toggleFly(false); return end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
            flyBV.Velocity = dir * (Library.Flags["FlySpeed"] or 50)
            flyBG.CFrame = cam.CFrame
        end)
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        local hum = getHumanoid()
        if hum then hum.PlatformStand = false end
    end
end

local ncConn
function toggleNoclip(enabled)
    State.LastNoclipToggle = enabled
    if ncConn then ncConn:Disconnect(); ncConn = nil end
    if not enabled then return end
    ncConn = RunService.Stepped:Connect(function()
        if not Library.Flags["Noclip"] then
            if ncConn then ncConn:Disconnect(); ncConn = nil end
            return
        end
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
end

local infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
    if Library.Flags["InfiniteJump"] then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
GlobalJanitor:Add(infiniteJumpConn)

-----------------------------------------------------------------
-- PERFORMANCE STABLE ESP ENGINE
-----------------------------------------------------------------
function clearESP()
    for _, obj in ipairs(State.ESPObjects) do pcall(function() obj:Destroy() end) end
    table.clear(State.ESPObjects)
end

function createEsp(target, color, text)
    if not target then return end
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = 0.55
        h.OutlineTransparency = 0
        h.Adornee = target
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = target
        return h
    end)
    if ok and hl then table.insert(State.ESPObjects, hl) end
    if text and Library.Flags["ESPShowNames"] then
        pcall(function()
            local bg = Instance.new("BillboardGui")
            bg.Size = UDim2.new(0, 100, 0, 20)
            bg.StudsOffset = Vector3.new(0, 3, 0)
            bg.AlwaysOnTop = true
            bg.Adornee = target
            bg.Parent = target
            
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.TextColor3 = color
            tl.TextStrokeTransparency = 0.5
            tl.Text = text
            tl.Parent = bg
            
            table.insert(State.ESPObjects, bg)
        end)
    end
end

function updateESP()
    if not Library.Flags["ESPEnabled"] then
        clearESP()
        return
    end
    clearESP()
    
    if Library.Flags["ESPPlayers"] then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= client and plr.Character then
                createEsp(plr.Character, Color3.fromRGB(0, 170, 255), plr.Name)
            end
        end
    end
    
    if Library.Flags["ESPPatients"] then
        local npcs = Workspace:FindFirstChild("NPCs")
        if npcs then
            for _, m in ipairs(npcs:GetChildren()) do
                if m:GetAttribute("IsPatient") then
                    createEsp(m, Color3.fromRGB(0, 255, 100), "Patient")
                end
            end
        end
    end
    
    if Library.Flags["ESPMonsters"] then
        for _, m in ipairs(MonsterCache:GetMonsters()) do
            local name = m.Name:lower()
            if name:find("monster") or name:find("shadow") or name:find("tallmonster") then
                createEsp(m, Color3.fromRGB(255, 50, 50), "Monster")
            end
        end
    end
    
    if Library.Flags["ESPAnomalies"] then
        for _, m in ipairs(MonsterCache:GetMonsters()) do
            local name = m.Name:lower()
            if name:find("anomaly") or name:find("eyemass") or name:find("stalker") or isSkinwalker(m) then
                createEsp(m, Color3.fromRGB(255, 85, 0), "Anomaly / Skinwalker")
            end
        end
    end
end

-----------------------------------------------------------------
-- SERVER ACTIONS
-----------------------------------------------------------------
function serverHop()
    pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        local body = game:HttpGet(url)
        if not body or body == "" then return end
        local data = HttpService:JSONDecode(body)
        for _, s in ipairs(data.data or {}) do
            if s.playing and s.maxPlayers and s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, client)
                return
            end
        end
        TeleportService:Teleport(game.PlaceId, client)
    end)
end

function rejoinServer()
    pcall(function() TeleportService:Teleport(game.PlaceId, client) end)
end

function setCameraMode(mode)
    pcall(function()
        if mode == "Normal" then
            Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            Workspace.CurrentCamera.CameraSubject = getHumanoid()
            client.CameraMode = Enum.CameraMode.Classic
            client.CameraMaxZoomDistance = 128
            client.CameraMinZoomDistance = 0.5
        elseif mode == "First Person Locked" then
            client.CameraMode = Enum.CameraMode.LockFirstPerson
            Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            Workspace.CurrentCamera.CameraSubject = getHumanoid()
        elseif mode == "Third Person" then
            client.CameraMode = Enum.CameraMode.Classic
            Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            Workspace.CurrentCamera.CameraSubject = getHumanoid()
            client.CameraMaxZoomDistance = 14
            client.CameraMinZoomDistance = 1
        end
    end)
end

-----------------------------------------------------------------
-- WATERMARK UI
-----------------------------------------------------------------
local function createWatermark()
    local sg = Instance.new("ScreenGui")
    sg.Name = "VersusAirlinesWatermark"
    sg.ResetOnSpawn = false
    sg.Parent = CoreGui
    
    local tl = Instance.new("TextLabel")
    tl.Name = "VersusLabel"
    tl.Size = UDim2.new(0, 180, 0, 28)
    tl.Position = UDim2.new(1, -190, 1, -38)
    tl.BackgroundTransparency = 0.45
    tl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    tl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tl.TextStrokeTransparency = 0.8
    tl.Text = "Versus Airlines v3.0"
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 14
    tl.Parent = sg
    
    GlobalJanitor:Add(sg)
end
createWatermark()

-----------------------------------------------------------------
-- UI DESIGN & CONFIGURATION
-----------------------------------------------------------------
local farmSection = ui:CreateSection("Auto Farm")
farmSection:createToggle({ Name = "Auto Farm", flagName = "AutoFarm", Flag = false })
farmSection:createToggle({ Name = "Auto Check-In", flagName = "AutoCheckIn", Flag = true })
farmSection:createToggle({ Name = "Auto Reject Skinwalkers", flagName = "AutoRejectSkinwalkers", Flag = true })
farmSection:createToggle({ Name = "Visitor Flow", flagName = "VisitorFlow", Flag = true })
farmSection:createToggle({ Name = "Room Treatment (Rooms 1-8)", flagName = "RoomTreatment", Flag = true })
farmSection:createToggle({ Name = "Emergency Rooms (Ambulance)", flagName = "EmergencyRooms", Flag = true })
farmSection:createToggle({ Name = "Auto Shift", flagName = "AutoShift", Flag = true })
farmSection:createToggle({ Name = "Fire Strat (XP Grind)", flagName = "FireStrat", Flag = false })
farmSection:createToggle({ Name = "Multi Farm (Safe Queue)", flagName = "MultiFarm", Flag = false })
farmSection:createSlider({ Name = "Replay Shifts", flagName = "ReplayShifts", value = 1, minValue = 1, maxValue = 30 })

farmSection:createToggle({
    Name = "Auto Replay",
    flagName = "AutoReplay",
    Flag = false,
    Callback = function(enabled)
        if enabled then
            State.ShiftCount = 0
            notify("Auto Replay", "Will vote to replay for " .. (Library.Flags["ReplayShifts"] or 1) .. " shifts")
        end
    end
})

local movementSection = ui:CreateSection("Movement Config")
movementSection:createDropdown({
    Name = "Movement Mode",
    flagName = "MovementMode",
    Flag = "Tween",
    List = {"Tween", "Instant Teleport"},
    multi = false
})
movementSection:createSlider({ Name = "Tween Speed", flagName = "TweenSpeed", value = 65, minValue = 30, maxValue = 150 })

local emergencySection = ui:CreateSection("Emergency & Interaction")
emergencySection:createToggle({ Name = "Auto Blow Candles", flagName = "AutoBlowCandles", Flag = true })
emergencySection:createToggle({ Name = "Auto Open Safes", flagName = "AutoOpenSafes", Flag = true })
emergencySection:createToggle({ Name = "Fix Cams (Repair CCTV)", flagName = "FixCams", Flag = false })
emergencySection:createToggle({ Name = "Carry / Throw Fainted", flagName = "CarryFainted", Flag = false })
emergencySection:createToggle({ Name = "Avoid Eye Mass", flagName = "AvoidEyeMass", Flag = true })
emergencySection:createToggle({ Name = "Avoid Monsters (Safety)", flagName = "AvoidMonsters", Flag = true })
emergencySection:createToggle({ Name = "Help Liz (Gift Claim)", flagName = "HelpLiz", Flag = false })
emergencySection:createToggle({ Name = "Stalker Handler", flagName = "StalkerHandler", Flag = false })

local combatSection = ui:CreateSection("Combat Suite")
combatSection:createToggle({ Name = "Auto Clean Slime", flagName = "AutoCleanSlime", Flag = true })
combatSection:createToggle({ Name = "Auto Extinguish Fires", flagName = "AutoExtinguishFires", Flag = true })
combatSection:createToggle({ Name = "Auto Fight Anomalies/Ghosts", flagName = "AutoFightAnomalies", Flag = true })
combatSection:createToggle({ Name = "Zombie Aura", flagName = "ZombieAura", Flag = false })
combatSection:createSlider({ Name = "Combat Range", flagName = "CombatRange", value = 25, minValue = 10, maxValue = 100 })

local taserSection = ui:CreateSection("Taser Controls")
taserSection:createToggle({ Name = "Auto Tase Critical", flagName = "AutoTaseCritical", Flag = false })
taserSection:createDropdown({
    Name = "Tase Critical Room",
    flagName = "TaseCriticalRoom",
    Flag = "All",
    List = {"All", "Room6", "Room7", "Room8"},
    multi = false
})
taserSection:createToggle({ Name = "Infinite Tase All", flagName = "InfiniteTaseAll", Flag = false })

local itemsSection = ui:CreateSection("Items & Cabinet")
itemsSection:createToggle({ Name = "Auto Buy Cabinet Items", flagName = "AutoBuyItems", Flag = false })
itemsSection:createDropdown({
    Name = "Cabinet Item Name",
    flagName = "AutoBuyItemName",
    Flag = "Eye Drops",
    List = {"Eye Drops", "IV Drops", "Thermo", "Medkit", "Bandages", "Herbs", "Medicine", "Ointment", "Cough Syrup", "Maple Syrup", "Coffee", "Chocolate (60% Sanity)"},
    multi = false
})
itemsSection:createToggle({ Name = "Auto Trash (Full)", flagName = "AutoTrash", Flag = true })
itemsSection:createToggle({ Name = "Instant Proximity Prompts", flagName = "InstantPP", Flag = true })

local survivalSection = ui:CreateSection("Survival Kit")
survivalSection:createDropdown({
    Name = "Sanity Exploit Mode",
    flagName = "SanityMode",
    Flag = "Silent Local Hook",
    List = {"Silent Local Hook", "Server NaN Exploit", "Disabled"},
    multi = false
})
survivalSection:createToggle({ Name = "Anti-Jumpscare popups", flagName = "AntiJumpscare", Flag = true })
survivalSection:createToggle({ Name = "Auto Revive Teammates", flagName = "AutoRevive", Flag = false })
survivalSection:createToggle({ Name = "Coin Farm", flagName = "CoinFarm", Flag = false })
survivalSection:createToggle({ Name = "Infinite Lives (Break Game)", flagName = "InfiniteLives", Flag = false })

local playerSection = ui:CreateSection("Player Movements")
playerSection:createSlider({ Name = "WalkSpeed", flagName = "WalkSpeed", value = 16, minValue = 16, maxValue = 250 })
playerSection:createSlider({ Name = "JumpPower", flagName = "JumpPower", value = 50, minValue = 50, maxValue = 200 })
playerSection:createSlider({ Name = "Fly Speed", flagName = "FlySpeed", value = 50, minValue = 10, maxValue = 200 })
playerSection:createToggle({ Name = "Fly Enabled", flagName = "Fly", Flag = false, Callback = function(e) toggleFly(e) end })
playerSection:createToggle({ Name = "Noclip Enabled", flagName = "Noclip", Flag = false, Callback = function(e) toggleNoclip(e) end })
playerSection:createDropdown({
    Name = "Camera View",
    flagName = "CameraMode",
    Flag = "Normal",
    List = {"Normal", "First Person Locked", "Third Person"},
    multi = false,
    Callback = function(v) setCameraMode(v) end
})

local visualSection = ui:CreateSection("Visuals ESP")
visualSection:createToggle({ Name = "ESP Master Toggle", flagName = "ESPEnabled", Flag = false })
visualSection:createToggle({ Name = "ESP Show Labels", flagName = "ESPShowNames", Flag = true })
visualSection:createToggle({ Name = "ESP Players", flagName = "ESPPlayers", Flag = false })
visualSection:createToggle({ Name = "ESP Patients", flagName = "ESPPatients", Flag = false })
visualSection:createToggle({ Name = "ESP Anomalies/Skinwalkers", flagName = "ESPAnomalies", Flag = false })
visualSection:createToggle({ Name = "ESP Monsters (Hazards)", flagName = "ESPMonsters", Flag = false })

local serverSection = ui:CreateSection("Server Utilities")
serverSection:createButton({ Name = "Rejoin Server", Callback = function() rejoinServer(); notify("Server", "Rejoining...") end })
serverSection:createButton({ Name = "Server Hop", Callback = function() serverHop(); notify("Server", "Hopping...") end })
if IS_LOBBY then
    serverSection:createButton({ Name = "Quick Start", Callback = function() fireRemote("RE/Quickstart"); task.wait(2); TeleportService:Teleport(MAIN_ID, client) end })
end
if IS_MAIN then
    serverSection:createButton({ Name = "Teleport to Lobby", Callback = function() fireRemote("RE/TeleportToLobby") end })
end

local debugSection = ui:CreateSection("System Diagnostics")
debugSection:createToggle({ Name = "Log System Actions", flagName = "DebugMode", Flag = false })
debugSection:createToggle({ Name = "Auto Heartbeat Minigame", flagName = "AutoHeartbeat", Flag = true })
debugSection:createButton({
    Name = "Print Session Statistics",
    Callback = function()
        notify("Session Stats", string.format("Healed: %d | Rejected: %d | Anomalies Slain: %d", State.SessionHealed, State.SessionRejected, State.SessionKilled))
    end
})
debugSection:createButton({
    Name = "Show Active Objective",
    Callback = function()
        local obj = State.CurrentObjective or "(none)"
        local tname = "(none)"
        pcall(function() tname = State.CurrentTarget and State.CurrentTarget.Name or "(none)" end)
        notify("Objective", "Text: " .. obj .. " | Target: " .. tname)
    end
})

-----------------------------------------------------------------
-- RUNTIME SCHEDULER & ENGINE LOOPS
-----------------------------------------------------------------

PromptCache:Start()
MonsterCache:Start()
setupSanityHook()
setupJumpscareBypass()
hookServerEvents()

-- Continuous 50-second NaN freeze trigger (Active Server exploit mode)
task.spawn(function()
    while task.wait(50) do
        triggerServerNaNFreeze()
    end
end)

-- Main high-performance in-game loop
interval("autofarm", "AutoFarm", 0.75, function()
    if followObjective() then return end
    scanIdentity()
    handleVisitorFlow()
    handleRoomTreatment()
    handleEmergency()
    startShift()
    handleFainted()
    handlePeopleOnFire()
    handleEyeMass()
    fleeMonsters()
    handleFixCams()
    handleTakeDNA()
    helpLiz()
    stalkerHandler()
    autoBuyItems()
    handleInventory()
    autoTaseCritical()
    infiniteTaseAll()
    coinFarm()
    infiniteLives()
    autoRevive()
    instantPP()
    
    -- Emergency & Combat subsystems
    autoBlowCandles()
    autoOpenSafes()
    cleanAllSlime()
    extinguishAllFires()
    autoFightAnomaliesAndGhosts()
    zombieAura()
end)

interval("movement", "WalkSpeed", 0.1, applyMovement)
interval("esp", "ESPEnabled", 1.8, updateESP)

local charConn = client.CharacterAdded:Connect(function()
    task.wait(0.6)
    if Library.Flags["Fly"] then toggleFly(true) end
    if Library.Flags["Noclip"] then toggleNoclip(true) end
end)
GlobalJanitor:Add(charConn)

notify("Versus Airlines Ultra", "In-Game Autopilot v3.0 LOADED - " .. PLACE)
print("[Versus Airlines v3.0] Ultra Farm Active. All game loops secured.")
