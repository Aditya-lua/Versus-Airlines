-- ╔══════════════════════════════════════════════════════════════╗
-- ║              opencode-live · Roblox Executor AI              ║
-- ║                   deepseek-v4-pro · v4                       ║
-- ╚══════════════════════════════════════════════════════════════╝

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local client = Players.LocalPlayer

local DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
local DEEPSEEK_MODEL = "deepseek-v4-pro"
local CONFIG_FILE = "opencode_live_config.json"
local SCRIPTS_DIR = "opencode_scripts/"
local MAX_TOOL_ROUNDS = 8

-- ── executor capability detection ──
local httpRequest = (syn and syn.request)
    or (http and http.request) or http_request or request
    or (fluxus and fluxus.request) or (krnl and krnl.request)
local g_writefile = writefile; local g_readfile = readfile
local g_isfile = isfile; local g_makefolder = makefolder
local g_listfiles = listfiles; local g_delfile = delfile
local g_setclipboard = setclipboard
local g_identifyexecutor = identifyexecutor

-- ── JSON helpers ──
local function json(v) local o,e=pcall(function()return HttpService:JSONEncode(v)end) return o and e or"null" end
local function unjson(s) local o,e=pcall(function()return HttpService:JSONDecode(s)end) if o then return e end end

-- ── Config persistence ──
local Config = { key="", editor="", editorName="live.lua", theme="dark", fontSize=11,
    activeSession="default", sessions={}, autoSave=true }
local SESSIONS_DIR = "opencode_sessions/"
local CURRENT_SESSION = nil -- name of loaded session (nil = unsaved)
local chist = {} -- chat history (moved up for session loader)

-- ── Session management ──
local function sessionPath(name)
    return SESSIONS_DIR .. name .. ".json"
end

local function saveSession(name)
    if not g_writefile then return end
    name = name or CURRENT_SESSION or Config.activeSession
    pcall(function()
        if g_makefolder then g_makefolder(SESSIONS_DIR) end
        local data = json({ name=name, history=chist, savedAt=os.time(), msgCount=#chist })
        g_writefile(sessionPath(name), data)
    end)
    CURRENT_SESSION = name
end

local function loadSession(name)
    if not g_readfile then return nil end
    local ok, data = pcall(function() return g_readfile(sessionPath(name)) end)
    if not ok or not data then return nil end
    local d = unjson(data)
    if d and d.history then return d end
    return nil
end

local function listSessions()
    if not g_listfiles then return {} end
    local ok, files = pcall(function() return g_listfiles(SESSIONS_DIR) end)
    if not ok then return {} end
    local results = {}
    for _, f in ipairs(files) do
        local name = f:match("([^/]+)%.json$")
        if name then results[#results + 1] = name end
    end
    table.sort(results)
    return results
end

local function deleteSession(name)
    if not g_delfile then return end
    pcall(function() g_delfile(sessionPath(name)) end)
    if CURRENT_SESSION == name then CURRENT_SESSION = nil end
end

local function exportSession(name, fmt)
    name = name or CURRENT_SESSION or "default"
    local d = loadSession(name)
    if not d or not d.history then return nil end
    if fmt == "markdown" or fmt == "md" then
        local lines = {"# opencode-live · " .. name, "", "Saved: " .. os.date("%Y-%m-%d %H:%M:%S", d.savedAt or os.time()), ""}
        for _, m in ipairs(d.history) do
            local role = m.role == "assistant" and "**AI**" or (m.role == "user" and "**You**" or "**" .. m.role .. "**")
            lines[#lines + 1] = role .. ": " .. (m.content or "")
            lines[#lines + 1] = ""
        end
        return table.concat(lines, "\n")
    end
    return json(d.history)
end

-- load active session on startup
local active = loadSession(Config.activeSession)
if active then chist = active.history or {} CURRENT_SESSION = Config.activeSession end

local function saveCfg()
    if not g_writefile then return end
    pcall(function()
        local c = {
            key=Config.key, editorName=Config.editorName, fontSize=Config.fontSize,
            activeSession=Config.activeSession, autoSave=Config.autoSave,
        }
        if #(Config.editor or "") < 50000 then c.editor = Config.editor end
        g_writefile(CONFIG_FILE, json(c))
    end)
end
pcall(function()
    if g_readfile then local d=unjson(g_readfile(CONFIG_FILE)) if d then for k,v in pairs(d)do Config[k]=v end end end
end)

-- ── GUI parent ──
local function host()
    local o,h=pcall(function()return gethui and gethui()end)
    if o and h then return h end
    return game:GetService("CoreGui")
end
pcall(function()local o=host():FindFirstChild("OCLive")if o then o:Destroy()end end)

local G = Instance.new("ScreenGui")
G.Name="OCLive";G.ResetOnSpawn=false;G.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;G.DisplayOrder=9999
G.Parent=host()
if syn and syn.protect_gui then pcall(syn.protect_gui,G)end

-- ── Colors ──
local C={bg=Color3.fromRGB(14,14,18),surf=Color3.fromRGB(22,22,28),accent=Color3.fromRGB(99,102,241),
    text=Color3.fromRGB(230,230,240),mute=Color3.fromRGB(140,140,155),code=Color3.fromRGB(18,18,24),
    green=Color3.fromRGB(34,197,94),red=Color3.fromRGB(239,68,68),yellow=Color3.fromRGB(234,179,8),
    cyan=Color3.fromRGB(34,211,238),pink=Color3.fromRGB(232,121,249),orange=Color3.fromRGB(251,146,60),
    user=Color3.fromRGB(37,99,235),ai=Color3.fromRGB(24,24,30),tool=Color3.fromRGB(15,23,42),
    err=Color3.fromRGB(49,12,12),bord=Color3.fromRGB(38,38,48),scroll=Color3.fromRGB(55,55,70)}

-- ── UI helpers ──
local FB=Enum.Font.GothamBold;local FM=Enum.Font.GothamMedium;local FR=Enum.Font.Gotham;local FF=Enum.Font.RobotoMono
local function make(cls,props)local o=Instance.new(cls)for k,v in pairs(props)do o[k]=v end return o end
local function rnd(obj,n)local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,n or 6)c.Parent=obj return c end
local function strk(obj,col,t)local s=Instance.new("UIStroke")s.Color=col or C.bord;s.Thickness=t or 1;s.Parent=obj return s end
local function pad(obj,l,r,t,b)
    local p=Instance.new("UIPadding")
    p.PaddingLeft=UDim.new(0,l or 8);p.PaddingRight=UDim.new(0,r or l or 8)
    p.PaddingTop=UDim.new(0,t or l or 8);p.PaddingBottom=UDim.new(0,b or t or l or 8)
    p.Parent=obj;return p
end

-- ═══════════════════════ TOOLS ═══════════════════════
local Tools={}

function Tools.eval(args)
    local code=args.code or args.source or args.luau or""
    local fn,err=loadstring(code)
    if not fn then return{ok=false,error="syntax: "..tostring(err)}end
    local out={}
    local function cap(p)return function(...)local a={}for i=1,select("#",...)do a[i]=tostring(select(i,...))end
        out[#out+1]=p..table.concat(a,"\t")end end
    setfenv(fn,setmetatable({print=cap(""),warn=cap("[warn] "),error=cap("[ERROR] ")},{__index=getfenv and getfenv()or _G}))
    local r={pcall(fn)}local ok=table.remove(r,1)
    local ret={}for i=1,#r do ret[i]=tostring(r[i])end
    return{ok=ok,output=table.concat(out,"\n"),returns=ret,error=not ok and tostring(r[1])or nil}
end

function Tools.console(args)
    local lim=math.min(tonumber(args.limit or args.count)or 40,100)
    local errs=args.errors==true;local h=LogService:GetLogHistory()
    local n={[0]="",[1]="",[2]="[warn] ",[3]="[ERROR] "}
    local lines={}
    for i=#h,1,-1 do
        local e=h[i];local l=e.messageType and e.messageType.Value or 0
        if not errs or l>=2 then lines[#lines+1]=n[l]..tostring(e.message)
            if#lines>=lim then break end end
    end
    for i=1,math.floor(#lines/2)do lines[i],lines[#lines-i+1]=lines[#lines-i+1],lines[i]end
    return{lines=lines,count=#lines}
end

function Tools.find(args)
    local q=args.query and string.lower(args.query)
    local t=args.type or args.class;local lim=math.min(tonumber(args.limit)or 40,150)
    local root=args.root or"game";local r
    if root=="game"then r=game elseif root=="workspace"then r=workspace
    elseif root=="players"then r=Players elseif root=="lighting"then r=Lighting
    elseif root=="rs"or root=="replicated"then r=ReplicatedStorage
    else r=game:FindFirstChild(root,true)or workspace end
    if not r then return{ok=false,error="root not found: "..root}end
    local results={}
    for _,inst in ipairs(r:GetDescendants())do
        local match=true
        if q and not string.find(string.lower(inst.Name),q,1,true)then match=false end
        if t and not pcall(function()return inst:IsA(t)end)then match=false end
        if match then results[#results+1]={name=inst.Name,class=inst.ClassName,parent=inst.Parent and inst.Parent.Name or"",}
            if#results>=lim then break end end
    end
    return{matches=results,truncated=#results>=lim}
end

function Tools.inspect(args)
    local path=args.path or"";local inst=game:FindFirstChild(path,true)
    if not inst then return{ok=false,error="not found: "..path}end
    local props={}
    for _,n in ipairs(args.what and type(args.what)=="table"and args.what or{"Name","ClassName","Parent","Archivable","Visible","Transparency","Color","Material","Position","Size","Anchored","CanCollide","Locked","Value","Text","Source","Enabled","Active"})do
        local o,p=pcall(function()return inst[n]end)if o then local v=tostring(p)
            if#v>500 then v=v:sub(1,500).."..."end;props[n]=v end end
    local attr={}
    pcall(function()for k,v in pairs(inst:GetAttributes())do attr[tostring(k)]=tostring(v)end end)
    local children={}
    for _,ch in ipairs(inst:GetChildren())do children[#children+1]=ch.Name.." ("..ch.ClassName..")"end
    return{path=inst:GetFullName(),class=inst.ClassName,properties=props,attributes=attr,nChildren=#children,children=children}
end

function Tools.tree(args)
    local inst=args.path and game:FindFirstChild(args.path,true)or workspace
    if not inst then return{ok=false,error="not found"}end
    local function w(x,d)
        local n={name=x.Name,class=x.ClassName}
        if d>0 then n.children={}
            for _,c in ipairs(x:GetChildren())do n.children[#n.children+1]=w(c,d-1)end
        else n.childCount=#x:GetChildren()end
        return n
    end
    return w(inst,math.min(tonumber(args.depth)or 2,4))
end

function Tools.fetch(args)
    local url=args.url or args.query or""
    if url==""then return{ok=false,error="no url"}end
    local o,b=pcall(function()return game:HttpGet(url)end)
    if not o then return{ok=false,error="fetch failed: "..tostring(b)}end
    if#b>30000 then b=b:sub(1,30000).."\n\n-- TRUNCATED at 30KB ("..(#b).." total)"end
    return{ok=true,content=b,length=#b}
end

function Tools.fs_read(args)
    local n=args.name or args.path or"";if n==""or not g_readfile then return{ok=false,error="no name or no readfile"}end
    local o,d=pcall(function()return g_readfile(n)end)
    if not o then return{ok=false,error="read failed"}end
    if#d>80000 then d=d:sub(1,80000).."\n\n-- TRUNCATED ("..(#d).." total)"end
    return{ok=true,content=d,name=n,length=#d}
end

function Tools.fs_write(args)
    local n=args.name or"live.lua";local d=args.source or args.content or""
    if not g_writefile then return{ok=false,error="no writefile"}end
    pcall(function()g_writefile(n,d)end)return{ok=true,name=n,length=#d}
end

function Tools.fs_list(args)
    local dir=args.dir or args.path or""
    if not g_listfiles then return{ok=false,error="no listfiles"}end
    local o,f=pcall(function()return g_listfiles(dir)end)
    if not o then return{ok=false,error="list failed"}end
    local items={};for _,p in ipairs(f)do items[#items+1]={name=p:match("[^/]+$")or p,path=p,}end
    return{files=items,count=#items}
end

function Tools.fs_delete(args)
    local n=args.name or"";if n==""or not g_delfile then return{ok=false,error="no name or no delfile"}end
    pcall(function()g_delfile(n)end)return{ok=true}
end

function Tools.editor_get()
    return{source=Config.editor or"",name=Config.editorName or"live.lua"}
end

function Tools.editor_set(args)
    Config.editor=args.source or args.content or"";Config.editorName=args.name or Config.editorName;saveCfg()
    return{ok=true}
end

function Tools.game_data(args)
    local d={}
    d.placeId=game.PlaceId;d.jobId=game.JobId;d.playerName=client.Name;d.userId=client.UserId
    d.accountAge=client.AccountAge;d.plotId=client:GetAttribute("PlotId")
    d.fruitCount=client:GetAttribute("FruitCount")or 0;d.maxFruit=client:GetAttribute("MaxFruitCapacity")or 100
    d.sheckles=client:GetAttribute("Sheckles")or 0
    local bal=pcall(function()if PlayerState then return PlayerState:GetLocalReplica().Data.Sheckles end end)
    if bal then d.balance=bal end
    d.night=ReplicatedStorage:FindFirstChild("Night")and ReplicatedStorage.Night.Value
    d.weather=workspace:GetAttribute("ActiveWeather");d.phase=workspace:GetAttribute("ActivePhase")
    d.phaseDuration=workspace:GetAttribute("PhaseDuration")
    local g=workspace:FindFirstChild("Gardens")
    if g then
        local p=g:FindFirstChild("Plot"..tostring(d.plotId or client:GetAttribute("PlotId")or 0))
        if p then
            local plants=p:FindFirstChild("Plants")d.plantCount=plants and#plants:GetChildren()or 0
            local s=p:FindFirstChild("Sprinklers")d.sprinklerCount=s and#s:GetChildren()or 0
        end
    end
    if g then for _,pl in ipairs(g:GetChildren())do
        if pl:GetAttribute("OwnerUserId")==client.UserId then d.hasPlot=true;d.plotName=pl.Name;break end
    end end
    return d
end

function Tools.game_remotes(args)
    local pk=ReplicatedStorage:FindFirstChild("SharedModules")
    pk=pk and pk:FindFirstChild("Packet")
    local ev=pk and pk:FindFirstChild("RemoteEvent")
    if not ev or not ev.GetAttributes then return{ok=false,error="Packet/RemoteEvent not found"}end
    local attrs=ev:GetAttributes();local r={}
    for k,v in pairs(attrs)do if type(k)=="string"then r[#r+1]={name=k,id=tostring(v)}end end
    table.sort(r,function(a,b)return(a.name:lower())<(b.name:lower())end)
    return{remotes=r,count=#r}
end

function Tools.game_modules(args)
    local sm=ReplicatedStorage:FindFirstChild("SharedModules")
    if not sm then return{ok=false,error="SharedModules not found"}end
    local mods={}
    for _,m in ipairs(sm:GetChildren())do if m:IsA("ModuleScript")then
        mods[#mods+1]={name=m.Name,hasRequire=pcall(function()return require(m)end)}end end
    return{modules=mods,count=#mods}
end

function Tools.perf(args)
    local d={}
    d.fps=1/RunService.Stepped:Wait();d.memory=collectgarbage("count")
    local c=client.Character;d.hrp=c and c:FindFirstChild("HumanoidRootPart")
    d.position=d.hrp and{d.hrp.Position.X,d.hrp.Position.Y,d.hrp.Position.Z}or nil
    d.scriptElapsed=time()-(_START or time())
    return d
end

function Tools.help(args)
    return{tools={
        "eval — execute Luau code in-game",
        "console — read recent console output",
        "find — search workspace instances",
        "inspect — dump Instance properties/attributes",
        "tree — explore Instance hierarchy",
        "fetch — HTTP GET a URL",
        "fs_read / fs_write / fs_list / fs_delete — device file ops",
        "editor_get / editor_set — read/write code editor",
        "game_data — get player/game state snapshot",
        "game_remotes — dump all remote event IDs",
        "game_modules — list SharedModules",
        "perf — FPS, memory, position stats",
        "help — this list",
    }}
end

-- alias
Tools.search=Tools.find;Tools.read_file=Tools.fs_read;Tools.write_file=Tools.fs_write
Tools.list_files=Tools.fs_list;Tools.delete_file=Tools.fs_delete
Tools.execute_luau=Tools.eval;Tools.run=Tools.eval
Tools.get_console=Tools.console;Tools.get_editor=Tools.editor_get
Tools.set_editor=Tools.editor_set;Tools.inspect_instance=Tools.inspect
Tools.read_tree=Tools.tree;Tools.web_fetch=Tools.fetch
Tools.game_state=Tools.game_data;Tools.get_remotes=Tools.game_remotes
Tools.get_modules=Tools.game_modules;Tools.performance=Tools.perf

local function runTool(name,input)
    local h=Tools[name]
    if not h then return{ok=false,error="unknown tool: "..tostring(name)..
        "\nTry: eval, find, inspect, game_data, console, fs_read, help"}end
    local o,r=pcall(h,input or{})
    if not o then return{ok=false,error="tool crashed: "..tostring(r)}end
    return r
end

-- ═══════════════════════ AI ═══════════════════════
local SYSTEM = {role="system",content=[[You are opencode-live, an expert Roblox Luau scripting AI with REAL-TIME access to the user's game session via tools.

You CAN:
- Execute code in the running game (eval tool)
- Read the console (console tool)
- Search workspace instances (find tool)
- Inspect any Instance's properties & attributes (inspect)
- Read/write device files (fs_read, fs_write)
- Fetch web URLs (fetch)
- Get game state snapshot (game_data)
- Dump remote event IDs (game_remotes)
- List SharedModules (game_modules)
- Explore Instance trees (tree)
- Read/write the user's code editor (editor_get, editor_set)
- Get performance stats (perf)

TOOL FORMAT — reply with EXACTLY this XML (nothing else):
<tool>tool_name</tool><input>{"key":"value"}</input>

After each tool call, you receive the result. You can chain up to 8 tool calls.
Respond normally when not using tools. Be concise. Write real, working code.
The user is on an Android executor. GAG2/FallHarvest internals are known.]]}

local function callAI(messages)
    if Config.key==""then return nil,"no api key"end
    if not httpRequest then return nil,"no http function"end
    local body=json({model=DEEPSEEK_MODEL,messages=messages,temperature=0.3,max_tokens=4096})
    local o,r=pcall(httpRequest,{Url=DEEPSEEK_URL,Method="POST",
        Headers={["Content-Type"]="application/json",["Authorization"]="Bearer "..Config.key},Body=body})
    if not o or not r then return nil,"http failed"end
    local bs=type(r)=="table"and(r.Body or r.body or tostring(r))or tostring(r)
    local d=unjson(bs)if not d then return nil,"invalid json"end
    if d.error then return nil,"API: "..tostring(d.error.message or d.error)end
    if not d.choices or not d.choices[1]then return nil,"empty response"end
    return d.choices[1].message.content,nil
end

local function parseTool(text)
    local n=text:match("<tool>(.-)</tool>")
    local i=text:match("<input>(.-)</input>")
    if not n then return nil end
    local inp=i and unjson(i)or{}
    return n,inp
end

-- ═══════════════════════ GUI ═══════════════════════
local W=math.min(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 500,500)
local H=math.min(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700,680)

local root=make("Frame",{Size=UDim2.fromOffset(W-40,H-80),Position=UDim2.new(0.5,-(W-40)/2,0.5,-(H-80)/2),
    BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,Draggable=true,Parent=G})
rnd(root,10)strk(root)

-- title bar
local bar=make("Frame",{Size=UDim2.new(1,0,0,36),BackgroundColor3=C.surf,Parent=root})rnd(bar,10)
make("Frame",{Size=UDim2.new(1,0,0,26),Position=UDim2.new(0,0,0,10),BackgroundColor3=C.surf,Parent=bar})
make("TextLabel",{Size=UDim2.new(1,-120,1,0),Text="  opencode-live",TextColor3=C.accent,Font=FB,TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Parent=bar})
local status=make("TextLabel",{Size=UDim2.new(0,180,1,0),Position=UDim2.new(1,-300,0,0),Text="Ready",
    TextColor3=C.mute,Font=FR,TextSize=9,BackgroundTransparency=1,Parent=bar})

for _,x in ipairs{{"×",-34,C.red},{"−",-70,C.text},{"□",-106,C.text}}do
    local b=make("TextButton",{Size=UDim2.fromOffset(30,30),Position=UDim2.new(1,x[2],0,3),
        BackgroundColor3=Color3.fromRGB(30,30,36),Text=x[1],TextColor3=x[3],Font=FB,TextSize=14,Parent=bar})
    rnd(b,6)
    if x[1]=="×"then b.MouseButton1Click:Connect(function()G:Destroy()end)
    elseif x[1]=="−"then
        local vis=true;b.MouseButton1Click:Connect(function()
            vis=not vis;for _,c in ipairs(root:GetChildren())do if c~=bar then c.Visible=vis end end
        end)
    elseif x[1]=="□"then
        b.MouseButton1Click:Connect(function()
            local f=root.Size==UDim2.fromOffset(W-40,H-80)
            if f then root.Size=UDim2.fromOffset(W-40,H-80)root.Position=UDim2.new(0.5,-(W-40)/2,0.5,-(H-80)/2)
            else root.Size=UDim2.new(1,-20,1,-20)root.Position=UDim2.new(0,10,0,10)end
        end)
    end
end

-- tabs
local tabs={}local bodies={}
local tbar=make("Frame",{Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,36),BackgroundColor3=C.bg,Parent=root})
for i,n in ipairs({"Chat","Editor","Console","Sessions","Settings"})do
    local w=1/5
    local t=make("TextButton",{Size=UDim2.new(w,-2,1,-4),Position=UDim2.new((i-1)*w,1,0,2),
        BackgroundColor3=i==1 and C.accent or C.code,Text=n,TextColor3=C.text,Font=FM,TextSize=10,Parent=tbar})
    rnd(t,4)tabs[i]=t
    local b=make("Frame",{Size=UDim2.new(1,0,1,-66),Position=UDim2.new(0,0,0,66),
        BackgroundTransparency=1,Visible=i==1,Parent=root})bodies[i]=b
    t.MouseButton1Click:Connect(function()
        for j,tt in ipairs(tabs)do tt.BackgroundColor3=C.code;bodies[j].Visible=false end
        t.BackgroundColor3=C.accent;b.Visible=true
        if n=="Sessions"then refreshSessions()end
    end)
end

-- ═══ CHAT ═══
local chatB=bodies[1]
local busy=false
local clog=make("ScrollingFrame",{Size=UDim2.new(1,0,1,-76),BackgroundTransparency=1,
    ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Parent=chatB})
local clist=make("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder,Parent=clog})
local cpad=make("UIPadding",{Parent=clog})cpad.PaddingTop=UDim.new(0,4)cpad.PaddingBottom=UDim.new(0,4)
cpad.PaddingLeft=UDim.new(0,4)cpad.PaddingRight=UDim.new(0,4)

local function bubble(role,text)
    local col=role=="user"and C.user or role=="tool"and C.tool or role=="err"and C.err or C.ai
    local tc=role=="tool"and C.cyan or role=="err"and C.red or C.text
    local pf=role=="tool"and"⚙ "or""
    local lbl=make("TextLabel",{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=col,BorderSizePixel=0,Font=role=="tool"and FF or FR,TextSize=Config.fontSize,
        TextColor3=tc,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true,Text=pf..text,Parent=clog})
    rnd(lbl,5)
    local p=make("UIPadding",{Parent=lbl})p.PaddingTop=UDim.new(0,4)p.PaddingBottom=UDim.new(0,4)
    p.PaddingLeft=UDim.new(0,6)p.PaddingRight=UDim.new(0,6)
    task.defer(function()clog.CanvasPosition=Vector2.new(0,clog.AbsoluteCanvasSize.Y)end)
    return lbl
end

local cinput=make("TextBox",{Size=UDim2.new(1,-76,0,60),Position=UDim2.new(0,4,1,-66),
    BackgroundColor3=C.code,BorderSizePixel=0,Font=FR,TextSize=11,TextColor3=C.text,
    PlaceholderText=Config.key==""and"Paste Deepseek API key (sk-...)"or"Ask me anything...",
    ClearTextOnFocus=false,MultiLine=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Parent=chatB})
rnd(cinput,6)pad(cinput,6,6,6,6)

make("TextButton",{Size=UDim2.fromOffset(64,60),Position=UDim2.new(1,-68,1,-66),
    BackgroundColor3=C.accent,Font=FB,TextSize=12,TextColor3=Color3.fromRGB(255,255,255),
    Text="Send",Parent=chatB}).MouseButton1Click:Connect(function()
    if busy then return end
    local t=cinput.Text if#t==0 then return end cinput.Text=""
    if Config.key==""then
        if t:match("^sk%-")then Config.key=t:gsub("\n","")saveCfg()bubble("ai","Key saved. Ask me anything!")end
        return
    end
    bubble("user",t)busy=true;status.Text="Thinking..."
    local msgs={SYSTEM}
    local st=math.max(1,#chist-14)for i=st,#chist do msgs[#msgs+1]=chist[i]end
    msgs[#msgs+1]={role="user",content=t}
    task.spawn(function()
        local r,e
        for s=1,MAX_TOOL_ROUNDS do
            r,e=callAI(msgs)if not r then break end
            local tn,ti=parseTool(r)
            if tn then
                bubble("tool",tn.." "..json(ti))
                msgs[#msgs+1]={role="assistant",content=r}
                local res=runTool(tn,ti)
                msgs[#msgs+1]={role="user",content="Tool result for "..tn..":\n"..json(res)}
            else
                bubble("ai",r)
                chist[#chist+1]={role="user",content=t}
                chist[#chist+1]={role="assistant",content=r}
                if#chist>60 then table.remove(chist,1)table.remove(chist,1)end
                if Config.autoSave then saveSession(CURRENT_SESSION or Config.activeSession) end
                refreshSessions()
                break
            end
        end
        if not r then bubble("err","Error: "..tostring(e or"unknown"))end
        busy=false;status.Text="Ready"
    end)
end)

-- ═══ EDITOR ═══
local editorB=bodies[2]
local ename=make("TextBox",{Size=UDim2.new(1,-8,0,24),Position=UDim2.fromOffset(4,4),
    BackgroundColor3=C.code,BorderSizePixel=0,Font=FR,TextSize=10,TextColor3=C.mute,
    Text=Config.editorName or"live.lua",PlaceholderText="script name...",Parent=editorB})
rnd(ename,4)

local ebox=make("TextBox",{Size=UDim2.new(1,-8,1,-64),Position=UDim2.fromOffset(4,32),
    BackgroundColor3=C.code,BorderSizePixel=0,Font=FF,TextSize=Config.fontSize,
    TextColor3=C.text,Text=(#(Config.editor or"")<60000 and Config.editor or"-- script too large for editor"),
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,Parent=editorB})
rnd(ebox,5)pad(ebox,4)

local function ebtn(t,y,cb)
    local b=make("TextButton",{Size=UDim2.new(1,-8,0,24),Position=UDim2.fromOffset(4,y),
        BackgroundColor3=C.code,Font=FB,TextSize=10,TextColor3=C.text,Text=t,Parent=editorB})
    rnd(b,4)b.MouseButton1Click:Connect(function()pcall(cb)end)return b
end

local ey=ebox.Position.Y.Offset+ebox.Size.Y.Offset+4
ebtn("Run (Ctrl+Enter)",ey,function()
    local code=ebox.Text;Config.editor=code;saveCfg();bubble("tool","Running...")
    local o,r=pcall(function()local fn,err=loadstring(code)if not fn then return nil,err end return fn()end)
    bubble("tool",o and(r~=nil and"→ "..tostring(r)or"done")or"Error: "..tostring(r))
end)
ebtn("Save to Device",ey+28,function()
    Config.editor=ebox.Text;Config.editorName=ename.Text;saveCfg()
    if g_writefile then pcall(function()g_writefile(ename.Text,ebox.Text)end)end
    bubble("tool","Saved: "..ename.Text)
end)
ebtn("Pull from Device",ey+56,function()
    if not g_readfile then return end
    local o,d=pcall(function()return g_readfile(ename.Text)end)
    if o and d and#d<80000 then ebox.Text=d;Config.editor=d;bubble("tool","Loaded: "..ename.Text)end
end)

-- ═══ CONSOLE ═══
local conB=bodies[3]
local conLabel=make("TextLabel",{Size=UDim2.new(1,0,1,-36),BackgroundTransparency=1,
    Font=FF,TextSize=9,TextColor3=C.mute,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Text="Press Refresh",Parent=conB})
pad(conLabel,4)
local function refreshCon()
    local h=LogService:GetLogHistory()local lines={}
    for i=math.max(1,#h-30),#h do
        local e=h[i]local l=e.messageType and e.messageType.Value or 0
        local p=l>=2 and"[!]"or"";lines[#lines+1]=p..tostring(e.message)
    end
    conLabel.Text=table.concat(lines,"\n")
end
make("TextButton",{Size=UDim2.new(1,-8,0,28),Position=UDim2.new(0,4,1,-32),
    BackgroundColor3=C.accent,Font=FB,TextSize=10,TextColor3=Color3.fromRGB(0,0,0),
    Text="Refresh Console",Parent=conB}).MouseButton1Click:Connect(refreshCon)
rnd(conB:FindFirstChildOfClass("TextButton"),4)

-- ═══ SESSIONS ═══
local sesB=bodies[4]
local seslist=make("UIListLayout",{Padding=UDim.new(0,6),Parent=sesB})
pad(sesB,6)

make("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Font=FM,TextSize=11,
    TextColor3=C.text,Text="Chat Sessions",Parent=sesB})

local sesInfo=make("TextLabel",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,Font=FR,TextSize=9,
    TextColor3=C.mute,TextWrapped=true,Text="Active: "..(CURRENT_SESSION or "unsaved"),Parent=sesB})

local sesListFrame=make("ScrollingFrame",{Size=UDim2.new(1,0,1,-220),BackgroundTransparency=1,
    ScrollBarThickness=4,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Parent=sesB})
local sesItems=make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder,Parent=sesListFrame})
pad(sesListFrame,2)

local function sesBtn(parent,text,cb,clr)
    local b=make("TextButton",{Size=UDim2.new(1,0,0,28),BackgroundColor3=clr or C.code,
        Font=FB,TextSize=10,TextColor3=clr and Color3.fromRGB(0,0,0)or C.text,Text=text,Parent=parent})
    rnd(b,4)b.MouseButton1Click:Connect(function()pcall(cb)end)return b
end

function refreshSessions()
    sesInfo.Text="Active: "..(CURRENT_SESSION or"unsaved").." · "..(#chist).." msgs"
    for _,c in ipairs(sesListFrame:GetChildren())do if c:IsA("TextButton")then c:Destroy()end end
    local list=listSessions()
    for _,name in ipairs(list)do
        local row=make("Frame",{Size=UDim2.new(1,0,0,30),BackgroundColor3=C.code,Parent=sesListFrame})
        rnd(row,4)
        make("TextLabel",{Size=UDim2.new(0.6,0,1,0),BackgroundTransparency=1,Font=FR,TextSize=10,
            TextColor3=(name==CURRENT_SESSION and C.accent or C.text),Text="  "..name,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=row})

        local d=loadSession(name)
        local info=make("TextLabel",{Size=UDim2.new(0,200,1,0),Position=UDim2.new(1,-280,0,0),
            BackgroundTransparency=1,Font=FR,TextSize=8,TextColor3=C.mute,
            Text=(d and#d.history or 0).." msgs",TextXAlignment=Enum.TextXAlignment.Right,Parent=row})

        row.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 then
                local d=loadSession(name)
                if d and d.history then
                    chist=d.history;CURRENT_SESSION=name;Config.activeSession=name;saveCfg()
                    clog:ClearAllChildren()
                    for _,m in ipairs(chist)do
                        local role=m.role=="assistant"and"ai"or m.role=="user"and"user"or"tool"
                        bubble(role,m.content)
                    end
                    bubble("ai","Session loaded: "..name.." ("..#chist.." messages)")
                    refreshSessions()
                end
            elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
                deleteSession(name)refreshSessions()
            end
        end)
    end
end

sesBtn(sesB,"Save Current Session",function()
    local name=CURRENT_SESSION or"session_"..os.date("%Y%m%d_%H%M%S")
    saveSession(name)Config.activeSession=name;saveCfg()
    sesInfo.Text="Saved: "..name.." · "..#chist.." msgs"
    bubble("tool","Session saved: "..name)
    refreshSessions()
end,C.green)

sesBtn(sesB,"Save As New Session",function()
    local name="session_"..os.date("%Y%m%d_%H%M%S")
    saveSession(name)Config.activeSession=name;CURRENT_SESSION=name;saveCfg()
    refreshSessions()bubble("tool","New session: "..name)
end)

sesBtn(sesB,"Export as Markdown",function()
    local md=exportSession(nil,"md")
    if md and g_setclipboard then pcall(function()g_setclipboard(md)end)end
    bubble("tool","Session exported"..(g_setclipboard and" (copied)"or""))
end)

sesBtn(sesB,"Export as JSON",function()
    local js=exportSession(nil,"json")
    if js and g_setclipboard then pcall(function()g_setclipboard(js)end)end
    bubble("tool","JSON exported"..(g_setclipboard and" (copied)"or""))
end)

sesBtn(sesB,"Clear Current Chat",function()
    chist={};clog:ClearAllChildren();bubble("ai","Chat cleared. Unsaved changes lost.")
    refreshSessions()
end,C.red)

-- ═══ SETTINGS ═══
local setB=bodies[5]
local slist=make("UIListLayout",{Padding=UDim.new(0,7),Parent=setB})
pad(setB,6)

make("TextLabel",{Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,Font=FM,TextSize=10,
    TextColor3=C.mute,Text="Deepseek API Key (deepseek-v4-pro)",Parent=setB})
local kbox=make("TextBox",{Size=UDim2.new(1,0,0,28),BackgroundColor3=C.code,Font=FR,TextSize=10,
    TextColor3=C.text,Text=Config.key,PlaceholderText="sk-...",Parent=setB})
rnd(kbox,4)kbox.FocusLost:Connect(function()Config.key=kbox.Text;saveCfg()end)

local function sbtn(t,cb,clr)
    local b=make("TextButton",{Size=UDim2.new(1,0,0,28),BackgroundColor3=clr or C.code,
        Font=FB,TextSize=10,TextColor3=clr and Color3.fromRGB(0,0,0)or C.text,Text=t,Parent=setB})
    rnd(b,4)b.MouseButton1Click:Connect(function()pcall(cb)end)return b
end
sbtn("Save & Test API Connection",function()
    Config.key=kbox.Text;saveCfg();status.Text="Testing..."
    local r,e=callAI({{role="user",content="Say OK in one word."}})
    bubble(r and"ai"or"err",r or("Error: "..tostring(e)))status.Text="Ready"
end,C.green)
sbtn("Save GAG2.lua to Device",function()
    local o,d=pcall(function()return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/GAG2.lua")end)
    if o and d and g_writefile then g_writefile("GAG2.lua",d)bubble("tool","GAG2.lua saved")end
end)
sbtn("Save FallHarvest.lua to Device",function()
    local o,d=pcall(function()return game:HttpGet("https://raw.githubusercontent.com/Aditya-lua/Versus-Airlines/main/FallHarvest.lua")end)
    if o and d and g_writefile then g_writefile("FallHarvest.lua",d)bubble("tool","FallHarvest.lua saved")end
end)

make("TextLabel",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,Font=FR,TextSize=9,
    TextColor3=C.mute,TextWrapped=true,
    Text="Model: deepseek-v4-pro\nHTTP: "..(httpRequest and"available ✓"or"none ✗")
        .."\nExecutor: "..(g_identifyexecutor and select(1,g_identifyexecutor())or"unknown")
        .."\nPlaceId: "..game.PlaceId,Parent=setB})

-- ═══ keybinds ═══
UIS.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.Return and(UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl))then
        local code=ebox.Text;Config.editor=code;saveCfg()
        local o,r=pcall(function()local fn,err=loadstring(code)if not fn then return nil,err end return fn()end)
        bubble("tool",o and(r~=nil and"→ "..tostring(r)or"done")or"Error: "..tostring(r))
    end
end)

-- ═══ init ═══
_START=time()
bubble("ai","opencode-live v4 · deepseek-v4-pro\n"..(Config.key==""and"Paste your API key below to start."or"Ready. Ask me anything."))
bubble("tool","Tools: eval · find · inspect · game_data · console · fs_read · fetch · remotes · help")
refreshCon()
status.Text="Ready · "..(httpRequest and"online"or"offline")
