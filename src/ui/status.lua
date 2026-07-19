--[[
    Versus-Airlines :: ui/status
    -----------------------------
    Live status label. Updated by the kernel at a slow cadence so the
    user can see at a glance: which executor tier, current sea, FPS,
    modules running, connections, and the last event.

    Public API:
        Status.start(kernel) -> statusHandle
        statusHandle:stop()  -> nil
]]

local Status = {}

local UPDATE_INTERVAL_SEC = 2.0
local FPS_ROUND_HALF      = 0.5
local SEA_PLACE_IDS = {
    [2753915549] = "1",
    [4442272183] = "2",
    [7449423635] = "3",
}
local SEA_UNKNOWN = "?"
local TIER_TAG_HEARTBEAT = "kernel:status"
local TIER_TAG_RENDER    = "kernel:status-fps"

function Status.start(kernel)
    -- 1. Mount the label.
    local label
    if _G.VersusUI and _G.VersusUI.CreateSection then
        local sec = _G.VersusUI:CreateSection("Status")
        if sec and sec.createLabel then
            label = sec:createLabel({
                Name     = "Versus-Airlines :: booting...",
                Special  = true,
                Center   = false,
            })
        end
    end

    -- 2. FPS sampler.
    local frameCount   = 0
    local lastFpsAt    = os.clock()
    local cachedFps    = 0
    local cachedSea    = SEA_UNKNOWN
    local lastEvent    = "started"
    local lastEventT   = os.clock()

    if kernel.events then
        kernel.events:onAny(function(name)
            lastEvent  = name
            lastEventT = os.clock()
        end)
    end

    kernel.conn:bindRenderStepped(function()
        frameCount = frameCount + 1
    end, TIER_TAG_RENDER)

    -- 3. Heartbeat updater.
    kernel.conn:bindHeartbeat(function()
        local now = os.clock()
        if (now - lastFpsAt) < UPDATE_INTERVAL_SEC then return end

        cachedFps = math.floor(frameCount / (now - lastFpsAt) + FPS_ROUND_HALF)
        frameCount = 0
        lastFpsAt = now

        if cachedSea == SEA_UNKNOWN then
            cachedSea = Status:_detectSea()
        end

        if label and label.Set then
            pcall(function()
                label:Set(Status:_formatLine(kernel, cachedFps, cachedSea, lastEvent, math.floor(now - lastEventT)))
            end)
        end
    end, TIER_TAG_HEARTBEAT)

    return {
        stop = function()
            kernel.conn:cleanup(TIER_TAG_HEARTBEAT)
            kernel.conn:cleanup(TIER_TAG_RENDER)
        end,
    }
end

function Status:_detectSea()
    local ok, place = pcall(function() return game.PlaceId end)
    if not ok then return SEA_UNKNOWN end
    return SEA_PLACE_IDS[place] or SEA_UNKNOWN
end

function Status:_formatLine(kernel, fps, sea, lastEvent, lastEventAgeSec)
    local runningCount, totalCount = 0, 0
    if kernel and kernel.registry then
        local list = kernel.registry:list()
        totalCount = #list
        for _, mod in ipairs(list) do
            if mod.running then runningCount = runningCount + 1 end
        end
    end
    local tier    = (kernel and kernel.compat and kernel.compat.tier)  or 0
    local conns   = (kernel and kernel.conn   and kernel.conn:count()) or 0
    local version = (kernel and kernel.version) or "?"
    return string.format(
        "v%s | exec=T%d | sea=%s | fps=%d | modules=%d/%d | conns=%d | last=%s(%ds)",
        version, tier, sea, fps, runningCount, totalCount, conns, lastEvent, lastEventAgeSec
    )
end

return Status
