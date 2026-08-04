-- opencode-live.lua — Live Scripting GUI with Deepseek AI for Roblox executors
-- Uses Fluent-modded UI library (StyearX/Fluent-modded)
-- Model: deepseek-v4-pro

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local client = Players.LocalPlayer

local DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
local DEEPSEEK_MODEL = "deepseek-v4-pro"
local FLUENT_URL = "https://github.com/StyearX/Fluent-Modded/releases/download/Fluent/FluentPro"

local CONFIG_FILE = "opencode_live_config.json"
local ApiKey = ""
local ScriptContent = "-- Write Luau code here\n-- Ctrl+Enter to execute\n-- Ask AI to generate/debug code"
local ScriptName = "live_script.lua"

-- ================ Load Fluent-modded ================
local Fluent = nil
pcall(function()
    Fluent = loadstring(game:HttpGet(FLUENT_URL))()
end)

if not Fluent then
    -- fallback: try alternate URLs
    for _, url in ipairs({
        "https://raw.githubusercontent.com/StyearX/Fluent-modded/main/build/init.luau",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua",
    }) do
        pcall(function()
            if not Fluent then Fluent = loadstring(game:HttpGet(url))() end
        end)
    end
end

-- ================ Save/Load Config ================
local function saveConfig()
    if not writefile then return end
    pcall(function()
        local cfg = { key = ApiKey, name = ScriptName, content = ScriptContent }
        writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
    end)
end

local function loadConfig()
    if not readfile then return end
    pcall(function()
        local data = readfile(CONFIG_FILE)
        if data then
            local cfg = HttpService:JSONDecode(data)
            if cfg.key then ApiKey = cfg.key end
            if cfg.name then ScriptName = cfg.name end
            if cfg.content then ScriptContent = cfg.content end
        end
    end)
end

loadConfig()

-- ================ Execute Script ================
local function executeCode(code)
    code = code or ScriptContent
    if #code == 0 then
        return false, "No code"
    end
    local fn, err = loadstring(code)
    if not fn then
        return false, "Syntax: " .. tostring(err)
    end
    local ok, result = pcall(fn)
    if not ok then
        return false, "Runtime: " .. tostring(result)
    end
    return true, result
end

-- ================ AI ================
local function askDeepseek(prompt, history)
    if ApiKey == "" then
        return "No API key. Set it in Settings tab."
    end
    if not HttpService then
        return "HttpService not available."
    end

    local messages = {
        {
            role = "system",
            content = "You are an expert Roblox Luau scripting assistant powered by deepseek-v4-pro. You help write, debug, and optimize executor scripts for Grow a Garden 2 and Fall Harvest. You know the game's full Networking module, remote paths, ValueEngine, tool system, and data structures. Be concise and provide complete, working code snippets when asked. The user is running scripts on an Android executor with access to: loadstring, writefile, readfile, getgenv, getgc, gethui, HttpService, syn/synapse APIs."
        }
    }
    if history then
        for _, msg in ipairs(history) do
            table.insert(messages, msg)
        end
    else
        table.insert(messages, { role = "user", content = prompt })
    end

    local body = HttpService:JSONEncode({
        model = DEEPSEEK_MODEL,
        messages = messages,
        temperature = 0.3,
        max_tokens = 4096,
    })

    local ok, result = pcall(function()
        return HttpService:PostAsync(
            DEEPSEEK_URL,
            body,
            Enum.HttpContentType.ApplicationJson,
            false,
            { ["Authorization"] = "Bearer " .. ApiKey }
        )
    end)

    if not ok then return "HttpService error: " .. tostring(result) end
    local data = HttpService:JSONDecode(result)
    if data and data.choices and data.choices[1] then
        return data.choices[1].message.content
    end
    return "API error: " .. tostring(result)
end

-- ================ Fluent UI ================
if Fluent then
    -- ====== FLUENT VERSION ======
    local Window = Fluent:CreateWindow({
        Title = "opencode-live",
        SubTitle = "by opencode • deepseek-v4-pro",
        TabWidth = 140,
        Size = UDim2.fromOffset(620, 520),
        Acrylic = true,
        Theme = "AMOLED",
        MinimizeKey = Enum.KeyCode.LeftControl,
        Search = true,
    })

    local chatHistory = {}

    -- Editor Tab
    local EditorTab = Window:AddTab({ Title = "Editor", Icon = "solar/code-bold" })

    EditorTab:AddInput("scriptName", {
        Title = "Script Name",
        Default = ScriptName,
        Callback = function(v) ScriptName = v; saveConfig() end,
    })

    local editorInput
    EditorTab:AddParagraph({ Title = "", Content = "" }) -- spacer

    -- use a large input as code editor
    editorInput = EditorTab:AddInput("codeEditor", {
        Title = "Code (Ctrl+Enter = execute)",
        Default = ScriptContent,
        Callback = function(v)
            ScriptContent = v
            saveConfig()
        end,
    })

    EditorTab:AddButton({
        Title = "Execute (Ctrl+Enter)",
        Icon = "solar/play-bold",
        Callback = function()
            local ok, msg = executeCode(ScriptContent)
            if not ok then
                Fluent:Notify({ Title = "Error", Content = msg, Duration = 4 })
            else
                Fluent:Notify({ Title = "Success", Content = "Script executed" .. (msg and " → " .. tostring(msg) or ""), Duration = 2 })
            end
        end,
    })

    EditorTab:AddButton({
        Title = "Save to Device (writefile)",
        Icon = "solar/save-bold",
        Callback = function()
            if writefile then
                pcall(function() writefile(ScriptName, ScriptContent) end)
                Fluent:Notify({ Title = "Saved", Content = "Written to " .. ScriptName, Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "writefile not available", Duration = 3 })
            end
        end,
    })

    EditorTab:AddButton({
        Title = "Load from Device (readfile)",
        Icon = "solar/folder-open-bold",
        Callback = function()
            if readfile then
                local ok, data = pcall(function() return readfile(ScriptName) end)
                if ok and data then
                    ScriptContent = data
                    saveConfig()
                    Fluent:Notify({ Title = "Loaded", Content = ScriptName, Duration = 2 })
                else
                    Fluent:Notify({ Title = "Error", Content = "Failed to read " .. ScriptName, Duration = 3 })
                end
            end
        end,
    })

    EditorTab:AddButton({
        Title = "Load GAG2.lua from GitHub",
        Icon = "solar/download-bold",
        Callback = function()
            local ok, data = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/GAG2.lua")
            end)
            if ok and data then
                ScriptContent = data
                ScriptName = "GAG2.lua"
                saveConfig()
                Fluent:Notify({ Title = "Loaded", Content = "GAG2.lua (6K+ lines)", Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "Failed to fetch GAG2.lua", Duration = 3 })
            end
        end,
    })

    EditorTab:AddButton({
        Title = "Load FallHarvest.lua from GitHub",
        Icon = "solar/download-bold",
        Callback = function()
            local ok, data = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/FallHarvest.lua")
            end)
            if ok and data then
                ScriptContent = data
                ScriptName = "FallHarvest.lua"
                saveConfig()
                Fluent:Notify({ Title = "Loaded", Content = "FallHarvest.lua (6K+ lines)", Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "Failed to fetch FallHarvest.lua", Duration = 3 })
            end
        end,
    })

    -- AI Chat Tab
    local AITab = Window:AddTab({ Title = "AI Chat", Icon = "solar/chat-round-dots-bold" })

    local chatContent = ""
    local function updateChat()
        -- Fluent doesn't have a direct chat widget, use Paragraph for display
    end

    AITab:AddParagraph({ Title = "Deepseek v4 Pro", Content = "Ask me to write, debug, or optimize scripts. I know GAG2/FallHarvest internals." })

    local chatInput
    AITab:AddInput("chatInput", {
        Title = "Ask AI...",
        Default = "",
        Callback = function(v)
            if v == "" then return end
            local prompt = v

            -- add to history
            table.insert(chatHistory, { role = "user", content = prompt })

            local response = askDeepseek(nil, chatHistory)
            table.insert(chatHistory, { role = "assistant", content = response })

            -- show in paragraph
            local preview = string.sub(response, 1, 1000)
            if #response > 1000 then preview = preview .. "\n\n... (truncated, " .. #response .. " chars total)" end

            Fluent:Notify({
                Title = "AI Response",
                Content = preview,
                Duration = 10,
            })

            -- auto-insert into editor if it looks like code
            if response:match("```lua") then
                local code = response:match("```lua\n(.-)```") or response:match("```\n(.-)```")
                if code then
                    ScriptContent = code
                    saveConfig()
                    Fluent:Notify({
                        Title = "Code Inserted",
                        Content = "AI-generated code inserted into editor.",
                        Duration = 2,
                    })
                end
            end
        end,
    })

    AITab:AddButton({
        Title = "Debug Current Script",
        Icon = "solar/bug-bold",
        Callback = function()
            local prompt = "Debug this Luau script and fix any errors:\n```lua\n" .. ScriptContent .. "\n```\nList all bugs found and provide the fixed code."
            table.insert(chatHistory, { role = "user", content = prompt })
            local response = askDeepseek(nil, chatHistory)
            table.insert(chatHistory, { role = "assistant", content = response })
            Fluent:Notify({ Title = "Debug Results", Content = string.sub(response, 1, 2000), Duration = 15 })
        end,
    })

    AITab:AddButton({
        Title = "Optimize Current Script",
        Icon = "solar/lightning-bold",
        Callback = function()
            local prompt = "Optimize this Luau script for performance and stability:\n```lua\n" .. ScriptContent .. "\n```\nIdentify bottlenecks and provide optimized code."
            table.insert(chatHistory, { role = "user", content = prompt })
            local response = askDeepseek(nil, chatHistory)
            table.insert(chatHistory, { role = "assistant", content = response })
            Fluent:Notify({ Title = "Optimization", Content = string.sub(response, 1, 2000), Duration = 15 })
        end,
    })

    AITab:AddButton({
        Title = "Clear Chat History",
        Icon = "solar/trash-bin-bold",
        Callback = function()
            chatHistory = {}
            Fluent:Notify({ Title = "Cleared", Content = "Chat history reset.", Duration = 2 })
        end,
    })

    -- Debug Tab
    local DebugTab = Window:AddTab({ Title = "Debug", Icon = "solar/terminal-bold" })

    local debugContent = ""
    DebugTab:AddParagraph({ Title = "Debug Log", Content = "Press Refresh to load gag2_debug_log.txt" })

    DebugTab:AddButton({
        Title = "Refresh Debug Log",
        Icon = "solar/refresh-bold",
        Callback = function()
            if readfile then
                local ok, data = pcall(function() return readfile("gag2_debug_log.txt") end)
                if ok and data then
                    local lines = {}
                    for line in string.gmatch(data .. "\n", "[^\n]*\n") do
                        table.insert(lines, line)
                    end
                    if #lines > 80 then
                        lines = { table.unpack(lines, #lines - 79, #lines) }
                    end
                    debugContent = table.concat(lines, "")
                else
                    debugContent = "No log found or read error."
                end
            else
                debugContent = "readfile not available."
            end
        end,
    })

    -- Settings Tab
    local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "solar/settings-bold" })

    SettingsTab:AddInput("apiKey", {
        Title = "Deepseek API Key",
        Default = ApiKey,
        Callback = function(v)
            ApiKey = v
            saveConfig()
            Fluent:Notify({ Title = "Saved", Content = "API key saved.", Duration = 2 })
        end,
    })

    SettingsTab:AddParagraph({
        Title = "Model",
        Content = "Using: deepseek-v4-pro\nAPI: " .. DEEPSEEK_URL,
    })

    SettingsTab:AddButton({
        Title = "Test API Connection",
        Icon = "solar/wifi-bold",
        Callback = function()
            local response = askDeepseek("Say hello in one word.")
            Fluent:Notify({ Title = "API Test", Content = response, Duration = 4 })
        end,
    })

    -- Quick Actions
    local QATab = Window:AddTab({ Title = "Quick", Icon = "solar/lightning-bold" })

    QATab:AddButton({
        Title = "Push GAG2.lua to Device",
        Callback = function()
            local ok, data = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/GAG2.lua") end)
            if ok and data and writefile then
                pcall(function() writefile("GAG2.lua", data) end)
                Fluent:Notify({ Title = "Pushed", Content = "GAG2.lua saved to device", Duration = 2 })
            end
        end,
    })

    QATab:AddButton({
        Title = "Push FallHarvest.lua to Device",
        Callback = function()
            local ok, data = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/FallHarvest.lua") end)
            if ok and data and writefile then
                pcall(function() writefile("FallHarvest.lua", data) end)
                Fluent:Notify({ Title = "Pushed", Content = "FallHarvest.lua saved to device", Duration = 2 })
            end
        end,
    })

    QATab:AddButton({
        Title = "Push opencode-live to Device",
        Callback = function()
            local ok, data = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/opencode_live.lua") end)
            if ok and data and writefile then
                pcall(function() writefile("opencode_live.lua", data) end)
                Fluent:Notify({ Title = "Pushed", Content = "opencode_live.lua saved to device", Duration = 2 })
            end
        end,
    })

    Fluent:Notify({ Title = "opencode-live", Content = "Loaded with Fluent UI • deepseek-v4-pro", Duration = 3 })

else
    -- ====== FALLBACK: Raw GUI ======
    warn("[opencode-live] Fluent-modded not available, using raw GUI")

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
    local FB = Enum.Font.GothamBold; local FM = Enum.Font.GothamMedium; local FR = Enum.Font.Gotham

    local function make(className, props)
        local obj = Instance.new(className)
        for k, v in pairs(props) do obj[k] = v end
        return obj
    end
    local function corner(obj, r)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = obj; return c
    end
    local function stroke(obj, col, t)
        local s = Instance.new("UIStroke"); s.Color = col or C.border; s.Thickness = t or 1; s.Parent = obj; return s
    end

    local Main = make("Frame", {
        Name = "Main", Size = UDim2.new(1, -20, 1, -80), Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Parent = SG,
    })
    corner(Main, 10); stroke(Main, C.border, 1.5)

    local TitleBar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.surface, Parent = Main,
    })
    corner(TitleBar, 10)
    make("Frame", {Size=UDim2.new(1,0,0,24),Position=UDim2.new(0,0,0,10),BackgroundColor3=C.surface,Parent=TitleBar})

    make("TextLabel", {Size=UDim2.new(1,-60,1,0),Text="  opencode-live • deepseek-v4-pro",TextColor3=C.accent,Font=FB,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Parent=TitleBar})

    local StatusLabel = make("TextLabel", {Size=UDim2.new(0,160,1,0),Position=UDim2.new(1,-200,0,0),Text="Ready",TextColor3=C.mute,Font=FR,TextSize=10,BackgroundTransparency=1,Parent=TitleBar})

    local CloseBtn = make("TextButton", {Size=UDim2.new(0,30,0,30),Position=UDim2.new(1,-34,0,2),BackgroundColor3=Color3.fromRGB(40,32,32),Text="✕",TextColor3=C.red,Font=FB,TextSize=14,Parent=TitleBar})
    corner(CloseBtn, 6); CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

    local MinBtn = make("TextButton", {Size=UDim2.new(0,30,0,30),Position=UDim2.new(1,-68,0,2),BackgroundColor3=C.surface,Text="−",TextColor3=C.text,Font=FB,TextSize=16,Parent=TitleBar})
    corner(MinBtn, 6)
    local BodyVisible = true
    MinBtn.MouseButton1Click:Connect(function()
        BodyVisible = not BodyVisible
        for _, child in ipairs(Main:GetChildren()) do
            if child.Name ~= "TitleBar" then child.Visible = BodyVisible end
        end
    end)

    local Body = make("Frame", {Name="Body",Size=UDim2.new(1,0,1,-34),Position=UDim2.new(0,0,0,34),BackgroundTransparency=1,Parent=Main})

    local EditorPanel = make("Frame", {Size=UDim2.new(0.6,-4,1,0),BackgroundColor3=C.code,Parent=Body})
    corner(EditorPanel, 6); stroke(EditorPanel)

    local EditorTabs = make("Frame", {Size=UDim2.new(1,0,0,28),BackgroundColor3=C.surface,Parent=EditorPanel})
    corner(EditorTabs, 6)

    make("TextLabel", {Size=UDim2.new(0,80,1,0),Text="  Editor",TextColor3=C.accent,Font=FB,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Parent=EditorTabs})

    local ScriptNameBox = make("TextBox", {Size=UDim2.new(1,-180,1,-4),Position=UDim2.new(0,86,0,2),Text=ScriptName,TextColor3=C.mute,Font=FR,TextSize=10,BackgroundColor3=Color3.fromRGB(30,30,36),PlaceholderText="script name...",Parent=EditorTabs})
    corner(ScriptNameBox, 4)
    ScriptNameBox.FocusLost:Connect(function() ScriptName = ScriptNameBox.Text; saveConfig() end)

    local EditorBox = make("TextBox", {Size=UDim2.new(1,-4,1,-32),Position=UDim2.new(0,2,0,30),Text=ScriptContent,TextColor3=C.text,Font=FR,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,ClearTextOnFocus=false,MultiLine=true,Parent=EditorPanel})
    EditorBox.FocusLost:Connect(function() ScriptContent = EditorBox.Text; saveConfig() end)

    -- Side panel
    local SidePanel = make("Frame", {Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0.6,4,0,0),BackgroundColor3=C.surface,Parent=Body})
    corner(SidePanel, 6); stroke(SidePanel)

    local sideTabs = {}
    local tabContents = {}

    local TabBar = make("Frame", {Size=UDim2.new(1,0,0,28),BackgroundColor3=C.bg,Parent=SidePanel})
    corner(TabBar, 6)

    for i, name in ipairs({"AI Chat", "Quick", "Debug", "Settings"}) do
        local w = 0.25
        local tab = make("TextButton", {Size=UDim2.new(w,-2,1,-4),Position=UDim2.new((i-1)*w,1,0,2),BackgroundColor3=i==1 and C.accent or C.code,Text=name,TextColor3=C.text,Font=FM,TextSize=10,Parent=TabBar})
        corner(tab, 4)
        local content = make("Frame", {Size=UDim2.new(1,0,1,-30),Position=UDim2.new(0,0,0,30),BackgroundTransparency=1,Visible=(i==1),Parent=SidePanel})
        tabContents[i] = content
        tab.MouseButton1Click:Connect(function()
            for j, t in ipairs(sideTabs) do t.BackgroundColor3 = C.code; tabContents[j].Visible = false end
            tab.BackgroundColor3 = C.accent; content.Visible = true
        end)
        sideTabs[i] = tab
    end

    -- AI Chat
    local chatContent = tabContents[1]
    local ChatBox = make("ScrollingFrame", {Size=UDim2.new(1,0,1,-36),BackgroundTransparency=1,ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0),Parent=chatContent})
    local chatVlist = Instance.new("UIListLayout"); chatVlist.Padding = UDim.new(0, 6); chatVlist.Parent = ChatBox

    local chatMessages = {}
    local function addChatRaw(role, text)
        local msg = make("Frame", {Size=UDim2.new(1,-8,0,28),BackgroundColor3=role=="user" and C.aiUser or C.aiBot,Parent=ChatBox})
        corner(msg, 5)
        local label = make("TextLabel", {Size=UDim2.new(1,-8,0,0),Text=(role=="user" and "You: " or "AI: ")..text,TextColor3=role=="user" and C.text or Color3.fromRGB(180,220,180),Font=FR,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,BackgroundTransparency=1,Parent=msg})
        label.Size = UDim2.new(1, -8, 0, label.TextBounds.Y + 16)
        msg.Size = UDim2.new(1, -8, 0, label.TextBounds.Y + 16)
        ChatBox.CanvasSize = UDim2.new(0, 0, 0, ChatBox.CanvasSize.Y.Offset + label.TextBounds.Y + 22)
        ChatBox.CanvasPosition = Vector2.new(0, ChatBox.CanvasSize.Y.Offset)
        table.insert(chatMessages, {role = role, content = text})
    end
    addChatRaw("ai", "Ready. deepseek-v4-pro loaded.\nWrite code in the editor or ask me to generate scripts.")

    local ChatInput = make("TextBox", {Size=UDim2.new(1,-56,0,28),Position=UDim2.new(0,4,1,-32),BackgroundColor3=C.code,PlaceholderText="Ask AI...",TextColor3=C.text,Font=FR,TextSize=10,ClearTextOnFocus=false,Parent=chatContent})
    corner(ChatInput, 5)

    local SendBtn = make("TextButton", {Size=UDim2.new(0,48,0,28),Position=UDim2.new(1,-52,1,-32),BackgroundColor3=C.accent,Text="Send",TextColor3=Color3.fromRGB(0,0,0),Font=FB,TextSize=10,Parent=chatContent})
    corner(SendBtn, 5)

    local function sendChatRaw()
        local text = ChatInput.Text; if #text == 0 then return end; ChatInput.Text = ""
        addChatRaw("user", text)
        task.spawn(function()
            local response = askDeepseek(nil, chatMessages)
            addChatRaw("ai", response)
            if response:match("```lua") then
                local code = response:match("```lua\n(.-)```") or response:match("```\n(.-)```")
                if code then ScriptContent = code; EditorBox.Text = code; saveConfig() end
            end
        end)
    end
    SendBtn.MouseButton1Click:Connect(sendChatRaw)
    ChatInput.FocusLost:Connect(function(enter) if enter then sendChatRaw() end end)

    -- Quick Actions
    local actionContent = tabContents[2]
    local avlist = Instance.new("UIListLayout"); avlist.Padding = UDim.new(0, 6); avlist.Parent = actionContent

    local function actionBtn(name, cb)
        local btn = make("TextButton", {Size=UDim2.new(1,0,0,32),BackgroundColor3=C.code,Text=name,TextColor3=C.text,Font=FM,TextSize=11,Parent=actionContent})
        corner(btn, 5); btn.MouseButton1Click:Connect(function() pcall(cb) end)
    end

    actionBtn("Execute Script (Ctrl+Enter)", function() local ok, msg = executeCode(); StatusLabel.Text = ok and "OK" or msg end)
    actionBtn("Save to Device", function() if writefile then pcall(function() writefile(ScriptName, ScriptContent) end); StatusLabel.Text = "Saved: " .. ScriptName end end)
    actionBtn("Load from Device", function() if readfile then local ok, data = pcall(function() return readfile(ScriptName) end); if ok then ScriptContent = data; EditorBox.Text = data end end end)
    actionBtn("Load GAG2.lua", function() local ok, data = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/GAG2.lua") end); if ok then ScriptContent = data; EditorBox.Text = data; ScriptName = "GAG2.lua" end end)
    actionBtn("Load FallHarvest.lua", function() local ok, data = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/FallHarvest.lua") end); if ok then ScriptContent = data; EditorBox.Text = data; ScriptName = "FallHarvest.lua" end end)
    actionBtn("Push GAG2 to Device", function() local ok, data = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/GAG2.lua") end); if ok and writefile then writefile("GAG2.lua", data) end end)
    actionBtn("Clear Editor", function() ScriptContent = ""; EditorBox.Text = "" end)

    -- Debug
    local debugContent = tabContents[3]
    local DebugLabel = make("TextLabel", {Size=UDim2.new(1,0,1,-32),Text="Press Refresh to load log",TextColor3=C.mute,Font=FR,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,BackgroundTransparency=1,Parent=debugContent})
    make("TextButton", {Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,1,-30),BackgroundColor3=C.accent,Text="Refresh Debug Log",TextColor3=Color3.fromRGB(0,0,0),Font=FM,TextSize=10,Parent=debugContent}).MouseButton1Click:Connect(function()
        if readfile then local ok, data = pcall(function() return readfile("gag2_debug_log.txt") end)
        if ok and data then DebugLabel.Text = data end end
    end)

    -- Settings
    local settingsContent = tabContents[4]
    local svlist = Instance.new("UIListLayout"); svlist.Padding = UDim.new(0, 6); svlist.Parent = settingsContent

    make("TextLabel", {Size=UDim2.new(1,0,0,18),Text="Deepseek API Key (deepseek-v4-pro)",TextColor3=C.mute,Font=FM,TextSize=10,BackgroundTransparency=1,Parent=settingsContent})
    local APIKeyBox = make("TextBox", {Size=UDim2.new(1,0,0,30),BackgroundColor3=C.code,Text=ApiKey,PlaceholderText="sk-...",TextColor3=C.text,Font=FR,TextSize=10,Parent=settingsContent})
    corner(APIKeyBox, 5)
    make("TextButton", {Size=UDim2.new(1,0,0,30),BackgroundColor3=C.green,Text="Save Settings",TextColor3=Color3.fromRGB(0,0,0),Font=FB,TextSize=11,Parent=settingsContent}).MouseButton1Click:Connect(function() ApiKey = APIKeyBox.Text; saveConfig(); StatusLabel.Text = "Saved" end)
    make("TextButton", {Size=UDim2.new(1,0,0,30),BackgroundColor3=C.code,Text="Test API",TextColor3=C.text,Font=FB,TextSize=11,Parent=settingsContent}).MouseButton1Click:Connect(function()
        local response = askDeepseek("Say hi in 3 words.")
        addChatRaw("ai", "Test: " .. response)
    end)

    -- Keyboard
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Return and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
            local ok, msg = executeCode(ScriptContent)
            StatusLabel.Text = ok and "Executed ✓" or tostring(msg)
        end
    end)

    StatusLabel.Text = "Ready (raw GUI fallback)"
end

-- Cleanup old instances
pcall(function()
    local old = (gethui and gethui() or CoreGui or client.PlayerGui):FindFirstChild("OpenCodeLive")
    for _, v in ipairs({old} or {}) do
        if v and v ~= SG then v:Destroy() end
    end
end)
