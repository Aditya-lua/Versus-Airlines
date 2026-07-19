--[[
    Versus-Airlines :: kernel/compat
    ---------------------------------
    Executor capability detection (D6, D10). Called once at boot by
    kernel/init. The rest of the script NEVER branches on executor *name*
    — only on capability *presence* (e.g. `if Compat.canHook then ...`).
    This is the difference between a shim that survives a new executor
    appearing next month and one that breaks the moment anything renames
    itself.

    Two tiers (D10):
        T1 — PC full-hook  (Wave, Fluxus, Synapse, Arceus X PC, PCK, AWP, Trigon Evo)
        T2 — mobile        (Delta, Arceus X mobile, Fluxus Mobile, Codex, KRNL mobile)
    Excluded: Xeno, Solara.

    Public API:
        Compat.detect() -> {
            tier             = 1 | 2,
            canHook          = bool,
            canNamecall      = bool,
            canRequest       = bool,
            canFS            = bool,
            canQueueTeleport = bool,
            canDrawing       = bool,
            canHiddenProp    = bool,
            canGetHui        = bool,
            canSetFflag      = bool,
        }
]]

local Compat = {}

local HOOK_NAMES         = { "hookfunction", "hook_func", "replaceclosure" }
local NAMECALL_NAMES     = { "getnamecallmethod", "getnamecallmethod_local" }
local REQUEST_NAMES      = { "request", "http_request", "http.request" }
local WRITE_FILE_NAMES   = { "writefile" }
local READ_FILE_NAMES    = { "readfile" }
local QUEUE_TP_NAMES     = { "queue_on_teleport", "queueonteleport" }
local DRAWING_NAMES      = { "Drawing" }
local HIDDEN_PROP_NAMES  = { "sethiddenproperty" }
local GET_HUI_NAMES      = { "gethui" }
local SET_FFLAG_NAMES    = { "setfflag" }

local T1_HOOK_REQUIRED    = true
local T1_NAMECALL_REQUIRED = true

local function probe(name)
    local ok, val = pcall(function() return name end)
    if not ok then return nil end
    return val
end

local function hasAny(names)
    for _, name in ipairs(names) do
        if type(probe(name)) == "function" then
            return true
        end
    end
    return false
end

function Compat.detect()
    local canHook         = hasAny(HOOK_NAMES)
    local canNamecall     = hasAny(NAMECALL_NAMES)
    local canRequest      = hasAny(REQUEST_NAMES)
    local canFS           = hasAny(WRITE_FILE_NAMES) and hasAny(READ_FILE_NAMES)
    local canQueueTeleport= hasAny(QUEUE_TP_NAMES)
    local canDrawing      = hasAny(DRAWING_NAMES)
    local canHiddenProp   = hasAny(HIDDEN_PROP_NAMES)
    local canGetHui       = hasAny(GET_HUI_NAMES)
    local canSetFflag     = hasAny(SET_FFLAG_NAMES)

    local tier = (canHook == T1_HOOK_REQUIRED) and (canNamecall == T1_NAMECALL_REQUIRED) and 1 or 2

    return {
        tier             = tier,
        canHook          = canHook,
        canNamecall      = canNamecall,
        canRequest       = canRequest,
        canFS            = canFS,
        canQueueTeleport = canQueueTeleport,
        canDrawing       = canDrawing,
        canHiddenProp    = canHiddenProp,
        canGetHui        = canGetHui,
        canSetFflag      = canSetFflag,
    }
end

return Compat
