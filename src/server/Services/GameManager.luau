-- Nuclear'd Game Manager
-- Top-level orchestrator: initializes all services, handles player lifecycle

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotService = require(script.Parent.PlotService)
local ResourceSystem = require(script.Parent.ResourceSystem)
local BuildingSystem = require(script.Parent.BuildingSystem)
local TechSystem = require(script.Parent.TechSystem)
local UnitSystem = require(script.Parent.UnitSystem)
local WaveSystem = require(script.Parent.WaveSystem)
local NuclearSystem = require(script.Parent.NuclearSystem)

local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

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

	-- Restart handler
	Remotes:WaitForChild("RestartGame").OnServerEvent:Connect(function(player)
		GameManager.RestartForPlayer(player)
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

	-- Character hiding is handled by Bootstrap.server.luau
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

function GameManager.RestartForPlayer(player: Player)
	print("[GameManager] Restarting game for:", player.Name)

	-- Cleanup everything (same as leaving)
	NuclearSystem.CleanupPlayer(player)
	WaveSystem.CleanupPlayer(player)
	UnitSystem.CleanupPlayer(player)
	BuildingSystem.CleanupPlayer(player)
	TechSystem.CleanupPlayer(player)
	ResourceSystem.CleanupPlayer(player)
	PlotService.RemovePlot(player)

	-- Notify client to reset UI
	Remotes.RestartGame:FireClient(player)

	-- Small delay to let cleanup finish
	task.wait(0.5)

	-- Re-initialize (same as joining)
	PlotService.AssignPlot(player)
	ResourceSystem.InitPlayer(player)
	TechSystem.InitPlayer(player)
	WaveSystem.StartForPlayer(player)

	print("[GameManager] Game restarted for:", player.Name)
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
