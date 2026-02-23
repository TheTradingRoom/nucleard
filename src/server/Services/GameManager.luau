-- Nuclear'd Game Manager
-- Top-level orchestrator: initializes all services, handles player lifecycle

local Players = game:GetService("Players")

local PlotService = require(script.Parent.PlotService)
local ResourceSystem = require(script.Parent.ResourceSystem)
local BuildingSystem = require(script.Parent.BuildingSystem)
local TechSystem = require(script.Parent.TechSystem)
local UnitSystem = require(script.Parent.UnitSystem)
local WaveSystem = require(script.Parent.WaveSystem)
local NuclearSystem = require(script.Parent.NuclearSystem)

local GameManager = {}

function GameManager.Init()
	print("[GameManager] Initializing all systems...")

	-- Initialize services in dependency order
	PlotService.Init()
	ResourceSystem.Init()
	BuildingSystem.Init()
	TechSystem.Init()
	UnitSystem.Init()
	WaveSystem.Init()
	NuclearSystem.Init()

	-- Player lifecycle
	Players.PlayerAdded:Connect(function(player)
		GameManager.OnPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		GameManager.OnPlayerRemoving(player)
	end)

	-- Handle players who joined before this script ran
	for _, player in Players:GetPlayers() do
		task.spawn(GameManager.OnPlayerAdded, player)
	end

	-- Start game ticks
	GameManager.StartTickLoops()

	print("[GameManager] All systems initialized.")
end

function GameManager.OnPlayerAdded(player: Player)
	print("[GameManager] Player joined:", player.Name)

	-- Assign plot
	PlotService.AssignPlot(player)

	-- Initialize resources
	ResourceSystem.InitPlayer(player)

	-- Initialize tech
	TechSystem.InitPlayer(player)

	-- Start wave timer for this player
	WaveSystem.StartForPlayer(player)

	-- Hide character (RTS — no walking around)
	local function hideCharacter(character)
		-- Wait for humanoid to exist
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			-- Make invincible so no death loop
			humanoid.MaxHealth = math.huge
			humanoid.Health = math.huge
		end

		-- Make all parts invisible and non-collidable
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 1
			end
		end

		-- Also handle parts added later (accessories loading in)
		character.DescendantAdded:Connect(function(desc)
			if desc:IsA("BasePart") then
				desc.Transparency = 1
				desc.CanCollide = false
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				desc.Transparency = 1
			end
		end)
	end

	if player.Character then
		task.spawn(hideCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(hideCharacter, character)
	end)
end

function GameManager.OnPlayerRemoving(player: Player)
	print("[GameManager] Player leaving:", player.Name)

	-- Cleanup in reverse order
	NuclearSystem.CleanupPlayer(player)
	WaveSystem.CleanupPlayer(player)
	UnitSystem.CleanupPlayer(player)
	BuildingSystem.CleanupPlayer(player)
	TechSystem.CleanupPlayer(player)
	ResourceSystem.CleanupPlayer(player)
	PlotService.RemovePlot(player)
end

function GameManager.StartTickLoops()
	-- Economy tick (1 Hz)
	task.spawn(function()
		while true do
			task.wait(1)
			ResourceSystem.Tick()
			BuildingSystem.Tick()
		end
	end)

	-- Combat tick (2 Hz)
	task.spawn(function()
		while true do
			task.wait(0.5)
			UnitSystem.CombatTick()
			WaveSystem.CombatTick()
			BuildingSystem.TurretTick()
		end
	end)

	-- Movement tick (10 Hz)
	task.spawn(function()
		while true do
			task.wait(0.1)
			UnitSystem.MovementTick()
			WaveSystem.MovementTick()
		end
	end)

	-- Nuclear enrichment tick (1 Hz)
	task.spawn(function()
		while true do
			task.wait(1)
			NuclearSystem.Tick()
		end
	end)
end

return GameManager
