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
- [ ] On-screen debug log added during development
- [ ] Check F9 Developer Console after every publish
