-- Nuclear'd Nuclear System
-- Enrichment progress, launch countdown, nuke detonation, boss wave trigger

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Constants)
local Remotes = ReplicatedStorage.Network.Remotes

local BuildingSystem = require(script.Parent.BuildingSystem)

local NuclearSystem = {}

-- State
local playerNuclearState = {} -- [Player] = { enriching, enrichProgress, launching, launchCountdown, launched, won }

function NuclearSystem.Init()
	Remotes.LaunchNuclear.OnServerEvent:Connect(function(player)
		NuclearSystem.HandleLaunch(player)
	end)

	print("[NuclearSystem] Initialized")
end

function NuclearSystem.CleanupPlayer(player: Player)
	playerNuclearState[player] = nil
end

function NuclearSystem.GetState(player: Player)
	return playerNuclearState[player]
end

function NuclearSystem.IsEnriching(player: Player): boolean
	local state = playerNuclearState[player]
	return state ~= nil and state.enriching == true
end

-- Called when a Nuclear Silo is built — start enrichment
function NuclearSystem.StartEnrichment(player: Player)
	if playerNuclearState[player] then
		return -- already started
	end

	playerNuclearState[player] = {
		enriching = true,
		enrichProgress = 0,
		launching = false,
		launchCountdown = 0,
		launched = false,
		won = false,
	}

	Remotes.NuclearStatus:FireClient(player, "enriching", 0)
	print("[NuclearSystem] Enrichment started for", player.Name)
end

-- Tick (1 Hz)
function NuclearSystem.Tick()
	for player, state in playerNuclearState do
		if not player.Parent then
			continue
		end

		-- Enrichment progress
		if state.enriching and not state.launching and not state.launched then
			-- Check silo still exists
			if not BuildingSystem.HasBuildingType(player, "NuclearSilo") then
				state.enriching = false
				Remotes.NuclearStatus:FireClient(player, "silo_destroyed", 0)
				playerNuclearState[player] = nil
				continue
			end

			state.enrichProgress += 1
			local pct = math.min(state.enrichProgress / Constants.NUCLEAR_ENRICH_TIME, 1)
			Remotes.NuclearStatus:FireClient(player, "enriching", pct)

			if state.enrichProgress >= Constants.NUCLEAR_ENRICH_TIME then
				state.enriching = false
				Remotes.NuclearStatus:FireClient(player, "ready", 1)
				print("[NuclearSystem] Enrichment complete for", player.Name, "— NUCLEAR READY!")
			end
		end

		-- Launch countdown
		if state.launching then
			state.launchCountdown -= 1
			Remotes.NuclearStatus:FireClient(player, "launching", state.launchCountdown)

			if state.launchCountdown <= 0 then
				NuclearSystem.Detonate(player)
			end
		end
	end
end

function NuclearSystem.HandleLaunch(player: Player)
	local state = playerNuclearState[player]
	if not state then
		return
	end

	-- Must be enriched and not already launching
	if state.enriching or state.launching or state.launched then
		return
	end

	-- Must have silo
	if not BuildingSystem.HasBuildingType(player, "NuclearSilo") then
		return
	end

	state.launching = true
	state.launchCountdown = Constants.NUCLEAR_LAUNCH_COUNTDOWN

	Remotes.NuclearStatus:FireClient(player, "launching", state.launchCountdown)
	print("[NuclearSystem] NUCLEAR LAUNCH INITIATED by", player.Name, "— T-minus", state.launchCountdown)
end

function NuclearSystem.Detonate(player: Player)
	local state = playerNuclearState[player]
	if not state then
		return
	end

	state.launched = true
	state.launching = false

	print("[NuclearSystem] NUCLEAR DETONATED by", player.Name, "!!!")

	-- Kill all current enemies
	local WaveSystem = require(script.Parent.WaveSystem)
	WaveSystem.KillAllEnemies(player)
	WaveSystem.StopWaves(player)

	-- Notify client
	Remotes.NuclearStatus:FireClient(player, "detonated", 0)

	-- Spawn boss wave after a brief pause
	task.delay(5, function()
		if player.Parent then
			Remotes.NuclearStatus:FireClient(player, "boss_incoming", 0)
			task.wait(3)
			if player.Parent then
				WaveSystem.SpawnBossWave(player)
			end
		end
	end)
end

function NuclearSystem.OnBossKilled(player: Player)
	local state = playerNuclearState[player]
	if not state then
		return
	end

	state.won = true

	-- Stop all waves
	local WaveSystem = require(script.Parent.WaveSystem)
	WaveSystem.StopWaves(player)
	WaveSystem.KillAllEnemies(player)

	-- Victory!
	Remotes.GameOver:FireClient(player, true) -- true = win
	print("[NuclearSystem] VICTORY!", player.Name, "defeated The Dermatologist!")
end

-- Check for game over (all buildings destroyed)
function NuclearSystem.CheckGameOver(player: Player)
	local buildings = BuildingSystem.GetPlayerBuildings(player)
	local count = 0
	for _ in buildings do
		count += 1
	end

	if count == 0 then
		local WaveSystem = require(script.Parent.WaveSystem)
		WaveSystem.StopWaves(player)
		WaveSystem.KillAllEnemies(player)
		Remotes.GameOver:FireClient(player, false) -- false = lose
		print("[NuclearSystem] DEFEAT!", player.Name, "lost all buildings!")
	end
end

return NuclearSystem
