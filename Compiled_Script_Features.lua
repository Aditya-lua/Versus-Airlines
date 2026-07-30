-- [ +1 Speed Keyboard Escape — Deobfuscated Features & Subsystems ]
-- Reconstructed architectural reference of all main modules and methods.

local ScriptFeatures = {
    -- 1. Movement & Teleportation Suite
    Movement = {
        GetMagnitude = function(m)
            -- Calculates Euclidean distance between point/CFrame m and PrimaryPart
        end,
        GetTo = function(m)
            -- Safe PivotTo wrapper; checks that IsTeleporting is false
        end,
        Teleport = function(m)
            -- Repeat-until CFrame teleport loop until Magnitude < 1
        end,
        MoveTo = function(targetVec3)
            -- Precision CFrame teleport with velocity zeroing and temporary anchoring
        end,
    },

    -- 2. Automation & External Integrations
    Automation = {
        Webhook = function(url, payloadTable)
            -- Detects exploit request API, JSON encodes payload, sends POST request
        end,
        ClickUI = function(guiObject)
            -- Focuses button, sets SelectedObject, simulates Return key down/up events
        end,
        GetImageURL = function(assetId)
            -- Fetches 420x420 PNG URL from Roblox Thumbnail web API with caching
        end,
        PlayAnimation = function(animationIdTrack)
            -- Stops existing Animator tracks and loads/plays custom AnimationId
        end,
    },

    -- 3. Utility & Lifecycle Engine (r.Utils)
    Utils = {
        Connections = function(event, callback, cacheKey)
            -- Error-caught event connection with auto-disconnect on unload
        end,
        Disconnect = function(cacheKey)
            -- Disconnects cached event handle
        end,
        StartLoop = function(name, callback)
            -- Background thread loop managed by toggle state
        end,
        Fallback = function(name, threshold, fallbackFn)
            -- Retry threshold counter for stuck routines
        end,
    },

    -- 4. Anti-Cheat Bypass & Character Manipulation (r.Misc)
    Misc = {
        BypassWalkSpeed = function()
            -- Hooks getrawmetatable(game).__index to return 16 when WalkSpeed is read
        end,
        FreezeAndClone = function()
            -- Freezes real character, spawns anchored scriptless Checkpoint clone, locks Camera
        end,
        UnfreezeAndDeleteClone = function()
            -- Restores character transparencies, removes clone, returns Camera to Custom
        end,
        EnableNoInput = function()
            -- Sinks all input via ContextActionService (priority 999999), shows '[START]' UI
        end,
        DisableNoInput = function()
            -- Restores PlayerModule controls and unbinds input block action
        end,
    },

    -- 5. Auto-Buy & Shop Automation
    Shop = {
        AutoBuyRarity = function(rarityList)
            -- Parses ItemShopModal, checks 'Sold out' / stock ratio (%d+/), fires BuyWins
        end,
    },

    -- 6. Hazard & Obstacle Handlers (NPC & Piege)
    Hazards = {
        AvoidKillBall = "Monitors BallSpawn / KillBall positions",
        TsunamiTimer = "Reads Tsunami1 stage countdown GUI",
        EyesLaser = "Detects active lasers in Stage 9",
        MovingWalls = "Synchronizes with Stage 9 wall cycles",
    }
}

return ScriptFeatures
