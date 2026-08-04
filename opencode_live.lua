-- opencode-live.lua — Deepseek AI assistant with NoTokenLimit-style GUI + tools
-- Uses the proven GUI and tool system from notokenlimit.com/exec-connector
-- AI backend: deepseek-v4-pro

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local client = Players.LocalPlayer

local DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
local DEEPSEEK_MODEL = "deepseek-v4-pro"
local CONFIG_FILE = "opencode_live_config.json"

local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request or request
    or (fluxus and fluxus.request)
    or (krnl and krnl.request)

local g_writefile = writefile
local g_readfile  = readfile

local function jencode(v)
    local ok, r = pcall(function() return HttpService:JSONEncode(v) end)
    return ok and r or "null"
end
local function jdecode(s)
    local ok, r = pcall(function() return HttpService:JSONDecode(s) end)
    if ok then return r end
    return nil
end

-- ================ Config ================
local ApiKey = ""
local ScriptContent = "-- Write Luau code here"

local function saveConfig()
    if not g_writefile then return end
    pcall(function()
        local c = ScriptContent
        if #c > 50000 then c = nil end
        g_writefile(CONFIG_FILE, jencode({ key = ApiKey, content = c }))
    end)
end

local function loadConfig()
    if not g_readfile then return end
    local ok, data = pcall(function() return jdecode(g_readfile(CONFIG_FILE)) end)
    if ok and data then
        if data.key then ApiKey = data.key end
        if data.content and #data.content < 50000 then ScriptContent = data.content end
    end
end
loadConfig()

-- ================ Tool handlers ================
local Ops = {}

function Ops.execute_luau(args)
    local code = args.code or args.source or ""
    local fn, cerr = loadstring(code)
    if not fn then return { ok = false, error = "compile: " .. tostring(cerr) } end
    local out = {}
    local function cap(prefix)
        return function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
            out[#out + 1] = prefix .. table.concat(parts, "\t")
        end
    end
    setfenv(fn, setmetatable({ print = cap(""), warn = cap("[warn] ") }, { __index = getfenv and getfenv() or _G }))
    local res = { pcall(fn) }
    local success = table.remove(res, 1)
    local returns = {}
    for i = 1, #res do returns[i] = tostring(res[i]) end
    return { ok = success, output = table.concat(out, "\n"), returns = returns,
        error = (not success) and tostring(res[1]) or nil }
end

function Ops.get_console(args)
    local limit = tonumber(args.limit or args.count) or 30
    local hist = LogService:GetLogHistory()
    local names = { [0] = "out", [1] = "info", [2] = "warn", [3] = "error" }
    local lines = {}
    for i = #hist, 1, -1 do
        local e = hist[i]
        local lvl = e.messageType and e.messageType.Value or 0
        table.insert(lines, 1, "[" .. (names[lvl] or "out") .. "] " .. tostring(e.message))
        if #lines >= limit then break end
    end
    return { lines = lines }
end

function Ops.search(args)
    local q = args.query and string.lower(args.query)
    local limit = math.min(tonumber(args.limit) or 30, 100)
    local results = {}
    for _, inst in ipairs(workspace:GetDescendants()) do
        if q and not string.find(string.lower(inst.Name), q, 1, true) then
            --
        else
            results[#results + 1] = inst:GetFullName()
            if #results >= limit then break end
        end
    end
    return { matches = results, truncated = #results >= limit }
end

function Ops.read_file(args)
    local name = args.name or args.path or ""
    if not g_readfile or name == "" then return { ok = false, error = "readfile not available" } end
    local ok, data = pcall(function() return g_readfile(name) end)
    if not ok then return { ok = false, error = "read failed" } end
    if #data > 50000 then data = string.sub(data, 1, 50000) .. "\n-- ...truncated" end
    return { source = data, name = name }
end

function Ops.write_file(args)
    local name = args.name or "live_script.lua"
    local content = args.source or args.content or ""
    if not g_writefile then return { ok = false, error = "writefile not available" } end
    pcall(function() g_writefile(name, content) end)
    return { ok = true, name = name }
end

function Ops.get_script_source(args)
    local inst = args.path and game:FindFirstChild(args.path, true)
    if not inst then return { ok = false, error = "not found" } end
    return { source = inst.Source or "", name = inst:GetFullName() }
end

function Ops.read_tree(args)
    local root = args.path and game:FindFirstChild(args.path, true) or workspace
    if not root then return { ok = false, error = "not found" } end
    local function walk(inst, d)
        local node = { name = inst.Name, class = inst.ClassName }
        if d > 0 then
            node.children = {}
            for _, ch in ipairs(inst:GetChildren()) do
                node.children[#node.children + 1] = walk(ch, d - 1)
            end
        end
        return node
    end
    return walk(root, math.min(tonumber(args.depth) or 2, 3))
end

function Ops.get_editor()
    return { source = ScriptContent }
end

function Ops.web_fetch(args)
    local url = args.url or args.query or ""
    if url == "" then return { ok = false, error = "no url provided" } end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then return { ok = false, error = "fetch failed: " .. tostring(body) } end
    if #body > 20000 then body = string.sub(body, 1, 20000) .. "\n-- TRUNCATED" end
    return { ok = true, content = body, length = #body }
end

function Ops.set_editor(args)
    ScriptContent = args.source or args.content or ""
    saveConfig()
    return { ok = true }
end

local function runTool(name, input)
    local handler = Ops[name]
    if not handler then return { ok = false, error = "unknown tool: " .. tostring(name) } end
    local ok, res = pcall(handler, input or {})
    if not ok then return { ok = false, error = "tool crashed: " .. tostring(res) } end
    return res
end

-- ================ Deepseek API ================
local function callDeepseek(messages)
    if ApiKey == "" then return nil, "No API key. Type /key YOUR_KEY to set it." end
    if not httpRequest then return nil, "No HTTP function on this executor" end

    local body = jencode({
        model = DEEPSEEK_MODEL,
        messages = messages,
        temperature = 0.3,
        max_tokens = 4096,
    })

    local ok, resp = pcall(httpRequest, {
        Url = DEEPSEEK_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. ApiKey,
        },
        Body = body,
    })

    if not ok or not resp then return nil, "HTTP request failed" end
    local bodyStr = type(resp) == "table" and (resp.Body or resp.body or tostring(resp)) or tostring(resp)
    local data = jdecode(bodyStr)
    if not data then return nil, "Invalid JSON response" end
    if data.error then return nil, "API: " .. tostring(data.error.message or data.error) end
    if not data.choices or not data.choices[1] then return nil, "Empty response" end
    return data.choices[1].message.content, nil
end

-- ================ GUI ================
local function hostGui()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end

-- Reopen-safe
pcall(function()
    local old = hostGui():FindFirstChild("OpenCodeLive")
    if old then old:Destroy() end
end)

local SG = Instance.new("ScreenGui")
SG.Name = "OpenCodeLive"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 9999
pcall(function() SG.Parent = hostGui() end)

local C = {
    bg = Color3.fromRGB(18, 18, 20), panel = Color3.fromRGB(28, 28, 32),
    accent = Color3.fromRGB(120, 90, 255), text = Color3.fromRGB(235, 235, 240),
    sub = Color3.fromRGB(150, 150, 160), me = Color3.fromRGB(40, 40, 48),
    green = Color3.fromRGB(50, 210, 100), red = Color3.fromRGB(230, 70, 70),
    yellow = Color3.fromRGB(255, 190, 50),
}

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(400, 500)
root.Position = UDim2.new(1, -420, 0, 60)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.Active = true
root.Draggable = true
root.Parent = SG
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)

-- Title bar
local bar = Instance.new("TextLabel")
bar.Size = UDim2.new(1, 0, 0, 34)
bar.BackgroundColor3 = C.panel
bar.BorderSizePixel = 0
bar.Font = Enum.Font.GothamBold
bar.TextSize = 14
bar.TextColor3 = C.text
bar.Text = "  opencode-live · deepseek-v4-pro"
bar.TextXAlignment = Enum.TextXAlignment.Left
bar.Parent = root
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(28, 28)
close.Position = UDim2.new(1, -32, 0, 3)
close.BackgroundColor3 = C.me
close.Text = "×"
close.TextColor3 = C.text
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.Parent = root
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
close.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.fromOffset(0, 34)
tabBar.BackgroundColor3 = C.panel
tabBar.Parent = root
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 10)

local tabNames = {"Chat", "Editor", "Settings"}
local tabBtns = {}
local tabFrames = {}
for i, name in ipairs(tabNames) do
    local w = 1 / #tabNames
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(w, -2, 1, -4)
    btn.Position = UDim2.new((i - 1) * w, 1, 0, 2)
    btn.BackgroundColor3 = i == 1 and C.accent or C.me
    btn.Text = name
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    tabBtns[i] = btn

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, -62)
    frame.Position = UDim2.fromOffset(0, 62)
    frame.BackgroundTransparency = 1
    frame.Visible = (i == 1)
    frame.Parent = root
    tabFrames[i] = frame

    btn.MouseButton1Click:Connect(function()
        for j, b in ipairs(tabBtns) do
            b.BackgroundColor3 = C.me
            tabFrames[j].Visible = false
        end
        btn.BackgroundColor3 = C.accent
        frame.Visible = true
    end)
end

-- CHAT TAB
local chatTab = tabFrames[1]

local function addBubble(parent, role, text)
    local col = role == "user" and C.me or role == "tool" and C.bg
        or role == "err" and Color3.fromRGB(60, 30, 30) or C.panel
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundColor3 = col
    lbl.BorderSizePixel = 0
    lbl.Font = role == "tool" and Enum.Font.RobotoMono or Enum.Font.Gotham
    lbl.TextSize = role == "tool" and 10 or 12
    lbl.TextColor3 = role == "tool" and C.sub or C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = true
    lbl.Text = (role == "tool" and "⚙ " or "") .. text
    lbl.Parent = parent
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 5)
    local p = Instance.new("UIPadding", lbl)
    p.PaddingTop = UDim.new(0, 4); p.PaddingBottom = UDim.new(0, 4)
    p.PaddingLeft = UDim.new(0, 6); p.PaddingRight = UDim.new(0, 6)
    if parent:IsA("ScrollingFrame") then
        parent.CanvasPosition = Vector2.new(0, parent.AbsoluteCanvasSize.Y)
    end
    return lbl
end

local chatLog = Instance.new("ScrollingFrame")
chatLog.Size = UDim2.new(1, 0, 1, -72)
chatLog.Position = UDim2.fromOffset(0, 0)
chatLog.BackgroundTransparency = 1
chatLog.ScrollBarThickness = 4
chatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
chatLog.AutomaticCanvasSize = Enum.AutomaticSize.Y
chatLog.Parent = chatTab
local chatList = Instance.new("UIListLayout", chatLog)
chatList.Padding = UDim.new(0, 5)
chatList.SortOrder = Enum.SortOrder.LayoutOrder
local chatPad = Instance.new("UIPadding", chatLog)
chatPad.PaddingTop = UDim.new(0, 4); chatPad.PaddingBottom = UDim.new(0, 4)
chatPad.PaddingLeft = UDim.new(0, 4); chatPad.PaddingRight = UDim.new(0, 4)

local chatBox = Instance.new("TextBox")
chatBox.Size = UDim2.new(1, -76, 0, 60)
chatBox.Position = UDim2.new(0, 4, 1, -66)
chatBox.BackgroundColor3 = C.panel
chatBox.BorderSizePixel = 0
chatBox.Font = Enum.Font.Gotham
chatBox.TextSize = 12
chatBox.TextColor3 = C.text
chatBox.PlaceholderText = ApiKey == "" and "Paste Deepseek API key first, then ask me anything..."
    or "Ask AI / type code / /key to change key / /editor to edit / /run to execute"
chatBox.ClearTextOnFocus = false
chatBox.MultiLine = true
chatBox.TextXAlignment = Enum.TextXAlignment.Left
chatBox.TextYAlignment = Enum.TextYAlignment.Top
chatBox.TextWrapped = true
chatBox.Parent = chatTab
Instance.new("UICorner", chatBox).CornerRadius = UDim.new(0, 6)
local p = Instance.new("UIPadding", chatBox)
p.PaddingLeft = UDim.new(0, 6); p.PaddingRight = UDim.new(0, 6)
p.PaddingTop = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6)

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.fromOffset(64, 60)
sendBtn.Position = UDim2.new(1, -68, 1, -66)
sendBtn.BackgroundColor3 = C.accent
sendBtn.Font = Enum.Font.GothamBold
sendBtn.TextSize = 13
sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sendBtn.Text = "Send"
sendBtn.Parent = chatTab
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 6)

-- EDITOR TAB
local editorTab = tabFrames[2]

local editorName = Instance.new("TextBox")
editorName.Size = UDim2.new(1, -8, 0, 26)
editorName.Position = UDim2.fromOffset(4, 4)
editorName.BackgroundColor3 = C.panel
editorName.Font = Enum.Font.Gotham
editorName.TextSize = 10
editorName.TextColor3 = C.sub
editorName.Text = "live_script.lua"
editorName.PlaceholderText = "script name..."
editorName.Parent = editorTab
Instance.new("UICorner", editorName).CornerRadius = UDim.new(0, 4)

local editorBox = Instance.new("TextBox")
editorBox.Size = UDim2.new(1, -8, 1, -68)
editorBox.Position = UDim2.fromOffset(4, 34)
editorBox.BackgroundColor3 = C.panel
editorBox.Font = Enum.Font.RobotoMono
editorBox.TextSize = 11
editorBox.TextColor3 = C.text
editorBox.Text = ScriptContent
editorBox.TextXAlignment = Enum.TextXAlignment.Left
editorBox.TextYAlignment = Enum.TextYAlignment.Top
editorBox.ClearTextOnFocus = false
editorBox.MultiLine = true
editorBox.TextWrapped = true
editorBox.Parent = editorTab
Instance.new("UICorner", editorBox).CornerRadius = UDim.new(0, 5)
local ep = Instance.new("UIPadding", editorBox)
ep.PaddingLeft = UDim.new(0, 4); ep.PaddingRight = UDim.new(0, 4)
ep.PaddingTop = UDim.new(0, 4); ep.PaddingBottom = UDim.new(0, 4)

local function makeBtn(parent, text, posY, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 24)
    btn.Position = UDim2.fromOffset(4, posY)
    btn.BackgroundColor3 = C.me
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = C.text
    btn.Text = text
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function() pcall(cb) end)
    return btn
end

makeBtn(editorTab, "Run (Ctrl+Enter)", editorBox.Position.Y.Offset + editorBox.Size.Y.Offset + 4, function()
    local code = editorBox.Text
    ScriptContent = code; saveConfig()
    local fn, err = loadstring(code)
    if not fn then addBubble(chatLog, "err", "Syntax: " .. tostring(err)); return end
    local ok, res = pcall(fn)
    addBubble(chatLog, "tool", ok and "Executed ✓" .. (res ~= nil and " → " .. tostring(res) or "") or "Error: " .. tostring(res))
end)

makeBtn(editorTab, "Save to Device", editorBox.Position.Y.Offset + editorBox.Size.Y.Offset + 32, function()
    ScriptContent = editorBox.Text; saveConfig()
    if g_writefile then pcall(function() g_writefile(editorName.Text, editorBox.Text) end) end
    addBubble(chatLog, "tool", "Saved: " .. editorName.Text)
end)

makeBtn(editorTab, "Load from Device", editorBox.Position.Y.Offset + editorBox.Size.Y.Offset + 60, function()
    if not g_readfile then return end
    local ok, data = pcall(function() return g_readfile(editorName.Text) end)
    if ok and data and #data < 100000 then
        editorBox.Text = data; ScriptContent = data
        addBubble(chatLog, "tool", "Loaded: " .. editorName.Text .. " (" .. #data .. " chars)")
    end
end)

-- SETTINGS TAB
local settingsTab = tabFrames[3]

local settingsList = Instance.new("UIListLayout", settingsTab)
settingsList.Padding = UDim.new(0, 6)
local sp = Instance.new("UIPadding", settingsTab)
sp.PaddingLeft = UDim.new(0, 6); sp.PaddingRight = UDim.new(0, 6)
sp.PaddingTop = UDim.new(0, 6); sp.PaddingBottom = UDim.new(0, 6)

local title1 = Instance.new("TextLabel")
title1.Size = UDim2.new(1, 0, 0, 18)
title1.BackgroundTransparency = 1
title1.Font = Enum.Font.GothamBold
title1.TextSize = 11
title1.TextColor3 = C.sub
title1.Text = "Deepseek API Key (deepseek-v4-pro)"
title1.Parent = settingsTab

local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(1, 0, 0, 30)
keyBox.BackgroundColor3 = C.panel
keyBox.Font = Enum.Font.Gotham
keyBox.TextSize = 11
keyBox.TextColor3 = C.text
keyBox.Text = ApiKey
keyBox.PlaceholderText = "sk-..."
keyBox.Parent = settingsTab
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 4)
keyBox.FocusLost:Connect(function()
    ApiKey = keyBox.Text; saveConfig()
end)

local saveSetBtn = Instance.new("TextButton")
saveSetBtn.Size = UDim2.new(1, 0, 0, 30)
saveSetBtn.BackgroundColor3 = C.green
saveSetBtn.Font = Enum.Font.GothamBold
saveSetBtn.TextSize = 11
saveSetBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
saveSetBtn.Text = "Save & Test API"
saveSetBtn.Parent = settingsTab
Instance.new("UICorner", saveSetBtn).CornerRadius = UDim.new(0, 4)
saveSetBtn.MouseButton1Click:Connect(function()
    ApiKey = keyBox.Text; saveConfig()
    local response, err = callDeepseek({
        { role = "user", content = "Say hello in 5 words." }
    })
    addBubble(chatLog, response and "ai" or "err", response or ("Error: " .. tostring(err)))
    tabBtns[1].BackgroundColor3 = C.accent
    tabFrames[2].Visible = false; tabFrames[3].Visible = false
    tabFrames[1].Visible = true
    for j, b in ipairs(tabBtns) do if j ~= 1 then b.BackgroundColor3 = C.me end end
end)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 40)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 10
infoLabel.TextColor3 = C.sub
infoLabel.TextWrapped = true
infoLabel.Text = "Model: deepseek-v4-pro\nHTTP: " .. (httpRequest and "available ✓" or "not found ✗")
infoLabel.Parent = settingsTab

-- ================ Chat logic ================
local chatHistory = {}
local busy = false

local SYSTEM_PROMPT = {
    role = "system",
    content = [[You are opencode-live, an expert Roblox Luau scripting assistant running directly on the user's executor (Delta/Codex Android). You have REAL-TIME access to the game session via tools.

CAPABILITIES:
- Execute arbitrary Luau code in the running Roblox session
- Read/write files on the device (readfile/writefile)
- Fetch web content (game:HttpGet)
- Search workspace instances by name
- Read console output (errors, warns, prints)
- Explore Instance hierarchies
- Read Roblox script sources
- Read/write the user's code editor

TOOL FORMAT:
Reply with ONLY this XML when using a tool:
<tool>name</tool><input>{"key":"value"}</input>

Available tools and their inputs:
- execute_luau → {"code":"..."}
- web_fetch → {"url":"https://..."}
- get_editor → {}
- set_editor → {"source":"..."}
- read_file → {"name":"filename.lua"}
- write_file → {"name":"file.lua","source":"..."}
- search → {"query":"name","limit":30}
- get_console → {"limit":40}
- read_tree → {"path":"workspace","depth":2}
- get_script_source → {"path":"game.ServerScriptService..."}

RULES:
1. One tool call OR one text response per message, never both.
2. After each tool call you receive the result. You can chain up to 6 tool calls.
3. Be concise. Write complete, working code in tool calls.
4. The user is on Android. They have: loadstring, writefile, readfile, getgenv, getgc, gethui, syn (maybe).
5. For GAG2/FallHarvest: you know the full Networking module, remote paths (Garden.CollectFruit, NPCS.SellAll, Backpack.SetFruitFavorite, etc), ValueEngine.compute, tool system, FruitProxy scanning, SprinklerData, and all game mechanics.]]
}

local function processToolCall(text)
    local toolName = text:match("<tool>(.-)</tool>")
    local inputStr = text:match("<input>(.-)</input>")
    if not toolName then return nil end
    local input = inputStr and jdecode(inputStr) or {}
    addBubble(chatLog, "tool", toolName .. " {" .. (inputStr or "{}") .. "}")
    local result = runTool(toolName, input)
    return { role = "user", content = "Tool result for " .. toolName .. ":\n" .. jencode(result) }
end

local function submitChat()
    if busy then return end
    local txt = chatBox.Text
    if #txt == 0 then return end
    chatBox.Text = ""

    -- Handle commands
    if txt:match("^/key%s") then
        ApiKey = txt:match("^/key%s+(.*)")
        keyBox.Text = ApiKey; saveConfig()
        addBubble(chatLog, "ai", "API key saved. You can now ask me anything.")
        return
    end
    if txt == "/editor" then
        addBubble(chatLog, "tool", "Switching to editor tab...")
        tabBtns[2].BackgroundColor3 = C.accent
        tabFrames[1].Visible = false; tabFrames[3].Visible = false
        tabFrames[2].Visible = true
        for j, b in ipairs(tabBtns) do if j ~= 2 then b.BackgroundColor3 = C.me end end
        return
    end
    if txt == "/run" then
        local code = editorBox.Text
        local fn, err = loadstring(code)
        if not fn then addBubble(chatLog, "err", "Syntax: " .. tostring(err)); return end
        local ok, res = pcall(fn)
        addBubble(chatLog, "tool", ok and "Executed ✓" or "Error: " .. tostring(res))
        return
    end

    addBubble(chatLog, "user", txt)
    local messages = { SYSTEM_PROMPT }
    -- add last 15 history messages
    local start = math.max(1, #chatHistory - 14)
    for i = start, #chatHistory do
        table.insert(messages, chatHistory[i])
    end
    table.insert(messages, { role = "user", content = txt })

    busy = true; sendBtn.Text = "..."
    task.spawn(function()
        local response, err
        for step = 1, 6 do
            response, err = callDeepseek(messages)
            if not response then break end

            -- check for tool calls
            local toolResult = processToolCall(response)
            if toolResult then
                table.insert(messages, { role = "assistant", content = response })
                table.insert(messages, toolResult) -- { role = "user", content = "Tool result:..." }
            else
                -- plain text response
                addBubble(chatLog, "ai", response)
                table.insert(chatHistory, { role = "user", content = txt })
                table.insert(chatHistory, { role = "assistant", content = response })
                if #chatHistory > 30 then
                    table.remove(chatHistory, 1); table.remove(chatHistory, 1)
                end
                break
            end
        end
        if not response and err then
            addBubble(chatLog, "err", "Error: " .. tostring(err))
        end
        busy = false; sendBtn.Text = "Send"
    end)
end

sendBtn.MouseButton1Click:Connect(submitChat)
chatBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then submitChat() end
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Return and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
        local code = editorBox.Text
        ScriptContent = code; saveConfig()
        local fn, err = loadstring(code)
        if not fn then addBubble(chatLog, "err", "Syntax: " .. tostring(err)); return end
        local ok, res = pcall(fn)
        addBubble(chatLog, "tool", ok and "Executed ✓" or "Error: " .. tostring(res))
    end
end)

-- ================ Startup ================
if ApiKey ~= "" then
    addBubble(chatLog, "ai", "opencode-live ready.\ndeepseek-v4-pro\n\nCommands:\n/key YOUR_KEY — set API key\n/editor — switch to editor\n/run — execute editor code\n\nJust chat to ask me anything, I can also run code, search instances, read files, and more.")
else
    addBubble(chatLog, "ai", "Welcome! Paste your Deepseek API key below (starts with sk-...) and press Send.\n\nOr type: /key YOUR_KEY")
end
addBubble(chatLog, "tool", "Tip: drag title bar · × close · Ctrl+Enter to execute editor code")
