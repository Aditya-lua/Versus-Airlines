-- Services
local client = game:GetService("Players").LocalPlayer
local request = (syn and syn.request) or (http and http.request) or http_request;
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LightingService = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Library Setup
print("Loading Library...")
local Library = loadstring(game:HttpGet("https://versusairlines.top/scripts/NewLibrary.lua"))()
local Setup = Library:Setup({
    Location = CoreGui,
    OpenCloseLocation = "Top Center"
})

-- Anti-Idle
client.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-- Helpers
local function interval(tag, flag, delayTime, callback)
    Library:CleanupConnectionsByTag(tag)
    if not Library.Flags[flag] then return end
    local last = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not Library.Flags[flag] then
            Library:CleanupConnectionsByTag(tag)
            return
        end
        local now = os.clock()
        if now - last >= delayTime then
            last = now
            pcall(callback)
        end
    end)
    Library:TrackConnection(conn, tag)
end

local function notify(title, desc, style)
    Library:createDisplayMessage(title, desc, {
        { text = "OK" },
    }, style or "info")
end

local function prettyPrint(data, indent)
    indent = indent or 0
    local prefix = string.rep("    ", indent)
    if type(data) ~= "table" then
        print(prefix .. tostring(data))
        return
    end
    for k, v in pairs(data) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. " = {")
            prettyPrint(v, indent + 1)
            print(prefix .. "}")
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

----------------------------------------------------------------- https://versusairlines.top/developers.html
-- Routes
local Routes = {
    ["World 1"] = {
        ["1 Win"] = {
            TargetWinBlock = "workspace.Structure.Stage2.WinBlock1",
            Waypoints = {
                Vector3.new(2.81,7.68,129.98),
                Vector3.new(-0.48,7.68,284.92),
                Vector3.new(-13.25,11.31,285.25),
            }
        },
        ["3 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage3.WinBlock2",
            Waypoints = {
                Vector3.new(50.45,7.68,399.32),
                Vector3.new(.22,7.68,504.8),
                Vector3.new(-16.12,10.65,507.26),
            }
        },
        ["10 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage4.WinBlock3",
            Waypoints = {
                Vector3.new(-12.28,7.68,526.86),
                Vector3.new(-15.79,7.68,559.83),
                Vector3.new(-16.23,49.29,677.16),
                Vector3.new(-15.94,75.96,757.34),
                Vector3.new(-15.92,77.92,774.04),
            }
        },
        ["20 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage5.WinBlock4",
            Waypoints = {
                Vector3.new(1.09,77.14,789.13),
                Vector3.new(2.33,77.14,817.71),
                Vector3.new(3.68,77.14,900.07),
                Vector3.new(3.89,77.14,945.26),
                Vector3.new(3.80,77.14,1013.27),
                Vector3.new(-3.04,77.14,1103.80),
                Vector3.new(-14.89,78.94,1108.95),
            }
        },
        ["50 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage6.WinBlock5",
            Waypoints = {
                Vector3.new(-0.39,77.14,1125.59),
                Vector3.new(-0.17,77.14,1151.55),
                Vector3.new(1.67,77.14,1358.60),
                Vector3.new(2.12,77.14,1410.29),
                Vector3.new(-20.89,78.4,1412.88),
            }
        },
        ["100 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage7.WinBlock6",
            Waypoints = {
                Vector3.new(1.71,75.96,1420.83),
                Vector3.new(-126.49,53.31,1444.94),
                Vector3.new(-433.16,53.31,1463.62),
                Vector3.new(-546.43,53.32,1463.7),
                Vector3.new(-539.85,55.15,1448.3),
            }
        },
        ["150 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage8.WinBlock7",
            Waypoints = {
                Vector3.new(-712.52,53.32,1465.25),
                Vector3.new(-1007.36,53.32,1466.5),
                Vector3.new(-1008.4,55.29,1451.05),
            }
        },
        ["300 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage9.WinBlock8",
            Waypoints = {
                Vector3.new(-1028.58,54.50,1467.10),
                Vector3.new(-1087.28,58.04,1467.11),
                Vector3.new(-1093.82,296.50,1466.77),
                Vector3.new(-1121.53,296.50,1464.99),
                Vector3.new(-1123.63,298.61,1452.2),
            }
        },
        ["500 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage10.WinBlock9",
            Waypoints = {
                Vector3.new(-1133.99,296.50,1466.29),
                Vector3.new(-1185.22,296.61,1466.74),
                Vector3.new(-1244.5,303.80,1467.25),
                Vector3.new(-1368.79,282.47,1468.33),
                Vector3.new(-1379.12,291.39,1468.48),
                Vector3.new(-1390.21,302.46,1468.64),
                Vector3.new(-1401.94,314.20,1468.82),
                Vector3.new(-1414.42,326.69,1469.01),
                Vector3.new(-1422.28,334.55,1469.10),
                Vector3.new(-1436.97,336.87,1469.23),
                Vector3.new(-1467.19,336.87,1469.49),
                Vector3.new(-1506.06,336.87,1469.83),
                Vector3.new(-1624.22,321.27,1470.85),
                Vector3.new(-1778.99,291.09,1472.18),
                Vector3.new(-1818.14,301.58,1472.52),
                Vector3.new(-1861.72,317.34,1472.83),
                Vector3.new(-2045.2,307.45,1474.42),
                Vector3.new(-2155.3,317.38,1475.39),
                Vector3.new(-2175.94,324.53,1475.57),
                Vector3.new(-2279.1,314.07,1476.47),
                Vector3.new(-2307.45,314.07,1476.71),
                Vector3.new(-2342.51,325.01,1477.02),
                Vector3.new(-2429.93,322.77,1474.25),
                Vector3.new(-2494.78,322.76,1472.55),
                Vector3.new(-2523.56,322.77,1486.14),
                Vector3.new(-2650.38,294.27,1499.56),
                Vector3.new(-2703.93,294.27,1484.21),
                Vector3.new(-2786.51,308.04,1472.55),
                Vector3.new(-2880.38,283.33,1474.26),
                Vector3.new(-2972.13,296.50,1468.36),
                Vector3.new(-2973.39,299.56,1449.55),
            }
        },
        ["1000 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage11.WinBlock10",
            Waypoints = {
                Vector3.new(-3251.58,295.32,1468.47),
                Vector3.new(-3732.62,295.32,1464.91),
                Vector3.new(-3943.55,295.32,1466.12),
                Vector3.new(-3939.01,299.56,1447.85),
            }
        },
        ["2500 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage12.WinBlock11",
            Waypoints = {
                Vector3.new(-3944.82,296.50,1465.57),
                Vector3.new(-3992.31,296.50,1463.09),
                Vector3.new(-4186.61,296.50,1464.14),
                Vector3.new(-4302.06,296.48,1467.15),
                Vector3.new(-4308.52,371.21,1467.09),
                Vector3.new(-4294.34,448.33,1502.85),
                Vector3.new(-4298.7,504.16,1525.44),
                Vector3.new(-4298.7,497.07,1525.44),
                Vector3.new(-4309.03,472.36,1527.47),
                Vector3.new(-4366.92,471.01,1526.97),
                Vector3.new(-4368.75,474.62,1513.47),
            }
        },
        ["10000 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage13.WinBlock12",
            Waypoints = {
                Vector3.new(-4584.82,469.65,1529.69),
                Vector3.new(-4628.37,469.65,1141.16),
                Vector3.new(-5046.67,469.65,1588.44),
                Vector3.new(-5266.65,469.65,1477.57),
                Vector3.new(-5341.57,469.43,1477.3),
                Vector3.new(-5341.17,472.4,1459.22),
            }
        },
        ["25000 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage14.WinBlock13",
            Waypoints = {
                Vector3.new(-5398.84,476.83,1480.4),
                Vector3.new(-5902.1,486.11,1565.53),
                Vector3.new(-6479.85,488.56,1388.15),
                Vector3.new(-6808.44,520.43,1487.06),
                Vector3.new(-6808.57,523.6,1470.37),
            }
        },
        ["50000 Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage15.WinBlock14",
            Waypoints = {
                Vector3.new(-6858.1,551.99,1489.02),
                Vector3.new(-8308.83,551.99,1489.02),
                Vector3.new(-8345.8,484.49,1489.52),
                Vector3.new(-8353.04,490.49,1468.88),
            }
        },
        ["150K Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage15.WinBlock14",
            Waypoints = {
                Vector3.new(-8453.98,484.49,1490.244),
                Vector3.new(-8802.23,500.14,1486.852),
                Vector3.new(-9143.41,503.41,1393.124),
                Vector3.new(-9375.97,505.18,1388.144),
                Vector3.new(-9507.49,506.27,1484.711),
                Vector3.new(-9899.78,500.40,1484.911),
                Vector3.new(-10160.3,504.36,1484.862),
                Vector3.new(-10253.13,504.21,1485.302),
                Vector3.new(-10256.06,527.41,1593.329),
                Vector3.new(-10352.32,436.98,1716.224),
                Vector3.new(-10360.53,442.96,1792.248),
                Vector3.new(-10360.24,545.07,2339.724),
                Vector3.new(-10359.65,745.49,3417.401),
                Vector3.new(-10474.12,751.02,3580.787),
                Vector3.new(-10684.21,751.61,3579.589),
                Vector3.new(-10745.23,808.04,3586.674),
                Vector3.new(-12045.39,804.50,3574.341),
                Vector3.new(-12118.14,751.43,3576.324),
                Vector3.new(-13209.91,750.54,3586.828),
                Vector3.new(-13406.26,750.54,3679.525),
                Vector3.new(-13424.09,750.54,3382.024),
                Vector3.new(-13625.38,750.54,3349.125),
                Vector3.new(-13632.23,750.54,3198.804),
                Vector3.new(-13869.61,750.54,3224.189),
                Vector3.new(-13718.49,750.54,3448.185),
                Vector3.new(-13709.48,750.54,3779.334),
                Vector3.new(-13637.45,750.54,3975.037),
                Vector3.new(-13989.7,750.54,3964.212),
                Vector3.new(-13994.57,750.54,3172.296),
                Vector3.new(-14002.12,750.54,3097.345),
                Vector3.new(-14001.91,754.54,3067.99),
            }
        },
    },
    ["World 2"] = {
        ["250K Wins"] = {
            TargetWinBlock = "workspace["WORLD 2"].Winblocks.WinBlock16",
            Waypoints = {
                Vector3.new(-393.47,505.00,-44.82),
                Vector3.new(-393.71,504.09,2.43),
                Vector3.new(-400.65,504.09,74.35),
                Vector3.new(-402.55,504.09,136.23),
                Vector3.new(-415.55,500.99,189.32),
            }
        },
        ["400K Wins"] = {
            TargetWinBlock = "workspace["WORLD 2"].Winblocks.WinBlock17",
            Waypoints = {
                Vector3.new(-399.46,498.99,198.01),
                Vector3.new(-399.82,498.99,267.71),
                Vector3.new(-400.21,498.99,341.16),
                Vector3.new(-400.58,498.99,412.84),
                Vector3.new(-416.32,500.83,433.69),
            }
        },
        ["600K Wins"] = {
            TargetWinBlock = "workspace['WORLD 2'].Winblocks.WinBlock18",
            Waypoints = {
                Vector3.new(-398.2,500.03,463.03),
                Vector3.new(-347.46,500.03,469.68),
                Vector3.new(-349.14,527.10,573.13),
                Vector3.new(-447.89,527.10,576.56),
                Vector3.new(-452.08,554.10,472.30),
                Vector3.new(-352.86,554.10,465.77),
                Vector3.new(-349.44,581.17,571.67),
                Vector3.new(-454.37,581.17,573.74),
                Vector3.new(-448.42,608.17,475.03),
                Vector3.new(-398.27,608.17,473.62),
                Vector3.new(-398.65,607.96,597.59),
                Vector3.new(-417.61,608.64,607.74),
            }
        },
        ["1M Wins"] = {
            TargetWinBlock = "workspace['WORLD 2'].Winblocks.WinBlock19",
            Waypoints = {
                Vector3.new(-398.68,606.78,608.25),
                Vector3.new(-418.31,608.6,841.45),
            }
        },
        ["1.5M Wins"] = {
            TargetWinBlock = "workspace['WORLD 2'].Winblocks.WinBlock20",
            Waypoints = {
                Vector3.new(-400.1,606.34,844.76),
                Vector3.new(-400.4,606.34,1069.42),
                Vector3.new(-398.86,606.34,1260.08),
                Vector3.new(-415.33,608.22,1261.47),
            }
        },
        ["2.5M Wins"] = {
            TargetWinBlock = "workspace["WORLD 2"].Winblocks.WinBlock21",
            Waypoints = {
                Vector3.new(-398.84,607.52,1287.80),
                Vector3.new(-399.64,619.24,1332.89),
                Vector3.new(-393.64,607.52,1455.49),
                Vector3.new(-391.58,607.52,1463.43),
                Vector3.new(-386.61,607.54,1477.10),
                Vector3.new(-364.94,627.82,1540.56),
                Vector3.new(-364.42,628.31,1600.44),
                Vector3.new(-362.27,605.40,1723.56),
                Vector3.new(-362.05,605.40,1752.47),
                Vector3.new(-368.45,616.15,1789.31),
                Vector3.new(-398.33,607.52,1884.31),
                Vector3.new(-401.3,607.52,1917.52),
                Vector3.new(-401.18,618.63,1956.97),
                Vector3.new(-398.73,607.52,2098.80),
                Vector3.new(-399.39,618.21,2136.59),
                Vector3.new(-401.83,607.52,2276.35),
                Vector3.new(-402.5,624.35,2314.60),
                Vector3.new(-404.03,624,2402.70),
                Vector3.new(-417.27,624,2415.65),
            }
        },
        ["4M Wins"] = {
            TargetWinBlock = "workspace["WORLD 2"].Winblocks.WinBlock22",
            Waypoints = {
                Vector3.new(-400.82,623.41,2632.3),
                Vector3.new(-417.27,621.4,2650.78),
            }
        },
        ["6M Wins"] = {
            TargetWinBlock = "workspace["WORLD 2"].Winblocks.WinBlock23",
            Waypoints = {
                Vector3.new(-400.52,623.43,3153.41),
                Vector3.new(-417.27,621.22,3158.65),
            }
        },
        ["10M Wins"] = {
            TargetWinBlock = "workspace["WORLD 2"].Winblocks.WinBlock24",
            Waypoints = {
                Vector3.new(-389.13,623.43,3336.43),
                Vector3.new(-196.84,623.43,3348.66),
                Vector3.new(-165.79,623.43,3259.28),
                Vector3.new(-111.84,623.43,3267.77),
                Vector3.new(-114.05,623.43,3423.23),
                Vector3.new(-272.18,623.43,3438.41),
                Vector3.new(-252.02,623.43,3627.99),
                Vector3.new(-549.29,623.43,3618.9),
                Vector3.new(-566.19,623.43,3800.48),
                Vector3.new(-125.02,623.43,3798.86),
                Vector3.new(-117.85,623.43,3869.58),
                Vector3.new(-61.37,623.5,3868.81),
                Vector3.new(-59.9,624.76,3881.49),
            }
        },
        ["15M Wins"] = {
            TargetWinBlock = "workspace.Winblocks.WinBlock25",
            Waypoints = {
                Vector3.new(-32.21,624.22,3864.24),
                Vector3.new(1177.52,625.06,3866.53),
                Vector3.new(1211.29,624.74,3866.80),
                Vector3.new(1228.42,621.59,3908.94),
            }
        },
        ["25M Wins"] = {
            TargetWinBlock = "workspace.Winblocks.WinBlock27",
            Waypoints = {
                Vector3.new(1321.79,619.60,3864.47),
                Vector3.new(1541.89,628.48,3799.19),
                Vector3.new(1741.58,638.05,3943.17),
                Vector3.new(1950.87,635.78,3800.74),
                Vector3.new(2081.97,642.01,3958.54),
                Vector3.new(2294.80,629.97,3870.72),
                Vector3.new(2390.38,629.42,3871.08),
                Vector3.new(2400.21,625.54,3887.94),
            }
        },
        ["40M Wins"] = {
            TargetWinBlock = "workspace.Winblocks.WinBlock28",
            Waypoints = {
                Vector3.new(2435.81,627.63,3871.18),
                Vector3.new(2490.45,639.51,3871.59),
                Vector3.new(2546.37,639.63,3869.79),
                Vector3.new(2703.03,634.63,3865.92),
                Vector3.new(2742.21,628.97,3869.99),
                Vector3.new(2742.21,575.63,3869.99),
                Vector3.new(2768.79,575.63,3870.23),
                Vector3.new(2825.36,575.63,3870.73),
                Vector3.new(2864.97,582.33,3871.07),
                Vector3.new(2884.59,592.78,3871.28),
                Vector3.new(2916.35,604.52,3871.55),
                Vector3.new(2972.13,576.61,3870.13),
                Vector3.new(2999.43,576.61,3871.04),
                Vector3.new(3047.81,591.50,3871.40),
                Vector3.new(3217.29,592.61,3872.60),
                Vector3.new(3263.77,592.63,3871.93),
                Vector3.new(3269.21,590.63,3887.94),
            }
        },
        ["60M Wins"] = {
            TargetWinBlock = "workspace.Winblocks.WinBlock29",
            Waypoints = {
                Vector3.new(3324.58,668.46,3872.93),
                Vector3.new(3344.39,666.98,3947.49),
                Vector3.new(3340.76,670.38,4159.59),
                Vector3.new(3340.76,670.38,4259.59),
                Vector3.new(3340.76,670.38,4359.59),
                Vector3.new(3340.76,670.38,4459.59),
                Vector3.new(3340.76,670.38,4559.59),
                Vector3.new(3340.76,670.38,4659.59),
                Vector3.new(3340.76,670.38,4759.59),
                Vector3.new(3340.76,670.38,4859.59),
                Vector3.new(3340.76,670.38,4959.59),
                Vector3.new(3440.61,666.36,5144.65),
                Vector3.new(3540.61,666.36,5144.65),
                Vector3.new(3640.61,666.36,5144.65),
                Vector3.new(3740.61,666.36,5144.65),
                Vector3.new(3840.61,666.36,5144.65),
                Vector3.new(3940.61,666.36,5144.65),
                Vector3.new(4040.61,666.36,5144.65),
                Vector3.new(4140.61,666.36,5144.65),
                Vector3.new(4240.61,666.36,5144.65),
                Vector3.new(4340.61,666.36,5144.65),
                Vector3.new(4440.61,666.36,5144.65),
                Vector3.new(4540.61,666.36,5144.65),
                Vector3.new(4613.28,664.56,5141.97),
                Vector3.new(4634.11,565.7,5159.4),
            }
        },
        ["100M Wins"] = {
            TargetWinBlock = "workspace.Winblocks.WinBlock30",
            Waypoints = {
                Vector3.new(4650.84,566.84,5143.59),
                Vector3.new(4717.82,565.83,5142.59),
                Vector3.new(4808.75,592.92,5144.15),
                Vector3.new(4879.62,566.20,5142.28),
                Vector3.new(4913.15,568.72,5023.33),
                Vector3.new(4912.98,676.88,5023.31),
                Vector3.new(4805.10,675.12,5036.15),
                Vector3.new(4681.35,674.53,5038.30),
                Vector3.new(4675.33,673.67,5136.85),
                Vector3.new(4673.61,674.25,5246.92),
                Vector3.new(4892.01,672.98,5241.74),
                Vector3.new(4994.24,672.98,5244.03),
                Vector3.new(4992.15,686.16,5142.58),
                Vector3.new(4989.77,556.73,5145.89),
                Vector3.new(5033.11,555.68,5159.02),
            }
        },
        ["200M Wins"] = {
            TargetWinBlock = "workspace.Winblocks.WinBlock31",
            Waypoints = {
                Vector3.new(5068.92,557.74,5144.38),
                Vector3.new(5128.76,557.74,5142.96),
                Vector3.new(5211.79,580.24,5143.06),
                Vector3.new(5296.07,556.97,5141.94),
                Vector3.new(5359.12,557.79,5143.17),
                Vector3.new(5452.83,586.31,5139.50),
                Vector3.new(5511.70,558.91,5142.62),
                Vector3.new(5590.65,558.00,5143.76),
                Vector3.new(5671.54,581.22,5143.29),
                Vector3.new(5739.79,557.29,5143.85),
                Vector3.new(6171.37,558.64,5141.97),
                Vector3.new(6183.89,557.77,5145.04),
                Vector3.new(6227.48,557.59,5082.80),
                Vector3.new(6363.85,591.62,5082.37),
                Vector3.new(6363.49,591.62,5203.34),
                Vector3.new(6227.78,625.56,5209.23),
                Vector3.new(6229.19,625.56,5086.88),
                Vector3.new(6359.62,659.58,5082.64),
                Vector3.new(6364.83,659.58,5203.34),
                Vector3.new(6224.91,693.52,5205.57),
                Vector3.new(6224.08,693.52,5145.71),
                Vector3.new(6394.67,693.52,5141.80),
                Vector3.new(6449.74,693.52,5147.57),
                Vector3.new(6533.68,713.56,5182.09),
                Vector3.new(6633.47,733.99,5186.79),
                Vector3.new(6667.66,680.66,5186.06),
                Vector3.new(6770.89,694.43,5187.80),
                Vector3.new(6955.48,680.66,5189.23),
                Vector3.new(7048.27,702.73,5187.25),
                Vector3.new(7135.76,722.04,5185.98),
                Vector3.new(7237.60,694.30,5181.04),
                Vector3.new(7292.34,709.59,5180.98),
                Vector3.new(7381.10,730.08,5184.13),
                Vector3.new(7499.82,692.23,5181.45),
                Vector3.new(7538.27,716.47,5180.83),
                Vector3.new(7585.95,716.30,5182.49),
                Vector3.new(7586.40,716.07,5150.84),
                Vector3.new(7585.95,666.35,5150.84),
                Vector3.new(7719.94,666.35,5148.50),
                Vector3.new(7774.98,682.35,5145.33),
                Vector3.new(7827.94,712.17,5145.54),
                Vector3.new(7912.64,712.30,5144.52),
                Vector3.new(7987.47,710.31,5143.42),
            }
        },
    },
    ["World 3"] = {
        ["300M Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock32",
            Waypoints = {
                Vector3.new(-1436.38,-159.43,-934.65),
                Vector3.new(-1434.34,-159.43,-887.05),
                Vector3.new(-1441.31,-69.54,-526.62),
                Vector3.new(-1481.83,-71.65,-515.77),
            }
        },
        ["500M Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock33",
            Waypoints = {
                Vector3.new(-1454.82,-70.04,-462.58),
                Vector3.new(-1454.82,-59.06,-396.55),
                Vector3.new(-1434.52,-57.04,-305.09),
                Vector3.new(-1341.17,-57.04,-292.06),
                Vector3.new(-1271.14,-57.04,-266.85),
                Vector3.new(-1272.2,-57.04,-172.78),
                Vector3.new(-1291.02,-57.04,-113.47),
                Vector3.new(-1382.5,-57.04,-109.47),
                Vector3.new(-1460.27,-57.04,-47.56),
                Vector3.new(-1480.76,-59.41,-15.81),
            }
        },
        ["800M Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock34",
            Waypoints = {
                Vector3.new(-1454.71,-57.05,21.75),
                Vector3.new(-1453.34,-53.92,83.79),
                Vector3.new(-1453.08,89.95,94.88),
                Vector3.new(-1433.74,89.94,95.68),
                Vector3.new(-1434.6,214.96,102.57),
                Vector3.new(-1446.15,222.69,176.72),
                Vector3.new(-1443.58,215.96,257.46),
                Vector3.new(-1457.24,214.71,322.68),
                Vector3.new(-1480.77,212.60,332.14),
            }
        },
        ["1.25B Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock35",
            Waypoints = {
                Vector3.new(-1458.22,214.71,378.48),
                Vector3.new(-1458.94,214.71,461.01),
                Vector3.new(-1456.73,214.72,627.46),
                Vector3.new(-1436.28,360.71,622.02),
                Vector3.new(-1436.83,360.71,580.85),
                Vector3.new(-1329.42,363.38,514.71),
                Vector3.new(-1249.38,328.17,518.92),
                Vector3.new(-1237.0,324.37,604.52),
                Vector3.new(-1236.11,328.55,682.06),
                Vector3.new(-1218.74,345.87,835.48),
                Vector3.new(-1371.46,364.31,839.30),
                Vector3.new(-1402.59,358.73,839.35),
                Vector3.new(-1404.02,373.70,724.20),
                Vector3.new(-1404.13,532.72,754.06),
                Vector3.new(-1416.31,532.72,757.31),
                Vector3.new(-1431.33,532.62,759.62),
            }
        },
        ["2B Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock36",
            Waypoints = {
                Vector3.new(-1391.47,532.72,857.95),
                Vector3.new(-1309.55,532.72,1216.51),
                Vector3.new(-1395.61,532.72,1322.67),
                Vector3.new(-1431.45,530.61,1329.82),
            }
        },
        ["3.5B Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock37",
            Waypoints = {
                Vector3.new(-1403.92,532.72,1370.41),
                Vector3.new(-1440.89,532.72,1437.77),
                Vector3.new(-1450.16,508.72,1446.18),
                Vector3.new(-2034.55,508.72,1447.40),
                Vector3.new(-2061.63,442.72,1483.68),
                Vector3.new(-2062.37,440.61,1459.37),
            }
        },
        ["5.5B Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock38",
            Waypoints = {
                Vector3.new(-2108.13,442.72,1480.43),
                Vector3.new(-2167.62,450.90,1483.76),
                Vector3.new(-2303.95,438.72,1488.53),
                Vector3.new(-2336.33,446.07,1489.94),
                Vector3.new(-2377.42,447.72,1486.59),
                Vector3.new(-2416.13,438.72,1482.57),
                Vector3.new(-2448.73,438.72,1483.99),
                Vector3.new(-2495.35,446.36,1486.04),
                Vector3.new(-2530.1,458.00,1487.55),
                Vector3.new(-2546.52,464.21,1488.27),
                Vector3.new(-2689.61,442.72,1489.92),
                Vector3.new(-2728.75,450.67,1489.92),
                Vector3.new(-2863.25,578.98,1484.21),
                Vector3.new(-2936.68,546.35,1485.69),
                Vector3.new(-2935.84,644.02,1487.80),
                Vector3.new(-3011.83,615.90,1486.04),
                Vector3.new(-2999.28,720.88,1486.99),
                Vector3.new(-3087.81,674.12,1488.96),
                Vector3.new(-3163.04,672.24,1486.99),
                Vector3.new(-3212.15,672.23,1486.47),
                Vector3.new(-3217.24,672.12,1459.43),
            }
        },
        ["8.5B Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock39",
            Waypoints = {
                Vector3.new(-3240.66,672.23,1487.13),
                Vector3.new(-3628.39,618.53,1486.45),
                Vector3.new(-3653.68,616.57,1486.45),
                Vector3.new(-3657.56,614.46,1459.28),
            }
        },
        ["16B Wins"] = {
            TargetWinBlock = "workspace.Structure.Stage1.SAS.WinBlock40",
            Waypoints = {
                Vector3.new(-3755.15,616.57,1485.15),
                Vector3.new(-4020.58,616.57,1485.51),
                Vector3.new(-4125.63,616.57,1483.66),
                Vector3.new(-4130.56,616.57,1458.66),
            }
        },
        ["300M Wins"] = {
            TargetWinBlock = "workspace["NPC & Piege"].Ball1.BallSpawn",
            Waypoints = {
                Vector3.new(-1433.18,-159.43,-918.69),
                Vector3.new(-1443.18,-159.43,-918.69),
                Vector3.new(-1442.42,-160.68,-856.0),
            }
        },
    },
    ["BBNO"] = {
        ["1 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild("EverythingElse",true):FindFirstChild('WinBlock1',true)",
            Waypoints = {
                Vector3.new(-132.72,59.43,-234.29),
                Vector3.new(-113.82,59.44,-234.29),
                Vector3.new(-84.66,59.43,-234.29),
                Vector3.new(-55.84,59.43,-234.3),
                Vector3.new(-25.96,59.43,-234.3),
                Vector3.new(2.17,59.43,-232.79),
                Vector3.new(32.55,59.43,-232.86),
                Vector3.new(61.60,59.43,-233.85),
                Vector3.new(130.19,59.53,-229.55),
                Vector3.new(139.02,59.53,-206.93),
                Vector3.new(142.63,59.53,-193.49),
            }
        },
        ["10 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock3",true)",
            Waypoints = {
                Vector3.new(177.88,59.53,-214.3),
                Vector3.new(240.43,59.52,-192.1),
                Vector3.new(303.10,59.52,-178.79),
                Vector3.new(343.46,59.52,-188.04),
                Vector3.new(382.64,59.52,-210.75),
                Vector3.new(446.74,59.52,-231.04),
                Vector3.new(470.86,59.52,-235.57),
                Vector3.new(493.38,59.52,-236.01),
                Vector3.new(1075,167,-702.0),
                Vector3.new(1079.35,167.64,-682.96),
                Vector3.new(1067.85,167.66,-639.57),
                Vector3.new(1057.62,167.66,-604.86),
                Vector3.new(1050.03,167.66,-572.77),
                Vector3.new(1075.53,168.65,-538.68),
                Vector3.new(1087.46,168.65,-496.78),
                Vector3.new(1088.57,167.66,-451.37),
                Vector3.new(1054.93,167.64,-388.9),
                Vector3.new(1032.29,167.47,-385.5),
            }
        },
        ["20 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock4",true)",
            Waypoints = {
                Vector3.new(1054.00,167.64,-356.57),
                Vector3.new(1068.66,167.64,-339.77),
                Vector3.new(1072.24,167.64,-113.27),
                Vector3.new(1053.44,167.64,-70.75),
                Vector3.new(1032.29,167.47,-65.5),
            }
        },
        ["50 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock5",true)",
            Waypoints = {
                Vector3.new(1051.58,167.64,-61.34),
                Vector3.new(1075.25,167.64,-9.33),
                Vector3.new(1074.93,167.64,201.89),
                Vector3.new(1051.58,167.64,251.63),
                Vector3.new(1032.29,165.47,254.49),
            }
        },
        ["100 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock6",true)",
            Waypoints = {
                Vector3.new(1073.64,167.64,290.62),
                Vector3.new(1072.98,167.64,329.23),
                Vector3.new(1071.46,167.64,744.65),
                Vector3.new(1071.89,167.64,796.01),
                Vector3.new(1075.10,165.47,815.61),
            }
        },
        ["150 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild('WinBlock7',true)",
            Waypoints = {
                Vector3.new(1058.25,167.64,787.80),
                Vector3.new(1030.43,167.64,775.00),
                Vector3.new(989.49,167.39,774.46),
                Vector3.new(896.68,152.78,775.28),
                Vector3.new(858.70,162.71,775.62),
                Vector3.new(792.59,171.39,776.21),
                Vector3.new(766.19,167.90,776.44),
                Vector3.new(750.57,161.70,776.58),
                Vector3.new(734.33,161.02,776.72),
                Vector3.new(717.31,163.94,776.87),
                Vector3.new(700.75,166.79,777.01),
                Vector3.new(682.97,169.88,777.16),
                Vector3.new(678.30,170.83,777.20),
                Vector3.new(576.58,153.93,776.55),
                Vector3.new(560.15,157.11,776.40),
                Vector3.new(548.00,160.49,776.30),
                Vector3.new(461.37,153.87,776.39),
                Vector3.new(422.97,165.56,776.42),
                Vector3.new(399.79,167.64,775.21),
                Vector3.new(375.96,167.64,754.90),
                Vector3.new(354.61,167.64,745.35),
                Vector3.new(354.29,165.47,732.48),
            }
        },
        ["300 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock8",true)",
            Waypoints = {
                Vector3.new(327.48,167.64,758.88),
                Vector3.new(310.44,167.64,773.39),
                Vector3.new(151.04,167.64,768.83),
                Vector3.new(-113.87,167.64,779.67),
                Vector3.new(-207.99,167.64,775.43),
                Vector3.new(-387.62,167.64,773.66),
                Vector3.new(-463.2,167.64,775.82),
                Vector3.new(-493.73,166.28,775.21),
                Vector3.new(-173.0,307,-897.0),
                Vector3.new(-172.2,305.51,-853.5),
            }
        },
        ["500 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild("EverythingElse",true):FindFirstChild('WinBlock9',true)",
            Waypoints = {
                Vector3.new(-137.69,307.68,-896.06),
                Vector3.new(-52.99,307.67,-846.61),
                Vector3.new(219.98,307.67,-945.54),
                Vector3.new(525.09,307.67,-864.82),
                Vector3.new(555.58,307.67,-865.87),
                Vector3.new(671.20,307.67,-882.11),
                Vector3.new(739.02,307.68,-870.92),
                Vector3.new(744.29,305.51,-853.49),
            }
        },
        ["1000 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock10",true)",
            Waypoints = {
                Vector3.new(770.32,307.68,-888.46),
                Vector3.new(1135.07,306.24,-896.29),
                Vector3.new(1528.40,307.68,-895.34),
                Vector3.new(1607.47,305.5,-896.3),
            }
        },
        ["2500 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild('EverythingElse',true):FindFirstChild('WinBlock11',true)",
            Waypoints = {
                Vector3.new(1591.33,307.68,-879.96),
                Vector3.new(1590.50,306.64,-831.37),
                Vector3.new(1637.70,306.64,-774.82),
                Vector3.new(1768.62,306.64,-708.91),
                Vector3.new(1870.80,306.64,-558.7),
                Vector3.new(1961.49,306.64,-83.75),
                Vector3.new(1871.89,306.64,-47.08),
                Vector3.new(1829.88,307.68,14.27),
                Vector3.new(1799.73,307.68,24.07),
                Vector3.new(1785.29,305.51,24.49),
            }
        },
        ["10000 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild("EverythingElse",true):FindFirstChild("WinBlock12",true)",
            Waypoints = {
                Vector3.new(1820.94,307.68,58.98),
                Vector3.new(1822.18,307.68,67.28),
                Vector3.new(1826.00,307.68,168.84),
                Vector3.new(1827.18,307.68,167.82),
                Vector3.new(1826.56,810.68,178.63),
                Vector3.new(1827.79,810.68,339.95),
                Vector3.new(1830.23,810.68,468.44),
                Vector3.new(1827.63,810.68,600.55),
                Vector3.new(1827.63,810.68,755.36),
                Vector3.new(1822.70,810.68,859.54),
                Vector3.new(1822.70,810.68,958.97),
                Vector3.new(1828.09,808.51,987.68),
            }
        },
        ["25000 Cash"] = {
            TargetWinBlock = "workspace:FindFirstChild("EverythingElse",true):FindFirstChild("WinBlock13",true)",
            Waypoints = {
                Vector3.new(1756.28,810.68,948.19),
                Vector3.new(1637.89,810.68,932.86),
                Vector3.new(1569.13,817.75,891.75),
                Vector3.new(1424.50,810.67,871.66),
                Vector3.new(1409.38,810.67,860.12),
                Vector3.new(1375.46,818.18,845.95),
                Vector3.new(1085.42,810.67,852.56),
                Vector3.new(936.15,810.67,851.35),
                Vector3.new(914.45,810.67,900.74),
                Vector3.new(883.44,810.67,942.78),
                Vector3.new(855.03,810.68,951.44),
                Vector3.new(809.69,810.68,921.83),
                Vector3.new(807.29,808.51,902.49),
            }
        },
        ["50000 Cash"] = {
            TargetWinBlock = "workspace.EverythingElse.FinalSAS.WinPad:FindFirstChild('WinBlock14')",
            Waypoints = {
                Vector3.new(766.63,810.68,942.38),
                Vector3.new(733.98,810.75,935.17),
                Vector3.new(714.95,810.75,699.80),
                Vector3.new(712.65,810.75,573.42),
                Vector3.new(598.73,810.75,566.76),
                Vector3.new(594.86,810.75,476.48),
                Vector3.new(403.02,810.75,468.67),
                Vector3.new(401.96,810.75,732.33),
                Vector3.new(505.19,810.75,739.38),
                Vector3.new(515.39,810.75,839.95),
                Vector3.new(320.87,810.75,840.91),
                Vector3.new(315.45,810.75,946.99),
                Vector3.new(202.00,810.75,948.63),
                Vector3.new(126.13,810.68,945.22),
                Vector3.new(100.12,808.96,945.90),
            }
        },
    },
}

-- Movement Features
local Movement = {}
function Movement.GetMagnitude(pos)
    local char = client.Character
    local root = char and char.PrimaryPart
    local target = typeof(pos) == "CFrame" and pos.Position or pos
    if root then
        return (root.Position - target).Magnitude
    end
    return math.huge
end

function Movement.GetTo(cframe)
    local char = client.Character
    if char and not Movement.IsTeleporting then
        char:PivotTo(cframe)
    end
end

function Movement.Teleport(cframe)
    local char = client.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    repeat
        task.wait(0.05)
        root.CFrame = cframe
    until (root.Position - cframe.Position).Magnitude < 2
end

function Movement.MoveTo(targetVec3)
    local char = client.Character
    local root = char and char.PrimaryPart
    if root then
        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
        root.Anchored = true
        local targetCFrame = CFrame.new(targetVec3 + Vector3.new(0, 2.5, 0))
        Movement.IsTeleporting = true
        char:SetPrimaryPartCFrame(targetCFrame)
        task.wait(0.06)
        Movement.IsTeleporting = false
        root.Anchored = false
        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
    end
end

-- Anti-Cheat Bypasses & Misc Features
local BypassSpeedEnabled = false
local function bypassWalkSpeed()
    if BypassSpeedEnabled then return end
    BypassSpeedEnabled = true
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldIndex = mt.__index
    mt.__index = newcclosure(function(self, prop)
        if prop == "WalkSpeed" then
            return 16
        end
        return oldIndex(self, prop)
    end)
    setreadonly(mt, true)
end

local CharacterClone = nil
local FrozenCFrame = nil
local FrozenConnection = nil
local SavedParts = {}
local SavedDecals = {}

local function freezeAndClone()
    local char = client.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or CharacterClone then return end
    FrozenCFrame = Camera.CFrame
    char.Archivable = true
    CharacterClone = char:Clone()
    CharacterClone.Name = "Checkpoint"
    for _, desc in ipairs(CharacterClone:GetDescendants()) do
        if desc:IsA("Script") or desc:IsA("LocalScript") then
            desc:Destroy()
        elseif desc:IsA("BasePart") then
            desc.Anchored = true
            desc.CanCollide = false
            desc.CanTouch = false
            desc.LocalTransparencyModifier = 0
            if desc.Name == "HumanoidRootPart" then
                desc.Transparency = 1
            end
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = 0
        end
    end
    CharacterClone.Parent = Workspace
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            SavedParts[part] = part.LocalTransparencyModifier
            part.LocalTransparencyModifier = 1
        elseif part:IsA("Decal") or part:IsA("Texture") then
            SavedDecals[part] = part.Transparency
            part.Transparency = 1
        end
    end
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = FrozenCFrame
    if FrozenConnection then FrozenConnection:Disconnect() end
    FrozenConnection = RunService.RenderStepped:Connect(function()
        if FrozenCFrame then
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = FrozenCFrame
        end
    end)
end

local function unfreezeAndDeleteClone()
    if FrozenConnection then
        FrozenConnection:Disconnect()
        FrozenConnection = nil
    end
    for part, mod in pairs(SavedParts) do
        if part and part.Parent and part:IsA("BasePart") then
            part.LocalTransparencyModifier = mod
        end
    end
    for dec, trans in pairs(SavedDecals) do
        if dec and dec.Parent and (dec:IsA("Decal") or dec:IsA("Texture")) then
            dec.Transparency = trans
        end
    end
    SavedParts = {}
    SavedDecals = {}
    if CharacterClone then
        CharacterClone:Destroy()
        CharacterClone = nil
    end
    FrozenCFrame = nil
    local char = client.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    Camera.CameraType = Enum.CameraType.Custom
    if hum then Camera.CameraSubject = hum end
end

-- Auto-Buy Shop Engine
local function autoBuyShop(rarities)
    local gui = client.PlayerGui:FindFirstChild("SpeedGameUI", true)
    local shopFrame = gui and gui:FindFirstChild("ItemShopModal", true) and gui.ItemShopModal:FindFirstChild("ShopItemsFrame")
    if not shopFrame then return end
    local selected = {}
    for _, r in ipairs(rarities) do selected[r] = true end
    for _, rarity in ipairs({"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Mysterious"}) do
        if selected[rarity] then
            local card = shopFrame:FindFirstChild(rarity)
            if card then
                local numFrame = card:FindFirstChild("NumberFrame")
                local label = numFrame and numFrame:FindFirstChild("NumberText")
                if label and label:IsA("TextLabel") and label.Text ~= "Sold out" then
                    ReplicatedStorage.BuyWins:FireServer(rarity)
                end
            end
        end
    end
end

-- Discord Webhook Reporter
local function sendWebhook(url, title, description, color)
    if not request or not url or url == "" then return end
    local payload = {
        embeds = {{
            title = title,
            description = description,
            color = color or 65280,
            footer = { text = "Versus Airlines +1 Speed Keyboard Escape" }
        }}
    }
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- Hazard Solvers (NPC & Piege / Obstacles)
local function clearHazards()
    if Library.Flags["AvoidKillBall"] then
        for _, ball in ipairs(Workspace:GetDescendants()) do
            if ball.Name == "KillBall" and ball:IsA("BasePart") then
                ball.CanTouch = false
            end
        end
    end
end

-- UI Sections
local Main = Setup:CreateSection("Versus")
local Shop = Setup:CreateSection("Shop")
local Hazards = Setup:CreateSection("Hazards")
local Settings = Setup:CreateSection("Settings")

-- Main Section
Main:createLabel({ Name = "+1 Speed Keyboard Escape", Special = true })
Main:createButton({
    Name = "VersusAI Pathing",
    VersusAI = true,
    flagName = "UseVersusAI",
    Callback = function(enabled)
        if enabled then
            notify("VersusAI Pathing", "VersusAI enabled — using learned route memory and waypoints first.", "info")
        else
            notify("VersusAI Pathing", "VersusAI disabled — falling back to standard movement.", "warning")
        end
    end,
})

Main:createToggle({
    Name = "Auto Win (Farm All Routes)",
    Flag = false,
    flagName = "AutoWin",
    Callback = function(state)
        if state then
            notify("Auto Win", "Starting Auto-Win loop...", "info")
        else
            notify("Auto Win", "Stopped Auto-Win loop.", "warning")
        end
    end,
})

Main:createToggle({
    Name = "Bypass WalkSpeed (Anti-Cheat)",
    Flag = false,
    flagName = "BypassSpeed",
    Callback = function(state)
        if state then bypassWalkSpeed() end
    end,
})

Main:createToggle({
    Name = "Freeze & Clone Checkpoint",
    Flag = false,
    flagName = "FreezeClone",
    Callback = function(state)
        if state then
            freezeAndClone()
        else
            unfreezeAndDeleteClone()
        end
    end,
})

-- Shop Section
Shop:createLabel({ Name = "Automated Shop Purchases", Special = true })
Shop:createToggle({
    Name = "Auto Buy All Rarities",
    Flag = false,
    flagName = "AutoBuy",
})

-- Hazards Section
Hazards:createLabel({ Name = "Stage Hazard Solvers", Special = true })
Hazards:createToggle({
    Name = "Avoid KillBalls",
    Flag = false,
    flagName = "AvoidKillBall",
})
Hazards:createToggle({
    Name = "Ignore Tsunami Timers",
    Flag = false,
    flagName = "IgnoreTsunami",
})

-- Settings Section
Settings:createLabel({ Name = "Discord Webhook & Logs", Special = true })
Settings:createButton({
    Name = "Test Webhook Notification",
    Callback = function()
        sendWebhook("https://discord.com/api/webhooks/test", "Versus Airlines Test", "Webhook system is operational!", 65280)
        notify("Webhook Test", "Test payload triggered.", "info")
    end,
})

-- Core Automated Farm Loops (using interval helper)
interval("AutoWinLoop", "AutoWin", 1.5, function()
    local char = client.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Choose route table (defaults to World 1)
    local wRoutes = Routes["World 1"]
    if not wRoutes then return end
    
    for rname, data in pairs(wRoutes) do
        if not Library.Flags["AutoWin"] then break end
        if Library.Flags["UseVersusAI"] then
            -- VersusAI Pathing enabled: use learned waypoint coordinates
            for _, pt in ipairs(data.Waypoints) do
                Movement.MoveTo(pt)
                task.wait(0.1)
            end
        else
            -- Standard fallback teleport to target WinBlock
            for _, pt in ipairs(data.Waypoints) do
                Movement.GetTo(CFrame.new(pt))
                task.wait(0.15)
            end
        end
    end
end)

interval("AutoBuyLoop", "AutoBuy", 2.0, function()
    autoBuyShop({"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Mysterious"})
end)

interval("HazardLoop", "AvoidKillBall", 1.0, function()
    clearHazards()
end)