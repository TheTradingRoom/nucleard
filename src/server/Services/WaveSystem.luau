-- Nuclear'd Wave System
-- Wave timer, enemy spawning, enemy AI, combat

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local WaveConfig = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Waves"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local PlotService = require(script.Parent.PlotService)
local ResourceSystem = require(script.Parent.ResourceSystem)

local WaveSystem = {}

-- State
local nextEnemyId = 1
local allEnemies = {} -- [id] = EnemyUnit
local playerEnemies = {} -- [Player] = { [id] = true } -- enemies attacking that player
local playerWaveState = {} -- [Player] = { currentWave, nextWaveTime, active, spawning }

function WaveSystem.Init()
	print("[WaveSystem] Initialized")
end

function WaveSystem.StartForPlayer(player: Player)
	playerWaveState[player] = {
		currentWave = 0,
		nextWaveTime = tick() + Constants.FIRST_WAVE_DELAY,
		active = true,
		spawning = false,
	}
	playerEnemies[player] = {}

	-- Wave timer coroutine
	task.spawn(function()
		while playerWaveState[player] and playerWaveState[player].active do
			local state = playerWaveState[player]
			if not state then
				break
			end

			local timeUntilWave = state.nextWaveTime - tick()

			-- Send warning
			if timeUntilWave <= Constants.WAVE_WARNING_TIME and timeUntilWave > Constants.WAVE_WARNING_TIME - 1 then
				local nextWaveNum = state.currentWave + 1
				if nextWaveNum <= #WaveConfig.Waves then
					Remotes.WaveWarning:FireClient(player, nextWaveNum, math.ceil(timeUntilWave))
				end
			end

			-- Spawn wave
			if timeUntilWave <= 0 and not state.spawning then
				state.currentWave += 1
				if state.currentWave <= #WaveConfig.Waves then
					WaveSystem.SpawnWave(player, WaveConfig.Waves[state.currentWave])
					state.nextWaveTime = tick() + Constants.WAVE_INTERVAL
				end
			end

			task.wait(1)
		end
	end)
end

function WaveSystem.SpawnWave(player: Player, waveDef)
	local state = playerWaveState[player]
	if not state then
		return
	end
	state.spawning = true

	print("[WaveSystem] Spawning wave", waveDef.waveNumber, "for", player.Name)

	local plotOrigin = PlotService.GetPlotOrigin(player)
	if not plotOrigin then
		state.spawning = false
		return
	end

	task.spawn(function()
		for _, group in waveDef.enemies do
			for i = 1, group.count do
				if not playerWaveState[player] then
					return
				end
				WaveSystem.SpawnEnemy(player, group.enemy, plotOrigin)
				task.wait(waveDef.spawnDelay)
			end
		end

		if state then
			state.spawning = false
		end
	end)
end

function WaveSystem.SpawnBossWave(player: Player)
	print("[WaveSystem] BOSS WAVE for", player.Name)
	WaveSystem.SpawnWave(player, WaveConfig.BossWave)
end

function WaveSystem.SpawnEnemy(player: Player, enemyDef, plotOrigin: Vector3)
	local id = "e" .. tostring(nextEnemyId)
	nextEnemyId += 1

	-- Spawn at random edge of plot
	local side = math.random(1, 4)
	local spawnPos
	local plotSize = Constants.PLOT_SIZE
	local offset = math.random() * plotSize

	if side == 1 then -- top
		spawnPos = Vector3.new(plotOrigin.X + offset, 0.5, plotOrigin.Z - 5)
	elseif side == 2 then -- bottom
		spawnPos = Vector3.new(plotOrigin.X + offset, 0.5, plotOrigin.Z + plotSize + 5)
	elseif side == 3 then -- left
		spawnPos = Vector3.new(plotOrigin.X - 5, 0.5, plotOrigin.Z + offset)
	else -- right
		spawnPos = Vector3.new(plotOrigin.X + plotSize + 5, 0.5, plotOrigin.Z + offset)
	end

	local part = Instance.new("Part")
	part.Name = "Enemy_" .. enemyDef.name .. "_" .. id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(enemyDef.size, enemyDef.size, enemyDef.size)
	part.Position = Vector3.new(spawnPos.X, enemyDef.size / 2 + 0.5, spawnPos.Z)
	part.Anchored = true
	part.CanCollide = false
	part.Color = enemyDef.color
	part.Material = Enum.Material.Neon

	-- Label
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 80, 0, 20)
	billboardGui.StudsOffset = Vector3.new(0, enemyDef.size / 2 + 1, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 100, 100)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = enemyDef.name
	label.Parent = billboardGui

	-- Health bar
	local healthBarGui = Instance.new("BillboardGui")
	healthBarGui.Name = "HealthBar"
	healthBarGui.Size = UDim2.new(0, 60, 0, 6)
	healthBarGui.StudsOffset = Vector3.new(0, enemyDef.size / 2 + 1.8, 0)
	healthBarGui.AlwaysOnTop = true
	healthBarGui.Parent = part

	local healthBg = Instance.new("Frame")
	healthBg.Size = UDim2.new(1, 0, 1, 0)
	healthBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	healthBg.BorderSizePixel = 0
	healthBg.Parent = healthBarGui

	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	local plotFolder = workspace:FindFirstChild("Plots")
	if plotFolder then
		part.Parent = plotFolder
	end

	local enemy = {
		id = id,
		name = enemyDef.name,
		health = enemyDef.health,
		maxHealth = enemyDef.health,
		damage = enemyDef.damage,
		attackSpeed = enemyDef.attackSpeed,
		moveSpeed = enemyDef.moveSpeed,
		range = enemyDef.range,
		part = part,
		targetBuildingId = nil,
		lastAttackTime = 0,
		reward = enemyDef.reward,
		targetPlayer = player,
	}
	allEnemies[id] = enemy
	playerEnemies[player] = playerEnemies[player] or {}
	playerEnemies[player][id] = true

	Remotes.EnemySpawned:FireAllClients(id, enemyDef.name)
end

-- Movement tick (10 Hz) — enemies move toward nearest building
function WaveSystem.MovementTick()
	local dt = 0.1
	local BuildingSystem = require(script.Parent.BuildingSystem)

	for id, enemy in allEnemies do
		if not enemy.part then
			continue
		end

		local currentPos = enemy.part.Position
		local player = enemy.targetPlayer

		-- Find nearest building to move toward
		local targetBuilding, dist = BuildingSystem.FindNearestBuilding(player, currentPos)
		if not targetBuilding or not targetBuilding.part then
			-- No buildings left — move toward plot center
			local origin = PlotService.GetPlotOrigin(player)
			if origin then
				local center = Vector3.new(origin.X + Constants.PLOT_SIZE / 2, currentPos.Y, origin.Z + Constants.PLOT_SIZE / 2)
				local diff = center - currentPos
				if diff.Magnitude > 1 then
					enemy.part.Position = currentPos + diff.Unit * enemy.moveSpeed * dt
				end
			end
			continue
		end

		enemy.targetBuildingId = targetBuilding.id

		-- Move toward building if out of range
		if dist > enemy.range then
			local targetPos = targetBuilding.part.Position
			local diff = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z) - currentPos
			local moveAmount = math.min(enemy.moveSpeed * dt, diff.Magnitude)
			enemy.part.Position = currentPos + diff.Unit * moveAmount
		end
	end
end

-- Combat tick (2 Hz) — enemies attack buildings/units
function WaveSystem.CombatTick()
	local now = tick()
	local BuildingSystem = require(script.Parent.BuildingSystem)
	local UnitSystem = require(script.Parent.UnitSystem)

	local deadEnemies = {}

	for id, enemy in allEnemies do
		if not enemy.part then
			continue
		end

		local attackInterval = 1 / enemy.attackSpeed
		if now - enemy.lastAttackTime < attackInterval then
			continue
		end

		local enemyPos = enemy.part.Position
		local player = enemy.targetPlayer

		-- Check for player units in range first (prioritize units)
		local nearestUnit, unitDist = UnitSystem.FindNearestUnit(player, enemyPos, enemy.range)
		if nearestUnit then
			enemy.lastAttackTime = now
			UnitSystem.DamageUnit(nearestUnit.id, enemy.damage)
			continue
		end

		-- Attack nearest building in range
		if enemy.targetBuildingId then
			local building = BuildingSystem.GetBuilding(enemy.targetBuildingId)
			if building and building.part then
				local dist = (building.part.Position - enemyPos).Magnitude
				if dist <= enemy.range then
					enemy.lastAttackTime = now
					local destroyed = BuildingSystem.DamageBuilding(enemy.targetBuildingId, enemy.damage)
					if destroyed then
						enemy.targetBuildingId = nil
					end
				end
			end
		end
	end
end

function WaveSystem.DamageEnemy(enemyId: string, damage: number, attackingPlayer: Player)
	local enemy = allEnemies[enemyId]
	if not enemy then
		return
	end

	enemy.health -= damage

	-- Update health bar
	if enemy.part then
		local healthBar = enemy.part:FindFirstChild("HealthBar")
		if healthBar then
			local bg = healthBar:FindFirstChildWhichIsA("Frame")
			if bg then
				local fill = bg:FindFirstChild("Fill")
				if fill then
					local pct = math.max(0, enemy.health / enemy.maxHealth)
					fill.Size = UDim2.new(pct, 0, 1, 0)
				end
			end
		end

		-- Damage flash
		task.spawn(function()
			if enemy.part then
				local origColor = enemy.part.Color
				enemy.part.Color = Color3.new(1, 1, 1)
				task.wait(0.1)
				if enemy.part then
					enemy.part.Color = origColor
				end
			end
		end)
	end

	if enemy.health <= 0 then
		-- Grant reward
		ResourceSystem.AddResources(attackingPlayer, enemy.reward)

		-- Check for boss kill
		if enemy.name == "The Dermatologist" then
			local NuclearSystem = require(script.Parent.NuclearSystem)
			NuclearSystem.OnBossKilled(attackingPlayer)
		end

		WaveSystem.DestroyEnemy(enemyId)
	end
end

function WaveSystem.DestroyEnemy(enemyId: string)
	local enemy = allEnemies[enemyId]
	if not enemy then
		return
	end

	local player = enemy.targetPlayer

	if enemy.part then
		enemy.part:Destroy()
	end

	if playerEnemies[player] then
		playerEnemies[player][enemyId] = nil
	end

	allEnemies[enemyId] = nil
	Remotes.EnemyDied:FireAllClients(enemyId)

	-- Check if wave is cleared
	WaveSystem.CheckWaveCleared(player)
end

function WaveSystem.CheckWaveCleared(player: Player)
	local enemies = playerEnemies[player]
	if not enemies then
		return
	end

	local state = playerWaveState[player]
	if not state or state.spawning then
		return
	end

	-- Count remaining enemies
	local count = 0
	for _ in enemies do
		count += 1
	end

	if count == 0 then
		Remotes.WaveCleared:FireClient(player, state.currentWave)
		print("[WaveSystem] Wave", state.currentWave, "cleared for", player.Name)
	end
end

function WaveSystem.FindNearestEnemy(player: Player, position: Vector3, maxRange: number?)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	local enemies = playerEnemies[player]
	if not enemies then
		return nil, math.huge
	end

	for id in enemies do
		local enemy = allEnemies[id]
		if enemy and enemy.part then
			local dist = (enemy.part.Position - position).Magnitude
			if dist < nearestDist then
				nearest = enemy
				nearestDist = dist
			end
		end
	end

	return nearest, nearestDist
end

function WaveSystem.GetEnemyCount(player: Player): number
	local count = 0
	local enemies = playerEnemies[player]
	if enemies then
		for _ in enemies do
			count += 1
		end
	end
	return count
end

function WaveSystem.GetCurrentWave(player: Player): number
	local state = playerWaveState[player]
	return state and state.currentWave or 0
end

function WaveSystem.GetNextWaveTime(player: Player): number
	local state = playerWaveState[player]
	return state and math.max(0, state.nextWaveTime - tick()) or 0
end

function WaveSystem.KillAllEnemies(player: Player)
	local enemies = playerEnemies[player]
	if not enemies then
		return
	end
	local ids = {}
	for id in enemies do
		table.insert(ids, id)
	end
	for _, id in ids do
		WaveSystem.DestroyEnemy(id)
	end
end

function WaveSystem.StopWaves(player: Player)
	local state = playerWaveState[player]
	if state then
		state.active = false
	end
end

function WaveSystem.CleanupPlayer(player: Player)
	WaveSystem.StopWaves(player)
	WaveSystem.KillAllEnemies(player)
	playerWaveState[player] = nil
	playerEnemies[player] = nil
end

return WaveSystem
