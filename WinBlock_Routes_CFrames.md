# +1 Speed Keyboard Escape — Win Block Routes & CFrame Waypoints

This document contains the complete deobfuscated list of all **53 Win Block Routes**, their **Target Win Blocks in Workspace**, and every **CFrame / `Vector3` Waypoint** across all worlds (`World 1`, `World 2`, `World 3`, and `BBNO`).

---

## Summary Table of Win Block Targets

| World | Route Name | Target Win Block | Waypoints Count |
| :--- | :--- | :--- | :---: |
| **World 1** | `1 Win` | `workspace.Structure.Stage2.WinBlock1` | 3 |
| **World 1** | `3 Wins` | `workspace.Structure.Stage3.WinBlock2` | 3 |
| **World 1** | `10 Wins` | `workspace.Structure.Stage4.WinBlock3` | 5 |
| **World 1** | `20 Wins` | `workspace.Structure.Stage5.WinBlock4` | 7 |
| **World 1** | `50 Wins` | `workspace.Structure.Stage6.WinBlock5` | 5 |
| **World 1** | `100 Wins` | `workspace.Structure.Stage7.WinBlock6` | 5 |
| **World 1** | `150 Wins` | `workspace.Structure.Stage8.WinBlock7` | 3 |
| **World 1** | `300 Wins` | `workspace.Structure.Stage9.WinBlock8` | 5 |
| **World 1** | `500 Wins` | `workspace.Structure.Stage10.WinBlock9` | 31 |
| **World 1** | `1000 Wins` | `workspace.Structure.Stage11.WinBlock10` | 4 |
| **World 1** | `2500 Wins` | `workspace.Structure.Stage12.WinBlock11` | 11 |
| **World 1** | `10000 Wins` | `workspace.Structure.Stage13.WinBlock12` | 6 |
| **World 1** | `25000 Wins` | `workspace.Structure.Stage14.WinBlock13` | 5 |
| **World 1** | `50000 Wins` | `workspace.Structure.Stage15.WinBlock14` | 4 |
| **World 1** | `150K Wins` | `workspace.Structure.Stage15.WinBlock14` | 31 |
| **World 2** | `250K Wins` | `workspace["WORLD 2"].Winblocks.WinBlock16` | 5 |
| **World 2** | `400K Wins` | `workspace["WORLD 2"].Winblocks.WinBlock17` | 5 |
| **World 2** | `600K Wins` | `workspace['WORLD 2'].Winblocks.WinBlock18` | 12 |
| **World 2** | `1M Wins` | `workspace['WORLD 2'].Winblocks.WinBlock19` | 2 |
| **World 2** | `1.5M Wins` | `workspace['WORLD 2'].Winblocks.WinBlock20` | 4 |
| **World 2** | `2.5M Wins` | `workspace["WORLD 2"].Winblocks.WinBlock21` | 19 |
| **World 2** | `4M Wins` | `workspace["WORLD 2"].Winblocks.WinBlock22` | 2 |
| **World 2** | `6M Wins` | `workspace["WORLD 2"].Winblocks.WinBlock23` | 2 |
| **World 2** | `10M Wins` | `workspace["WORLD 2"].Winblocks.WinBlock24` | 13 |
| **World 2** | `15M Wins` | `workspace.Winblocks.WinBlock25` | 4 |
| **World 2** | `25M Wins` | `workspace.Winblocks.WinBlock27` | 8 |
| **World 2** | `40M Wins` | `workspace.Winblocks.WinBlock28` | 17 |
| **World 2** | `60M Wins` | `workspace.Winblocks.WinBlock29` | 25 |
| **World 2** | `100M Wins` | `workspace.Winblocks.WinBlock30` | 15 |
| **World 2** | `200M Wins` | `workspace.Winblocks.WinBlock31` | 43 |
| **World 3** | `300M Wins` | `workspace.Structure.Stage1.SAS.WinBlock32` | 4 |
| **World 3** | `500M Wins` | `workspace.Structure.Stage1.SAS.WinBlock33` | 10 |
| **World 3** | `800M Wins` | `workspace.Structure.Stage1.SAS.WinBlock34` | 9 |
| **World 3** | `1.25B Wins` | `workspace.Structure.Stage1.SAS.WinBlock35` | 16 |
| **World 3** | `2B Wins` | `workspace.Structure.Stage1.SAS.WinBlock36` | 4 |
| **World 3** | `3.5B Wins` | `workspace.Structure.Stage1.SAS.WinBlock37` | 6 |
| **World 3** | `5.5B Wins` | `workspace.Structure.Stage1.SAS.WinBlock38` | 21 |
| **World 3** | `8.5B Wins` | `workspace.Structure.Stage1.SAS.WinBlock39` | 4 |
| **World 3** | `16B Wins` | `workspace.Structure.Stage1.SAS.WinBlock40` | 4 |
| **BBNO** | `1 Cash` | `workspace:FindFirstChild("EverythingElse",true):FindFirstChild('WinBlock1',true)` | 11 |
| **BBNO** | `10 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock3",true)` | 18 |
| **BBNO** | `20 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock4",true)` | 5 |
| **BBNO** | `50 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock5",true)` | 5 |
| **BBNO** | `100 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock6",true)` | 5 |
| **BBNO** | `150 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild('WinBlock7',true)` | 22 |
| **BBNO** | `300 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock8",true)` | 10 |
| **BBNO** | `500 Cash` | `workspace:FindFirstChild("EverythingElse",true):FindFirstChild('WinBlock9',true)` | 8 |
| **BBNO** | `1000 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock10",true)` | 4 |
| **BBNO** | `2500 Cash` | `workspace:FindFirstChild('EverythingElse',true):FindFirstChild('WinBlock11',true)` | 10 |
| **BBNO** | `10000 Cash` | `workspace:FindFirstChild("EverythingElse",true):FindFirstChild("WinBlock12",true)` | 12 |
| **BBNO** | `25000 Cash` | `workspace:FindFirstChild("EverythingElse",true):FindFirstChild("WinBlock13",true)` | 13 |
| **BBNO** | `50000 Cash` | `workspace.EverythingElse.FinalSAS.WinPad:FindFirstChild('WinBlock14')` | 15 |
| **World 3** | `300M Wins` | `workspace["NPC & Piege"].Ball1.BallSpawn` | 3 |

---

## Detailed CFrame & Waypoint Coordinates by World


### World 1

#### Route: `1 Win`
- **Target Win Block:** `workspace.Structure.Stage2.WinBlock1`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(2.81,7.68,129.98)`
  2. `Vector3.new(-0.48,7.68,284.92)`
  3. `Vector3.new(-13.25,11.31,285.25)`

#### Route: `3 Wins`
- **Target Win Block:** `workspace.Structure.Stage3.WinBlock2`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(50.45,7.68,399.32)`
  2. `Vector3.new(.22,7.68,504.8)`
  3. `Vector3.new(-16.12,10.65,507.26)`

#### Route: `10 Wins`
- **Target Win Block:** `workspace.Structure.Stage4.WinBlock3`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-12.28,7.68,526.86)`
  2. `Vector3.new(-15.79,7.68,559.83)`
  3. `Vector3.new(-16.23,49.29,677.16)`
  4. `Vector3.new(-15.94,75.96,757.34)`
  5. `Vector3.new(-15.92,77.92,774.04)`

#### Route: `20 Wins`
- **Target Win Block:** `workspace.Structure.Stage5.WinBlock4`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1.09,77.14,789.13)`
  2. `Vector3.new(2.33,77.14,817.71)`
  3. `Vector3.new(3.68,77.14,900.07)`
  4. `Vector3.new(3.89,77.14,945.26)`
  5. `Vector3.new(3.80,77.14,1013.27)`
  6. `Vector3.new(-3.04,77.14,1103.80)`
  7. `Vector3.new(-14.89,78.94,1108.95)`
- **Axis / Tween Segments (`Q`):**
  - `Q("z",817.71,853.24,5)`
  - `Q("z",900.07,921.40,5)`
  - `Q("z",945.26,998.72,5)`
  - `Q('z',1013.27,1036.98,5)`

#### Route: `50 Wins`
- **Target Win Block:** `workspace.Structure.Stage6.WinBlock5`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-0.39,77.14,1125.59)`
  2. `Vector3.new(-0.17,77.14,1151.55)`
  3. `Vector3.new(1.67,77.14,1358.60)`
  4. `Vector3.new(2.12,77.14,1410.29)`
  5. `Vector3.new(-20.89,78.4,1412.88)`

#### Route: `100 Wins`
- **Target Win Block:** `workspace.Structure.Stage7.WinBlock6`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1.71,75.96,1420.83)`
  2. `Vector3.new(-126.49,53.31,1444.94)`
  3. `Vector3.new(-433.16,53.31,1463.62)`
  4. `Vector3.new(-546.43,53.32,1463.7)`
  5. `Vector3.new(-539.85,55.15,1448.3)`

#### Route: `150 Wins`
- **Target Win Block:** `workspace.Structure.Stage8.WinBlock7`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-712.52,53.32,1465.25)`
  2. `Vector3.new(-1007.36,53.32,1466.5)`
  3. `Vector3.new(-1008.4,55.29,1451.05)`

#### Route: `300 Wins`
- **Target Win Block:** `workspace.Structure.Stage9.WinBlock8`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1028.58,54.50,1467.10)`
  2. `Vector3.new(-1087.28,58.04,1467.11)`
  3. `Vector3.new(-1093.82,296.50,1466.77)`
  4. `Vector3.new(-1121.53,296.50,1464.99)`
  5. `Vector3.new(-1123.63,298.61,1452.2)`

#### Route: `500 Wins`
- **Target Win Block:** `workspace.Structure.Stage10.WinBlock9`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1133.99,296.50,1466.29)`
  2. `Vector3.new(-1185.22,296.61,1466.74)`
  3. `Vector3.new(-1244.5,303.80,1467.25)`
  4. `Vector3.new(-1368.79,282.47,1468.33)`
  5. `Vector3.new(-1379.12,291.39,1468.48)`
  6. `Vector3.new(-1390.21,302.46,1468.64)`
  7. `Vector3.new(-1401.94,314.20,1468.82)`
  8. `Vector3.new(-1414.42,326.69,1469.01)`
  9. `Vector3.new(-1422.28,334.55,1469.10)`
  10. `Vector3.new(-1436.97,336.87,1469.23)`
  11. `Vector3.new(-1467.19,336.87,1469.49)`
  12. `Vector3.new(-1506.06,336.87,1469.83)`
  13. `Vector3.new(-1624.22,321.27,1470.85)`
  14. `Vector3.new(-1778.99,291.09,1472.18)`
  15. `Vector3.new(-1818.14,301.58,1472.52)`
  16. `Vector3.new(-1861.72,317.34,1472.83)`
  17. `Vector3.new(-2045.2,307.45,1474.42)`
  18. `Vector3.new(-2155.3,317.38,1475.39)`
  19. `Vector3.new(-2175.94,324.53,1475.57)`
  20. `Vector3.new(-2279.1,314.07,1476.47)`
  21. `Vector3.new(-2307.45,314.07,1476.71)`
  22. `Vector3.new(-2342.51,325.01,1477.02)`
  23. `Vector3.new(-2429.93,322.77,1474.25)`
  24. `Vector3.new(-2494.78,322.76,1472.55)`
  25. `Vector3.new(-2523.56,322.77,1486.14)`
  26. `Vector3.new(-2650.38,294.27,1499.56)`
  27. `Vector3.new(-2703.93,294.27,1484.21)`
  28. `Vector3.new(-2786.51,308.04,1472.55)`
  29. `Vector3.new(-2880.38,283.33,1474.26)`
  30. `Vector3.new(-2972.13,296.50,1468.36)`
  31. `Vector3.new(-2973.39,299.56,1449.55)`
- **Axis / Tween Segments (`Q`):**
  - `Q("x",-1244.5,-1357.63,8,282.47)`
  - `Q("x",-1506.06,-1565.56,8,321.27)`
  - `Q('x',-1624.22,-1746.12,8,290.87)`
  - `Q('x',-1861.72,-1934.48,8,307.45)`
  - `Q("x",-2045.2,-2127.3,8,307.67)`
  - `Q("x",-2175.94,-2251.62,8,314.07)`
  - `Q('x',-2342.51,-2417.97,8,322.77)`
  - `Q('x',-2523.56,-2627.28,8,294.27)`
  - `Q("x",-2786.51,-2871.51,8,283.33)`

#### Route: `1000 Wins`
- **Target Win Block:** `workspace.Structure.Stage11.WinBlock10`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-3251.58,295.32,1468.47)`
  2. `Vector3.new(-3732.62,295.32,1464.91)`
  3. `Vector3.new(-3943.55,295.32,1466.12)`
  4. `Vector3.new(-3939.01,299.56,1447.85)`

#### Route: `2500 Wins`
- **Target Win Block:** `workspace.Structure.Stage12.WinBlock11`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-3944.82,296.50,1465.57)`
  2. `Vector3.new(-3992.31,296.50,1463.09)`
  3. `Vector3.new(-4186.61,296.50,1464.14)`
  4. `Vector3.new(-4302.06,296.48,1467.15)`
  5. `Vector3.new(-4308.52,371.21,1467.09)`
  6. `Vector3.new(-4294.34,448.33,1502.85)`
  7. `Vector3.new(-4298.7,504.16,1525.44)`
  8. `Vector3.new(-4298.7,497.07,1525.44)`
  9. `Vector3.new(-4309.03,472.36,1527.47)`
  10. `Vector3.new(-4366.92,471.01,1526.97)`
  11. `Vector3.new(-4368.75,474.62,1513.47)`
- **Axis / Tween Segments (`Q`):**
  - `Q("x",-3992.31,-4101.22,8,296.50)`
  - `Q('x',-4186.61,-4292.88,8,296.50)`

#### Route: `10000 Wins`
- **Target Win Block:** `workspace.Structure.Stage13.WinBlock12`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-4584.82,469.65,1529.69)`
  2. `Vector3.new(-4628.37,469.65,1141.16)`
  3. `Vector3.new(-5046.67,469.65,1588.44)`
  4. `Vector3.new(-5266.65,469.65,1477.57)`
  5. `Vector3.new(-5341.57,469.43,1477.3)`
  6. `Vector3.new(-5341.17,472.4,1459.22)`

#### Route: `25000 Wins`
- **Target Win Block:** `workspace.Structure.Stage14.WinBlock13`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-5398.84,476.83,1480.4)`
  2. `Vector3.new(-5902.1,486.11,1565.53)`
  3. `Vector3.new(-6479.85,488.56,1388.15)`
  4. `Vector3.new(-6808.44,520.43,1487.06)`
  5. `Vector3.new(-6808.57,523.6,1470.37)`

#### Route: `50000 Wins`
- **Target Win Block:** `workspace.Structure.Stage15.WinBlock14`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-6858.1,551.99,1489.02)`
  2. `Vector3.new(-8308.83,551.99,1489.02)`
  3. `Vector3.new(-8345.8,484.49,1489.52)`
  4. `Vector3.new(-8353.04,490.49,1468.88)`

#### Route: `150K Wins`
- **Target Win Block:** `workspace.Structure.Stage15.WinBlock14`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-8453.98,484.49,1490.244)`
  2. `Vector3.new(-8802.23,500.14,1486.852)`
  3. `Vector3.new(-9143.41,503.41,1393.124)`
  4. `Vector3.new(-9375.97,505.18,1388.144)`
  5. `Vector3.new(-9507.49,506.27,1484.711)`
  6. `Vector3.new(-9899.78,500.40,1484.911)`
  7. `Vector3.new(-10160.3,504.36,1484.862)`
  8. `Vector3.new(-10253.13,504.21,1485.302)`
  9. `Vector3.new(-10256.06,527.41,1593.329)`
  10. `Vector3.new(-10352.32,436.98,1716.224)`
  11. `Vector3.new(-10360.53,442.96,1792.248)`
  12. `Vector3.new(-10360.24,545.07,2339.724)`
  13. `Vector3.new(-10359.65,745.49,3417.401)`
  14. `Vector3.new(-10474.12,751.02,3580.787)`
  15. `Vector3.new(-10684.21,751.61,3579.589)`
  16. `Vector3.new(-10745.23,808.04,3586.674)`
  17. `Vector3.new(-12045.39,804.50,3574.341)`
  18. `Vector3.new(-12118.14,751.43,3576.324)`
  19. `Vector3.new(-13209.91,750.54,3586.828)`
  20. `Vector3.new(-13406.26,750.54,3679.525)`
  21. `Vector3.new(-13424.09,750.54,3382.024)`
  22. `Vector3.new(-13625.38,750.54,3349.125)`
  23. `Vector3.new(-13632.23,750.54,3198.804)`
  24. `Vector3.new(-13869.61,750.54,3224.189)`
  25. `Vector3.new(-13718.49,750.54,3448.185)`
  26. `Vector3.new(-13709.48,750.54,3779.334)`
  27. `Vector3.new(-13637.45,750.54,3975.037)`
  28. `Vector3.new(-13989.7,750.54,3964.212)`
  29. `Vector3.new(-13994.57,750.54,3172.296)`
  30. `Vector3.new(-14002.12,750.54,3097.345)`
  31. `Vector3.new(-14001.91,754.54,3067.99)`


### World 2

#### Route: `250K Wins`
- **Target Win Block:** `workspace["WORLD 2"].Winblocks.WinBlock16`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-393.47,505.00,-44.82)`
  2. `Vector3.new(-393.71,504.09,2.43)`
  3. `Vector3.new(-400.65,504.09,74.35)`
  4. `Vector3.new(-402.55,504.09,136.23)`
  5. `Vector3.new(-415.55,500.99,189.32)`
- **Axis / Tween Segments (`Q`):**
  - `Q("z",2.43,48.95,7.65)`
  - `Q("z",74.35,121.47,7.65)`
  - `Q('z',136.23,175.91,7.65)`

#### Route: `400K Wins`
- **Target Win Block:** `workspace["WORLD 2"].Winblocks.WinBlock17`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-399.46,498.99,198.01)`
  2. `Vector3.new(-399.82,498.99,267.71)`
  3. `Vector3.new(-400.21,498.99,341.16)`
  4. `Vector3.new(-400.58,498.99,412.84)`
  5. `Vector3.new(-416.32,500.83,433.69)`

#### Route: `600K Wins`
- **Target Win Block:** `workspace['WORLD 2'].Winblocks.WinBlock18`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-398.2,500.03,463.03)`
  2. `Vector3.new(-347.46,500.03,469.68)`
  3. `Vector3.new(-349.14,527.10,573.13)`
  4. `Vector3.new(-447.89,527.10,576.56)`
  5. `Vector3.new(-452.08,554.10,472.30)`
  6. `Vector3.new(-352.86,554.10,465.77)`
  7. `Vector3.new(-349.44,581.17,571.67)`
  8. `Vector3.new(-454.37,581.17,573.74)`
  9. `Vector3.new(-448.42,608.17,475.03)`
  10. `Vector3.new(-398.27,608.17,473.62)`
  11. `Vector3.new(-398.65,607.96,597.59)`
  12. `Vector3.new(-417.61,608.64,607.74)`

#### Route: `1M Wins`
- **Target Win Block:** `workspace['WORLD 2'].Winblocks.WinBlock19`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-398.68,606.78,608.25)`
  2. `Vector3.new(-418.31,608.6,841.45)`
- **Axis / Tween Segments (`Q`):**
  - `Q('z',608.25,839.73,15.5)`

#### Route: `1.5M Wins`
- **Target Win Block:** `workspace['WORLD 2'].Winblocks.WinBlock20`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-400.1,606.34,844.76)`
  2. `Vector3.new(-400.4,606.34,1069.42)`
  3. `Vector3.new(-398.86,606.34,1260.08)`
  4. `Vector3.new(-415.33,608.22,1261.47)`

#### Route: `2.5M Wins`
- **Target Win Block:** `workspace["WORLD 2"].Winblocks.WinBlock21`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-398.84,607.52,1287.80)`
  2. `Vector3.new(-399.64,619.24,1332.89)`
  3. `Vector3.new(-393.64,607.52,1455.49)`
  4. `Vector3.new(-391.58,607.52,1463.43)`
  5. `Vector3.new(-386.61,607.54,1477.10)`
  6. `Vector3.new(-364.94,627.82,1540.56)`
  7. `Vector3.new(-364.42,628.31,1600.44)`
  8. `Vector3.new(-362.27,605.40,1723.56)`
  9. `Vector3.new(-362.05,605.40,1752.47)`
  10. `Vector3.new(-368.45,616.15,1789.31)`
  11. `Vector3.new(-398.33,607.52,1884.31)`
  12. `Vector3.new(-401.3,607.52,1917.52)`
  13. `Vector3.new(-401.18,618.63,1956.97)`
  14. `Vector3.new(-398.73,607.52,2098.80)`
  15. `Vector3.new(-399.39,618.21,2136.59)`
  16. `Vector3.new(-401.83,607.52,2276.35)`
  17. `Vector3.new(-402.5,624.35,2314.60)`
  18. `Vector3.new(-404.03,624,2402.70)`
  19. `Vector3.new(-417.27,624,2415.65)`
- **Axis / Tween Segments (`Q`):**
  - `Q("z",1332.89,1432.40,5)`
  - `Q('z',1600.44,1694.74,5)`
  - `Q('z',1789.31,1860.39,5)`
  - `Q('z',1956.97,2068.00,5)`
  - `Q("z",2136.59,2249.81,5)`
  - `Q("z",2314.60,2380.09,5)`

#### Route: `4M Wins`
- **Target Win Block:** `workspace["WORLD 2"].Winblocks.WinBlock22`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-400.82,623.41,2632.3)`
  2. `Vector3.new(-417.27,621.4,2650.78)`

#### Route: `6M Wins`
- **Target Win Block:** `workspace["WORLD 2"].Winblocks.WinBlock23`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-400.52,623.43,3153.41)`
  2. `Vector3.new(-417.27,621.22,3158.65)`

#### Route: `10M Wins`
- **Target Win Block:** `workspace["WORLD 2"].Winblocks.WinBlock24`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-389.13,623.43,3336.43)`
  2. `Vector3.new(-196.84,623.43,3348.66)`
  3. `Vector3.new(-165.79,623.43,3259.28)`
  4. `Vector3.new(-111.84,623.43,3267.77)`
  5. `Vector3.new(-114.05,623.43,3423.23)`
  6. `Vector3.new(-272.18,623.43,3438.41)`
  7. `Vector3.new(-252.02,623.43,3627.99)`
  8. `Vector3.new(-549.29,623.43,3618.9)`
  9. `Vector3.new(-566.19,623.43,3800.48)`
  10. `Vector3.new(-125.02,623.43,3798.86)`
  11. `Vector3.new(-117.85,623.43,3869.58)`
  12. `Vector3.new(-61.37,623.5,3868.81)`
  13. `Vector3.new(-59.9,624.76,3881.49)`

#### Route: `15M Wins`
- **Target Win Block:** `workspace.Winblocks.WinBlock25`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-32.21,624.22,3864.24)`
  2. `Vector3.new(1177.52,625.06,3866.53)`
  3. `Vector3.new(1211.29,624.74,3866.80)`
  4. `Vector3.new(1228.42,621.59,3908.94)`

#### Route: `25M Wins`
- **Target Win Block:** `workspace.Winblocks.WinBlock27`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1321.79,619.60,3864.47)`
  2. `Vector3.new(1541.89,628.48,3799.19)`
  3. `Vector3.new(1741.58,638.05,3943.17)`
  4. `Vector3.new(1950.87,635.78,3800.74)`
  5. `Vector3.new(2081.97,642.01,3958.54)`
  6. `Vector3.new(2294.80,629.97,3870.72)`
  7. `Vector3.new(2390.38,629.42,3871.08)`
  8. `Vector3.new(2400.21,625.54,3887.94)`

#### Route: `40M Wins`
- **Target Win Block:** `workspace.Winblocks.WinBlock28`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(2435.81,627.63,3871.18)`
  2. `Vector3.new(2490.45,639.51,3871.59)`
  3. `Vector3.new(2546.37,639.63,3869.79)`
  4. `Vector3.new(2703.03,634.63,3865.92)`
  5. `Vector3.new(2742.21,628.97,3869.99)`
  6. `Vector3.new(2742.21,575.63,3869.99)`
  7. `Vector3.new(2768.79,575.63,3870.23)`
  8. `Vector3.new(2825.36,575.63,3870.73)`
  9. `Vector3.new(2864.97,582.33,3871.07)`
  10. `Vector3.new(2884.59,592.78,3871.28)`
  11. `Vector3.new(2916.35,604.52,3871.55)`
  12. `Vector3.new(2972.13,576.61,3870.13)`
  13. `Vector3.new(2999.43,576.61,3871.04)`
  14. `Vector3.new(3047.81,591.50,3871.40)`
  15. `Vector3.new(3217.29,592.61,3872.60)`
  16. `Vector3.new(3263.77,592.63,3871.93)`
  17. `Vector3.new(3269.21,590.63,3887.94)`
- **Axis / Tween Segments (`Q`):**
  - `Q('x',2546.37,2674.71,8)`
  - `Q("x",3047.81,3189.62,8)`

#### Route: `60M Wins`
- **Target Win Block:** `workspace.Winblocks.WinBlock29`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(3324.58,668.46,3872.93)`
  2. `Vector3.new(3344.39,666.98,3947.49)`
  3. `Vector3.new(3340.76,670.38,4159.59)`
  4. `Vector3.new(3340.76,670.38,4259.59)`
  5. `Vector3.new(3340.76,670.38,4359.59)`
  6. `Vector3.new(3340.76,670.38,4459.59)`
  7. `Vector3.new(3340.76,670.38,4559.59)`
  8. `Vector3.new(3340.76,670.38,4659.59)`
  9. `Vector3.new(3340.76,670.38,4759.59)`
  10. `Vector3.new(3340.76,670.38,4859.59)`
  11. `Vector3.new(3340.76,670.38,4959.59)`
  12. `Vector3.new(3440.61,666.36,5144.65)`
  13. `Vector3.new(3540.61,666.36,5144.65)`
  14. `Vector3.new(3640.61,666.36,5144.65)`
  15. `Vector3.new(3740.61,666.36,5144.65)`
  16. `Vector3.new(3840.61,666.36,5144.65)`
  17. `Vector3.new(3940.61,666.36,5144.65)`
  18. `Vector3.new(4040.61,666.36,5144.65)`
  19. `Vector3.new(4140.61,666.36,5144.65)`
  20. `Vector3.new(4240.61,666.36,5144.65)`
  21. `Vector3.new(4340.61,666.36,5144.65)`
  22. `Vector3.new(4440.61,666.36,5144.65)`
  23. `Vector3.new(4540.61,666.36,5144.65)`
  24. `Vector3.new(4613.28,664.56,5141.97)`
  25. `Vector3.new(4634.11,565.7,5159.4)`

#### Route: `100M Wins`
- **Target Win Block:** `workspace.Winblocks.WinBlock30`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(4650.84,566.84,5143.59)`
  2. `Vector3.new(4717.82,565.83,5142.59)`
  3. `Vector3.new(4808.75,592.92,5144.15)`
  4. `Vector3.new(4879.62,566.20,5142.28)`
  5. `Vector3.new(4913.15,568.72,5023.33)`
  6. `Vector3.new(4912.98,676.88,5023.31)`
  7. `Vector3.new(4805.10,675.12,5036.15)`
  8. `Vector3.new(4681.35,674.53,5038.30)`
  9. `Vector3.new(4675.33,673.67,5136.85)`
  10. `Vector3.new(4673.61,674.25,5246.92)`
  11. `Vector3.new(4892.01,672.98,5241.74)`
  12. `Vector3.new(4994.24,672.98,5244.03)`
  13. `Vector3.new(4992.15,686.16,5142.58)`
  14. `Vector3.new(4989.77,556.73,5145.89)`
  15. `Vector3.new(5033.11,555.68,5159.02)`

#### Route: `200M Wins`
- **Target Win Block:** `workspace.Winblocks.WinBlock31`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(5068.92,557.74,5144.38)`
  2. `Vector3.new(5128.76,557.74,5142.96)`
  3. `Vector3.new(5211.79,580.24,5143.06)`
  4. `Vector3.new(5296.07,556.97,5141.94)`
  5. `Vector3.new(5359.12,557.79,5143.17)`
  6. `Vector3.new(5452.83,586.31,5139.50)`
  7. `Vector3.new(5511.70,558.91,5142.62)`
  8. `Vector3.new(5590.65,558.00,5143.76)`
  9. `Vector3.new(5671.54,581.22,5143.29)`
  10. `Vector3.new(5739.79,557.29,5143.85)`
  11. `Vector3.new(6171.37,558.64,5141.97)`
  12. `Vector3.new(6183.89,557.77,5145.04)`
  13. `Vector3.new(6227.48,557.59,5082.80)`
  14. `Vector3.new(6363.85,591.62,5082.37)`
  15. `Vector3.new(6363.49,591.62,5203.34)`
  16. `Vector3.new(6227.78,625.56,5209.23)`
  17. `Vector3.new(6229.19,625.56,5086.88)`
  18. `Vector3.new(6359.62,659.58,5082.64)`
  19. `Vector3.new(6364.83,659.58,5203.34)`
  20. `Vector3.new(6224.91,693.52,5205.57)`
  21. `Vector3.new(6224.08,693.52,5145.71)`
  22. `Vector3.new(6394.67,693.52,5141.80)`
  23. `Vector3.new(6449.74,693.52,5147.57)`
  24. `Vector3.new(6533.68,713.56,5182.09)`
  25. `Vector3.new(6633.47,733.99,5186.79)`
  26. `Vector3.new(6667.66,680.66,5186.06)`
  27. `Vector3.new(6770.89,694.43,5187.80)`
  28. `Vector3.new(6955.48,680.66,5189.23)`
  29. `Vector3.new(7048.27,702.73,5187.25)`
  30. `Vector3.new(7135.76,722.04,5185.98)`
  31. `Vector3.new(7237.60,694.30,5181.04)`
  32. `Vector3.new(7292.34,709.59,5180.98)`
  33. `Vector3.new(7381.10,730.08,5184.13)`
  34. `Vector3.new(7499.82,692.23,5181.45)`
  35. `Vector3.new(7538.27,716.47,5180.83)`
  36. `Vector3.new(7585.95,716.30,5182.49)`
  37. `Vector3.new(7586.40,716.07,5150.84)`
  38. `Vector3.new(7585.95,666.35,5150.84)`
  39. `Vector3.new(7719.94,666.35,5148.50)`
  40. `Vector3.new(7774.98,682.35,5145.33)`
  41. `Vector3.new(7827.94,712.17,5145.54)`
  42. `Vector3.new(7912.64,712.30,5144.52)`
  43. `Vector3.new(7987.47,710.31,5143.42)`


### World 3

#### Route: `300M Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock32`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1436.38,-159.43,-934.65)`
  2. `Vector3.new(-1434.34,-159.43,-887.05)`
  3. `Vector3.new(-1441.31,-69.54,-526.62)`
  4. `Vector3.new(-1481.83,-71.65,-515.77)`
- **Axis / Tween Segments (`Q`):**
  - `Q("z",-887.05,-837.57,5,-158.57)`
  - `Q("z",-837.57,-732.15,15,-125.42)`
  - `Q('z',-732.15,-630.24,15,-93.37)`
  - `Q('z',-630.24,-534.11,15,-69.54)`

#### Route: `500M Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock33`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1454.82,-70.04,-462.58)`
  2. `Vector3.new(-1454.82,-59.06,-396.55)`
  3. `Vector3.new(-1434.52,-57.04,-305.09)`
  4. `Vector3.new(-1341.17,-57.04,-292.06)`
  5. `Vector3.new(-1271.14,-57.04,-266.85)`
  6. `Vector3.new(-1272.2,-57.04,-172.78)`
  7. `Vector3.new(-1291.02,-57.04,-113.47)`
  8. `Vector3.new(-1382.5,-57.04,-109.47)`
  9. `Vector3.new(-1460.27,-57.04,-47.56)`
  10. `Vector3.new(-1480.76,-59.41,-15.81)`
- **Axis / Tween Segments (`Q`):**
  - `Q("z",-392.9,-340.07,7,-57.04)`
  - `Q("x",-1434.74,-1377.35,7)`
  - `Q('x',-1341.17,-1291.83,7)`
  - `Q('z',-266.85,-212.67,7)`
  - `Q('z',-172.78,-115.44,7)`
  - `Q('x',-1291.02,-1342.12,7)`
  - `Q("x",-1382.5,-1433.22,7)`

#### Route: `800M Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock34`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1454.71,-57.05,21.75)`
  2. `Vector3.new(-1453.34,-53.92,83.79)`
  3. `Vector3.new(-1453.08,89.95,94.88)`
  4. `Vector3.new(-1433.74,89.94,95.68)`
  5. `Vector3.new(-1434.6,214.96,102.57)`
  6. `Vector3.new(-1446.15,222.69,176.72)`
  7. `Vector3.new(-1443.58,215.96,257.46)`
  8. `Vector3.new(-1457.24,214.71,322.68)`
  9. `Vector3.new(-1480.77,212.60,332.14)`
- **Axis / Tween Segments (`Q`):**
  - `Q('z',176.72,232.09,10)`

#### Route: `1.25B Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock35`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1458.22,214.71,378.48)`
  2. `Vector3.new(-1458.94,214.71,461.01)`
  3. `Vector3.new(-1456.73,214.72,627.46)`
  4. `Vector3.new(-1436.28,360.71,622.02)`
  5. `Vector3.new(-1436.83,360.71,580.85)`
  6. `Vector3.new(-1329.42,363.38,514.71)`
  7. `Vector3.new(-1249.38,328.17,518.92)`
  8. `Vector3.new(-1237.0,324.37,604.52)`
  9. `Vector3.new(-1236.11,328.55,682.06)`
  10. `Vector3.new(-1218.74,345.87,835.48)`
  11. `Vector3.new(-1371.46,364.31,839.30)`
  12. `Vector3.new(-1402.59,358.73,839.35)`
  13. `Vector3.new(-1404.02,373.70,724.20)`
  14. `Vector3.new(-1404.13,532.72,754.06)`
  15. `Vector3.new(-1416.31,532.72,757.31)`
  16. `Vector3.new(-1431.33,532.62,759.62)`
- **Axis / Tween Segments (`Q`):**
  - `Q("z",461.01,535.01,10)`
  - `Q('z',580.85,516.73,10,359.91)`
  - `Q("x",-1432.85,-1370.77,10,359.80)`
  - `Q('x',-1329.42,-1256.57,10,328.20)`
  - `Q('z',518.92,579.21,10,318.02)`
  - `Q("z",604.52,641.39,7,328.55)`
  - `Q("z",682.06,754.47,10,334.78)`
  - `Q('x',-1218.74,-1256.9,10,349.44)`

#### Route: `2B Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock36`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1391.47,532.72,857.95)`
  2. `Vector3.new(-1309.55,532.72,1216.51)`
  3. `Vector3.new(-1395.61,532.72,1322.67)`
  4. `Vector3.new(-1431.45,530.61,1329.82)`

#### Route: `3.5B Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock37`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1403.92,532.72,1370.41)`
  2. `Vector3.new(-1440.89,532.72,1437.77)`
  3. `Vector3.new(-1450.16,508.72,1446.18)`
  4. `Vector3.new(-2034.55,508.72,1447.40)`
  5. `Vector3.new(-2061.63,442.72,1483.68)`
  6. `Vector3.new(-2062.37,440.61,1459.37)`

#### Route: `5.5B Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock38`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-2108.13,442.72,1480.43)`
  2. `Vector3.new(-2167.62,450.90,1483.76)`
  3. `Vector3.new(-2303.95,438.72,1488.53)`
  4. `Vector3.new(-2336.33,446.07,1489.94)`
  5. `Vector3.new(-2377.42,447.72,1486.59)`
  6. `Vector3.new(-2416.13,438.72,1482.57)`
  7. `Vector3.new(-2448.73,438.72,1483.99)`
  8. `Vector3.new(-2495.35,446.36,1486.04)`
  9. `Vector3.new(-2530.1,458.00,1487.55)`
  10. `Vector3.new(-2546.52,464.21,1488.27)`
  11. `Vector3.new(-2689.61,442.72,1489.92)`
  12. `Vector3.new(-2728.75,450.67,1489.92)`
  13. `Vector3.new(-2863.25,578.98,1484.21)`
  14. `Vector3.new(-2936.68,546.35,1485.69)`
  15. `Vector3.new(-2935.84,644.02,1487.80)`
  16. `Vector3.new(-3011.83,615.90,1486.04)`
  17. `Vector3.new(-2999.28,720.88,1486.99)`
  18. `Vector3.new(-3087.81,674.12,1488.96)`
  19. `Vector3.new(-3163.04,672.24,1486.99)`
  20. `Vector3.new(-3212.15,672.23,1486.47)`
  21. `Vector3.new(-3217.24,672.12,1459.43)`
- **Axis / Tween Segments (`Q`):**
  - `Q("x",-2167.62,-2277.46,5,438.72)`
  - `Q("x",-2546.52,-2663.29,15,442.72)`
  - `Q('x',-2728.75,-2859.0,15,467.14)`

#### Route: `8.5B Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock39`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-3240.66,672.23,1487.13)`
  2. `Vector3.new(-3628.39,618.53,1486.45)`
  3. `Vector3.new(-3653.68,616.57,1486.45)`
  4. `Vector3.new(-3657.56,614.46,1459.28)`

#### Route: `16B Wins`
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock40`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-3755.15,616.57,1485.15)`
  2. `Vector3.new(-4020.58,616.57,1485.51)`
  3. `Vector3.new(-4125.63,616.57,1483.66)`
  4. `Vector3.new(-4130.56,616.57,1458.66)`


### BBNO

#### Route: `1 Cash`
- **Target Win Block:** `workspace:FindFirstChild("EverythingElse",true):FindFirstChild('WinBlock1',true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-132.72,59.43,-234.29)`
  2. `Vector3.new(-113.82,59.44,-234.29)`
  3. `Vector3.new(-84.66,59.43,-234.29)`
  4. `Vector3.new(-55.84,59.43,-234.3)`
  5. `Vector3.new(-25.96,59.43,-234.3)`
  6. `Vector3.new(2.17,59.43,-232.79)`
  7. `Vector3.new(32.55,59.43,-232.86)`
  8. `Vector3.new(61.60,59.43,-233.85)`
  9. `Vector3.new(130.19,59.53,-229.55)`
  10. `Vector3.new(139.02,59.53,-206.93)`
  11. `Vector3.new(142.63,59.53,-193.49)`
- **Axis / Tween Segments (`Q`):**
  - `Q('x',-113.82,-97.56,5)`
  - `Q('x',-84.66,-68.74,5)`
  - `Q("x",-55.84,-39.96,5)`
  - `Q("x",-25.96,-12.15,5)`
  - `Q("x",2.17,20.56,5)`
  - `Q('x',33.03,45.95,5)`
  - `Q('x',61.60,78.22,5)`

#### Route: `10 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock3",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(177.88,59.53,-214.3)`
  2. `Vector3.new(240.43,59.52,-192.1)`
  3. `Vector3.new(303.10,59.52,-178.79)`
  4. `Vector3.new(343.46,59.52,-188.04)`
  5. `Vector3.new(382.64,59.52,-210.75)`
  6. `Vector3.new(446.74,59.52,-231.04)`
  7. `Vector3.new(470.86,59.52,-235.57)`
  8. `Vector3.new(493.38,59.52,-236.01)`
  9. `Vector3.new(1075,167,-702.0)`
  10. `Vector3.new(1079.35,167.64,-682.96)`
  11. `Vector3.new(1067.85,167.66,-639.57)`
  12. `Vector3.new(1057.62,167.66,-604.86)`
  13. `Vector3.new(1050.03,167.66,-572.77)`
  14. `Vector3.new(1075.53,168.65,-538.68)`
  15. `Vector3.new(1087.46,168.65,-496.78)`
  16. `Vector3.new(1088.57,167.66,-451.37)`
  17. `Vector3.new(1054.93,167.64,-388.9)`
  18. `Vector3.new(1032.29,167.47,-385.5)`
- **Axis / Tween Segments (`Q`):**
  - `Q('z',-639.57,-617.47,5)`
  - `Q("z",-604.86,-579.66,5)`
  - `Q('z',-572.77,-539.64,5)`
  - `Q("z",-538.68,-507.89,5)`
  - `Q("z",-496.78,-470.13,5)`

#### Route: `20 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock4",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1054.00,167.64,-356.57)`
  2. `Vector3.new(1068.66,167.64,-339.77)`
  3. `Vector3.new(1072.24,167.64,-113.27)`
  4. `Vector3.new(1053.44,167.64,-70.75)`
  5. `Vector3.new(1032.29,167.47,-65.5)`

#### Route: `50 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock5",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1051.58,167.64,-61.34)`
  2. `Vector3.new(1075.25,167.64,-9.33)`
  3. `Vector3.new(1074.93,167.64,201.89)`
  4. `Vector3.new(1051.58,167.64,251.63)`
  5. `Vector3.new(1032.29,165.47,254.49)`

#### Route: `100 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock6",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1073.64,167.64,290.62)`
  2. `Vector3.new(1072.98,167.64,329.23)`
  3. `Vector3.new(1071.46,167.64,744.65)`
  4. `Vector3.new(1071.89,167.64,796.01)`
  5. `Vector3.new(1075.10,165.47,815.61)`

#### Route: `150 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild('WinBlock7',true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1058.25,167.64,787.80)`
  2. `Vector3.new(1030.43,167.64,775.00)`
  3. `Vector3.new(989.49,167.39,774.46)`
  4. `Vector3.new(896.68,152.78,775.28)`
  5. `Vector3.new(858.70,162.71,775.62)`
  6. `Vector3.new(792.59,171.39,776.21)`
  7. `Vector3.new(766.19,167.90,776.44)`
  8. `Vector3.new(750.57,161.70,776.58)`
  9. `Vector3.new(734.33,161.02,776.72)`
  10. `Vector3.new(717.31,163.94,776.87)`
  11. `Vector3.new(700.75,166.79,777.01)`
  12. `Vector3.new(682.97,169.88,777.16)`
  13. `Vector3.new(678.30,170.83,777.20)`
  14. `Vector3.new(576.58,153.93,776.55)`
  15. `Vector3.new(560.15,157.11,776.40)`
  16. `Vector3.new(548.00,160.49,776.30)`
  17. `Vector3.new(461.37,153.87,776.39)`
  18. `Vector3.new(422.97,165.56,776.42)`
  19. `Vector3.new(399.79,167.64,775.21)`
  20. `Vector3.new(375.96,167.64,754.90)`
  21. `Vector3.new(354.61,167.64,745.35)`
  22. `Vector3.new(354.29,165.47,732.48)`
- **Axis / Tween Segments (`Q`):**
  - `Q("x",989.49,903.64,10)`
  - `Q('x',858.70,804.76,10,171.39)`
  - `Q('x',678.30,591.58,10,153.93)`
  - `Q("x",548.00,474.80,10,153.87)`

#### Route: `300 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock8",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(327.48,167.64,758.88)`
  2. `Vector3.new(310.44,167.64,773.39)`
  3. `Vector3.new(151.04,167.64,768.83)`
  4. `Vector3.new(-113.87,167.64,779.67)`
  5. `Vector3.new(-207.99,167.64,775.43)`
  6. `Vector3.new(-387.62,167.64,773.66)`
  7. `Vector3.new(-463.2,167.64,775.82)`
  8. `Vector3.new(-493.73,166.28,775.21)`
  9. `Vector3.new(-173.0,307,-897.0)`
  10. `Vector3.new(-172.2,305.51,-853.5)`

#### Route: `500 Cash`
- **Target Win Block:** `workspace:FindFirstChild("EverythingElse",true):FindFirstChild('WinBlock9',true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-137.69,307.68,-896.06)`
  2. `Vector3.new(-52.99,307.67,-846.61)`
  3. `Vector3.new(219.98,307.67,-945.54)`
  4. `Vector3.new(525.09,307.67,-864.82)`
  5. `Vector3.new(555.58,307.67,-865.87)`
  6. `Vector3.new(671.20,307.67,-882.11)`
  7. `Vector3.new(739.02,307.68,-870.92)`
  8. `Vector3.new(744.29,305.51,-853.49)`
- **Axis / Tween Segments (`Q`):**
  - `Q("x",555.58,645.77,8)`

#### Route: `1000 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild("WinBlock10",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(770.32,307.68,-888.46)`
  2. `Vector3.new(1135.07,306.24,-896.29)`
  3. `Vector3.new(1528.40,307.68,-895.34)`
  4. `Vector3.new(1607.47,305.5,-896.3)`

#### Route: `2500 Cash`
- **Target Win Block:** `workspace:FindFirstChild('EverythingElse',true):FindFirstChild('WinBlock11',true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1591.33,307.68,-879.96)`
  2. `Vector3.new(1590.50,306.64,-831.37)`
  3. `Vector3.new(1637.70,306.64,-774.82)`
  4. `Vector3.new(1768.62,306.64,-708.91)`
  5. `Vector3.new(1870.80,306.64,-558.7)`
  6. `Vector3.new(1961.49,306.64,-83.75)`
  7. `Vector3.new(1871.89,306.64,-47.08)`
  8. `Vector3.new(1829.88,307.68,14.27)`
  9. `Vector3.new(1799.73,307.68,24.07)`
  10. `Vector3.new(1785.29,305.51,24.49)`

#### Route: `10000 Cash`
- **Target Win Block:** `workspace:FindFirstChild("EverythingElse",true):FindFirstChild("WinBlock12",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1820.94,307.68,58.98)`
  2. `Vector3.new(1822.18,307.68,67.28)`
  3. `Vector3.new(1826.00,307.68,168.84)`
  4. `Vector3.new(1827.18,307.68,167.82)`
  5. `Vector3.new(1826.56,810.68,178.63)`
  6. `Vector3.new(1827.79,810.68,339.95)`
  7. `Vector3.new(1830.23,810.68,468.44)`
  8. `Vector3.new(1827.63,810.68,600.55)`
  9. `Vector3.new(1827.63,810.68,755.36)`
  10. `Vector3.new(1822.70,810.68,859.54)`
  11. `Vector3.new(1822.70,810.68,958.97)`
  12. `Vector3.new(1828.09,808.51,987.68)`
- **Axis / Tween Segments (`Q`):**
  - `Q('z',339.95,425.76,10)`
  - `Q("z",600.55,695.27,10)`

#### Route: `25000 Cash`
- **Target Win Block:** `workspace:FindFirstChild("EverythingElse",true):FindFirstChild("WinBlock13",true)`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(1756.28,810.68,948.19)`
  2. `Vector3.new(1637.89,810.68,932.86)`
  3. `Vector3.new(1569.13,817.75,891.75)`
  4. `Vector3.new(1424.50,810.67,871.66)`
  5. `Vector3.new(1409.38,810.67,860.12)`
  6. `Vector3.new(1375.46,818.18,845.95)`
  7. `Vector3.new(1085.42,810.67,852.56)`
  8. `Vector3.new(936.15,810.67,851.35)`
  9. `Vector3.new(914.45,810.67,900.74)`
  10. `Vector3.new(883.44,810.67,942.78)`
  11. `Vector3.new(855.03,810.68,951.44)`
  12. `Vector3.new(809.69,810.68,921.83)`
  13. `Vector3.new(807.29,808.51,902.49)`
- **Axis / Tween Segments (`Q`):**
  - `Q('x',1569.13,1428.92,15,810.67)`
  - `Q('x',1375.46,1210.54,15,810.67)`
  - `Q('x',1085.42,948.61,15,804.28)`

#### Route: `50000 Cash`
- **Target Win Block:** `workspace.EverythingElse.FinalSAS.WinPad:FindFirstChild('WinBlock14')`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(766.63,810.68,942.38)`
  2. `Vector3.new(733.98,810.75,935.17)`
  3. `Vector3.new(714.95,810.75,699.80)`
  4. `Vector3.new(712.65,810.75,573.42)`
  5. `Vector3.new(598.73,810.75,566.76)`
  6. `Vector3.new(594.86,810.75,476.48)`
  7. `Vector3.new(403.02,810.75,468.67)`
  8. `Vector3.new(401.96,810.75,732.33)`
  9. `Vector3.new(505.19,810.75,739.38)`
  10. `Vector3.new(515.39,810.75,839.95)`
  11. `Vector3.new(320.87,810.75,840.91)`
  12. `Vector3.new(315.45,810.75,946.99)`
  13. `Vector3.new(202.00,810.75,948.63)`
  14. `Vector3.new(126.13,810.68,945.22)`
  15. `Vector3.new(100.12,808.96,945.90)`


### World 3

#### Route: `300M Wins`
- **Target Win Block:** `workspace["NPC & Piege"].Ball1.BallSpawn`
- **CFrame / Vector3 Waypoints:**
  1. `Vector3.new(-1433.18,-159.43,-918.69)`
  2. `Vector3.new(-1443.18,-159.43,-918.69)`
  3. `Vector3.new(-1442.42,-160.68,-856.0)`

### World 3 — Dynamic `300M Wins` Variants (via `k.UpdateRoute`)

The script dynamically updates the `300M Wins` route in World 3 depending on whether **Wait Mode** is enabled:

#### `300M Wins` (Wait Mode = true)
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock32`
  1. `Vector3.new(-1433.18,-159.43,-918.69)`
  2. `Vector3.new(-1443.18,-159.43,-918.69)`
  3. `Vector3.new(-1442.42,-160.68,-856.0)`
  4. `Vector3.new(-1433.7,-157.07,-832.8)`
  5. `Vector3.new(-1443.7,-157.07,-832.8)`
  6. `Vector3.new(-1442.99,-142.74,-787.21)`
  7. `Vector3.new(-1442.94,-125.83,-733.44)`
  8. `Vector3.new(-1430.96,-125.73,-733.13)`
  9. `Vector3.new(-1440.96,-125.73,-733.13)`
  10. `Vector3.new(-1444.83,-111.0,-686.28)`
  11. `Vector3.new(-1442.15,-92.21,-630.54)`
  12. `Vector3.new(-1431.08,-90.91,-630.42)`
  13. `Vector3.new(-1445.38,-83.54,-618.05)`
  14. `Vector3.new(-1443.04,-68.54,-532.27)`
  15. `Vector3.new(-1481.83,-68.65,-515.77)`

#### `300M Wins` (Wait Mode = false)
- **Target Win Block:** `workspace.Structure.Stage1.SAS.WinBlock32`
  1. `Vector3.new(-1436.38,-159.43,-934.65)`
  2. `Vector3.new(-1434.34,-159.43,-887.05)`
  3. `Vector3.new(-1441.31,-69.54,-526.62)`
  4. `Vector3.new(-1481.83,-71.65,-515.77)`