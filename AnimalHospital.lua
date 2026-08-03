--[[
    Versus Airlines - Animal Hospital Ultra
    PlaceId: 104522435597696 / Lobby: 78515283254292
    
    
    Architected by Senior Roblox Software Engineering Assistant
    - Ultra-optimized event-driven caches (PromptCache & MonsterCache)
    - Full Hospital Autopilot (Handles Rooms 1 to 8: X-Ray, Surgery, Heart Monitor, Medical)
    - Treatment Engine: step-machine locks, TV inv parsing, Room6 colors solver, Room8 surgery loop
    - Check-In: attribute/voice/tag monster filter, shutter toggle, named-prompt sequence
    - Tool-based Tasing (no fake remotes), Coffee sanity, Bed Monster syrup, head banger
    - Ceiling eyes, skinwalker E-escape, CCTV auto-exit, fuses, shop upgrades, teleports
    - Drawing API ESP (boxes/tracers/names) with Highlight fallback
    - Silent Anti-Jumpscare Hook, Dual-Mode Infinite Sanity, cutscene skip
]]
--

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

local MEDICINE_PRIORITY = {
	"Eye Drops",
	"IV Drops",
	"Medicine",
	"Herbs",
	"Antibiotics",
	"Bandages",
	"Ointment",
	"Medkit",
	"Thermo",
	"Cough Syrup",
	"Maple Syrup",
}

local OBJECTIVE_TO_AT = {
	["scan identity"] = { "Scan Identity" },
	["check in"] = { "Scan Identity" },
	["register"] = { "Register" },
	["register in pc"] = { "Register" },
	["print badge"] = { "Print Badge" },
	["take badge"] = { "Take Badge", "Take" },
	["take sample"] = { "Take Sample", "Take DNA", "Collect Sample" },
	["take sample from patient"] = { "Take Sample", "Take DNA", "Collect Sample" },
	["analyze the sample"] = { "Analyze Sample" },
	["analyze sample"] = { "Analyze Sample" },
	["analyze"] = { "Analyze Sample" },
	["inspect"] = { "Inspect" },
	["process results"] = { "Process Results" },
	["complete analysis"] = { "Process Results", "Complete Analysis" },
	["complete analysis on pc"] = { "Process Results", "Complete Analysis" },
	["xray"] = { "Begin X-Ray" },
	["begin xray"] = { "Begin X-Ray" },
	["begin scan"] = { "Begin" },
	["begin"] = { "Begin" },
	["set up"] = { "Set Up" },
	["turn on"] = { "Turn On" },
	["prepare patient"] = { "Prepare Patient" },
	["prepare"] = { "Prepare Patient" },
	["apply treatment"] = { "Apply Treatment" },
	["apply the treatment"] = { "Apply Treatment" },
	["treat"] = { "Apply Treatment" },
	["treatment"] = { "Apply Treatment" },
	["treat the patient"] = { "Apply Treatment" },
	["collect"] = { "Collect" },
	["collect results"] = { "Collect" },
	["take photo"] = { "Take Photo", "Take UV Photo" },
	["take a photo"] = { "Take Photo", "Take UV Photo" },
	["photo"] = { "Take Photo", "Take UV Photo" },
	["stamp forms"] = { "Stamp Forms", "Stamp the form" },
	["stamp the forms"] = { "Stamp Forms", "Stamp the form" },
	["stamp form"] = { "Stamp Forms", "Stamp the form" },
	["stamp the form"] = { "Stamp Forms", "Stamp the form" },
	["finish the check in"] = { "Talk", "Finish the check-in" },
	["finish check in"] = { "Talk", "Finish the check-in" },
	["finish the check-in"] = { "Talk", "Finish the check-in" },
	["security cams"] = { "Security Cams" },
	["talk"] = { "Talk" },
	["ask to leave"] = { "Ask to Leave" },
	["take key"] = { "Take Key" },
	["put out"] = { "Put out" },
	["put out fire"] = { "Put out" },
	["clean slime"] = { "Clean Slime" },
	["unjam"] = { "Un-jam button." },
	["accept gift"] = { "Accept Gift" },
	["help liz"] = { "Accept Gift", "Help Liz" },
	["buy"] = { "Buy" },
	["reroll"] = { "Reroll Shop" },
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
			if task.Connected then
				task:Disconnect()
			end
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
local State = {
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
	TreatLock = false,
	ActiveRoom = nil,
	IsTreatingRoom = false,
	IsDrinkingCoffee = false,
	RoomAppliedMeds = {},
	LastMedApply = {},
	RoomUnlockAt = {},
	ItemCache = {},
	OriginalHoldDurations = setmetatable({}, { __mode = "k" }),
	InstantPPHooked = setmetatable({}, { __mode = "k" }),
	ESPBoxes = {},
	ESPTracked = {},
	CameraYaw = 0,
	ConfigLoaded = false,
}

-- Illness token -> cure medicine (verified gameplay mapping; used as
-- fallback when the game's IllnessesAndCures module has no entry)
local SUN_CURE_MAP = {
	["Fever"] = "Thermo",
	["Headache"] = "Medicine",
	["Dried Eyes"] = "Eye Drops",
	["Dehydration"] = "IV Drops",
	["Bruises"] = "Medkit",
	["Rashes"] = "Ointment",
	["Bleeding"] = "Bandages",
	["Stomach Ache"] = "Herbs",
	["Low sugar"] = "Maple Syrup",
	["Canadian"] = "Maple Syrup",
	["Flu"] = "Cough Syrup",
}

-- Full inventory medicine tool list (used to detect "non-medicine" tools that
-- can be trashed to free inventory space)
local MEDICINE_TOOLS = {
	"Maple Syrup", "Herbs", "Ointment", "Pills", "Bandages", "Antibiotics",
	"IV Drops", "Organ", "Transplant", "Scalpel", "Scissors", "Medicine",
	"Medkit", "Ice Pack", "Splint", "Inhaler", "Cough Syrup", "Eye Drops",
}

-- Room 8 surgery: PP ActionText keyword -> required tool
local SURGERY_TOOL_MAP = {
	["scissors"] = "Scissors",
	["transplant"] = "Transplant",
	["scalpel"] = "Scalpel",
	["antibiotics"] = "Antibiotics",
	["organ"] = "Organ",
}

-- Monster detection attributes / voices (verified via live gameplay)
local MONSTER_ATTRIBUTES = {
	"PhotoEffect", "PhotoEffect2", "CameraEffect", "CameraEffect2",
	"InspectEffect", "InspectEffect2", "Cursed", "IsMonster", "Skinwalker",
}
local MONSTER_VOICES = { "Distorted", "LowDistorted", "Monster" }

-- Shop upgrade keyword categories (ObjectText/Parent.Name match)
local SHOP_CATEGORIES = {
	["BuyCapacity"] = { "backpack", "capacity", "pocket" },
	["BuyDNASpeed"] = { "dna", "synth", "analyzer" },
	["BuyGiveInventory"] = { "technique", "formula", "inventory" },
	["BuyCheckIn"] = { "check", "window", "bell" },
	["BuyConsumables"] = { "chocolate", "coffee" },
}

-- Teleport destinations
local TELEPORT_DESTINATIONS = {
	"Check-In Counter",
	"Coffee Machine (Sanity)",
	"Supplies Shop",
	"Medical Room 1",
	"Medical Room 2",
	"Medical Room 3",
	"Medical Room 4",
	"Medical Room 5",
	"Medical Room 6",
	"Medical Room 7",
	"Medical Room 8 (Surgery)",
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
		if not pp:IsA("ProximityPrompt") then
			return
		end
		self._prompts[pp] = true

		local at = pp.ActionText
		if not self._byActionText[at] then
			self._byActionText[at] = {}
		end
		self._byActionText[at][pp] = true

		local model = pp:FindFirstAncestorWhichIsA("Model")
		local mName = model and model.Name or ""
		if mName ~= "" then
			if not self._byModelName[mName] then
				self._byModelName[mName] = {}
			end
			self._byModelName[mName][pp] = true
		end

		local atConn = pp:GetPropertyChangedSignal("ActionText"):Connect(function()
			local oldAt = at
			local newAt = pp.ActionText
			if self._byActionText[oldAt] then
				self._byActionText[oldAt][pp] = nil
			end
			if not self._byActionText[newAt] then
				self._byActionText[newAt] = {}
			end
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
				if not self._byModelName[newMName] then
					self._byModelName[newMName] = {}
				end
				self._byModelName[newMName][pp] = true
			end
			mName = newMName
		end)

		GlobalJanitor:Add(atConn)
		GlobalJanitor:Add(parentConn)
	end

	local function removePrompt(pp)
		if not pp:IsA("ProximityPrompt") then
			return
		end
		self._prompts[pp] = nil
		for _, list in pairs(self._byActionText) do
			list[pp] = nil
		end
		for _, list in pairs(self._byModelName) do
			list[pp] = nil
		end
	end

	for _, pp in ipairs(Workspace:GetDescendants()) do
		if pp:IsA("ProximityPrompt") then
			addPrompt(pp)
		end
	end

	local addConn = Workspace.DescendantAdded:Connect(addPrompt)
	local removeConn = Workspace.DescendantRemoving:Connect(removePrompt)
	GlobalJanitor:Add(addConn)
	GlobalJanitor:Add(removeConn)

	print("[PromptCache] Loaded prompts: " .. #self:GetAllPrompts())
end

function PromptCache:GetAllPrompts()
	local list = {}
	for pp in pairs(self._prompts) do
		table.insert(list, pp)
	end
	return list
end

function PromptCache:GetPromptsByActionText(actionText)
	return self._byActionText[actionText] or {}
end

function PromptCache:GetNearestPrompt(actionText, maxDistance)
	local root = getRoot()
	if not root then
		return nil, nil
	end

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
	if not root then
		return nil, nil
	end

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
	_tags = { "Shadow", "TallMonsterHead", "TallMonsterSpawn", "Zombie", "Skinwalker", "StalkerJumpscare", "EyeMass" },
	_names = {
		"shadow",
		"tallmonster",
		"monsterbed",
		"hider",
		"ghost",
		"skinwalker",
		"zombie",
		"stalker",
		"hollow",
		"eyemass",
	},
}

function MonsterCache:Start()
	local function checkAndAdd(obj)
		if not obj:IsA("Model") then
			return
		end
		local name = obj.Name:lower()
		local isMonster = false
		for _, pat in ipairs(self._names) do
			if name:find(pat) then
				isMonster = true
				break
			end
		end
		if not isMonster then
			for _, tag in ipairs(self._tags) do
				if CollectionService:HasTag(obj, tag) then
					isMonster = true
					break
				end
			end
		end
		if isMonster then
			self._monsters[obj] = true
		end
	end

	local function checkAndRemove(obj)
		self._monsters[obj] = nil
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		checkAndAdd(obj)
	end

	local addConn = Workspace.DescendantAdded:Connect(checkAndAdd)
	local removeConn = Workspace.DescendantRemoving:Connect(checkAndRemove)
	GlobalJanitor:Add(addConn)
	GlobalJanitor:Add(removeConn)
end

function MonsterCache:GetMonsters()
	local list = {}
	for m in pairs(self._monsters) do
		if m.Parent then
			table.insert(list, m)
		end
	end
	return list
end

-----------------------------------------------------------------
-- SKINWALKER DETECTION & AUTO REJECT ENGINE
-----------------------------------------------------------------
function isSkinwalker(npc)
	if not npc or not npc:IsA("Model") then
		return false
	end
	-- Verified attribute filter (PhotoEffect "Static" is NOT a monster)
	for _, attr in ipairs(MONSTER_ATTRIBUTES) do
		local v = npc:GetAttribute(attr)
		if v ~= nil and v ~= "Static" then
			return true
		end
	end
	local voice = npc:GetAttribute("Voice")
	if voice and MONSTER_VOICES[voice] then
		return true
	end
	-- Scan hidden anatomy subparts (specific to skinwalkers)
	for _, partName in ipairs({ "Gulp", "Tooth", "TongueMesh", "Spit", "Teeth" }) do
		if npc:FindFirstChild(partName, true) then
			return true
		end
	end
	if npc.Name:lower():find("skinwalker") or npc.Name:lower() == "barney" then
		return true
	end
	for _, tag in ipairs({ "Skinwalker", "Anomaly", "Monster", "Enemy" }) do
		if CollectionService:HasTag(npc, tag) then
			return true
		end
	end
	return false
end

function getShutterPP()
	local shutterModel = Workspace:FindFirstChild("ShutterButton", true) or Workspace:FindFirstChild("Shutters", true)
	if not shutterModel then
		return nil
	end
	return shutterModel:FindFirstChildWhichIsA("ProximityPrompt", true)
end

function fireShutter(actionTextLower)
	local shutterPP = getShutterPP()
	if not shutterPP or not shutterPP.Enabled then
		return false
	end
	local at = (shutterPP.ActionText or ""):lower()
	-- ActionText reflects the CURRENT state (e.g. "Locked" = shutters closed).
	-- Pressing the button TOGGLES, so:
	--   close (lock):   fire only when NOT already locked
	--   open  (unlock): fire only when currently locked
	local matches = false
	if actionTextLower == "open" then
		matches = at:find("lock")
	else
		matches = not (at:find("lock"))
	end
	if not matches then
		return false
	end
	local shutterModel = shutterPP:FindFirstAncestorWhichIsA("Model")
	if not shutterModel then
		return false
	end
	safeMoveToModel(shutterModel, function()
		pcall(function()
			shutterPP.HoldDuration = 0
			shutterPP.MaxActivationDistance = 25
			if fireproximityprompt then
				fireproximityprompt(shutterPP, 1)
			elseif firesignal then
				firesignal(shutterPP.Triggered, client)
			else
				shutterPP:InputHoldBegin()
				task.wait(0.1)
				shutterPP:InputHoldEnd()
			end
		end)
	end)
	return true
end

function checkAndRejectSkinwalker()
	if not Library or not Library.Flags or not Library.Flags["AutoRejectSkinwalkers"] then
		return false
	end

	local scanList = PromptCache:GetPromptsByActionText("Scan Identity")
	for pp in pairs(scanList) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model and isSkinwalker(model) then
				print("[Ultra Control] Detected Skinwalker at front desk!")
				if fireShutter("close") then
					State.SessionRejected = State.SessionRejected + 1
					notify("Anti-Skinwalker", "Rejected Disguised Skinwalker!")
					return true
				end
			end
		end
	end
	return false
end

function findVisitorAtCheckIn()
	for _, npc in ipairs(Workspace:FindFirstChild("NPCs") and Workspace.NPCs:GetChildren() or {}) do
		if CollectionService:HasTag(npc, "VisitorAtCheckIn") then
			return npc
		end
	end
	return nil
end

-----------------------------------------------------------------
-- HEART AND MONITOR TEXT BOARD PARSER (Rooms 1 to 8)
-----------------------------------------------------------------
function getTreatmentOrIllness(roomModel)
	if not roomModel then
		return nil
	end
	local minigame = roomModel:FindFirstChild("Minigame", true)
	if not minigame then
		return nil
	end

	-- Try TV first: its "treatment" label already contains exact CURE names
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

	-- Fallback: Monitor shows the illness names (screen spelling, comma-separated)
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
	OpenCloseLocation = "Top Center",
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
		Library:createDisplayMessage(tostring(title), tostring(desc), { { text = "OK" } }, style or "info")
	end)
end

local activeIntervals = {}
function interval(tag, flag, delayTime, callback)
	if activeIntervals[tag] then
		activeIntervals[tag]:Disconnect()
		activeIntervals[tag] = nil
	end
	delayTime = math.max(tonumber(delayTime) or 1, 0.05)

	local flagsList = type(flag) == "table" and flag or { flag }
	local last = 0
	local running = false
	local conn = RunService.Heartbeat:Connect(function()
		if not Library or not Library.Flags then
			return
		end
		local anyOn = false
		for _, f in ipairs(flagsList) do
			if Library.Flags[f] then
				anyOn = true
				break
			end
		end
		if not anyOn then
			return
		end
		local now = tick()
		if running or (now - last) < delayTime then
			return
		end
		last = now
		running = true
		task.spawn(function()
			local ok, err = pcall(callback)
			if not ok then
				warn("[interval:" .. tostring(tag) .. "]", err)
			end
			task.wait()
			running = false
		end)
	end)

	activeIntervals[tag] = conn
	GlobalJanitor:Add(conn)
end

function getChar()
	return client.Character
end

function getRoot()
	local char = getChar()
	if char then
		return char:FindFirstChild("HumanoidRootPart")
			or char:FindFirstChild("Torso")
			or char:FindFirstChild("UpperTorso")
	end
	return nil
end

function getHumanoid()
	local char = getChar()
	if char then
		return char:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

function distanceTo(pos)
	local root = getRoot()
	if root and pos then
		return (root.Position - pos).Magnitude
	end
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
	for _, tw in ipairs(State.ActiveTweens) do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(State.ActiveTweens)
end

function safeMoveToModel(model, callback)
	local root = getRoot()
	if not root or not model then
		return
	end

	local pivot = model:GetPivot()
	local targetPos = pivot.Position + Vector3.new(0, 5.5, 0)
	local dist = (root.Position - targetPos).Magnitude

	if dist < 4 then
		if callback then
			callback()
		end
		return
	end

	clearActiveTweens()

	if Library and Library.Flags and Library.Flags["MovementMode"] == "Tween" then
		local speed = Library.Flags["TweenSpeed"] or 65
		local duration = dist / speed
		local twInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(root, twInfo, { CFrame = CFrame.new(targetPos) })
		table.insert(State.ActiveTweens, tween)

		local conn
		conn = tween.Completed:Connect(function()
			if conn then
				conn:Disconnect()
			end
			if callback then
				callback()
			end
		end)
		tween:Play()
	else
		root.CFrame = CFrame.new(targetPos)
		task.wait(0.12)
		if callback then
			callback()
		end
	end
end

-----------------------------------------------------------------
-- NETWORK COMMUNICATIONS
-----------------------------------------------------------------
local NetworkObj = (function()
	local ok, util = pcall(function()
		return ReplicatedStorage:WaitForChild("Util", 5)
	end)
	if ok and util then
		local ok2, net = pcall(function()
			return util:WaitForChild("Net", 5)
		end)
		if ok2 and net then
			local ok3, netMod = pcall(require, net)
			if ok3 and netMod then
				return netMod.Network or netMod
			end
		end
	end
	local ok2, lib = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Lib", 5))
	end)
	if ok2 and lib then
		return lib.Network
	end
	return nil
end)()

function fireRemote(name, ...)
	local args = { ... }
	local baseName = name
	if baseName:sub(1, 3) == "RE/" then
		baseName = baseName:sub(4)
	end

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
	if baseName:sub(1, 3) == "RE/" then
		baseName = baseName:sub(4)
	end

	if NetworkObj and NetworkObj.Connect then
		pcall(function()
			NetworkObj:Connect(baseName, callback)
		end)
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
-- CORE HELPERS (proven in-game utilities)
-----------------------------------------------------------------
local AHLib = nil
function getAHLib()
	if AHLib then
		return AHLib
	end
	pcall(function()
		AHLib = require(ReplicatedStorage:WaitForChild("Lib", 5))
	end)
	return AHLib
end

function getInventoryTools()
	local tools = {}
	local backpack = client:FindFirstChild("Backpack")
	local char = getChar()
	if backpack then
		for _, v in ipairs(backpack:GetChildren()) do
			if v:IsA("Tool") then
				table.insert(tools, v)
			end
		end
	end
	if char then
		for _, v in ipairs(char:GetChildren()) do
			if v:IsA("Tool") then
				table.insert(tools, v)
			end
		end
	end
	return tools
end

function findToolInInventory(name)
	for _, tool in ipairs(getInventoryTools()) do
		if tool.Name == name or tool.Name:find(name, 1, true) or name:find(tool.Name, 1, true) then
			return tool
		end
	end
	return nil
end

function useToolByName(name)
	local tool = findToolInInventory(name)
	if not tool then
		return nil
	end
	local hum = getHumanoid()
	if hum and tool.Parent ~= getChar() then
		pcall(function()
			hum:EquipTool(tool)
		end)
		task.wait(0.15)
	end
	if tool.Parent == getChar() then
		return tool
	end
	return tool
end

function getCarryCapacity()
	return 3 + (client:GetAttribute("BonusCarryItems") or 0)
end

function getInstancePart(model)
	if not model then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart")
end

function findTrashCan()
	local root = getRoot()
	local best, bestDist = nil, math.huge
	local function check(obj)
		if not obj:IsA("ProximityPrompt") or not obj.Enabled then
			return
		end
		local model = obj:FindFirstAncestorWhichIsA("Model")
		local mName = model and model.Name or ""
		local at = obj.ActionText or ""
		if mName == "Trash" or at == "Trash Item" or at:lower():find("trash") then
			local part = getInstancePart(model) or obj.Parent
			if part and root and part:IsA("BasePart") then
				local d = (root.Position - part.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = obj
				end
			end
		end
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		check(obj)
	end
	return best
end

function findItemShelf(item)
	if State.ItemCache[item] then
		local cached = State.ItemCache[item]
		if cached.Parent then
			return cached
		end
		State.ItemCache[item] = nil
	end
	local root = getRoot()
	local best, bestDist = nil, math.huge
	local function consider(candidate)
		if not candidate or not candidate.Parent then
			return
		end
		local pp = candidate:FindFirstChild("PP") or candidate:FindFirstChildWhichIsA("ProximityPrompt", true)
		local part = getInstancePart(candidate)
		if pp and part then
			local d = root and (root.Position - part.Position).Magnitude or 0
			if d < bestDist then
				bestDist = d
				best = candidate
			end
		end
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") then
			local items = child:FindFirstChild("Items")
			if items then
				consider(items:FindFirstChild(item))
			end
		end
	end
	local rooms = Workspace:FindFirstChild("Rooms")
	local room8 = rooms and rooms:FindFirstChild("Emergency") and rooms.Emergency:FindFirstChild("Room8")
	local medicine = room8 and room8:FindFirstChild("Minigame") and room8.Minigame:FindFirstChild("Medicine")
	if medicine then
		for _, child in ipairs(medicine:GetChildren()) do
			local found = child:FindFirstChild(item)
			if found then
				consider(found)
			end
		end
	end
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc.Name == item and (desc:FindFirstChild("PP") or desc:FindFirstChildWhichIsA("ProximityPrompt", true)) then
			consider(desc)
		end
	end
	if best then
		State.ItemCache[item] = best
	end
	return best
end

function findBedMonster()
	local rooms = Workspace:FindFirstChild("Rooms")
	if not rooms then
		return nil
	end
	for _, room in ipairs(rooms:GetChildren()) do
		for _, child in ipairs(room:GetChildren()) do
			if child:IsA("Model") then
				local n = child.Name:lower()
				if (n:find("bed monster") or n:find("bedmonster") or n == "monster") and getInstancePart(child) then
					return child
				end
			end
		end
		local minigame = room:FindFirstChild("Minigame")
		local bed = minigame and minigame:FindFirstChild("Bed")
		if bed then
			for _, child in ipairs(bed:GetChildren()) do
				if child:IsA("Model") then
					local n = child.Name:lower()
					if (n:find("bed monster") or n:find("bedmonster") or n:find("monster")) and getInstancePart(child) then
						return child
					end
				end
			end
		end
	end
	return nil
end

local tweenNoclipActive = false
local tweenNoclipConn = nil
local function enableTweenNoclip()
	if tweenNoclipConn then
		return
	end
	tweenNoclipActive = true
	tweenNoclipConn = RunService.Stepped:Connect(function()
		if not tweenNoclipActive then
			if tweenNoclipConn then
				tweenNoclipConn:Disconnect()
				tweenNoclipConn = nil
			end
			return
		end
		local char = getChar()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)
end

function tweenToPosition(targetPos)
	local root = getRoot()
	if not root or not targetPos then
		return
	end
	local goal = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
	local dist = (root.Position - goal).Magnitude
	if dist < 4 then
		return
	end
	clearActiveTweens()
	enableTweenNoclip()
	local duration = dist / 35
	local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(goal) })
	table.insert(State.ActiveTweens, tween)
	local conn
	conn = tween.Completed:Connect(function()
		if conn then
			conn:Disconnect()
		end
		tweenNoclipActive = false
	end)
	tween:Play()
	tween.Completed:Wait()
end

local maxActivationThrottle = {}
function updateMaxActivationDistance(pp, force)
	if not pp then
		return
	end
	local key = pp:GetFullName()
	local now = tick()
	if not force and maxActivationThrottle[key] and (now - maxActivationThrottle[key]) < 2.5 then
		return
	end
	maxActivationThrottle[key] = now
	if pp.MaxActivationDistance < 25 then
		pp.MaxActivationDistance = 25
	end
	if fireproximityprompt then
		fireproximityprompt(pp, 1)
	elseif firesignal then
		firesignal(pp.Triggered, client)
	else
		pp:InputHoldBegin()
		task.wait(0.1)
		pp:InputHoldEnd()
	end
end

function firePromptChecked(pp)
	if not pp or not pp.Enabled then
		return
	end
	pcall(function()
		pp.HoldDuration = 0
		if pp.MaxActivationDistance < 25 then
			pp.MaxActivationDistance = 25
		end
	end)
	updateMaxActivationDistance(pp, true)
end

function isDialogueOpen()
	local gui = client:FindFirstChild("PlayerGui")
	if not gui then
		return false
	end
	local dialogue = gui:FindFirstChild("Dialogue")
	if not dialogue or not dialogue.Enabled then
		return false
	end
	local frame = dialogue:FindFirstChild("Frame")
	if not frame or not frame.Visible then
		return false
	end
	local textframe = frame:FindFirstChild("textframe")
	return textframe and textframe.Text ~= ""
end

function isMonsterVisitor(npc)
	if not npc or not npc:IsA("Model") then
		return false
	end
	for _, attr in ipairs(MONSTER_ATTRIBUTES) do
		local v = npc:GetAttribute(attr)
		if v ~= nil and v ~= "Static" then
			return true
		end
	end
	local voice = npc:GetAttribute("Voice")
	if voice and MONSTER_VOICES[voice] then
		return true
	end
	local n = npc.Name:lower()
	if n == "barney" or n:find("skinwalker") then
		return true
	end
	for _, tag in ipairs({ "Skinwalker", "Anomaly", "Monster", "Enemy" }) do
		if CollectionService:HasTag(npc, tag) then
			return true
		end
	end
	return false
end

function getRoomByNumber(num)
	local rooms = Workspace:FindFirstChild("Rooms")
	if not rooms then
		return nil
	end
	local name = "Room" .. tostring(num)
	local room = rooms.Medical and rooms.Medical:FindFirstChild(name)
	if room then
		return room
	end
	return rooms.Emergency and rooms.Emergency:FindFirstChild(name)
end

function getPromptPart(pp)
	if not pp then
		return nil
	end
	local cur = pp.Parent
	while cur do
		if cur:IsA("BasePart") then
			return cur
		end
		if cur:IsA("Model") then
			local part = getInstancePart(cur)
			if part then
				return part
			end
		end
		cur = cur.Parent
	end
	return nil
end

function getIllnessText(room)
	if not room then
		return nil
	end
	local minigame = room:FindFirstChild("Minigame", true)
	if not minigame then
		return nil
	end
	local function readLabel(rootPart)
		local screen = rootPart and rootPart:FindFirstChild("Screen", true)
		local ui = screen and screen:FindFirstChild("UI", true)
		local report = ui and ui:FindFirstChild("Report", true)
		return report and report:FindFirstChild("illnesses", true)
	end
	local monitor = minigame:FindFirstChild("Monitor", true)
	local mLabel = readLabel(monitor)
	if mLabel and mLabel.Text ~= "" and mLabel.Text ~= "REGISTERING" then
		return mLabel.Text
	end
	local xray = minigame:FindFirstChild("xrayMonitor", true)
	local xLabel = readLabel(xray)
	if xLabel and xLabel.Text ~= "" then
		return xLabel.Text
	end
	return nil
end

function isRecovering(room)
	if not room then
		return false
	end
	local minigame = room:FindFirstChild("Minigame", true)
	if not minigame then
		return false
	end
	local tv = minigame:FindFirstChild("TV", true)
	if tv then
		local screen = tv:FindFirstChild("Screen", true)
		local ui = screen and screen:FindFirstChild("UI", true)
		local healing = ui and ui:FindFirstChild("Healing", true)
		local header = healing and healing:FindFirstChild("header", true)
		if header and header.Text:lower():find("recover") then
			return true
		end
	end
	local illnesses = getIllnessText(room)
	if illnesses and illnesses:lower():find("recovering") then
		return true
	end
	return false
end

function isInvReportVisible(room)
	if not room then
		return false
	end
	local minigame = room:FindFirstChild("Minigame", true)
	local tv = minigame and minigame:FindFirstChild("TV", true)
	if not tv then
		return false
	end
	local screen = tv:FindFirstChild("Screen", true)
	local ui = screen and screen:FindFirstChild("UI", true)
	local report = ui and ui:FindFirstChild("Report", true)
	local inv = report and report:FindFirstChild("inv", true)
	if not inv then
		return false
	end
	for _, child in ipairs(inv:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			return true
		end
	end
	return false
end

function getIllnessData(name)
	if type(name) ~= "string" then
		return nil
	end
	local data = ReplicatedStorage:FindFirstChild("Data")
	local module = data and data:FindFirstChild("IllnessesAndCures")
	if not module then
		return nil
	end
	local ok, tableData = pcall(require, module)
	if ok and tableData then
		if tableData.GetIllnessByName then
			local ok2, entry = pcall(tableData.GetIllnessByName, tableData, name)
			if ok2 and entry then
				return entry
			end
		end
		for _, entry in pairs(tableData) do
			if type(entry) == "table" and (entry.Name == name or (entry.IllnessName and entry.IllnessName == name)) then
				return entry
			end
		end
	end
	return nil
end

function getRequiredMeds(room)
	if not room then
		return {}
	end
	local minigame = room:FindFirstChild("Minigame", true)
	if not minigame then
		return {}
	end
	local roomName = room.Name
	State.RoomAppliedMeds[roomName] = State.RoomAppliedMeds[roomName] or {}

	local needed = {}
	if isInvReportVisible(room) then
		local tv = minigame:FindFirstChild("TV", true)
		local report = tv and tv:FindFirstChild("Screen", true)
			and tv.Screen:FindFirstChild("UI", true)
			and tv.Screen.UI:FindFirstChild("Report", true)
		local inv = report and report:FindFirstChild("inv", true)
		if inv then
			local nameCounts = {}
			local nameChecked = {}
			for _, row in ipairs(inv:GetChildren()) do
				if row:IsA("Frame") and row.Name ~= "Template" then
					local nameLabel = row:FindFirstChild("name", true)
					local check = row:FindFirstChild("check", true)
					local name = (nameLabel and nameLabel.Text ~= "" and nameLabel.Text) or row.Name
					if name then
						nameCounts[name] = (nameCounts[name] or 0) + 1
						if check and check.Visible then
							nameChecked[name] = (nameChecked[name] or 0) + 1
						end
					end
				end
			end
			for name, total in pairs(nameCounts) do
				local done = nameChecked[name] or 0
				for i = 1, total - done do
					table.insert(needed, name)
				end
			end
		end
	else
		local text = getIllnessText(room)
		if text then
			for _, token in ipairs(string.split(text:gsub("\n", ","), ",")) do
				local clean = token:gsub("^%s*%-*%s*(.-)%s*$", "%1")
				if clean ~= "" and clean ~= "RACE: Human" then
					local cure = SUN_CURE_MAP[clean:lower()] or SUN_CURE_MAP[clean]
					if not cure then
						local data = getIllnessData(clean)
						if data then
							cure = data.HealedWith or data.Cure
						end
					end
					if cure then
						table.insert(needed, cure)
					end
				end
			end
		end
	end

	local applied = State.RoomAppliedMeds[roomName]
	local result = {}
	for _, med in ipairs(needed) do
		if not applied[med] or applied[med] <= 0 then
			table.insert(result, med)
		end
	end
	return result
end

function trashUnneededItems(keepName)
	local trashPP = findTrashCan()
	if not trashPP then
		print("[Inventory] Failed to find active trash can to discard " .. tostring(keepName) .. "...")
		return false
	end
	local keepList = { "Taser", "X-Taser", "Gun", "Fire Extinguisher", "Coffee" }
	local discardable = {}
	for _, tool in ipairs(getInventoryTools()) do
		local keep = false
		for _, k in ipairs(keepList) do
			if tool.Name:find(k, 1, true) or k:find(tool.Name, 1, true) then
				keep = true
				break
			end
		end
		if not keep and keepName and (tool.Name:find(keepName, 1, true) or keepName:find(tool.Name, 1, true)) then
			keep = true
		end
		if not keep then
			table.insert(discardable, tool)
		end
	end
	if #discardable == 0 then
		return false
	end
	print("[Inventory] Discarding " .. #discardable .. " unneeded items...")
	for _, tool in ipairs(discardable) do
		pcall(function()
			useToolByName(tool.Name)
			task.wait(0.1)
			local trashPart = getPromptPart(trashPP)
			if trashPart then
				tweenToPosition(trashPart.Position)
			end
			task.wait(0.3)
			updateMaxActivationDistance(trashPP, true)
			task.wait(0.5)
		end)
	end
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
			-- Block Cursed Photo sanity drain entirely
			if Library and Library.Flags and Library.Flags["AutoSkipCutscenes"] and reason == "Cursed Photo" then
				return
			end

			-- Mode 1: Silent Hook
			if Library and Library.Flags and Library.Flags["SanityMode"] == "Silent Local Hook" then
				pcall(function()
					client:SetAttribute("Sanity", 100)
				end)
				return
			end

			if originalPlayerLostSanity then
				return originalPlayerLostSanity(amount, reason, suppressRemote)
			end
		end
	end
end

-- Cutscene skip watchdog: hides the blackscreen and resets the camera while a
-- cutscene is active. NOTE: never read/write unknown Lib fields - Lib's
-- __index auto-requires modules and crashes on names that don't exist
-- (that's what killed the old Lib.__cutsceneHookInstalled / Lib.PlayCutscene hook).
function handleCutsceneSkip()
	if not Library or not Library.Flags or not Library.Flags["AutoSkipCutscenes"] then
		return
	end
	pcall(function()
		local cam = Workspace.CurrentCamera
		if cam and cam:HasTag("InCutscene") then
			cam.CameraType = Enum.CameraType.Custom
			local hum = getHumanoid()
			if hum then
				cam.CameraSubject = hum
			end
		end
	end)
	pcall(function()
		local gui = client:FindFirstChild("PlayerGui")
		local blackscreen = gui and gui:FindFirstChild("blackscreen")
		local black = blackscreen and blackscreen:FindFirstChild("black")
		if black then
			black.BackgroundTransparency = 1
			local text = blackscreen:FindFirstChild("text")
			if text then
				text.Visible = false
			end
		end
	end)
end

-- Mode 2: Server-side NaN Exploit
function triggerServerNaNFreeze()
	if Library and Library.Flags and Library.Flags["SanityMode"] == "Server NaN Exploit" then
		pcall(function()
			local args = { math.huge / math.huge, "Job Stress", true }
			fireRemote("RE/PlayerLostSanity", unpack(args))
		end)
	end
end

-- Silent Anti-Jumpscare
local function setupJumpscareBypass()
	local ok, Net = pcall(function()
		return require(ReplicatedStorage.Util.Net)
	end)
	if ok and Net then
		local originalConnect = Net.Connect
		Net.Connect = function(self, name, callback)
			if Library and Library.Flags and Library.Flags["AntiJumpscare"] then
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
	if not Library or not Library.Flags or not Library.Flags["AutoCleanSlime"] then
		return
	end
	for _, grime in ipairs(CollectionService:GetTagged("Grime")) do
		fireRemote("ExtinguisherBubbleHitGrime", grime)
	end
end

function extinguishAllFires()
	if not Library or not Library.Flags or not Library.Flags["AutoExtinguishFires"] then
		return
	end
	for _, part in ipairs(CollectionService:GetTagged("OnFire")) do
		fireRemote("ExtinguisherBubbleHit", part)
	end
	for _, npc in ipairs(CollectionService:GetTagged("NPC")) do
		if npc:HasTag("OnFire") then
			-- Fire once per FireCharges attribute so multi-charge blazes go out
			local charges = tonumber(npc:GetAttribute("FireCharges")) or 1
			for i = 1, math.max(1, charges) do
				fireRemote("ExtinguisherBubbleHitFireNPC", npc)
			end
		end
	end
	local char = getChar()
	if char and char:HasTag("OnFire") then
		local charges = tonumber(char:GetAttribute("FireCharges")) or 1
		for i = 1, math.max(1, charges) do
			fireRemote("ExtinguisherBubbleHitFireNPC", char)
		end
	end
end

-- Auto-tag shop prompts so handleShopUpgrades can find them (the game
-- marks them at runtime; tagging here keeps the keyword filter working)
function setupShopTagHook()
	local function tagPrompt(pp)
		if not pp:IsA("ProximityPrompt") then
			return
		end
		local model = pp:FindFirstAncestorWhichIsA("Model")
		if model then
			local n = model.Name:lower()
			if n:find("shop") or n:find("cabinet") or n:find("shopitem") then
				pp:SetAttribute("ShopItemPP", true)
			end
		end
	end
	for _, pp in ipairs(Workspace:GetDescendants()) do
		tagPrompt(pp)
	end
	Workspace.DescendantAdded:Connect(tagPrompt)
end

function autoFightAnomaliesAndGhosts()
	if not Library or not Library.Flags or not Library.Flags["AutoFightAnomalies"] then
		return
	end
	for _, m in ipairs(MonsterCache:GetMonsters()) do
		if m:HasTag("GhostAnomaly") or m.Name:lower():find("ghost") or m.Name:lower():find("hider") then
			-- Reveal invisible ghosts with the extinguisher (verified remote), then
			-- taser is handled separately by the taser toggles.
			fireRemote("ExtinguisherBubbleHit", m)
			State.SessionKilled = State.SessionKilled + 1
		end
	end
end

function zombieAura()
	if not Library or not Library.Flags or not Library.Flags["ZombieAura"] then
		return
	end
	local char = getChar()
	if not char then
		return
	end
	local tool = char:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then
		return
	end

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
	if not model then
		return false
	end

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
		pp = model:FindFirstChild("PP")
			or model:FindFirstChild("ProximityPrompt")
			or model:FindFirstChildWhichIsA("ProximityPrompt", true)
	end

	if not pp or not pp.Enabled then
		return false
	end
	if DANGEROUS_AT[pp.ActionText] then
		return false
	end

	local cooldownKey = tostring(model) .. "|" .. tostring(pp.ActionText)
	if isCooldown(cooldownKey, 1.1) then
		return false
	end

	safeMoveToModel(model, function()
		if pp.ActionText == "Apply Treatment" then
			-- Only equip a fallback medicine if the character is holding NOTHING.
			-- NEVER override a cure that the caller already equipped!
			local equippedTool = getChar() and getChar():FindFirstChildOfClass("Tool")
			if not equippedTool then
				equipMedicine()
			end
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
		for _, v in ipairs(backpack:GetChildren()) do
			if v:IsA("Tool") then
				count = count + 1
			end
		end
	end
	if char then
		for _, v in ipairs(char:GetChildren()) do
			if v:IsA("Tool") then
				count = count + 1
			end
		end
	end
	return count
end

function equipTool(toolName)
	local backpack = client:FindFirstChild("Backpack")
	local char = getChar()
	local hum = getHumanoid()
	if not backpack or not char or not hum then
		return nil
	end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and (tool.Name:find(toolName) or toolName:find(tool.Name)) then
			pcall(function()
				hum:EquipTool(tool)
			end)
			return tool
		end
	end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and (tool.Name:find(toolName) or toolName:find(tool.Name)) then
			return tool
		end
	end
	return nil
end

function buyTool(toolName)
	local model = PromptCache:GetNearestPrompt(toolName)
	if model then
		fireModelPrompt(model)
		return true
	end
	return false
end

function trashItems()
	local trash = Workspace:FindFirstChild("Trash")
	if trash then
		fireModelPrompt(trash)
	end
end

function equipMedicine()
	for _, name in ipairs(MEDICINE_PRIORITY) do
		local tool = equipTool(name)
		if tool then
			return tool
		end
	end
	for _, name in ipairs({ "Eye Drops", "Medicine", "Herbs" }) do
		if buyTool(name) then
			task.wait(0.3)
			local tool = equipTool(name)
			if tool then
				return tool
			end
		end
	end
	return nil
end

function isPatientOwned(model)
	if not Library or not Library.Flags or not Library.Flags["MultiFarm"] then
		return false
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= client and plr.Character then
			local root = plr.Character:FindFirstChild("HumanoidRootPart")
			if root and model then
				if (root.Position - model:GetPivot().Position).Magnitude < 12 then
					return true
				end
			end
		end
	end
	return false
end

function getExpectedATs(text)
	if type(text) ~= "string" then
		return nil
	end
	local key = text:lower():gsub("[^%a%s]", "")
	local direct = OBJECTIVE_TO_AT[key]
	if direct then
		return direct
	end
	for k, v in pairs(OBJECTIVE_TO_AT) do
		local nk = k:lower():gsub("[^%a%s]", "")
		if key:find(nk, 1, true) or nk:find(key, 1, true) then
			return v
		end
	end
	return nil
end

-----------------------------------------------------------------
-- SERVER ROUND EVENT REGISTER
-----------------------------------------------------------------
function hookServerEvents()
	connectRemote("SetObjective", function(...)
		local args = { ... }
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
		if Library and Library.Flags and Library.Flags["AutoHeartbeat"] then
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
		if
			Library
			and Library.Flags
			and Library.Flags["AutoReplay"]
			and State.ShiftCount < maxShifts
			and (tick() - State.LastReplayVote) > 10
		then
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
	if not State.CurrentObjective then
		return false
	end

	local objLower = State.CurrentObjective:lower()
	if objLower:find("follow") or objLower:find("wait") then
		return true
	end

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
			local model = PromptCache:GetNearestPrompt(at)
			if model and not isPatientOwned(model) then
				return fireModelPrompt(model, at)
			end
		end
	end
	return false
end

function scanIdentity()
	if not Library or not Library.Flags or not Library.Flags["AutoCheckIn"] then
		return false
	end
	if State.CheckedInPatients >= State.MaxCheckIns then
		return false
	end

	-- Safety skinwalker intercept before checking in
	if checkAndRejectSkinwalker() then
		return true
	end

	local visitor = findVisitorAtCheckIn()
	if visitor and isMonsterVisitor(visitor) then
		print("[Check-In] Monster detected at check-in, closing shutters!")
		if fireShutter("close") then
			State.SessionRejected = State.SessionRejected + 1
			notify("Anti-Skinwalker", "Rejected Disguised Skinwalker!")
		end
		return true
	end

	local root = getRoot()
	if not root then
		return false
	end

	-- Don't fire prompts while the check-in dialogue is open
	if isDialogueOpen() then
		return true
	end

	-- Named-prompt check-in sequence: Form -> Camera -> Printer -> Badge -> Computer
	local sequence = { "Stamp Forms", "Take Photo", "Print Badge", "Take Badge", "Register", "Take" }
	for _, at in ipairs(sequence) do
		local model = PromptCache:GetNearestPrompt(at)
		if model then
			local pp = model:FindFirstChildWhichIsA("ProximityPrompt", true)
			if pp and pp.Enabled and pp.ActionText:find(at, 1, true) then
				local part = getPromptPart(pp)
				if part and root and (part.Position - root.Position).Magnitude < 15 then
					if fireModelPrompt(model, at) then
						State.CheckedInPatients = State.CheckedInPatients + 1
						return true
					end
				end
			end
		end
	end

	-- Fallback: classic Scan Identity flow
	local model = PromptCache:GetNearestPrompt("Scan Identity")
	if model then
		if fireModelPrompt(model, "Scan Identity") then
			State.CheckedInPatients = State.CheckedInPatients + 1
			return true
		end
	end
	return false
end

function handleVisitorFlow()
	if not Library or not Library.Flags or not Library.Flags["VisitorFlow"] then
		return false
	end
	local obj = State.CurrentObjective
	if obj and (obj:lower():find("follow") or obj:lower():find("wait")) then
		return false
	end

	local order = {
		"Take Photo",
		"Take UV Photo",
		"Stamp Forms",
		"Stamp the form",
		"Register",
		"Print Badge",
		"Take Badge",
		"Take",
		"Talk",
		"Finish the check-in",
	}
	for _, at in ipairs(order) do
		local model = PromptCache:GetNearestPrompt(at)
		if model then
			if fireModelPrompt(model, at) then
				return true
			end
		end
	end
	return false
end

local SYNONYMS = {
	["head_ache"] = "Head Ache",
	["headache"] = "Head Ache",
	["headaches"] = "Head Ache",
	["head ache"] = "Head Ache",
	["stomachache"] = "Stomach Ache",
	["stomach_ache"] = "Stomach Ache",
	["stomach ache"] = "Stomach Ache",
	["stomach aches"] = "Stomach Ache",
	["stomach-ache"] = "Stomach Ache",
	["dry_eyes"] = "Dried Eyes",
	["dry eyes"] = "Dried Eyes",
	["dry eye"] = "Dried Eyes",
	["dried eyes"] = "Dried Eyes",
	["dried eye"] = "Dried Eyes",
	["low_sugar"] = "Low Sugar",
	["low sugar"] = "Low Sugar",
	["low blood sugar"] = "Low Sugar",
	["dehydrated"] = "Dehydration",
	["dehydration"] = "Dehydration",
	["canadian"] = "Canadian",
	["fever"] = "Fever",
	["bleeding"] = "Bleeding",
	["bruises"] = "Bruises",
	["rash"] = "Rash",
	["flu"] = "Flu",
}

local KNOWN_CURES = {
	["IV Drops"] = true,
	["Eye Drops"] = true,
	["Medicine"] = true,
	["Herbs"] = true,
	["Antibiotics"] = true,
	["Bandages"] = true,
	["Ointment"] = true,
	["Scissors"] = true,
	["Scalpel"] = true,
	["Medkit"] = true,
	["Thermo"] = true,
	["Transplant"] = true,
	["Organ"] = true,
	["Maple Syrup"] = true,
	["Cough Syrup"] = true,
	["Coffee"] = true,
}

local function getIllnessData(illnessName)
	if not illnessName then
		return nil
	end

	-- Clean and normalize name
	local cleanName = string.lower(illnessName):gsub("^%s*(.-)%s*$", "%1")
	local normalized = SYNONYMS[cleanName] or illnessName

	local ok, module = pcall(function()
		return ReplicatedStorage:FindFirstChild("Data", true):FindFirstChild("IllnessesAndCures")
	end)
	if not ok or not module then
		return nil
	end
	local ok2, data = pcall(require, module)
	if not ok2 or not data then
		return nil
	end

	if data.GetIllness then
		local ok3, res = pcall(data.GetIllness, normalized)
		if ok3 then
			return res
		end
	end

	-- Fuzzy matching
	for k, v in pairs(data) do
		local keyLower = tostring(k):lower()
		if keyLower:find(normalized:lower(), 1, true) or normalized:lower():find(keyLower, 1, true) then
			return v
		end
	end
	return nil
end

local function getCureForIllness(illnessName)
	local data = getIllnessData(illnessName)
	if data then
		if type(data) == "table" then
			local cure = data.HealedWith or data.Cure
			if cure then
				return tostring(cure)
			end
		elseif type(data) == "string" then
			return data
		end
	end
	return nil
end

local function getCuresForIllnessString(illnessString)
	if not illnessString or illnessString == "" then
		return {}
	end

	local allowedCures = {}
	for part in string.gmatch(illnessString, "[^,;]+") do
		local clean = string.gsub(part, "^%s*(.-)%s*$", "%1") -- trim
		if clean ~= "" then
			if KNOWN_CURES[clean] then
				table.insert(allowedCures, clean)
			else
				local cure = getCureForIllness(clean)
				if cure then
					table.insert(allowedCures, cure)
				end
			end
		end
	end
	return allowedCures
end

local TREATMENT_ATs = {
	"Prepare Patient",
	"Analyze Sample",
	"Process Results",
	"Begin X-Ray",
	"Turn On",
	"Set Up",
	"Begin",
	"Collect",
	"Print Badge",
	"Inspect",
	"Apply Treatment",
	"Ask to Leave",
	"Complete Analysis",
	"Take Sample",
	"Collect Results",
	"Treat",
	"Give Medicine",
}

local SURGERY_KEYWORDS = { "scissors", "transplant", "scalpel", "antibiotics", "organ", "perform", "surgery" }
local COLORS_BASE_COLOR = Color3.new(27 / 255, 42 / 255, 53 / 255)

function lockTreatment(room)
	State.IsTreatingRoom = true
	State.ActiveRoom = room
	State.TreatLock = true
end

function unlockTreatment()
	local room = State.ActiveRoom
	State.IsTreatingRoom = false
	State.ActiveRoom = nil
	State.TreatLock = false
	if room then
		State.RoomUnlockAt[room.Name] = tick()
	end
	State.ColorsSequence = {}
	State.ColorsSeen = {}
	State.ColorsLastFlash = 0
	State.ColorsAttempts = 0
	State.SurgeryDeadline = 0
end

function findRoomBedPP(room)
	if not room then
		return nil
	end
	local minigame = room:FindFirstChild("Minigame", true)
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model and not isPatientOwned(model) and model:IsDescendantOf(room) then
				local at = pp.ActionText or ""
				if at:find("Apply Treatment") or at:find("Prepare Patient") then
					return pp
				end
			end
		end
	end
	return nil
end

function isColorsGameActive(room)
	local minigame = room and room:FindFirstChild("Minigame", true)
	if not minigame then
		return nil
	end
	for _, child in ipairs(minigame:GetChildren()) do
		if child:IsA("Model") and child.Name:lower():find("color") then
			for _, m in ipairs(child:GetChildren()) do
				if m:FindFirstChild("Button", true) then
					return child
				end
			end
		end
	end
	return nil
end

function solveColorsMinigame(room)
	local colors = isColorsGameActive(room)
	if not colors then
		State.ColorsSequence = {}
		State.ColorsSeen = {}
		return false
	end
	local root = getRoot()
	if not root then
		return false
	end

	local flashed = {}
	for _, buttonModel in ipairs(colors:GetChildren()) do
		local button = buttonModel:FindFirstChild("Button", true)
		if button and button:IsA("BasePart") and button:FindFirstChildWhichIsA("ClickDetector") then
			local c = button.Color
			local dx = c.R - COLORS_BASE_COLOR.R
			local dy = c.G - COLORS_BASE_COLOR.G
			local dz = c.B - COLORS_BASE_COLOR.B
			if dx * dx + dy * dy + dz * dz > 0.01 then
				table.insert(flashed, button)
			end
		end
	end

	local now = tick()
	if #flashed > 0 then
		State.ColorsSeen = State.ColorsSeen or {}
		for _, b in ipairs(flashed) do
			local key = tostring(b.Position)
			if not State.ColorsSeen[key] then
				State.ColorsSeen[key] = true
				table.insert(State.ColorsSequence, b)
				State.ColorsLastFlash = now
			end
		end
		return false
	end

	if #State.ColorsSequence == 0 then
		return false
	end
	if now - (State.ColorsLastFlash or now) < 3 then
		return false
	end

	if (State.ColorsAttempts or 0) >= 3 then
		State.ColorsSequence = {}
		State.ColorsSeen = {}
		return false
	end
	State.ColorsAttempts = (State.ColorsAttempts or 0) + 1
	print("[Treatment] Replaying " .. #State.ColorsSequence .. " flashed colors...")
	for i, button in ipairs(State.ColorsSequence) do
		local cd = button:FindFirstChildWhichIsA("ClickDetector")
		if cd and button:IsA("BasePart") then
			local dir = (root.Position - button.Position).Unit or Vector3.new(1, 0, 0)
			root.CFrame = CFrame.new(button.Position + dir * 5 + Vector3.new(0, 3, 0))
			task.wait(0.3)
			pcall(function()
				cd.MouseClick:Fire()
			end)
			if i < #State.ColorsSequence then
				task.wait(2.5)
			end
		end
	end
	State.ColorsSequence = {}
	State.ColorsSeen = {}
	return true
end

function isSurgeryRoom(room)
	if not room then
		return false
	end
	if room.Name:lower():find("room8") or room.Name == "Room8" then
		return true
	end
	if isInvReportVisible(room) then
		return true
	end
	local text = getIllnessText(room)
	if text then
		for _, kw in ipairs(SURGERY_KEYWORDS) do
			if text:lower():find(kw, 1, true) then
				return true
			end
		end
	end
	return false
end

function fetchToolFromShelf(toolName)
	local shelf = findItemShelf(toolName)
	if not shelf then
		return false
	end
	local pp = shelf:FindFirstChild("PP") or shelf:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not pp then
		return false
	end
	local part = getInstancePart(shelf)
	if not part then
		return false
	end
	print("[Treatment] Fetching " .. toolName .. " from shelf...")
	tweenToPosition(part.Position)
	task.wait(0.5)
	updateMaxActivationDistance(pp, true)
	task.wait(0.6)
	return findToolInInventory(toolName) ~= nil
end

function fireRoomSteps(room)
	for _, at in ipairs(TREATMENT_ATs) do
		if at ~= "Apply Treatment" then
			for pp in pairs(PromptCache:GetPromptsByActionText(at)) do
				if pp.Enabled then
					local model = pp:FindFirstAncestorWhichIsA("Model")
					if model and not isPatientOwned(model) and model:IsDescendantOf(room) then
						if fireModelPrompt(model, at) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

function handleSurgery(room)
	if State.SurgeryDeadline == 0 then
		State.SurgeryDeadline = tick() + 30
	end
	if tick() > State.SurgeryDeadline then
		print("[Treatment] Surgery timed out, retrying fresh...")
		State.SurgeryDeadline = tick() + 30
		State.RoomAppliedMeds[room.Name] = nil
		State.LastMedApply[room.Name] = tick()
	end

	local required = nil
	if isInvReportVisible(room) then
		local meds = getRequiredMeds(room)
		required = meds and meds[1]
	end
	if not required then
		local text = getIllnessText(room) or ""
		for kw, tool in pairs(SURGERY_TOOL_MAP) do
			if text:lower():find(kw:lower(), 1, true) then
				required = tool
				break
			end
		end
	end
	if not required then
		return fireRoomSteps(room)
	end
	local lastApply = State.LastMedApply[room.Name]
	if lastApply and tick() - lastApply < 4 then
		return true
	end

	local tool = findToolInInventory(required)
	if not tool then
		if not fetchToolFromShelf(required) then
			return true
		end
		tool = findToolInInventory(required)
	end
	if not tool then
		return true
	end
	local bedPP = findRoomBedPP(room)
	if not bedPP then
		return true
	end
	if not useToolByName(tool.Name) then
		return true
	end
	safeMoveToModel(bedPP:FindFirstAncestorWhichIsA("Model"))
	task.wait(0.3)
	if fireModelPrompt(bedPP:FindFirstAncestorWhichIsA("Model"), bedPP.ActionText) then
		State.SessionHealed = State.SessionHealed + 1
		State.LastMedApply[room.Name] = tick()
		State.RoomAppliedMeds[room.Name] = State.RoomAppliedMeds[room.Name] or {}
		State.RoomAppliedMeds[room.Name][required] = (State.RoomAppliedMeds[room.Name][required] or 0) + 1
	end
	return true
end

function continueRoomTreatment(room)
	if not room then
		unlockTreatment()
		return false
	end
	State.ActiveRoom = room

	if isRecovering(room) then
		print("[Treatment] Patient in " .. room.Name .. " is recovering, moving on.")
		State.RoomAppliedMeds[room.Name] = nil
		unlockTreatment()
		return false
	end

	if solveColorsMinigame(room) then
		return true
	end

	if isSurgeryRoom(room) then
		return handleSurgery(room)
	end

	local bedPP = findRoomBedPP(room)
	local requiredMeds = getRequiredMeds(room)

	if #requiredMeds > 0 then
		local cure = requiredMeds[1]
		-- Wait for the game's report check / Healing header to register before
		-- applying again: re-firing too fast re-doses the patient and kills them.
		local lastApply = State.LastMedApply[room.Name]
		if lastApply and tick() - lastApply < 4 then
			return true
		end
		-- Free inventory space first (trash unneeded items)
		if getToolCount() >= getCarryCapacity() then
			trashUnneededItems(cure)
			task.wait(0.3)
		end
		local tool = findToolInInventory(cure)
		if not tool then
			if not fetchToolFromShelf(cure) then
				return true
			end
			tool = findToolInInventory(cure)
		end
		if tool and bedPP then
			if useToolByName(tool.Name) then
				safeMoveToModel(bedPP:FindFirstAncestorWhichIsA("Model"))
				task.wait(0.3)
				if fireModelPrompt(bedPP:FindFirstAncestorWhichIsA("Model"), bedPP.ActionText) then
					State.SessionHealed = State.SessionHealed + 1
					State.LastMedApply[room.Name] = tick()
					State.RoomAppliedMeds[room.Name] = State.RoomAppliedMeds[room.Name] or {}
					State.RoomAppliedMeds[room.Name][cure] = (State.RoomAppliedMeds[room.Name][cure] or 0) + 1
					return true
				end
			end
		end
		return true
	end

	local progress = fireRoomSteps(room)
	if not progress then
		-- Nothing actionable left in this room: release the step lock
		unlockTreatment()
	end
	return progress
end

function handleRoomTreatment()
	if not Library or not Library.Flags or not Library.Flags["RoomTreatment"] then
		return false
	end

	if State.IsTreatingRoom then
		return continueRoomTreatment(State.ActiveRoom)
	end

	local candidates = {}
	local seen = {}
	for _, at in ipairs(TREATMENT_ATs) do
		for pp in pairs(PromptCache:GetPromptsByActionText(at)) do
			if pp.Enabled then
				local model = pp:FindFirstAncestorWhichIsA("Model")
				if model and not isPatientOwned(model) then
					local room = model:FindFirstAncestorWhichIsA("Model")
					if room and not seen[room] then
						seen[room] = true
						table.insert(candidates, { Room = room, Dist = distanceTo(room:GetPivot().Position) })
					end
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Dist < b.Dist
	end)

	for _, c in ipairs(candidates) do
		local un = State.RoomUnlockAt[c.Room]
		if not (un and tick() - un < 4) then
			if continueRoomTreatment(c.Room) then
				lockTreatment(c.Room)
				return true
			end
		end
	end
	return false
end

function handleEmergency()
	if not Library or not Library.Flags or not Library.Flags["EmergencyRooms"] then
		return false
	end

	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model and not isPatientOwned(model) then
				local name = model.Name
				if name:find("Ambulance") or name:find("Critical") or name:find("Emergency") then
					if fireModelPrompt(model) then
						return true
					end
				end
			end
		end
	end
	return false
end

function startShift()
	if not Library or not Library.Flags or not Library.Flags["AutoShift"] then
		return
	end

	local desk = Workspace:FindFirstChild("Misc") and Workspace.Misc:FindFirstChild("StartShift")
	if desk then
		local pp = desk:FindFirstChildWhichIsA("ProximityPrompt", true)
		if pp and pp.Enabled then
			fireModelPrompt(desk)
			return
		end
	end

	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model then
				local name = model.Name
				-- NOTE: "Computer" is the check-in register; never fire it here.
				if (name:find("StartShift") or name:find("ShiftButton")) and not name:find("CheckIn") then
					fireModelPrompt(model)
					return
				end
			end
		end
	end
end

function handleFainted()
	if not Library or not Library.Flags or not Library.Flags["CarryFainted"] then
		return
	end
	local root = getRoot()
	if not root then
		return
	end

	for _, tag in ipairs({ "Downed", "DeadPlayer", "Fainted" }) do
		for _, m in ipairs(CollectionService:GetTagged(tag)) do
			if m:IsA("Model") then
				local p = m:FindFirstChild("HumanoidRootPart")
					or m:FindFirstChild("Torso")
					or m:FindFirstChildWhichIsA("BasePart")
				if p and distanceTo(p.Position) < 40 then
					-- Pick up the fainted NPC and drop them at the trash can,
					-- or at a bed inside their room if no trash can is available
					local carryPP = nil
					for pp in pairs(PromptCache._prompts) do
						if pp.Enabled then
							local at = pp.ActionText or ""
							if at:find("Pick Up") or at:find("Carry") then
								local pm = pp:FindFirstAncestorWhichIsA("Model")
								if pm and (pm == m or pm:IsDescendantOf(m)) then
									carryPP = pp
									break
								end
							end
						end
					end
					if not carryPP then
						return
					end
					tweenToPosition(p.Position)
					task.wait(0.3)
					firePromptChecked(carryPP)
					task.wait(0.6)
					local trashPP = findTrashCan()
					if trashPP then
						local trashPart = getPromptPart(trashPP)
						if trashPart then
							tweenToPosition(trashPart.Position)
						end
						task.wait(0.4)
						updateMaxActivationDistance(trashPP, true)
					else
						local room = m:FindFirstAncestorWhichIsA("Model")
						local bedPP = findRoomBedPP(room)
						if bedPP then
							safeMoveToModel(bedPP:FindFirstAncestorWhichIsA("Model"))
							task.wait(0.3)
							fireModelPrompt(bedPP:FindFirstAncestorWhichIsA("Model"), bedPP.ActionText)
						end
					end
					return
				end
			end
		end
	end
end

function handlePeopleOnFire()
	if not Library or not Library.Flags or not Library.Flags["PutOutFire"] then
		return
	end
	if Library and Library.Flags and Library.Flags["FireStrat"] and Library.Flags["AutoShift"] then
		return
	end

	local fireModel = PromptCache:GetNearestPrompt("Put out")
	if fireModel then
		fireModelPrompt(fireModel, "Put out")
		return
	end
end

function handleEyeMass()
	if not Library or not Library.Flags or not Library.Flags["AvoidEyeMass"] then
		return
	end
	local root = getRoot()
	if not root then
		return
	end

	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model then
				local name = model.Name:lower()
				if name:find("eyemass") or name:find("eye mass") then
					local pivot = model:GetPivot()
					local dist = (root.Position - pivot.Position).Magnitude
					if dist < 40 then
						equipTool("Eye Drops")
						-- Room-aware: apply Eye Drops to the patient BED inside the
						-- room where the eyemass is, not to the eyemass itself.
						local room = model:FindFirstAncestorWhichIsA("Model")
						local bedTarget = nil
						for pp2 in pairs(PromptCache._prompts) do
							if pp2.Enabled and pp2.ActionText == "Apply Treatment" then
								local m2 = pp2:FindFirstAncestorWhichIsA("Model")
								if m2 and m2:IsDescendantOf(room) and not isPatientOwned(m2) then
									bedTarget = m2
									break
								end
							end
						end
						local target = bedTarget or model
						if dist > 10 then
							safeMoveToModel(target)
						end
						fireModelPrompt(target, "Apply Treatment")
						return
					end
				end
			end
		end
	end
end

function fleeMonsters()
	if not Library or not Library.Flags or not Library.Flags["AvoidMonsters"] then
		return
	end
	local root = getRoot()
	if not root then
		return
	end

	local monsters = MonsterCache:GetMonsters()
	for _, m in ipairs(monsters) do
		local p = m:FindFirstChild("HumanoidRootPart")
			or m:FindFirstChild("Torso")
			or m:FindFirstChildWhichIsA("BasePart")
		if p then
			local dist = (root.Position - p.Position).Magnitude
			if dist < 32 then
				local dir = (root.Position - p.Position).Unit
				pcall(function()
					root.CFrame = CFrame.new(root.Position + dir * 55)
				end)
				clearActiveTweens()
				return
			end
		end
	end
end

function handleFixCams()
	if not Library or not Library.Flags or not Library.Flags["FixCams"] then
		return
	end
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model and (model.Name:lower():find("camera") or model.Name:lower():find("cam")) then
				fireModelPrompt(model)
				task.wait(2)
				return
			end
		end
	end
end

function handleTakeDNA()
	if not Library or not Library.Flags or not Library.Flags["TakeDNA"] then
		return
	end
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model and (model.Name:lower():find("dna") or model.Name:lower():find("sample")) then
				fireModelPrompt(model)
				return
			end
		end
	end
end

function helpLiz()
	if not Library or not Library.Flags or not Library.Flags["HelpLiz"] then
		return
	end
	local lizModel = PromptCache:GetNearestPrompt("Help Liz")
	if lizModel then
		fireModelPrompt(lizModel, "Help Liz")
		return
	end

	local giftModel = PromptCache:GetNearestPrompt("Accept Gift")
	if giftModel then
		fireModelPrompt(giftModel, "Accept Gift")
		return
	end
end

function stalkerHandler()
	if not Library or not Library.Flags or not Library.Flags["StalkerHandler"] then
		return
	end
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
	if not Library or not Library.Flags or not Library.Flags["AutoBuyItems"] then
		return
	end
	local item = Library.Flags["AutoBuyItemName"]
	if not item then
		return
	end

	if getToolCount() >= 3 then
		trashItems()
		task.wait(0.5)
	end
	local model = PromptCache:GetNearestPrompt(item)
	if model then
		fireModelPrompt(model)
	end
end

function handleInventory()
	if not Library or not Library.Flags or not Library.Flags["AutoTrash"] then
		return
	end
	if getToolCount() >= 3 then
		trashItems()
	end
end

function autoTaseCritical()
	if not Library or not Library.Flags or not Library.Flags["AutoTaseCritical"] then
		return
	end
	local mode = Library.Flags["TaseCriticalRoom"] or "All"

	for _, m in ipairs(Workspace:GetDescendants()) do
		if m:IsA("Model") and m.Name:lower():find("critical") then
			local roomOk = (mode == "All") or (m.Name:find(tostring(mode)))
			if roomOk then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
					if p and distanceTo(p.Position) < 30 then
						-- Tool-based tase (no fake remote; TaserFired does not exist)
						toolTaseTarget(m)
						task.wait(0.3)
					end
				end
			end
		end
	end
end

function infiniteTaseAll()
	if not Library or not Library.Flags or not Library.Flags["InfiniteTaseAll"] then
		return
	end
	local taser = equipTool("Taser") or equipTool("X-Taser")
	if not taser then
		return
	end

	for pp in pairs(PromptCache._prompts) do
		local m = pp:FindFirstAncestorWhichIsA("Model")
		if m and (m:GetAttribute("IsPatient") or m.Name:lower():find("patient") or m.Name:lower():find("visitor")) then
			local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
			if p and distanceTo(p.Position) < 50 then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					pcall(function()
						toolTaseTarget(m)
					end)
					task.wait(0.1)
				end
			end
		end
	end
end

-----------------------------------------------------------------
-- UPGRADED SUBSYSTEMS (proven in-game techniques)
-----------------------------------------------------------------
local function findCoffeePrompt()
	local best, bestDist = nil, math.huge
	local root = getRoot()
	for _, pp in ipairs(Workspace:GetDescendants()) do
		if pp:IsA("ProximityPrompt") and pp.Enabled then
			local at = pp.ActionText or ""
			if at:find("Coffee") or at:find("coffee") then
				local part = getPromptPart(pp)
				if part and root then
					local d = (part.Position - root.Position).Magnitude
					if d < bestDist then
						bestDist = d
						best = pp
					end
				end
			end
		end
	end
	return best, bestDist
end

local function activateTool(tool)
	if not tool then
		return
	end
	pcall(function()
		tool:Activate()
	end)
end

function toolTaseTarget(target)
	if not target then
		return false
	end
	local taser = findToolInInventory("Taser") or findToolInInventory("X-Taser")
	if not taser then
		if not fetchToolFromShelf("Taser") and not fetchToolFromShelf("X-Taser") then
			return false
		end
		taser = findToolInInventory("Taser") or findToolInInventory("X-Taser")
	end
	if not taser then
		return false
	end
	local root = getRoot()
	local p = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or getInstancePart(target)
	if not p then
		return false
	end
	if root and (p.Position - root.Position).Magnitude > 25 then
		tweenToPosition(p.Position)
	end
	useToolByName(taser.Name)
	task.wait(0.2)
	activateTool(taser)
	return true
end

function handleTaseMonsters()
	if not Library or not Library.Flags or not Library.Flags["AutoTaseMonsters"] then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	for _, m in ipairs(MonsterCache:GetMonsters()) do
		local p = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or getInstancePart(m)
		if p and (p.Position - root.Position).Magnitude <= 25 then
			if not m:GetAttribute("IsPatient") then
				if m:GetAttribute("Skinwalker") or m:GetAttribute("IsMonster") or m:GetAttribute("Monster") then
					if toolTaseTarget(m) then
						task.wait(0.3)
					end
					return
				end
			end
		end
	end
end

function drinkCoffeeIfNeeded()
	if not Library or not Library.Flags or not Library.Flags["AutoDrinkCoffee"] then
		return
	end
	if State.IsDrinkingCoffee then
		return
	end
	local sanity = client:GetAttribute("Sanity")
	if sanity == nil or sanity >= 50 then
		return
	end
	local pp = findCoffeePrompt()
	if not pp then
		return
	end
	State.IsDrinkingCoffee = true
	print("[Sanity] Sanity low (" .. tostring(sanity) .. "), grabbing coffee...")
	local ok = fetchToolFromShelf("Coffee")
	if not ok then
		local part = getPromptPart(pp)
		if part then
			tweenToPosition(part.Position)
		end
		task.wait(0.3)
		updateMaxActivationDistance(pp, true)
		task.wait(0.5)
	end
	local coffee = useToolByName("Coffee")
	if coffee then
		activateTool(coffee)
		task.wait(0.2)
		activateTool(coffee)
		task.wait(0.2)
		activateTool(coffee)
	end
	State.IsDrinkingCoffee = false
end

function handleBedMonster()
	if not Library or not Library.Flags or not Library.Flags["BedMonsterSyrup"] then
		return
	end
	local monster = findBedMonster()
	if not monster then
		return
	end
	local root = getRoot()
	local p = getInstancePart(monster)
	if not p or not root or (p.Position - root.Position).Magnitude > 30 then
		return
	end
	local syrup = findToolInInventory("Maple Syrup")
	if not syrup then
		fetchToolFromShelf("Maple Syrup")
		syrup = findToolInInventory("Maple Syrup")
	end
	if not syrup then
		return
	end
	useToolByName("Maple Syrup")
	task.wait(0.2)
	local room = monster:FindFirstAncestorWhichIsA("Model")
	local bedPP = findRoomBedPP(room)
	if bedPP then
		safeMoveToModel(bedPP:FindFirstAncestorWhichIsA("Model"))
		task.wait(0.3)
		fireModelPrompt(bedPP:FindFirstAncestorWhichIsA("Model"), bedPP.ActionText)
	else
		activateTool(syrup)
	end
end

function handleHeadBanger()
	if not Library or not Library.Flags or not Library.Flags["AutoHeadBanger"] then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	for _, npc in ipairs(Workspace:FindFirstChild("NPCs") and Workspace.NPCs:GetChildren() or {}) do
		local n = npc.Name:lower()
		if n:find("banger") or n:find("head") then
			local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
			if p and (p.Position - root.Position).Magnitude <= 30 then
				if not findToolInInventory("Coffee") then
					fetchToolFromShelf("Coffee")
				end
				if useToolByName("Coffee") then
					for pp in pairs(PromptCache._prompts) do
						if pp.Enabled then
							local m = pp:FindFirstAncestorWhichIsA("Model")
							if m == npc or m:IsDescendantOf(npc) then
								fireModelPrompt(m, pp.ActionText)
								return
							end
						end
					end
				end
			end
		end
	end
end

function handleCeilingEyes()
	if not Library or not Library.Flags or not Library.Flags["CeilingEyes"] then
		return
	end
	local gui = client:FindFirstChild("PlayerGui")
	if not gui then
		return
	end
	local warning = false
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextLabel") and desc.Text:lower():find("don't look up") then
			warning = true
			break
		end
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	if warning then
		State.CameraYaw = State.CameraYaw or 0
		pcall(function()
			cam.CFrame = cam.CFrame * CFrame.Angles(1.2, 0, 0)
		end)
	else
		State.CameraYaw = nil
	end
end

function handleSkinwalkerEscape()
	if not Library or not Library.Flags or not Library.Flags["SkinwalkerEscape"] then
		return
	end
	local gui = client:FindFirstChild("PlayerGui")
	if not gui then
		return
	end
	local escaped = false
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextLabel") then
			local t = desc.Text:lower()
			if t:find("grab") or t:find("struggle") then
				escaped = true
				break
			end
		end
	end
	if escaped then
		pcall(function()
			keypress(69)
			task.wait(0.1)
			keyrelease(69)
		end)
		pcall(function()
			SendKeyEvent = SendKeyEvent or (game:GetService("VirtualInputManager") and function(key)
				game:GetService("VirtualInputManager"):SendKeyEvent(true, key, false, game)
				task.wait(0.05)
				game:GetService("VirtualInputManager"):SendKeyEvent(false, key, false, game)
			end)
			if SendKeyEvent then
				SendKeyEvent(Enum.KeyCode.E)
			end
		end)
	end
end

function handleCCTVExit()
	if not Library or not Library.Flags or not Library.Flags["CCTVExit"] then
		return
	end
	local gui = client:FindFirstChild("PlayerGui")
	if not gui then
		return
	end
	local camsys = gui:FindFirstChild("CameraSystem")
	if not camsys or not camsys.Enabled then
		return
	end
	local lost = false
	for _, desc in ipairs(camsys:GetDescendants()) do
		if desc:IsA("TextLabel") then
			local t = desc.Text:lower()
			if t:find("lost") or t:find("signal") or t:find("error") then
				lost = true
				break
			end
		end
	end
	if lost then
		pcall(function()
			local btn = camsys:FindFirstChild("BackButton", true)
				or camsys:FindFirstChild("Exit", true)
				or camsys:FindFirstChild("Close", true)
			if btn then
				firesignal(btn.MouseButton1Click)
			end
		end)
	end
end

function handleFuses()
	if not Library or not Library.Flags or not Library.Flags["AutoFuses"] then
		return
	end
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model then
				local n = model.Name:lower()
				if n:find("fuse") then
					fireModelPrompt(model, pp.ActionText)
					task.wait(1.5)
					return
				end
			end
		end
	end
end

function handleShopUpgrades()
	if not Library or not Library.Flags or not Library.Flags["AutoShopUpgrades"] then
		return
	end
	local category = Library.Flags["ShopUpgradeCategory"] or "BuyCapacity"
	local keywords = SHOP_CATEGORIES[category]
	if not keywords then
		return
	end
	local root = getRoot()
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled and pp:GetAttribute("ShopItemPP") then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			local match = (model and (model:GetAttribute("ObjectText") or model.Name)) or ""
			match = match:lower()
			for _, kw in ipairs(keywords) do
				if match:find(kw, 1, true) then
					local part = getPromptPart(pp)
					if part and root and (part.Position - root.Position).Magnitude < 15 then
						updateMaxActivationDistance(pp, true)
						return
					end
				end
			end
		end
	end
end

function handleHeartbeatFallback()
	if not Library or not Library.Flags or not Library.Flags["AutoHeartbeat"] then
		return
	end
	if not CollectionService:HasTag(client, "InMinigame") then
		return
	end
	local lib = getAHLib()
	if lib and lib.HeartMinigameComplete then
		pcall(function()
			lib.HeartMinigameComplete(true)
		end)
	else
		fireRemote("RE/HeartbeatMinigameComplete", nil, true)
	end
end

local CONFIG_NAME = "VersusAirlinesUltra.json"

function saveFlags()
	local ok = pcall(function()
		local out = {}
		for k, v in pairs(Library.Flags) do
			if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
				out[k] = v
			end
		end
		writefile(CONFIG_NAME, HttpService:JSONEncode(out))
	end)
	if ok then
		notify("Config", "Saved to " .. CONFIG_NAME)
	else
		notify("Config", "writefile not supported on this executor")
	end
end

function loadFlags()
	local ok, data = pcall(function()
		return readfile(CONFIG_NAME)
	end)
	if not ok or not data then
		return
	end
	local ok2, tbl = pcall(function()
		return HttpService:JSONDecode(data)
	end)
	if not ok2 or type(tbl) ~= "table" then
		return
	end
	for k, v in pairs(tbl) do
		if Library.Flags[k] ~= nil then
			Library.Flags[k] = v
		end
	end
	State.ConfigLoaded = true
	notify("Config", "Loaded settings from " .. CONFIG_NAME)
end

function tryTeleport(name)
	local root = getRoot()
	if not root then
		return false
	end
	local pos = nil
	if name:find("Coffee") then
		local pp = findCoffeePrompt()
		local part = pp and getPromptPart(pp)
		if part then
			pos = part.Position + Vector3.new(0, 3, 0)
		end
	elseif name:find("Check%-In") or name:find("Counter") then
		local model = PromptCache:GetNearestPrompt("Stamp Forms")
			or PromptCache:GetNearestPrompt("Take Photo")
			or PromptCache:GetNearestPrompt("Scan Identity")
		if model then
			pos = model:GetPivot().Position
		end
	elseif name:find("Shop") then
		local model = PromptCache:GetNearestPrompt("Buy")
		if model then
			pos = model:GetPivot().Position
		end
	else
		local roomNum = name:match("(%d)")
		if roomNum then
			local room = getRoomByNumber(tonumber(roomNum))
			local minigame = room and room:FindFirstChild("Minigame", true)
			local bed = minigame and minigame:FindFirstChild("Bed")
			local part = getInstancePart(bed)
			if part then
				pos = part.Position + Vector3.new(0, 3, 0)
			end
		end
	end
	if not pos then
		notify("Teleport", "Destination not found: " .. name)
		return false
	end
	tweenToPosition(pos)
	notify("Teleport", "Moved to " .. name)
	return true
end

function coinFarm()
	if not Library or not Library.Flags or not Library.Flags["CoinFarm"] then
		return
	end
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local model = pp:FindFirstAncestorWhichIsA("Model")
			if model then
				local name = model.Name:lower()
				if name:find("coin") or name:find("cash") or name:find("shutter") then
					fireModelPrompt(model)
					return
				end
			end
		end
	end
end

function infiniteLives()
	if not Library or not Library.Flags or not Library.Flags["InfiniteLives"] then
		return
	end
	local hum = getHumanoid()
	if hum and hum.Health <= 0 then
		fireRemote("RE/ReviveOther", client)
	end
end

function autoRevive()
	if not Library or not Library.Flags or not Library.Flags["AutoRevive"] then
		return
	end
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
	if not Library or not Library.Flags or not Library.Flags["InstantPP"] then
		return
	end
	-- Never auto-trigger dangerous prompts: skipping HoldDuration=0 means the
	-- player must hold them manually (e.g. "Jumpscare All", "Buy Gun").
	local DANGEROUS_AT = {
		["Jumpscare All"] = true,
		["Buy Gun"] = true,
		["Vote to End the Game"] = true,
	}
	for pp in pairs(PromptCache._prompts) do
		if not DANGEROUS_AT[pp.ActionText] then
			pcall(function()
				-- Cache the original hold duration once and restore it after
				-- each trigger (instant-interact restore pattern)
				if State.OriginalHoldDurations[pp] == nil then
					State.OriginalHoldDurations[pp] = pp.HoldDuration
				end
				if not State.InstantPPHooked[pp] then
					State.InstantPPHooked[pp] = true
					local conn = pp.Triggered:Connect(function()
						task.wait(0.2)
						pcall(function()
							pp.HoldDuration = State.OriginalHoldDurations[pp] or 0.5
						end)
					end)
					GlobalJanitor:Add(conn)
				end
				pp.HoldDuration = 0
			end)
		end
	end
end

-----------------------------------------------------------------
-- EMERGENCY UTILITIES (Candles, Safes, etc.)
-----------------------------------------------------------------
function autoBlowCandles()
	if not Library or not Library.Flags or not Library.Flags["AutoBlowCandles"] then
		return false
	end
	-- Blow out EVERY lit candle, not just the nearest one
	local blew = false
	for pp in pairs(PromptCache._prompts) do
		if pp.Enabled then
			local at = pp.ActionText or ""
			if at:find("Blow out") then
				local model = pp:FindFirstAncestorWhichIsA("Model")
				if model then
					fireModelPrompt(model, "Blow out")
					blew = true
				end
			end
		end
	end
	return blew
end

function autoOpenSafes()
	if not Library or not Library.Flags or not Library.Flags["AutoOpenSafes"] then
		return
	end
	local m = PromptCache:GetNearestPrompt("Open")
	if m and m.Name:lower():find("safe") then
		fireModelPrompt(m, "Open")
	end
end

function skipDialogue()
	if not Library or not Library.Flags or not Library.Flags["AutoSkipDialogue"] then
		return
	end
	if isDialogueOpen() then
		fireRemote("RE/SetDoctorDialogueSkipped")
	end
end

function autoRescueEaten()
	if not Library or not Library.Flags or not Library.Flags["AutoRescueEaten"] then
		return
	end
	local target = nil
	for _, m in ipairs(MonsterCache:GetMonsters()) do
		if not m:IsA("Model") then
			break
		end
		local isEating = false
		for _, pp in ipairs(m:GetDescendants()) do
			if pp:IsA("ProximityPrompt") and pp.Enabled then
				local at = (pp.ActionText or ""):lower()
				if at:find("eat") or at:find("feed") then
					isEating = true
					break
				end
			end
		end
		if isEating then
			target = m
			break
		end
	end
	if not target then
		return
	end
	local syrup = findToolInInventory("Maple Syrup")
	if not syrup then
		if not fetchToolFromShelf("Maple Syrup") then
			return
		end
		syrup = findToolInInventory("Maple Syrup")
	end
	if not syrup then
		return
	end
	if useToolByName(syrup.Name) then
		safeMoveToModel(target)
		task.wait(0.3)
		local tool = getChar() and getChar():FindFirstChild("Maple Syrup")
		if tool then
			pcall(function()
				tool:Activate()
			end)
		end
	end
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
		if not root then
			return
		end
		if flyBV then
			flyBV:Destroy()
		end
		if flyBG then
			flyBG:Destroy()
		end

		flyBV = Instance.new("BodyVelocity")
		flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
		flyBV.Velocity = Vector3.zero
		flyBV.Parent = root

		flyBG = Instance.new("BodyGyro")
		flyBG.MaxForce = Vector3.new(1, 1, 1) * 9e9
		flyBG.P = 9e4
		flyBG.Parent = root

		local hum = getHumanoid()
		if hum then
			hum.PlatformStand = true
		end

		if flyConn then
			flyConn:Disconnect()
		end
		flyConn = RunService.RenderStepped:Connect(function()
			if not Library or not Library.Flags or not Library.Flags["Fly"] then
				toggleFly(false)
				return
			end
			local cam = Workspace.CurrentCamera
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
			flyBV.Velocity = dir * (Library.Flags["FlySpeed"] or 50)
			flyBG.CFrame = cam.CFrame
		end)
	else
		if flyBV then
			flyBV:Destroy()
			flyBV = nil
		end
		if flyBG then
			flyBG:Destroy()
			flyBG = nil
		end
		if flyConn then
			flyConn:Disconnect()
			flyConn = nil
		end
		local hum = getHumanoid()
		if hum then
			hum.PlatformStand = false
		end
	end
end

local ncConn
function toggleNoclip(enabled)
	State.LastNoclipToggle = enabled
	if ncConn then
		ncConn:Disconnect()
		ncConn = nil
	end
	if not enabled then
		return
	end
	ncConn = RunService.Stepped:Connect(function()
		if not Library or not Library.Flags or not Library.Flags["Noclip"] then
			if ncConn then
				ncConn:Disconnect()
				ncConn = nil
			end
			return
		end
		local char = getChar()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)
end

local infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
	if Library and Library.Flags and Library.Flags["InfiniteJump"] then
		local hum = getHumanoid()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)
GlobalJanitor:Add(infiniteJumpConn)

-----------------------------------------------------------------
-- PERFORMANCE STABLE ESP ENGINE
-----------------------------------------------------------------
function clearESP()
	for _, obj in ipairs(State.ESPObjects) do
		pcall(function()
			if obj.Remove then
				obj:Remove()
			else
				obj:Destroy()
			end
		end)
	end
	table.clear(State.ESPObjects)
	table.clear(State.ESPTracked)
end

function createEsp(target, color, text)
	if not target then
		return
	end
	-- Drawing API boxes + tracers + names (lower overhead)
	local drawing = Drawing
	local part = getInstancePart(target)
	if part and drawing and drawing.new then
		local box = drawing.new("Square")
		box.Visible = false
		box.Color = color
		box.Thickness = 1.5
		box.Filled = false
		box.Transparency = 0.2
		table.insert(State.ESPObjects, box)

		local line = drawing.new("Line")
		line.Visible = false
		line.Color = color
		line.Thickness = 1
		line.Transparency = 0.4
		table.insert(State.ESPObjects, line)

		local nameText = nil
		if text and Library.Flags["ESPShowNames"] then
			nameText = drawing.new("Text")
			nameText.Visible = false
			nameText.Color = color
			nameText.Center = true
			nameText.Size = 14
			nameText.Outline = true
			nameText.Text = text
			table.insert(State.ESPObjects, nameText)
		end

		table.insert(State.ESPTracked, {
			Part = part,
			Box = box,
			Line = line,
			Text = nameText,
		})
		return
	end

	-- Fallback: Highlight (works on all executors)
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
	if ok and hl then
		table.insert(State.ESPObjects, hl)
	end
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
	if not Library or not Library.Flags or not Library.Flags["ESPEnabled"] then
		clearESP()
		return
	end
	clearESP()

	if Library and Library.Flags and Library.Flags["ESPPlayers"] then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= client and plr.Character then
				createEsp(plr.Character, Color3.fromRGB(0, 170, 255), plr.Name)
			end
		end
	end

	if Library and Library.Flags and Library.Flags["ESPPatients"] then
		local npcs = Workspace:FindFirstChild("NPCs")
		if npcs then
			for _, m in ipairs(npcs:GetChildren()) do
				if m:GetAttribute("IsPatient") then
					createEsp(m, Color3.fromRGB(0, 255, 100), "Patient")
				end
			end
		end
	end

	if Library and Library.Flags and Library.Flags["ESPMonsters"] then
		for _, m in ipairs(MonsterCache:GetMonsters()) do
			local name = m.Name:lower()
			if name:find("monster") or name:find("shadow") or name:find("tallmonster") then
				createEsp(m, Color3.fromRGB(255, 50, 50), "Monster")
			end
		end
	end

	if Library and Library.Flags and Library.Flags["ESPAnomalies"] then
		for _, m in ipairs(MonsterCache:GetMonsters()) do
			local name = m.Name:lower()
			if name:find("anomaly") or name:find("eyemass") or name:find("stalker") or isSkinwalker(m) then
				createEsp(m, Color3.fromRGB(255, 85, 0), "Anomaly / Skinwalker")
			end
		end
	end
end

-- Draw ESP boxes/tracers each frame using tracked parts
local espDrawConn = RunService.RenderStepped:Connect(function()
	if not Library or not Library.Flags or not Library.Flags["ESPEnabled"] then
		return
	end
	if #State.ESPTracked == 0 then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local root = getRoot()
	for _, entry in ipairs(State.ESPTracked) do
		local p = entry.Part
		if p and p.Parent then
			local spos = cam:WorldToScreenPoint(p.Position)
			if spos.Z < 0 then
				if entry.Box then
					entry.Box.Visible = false
				end
				if entry.Text then
					entry.Text.Visible = false
				end
			else
				local scale = 0.12 * (math.max(1, spos.Z))
				local boxSize = Vector2.new(scale * 1.6, scale * 4.4)
				if entry.Box then
					entry.Box.Position = Vector2.new(spos.X, spos.Y - boxSize.Y / 2)
					entry.Box.Size = boxSize
					entry.Box.Visible = true
				end
				if entry.Text then
					entry.Text.Position = Vector2.new(spos.X, spos.Y - boxSize.Y / 2 - 16)
					entry.Text.Visible = true
				end
				if entry.Line and root then
					local rootScreen = cam:WorldToScreenPoint(root.Position)
					entry.Line.From = Vector2.new(rootScreen.X, rootScreen.Y)
					entry.Line.To = Vector2.new(spos.X, spos.Y)
					entry.Line.Visible = rootScreen.Z > 0
				end
			end
		else
			if entry.Box then
				entry.Box.Visible = false
			end
			if entry.Text then
				entry.Text.Visible = false
			end
		end
	end
end)
GlobalJanitor:Add(espDrawConn)

-----------------------------------------------------------------
-- SERVER ACTIONS
-----------------------------------------------------------------
function serverHop()
	pcall(function()
		local url =
			string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
		local body = game:HttpGet(url)
		if not body or body == "" then
			return
		end
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
	pcall(function()
		TeleportService:Teleport(game.PlaceId, client)
	end)
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
-- UI DESIGN & CONFIGURATION
-----------------------------------------------------------------
local farmSection = ui:CreateSection("Auto Farm")
farmSection:createToggle({
	Name = "Auto Farm",
	flagName = "AutoFarm",
	Flag = false,
})
farmSection:createToggle({
	Name = "Auto Check-In",
	flagName = "AutoCheckIn",
	Flag = false,
})
farmSection:createToggle({
	Name = "Auto Reject Skinwalkers",
	flagName = "AutoRejectSkinwalkers",
	Flag = false,
})
farmSection:createToggle({
	Name = "Visitor Flow",
	flagName = "VisitorFlow",
	Flag = false,
})
farmSection:createToggle({
	Name = "Room Treatment (Rooms 1-8)",
	flagName = "RoomTreatment",
	Flag = false,
})
farmSection:createToggle({
	Name = "Emergency Rooms (Ambulance)",
	flagName = "EmergencyRooms",
	Flag = false,
})
farmSection:createToggle({
	Name = "Auto Shift",
	flagName = "AutoShift",
	Flag = false,
})
farmSection:createToggle({
	Name = "Fire Strat (XP Grind)",
	flagName = "FireStrat",
	Flag = false,
})
farmSection:createToggle({
	Name = "Multi Farm (Safe Queue)",
	flagName = "MultiFarm",
	Flag = false,
})
farmSection:createSlider({
	Name = "Replay Shifts",
	flagName = "ReplayShifts",
	value = 1,
	minValue = 1,
	maxValue = 30,
})

farmSection:createToggle({
	Name = "Auto Replay",
	flagName = "AutoReplay",
	Flag = false,
	Callback = function(enabled)
		if enabled then
			State.ShiftCount = 0
			notify("Auto Replay", "Will vote to replay for " .. (Library.Flags["ReplayShifts"] or 1) .. " shifts")
		end
	end,
})

local movementSection = ui:CreateSection("Movement Config")
movementSection:createDropdown({
	Name = "Movement Mode",
	flagName = "MovementMode",
	Flag = "Tween",
	List = { "Tween", "Instant Teleport" },
	multi = false,
})
movementSection:createSlider({
	Name = "Tween Speed",
	flagName = "TweenSpeed",
	value = 65,
	minValue = 30,
	maxValue = 150,
})

local emergencySection = ui:CreateSection("Emergency & Interaction")
emergencySection:createToggle({
	Name = "Auto Blow Candles",
	flagName = "AutoBlowCandles",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Auto Open Safes",
	flagName = "AutoOpenSafes",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Fix Cams (Repair CCTV)",
	flagName = "FixCams",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Carry / Throw Fainted",
	flagName = "CarryFainted",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Avoid Eye Mass",
	flagName = "AvoidEyeMass",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Avoid Monsters (Safety)",
	flagName = "AvoidMonsters",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Help Liz (Gift Claim)",
	flagName = "HelpLiz",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Stalker Handler",
	flagName = "StalkerHandler",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Auto Skip Dialogue",
	flagName = "AutoSkipDialogue",
	Flag = false,
})
emergencySection:createToggle({
	Name = "Save Eaten Patients (Syrup)",
	flagName = "AutoRescueEaten",
	Flag = false,
})

local combatSection = ui:CreateSection("Combat Suite")
combatSection:createToggle({
	Name = "Auto Clean Slime",
	flagName = "AutoCleanSlime",
	Flag = false,
})
combatSection:createToggle({
	Name = "Auto Extinguish Fires",
	flagName = "AutoExtinguishFires",
	Flag = false,
})
combatSection:createToggle({
	Name = "Auto Fight Anomalies/Ghosts",
	flagName = "AutoFightAnomalies",
	Flag = false,
})
combatSection:createToggle({
	Name = "Zombie Aura",
	flagName = "ZombieAura",
	Flag = false,
})
combatSection:createSlider({
	Name = "Combat Range",
	flagName = "CombatRange",
	value = 25,
	minValue = 10,
	maxValue = 100,
})

local taserSection = ui:CreateSection("Taser Controls")
taserSection:createToggle({
	Name = "Auto Tase Critical",
	flagName = "AutoTaseCritical",
	Flag = false,
})
taserSection:createDropdown({
	Name = "Tase Critical Room",
	flagName = "TaseCriticalRoom",
	Flag = "All",
	List = { "All", "Room6", "Room7", "Room8" },
	multi = false,
})
taserSection:createToggle({
	Name = "Infinite Tase All",
	flagName = "InfiniteTaseAll",
	Flag = false,
})
taserSection:createToggle({
	Name = "Auto Tase Monsters (Tool)",
	flagName = "AutoTaseMonsters",
	Flag = false,
})

local teleportSection = ui:CreateSection("Teleports")
teleportSection:createDropdown({
	Name = "Destination",
	flagName = "TeleportDestination",
	Flag = "Medical Room 1",
	List = TELEPORT_DESTINATIONS,
	multi = false,
})
teleportSection:createButton({
	Name = "Teleport Now",
	Callback = function()
		tryTeleport(Library.Flags["TeleportDestination"] or "Medical Room 1")
	end,
})

local monsterSection = ui:CreateSection("Monster Defense")
monsterSection:createToggle({
	Name = "Bed Monster Syrup",
	flagName = "BedMonsterSyrup",
	Flag = false,
})
monsterSection:createToggle({
	Name = "Head Banger (Give Coffee)",
	flagName = "AutoHeadBanger",
	Flag = false,
})
monsterSection:createToggle({
	Name = "Ceiling Eyes (Look Down)",
	flagName = "CeilingEyes",
	Flag = false,
})
monsterSection:createToggle({
	Name = "Skinwalker Escape (Press E)",
	flagName = "SkinwalkerEscape",
	Flag = false,
})
monsterSection:createToggle({
	Name = "CCTV Auto Exit",
	flagName = "CCTVExit",
	Flag = false,
})
monsterSection:createToggle({
	Name = "Auto Fix Fuses",
	flagName = "AutoFuses",
	Flag = false,
})
monsterSection:createToggle({
	Name = "Auto Shop Upgrades",
	flagName = "AutoShopUpgrades",
	Flag = false,
})
monsterSection:createDropdown({
	Name = "Shop Upgrade Category",
	flagName = "ShopUpgradeCategory",
	Flag = "BuyCapacity",
	List = { "BuyCapacity", "BuyDNASpeed", "BuyGiveInventory", "BuyCheckIn", "BuyConsumables" },
	multi = false,
})

local itemsSection = ui:CreateSection("Items & Cabinet")
itemsSection:createToggle({
	Name = "Auto Buy Cabinet Items",
	flagName = "AutoBuyItems",
	Flag = false,
})
itemsSection:createDropdown({
	Name = "Cabinet Item Name",
	flagName = "AutoBuyItemName",
	Flag = "Eye Drops",
	List = {
		"Eye Drops",
		"IV Drops",
		"Thermo",
		"Medkit",
		"Bandages",
		"Herbs",
		"Medicine",
		"Ointment",
		"Cough Syrup",
		"Maple Syrup",
		"Coffee",
		"Chocolate (60% Sanity)",
	},
	multi = false,
})
itemsSection:createToggle({
	Name = "Auto Trash (Full)",
	flagName = "AutoTrash",
	Flag = false,
})
itemsSection:createToggle({
	Name = "Instant Proximity Prompts",
	flagName = "InstantPP",
	Flag = false,
})

local survivalSection = ui:CreateSection("Survival Kit")
survivalSection:createDropdown({
	Name = "Sanity Exploit Mode",
	flagName = "SanityMode",
	Flag = "Silent Local Hook",
	List = { "Silent Local Hook", "Server NaN Exploit", "Disabled" },
	multi = false,
})
survivalSection:createToggle({
	Name = "Auto Drink Coffee (Low Sanity)",
	flagName = "AutoDrinkCoffee",
	Flag = false,
})
survivalSection:createToggle({
	Name = "Auto Skip Cutscenes",
	flagName = "AutoSkipCutscenes",
	Flag = false,
})
survivalSection:createToggle({
	Name = "Anti-Jumpscare popups",
	flagName = "AntiJumpscare",
	Flag = false,
})
survivalSection:createToggle({
	Name = "Auto Revive Teammates",
	flagName = "AutoRevive",
	Flag = false,
})
survivalSection:createToggle({
	Name = "Coin Farm",
	flagName = "CoinFarm",
	Flag = false,
})
survivalSection:createToggle({
	Name = "Infinite Lives (Break Game)",
	flagName = "InfiniteLives",
	Flag = false,
})

local playerSection = ui:CreateSection("Player Movements")
playerSection:createSlider({
	Name = "WalkSpeed",
	flagName = "WalkSpeed",
	value = 16,
	minValue = 16,
	maxValue = 250,
})
playerSection:createSlider({
	Name = "JumpPower",
	flagName = "JumpPower",
	value = 50,
	minValue = 50,
	maxValue = 200,
})
playerSection:createSlider({
	Name = "Fly Speed",
	flagName = "FlySpeed",
	value = 50,
	minValue = 10,
	maxValue = 200,
})
playerSection:createToggle({
	Name = "Fly Enabled",
	flagName = "Fly",
	Flag = false,
	Callback = function(e)
		toggleFly(e)
	end,
})
playerSection:createToggle({
	Name = "Noclip Enabled",
	flagName = "Noclip",
	Flag = false,
	Callback = function(e)
		toggleNoclip(e)
	end,
})
playerSection:createDropdown({
	Name = "Camera View",
	flagName = "CameraMode",
	Flag = "Normal",
	List = { "Normal", "First Person Locked", "Third Person" },
	multi = false,
	Callback = function(v)
		setCameraMode(v)
	end,
})

local visualSection = ui:CreateSection("Visuals ESP")
visualSection:createToggle({
	Name = "ESP Master Toggle",
	flagName = "ESPEnabled",
	Flag = false,
})
visualSection:createToggle({
	Name = "ESP Show Labels",
	flagName = "ESPShowNames",
	Flag = false,
})
visualSection:createToggle({
	Name = "ESP Players",
	flagName = "ESPPlayers",
	Flag = false,
})
visualSection:createToggle({
	Name = "ESP Patients",
	flagName = "ESPPatients",
	Flag = false,
})
visualSection:createToggle({
	Name = "ESP Anomalies/Skinwalkers",
	flagName = "ESPAnomalies",
	Flag = false,
})
visualSection:createToggle({
	Name = "ESP Monsters (Hazards)",
	flagName = "ESPMonsters",
	Flag = false,
})

local serverSection = ui:CreateSection("Server Utilities")
serverSection:createButton({
	Name = "Save Config",
	Callback = function()
		saveFlags()
	end,
})
serverSection:createButton({
	Name = "Load Config",
	Callback = function()
		loadFlags()
	end,
})
serverSection:createButton({
	Name = "Rejoin Server",
	Callback = function()
		rejoinServer()
		notify("Server", "Rejoining...")
	end,
})
serverSection:createButton({
	Name = "Server Hop",
	Callback = function()
		serverHop()
		notify("Server", "Hopping...")
	end,
})
if IS_LOBBY then
	serverSection:createButton({
		Name = "Quick Start",
		Callback = function()
			fireRemote("RE/Quickstart")
			task.wait(2)
			TeleportService:Teleport(MAIN_ID, client)
		end,
	})
end
if IS_MAIN then
	serverSection:createButton({
		Name = "Teleport to Lobby",
		Callback = function()
			fireRemote("RE/TeleportToLobby")
		end,
	})
end

local debugSection = ui:CreateSection("System Diagnostics")
debugSection:createToggle({
	Name = "Log System Actions",
	flagName = "DebugMode",
	Flag = false,
})
debugSection:createToggle({
	Name = "Auto Heartbeat Minigame",
	flagName = "AutoHeartbeat",
	Flag = false,
})
debugSection:createButton({
	Name = "Print Session Statistics",
	Callback = function()
		notify(
			"Session Stats",
			string.format(
				"Healed: %d | Rejected: %d | Anomalies Slain: %d",
				State.SessionHealed,
				State.SessionRejected,
				State.SessionKilled
			)
		)
	end,
})
debugSection:createButton({
	Name = "Show Active Objective",
	Callback = function()
		local obj = State.CurrentObjective or "(none)"
		local tname = "(none)"
		pcall(function()
			tname = State.CurrentTarget and State.CurrentTarget.Name or "(none)"
		end)
		notify("Objective", "Text: " .. obj .. " | Target: " .. tname)
	end,
})

-----------------------------------------------------------------
-- RUNTIME SCHEDULER & ENGINE LOOPS
-----------------------------------------------------------------

PromptCache:Start()
MonsterCache:Start()
setupSanityHook()
setupJumpscareBypass()
setupShopTagHook()
hookServerEvents()
if not State.ConfigLoaded then
	loadFlags()
end

-- Continuous 50-second NaN freeze trigger (Active Server exploit mode)
task.spawn(function()
	while task.wait(50) do
		triggerServerNaNFreeze()
	end
end)

-- Main high-performance in-game loop.
-- Runs when ANY of its flags is enabled, so each toggle works independently.
interval(
	"autofarm",
	{ "AutoFarm", "AutoCheckIn", "VisitorFlow", "RoomTreatment", "EmergencyRooms", "AutoShift", "CarryFainted", "PutOutFire", "AvoidEyeMass", "FixCams", "TakeDNA", "HelpLiz", "AutoBuyItems", "AutoTrash", "AutoTaseCritical", "InfiniteTaseAll", "CoinFarm", "InfiniteLives", "AutoRevive", "InstantPP", "AutoBlowCandles", "AutoOpenSafes", "AutoCleanSlime", "AutoExtinguishFires", "AutoFightAnomalies", "ZombieAura", "AutoShopUpgrades", "AutoSkipDialogue", "AutoRescueEaten" },
	0.75,
	function()
		-- 1. Follow Core Game Directive (Priority 1)
		if Library.Flags["AutoFarm"] and followObjective() then
			return
		end

		-- 3. New Patient Check-In & Registration (Priority 2)
		if Library.Flags["AutoCheckIn"] and scanIdentity() then
			return
		end
		if Library.Flags["VisitorFlow"] and handleVisitorFlow() then
			return
		end

		-- 4. Admitted Patient Treatment (Priority 3)
		if Library.Flags["RoomTreatment"] then
			if handleRoomTreatment() then
				return
			end
		end

		-- 5. Emergency & Ambulance Rooms (Priority 4)
		if Library.Flags["EmergencyRooms"] then
			if handleEmergency() then
				return
			end
		end

		-- 6. General QoL Subsystems & Exploits (Priority 5)
		startShift()
		handleFainted()
		handlePeopleOnFire()
		handleEyeMass()
		handleFixCams()
		handleFuses()
		handleShopUpgrades()
		handleTakeDNA()
		helpLiz()
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
		skipDialogue()
		autoRescueEaten()
	end
)

-- Safety loop: runs when ANY monster-defense toggle is enabled
interval("safety", { "AvoidMonsters", "StalkerHandler", "BedMonsterSyrup", "CeilingEyes", "SkinwalkerEscape", "CCTVExit", "AutoTaseMonsters" }, 0.5, function()
	fleeMonsters()
	stalkerHandler()
	handleBedMonster()
	handleCeilingEyes()
	handleSkinwalkerEscape()
	handleCCTVExit()
	handleTaseMonsters()
end)

interval("coffee", "AutoDrinkCoffee", 2, drinkCoffeeIfNeeded)

interval("fuses", "AutoFuses", 4, handleFuses)

interval("banger", "AutoHeadBanger", 3, handleHeadBanger)

interval("heartbeat", "AutoHeartbeat", 2, handleHeartbeatFallback)

interval("cutscene", "AutoSkipCutscenes", 0.5, handleCutsceneSkip)

-- Sanity clamp: the game's 50s "Job Stress" drain calls the captured
-- LocalLoseSanity closure directly, bypassing the Lib hook. Force the local
-- attribute back to 100 so Silent mode actually keeps sanity full.
interval("sanityclamp", "SanityMode", 1, function()
	if Library.Flags["SanityMode"] == "Silent Local Hook" then
		pcall(function()
			if client:GetAttribute("Sanity") ~= 100 then
				client:SetAttribute("Sanity", 100)
			end
		end)
	end
end)

interval("movement", "WalkSpeed", 0.1, applyMovement)
interval("esp", "ESPEnabled", 1.8, updateESP)
interval("camera", "CameraMode", 0.5, function()
	local mode = Library.Flags["CameraMode"]
	setCameraMode(mode)
end)

local charConn = client.CharacterAdded:Connect(function()
	task.wait(0.6)
	if Library and Library.Flags and Library.Flags["Fly"] then
		toggleFly(true)
	end
	if Library and Library.Flags and Library.Flags["Noclip"] then
		toggleNoclip(true)
	end
end)
GlobalJanitor:Add(charConn)

notify("Versus Airlines Ultra", "In-Game Autopilot LOADED - " .. PLACE)
print("[Versus Airlines Ultra] Autopilot active. All game loops secured.")
