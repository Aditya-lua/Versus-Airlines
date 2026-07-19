--[[
    Versus-Airlines :: ui/window
    ------------------------------
    Loads the Versus UI library from the official URL and creates the
    main window. Cached in _G so repeated loads of this file don't hit
    the network twice.

    Public API:
        Window.create() -> Library
]]

local Window = {}

local VERSUS_LIBRARY_URL    = "https://versusairlines.top/scripts/NewLibrary.lua"
local WINDOW_LOCATION       = "CoreGui"
local OPEN_CLOSE_LOCATION   = "Top Center"
local THEME_DEFAULT         = "Dark Mode"
local SOUNDS_DEFAULT_DISABLED = true

function Window.create()
    if _G.VersusLibrary then return _G.VersusLibrary end

    local okLoad, libOrErr = pcall(function()
        return loadstring(game:HttpGet(VERSUS_LIBRARY_URL))()
    end)
    if not okLoad or type(libOrErr) ~= "table" then
        error("Versus library load failed: " .. tostring(libOrErr))
    end
    local Library = libOrErr

    local okSetup, uiOrErr = pcall(function()
        return Library:Setup({
            Location        = game:GetService(WINDOW_LOCATION),
            OpenCloseLocation = OPEN_CLOSE_LOCATION,
        })
    end)
    if not okSetup or type(uiOrErr) ~= "table" then
        error("Library:Setup failed: " .. tostring(uiOrErr))
    end

    pcall(function() Library.DisableSounds = SOUNDS_DEFAULT_DISABLED end)
    pcall(function() Library:UpdateUI(THEME_DEFAULT) end)

    _G.VersusLibrary = Library
    _G.VersusUI      = uiOrErr
    return Library
end

return Window
