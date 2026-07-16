--[[
    Versus-Airlines :: ui/sections
    -------------------------------
    Section tree. In slice 5, the toggle callbacks emit a `toggle`
    event to the events system. As module files land in slices 5+,
    they replace the no-op callbacks with kernel.registry:start/stop
    calls.

    Public API:
        Sections.build(Library) -> ui_handle
]]

local Sections = {}

local SECTION_MAIN     = "Main"
local SECTION_FARMING  = "Farming"
local SECTION_FRUITS   = "Fruits"
local SECTION_EVENTS   = "Events"
local SECTION_ESP      = "ESP"
local SECTION_PARTY    = "Party"
local SECTION_SETTINGS = "Settings"
local SECTION_LOGS     = "Logs"

local Flags = {
    AutoFarm         = "AutoFarm",
    BringMob         = "BringMob",
    AutoBoss         = "AutoBoss",
    AutoStat         = "AutoStat",
    AutoEnhance      = "AutoEnhance",
    AutoMastery      = "AutoMastery",
    FruitSniper      = "FruitSniper",
    AutoBuyFruit     = "AutoBuyFruit",
    AutoSeaEvent     = "AutoSeaEvent",
    AutoRaid         = "AutoRaid",
    AutoV4           = "AutoV4",
    ESPEnabled       = "ESPEnabled",
    ESPPlayers       = "ESPPlayers",
    ESPMobs          = "ESPMobs",
    ESPFruits        = "ESPFruits",
    StealthOn        = "StealthOn",
    Humanize         = "Humanize",
    AutoReconnect    = "AutoReconnect",
    WebhookEnabled   = "WebhookEnabled",
}

local SliderFlags = {
    ThrottleMs  = "ThrottleMs",
    ESPDistance = "ESPDistance",
    FarmRadius  = "FarmRadius",
}

local Islands = {
    "Jungle","Buggy","Desert","Snow Island","Marine Start",
    "Sky Island 1","Sky Island 2","Prison","Colosseum",
    "Magma Village","Underwater City","Fountain City",
    "Kingdom of Rose","Green Zone","Factory","Port Town",
    "Hydra Island","Cake Island","Haunted Castle","Tiki Outpost",
}
local StatPriorities = { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
local MasteryWeapons = { "Melee", "Sword", "Blox Fruit", "Gun" }
local Fruits = {
    "Flame","Ice","Dark","Light","Rubber","Barrier","Ghost","Magma","Quake",
    "Buddha","Love","Spider","Phoenix","Rumble","Paw","Gravity","Dough",
    "Shadow","Venom","Control","Spirit","Dragon","Leopard",
}
local Raids = { "Flame","Ice","Dark","Light","Rumble","Magma","Water","Phoenix","Dough" }

function Sections.build(_Library, _kernel)
    local ui = _G.VersusUI
    if not ui then error("Sections.build called before Window.create") end

    local function toggle(name, flagName, default)
        ui:CreateSection(name):createToggle({
            Name     = name,
            Flag     = default == nil and false or default,
            flagName = flagName,
            Callback = function(enabled)
                if _kernel and _kernel.events then
                    _kernel.events:emit("toggle", { flag = flagName, enabled = enabled })
                end
                if _kernel and _kernel.registry then
                    -- Map flagName -> module name. Toggles for not-yet-
                    -- implemented modules are no-ops; the registry
                    -- returns false for unknown names.
                    local moduleName = flagName
                    if enabled then _kernel.registry:start(moduleName)
                    else _kernel.registry:stop(moduleName) end
                end
            end,
        })
    end

    local function dropdown(name, list, default)
        ui:CreateSection(name):createDropdown({
            Name     = name,
            Flag     = default or list[1] or "",
            flagName = "dd_" .. name:gsub("%s+", "_"):lower(),
            List     = list,
        })
    end

    local function slider(name, minValue, maxValue, default, flagName)
        ui:CreateSection(name):createSlider({
            Name     = name,
            minValue = minValue,
            maxValue = maxValue,
            value    = default,
            flagName = flagName or ("sl_" .. name:gsub("%s+", "_"):lower()),
        })
    end

    local function button(name, _label)
        ui:CreateSection(name):createButton({
            Name     = name,
            Callback = function()
                if _kernel and _kernel.events then
                    _kernel.events:emit("button", { name = name })
                end
            end,
        })
    end

    -- Main
    toggle("Auto Farm Level", Flags.AutoFarm, false)
    toggle("Auto Farm Bring", Flags.BringMob, false)
    toggle("Boss Farm",       Flags.AutoBoss, false)
    -- Boss target dropdown. Populated from kernel.boss:list() in a
    -- follow-up; for now default to Saber Expert (the first entry
    -- in the bosses data table).
    ui:CreateSection("Main"):createDropdown({
        Name     = "Select Boss",
        Flag     = "Saber Expert",
        flagName = "SelectBoss",
        List     = { "Saber Expert", "The Saw", "Greybeard", "Diamond", "Jerome",
                     "Fajita", "Captain Elephant", "Order", "Don Swan", "Dragon",
                     "Rip Indra", "Longma", "Hydra", "Admiral", "Soul Reaper",
                     "Ghost", "Coconut", "Cake Queen", "Dough King", "Beautiful Pirate" },
    })
    dropdown("Teleport To", Islands, Islands[1])

    -- Farming
    toggle("Auto Stat",    Flags.AutoStat,    false)
    dropdown("Stat Priority", StatPriorities, StatPriorities[1])
    toggle("Auto Enhance", Flags.AutoEnhance, false)
    toggle("Auto Mastery", Flags.AutoMastery, false)
    dropdown("Mastery Weapon",  MasteryWeapons, MasteryWeapons[1])
    slider("Farm Radius", 50, 500, 150, SliderFlags.FarmRadius)

    -- Fruits
    toggle("Fruit Sniper",   Flags.FruitSniper,  false)
    toggle("Auto Buy Fruit", Flags.AutoBuyFruit, false)
    ui:CreateSection(SECTION_FRUITS):createDropdown({
        Name     = "Fruit to Buy",
        Flag     = Fruits[1] or "Flame",
        flagName = "FruitToBuy",
        List     = Fruits,
    })
    button("Show Inventory", "Show Inventory")

    -- Events
    toggle("Sea Event Farm", Flags.AutoSeaEvent, false)
    toggle("Auto Raid",      Flags.AutoRaid,     false)
    ui:CreateSection(SECTION_EVENTS):createDropdown({
        Name     = "Raid Type",
        Flag     = Raids[1] or "Flame",
        flagName = "RaidType",
        List     = Raids,
    })
    toggle("Race V4 Trial",  Flags.AutoV4,       false)

    -- ESP
    toggle("ESP Enabled",  Flags.ESPEnabled, false)
    toggle("Show Players", Flags.ESPPlayers, true)
    toggle("Show Mobs",    Flags.ESPMobs,    true)
    toggle("Show Fruits",  Flags.ESPFruits,  true)
    slider("ESP Distance", 100, 5000, 1000, SliderFlags.ESPDistance)

    -- Party
    ui:CreateSection(SECTION_PARTY):createInputBox({ Name = "Add Member",    flagName = "PartyAdd"    })
    ui:CreateSection(SECTION_PARTY):createInputBox({ Name = "Remove Member", flagName = "PartyRemove" })
    button("Teleport to Party", "Teleport to Party")

    -- Settings
    toggle("Stealth On",       Flags.StealthOn,     true)
    slider("Throttle (ms)", 50, 1000, 200, SliderFlags.ThrottleMs)
    toggle("Humanize",         Flags.Humanize,      true)
    toggle("Auto Reconnect",   Flags.AutoReconnect, true)
    button("Reconnect Now",  "Reconnect Now")
    button("Save Config",    "Save Config")
    button("Load Config",    "Load Config")

    -- Logs
    ui:CreateSection(SECTION_LOGS):createInputBox({
        Name     = "Webhook URL",
        flagName = "WebhookURL",
        Flag     = "",
    })
    toggle("Webhook Enabled", Flags.WebhookEnabled, true)
    button("Test Webhook", "Test Webhook")

    return ui
end

return Sections
