--services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")

--constants
local client = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local LOBBY_ID = 78515283254292
local MAIN_ID = 104522435597696
local IS_LOBBY = game.PlaceId == LOBBY_ID
local IS_MAIN = game.PlaceId == MAIN_ID
local PLACE = IS_LOBBY and "Lobby" or (IS_MAIN and "Main Game" or "?")
local DESK_POS = Vector3.new(-92, 3, 3)
local GAME_CENTER = Vector3.new(-92, 0, 3)
local GAME_RADIUS = 300

--PP ActionText constants
local AT = {
	ScanIdentity = "Scan Identity",
	ApplyTreatment = "Apply Treatment",
	Inspect = "Inspect",
	ProcessResults = "Process Results",
	AnalyzeSample = "Analyze Sample",
	Register = "Register",
	PrintBadge = "Print Badge",
	Collect = "Collect",
	PreparePatient = "Prepare Patient",
	Begin = "Begin",
	BeginXRay = "Begin X-Ray",
	SetUp = "Set Up",
	TurnOn = "Turn On",
	TakePhoto = "Take Photo",
	Take = "Take",
	StampForms = "Stamp Forms",
	SecurityCams = "Security Cams",
	Talk = "Talk",
	JumpscareAll = "Jumpscare All",
}

--WHITELIST: only these ActionTexts are auto-fired by the pipeline
local WORKFLOW_AT = {
	["Scan Identity"] = true,
	["Take Photo"] = true,
	["Print Badge"] = true,
	["Take"] = true,
	["Register"] = true,
	["Analyze Sample"] = true,
	["Inspect"] = true,
	["Process Results"] = true,
	["Begin X-Ray"] = true,
	["Collect"] = true,
	["Set Up"] = true,
	["Turn On"] = true,
	["Begin"] = true,
	["Prepare Patient"] = true,
	["Apply Treatment"] = true,
	["Stamp Forms"] = true,
	["Security Cams"] = true,
}

--monster tags + name patterns
local MONSTER_TAGS = {"Shadow", "TallMonsterHead", "TallMonsterSpawn", "Zombie", "Skinwalker", "StalkerJumpscare"}
local MONSTER_NAMES = {
	"shadow", "eyemass", "tallmonster", "monsterbed", "hider", "ghost",
	"skinwalker", "zombie", "candles", "stalker", "hollow",
}

--wait
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

--library
local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
local ui = Library:Setup({ Location = CoreGui, OpenCloseLocation = "Top Center" })

--anti idle
client.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
	task.wait(1); VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
end)

--game lib
local Lib = require(ReplicatedStorage:WaitForChild("Lib"))

--notify
local function nfy(t, d, s)
	Library:createDisplayMessage(t, d, {{ text = "OK" }}, s or "info")
end

--network helpers
local function netFire(name, ...)
	local args = {...}
	pcall(function() Lib.Network:FireServer(name, table.unpack(args)) end)
end

--direct remote finder — bypasses Lib.Network:Connect wrapper for reliability
local NetModule
local function getNetModule()
	if NetModule and NetModule.Parent then return NetModule end
	local util = ReplicatedStorage:FindFirstChild("Util")
	if not util then
		util = ReplicatedStorage:WaitForChild("Util", 10)
	end
	if util then
		NetModule = util:FindFirstChild("Net") or util:WaitForChild("Net", 10)
	end
	return NetModule
end
local function getRemote(name)
	local net = getNetModule()
	if not net then return nil end
	local rn = "RE/" .. name
	return net:FindFirstChild(rn) or net:WaitForChild(rn, 10)
end
local function directConnect(name, callback)
	local remote = getRemote(name)
	if remote then
		remote.OnClientEvent:Connect(callback)
		if Library.Flags and Library.Flags["DebugMode"] then
			print("[Net] Directly connected to RE/" .. name)
		end
		return true
	end
	if Library.Flags and Library.Flags["DebugMode"] then
		warn("[Net] Failed to find RE/" .. name)
	end
	return false
end

--character helpers
local function gChar()
	return client.Character or client.CharacterAdded:Wait()
end
local function gRoot()
	local c = gChar()
	return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
end
local function gHum()
	return gChar():FindFirstChildOfClass("Humanoid")
end

--game area filter
local function inGameArea(pos)
	return pos and (pos - GAME_CENTER).Magnitude < GAME_RADIUS
end
local function getPPPos(p)
	if p.Parent:IsA("BasePart") then return p.Parent.Position end
	if p.Parent:IsA("Model") then
		local pt = p.Parent:FindFirstChild("HumanoidRootPart") or p.Parent:FindFirstChildOfClass("BasePart")
		if pt then return pt.Position end
		return p.Parent:GetPivot().Position
	end
	return nil
end
local function getInstPos(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local pt = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildOfClass("BasePart")
		if pt then return pt.Position end
		return inst:GetPivot().Position
	end
	return nil
end

--movement
local SAFE_Y = -10
local function tp(pos)
	local r = gRoot()
	if r then
		local yPos = pos.Y
		if yPos < SAFE_Y then yPos = 3 end
		r.CFrame = CFrame.new(pos.X, yPos + 3, pos.Z)
	end
end
local function walk(pos, t)
	t = t or 8; local h = gHum(); local r = gRoot()
	if not h or not r then return end
	h:MoveTo(pos); local s = tick()
	while tick() - s < t do
		task.wait(0.1)
		if not r or not r.Parent then return end
		if (r.Position - pos).Magnitude < 5 then break end
	end
	h:MoveTo(nil)
end
local function move(pos)
	if Library.Flags and Library.Flags["WalkMode"] then walk(pos) else tp(pos) end
end

--NPC helpers
local function getNPCsFolder()
	return Workspace:FindFirstChild("NPCs")
end
local function getNPCs()
	local list = {}
	local f = getNPCsFolder()
	if f then
		for _, v in ipairs(f:GetChildren()) do
			if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
				table.insert(list, v)
			end
		end
		if #list > 0 then return list end
	end
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(v) then
			table.insert(list, v)
		end
	end
	return list
end

--monster helpers
local function getMonsters()
	local list = {}; local seen = {}
	for _, tag in ipairs(MONSTER_TAGS) do
		for _, v in ipairs(CollectionService:GetTagged(tag)) do
			if v:IsA("Model") and not seen[v] then seen[v] = true; table.insert(list, v) end
		end
	end
	for _, v in ipairs(getNPCs()) do
		if not seen[v] then
			local n = v.Name:lower()
			for _, pattern in ipairs(MONSTER_NAMES) do
				if n:find(pattern) then seen[v] = true; table.insert(list, v); break end
			end
		end
	end
	return list
end

--PP finders — only find ENABLED PPs in the whitelist
local function findPP(at)
	for _, p in ipairs(Workspace:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == at then
			local ppos = getPPPos(p)
			if ppos and inGameArea(ppos) then return p end
		end
	end
	return nil
end
local function findNearestWorkflowPP()
	local r = gRoot(); if not r then return nil end
	local closest, closestDist, closestModel = nil, math.huge, nil
	for _, p in ipairs(Workspace:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText ~= "" and WORKFLOW_AT[p.ActionText] then
			local ppos = getPPPos(p)
			if ppos and inGameArea(ppos) then
				local d = (r.Position - ppos).Magnitude
				if d < closestDist then
					closestDist = d; closest = p
					closestModel = p:FindFirstAncestorWhichIsA("Model") or p.Parent
				end
			end
		end
	end
	return closest, closestModel
end

--interaction
local function firePP(pp)
	local ok = pcall(fireproximityprompt, pp)
	if not ok then
		pcall(function() pp:InputPerformed(Enum.UserInputType.Keyboard) end)
	end
	return ok
end
local function interactPP(pp, model)
	if not pp or not pp:IsA("ProximityPrompt") or not pp.Enabled then return false end
	local pos = model and getInstPos(model) or getPPPos(pp)
	if pos and inGameArea(pos) then
		tp(pos)
		task.wait(0.2)
		local r = gRoot()
		if r and (r.Position - pos).Magnitude > 8 then
			r.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z)
			task.wait(0.15)
		end
	end
	return firePP(pp)
end

--find and fire an enabled PP on or near a target instance
local function findAndFirePP(target)
	if not target then return false end
	-- search target's children for an ENABLED PP
	local pp = nil
	for _, d in ipairs(target:GetChildren()) do
		if d:IsA("ProximityPrompt") and d.Enabled then pp = d; break end
	end
	-- search descendants if not found
	if not pp then
		for _, d in ipairs(target:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled then pp = d; break end
		end
	end
	if pp then
		return interactPP(pp, target)
	end
	-- no enabled PP found — TP to target and wait for PP to enable
	local pos = getInstPos(target)
	if pos then
		move(pos)
		task.wait(0.3)
		-- retry after TP
		for _, d in ipairs(target:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled then
				return interactPP(d, target)
			end
		end
	end
	return false
end

--objective tracking — THE KEY SYSTEM
-- server fires RE/SetObjective with (text, nil, targetInstance) or similar
local currentObjective = nil
local currentTarget = nil
local lastObjectiveTime = 0
local function hookObjectives()
	local connected = directConnect("SetObjective", function(...)
		local args = {...}
		-- handle both varargs and single-table formats
		local text, target
		if type(args[1]) == "table" then
			-- single table argument
			text = args[1][1]
			target = args[1][3]
		else
			-- varargs
			text = args[1]
			target = args[3]
		end
		if type(text) == "string" and text ~= "" then
			currentObjective = text
			currentTarget = target
			lastObjectiveTime = tick()
			if Library.Flags and Library.Flags["DebugMode"] then
				print("[Objective]", text, "| target:", target and (target.Name or "?") or "none")
			end
		else
			-- empty objective = step complete, wait for next
			if Library.Flags and Library.Flags["DebugMode"] then
				print("[Objective] cleared")
			end
		end
	end)
	if not connected then
		-- fallback: try Lib.Network:Connect
		pcall(function() Lib.Network:Connect("SetObjective", function(...)
			local args = {...}
			local text, target
			if type(args[1]) == "table" then
				text = args[1][1]; target = args[1][3]
			else
				text = args[1]; target = args[3]
			end
			if type(text) == "string" and text ~= "" then
				currentObjective = text
				currentTarget = target
				lastObjectiveTime = tick()
			end
		end) end)
	end
end

--cutscene hook
local function hookCutscenes()
	directConnect("PlayCutscene", function(name, ...)
		if Library.Flags and Library.Flags["DebugMode"] then
			print("[Cutscene]", name, ...)
		end
		if name == "ThreePatientsDiedEnding" and Library.Flags and Library.Flags["AutoReplay"] then
			task.wait(3)
			netFire("PlayAgainVote")
		end
	end)
end

--shift end detection
local function hookShiftEnd()
	directConnect("DisplayRoundStats", function()
		if Library.Flags and Library.Flags["DebugMode"] then print("[Shift] Round stats displayed") end
		if Library.Flags and Library.Flags["AutoReplay"] then
			local delay = Library.Flags["ShiftBeforeReset"] or 0
			task.wait(delay)
			netFire("PlayAgainVote")
			nfy("Auto Replay", "Voted play again", "info")
		end
	end)
end
--game over tag watcher
task.spawn(function()
	while true do
		task.wait(2)
		if Library.Flags and Library.Flags["AutoReplay"] then
			if game.Players:HasTag("GameOverWith3Deaths") or game.Players:HasTag("GameOver") then
				netFire("PlayAgainVote")
				task.wait(5)
			end
		end
	end
end)

--reactive tasks
local function doAvoid()
	local r = gRoot(); if not r then return end
	for _, v in ipairs(getMonsters()) do
		local p = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso") or v:FindFirstChildOfClass("BasePart")
		if p and (r.Position - p.Position).Magnitude < 35 then
			tp(r.Position + (r.Position - p.Position).Unit * 80)
			return
		end
	end
end
local function doSlime()
	local r = gRoot(); if not r then return end
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("BasePart") and (v.Name:lower():find("slime") or v.Name:lower():find("grime")) then
			if inGameArea(v.Position) and (r.Position - v.Position).Magnitude < 80 then
				move(v.Position); task.wait(0.3)
				netFire("ExtinguisherBubbleHitGrime", v)
				task.wait(1); return
			end
		end
	end
end
local function doFire()
	local r = gRoot(); if not r then return end
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("BasePart") and v.Name:lower():find("fire") then
			if inGameArea(v.Position) and (r.Position - v.Position).Magnitude < 80 then
				move(v.Position); task.wait(0.3)
				netFire("ExtinguisherBubbleHit", v)
				task.wait(1); return
			end
		end
	end
	for _, c2 in ipairs(Workspace:GetDescendants()) do
		if c2:IsA("Model") and c2:FindFirstChildOfClass("Humanoid") and c2:FindFirstChild("Fire") then
			local p = c2:FindFirstChild("HumanoidRootPart") or c2:FindFirstChild("Torso")
			if p and inGameArea(p.Position) and (r.Position - p.Position).Magnitude < 80 then
				move(p.Position); task.wait(0.3)
				netFire("ExtinguisherBubbleHitFireNPC", c2)
				task.wait(1); return
			end
		end
	end
end
local function doTreatFire()
	local r = gRoot(); if not r then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= client and plr.Character then
			local c2 = plr.Character
			local p = c2:FindFirstChild("HumanoidRootPart") or c2:FindFirstChild("Torso")
			if p and c2:FindFirstChild("Fire") and (r.Position - p.Position).Magnitude < 80 then
				local pp = c2:FindFirstChild("PP") or c2:FindFirstChildWhichIsA("ProximityPrompt")
				if pp then interactPP(pp, c2) else move(p.Position) end
				task.wait(1); return
			end
		end
	end
end
local function doFix()
	local r = gRoot(); if not r then return end
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("Model") and v.Name:lower():find("camera") then
			local pp = v:FindFirstChild("PP") or v:FindFirstChildWhichIsA("ProximityPrompt")
			local bp = v:FindFirstChildWhichIsA("BasePart")
			if bp and pp and inGameArea(bp.Position) and (r.Position - bp.Position).Magnitude < 100 then
				interactPP(pp, v); task.wait(2); return
			end
		end
	end
end

--auto play lobby
local lobbyPlayC
local function startLobbyPlay()
	if not IS_LOBBY then return end
	if lobbyPlayC then lobbyPlayC:Disconnect(); lobbyPlayC = nil end
	lobbyPlayC = RunService.Heartbeat:Connect(function()
		if not Library.Flags or not Library.Flags["AutoPlay"] then
			if lobbyPlayC then lobbyPlayC:Disconnect(); lobbyPlayC = nil end; return
		end
		if game.PlaceId ~= LOBBY_ID then
			if lobbyPlayC then lobbyPlayC:Disconnect(); lobbyPlayC = nil end; return
		end
		netFire("Quickstart")
		task.wait(3)
		if game.PlaceId == LOBBY_ID then
			TeleportService:Teleport(MAIN_ID, client)
			task.wait(5)
		end
	end)
end

--ESP
local espHolders = {}
local function clearESP()
	for _, h in ipairs(espHolders) do pcall(h.Destroy, h) end
	espHolders = {}
end
local function addESP(obj, color)
	local h = Instance.new("Highlight")
	h.FillColor = color; h.FillTransparency = 0.5
	h.OutlineColor = color; h.OutlineTransparency = 0
	h.Adornee = obj; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = CoreGui; table.insert(espHolders, h)
end
local function doESP()
	if not Library.Flags or not Library.Flags["ESPEnabled"] then clearESP(); return end
	clearESP()
	if Library.Flags["ESPPlayers"] then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= client and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
				addESP(plr.Character, Color3.fromRGB(0, 170, 255))
			end
		end
	end
	local f = getNPCsFolder()
	if Library.Flags["ESPPatients"] and f then
		for _, v in ipairs(f:GetChildren()) do
			if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
				local pp = v:FindFirstChild("PP")
				if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
					addESP(v, Color3.fromRGB(0, 255, 0))
				end
			end
		end
	end
	if Library.Flags["ESPNPCs"] then
		for _, v in ipairs(getNPCs()) do
			local found = false
			for _, h in ipairs(espHolders) do if h.Adornee == v then found = true; break end end
			if not found then addESP(v, Color3.fromRGB(255, 200, 0)) end
		end
	end
	if Library.Flags["ESPMonsters"] then
		for _, v in ipairs(getMonsters()) do addESP(v, Color3.fromRGB(255, 0, 0)) end
	end
end
local espThread
local function startESP()
	if espThread then return end
	espThread = task.spawn(function()
		while true do
			task.wait(0.5)
			if Library.Flags and Library.Flags["ESPEnabled"] then pcall(doESP) else clearESP(); break end
		end
		espThread = nil
	end)
end

--fly
local fBV, fBG, fConn
local function tFly(en)
	local r = gRoot(); local h = gHum()
	if not r or not h then return end
	if en then
		h.PlatformStand = true
		fBV = Instance.new("BodyVelocity"); fBV.MaxForce = Vector3.new(1,1,1)*10000; fBV.Parent = r
		fBG = Instance.new("BodyGyro"); fBG.MaxTorque = Vector3.new(1,1,1)*10000; fBG.CFrame = r.CFrame; fBG.P = 1000; fBG.Parent = r
		if fConn then fConn:Disconnect() end
		fConn = RunService.RenderStepped:Connect(function()
			if not Library.Flags or not Library.Flags["Fly"] then if fConn then fConn:Disconnect(); fConn=nil end; return end
			local rt = gRoot(); if not rt or not fBV then return end
			local spd = Library.Flags["FlySpeed"] or 50; local cf = camera.CFrame; local v = Vector3.new(0,0,0)
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then v = v + cf.LookVector * spd end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then v = v - cf.LookVector * spd end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then v = v - cf.RightVector * spd end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then v = v + cf.RightVector * spd end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v = v + Vector3.new(0,spd,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v = v - Vector3.new(0,spd,0) end
			fBV.Velocity = v; fBG.CFrame = cf
		end)
	else
		if fBV then fBV:Destroy(); fBV=nil end
		if fBG then fBG:Destroy(); fBG=nil end
		if fConn then fConn:Disconnect(); fConn=nil end
		h.PlatformStand = false
	end
end

--noclip
local ncC
local function tNc(en)
	if ncC then ncC:Disconnect(); ncC=nil end
	if en then
		pcall(function() sethiddenproperty(client, "SimulationRadius", math.huge) end)
		ncC = RunService.Stepped:Connect(function()
			if not Library.Flags or not Library.Flags["Noclip"] then if ncC then ncC:Disconnect(); ncC=nil end; return end
			for _, p in ipairs(gChar():GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end)
	end
end

--sanity (client is authoritative — just override the attribute)
local saC
local function tSa(en)
	if saC then saC:Disconnect(); saC=nil end
	if en then
		client:SetAttribute("Sanity", 100)
		saC = RunService.Heartbeat:Connect(function()
			if not Library.Flags or not Library.Flags["InfiniteSanity"] then if saC then saC:Disconnect(); saC=nil end; return end
			if client:GetAttribute("Sanity") ~= 100 then client:SetAttribute("Sanity", 100) end
		end)
	end
end

--camera
local function setCam(m)
	if m == "Classic" then
		camera.CameraType = Enum.CameraType.Custom
		local r = gRoot()
		if r then camera.CFrame = CFrame.new(r.Position + Vector3.new(0,5,10), r.Position) end
	elseif m == "LockFirstPerson" then
		camera.CameraType = Enum.CameraType.Attach
		local h = gChar():FindFirstChild("Head")
		if h then camera.CameraSubject = h end
	else
		camera.CameraType = Enum.CameraType.Custom
		local h = gHum()
		if h then camera.CameraSubject = h end
	end
end

--FPS booster
local fpsConn
local function tFPS(en)
	if en then
		pcall(function() settings().Rendering.QualityLevel = 1 end)
		for _, d in ipairs(Workspace:GetDescendants()) do
			pcall(function()
				if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then d.Enabled = false end
			end)
		end
		if fpsConn then fpsConn:Disconnect() end
		fpsConn = Workspace.DescendantAdded:Connect(function(d)
			if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then d.Enabled = false end
		end)
	else
		pcall(function() settings().Rendering.QualityLevel = 10 end)
		if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
	end
end

--walk speed
task.spawn(function()
	while task.wait(1) do
		local h = gHum()
		if h and Library.Flags and Library.Flags["WalkSpeed"] and Library.Flags["WalkSpeed"] ~= 16 then
			h.WalkSpeed = Library.Flags["WalkSpeed"]
			h.JumpPower = Library.Flags["JumpPower"] or 50
		end
	end
end)

--anti void — TP back to desk if falling
task.spawn(function()
	while task.wait(0.5) do
		local r = gRoot()
		if r then
			local p = r.Position
			if p.Y < SAFE_Y then
				r.CFrame = CFrame.new(DESK_POS + Vector3.new(0, 3, 0))
				if Library.Flags and Library.Flags["DebugMode"] then
					print("[AntiVoid] Caught fall at Y=" .. math.floor(p.Y))
				end
			end
		end
	end
end)

--reactive heartbeat
local reactiveC
local function startReactive()
	if reactiveC then return end
	reactiveC = RunService.Heartbeat:Connect(function()
		if not Library.Flags or not Library.Flags["AutoEnabled"] then return end
		local r = gRoot()
		if not r then return end
		if Library.Flags["AutoAvoidSkinWalkers"] then pcall(doAvoid) end
		if Library.Flags["AvoidSlime"] then pcall(doSlime) end
		if Library.Flags["PutOutFire"] then pcall(doFire) end
		if Library.Flags["TreatFirePerson"] then pcall(doTreatFire) end
		if Library.Flags["FixCams"] then pcall(doFix) end
	end)
end
local function stopReactive()
	if reactiveC then reactiveC:Disconnect(); reactiveC = nil end
end

--pipeline — follows the objective system + fallback to scanning for enabled PPs
local pipelineActive = false
local function pipelineLoop()
	pipelineActive = true
	if Library.Flags and Library.Flags["DebugMode"] then
		print("[Pipeline] Started")
	end
	while Library.Flags and Library.Flags["AutoEnabled"] and pipelineActive do
		local didSomething = false

		-- 1. If we have an objective target from SetObjective, TP to it and fire its PP
		if currentTarget then
			if Library.Flags and Library.Flags["DebugMode"] then
				print("[Pipeline] Following target:", currentTarget.Name or "?", "obj:", currentObjective or "?")
			end
			findAndFirePP(currentTarget)
			didSomething = true
			task.wait(1)

		-- 2. If we have an objective text but no target, find nearest enabled workflow PP
		elseif currentObjective then
			if Library.Flags and Library.Flags["DebugMode"] then
				print("[Pipeline] Objective without target:", currentObjective)
			end
			local pp, model = findNearestWorkflowPP()
			if pp then
				interactPP(pp, model)
				didSomething = true
			end
			task.wait(1)

		-- 3. No objective — try to start the chain by scanning identity at desk
		else
			-- First check if any workflow PP is enabled (game might have enabled one)
			local pp, model = findNearestWorkflowPP()
			if pp then
				if Library.Flags and Library.Flags["DebugMode"] then
					print("[Pipeline] Found enabled workflow PP:", pp.ActionText)
				end
				interactPP(pp, model)
				didSomething = true
				task.wait(1)
			else
				-- No workflow PP enabled — go to desk and scan identity
				if Library.Flags and Library.Flags["AutoFrontDesk"] then
					if Library.Flags and Library.Flags["DebugMode"] then
						print("[Pipeline] No objective, going to desk")
					end
					local scanPP = findPP("Scan Identity")
					if scanPP then
						interactPP(scanPP)
						didSomething = true
					else
						move(DESK_POS)
					end
					task.wait(1.5)
				else
					task.wait(1)
				end
			end
		end
	end
	if Library.Flags and Library.Flags["DebugMode"] then
		print("[Pipeline] Stopped")
	end
	pipelineActive = false
end
local function startPipeline()
	pipelineActive = false
	task.spawn(pipelineLoop)
end

--teleport hook
client.OnTeleport:Connect(function(state)
	if state == Enum.TeleportState.Finished then
		task.wait(3)
		if IS_MAIN then hookObjectives(); hookCutscenes(); hookShiftEnd() end
	end
end)

--UI
local ms = ui:CreateSection("Animal Hospital")
ms:createLabel({ Name = "Animal Hospital", Special = true })
ms:createLabel({ Name = "[ " .. PLACE .. " ]", Center = true, Bold = true })
if IS_LOBBY then
	ms:createButton({
		Name = "Quick Join",
		Callback = function()
			netFire("Quickstart")
			task.wait(2)
			if game.PlaceId == LOBBY_ID then TeleportService:Teleport(MAIN_ID, client) end
		end
	})
	ms:createButton({ Name = "Teleport to Main Game", Callback = function() TeleportService:Teleport(MAIN_ID, client) end })
	ms:createToggle({ Name = "Auto Play Lobby", flagName = "AutoPlay", Flag = false, Callback = function(e) if e then startLobbyPlay() end end })
end
if IS_MAIN then
	ms:createButton({ Name = "Teleport to Lobby", Callback = function() netFire("TeleportToLobby") end })
end

if IS_MAIN then
	local aS = ui:CreateSection("Automation")
	aS:createLabel({ Name = "Master Automation", Special = true })
	aS:createToggle({
		Name = "Enable Automation", flagName = "AutoEnabled", Flag = false,
		Callback = function(e)
			if e then
				startReactive(); startPipeline()
				nfy("Auto", "Workflow started", "info")
			else
				pipelineActive = false; stopReactive()
				nfy("Auto", "Workflow stopped", "info")
			end
		end
	})
	aS:createLabel({ Name = "Follows game objectives + PP scanning", Center = true })
	aS:createLabel({ Name = "--- Auto ---", Center = true })
	aS:createToggle({ Name = "Auto Front Desk", flagName = "AutoFrontDesk", Flag = false })
	aS:createToggle({ Name = "Auto Replay", flagName = "AutoReplay", Flag = false })
	aS:createSlider({ Name = "Shift Before Reset (s)", flagName = "ShiftBeforeReset", value = 0, minValue = 0, maxValue = 10 })
	aS:createLabel({ Name = "--- Hazards ---", Center = true })
	aS:createToggle({ Name = "Auto Avoid Monsters", flagName = "AutoAvoidSkinWalkers", Flag = false })
	aS:createToggle({ Name = "Avoid Slime", flagName = "AvoidSlime", Flag = false })
	aS:createToggle({ Name = "Put Out Fire", flagName = "PutOutFire", Flag = false })
	aS:createToggle({ Name = "Treat Fire Person", flagName = "TreatFirePerson", Flag = false })
	aS:createToggle({ Name = "Fix Cams", flagName = "FixCams", Flag = false })
	aS:createLabel({ Name = "--- Recovery ---", Center = true })
	aS:createToggle({ Name = "Infinite Sanity", flagName = "InfiniteSanity", Flag = false, Callback = function(e) tSa(e) end })
	aS:createToggle({ Name = "FPS Booster", flagName = "FPSBooster", Flag = false, Callback = function(e) tFPS(e) end })
	aS:createLabel({ Name = "--- ESP ---", Center = true })
	aS:createToggle({ Name = "ESP Enabled", flagName = "ESPEnabled", Flag = false, Callback = function(e) if e then startESP() else clearESP() end end })
	aS:createToggle({ Name = "ESP Players", flagName = "ESPPlayers", Flag = false })
	aS:createToggle({ Name = "ESP Patients", flagName = "ESPPatients", Flag = false })
	aS:createToggle({ Name = "ESP NPCs", flagName = "ESPNPCs", Flag = false })
	aS:createToggle({ Name = "ESP Monsters", flagName = "ESPMonsters", Flag = false })

	local pS = ui:CreateSection("Player")
	pS:createSlider({ Name = "WalkSpeed", flagName = "WalkSpeed", value = 16, minValue = 16, maxValue = 250 })
	pS:createSlider({ Name = "JumpPower", flagName = "JumpPower", value = 50, minValue = 50, maxValue = 200 })
	pS:createToggle({ Name = "Walk Mode", flagName = "WalkMode", Flag = false })
	pS:createToggle({ Name = "Noclip", flagName = "Noclip", Flag = false, Callback = function(e) tNc(e) end })
	pS:createToggle({ Name = "Fly", flagName = "Fly", Flag = false, Callback = function(e) tFly(e) end })
	pS:createSlider({ Name = "Fly Speed", flagName = "FlySpeed", value = 50, minValue = 10, maxValue = 200 })
	pS:createDropdown({ Name = "Camera Mode", flagName = "CameraMode", Flag = "Default", List = {"Default", "Classic", "LockFirstPerson"}, multi = false, Callback = function(v) setCam(v) end })

	local dbS = ui:CreateSection("Debug")
	dbS:createToggle({ Name = "Debug Mode", flagName = "DebugMode", Flag = false })
	dbS:createButton({
		Name = "Discover PPs",
		Callback = function()
			local count = 0; local buf = {}
			for _, v in ipairs(Workspace:GetDescendants()) do
				if v:IsA("ProximityPrompt") then
					count = count + 1
					local par = v.Parent
					local parName = par:IsA("Model") and par.Name or (par:IsA("BasePart") and par.Name or "?")
					local line = string.format("[PP #%d] AT=%q OT=%q Name=%q P=%s E=%s",
						count, v.ActionText, v.ObjectText or "", v.Name, parName, tostring(v.Enabled))
					print(line); table.insert(buf, line)
				end
			end
			pcall(setclipboard, table.concat(buf, "\n"))
			nfy("PP Discovery", "Found " .. count .. " - copied to clipboard", "info")
		end
	})
	dbS:createButton({
		Name = "Test: Fire Nearest PP",
		Callback = function()
			local pp, model = findNearestWorkflowPP()
			if not pp then nfy("Test", "No enabled workflow PP found", "warning"); return end
			nfy("Test", "Firing PP | AT=" .. pp.ActionText, "info")
			interactPP(pp, model)
		end
	})
	dbS:createButton({
		Name = "Reconnect Objectives",
		Callback = function()
			hookObjectives()
			hookCutscenes()
			hookShiftEnd()
			nfy("Reconnect", "Objective hooks reconnected", "info")
		end
	})
	dbS:createButton({
		Name = "Show Current Objective",
		Callback = function()
			nfy("Objective", "Text: " .. (currentObjective or "(none)") .. " | Target: " .. (currentTarget and currentTarget.Name or "(none)"), "info")
		end
	})
	dbS:createLabel({ Name = "Keybinds: [F] Fly [B] Noclip [X] Sanity", Center = true })
end

--keybinds
UserInputService.InputBegan:Connect(function(inp, g)
	if g then return end
	if inp.KeyCode == Enum.KeyCode.B then
		Library.Flags["Noclip"] = not Library.Flags["Noclip"]
		tNc(Library.Flags["Noclip"])
		nfy("NoClip", Library.Flags["Noclip"] and "ON" or "OFF", "info")
	end
	if inp.KeyCode == Enum.KeyCode.F then
		Library.Flags["Fly"] = not Library.Flags["Fly"]
		tFly(Library.Flags["Fly"])
		nfy("Fly", Library.Flags["Fly"] and "ON" or "OFF", "info")
	end
	if inp.KeyCode == Enum.KeyCode.X then
		Library.Flags["InfiniteSanity"] = not Library.Flags["InfiniteSanity"]
		tSa(Library.Flags["InfiniteSanity"])
		nfy("Sanity", Library.Flags["InfiniteSanity"] and "ON" or "OFF", "info")
	end
end)

--init
if IS_MAIN then
	task.spawn(function()
		task.wait(1)
		hookObjectives()
		hookCutscenes()
		hookShiftEnd()
	end)
end

nfy("Animal Hospital", "Premium Hub loaded - " .. PLACE, "info")
print("==============================")
print(" Animal Hospital Premium Hub")
print(" " .. PLACE)
print("==============================")
