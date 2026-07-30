# +1 Speed Keyboard Escape — Comprehensive Script Features & Architecture

This document compiles and documents **every major subsystem, function module, and utility feature** deobfuscated from the `+1 Speed Keyboard Escape.lua` script.

---

## 1. Core Movement & Teleportation Modules (`r`)

### `r.GetMagnitude(m)`
- **Purpose:** Calculates Euclidean distance (`Magnitude`) between a target position/CFrame (`m`) and the player's `PrimaryPart` (`HumanoidRootPart`).
- **Parameters:** `m` (`CFrame` or `Vector3`).
- **Returns:** Distance in studs (`number`) or `math.huge` if character is missing.

### `r.GetTo(m)`
- **Purpose:** Safe PivotTo teleportation wrapper.
- **Behavior:** Checks that the character exists and `w.IsTeleporting` is `false` before calling `Character:PivotTo(m)`.

### `r.Teleport(m)`
- **Purpose:** Forced loop teleportation.
- **Behavior:** Continuously assigns `y.Character.HumanoidRootPart.CFrame = m` in a repeat-until loop until `(q - m.Position).Magnitude < 1`.

### `r.MoveTo(b)`
- **Purpose:** Precision CFrame movement helper with velocity dampening.
- **Behavior:**
  1. Sets `Velocity = Vector3.zero` and `RotVelocity = Vector3.zero`.
  2. Temporarily sets `q.Anchored = true` and `w.IsTeleporting = true`.
  3. Moves character using `SetPrimaryPartCFrame` with a Y-offset of `+2.5` studs.
  4. Waits `0.06` seconds, unanchors, and zeroes out velocity again.

---

## 2. Automation & External Integrations

### `r.Webhook(url, payload)`
- **Purpose:** Discord Webhook integration for milestone and purchase notifications.
- **Behavior:** Dynamically detects the exploit's HTTP API (`request`, `syn.request`, `http.request`, `fluxus.request`, `http_request`), encodes the table payload using JSON, and sends a `POST` request with `'Content-Type': 'application/json'`.

### `r.ClickUI(guiObject)`
- **Purpose:** Programmatic UI button clicking without mouse movement.
- **Behavior:** Enables button selectability and navigation, assigns `GuiService.SelectedObject = guiObject`, and fires `ContextActionService:SendKeyEvent` with `Enum.KeyCode.Return` (Enter down and up) to trigger a native button activation.

### `r.GetImageURL(assetId)`
- **Purpose:** Converts Roblox asset IDs into direct 420x420 PNG image URLs via Roblox's web API.
- **Behavior:** Queries `https://thumbnails.roblox.com/v1/assets?assetIds={ID}&size=420x420&format=Png&isCircular=false`, parses the JSON response, and caches the URL in `O.Image[assetId]`.

### `r.PlayAnimation(animationId)`
- **Purpose:** Custom animation track loader.
- **Behavior:** Stops all existing playing animation tracks on the Humanoid's `Animator`, creates a new `Animation` instance with `AnimationId`, loads it, and plays it.

---

## 3. Utility & Lifecycle Engine (`r.Utils`)

### `k.Connections(event, callback, cacheKey)`
- **Purpose:** Safe event connector.
- **Behavior:** Wraps callbacks in `pcall`, checks if the script is unloaded (`W[1][W[3]].Unloaded`), and automatically logs errors. Stores connection handle in `s[cacheKey]` for easy teardown.

### `k.Disconnect(cacheKey)`
- **Purpose:** Safely disconnects and clears a cached event listener from `s[cacheKey]`.

### `k.StartLoop(name, callback)`
- **Purpose:** Non-blocking managed loop thread.
- **Behavior:** Runs inside `while not Unloaded do`, checks toggle state `w[name]`, executes callback in `pcall`, and yields via `task.wait(0)`.

### `k.Fallback(name, threshold, fallbackFn)`
- **Purpose:** Error recovery and stuck-state detection counter.

---

## 4. World Building & Teleportation (`r.World`)

### `k.GetPath(root, ...)`
- **Purpose:** Traverses instance hierarchies safely using `WaitForChild(name)` for every argument.

### `k.ApplyBaseProperties(part, props)`
- **Purpose:** Standardizes newly created helper parts (sets `CanCollide`, `Anchored`, `Transparency`, `BrickColor`, `Material`).

### `k.CreatePartOnce(parent, className, name, ...)`
- **Purpose:** Singleton part creator (returns existing child if found, or creates a new one).

---

## 5. Anti-Cheat Bypass & Character Manipulation (`r.Misc`)

### `I.BypassWalkSpeed()`
- **Purpose:** Spoofer for client speed anti-cheat.
- **Behavior:** Uses `getrawmetatable(game)` to hook `__index`. When scripts query `Humanoid.WalkSpeed`, the closure intercepts the read and returns `16` (default speed), allowing the player to move at custom speeds without detection.

### `I.FreezeAndClone()`
- **Purpose:** Creates a safe anchored checkpoint ghost of the player.
- **Behavior:**
  1. Freezes current `CFrame` and saves transparency modifiers for all parts and decals.
  2. Clones the character (`Name = 'Checkpoint'`), strips out all LocalScripts/Scripts, and anchors all BaseParts.
  3. Sets `CameraType = Scriptable` and binds `RenderStepped` to lock camera view to the frozen CFrame.

### `I.UnfreezeAndDeleteClone()`
- **Purpose:** Restores character visibility, deletes `CharacterClone`, disconnects `RenderStepped` freeze hook, and returns camera to `Custom` tracking `Humanoid`.

### `I.EnableNoInput()` & `I.DisableNoInput()`
- **Purpose:** Completely locks player input during automated sequences.
- **Behavior:**
  - Disables Roblox `PlayerModule` controls (`GetControls():Disable()`).
  - Binds context action `'BlockAllPlayerInput'` at maximum priority `999999` returning `Enum.ContextActionResult.Sink` across Keyboard, MouseButtons, Touch, and Gamepads.
  - Displays a red-and-white GUI banner (`'[START]'`) on screen.

---

## 6. Auto-Buy Shop Automation (`S = function(r)`)

- **Purpose:** Automates purchasing rarity items from `SpeedGameUI.Modals.ItemShopModal.ShopItemsFrame`.
- **Supported Rarities:**
  - Standard: `Common`, `Uncommon`, `Rare`
  - Premium/Mysterious: `Epic`, `Legendary`, `Mythic`, `Secret`, `Mysterious`
- **Behavior:** Checks if text is not `'Sold out'`, matches `^(%d+)/` stock counter, and invokes `BuyWins:FireServer(rarity)`.

---

## 7. Hazard & Obstacle Bypass (`NPC & Piege`)

- **Purpose:** Automated avoidance handlers for stage hazards.
- **Features:**
  - `KillBall` avoidance: Monitors ball spawn/kill positions.
  - `Tsunami1`: Reads timer countdowns.
  - `EyesLaser`: Detects active laser beams in Stage 9.
  - `MovingWalls`: Synchronizes movement with Stage 9 wall cycles.
