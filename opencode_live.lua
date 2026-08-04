-- opencode-live.lua — Live scripting GUI with Deepseek AI for Roblox executors
-- Dependencies: executor with HttpService, loadstring, writefile, getsenv, gethui/CoreGui

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local client = Players.LocalPlayer

local DeepseekKey = ""
local DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"

-- ================ GUI Setup ================
local guiParent
pcall(function() guiParent = gethui and gethui() end)
if not guiParent then pcall(function() guiParent = game:GetService("CoreGui") end) end
if not guiParent then guiParent = client:WaitForChild("PlayerGui") end

local existing = guiParent:FindFirstChild("OpenCodeLive")
if existing then existing:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "OpenCodeLive"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.Parent = guiParent
if syn and syn.protect_gui then pcall(syn.protect_gui, SG) end

local C = {
    bg = Color3.fromRGB(12,12,16), surface = Color3.fromRGB(20,20,26),
    border = Color3.fromRGB(40,40,50), text = Color3.fromRGB(220,225,235),
    mute = Color3.fromRGB(130,135,150), accent = Color3.fromRGB(80,140,255),
    green = Color3.fromRGB(50,210,100), red = Color3.fromRGB(230,70,70),
    yellow = Color3.fromRGB(255,190,50), code = Color3.fromRGB(25,25,32),
    aiUser = Color3.fromRGB(30,50,80), aiBot = Color3.fromRGB(25,35,30),
}

local FB = Enum.Font.GothamBold
local FM = Enum.Font.GothamMedium
local FR = Enum.Font.Gotham

local function make(className, props)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = obj
    return c
end

local function stroke(obj, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border
    s.Thickness = t or 1
    s.Parent = obj
    return s
end

-- ================ Main Frame ================
local Main = make("Frame", {
    Name = "Main",
    Size = UDim2.new(1, -20, 1, -80),
    Position = UDim2.new(0, 10, 0, 10),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    Parent = SG,
})
corner(Main, 10)
stroke(Main, C.border, 1.5)

-- Title bar
local TitleBar = make("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = C.surface,
    Parent = Main,
})
corner(TitleBar, 10)
make("Frame", {Size=UDim2.new(1,0,0,24),Position=UDim2.new(0,0,0,10),BackgroundColor3=C.surface,Parent=TitleBar})

local Title = make("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0),
    Text = "  opencode-live",
    TextColor3 = C.accent,
    Font = FB, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1, Parent = TitleBar,
})

local StatusLabel = make("TextLabel", {
    Size = UDim2.new(0, 140, 1, 0), Position = UDim2.new(1, -180, 0, 0),
    Text = "Ready", TextColor3 = C.mute, Font = FR, TextSize = 10,
    BackgroundTransparency = 1, Parent = TitleBar,
})

local CloseBtn = make("TextButton", {
    Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -34, 0, 2),
    BackgroundColor3 = Color3.fromRGB(40,32,32), Text = "✕", TextColor3 = C.red,
    Font = FB, TextSize = 14, Parent = TitleBar,
})
corner(CloseBtn, 6)
CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Minimize button
local MinBtn = make("TextButton", {
    Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -68, 0, 2),
    BackgroundColor3 = C.surface, Text = "−", TextColor3 = C.text,
    Font = FB, TextSize = 16, Parent = TitleBar,
})
corner(MinBtn, 6)

local BodyVisible = true
MinBtn.MouseButton1Click:Connect(function()
    BodyVisible = not BodyVisible
    for _, child in ipairs(Main:GetChildren()) do
        if child.Name ~= "TitleBar" then
            child.Visible = BodyVisible
        end
    end
end)

-- ================ Body Layout ================
local Body = make("Frame", {
    Name = "Body",
    Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34),
    BackgroundTransparency = 1, Parent = Main,
})

local function vlist(parent, pad)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, pad or 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function pad(obj, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 8)
    p.PaddingRight = UDim.new(0, r or l or 8)
    p.PaddingTop = UDim.new(0, t or l or 8)
    p.PaddingBottom = UDim.new(0, b or t or l or 8)
    p.Parent = obj
    return p
end

-- Left: Editor
local EditorPanel = make("Frame", {
    Size = UDim2.new(0.6, -4, 1, 0),
    BackgroundColor3 = C.code, Parent = Body,
})
corner(EditorPanel, 6)
stroke(EditorPanel)

-- Editor tabs
local EditorTabs = make("Frame", {
    Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.surface, Parent = EditorPanel,
})
corner(EditorTabs, 6)
make("Frame", {Size=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,10),BackgroundColor3=C.surface,Parent=EditorTabs})

local EditorLabel = make("TextLabel", {
    Size = UDim2.new(0, 80, 1, 0), Text = "  Editor", TextColor3 = C.accent,
    Font = FB, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1, Parent = EditorTabs,
})

local ScriptNameBox = make("TextBox", {
    Size = UDim2.new(1, -180, 1, -4), Position = UDim2.new(0, 86, 0, 2),
    Text = "live_script.lua", TextColor3 = C.mute, Font = FR, TextSize = 10,
    BackgroundColor3 = Color3.fromRGB(30,30,36), PlaceholderText = "script name...",
    Parent = EditorTabs,
})
corner(ScriptNameBox, 4)

local EditorBox = make("TextBox", {
    Size = UDim2.new(1, -4, 1, -32), Position = UDim2.new(0, 2, 0, 30),
    Text = "-- Write Luau code here\n-- Press Ctrl+Enter to execute\n-- Use the AI panel for help",
    TextColor3 = C.text, Font = FR, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, BackgroundTransparency = 1,
    ClearTextOnFocus = false, MultiLine = true, Parent = EditorPanel,
})
pad(EditorBox, 8, 8, 4, 4)

-- Right: Side panel
local SidePanel = make("Frame", {
    Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.6, 4, 0, 0),
    BackgroundColor3 = C.surface, Parent = Body,
})
corner(SidePanel, 6)
stroke(SidePanel)

-- Side tabs
local sideTabs = {}
local tabNames = {"AI Chat", "Quick Actions", "Debug Log", "Settings"}
local tabContents = {}

local TabBar = make("Frame", {
    Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.bg, Parent = SidePanel,
})
corner(TabBar, 6)
make("Frame", {Size=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,10),BackgroundColor3=C.bg,Parent=TabBar})

for i, name in ipairs(tabNames) do
    local w = 1 / #tabNames
    local tab = make("TextButton", {
        Size = UDim2.new(w, -2, 1, -4), Position = UDim2.new((i-1)*w, 1, 0, 2),
        BackgroundColor3 = i == 1 and C.accent or C.code,
        Text = name, TextColor3 = C.text, Font = FM, TextSize = 10,
        Parent = TabBar,
    })
    corner(tab, 4)

    local content = make("Frame", {
        Size = UDim2.new(1, 0, 1, -30), Position = UDim2.new(0, 0, 0, 30),
        BackgroundTransparency = 1, Visible = (i == 1), Parent = SidePanel,
    })
    tabContents[i] = content

    tab.MouseButton1Click:Connect(function()
        for j, t in ipairs(sideTabs) do
            t.BackgroundColor3 = C.code
            tabContents[j].Visible = false
        end
        tab.BackgroundColor3 = C.accent
        content.Visible = true
    end)
    sideTabs[i] = tab
end

-- ================ AI Chat Panel ================
local chatContent = tabContents[1]
local ChatBox = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -36),
    BackgroundTransparency = 1, ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0), Parent = chatContent,
})
vlist(ChatBox, 6)
pad(ChatBox, 8, 4, 4, 4)

local chatMessages = {}
local function addChat(role, text)
    local msg = make("Frame", {
        Size = UDim2.new(1, -8, 0, 28),
        BackgroundColor3 = role == "user" and C.aiUser or C.aiBot,
        Parent = ChatBox,
    })
    corner(msg, 5)
    local label = make("TextLabel", {
        Size = UDim2.new(1, -8, 0, 0),
        Text = (role == "user" and "You: " or "AI: ") .. text,
        TextColor3 = role == "user" and C.text or Color3.fromRGB(180,220,180),
        Font = FR, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        BackgroundTransparency = 1, Parent = msg,
    })
    label.Size = UDim2.new(1, -8, 0, label.TextBounds.Y + 16)
    msg.Size = UDim2.new(1, -8, 0, label.TextBounds.Y + 16)
    ChatBox.CanvasSize = UDim2.new(0, 0, 0, ChatBox.CanvasSize.Y.Offset + label.TextBounds.Y + 22)
    ChatBox.CanvasPosition = Vector2.new(0, ChatBox.CanvasSize.Y.Offset)
    table.insert(chatMessages, {role = role, content = text})
    return msg
end

addChat("ai", "Ready. Write code in the editor or ask me to generate scripts.")

local ChatInput = make("TextBox", {
    Size = UDim2.new(1, -56, 0, 28), Position = UDim2.new(0, 4, 1, -32),
    BackgroundColor3 = C.code, PlaceholderText = "Ask AI...",
    TextColor3 = C.text, Font = FR, TextSize = 10,
    ClearTextOnFocus = false, Parent = chatContent,
})
corner(ChatInput, 5)

local SendBtn = make("TextButton", {
    Size = UDim2.new(0, 48, 0, 28), Position = UDim2.new(1, -52, 1, -32),
    BackgroundColor3 = C.accent, Text = "Send", TextColor3 = Color3.fromRGB(0,0,0),
    Font = FB, TextSize = 10, Parent = chatContent,
})
corner(SendBtn, 5)

-- ================ Quick Actions ================
local actionContent = tabContents[2]
vlist(actionContent, 6)
pad(actionContent)

local function actionBtn(name, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = C.code, Text = name, TextColor3 = C.text,
        Font = FM, TextSize = 11, Parent = actionContent,
    })
    corner(btn, 5)
    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return btn
end

actionBtn("Execute Script (Ctrl+Enter)", function()
    executeScript()
end)
actionBtn("Push to Device (writefile)", function()
    saveToDevice()
end)
actionBtn("Pull from Device (readfile)", function()
    loadFromDevice()
end)
actionBtn("Load GAG2.lua (live)", function()
    loadFromURL("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/GAG2.lua")
end)
actionBtn("Load FallHarvest.lua (live)", function()
    loadFromURL("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/FallHarvest.lua")
end)
actionBtn("Clear Editor", function()
    EditorBox.Text = ""
end)

-- ================ Debug Log ================
local debugContent = tabContents[3]
local DebugLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 1, -32),
    Text = "Press Refresh to load gag2_debug_log.txt",
    TextColor3 = C.mute, Font = FR, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, BackgroundTransparency = 1, Parent = debugContent,
})
pad(DebugLabel)

local function refreshDebug()
    local ok, content = pcall(function()
        return readfile and readfile("gag2_debug_log.txt") or "readfile not available"
    end)
    if ok and content then
        local lines = {}
        for line in string.gmatch(content .. "\n", "[^\n]*\n") do
            table.insert(lines, line)
        end
        -- keep last 100 lines
        if #lines > 100 then
            lines = { table.unpack(lines, #lines - 99, #lines) }
        end
        DebugLabel.Text = table.concat(lines, "")
    end
end

make("TextButton", {
    Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -30),
    BackgroundColor3 = C.accent, Text = "Refresh Debug Log", TextColor3 = Color3.fromRGB(0,0,0),
    Font = FM, TextSize = 10, Parent = debugContent,
}).MouseButton1Click:Connect(refreshDebug)
corner(debugContent.Parent:FindFirstChildOfClass("TextButton"), 5)

-- ================ Settings ================
local settingsContent = tabContents[4]
vlist(settingsContent, 6)
pad(settingsContent)

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), Text = "Deepseek API Key",
    TextColor3 = C.mute, Font = FM, TextSize = 10, BackgroundTransparency = 1, Parent = settingsContent,
})

local APIKeyBox = make("TextBox", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = C.code, Text = DeepseekKey, PlaceholderText = "sk-...",
    TextColor3 = C.text, Font = FR, TextSize = 10, Parent = settingsContent,
})
corner(APIKeyBox, 5)

make("TextButton", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = C.green, Text = "Save Settings",
    TextColor3 = Color3.fromRGB(0,0,0), Font = FB, TextSize = 11, Parent = settingsContent,
}).MouseButton1Click:Connect(function()
    DeepseekKey = APIKeyBox.Text
    local cfg = { key = DeepseekKey }
    if writefile then
        pcall(function()
            writefile("opencode_live_config.json", HttpService:JSONEncode(cfg))
        end)
    end
    StatusLabel.Text = "Settings saved"
    addChat("ai", "API key saved.")
end)
corner(settingsContent:FindFirstChildOfClass("TextButton"), 5)

make("TextButton", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = C.code, Text = "Load Settings",
    TextColor3 = C.text, Font = FB, TextSize = 11, Parent = settingsContent,
}).MouseButton1Click:Connect(function()
    if readfile then
        local ok, data = pcall(function()
            return readfile("opencode_live_config.json")
        end)
        if ok and data then
            local cfg = HttpService:JSONDecode(data)
            if cfg.key then
                DeepseekKey = cfg.key
                APIKeyBox.Text = DeepseekKey
                StatusLabel.Text = "API key loaded"
            end
        end
    end
end)
corner(settingsContent.Parent:FindFirstChildOfClass("TextButton"), 5)

-- ================ Core Functions ================
local function setStatus(s)
    StatusLabel.Text = s
end

local function executeScript()
    local code = EditorBox.Text
    if #code == 0 then
        setStatus("No code to execute")
        return
    end
    setStatus("Executing...")
    local fn, err = loadstring(code)
    if not fn then
        addChat("ai", "Syntax Error: " .. tostring(err))
        setStatus("Syntax error")
        return
    end
    local ok, result = pcall(fn)
    if ok then
        setStatus("Executed successfully")
        if result ~= nil then
            addChat("ai", "Returned: " .. tostring(result))
        end
    else
        addChat("ai", "Runtime Error: " .. tostring(result))
        setStatus("Runtime error")
    end
end

local function saveToDevice()
    local name = ScriptNameBox.Text
    local content = EditorBox.Text
    if writefile then
        pcall(function()
            writefile(name, content)
        end)
        setStatus("Saved: " .. name)
        addChat("ai", "Script saved to " .. name)
    else
        setStatus("writefile not available")
    end
end

local function loadFromDevice()
    local name = ScriptNameBox.Text
    if readfile then
        local ok, content = pcall(function()
            return readfile(name)
        end)
        if ok and content then
            EditorBox.Text = content
            setStatus("Loaded: " .. name)
        else
            setStatus("Failed to read: " .. name)
        end
    else
        setStatus("readfile not available")
    end
end

local function loadFromURL(url)
    setStatus("Loading from URL...")
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and result then
        EditorBox.Text = result
        setStatus("Loaded from URL")
        addChat("ai", "Script loaded from GitHub.")
    else
        setStatus("Failed to load URL")
    end
end

-- ================ Deepseek API ================
local function askDeepseek(prompt)
    if DeepseekKey == "" then
        return "No API key configured. Set it in Settings tab."
    end
    if not HttpService then
        return "HttpService not available on this executor."
    end

    local body = HttpService:JSONEncode({
        model = "deepseek-chat",
        messages = {
            {
                role = "system",
                content = "You are an expert Roblox Luau scripting assistant. Help write, debug, and optimize scripts. Be concise. Provide working code. You know the GAG2/FallHarvest game internals."
            },
            {
                role = "user",
                content = prompt
            }
        },
        temperature = 0.3,
        max_tokens = 4096,
    })

    local ok, result = pcall(function()
        return HttpService:PostAsync(
            DEEPSEEK_URL,
            body,
            Enum.HttpContentType.ApplicationJson,
            false,
            { ["Authorization"] = "Bearer " .. DeepseekKey }
        )
    end)

    if not ok then
        return "HttpService error: " .. tostring(result)
    end

    local data = HttpService:JSONDecode(result)
    if data.choices and data.choices[1] then
        return data.choices[1].message.content
    end
    return "API error: " .. tostring(result)
end

local function sendChatMessage()
    local text = ChatInput.Text
    if #text == 0 then return end
    ChatInput.Text = ""
    addChat("user", text)
    setStatus("AI thinking...")

    task.spawn(function()
        local response = askDeepseek(text)
        addChat("ai", response)
        setStatus("Ready")
    end)
end

SendBtn.MouseButton1Click:Connect(sendChatMessage)
ChatInput.FocusLost:Connect(function(enter)
    if enter then
        sendChatMessage()
    end
end)

-- ================ Keyboard Shortcuts ================
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Return and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
        executeScript()
    end
end)

-- ================ Startup ================
if readfile then
    local ok, data = pcall(function()
        return readfile("opencode_live_config.json")
    end)
    if ok and data then
        local cfg = HttpService:JSONDecode(data)
        if cfg.key then
            DeepseekKey = cfg.key
            APIKeyBox.Text = DeepseekKey
        end
    end
end

setStatus("Ready — opencode-live loaded")
addChat("ai", "opencode-live loaded.\n\nCommands:\n• Type code in the editor, Ctrl+Enter to execute\n• Use AI chat to generate/debug scripts\n• Push/Pull scripts to device storage\n• Load GAG2/FallHarvest from GitHub")
