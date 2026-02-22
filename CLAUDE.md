# Nuclear'd - Claude Instructions

## Project Overview

**Nuclear'd: The Battle for Clear Skin** — a comedic RTS game on Roblox where players are zits battling for dominance on The Great Face. Modern military RTS mechanics reskinned with spot/pimple humor.

- **Roblox Account:** Spin0580
- **Credentials:** Hive credential store (`spin0580` scope for API key + universe ID)
- **Game Design Doc:** NAS at `/mnt/user/ClaudeHive/projects/Roblox/games/nucleard/game-design.md`
- **Full Rojo/Security Reference:** NAS at `/mnt/user/ClaudeHive/projects/Roblox/docs/05_rojo_pipeline_guide.md`

## Tech Stack

- **Build tool:** Rojo 7.6.1 (`rojo build -o game.rbxl`)
- **Publish:** Open Cloud API (PowerShell script in `scripts/publish.ps1`)
- **Packages:** Wally (`wally install` before building)
- **Language:** Luau (use `.luau` extension, not `.lua`)
- **Linter:** Selene | **Formatter:** StyLua

## Architecture: Game Systems Design

Each game system is an independent ModuleScript with a clear API. Server-side systems live in `src/server/Services/`. Client systems in `src/client/Controllers/`.

| System | Location | Responsibility |
|--------|----------|----------------|
| ResourceSystem | server/Services | Sebum, Grease, Bacteria, Sweat tracking |
| BuildingSystem | server/Services | Placement validation, construction, health |
| UnitSystem | server/Services | Spawning, movement, pathfinding, combat |
| TechSystem | server/Services | Age progression, unlock requirements |
| NuclearSystem | server/Services | Enrichment, silo, launch, interception |
| WaveSystem | server/Services | Face Wash enemy waves, The Dermatologist boss |
| InputController | client/Controllers | Click-to-select, movement commands |
| CameraController | client/Controllers | Top-down/isometric camera |
| UIController | client/Controllers | HUD updates, menus |

## Critical Rules

### Rojo
- File extensions: always `.luau` (not `.lua`)
- `init.luau` must be LOWERCASE — `Init.luau` creates silent duplicates
- Only ONE init script per directory
- Set `$ignoreUnknownInstances: true` on services with mixed content
- Never commit `.rbxl` files — they are build artifacts

### Security (MUST follow)
- **NEVER trust the client.** All game logic is server-authoritative
- Client sends INTENTS ("build here", "move unit"), server validates and executes
- Every RemoteEvent handler: type-check args, range-check values, verify player state, rate-limit
- Never use server-to-client RemoteFunctions (exploiters can hang the server)
- Game pass ownership: always verify server-side with `MarketplaceService:UserOwnsGamePassAsync`
- Resources, combat, building — ALL calculated server-side
- ServerScriptService/ServerStorage = server only. ReplicatedStorage = visible to clients
- NEVER put secrets, pricing tables, or authoritative logic in ReplicatedStorage

### Code Style
- Tabs for indentation, 120 char line width
- PascalCase for ModuleScripts, services, classes
- camelCase for local variables and functions
- UPPER_SNAKE for constants
- Wrap pcall around all external API calls (MarketplaceService, DataStore, HTTP)

## Build & Deploy

```bash
# From project root:
rojo build -o game.rbxl
powershell -ExecutionPolicy Bypass -File scripts/publish.ps1
```

## NAS Access

- **Read:** SMB `\\100.93.55.100\ClaudeHive\`
- **Write:** SSH `root@100.93.55.100` (key auth)
- **NAS git mirror:** `/mnt/user/ClaudeHive/projects/Roblox/games/nucleard/repo.git`
- **NEVER use bash with UNC paths** — always write PowerShell to .ps1 files

## Credential Retrieval

```bash
# API Key
curl -s http://100.93.55.100:8743/credentials/get/spin0580/ROBLOX_API_KEY
# Universe ID
curl -s http://100.93.55.100:8743/credentials/get/spin0580/ROBLOX_UNIVERSE_ID
# Place ID (once created for Nuclear'd)
curl -s http://100.93.55.100:8743/credentials/get/nucleard/ROBLOX_PLACE_ID
```
