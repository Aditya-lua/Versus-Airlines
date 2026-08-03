--[[
    Versus-Airlines :: src/game/data/fighting_styles
    -----------------------------------------
    --- Mined from UltimateBloxFruits_Fluent.lua on 2026-07-16.
    --- Do not edit; regenerate from upstream via scripts/mine_data.py. ---

    Format: a single Lua table returned at the bottom of the file.
    Modules load it with `local data = require("src.game.data.fighting_styles")`
    (or via the kernel's data registry, slice 4).
]]

return {

        ["Dark Step"] = { Name = "Dark Step", Level = 200, Sea = 1, Cost = 80000, Location = "Prison Island", CFrame = CFrame.new(5300.0, 0.3, 470.0), NPCName = "Dark Step Teacher" },
        ["Sky Walk"] = { Name = "Sky Walk", Level = 200, Sea = 1, Cost = 100000, Location = "Sky Island 1", CFrame = CFrame.new(-4840.0, 715.0, -2625.0), NPCName = "Sky Walk Teacher" },
        ["Geppo"] = { Name = "Geppo", Level = 300, Sea = 1, Cost = 150000, Location = "Sky Island 2", CFrame = CFrame.new(-7900.0, 5635.0, -1415.0), NPCName = "Geppo Teacher" },
        ["Electric"] = { Name = "Electric", Level = 400, Sea = 1, Cost = 250000, Location = "Jungle", CFrame = CFrame.new(-1600.0, 35.0, 150.0), NPCName = "Electric Teacher" },
        ["Water Kung Fu"] = { Name = "Water Kung Fu", Level = 600, Sea = 1, Cost = 450000, Location = "Underwater City", CFrame = CFrame.new(61100.0, 18.0, 1575.0), NPCName = "Water Teacher" },
        ["Dragon"] = { Name = "Dragon", Level = 800, Sea = 2, Cost = 1500000, Location = "Kingdom of Rose", CFrame = CFrame.new(-3950.0, 15.0, -2100.0), NPCName = "Dragon Teacher" },
        ["Superhuman"] = { Name = "Superhuman", Level = 1000, Sea = 2, Cost = 3000000, Location = "Kingdom of Rose", CFrame = CFrame.new(-3800.0, 15.0, -2200.0), NPCName = "Superhuman Teacher", Requirements = {"Electric", "Water Kung Fu", "Dragon", "Dark Step"} },
        ["Death Step"] = { Name = "Death Step", Level = 1200, Sea = 2, Cost = 5000000, Location = "Ice Castle", CFrame = CFrame.new(7100.0, 25.0, -6800.0), NPCName = "Death Step Teacher", Requirements = {"Superhuman", "5,000 Fragments"} },
        ["Sanguine Art"] = { Name = "Sanguine Art", Level = 2000, Sea = 3, Cost = 8000000, Location = "Haunted Castle", CFrame = CFrame.new(-9550.0, 68.0, 6100.0), NPCName = "Sanguine Teacher", Requirements = {"Death Step", "10,000 Fragments"} },
        ["Dragon Talon"] = { Name = "Dragon Talon", Level = 1500, Sea = 3, Cost = 6000000, Location = "Castle Island", CFrame = CFrame.new(-5400.0, 50.0, -5200.0), NPCName = "Dragon Talon Teacher", Requirements = {"Dragon", "5,000 Fragments"} },
        ["Godhuman"] = { Name = "Godhuman", Level = 2000, Sea = 3, Cost = 10000000, Location = "Forgotten Island", CFrame = CFrame.new(-3100.0, 240.0, -10100.0), NPCName = "Godhuman Teacher", Requirements = {"Superhuman", "Death Step", "Sanguine Art", "Electric", "10,000 Fragments"} }

}
