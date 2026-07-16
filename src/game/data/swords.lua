--[[
    Versus-Airlines :: src/game/data/swords
    -----------------------------------------
    --- Mined from UltimateBloxFruits_Fluent.lua on 2026-07-16.
    --- Do not edit; regenerate from upstream via scripts/mine_data.py. ---

    Format: a single Lua table returned at the bottom of the file.
    Modules load it with `local data = require("src.game.data.swords")`
    (or via the kernel's data registry, slice 4).
]]

return {

        Saber = { Name = "Saber", Level = 200, Sea = 1, ObtainMethod = "Kill Saber Expert boss at Jungle. Spawns every 5 min.", Steps = {"Go to Jungle", "Defeat Saber Expert", "Collect Saber drop"}, RequiredBoss = "Saber Expert", CFrame = CFrame.new(-1458.0, 29.0, -29.0) },
        ["Saber V2"] = { Name = "Saber V2", Level = 300, Sea = 1, ObtainMethod = "Upgrade Saber with 10 Scrap Metal + 5 Magma Ore.", Steps = {"Obtain Saber", "Collect 10 Scrap Metal", "Collect 5 Magma Ore", "Bring to Jungle NPC"}, RequiredItem = "Saber" },
        ["Swan Cutlass"] = { Name = "Swan Cutlass", Level = 500, Sea = 2, ObtainMethod = "Kill Don Swan at Mansion.", Steps = {"Go to Mansion Sea 2", "Defeat Don Swan", "Collect Swan Cutlass"}, RequiredBoss = "Don Swan" },
        ["Dark Dagger"] = { Name = "Dark Dagger", Level = 1500, Sea = 3, ObtainMethod = "Kill Rip Indra at Hydra Island.", Steps = {"Go to Hydra Island Sea 3", "Wait for Rip Indra spawn", "Defeat Rip Indra", "Collect Dark Dagger"}, RequiredBoss = "Rip Indra" },
        ["True Triple Katana"] = { Name = "True Triple Katana", Level = 2000, Sea = 3, ObtainMethod = "Purchase for 3,000 Fragments from sword dealer on Forgotten Island.", Steps = {"Have 3,000 Fragments", "Go to Forgotten Island Sea 3", "Find Sword Dealer", "Purchase for 3,000 Fragments"}, CostFragments = 3000 },
        ["Shark Cutlass"] = { Name = "Shark Cutlass", Level = 700, Sea = 2, ObtainMethod = "Complete Shark NPC quest at Green Zone. Kill 50 Sharks.", Steps = {"Go to Green Zone Sea 2", "Talk to Shark NPC", "Kill 50 Sharks", "Return to NPC" } },
        ["Buddy Sword"] = { Name = "Buddy Sword", Level = 800, Sea = 2, ObtainMethod = "Complete Buddy quest at Kingdom of Rose. Kill 30 Order.", Steps = {"Go to Kingdom of Rose Sea 2", "Find Buddy NPC by castle", "Kill 30 Order enemies", "Return for Buddy Sword" } },
        ["Warden Sword"] = { Name = "Warden Sword", Level = 600, Sea = 1, ObtainMethod = "Complete Warden quest at Prison. Kill 50 Prisoners + 30 Dangerous.", Steps = {"Go to Prison Island Sea 1", "Talk to Warden NPC", "Kill 50 Prisoners", "Kill 30 Dangerous Prisoners", "Return for Warden Sword" } },
        ["Dragon Trident"] = { Name = "Dragon Trident", Level = 1200, Sea = 2, ObtainMethod = "Defeat Dragon boss at Ice Castle.", RequiredBoss = "Dragon" },
        ["Cake Sword"] = { Name = "Cake Sword", Level = 2000, Sea = 3, ObtainMethod = "Defeat Cake Queen at Cake Island.", RequiredBoss = "Cake Queen" },
        ["Coconut Sword"] = { Name = "Coconut Sword", Level = 2200, Sea = 3, ObtainMethod = "Defeat Coconut boss at Tiki Outpost.", RequiredBoss = "Coconut" },
        ["Scythe"] = { Name = "Scythe", Level = 2200, Sea = 3, ObtainMethod = "Kill Soul Reaper at Haunted Castle.", RequiredBoss = "Soul Reaper" },
        ["Longma Sword"] = { Name = "Longma Sword", Level = 1500, Sea = 2, ObtainMethod = "Defeat Longma at Forgotten Island.", RequiredBoss = "Longma" },
        ["Saw Cutlass"] = { Name = "Saw Cutlass", Level = 300, Sea = 1, ObtainMethod = "Defeat The Saw boss near Desert.", RequiredBoss = "The Saw" },
        ["Hallow Sword"] = { Name = "Hallow Sword", Level = 1900, Sea = 3, ObtainMethod = "Craft with 50 Hallow Essence from Rip Indra.", Steps = {"Defeat Rip Indra for Hallow Essence", "Collect 50 Hallow Essence", "Go to Haunted Castle dealer", "Craft Hallow Sword" } },
        ["Yama"] = { Name = "Yama", Level = 1800, Sea = 3, ObtainMethod = "Purchase for 2,000 Fragments at Castle Island.", Steps = {"Go to Castle Island Sea 3", "Find Yama dealer", "Purchase for 2,000 Fragments" }, CostFragments = 2000 },
        ["Tushita"] = { Name = "Tushita", Level = 1900, Sea = 3, ObtainMethod = "Find hidden chest in Hydra Island cave.", Steps = {"Go to Hydra Island Sea 3", "Find hidden cave chest", "Open chest (may need key)", "Collect Tushita" } },
        ["Hawk Sword"] = { Name = "Hawk Sword", Level = 100, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Start Island for $10,000.", Cost = 10000 },
        ["Streaming Sword"] = { Name = "Streaming Sword", Level = 150, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Jungle for $25,000.", Cost = 25000 },
        ["Pipe Sword"] = { Name = "Pipe Sword", Level = 200, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Desert for $50,000.", Cost = 50000 },
        ["Katana"] = { Name = "Katana", Level = 250, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Snow Island for $75,000.", Cost = 75000 },
        ["Dual Katana"] = { Name = "Dual Katana", Level = 300, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Marine Start for $100,000.", Cost = 100000 },
        ["Sword of the Night"] = { Name = "Sword of the Night", Level = 350, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Sky Island for $150,000.", Cost = 150000 },
        ["Koko Sword"] = { Name = "Koko Sword", Level = 400, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Prison for $200,000.", Cost = 200000 },
        ["Spike Sword"] = { Name = "Spike Sword", Level = 450, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Colosseum for $250,000.", Cost = 250000 },
        ["Dual-Headed Blade"] = { Name = "Dual-Headed Blade", Level = 500, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Magma for $300,000.", Cost = 300000 },
        ["Biscuit Hammer"] = { Name = "Biscuit Hammer", Level = 600, Sea = 1, ObtainMethod = "Buy from Sword Dealer at Underwater City for $400,000.", Cost = 400000 },
        ["Electric Sword"] = { Name = "Electric Sword", Level = 700, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Kingdom of Rose for $500,000.", Cost = 500000 },
        ["Dark Blade"] = { Name = "Dark Blade", Level = 800, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Green Zone for $600,000.", Cost = 600000 },
        ["Frost Sword"] = { Name = "Frost Sword", Level = 900, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Snow Mountain for $700,000.", Cost = 700000 },
        ["Twin Hooks"] = { Name = "Twin Hooks", Level = 1000, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Ice Castle for $800,000.", Cost = 800000 },
        ["Shisui"] = { Name = "Shisui", Level = 1100, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Factory for $1,000,000.", Cost = 1000000 },
        ["Rengoku"] = { Name = "Rengoku", Level = 1200, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Fire Island for $1,200,000.", Cost = 1200000 },
        ["Warden Longsword"] = { Name = "Warden Longsword", Level = 1300, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Ship Island for $1,500,000.", Cost = 1500000 },
        ["Canesword"] = { Name = "Canesword", Level = 1400, Sea = 2, ObtainMethod = "Buy from Sword Dealer at Forgotten Island for $1,800,000.", Cost = 1800000 },
        ["Pirate Captain Sword"] = { Name = "Pirate Captain Sword", Level = 1500, Sea = 3, ObtainMethod = "Buy from Sword Dealer at Port Town for $2,000,000.", Cost = 2000000 },
        ["Amazon Sword"] = { Name = "Amazon Sword", Level = 1600, Sea = 3, ObtainMethod = "Buy from Sword Dealer at Amazon Island for $2,500,000.", Cost = 2500000 },
        ["Dragon Sword"] = { Name = "Dragon Sword", Level = 1700, Sea = 3, ObtainMethod = "Buy from Sword Dealer at Hydra Island for $3,000,000.", Cost = 3000000 }

}
