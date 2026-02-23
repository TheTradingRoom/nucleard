# Nuclear'd Build Lessons — Real World Rojo/Roblox Gotchas

*Documented during the V1 MVP build of Nuclear'd (Feb 2026). Every issue here was hit in production and cost at least one publish cycle to debug.*

---

## 1. Rojo Folder Visibility — `init.meta.json` Required

**Problem:** Created `src/server/Services/` and `src/client/Controllers/` directories with `.luau` files inside them. Built fine with Rojo. But at runtime: `"Controllers is not a valid member of PlayerScripts"`.

**Root Cause:** Rojo doesn't always emit bare directories as Folder instances in the DataModel. Without an `init.meta.json`, the directory may not appear as a reachable child at runtime.

**Fix:** Add `init.meta.json` to every directory that scripts need to `require()` into:

```json
{
  "className": "Folder"
}
```

**Files that needed this:**
- `src/server/Services/init.meta.json`
- `src/client/Controllers/init.meta.json`
- `src/shared/GameConfig/init.meta.json`

**Rule:** If you create a subdirectory under a `$path` target, always add `init.meta.json` with `"className": "Folder"`.

---

## 2. WaitForChild Everywhere — The #1 Runtime Killer

**Problem:** Scripts crash with `"X is not a valid member of Y"` even though the instance clearly exists in the built .rbxl.

**Root Cause:** Scripts execute before the DataModel is fully populated. Direct dot-access like `ReplicatedStorage.Constants` fails because `Constants` hasn't loaded yet when the line runs.

**Affects BOTH server and client.** Server scripts in ServerScriptService race against ReplicatedStorage population. Client scripts in PlayerScripts race against everything.

**Fix:** Use `WaitForChild()` for ANY cross-service reference:

```lua
-- BAD — race condition
local Constants = require(ReplicatedStorage.Constants)
local Remotes = ReplicatedStorage.Network.Remotes

-- GOOD — waits for instance to exist
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")
```

**Also applies to Bootstrap scripts finding their sibling folders:**
```lua
-- BAD
local GameManager = require(script.Parent.Services.GameManager)

-- GOOD
local Services = script.Parent:WaitForChild("Services", 10)
local GameManager = require(Services:WaitForChild("GameManager"))
```

**Exception:** Sibling requires within the same folder are safe (e.g., `require(script.Parent.PlotService)` from GameManager inside Services/) because they're loaded together.

**Rule:** Any time you cross a service boundary (ServerScriptService → ReplicatedStorage, PlayerScripts → ReplicatedStorage, Bootstrap → sibling folder), use `WaitForChild`.

---

## 3. `script` vs `script.Parent` — Know Your Rojo Tree Position

**Problem:** `require(script.Services.GameManager)` fails silently. No error, just nothing works.

**Root Cause:** In the Rojo project tree:
```
ServerScriptService ($path = "src/server")
├── Bootstrap (from Bootstrap.server.luau)   ← this is `script`
├── Services/ (folder)
│   ├── GameManager.luau
│   └── ...
```

`Bootstrap.server.luau` becomes a **child** of ServerScriptService, NOT the root. `Services/` is a **sibling**, not a child of Bootstrap. So `script.Services` looks for Services *inside* Bootstrap — which doesn't exist.

**Fix:** `script.Parent.Services.GameManager` (go up to the service, then down to sibling).

**Rule:** `$path` files become children of the mapped service. To reach siblings, always go through `script.Parent`.

---

## 4. SpawnLocation Gotchas — Glow, ForceField, Timing

### 4a. No SpawnLocation = Death Loop

**Problem:** Player joins, spawns at origin in mid-air, falls to death, respawns, dies again, infinite loop.

**Root Cause:** No SpawnLocation exists in the DataModel. Roblox spawns the character at (0, 100, 0) or wherever, and if there's no ground, they die.

**Fix:** Bake a SpawnLocation into `default.project.json` so it exists before any scripts run:
```json
"SpawnPoint": {
  "$className": "SpawnLocation",
  "$properties": {
    "Position": [32, -10, 32],
    "Anchored": true,
    "Transparency": 1,
    "CanCollide": false,
    "Enabled": true,
    "Duration": 0
  }
}
```

**Rule:** Never rely on server scripts to create the SpawnLocation — they may run too late.

### 4b. SpawnLocation Creates a ForceField

**Problem:** Character spawns with a glowing bubble effect around them.

**Root Cause:** SpawnLocation gives a ForceField to characters by default (Duration property controls how long).

**Fix:** Set `Duration = 0` on the SpawnLocation. Also destroy any ForceField that appears:
```lua
character.ChildAdded:Connect(function(child)
    if child:IsA("ForceField") then
        child:Destroy()
    end
end)
```

### 4c. SpawnLocation Has a Special Visual Shader

**Problem:** The floor was "glowing bright" — SpawnLocations have a distinctive visual rendering that makes them look different from normal Parts.

**Fix:** If you just need a floor, use a regular `Part`. Put the `SpawnLocation` somewhere hidden (underground, transparent, CanCollide=false) and use a separate visible `Part` for the actual floor.

---

## 5. RTS Camera — Fight Roblox Every Frame

**Problem:** Set `camera.CameraType = Enum.CameraType.Scriptable` once in Init(). Camera immediately resets to following the character.

**Root Cause:** Roblox's default camera scripts constantly reset CameraType back to `Custom` and CameraSubject back to the Humanoid. Setting it once is not enough.

**Fix:** Force it EVERY frame in RenderStepped:
```lua
RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end
    camera.CameraSubject = nil
    -- ... apply your custom CFrame
end)
```

**Rule:** For custom cameras, set CameraType and CameraSubject every single frame.

---

## 6. Hiding the Character in a Non-FPS Game

**Problem:** In an RTS/top-down game, the player's 3D avatar is visible, collidable, and the camera keeps snapping to it.

**What DOESN'T work:**
- `math.huge` for MaxHealth — Roblox may not accept it
- Just setting Transparency — accessories load asynchronously and appear later
- Just hiding — character is still collidable and can push game objects

**What DOES work — the full recipe:**
```lua
local function hideCharacter(character)
    -- Kill ForceField
    character.ChildAdded:Connect(function(child)
        if child:IsA("ForceField") then child:Destroy() end
    end)

    local rootPart = character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = character:WaitForChild("Humanoid", 10)

    if humanoid then
        humanoid.MaxHealth = 99999
        humanoid.Health = 99999
        humanoid.WalkSpeed = 0
        humanoid.JumpHeight = 0
        humanoid.JumpPower = 0
    end

    -- Teleport underground and anchor
    if rootPart then
        rootPart.CFrame = CFrame.new(0, -50, 0)
        rootPart.Anchored = true
    end

    -- Invisible + non-collidable
    for _, desc in character:GetDescendants() do
        if desc:IsA("BasePart") then
            desc.Transparency = 1
            desc.CanCollide = false
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = 1
        end
    end

    -- Catch late-loading accessories
    character.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            desc.Transparency = 1
            desc.CanCollide = false
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            desc.Transparency = 1
        end
    end)
end

-- Must handle both initial spawn and respawns
if player.Character then task.spawn(hideCharacter, player.Character) end
player.CharacterAdded:Connect(function(char) task.spawn(hideCharacter, char) end)
```

---

## 7. pcall Your Bootstrap — Silent Failures Kill Debugging

**Problem:** Game loads, nothing works, no errors visible. Spent multiple publish cycles guessing.

**Root Cause:** When a `require()` or `Init()` call fails at the top level of a Script, the error goes to the server console but isn't visible to the player. If you don't have Studio access, you're blind.

**Fix:** Wrap your bootstrap in pcall and `warn()`:
```lua
local success, err = pcall(function()
    local Services = script.Parent:WaitForChild("Services", 10)
    local GameManager = require(Services:WaitForChild("GameManager"))
    GameManager.Init()
end)

if not success then
    warn("[Nuclear'd] SERVER INIT FAILED:", err)
end
```

Now errors show as yellow warnings in the F9 Developer Console in-game.

**Rule:** Always pcall your bootstrap. Always check F9 in-game.

---

## 8. Static Parts in `default.project.json` vs Script-Created Parts

**Problem:** Script creates a floor Part in `Init()`. Player joins before Init() runs. Player falls through nothing.

**Root Cause:** There's a race between player character spawning and server scripts running. The character can spawn before your script creates the floor.

**Fix:** Anything that MUST exist for the player to not die (floor, spawn point) should be baked into `default.project.json`:
```json
"Workspace": {
    "$className": "Workspace",
    "Floor": {
        "$className": "Part",
        "$properties": {
            "Size": [512, 1, 512],
            "Position": [0, -0.5, 0],
            "Anchored": true
        }
    }
}
```

**Rule:** Essential geometry goes in the project tree. Game-specific geometry (plots, buildings, units) can be script-created.

---

## 9. Rojo Color3 Values — 0-1 Floats, NOT 0-255

**Problem:** Floor Part exists but appears pure white. Entire scene washed out.

**Root Cause:** In `default.project.json`, Color3 properties expect **0-1 float values**. We had:
```json
"Color": [240, 180, 160],
"Ambient": [40, 30, 50]
```
Values > 1.0 get clamped to 1.0, so `[240, 180, 160]` → `[1, 1, 1]` = white. And Ambient of `[40, 30, 50]` was blasting 40x normal light, washing everything out.

**Fix:**
```json
"Color": [0.94, 0.71, 0.63],
"Ambient": [0.16, 0.12, 0.2]
```

**Conversion:** Divide each RGB value by 255. `240/255 = 0.94`, `180/255 = 0.71`, etc.

**Note:** In Luau scripts, `Color3.fromRGB(240, 180, 160)` handles the conversion automatically. This gotcha is **only** in Rojo JSON project files.

**Rule:** In `default.project.json`, all Color3 values must be 0-1 floats. In `.luau` code, use `Color3.fromRGB()` which takes 0-255.

---

## 10. WASD Conflicts — Disable Default Character Controls

**Problem:** WASD keys move the player's avatar instead of panning the custom RTS camera.

**Root Cause:** Roblox's built-in PlayerModule captures WASD/arrow keys for character movement. Even with `WalkSpeed = 0`, the default scripts still consume the input events, preventing your custom camera from seeing them.

**Fix — Server side** (in Bootstrap or project.json):
```lua
local StarterPlayer = game:GetService("StarterPlayer")
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
```

**Fix — Client side** (disable the PlayerModule controls):
```lua
local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule", 10))
local controls = PlayerModule:GetControls()
controls:Disable()
```

**Rule:** For any non-standard camera/movement game (RTS, top-down, fixed camera), disable both the server movement mode AND the client PlayerModule controls.

---

## 11. Character Hiding Must Be Independent of Game Systems

**Problem:** Character hiding code was inside `GameManager.OnPlayerAdded()`. If GameManager failed to init (e.g., due to a require error), character hiding never ran — player avatar stayed visible.

**Root Cause:** Coupling critical UX code (hiding the avatar) to game logic initialization. If any service in the chain errors, everything downstream fails.

**Fix:** Move character hiding to Bootstrap.server.luau, BEFORE game system init:
```lua
-- This runs even if GameManager.Init() fails
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        task.spawn(hideCharacter, player, character)
    end)
end)

-- Game systems init (may fail, but character is still hidden)
local success, err = pcall(function()
    GameManager.Init()
end)
```

**Rule:** Safety-critical code (spawn handling, character setup, crash recovery) should run independently from game logic, not nested inside it.

---

## 12. On-Screen Debug Log — You Can't Copy from Roblox Dev Console

**Problem:** Errors only visible in F9 Developer Console, which doesn't support copy/paste. Debugging via screenshots of tiny console text is painful.

**Fix:** Create a ScreenGui debug panel that captures LogService messages and displays them on-screen:
```lua
local LogService = game:GetService("LogService")
LogService.MessageOut:Connect(function(message, messageType)
    if message:find("YourGame") then
        addDebugLine(message, colorByType[messageType])
    end
end)
```

For server errors, forward them to clients via a RemoteEvent so they appear in the same panel.

**Rule:** For any Rojo-published game without Studio access, add a debug overlay early. Remove it before public release.

---

## 13. Luau Return Type Annotations — No `?` on Function Returns

**Problem:** `PlotService:147: Expected identifier when parsing expression, got '?'` — kills the entire module.

**Root Cause:** Luau supports `Type?` (optional) in table field annotations, but NOT on function return types. `): Vector3?` or `): (number, number)?` causes a parse error.

**Fix:** Remove `?` from function return type annotations. They're optional anyway:
```lua
-- BAD — parse error
function Foo(): Vector3?
function Bar(): (number, number)?

-- GOOD
function Foo()
function Bar()
```

**Rule:** Never use `?` on function return types. Only use it in table type fields (`field: Type?`).

---

## 14. Mouse Raycasting — ViewportPointToRay, Not ScreenPointToRay

**Problem:** Building placement always goes to grid position (1,1) regardless of where the mouse is.

**Root Cause:** `Mouse.X/Y` returns screen coordinates that include the Roblox top bar (36px). `ScreenPointToRay` also accounts for the top bar. But with Scriptable cameras, the coordinate systems can mismatch, causing wrong world positions.

**Fix:** Use `UserInputService:GetMouseLocation()` + `ViewportPointToRay()`:
```lua
-- BAD — coordinate mismatch with Scriptable camera
local mouse = Players.LocalPlayer:GetMouse()
local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)

-- GOOD — consistent viewport coordinates
local UIS = game:GetService("UserInputService")
local mousePos = UIS:GetMouseLocation()
local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
```

**Rule:** For custom/Scriptable cameras, always use `GetMouseLocation()` + `ViewportPointToRay()`. Never use the deprecated `Mouse` object for raycasting.

---

## 15. RemoteEvent Race Condition — Server Fires Before Client Listens

**Problem:** `plotOrigin` was always `nil` on the client. Ghost wouldn't follow mouse, grid placement failed. Camera only worked because its default center `(32, 0, 32)` happened to match the first plot.

**Root Cause:** The server fires `PlotAssigned` during `PlayerAdded` → `PlotService.AssignPlot()`. But the client hasn't loaded yet — Bootstrap is still requiring modules and calling `Init()`. By the time `InputController.Init()` connects `.OnClientEvent`, the event was already fired and lost forever.

**This is the #1 silent killer in Rojo builds.** Unlike `WaitForChild` (which waits), `OnClientEvent:Connect` only captures FUTURE events. There is no replay buffer.

**Fix — Use Player Attributes (always readable, no timing issue):**

Server side:
```lua
-- In PlotService.AssignPlot()
player:SetAttribute("PlotOriginX", originX)
player:SetAttribute("PlotOriginZ", originZ)
player:SetAttribute("PlotSize", Constants.PLOT_SIZE)

-- Also fire event as backup for any listeners already connected
Remotes.PlotAssigned:FireClient(player, plotData.origin, Constants.PLOT_SIZE)
```

Client side:
```lua
-- Try reading attributes first (already set if server ran before client loaded)
local ox = player:GetAttribute("PlotOriginX")
local oz = player:GetAttribute("PlotOriginZ")
local sz = player:GetAttribute("PlotSize")
if ox and oz and sz then
    plotOrigin = Vector3.new(ox, 0, oz)
    plotSize = sz
else
    -- Not set yet — listen for attribute changes
    player:GetAttributeChangedSignal("PlotOriginX"):Connect(function()
        -- read attributes here
    end)
end

-- Also listen for the event (belt and suspenders)
Remotes:WaitForChild("PlotAssigned").OnClientEvent:Connect(function(origin, size)
    plotOrigin = origin
    plotSize = size
end)
```

**Rule:** For any one-shot server→client data (plot assignment, initial state, player config), ALWAYS store it as Player attributes AND fire the RemoteEvent. Client reads attributes first, connects event as fallback. Never rely solely on a RemoteEvent fired during PlayerAdded.

---

## 16. Build Mode Ghost — Don't Parent at Default Position

**Problem:** Player clicks "Build Barracks" in the panel → ghost Part appears at grid (1,1) in the top-left corner. Player has to "collect" it by moving mouse over the grid.

**Root Cause:** When the build button is clicked, the mouse is over the GUI panel (off the grid). The ghost Part is created with `Instance.new("Part")` which defaults to position `(0, 0, 0)` — which happens to be the plot origin (grid 1,1). The ghost is visible at the wrong spot until `RenderStepped` moves it.

**Fix:** Create the ghost hidden and underground. Only show it once the mouse is actually over the grid:
```lua
-- In EnterBuildMode():
ghostPart.Transparency = 1  -- invisible
ghostPart.Position = Vector3.new(0, -100, 0)  -- underground
ghostPart.Parent = workspace

-- In UpdateGhost() (runs every frame):
if not gridX or not gridZ then
    -- Mouse is off grid — hide ghost
    ghostPart.Transparency = 1
    ghostPart.Position = Vector3.new(0, -100, 0)
    return
end
-- Mouse is on grid — show and snap
ghostPart.Transparency = 0.4
ghostPart.Position = snapPos
```

**Rule:** Never parent a Part at its default position `(0, 0, 0)` and rely on the next frame to move it. Players will see it flash at the wrong spot. Either position it correctly before parenting, or create it hidden.

---

## 17. BillboardGui Clutter — Health Bars and Labels Block the View

**Problem:** Every building, unit, and enemy has a floating name label AND health bar above it. With 10+ buildings and units on screen, the map is unreadable — text everywhere, overlapping, blocking the actual game objects.

**Root Cause:** `AlwaysOnTop = true` on BillboardGuis means they render through everything. Name labels + health bars on every entity = visual noise explosion.

**Fix:**
1. **Remove name labels entirely** — buildings are distinguished by color/size, units by shape. Names are in the UI panels.
2. **Health bars hidden until damaged** — set `Enabled = false` on creation, set `Enabled = true` in `DamageBuilding()`/`DamageUnit()`
3. **Smaller health bars** — `UDim2.new(0, 40, 0, 4)` instead of `(0, 80, 0, 8)`
4. **AlwaysOnTop = false** — health bars render naturally (hidden behind buildings gives depth)

```lua
-- Creation:
healthBarGui.AlwaysOnTop = false
healthBarGui.Enabled = false  -- hidden until damaged

-- In DamageBuilding()/DamageUnit():
healthBar.Enabled = true  -- show on first damage
```

**Exception:** Enemy health bars should always be visible (they're threats the player needs to assess).

**Rule:** In top-down/RTS games, minimize world-space UI. Only show information the player needs in the moment. Use screen-space UI (panels) for details.

---

## 18. gameProcessed Timing with Programmatic GUIs

**Problem:** Expected `gameProcessed = true` in `InputBegan` when clicking GUI buttons, which would prevent `OnLeftClick()` from firing. It DID work — but the build mode entered on `MouseButton1Click` (mouse UP) while `InputBegan` fires on mouse DOWN. So the NEXT click (on the game world) was the real placement click, not the same one.

**Insight:** `InputBegan` = mouse DOWN (fires first), `MouseButton1Click` = mouse UP (fires second). They're different events on the same physical click. `gameProcessed` correctly filters the DOWN event when over GUI, and the button's UP event enters build mode. This means the frame-count guard (`buildModeFrameCount < 2`) was unnecessary for this specific case — but it's still good defensive code.

**Real issue was:** Ghost appeared at wrong position (lesson 16) + plotOrigin was nil (lesson 15), making it LOOK like same-click placement.

**Rule:** When debugging "click does two things at once," trace the exact event order: InputBegan (DOWN) → gameProcessed check → MouseButton1Click (UP). They're rarely the same frame. The real bug is usually elsewhere.

---

## Summary Checklist — Before Every Publish

- [ ] Every subdirectory has `init.meta.json` with `"className": "Folder"`
- [ ] All cross-service `require()` and instance access uses `WaitForChild()`
- [ ] Bootstrap scripts use `script.Parent` (not `script`) to find siblings
- [ ] Bootstrap wrapped in `pcall` with `warn()` on failure
- [ ] SpawnLocation exists in project tree (not script-created)
- [ ] SpawnLocation has `Duration: 0`
- [ ] Character hidden: underground + anchored + transparent + ForceField destroyed
- [ ] Camera forced to Scriptable every frame in RenderStepped
- [ ] Floor/ground exists as static Part in project tree
- [ ] All Color3 values in project.json are 0-1 floats (not 0-255)
- [ ] Default movement controls disabled (DevComputerMovementMode + PlayerModule)
- [ ] Character hiding runs independently in Bootstrap (not inside game system init)
- [ ] One-shot server→client data uses Player attributes (not just RemoteEvent)
- [ ] Ghost/preview Parts created hidden, only shown when properly positioned
- [ ] World-space UI (BillboardGui) kept minimal — health bars hidden until damaged, no name labels
- [ ] On-screen debug log added during development
- [ ] Check F9 Developer Console after every publish
