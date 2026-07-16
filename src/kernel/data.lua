--[[
    Versus-Airlines :: kernel/data
    -------------------------------
    Loads every data file under src/game/data/ and publishes them as
    kernel.data.<name>. Modules read from this table instead of doing
    their own file I/O.

    Public API:
        Data.new(services)         -> Data
        Data:loadAll()             -> { name = ok_bool }
        Data:get(name)             -> table | nil
        Data:list()                -> { name }
        Data:health()              -> { loaded, failed, missing }
        Data:reset()               -> nil
        Data:setEmitter(emitFn)    -> nil
]]

local Data = {}
Data.__index = Data

local DATA_FILES = {
    { name = "sea1_quests",    file = "src/game/data/sea1_quests.lua" },
    { name = "sea2_quests",    file = "src/game/data/sea2_quests.lua" },
    { name = "sea3_quests",    file = "src/game/data/sea3_quests.lua" },
    { name = "bosses",         file = "src/game/data/bosses.lua" },
    { name = "swords",         file = "src/game/data/swords.lua" },
    { name = "fighting_styles",file = "src/game/data/fighting_styles.lua" },
    { name = "fruits",         file = "src/game/data/fruits.lua" },
    { name = "accessories",    file = "src/game/data/accessories.lua" },
    { name = "guns",           file = "src/game/data/guns.lua" },
    { name = "materials",      file = "src/game/data/materials.lua" },
    { name = "raids",          file = "src/game/data/raids.lua" },
    { name = "race_v4",        file = "src/game/data/race_v4.lua" },
    { name = "sea_events",     file = "src/game/data/sea_events.lua" },
    { name = "islands",        file = "src/game/data/islands.lua" },
    { name = "quest_npcs",     file = "src/game/data/quest_npcs.lua" },
    { name = "fruit_dealers",  file = "src/game/data/fruit_dealers.lua" },
    { name = "enemy_spawn_db", file = "src/game/data/enemy_spawn_db.lua" },
}

function Data.new(_services)
    local self = setmetatable({}, Data)
    self._emit    = nil
    self._tables = {}
    self._health = { loaded = 0, failed = 0, missing = 0 }
    return self
end

function Data:setEmitter(emitFn)
    self._emit = emitFn
end

function Data:loadAll()
    self._health = { loaded = 0, failed = 0, missing = 0 }
    for _, entry in ipairs(DATA_FILES) do
        local ok, result = self:_loadOne(entry.name, entry.file)
        if ok then
            self._health.loaded = self._health.loaded + 1
            self._tables[entry.name] = result
        elseif result == "missing" then
            self._health.missing = self._health.missing + 1
        else
            self._health.failed = self._health.failed + 1
        end
    end
    return {
        loaded  = self._health.loaded,
        failed  = self._health.failed,
        missing = self._health.missing,
    }
end

function Data:get(name)
    return self._tables[name]
end

function Data:list()
    local out = {}
    for name, _ in pairs(self._tables) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Data:health()
    return {
        loaded  = self._health.loaded,
        failed  = self._health.failed,
        missing = self._health.missing,
    }
end

function Data:reset()
    self._tables = {}
    self._health = { loaded = 0, failed = 0, missing = 0 }
end

function Data:_loadOne(name, path)
    local exists = false
    pcall(function()
        local f = io.open(path, "r")
        if f then f:close(); exists = true end
    end)
    if not exists then return false, "missing" end

    local chunk, loadErr = loadfile(path)
    if not chunk then return false, "error" end

    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return false, "error" end
    return true, result
end

return Data
