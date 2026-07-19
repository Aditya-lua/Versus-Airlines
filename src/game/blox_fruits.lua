--[[
    Versus-Airlines :: game/blox_fruits
    -------------------------------------
    Game detection for Blox Fruits.

    Public API:
        BloxFruits.new()          -> BloxFruits
        BloxFruits:detectSea()    -> 0 | 1 | 2 | 3
        BloxFruits:getPlaceId()   -> number
        BloxFruits:isInGame()     -> bool
        BloxFruits:summary()      -> { placeId, sea, inGame }
        BloxFruits:reset()        -> nil
]]

local BloxFruits = {}
BloxFruits.__index = BloxFruits

local PLACE_ID_TO_SEA = {
    [2753915549] = 1,
    [4442272183] = 2,
    [7449423635] = 3,
}

local SEA_UNKNOWN = 0

function BloxFruits.new()
    local self = setmetatable({}, BloxFruits)
    self._placeId = nil
    self._sea     = nil
    return self
end

function BloxFruits:detectSea()
    if self._sea ~= nil then return self._sea end
    local placeId = self:getPlaceId()
    self._sea = PLACE_ID_TO_SEA[placeId] or SEA_UNKNOWN
    return self._sea
end

function BloxFruits:getPlaceId()
    if self._placeId ~= nil then return self._placeId end
    local ok, id = pcall(function() return game.PlaceId end)
    if not ok or type(id) ~= "number" then self._placeId = 0 else self._placeId = id end
    return self._placeId
end

function BloxFruits:isInGame()
    return self:detectSea() ~= SEA_UNKNOWN
end

function BloxFruits:summary()
    return {
        placeId = self:getPlaceId(),
        sea     = self:detectSea(),
        inGame  = self:isInGame(),
    }
end

function BloxFruits:reset()
    self._placeId = nil
    self._sea     = nil
end

return BloxFruits
