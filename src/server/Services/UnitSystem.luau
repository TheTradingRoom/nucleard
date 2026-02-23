-- Nuclear'd Unit System
-- Training queue, movement tick (10Hz), combat tick (2Hz), auto-attack

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Units = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Units"))
local Buildings = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Buildings"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local ResourceSystem = require(script.Parent.ResourceSystem)
local PlotService = require(script.Parent.PlotService)

local UnitSystem = {}

-- State
local nextUnitId = 1
local allUnits = {} -- [id] = ActiveUnit
local playerUnits = {} -- [Player] = { [id] = true }
local trainingQueues = {} -- [buildingId] = { { defId, finishTime } }

function UnitSystem.Init()
	-- Listen for train requests
	Remotes.TrainUnit.OnServerEvent:Connect(function(player, buildingId, unitDefId)
		UnitSystem.HandleTrainRequest(player, buildingId, unitDefId)
	end)

	-- Listen for move commands
	Remotes.MoveUnits.OnServerEvent:Connect(function(player, unitIds, targetPos)
		UnitSystem.HandleMoveCommand(player, unitIds, targetPos)
	end)

	print("[UnitSystem] Initialized")
end

function UnitSystem.HandleTrainRequest(player: Player, buildingId: string, unitDefId: string)
	if type(buildingId) ~= "string" or type(unitDefId) ~= "string" then
		return
	end

	local BuildingSystem = require(script.Parent.BuildingSystem)
	local building = BuildingSystem.GetBuilding(buildingId)
	if not building then
		return
	end
	if building.owner ~= player then
		return
	end

	if building.defId ~= "Barracks" and building.defId ~= "AdvancedBarracks" then
		return
	end

	local unitDef = Units[unitDefId]
	if not unitDef then
		return
	end

	local TechSystem = require(script.Parent.TechSystem)
	if TechSystem.GetAge(player) < unitDef.ageRequired then
		return
	end

	if unitDef.ageRequired >= 3 and building.defId ~= "AdvancedBarracks" then
		return
	end

	local queue = trainingQueues[buildingId]
	if not queue then
		queue = {}
		trainingQueues[buildingId] = queue
	end
	if #queue >= 5 then
		return
	end

	if not ResourceSystem.CanAfford(player, unitDef.cost) then
		return
	end

	ResourceSystem.Deduct(player, unitDef.cost)

	local lastFinish = tick()
	if #queue > 0 then
		lastFinish = queue[#queue].finishTime
	end
	table.insert(queue, {
		defId = unitDefId,
		finishTime = lastFinish + unitDef.trainTime,
		owner = player,
		buildingId = buildingId,
	})
end

function UnitSystem.HandleMoveCommand(player: Player, unitIds, targetPos)
	if type(unitIds) ~= "table" or typeof(targetPos) ~= "Vector3" then
		return
	end

	-- Validate target is in player's plot
	if not PlotService.IsInPlot(player, targetPos) then
		return
	end

	for _, unitId in unitIds do
		if type(unitId) ~= "string" then
			continue
		end
		local unit = allUnits[unitId]
		if unit and unit.owner == player then
			unit.target = targetPos
			unit.attackTarget = nil -- cancel auto-attack when given move order
		end
	end
end

function UnitSystem.SpawnUnit(player: Player, defId: string, position: Vector3)
	local def = Units[defId]
	if not def then
		return nil
	end

	local id = "u" .. tostring(nextUnitId)
	nextUnitId += 1

	local part = Instance.new("Part")
	part.Name = "Unit_" .. def.id .. "_" .. id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(def.size, def.size, def.size)
	part.Position = Vector3.new(position.X, def.size / 2 + 0.5, position.Z)
	part.Anchored = true
	part.CanCollide = false
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic

	-- Selection indicator (hidden by default)
	local selectionRing = Instance.new("Part")
	selectionRing.Name = "SelectionRing"
	selectionRing.Shape = Enum.PartType.Cylinder
	selectionRing.Size = Vector3.new(0.1, def.size + 1, def.size + 1)
	selectionRing.CFrame = CFrame.new(position.X, 0.55, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	selectionRing.Anchored = true
	selectionRing.CanCollide = false
	selectionRing.Color = Color3.fromRGB(0, 255, 0)
	selectionRing.Material = Enum.Material.Neon
	selectionRing.Transparency = 1
	selectionRing.Parent = part

	-- Health bar (hidden until damaged)
	local healthBarGui = Instance.new("BillboardGui")
	healthBarGui.Name = "HealthBar"
	healthBarGui.Size = UDim2.new(0, 40, 0, 4)
	healthBarGui.StudsOffset = Vector3.new(0, def.size / 2 + 0.3, 0)
	healthBarGui.AlwaysOnTop = false
	healthBarGui.Enabled = false
	healthBarGui.Parent = part

	local healthBg = Instance.new("Frame")
	healthBg.Size = UDim2.new(1, 0, 1, 0)
	healthBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	healthBg.BorderSizePixel = 0
	healthBg.Parent = healthBarGui

	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	local plotFolder = workspace:FindFirstChild("Plots")
	if plotFolder then
		part.Parent = plotFolder
	end

	local unit = {
		id = id,
		defId = defId,
		owner = player,
		health = def.health,
		maxHealth = def.health,
		damage = def.damage,
		attackSpeed = def.attackSpeed,
		moveSpeed = def.moveSpeed,
		range = def.range,
		part = part,
		target = nil,
		attackTarget = nil,
		lastAttackTime = 0,
	}
	allUnits[id] = unit

	if not playerUnits[player] then
		playerUnits[player] = {}
	end
	playerUnits[player][id] = true

	Remotes.UnitSpawned:FireAllClients(id, defId, player)
	return unit
end

-- Process training queues (called from combat tick)
function UnitSystem.ProcessTrainingQueues()
	local now = tick()
	local BuildingSystem = require(script.Parent.BuildingSystem)

	for buildingId, queue in trainingQueues do
		while #queue > 0 and queue[1].finishTime <= now do
			local entry = table.remove(queue, 1)
			local building = BuildingSystem.GetBuilding(buildingId)
			if building and building.part then
				-- Spawn outside the barracks (random side, offset by building size + unit size)
				local bSize = building.part.Size.X / 2 + 4
				local side = math.random(1, 4)
				local offX, offZ = 0, 0
				if side == 1 then offX = bSize + math.random() * 3
				elseif side == 2 then offX = -bSize - math.random() * 3
				elseif side == 3 then offZ = bSize + math.random() * 3
				else offZ = -bSize - math.random() * 3
				end
				local spawnPos = building.part.Position + Vector3.new(offX, 0, offZ)
				UnitSystem.SpawnUnit(entry.owner, entry.defId, spawnPos)
			end
		end
	end
end

-- Movement tick (10 Hz)
function UnitSystem.MovementTick()
	local dt = 0.1

	for id, unit in allUnits do
		if not unit.part or not unit.target then
			continue
		end

		local currentPos = unit.part.Position
		local targetPos = Vector3.new(unit.target.X, currentPos.Y, unit.target.Z)
		local diff = targetPos - currentPos
		local dist = diff.Magnitude

		if dist < 0.5 then
			unit.target = nil
			continue
		end

		local moveAmount = math.min(unit.moveSpeed * dt, dist)
		local newPos = currentPos + diff.Unit * moveAmount
		unit.part.Position = newPos

		-- Update selection ring position
		local ring = unit.part:FindFirstChild("SelectionRing")
		if ring then
			ring.CFrame = CFrame.new(newPos.X, 0.55, newPos.Z) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

-- Combat tick (2 Hz)
function UnitSystem.CombatTick()
	local now = tick()
	local WaveSystem = require(script.Parent.WaveSystem)

	-- Process training queues here too (piggyback on combat tick for simplicity)
	UnitSystem.ProcessTrainingQueues()

	for id, unit in allUnits do
		if not unit.part then
			continue
		end

		local attackInterval = 1 / unit.attackSpeed
		if now - unit.lastAttackTime < attackInterval then
			continue
		end

		-- Auto-attack: find nearest enemy in range
		local unitPos = unit.part.Position
		local nearestEnemy, nearestDist = WaveSystem.FindNearestEnemy(unit.owner, unitPos, unit.range)

		if nearestEnemy and nearestEnemy.part then
			unit.lastAttackTime = now
			unit.target = nil -- stop moving, fight!

			local unitPos = unit.part.Position
			local enemyPos = nearestEnemy.part.Position

			if unit.range <= 6 then
				-- Melee: splash ring at enemy position
				local splash = Instance.new("Part")
				splash.Name = "MeleeSplash"
				splash.Shape = Enum.PartType.Cylinder
				splash.Size = Vector3.new(0.3, unit.range * 2, unit.range * 2)
				splash.CFrame = CFrame.new(enemyPos.X, 0.6, enemyPos.Z) * CFrame.Angles(0, 0, math.rad(90))
				splash.Anchored = true
				splash.CanCollide = false
				splash.Color = unit.part.Color
				splash.Material = Enum.Material.Neon
				splash.Transparency = 0.4
				splash.Parent = workspace
				task.delay(0.2, function()
					splash:Destroy()
				end)
			else
				-- Ranged: beam from unit to enemy
				local midPoint = (unitPos + enemyPos) / 2
				local dist = (enemyPos - unitPos).Magnitude

				local beam = Instance.new("Part")
				beam.Name = "AttackBeam"
				beam.Size = Vector3.new(0.3, 0.3, dist)
				beam.CFrame = CFrame.lookAt(midPoint, enemyPos)
				beam.Anchored = true
				beam.CanCollide = false
				beam.Color = unit.part.Color
				beam.Material = Enum.Material.Neon
				beam.Transparency = 0.3
				beam.Parent = workspace
				task.delay(0.15, function()
					beam:Destroy()
				end)
			end

			-- Unit briefly flashes neon when attacking
			task.spawn(function()
				unit.part.Material = Enum.Material.Neon
				task.wait(0.1)
				if unit.part then
					unit.part.Material = Enum.Material.SmoothPlastic
				end
			end)

			WaveSystem.DamageEnemy(nearestEnemy.id, unit.damage, unit.owner)
		elseif not unit.target and unit.range <= 6 then
			-- Melee auto-chase: move toward nearest enemy within aggro range (3x attack range)
			local aggroRange = unit.range * 5
			local chaseEnemy, chaseDist = WaveSystem.FindNearestEnemy(unit.owner, unit.part.Position, aggroRange)
			if chaseEnemy and chaseEnemy.part then
				unit.target = chaseEnemy.part.Position
			end
		end
	end
end

function UnitSystem.DamageUnit(unitId: string, damage: number): boolean
	local unit = allUnits[unitId]
	if not unit then
		return false
	end

	unit.health -= damage

	-- Update health bar (show on first damage)
	if unit.part then
		local healthBar = unit.part:FindFirstChild("HealthBar")
		if healthBar then
			healthBar.Enabled = true
			local bg = healthBar:FindFirstChildWhichIsA("Frame")
			if bg then
				local fill = bg:FindFirstChild("Fill")
				if fill then
					local pct = math.max(0, unit.health / unit.maxHealth)
					fill.Size = UDim2.new(pct, 0, 1, 0)
					if pct > 0.5 then
						fill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
					elseif pct > 0.25 then
						fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
					else
						fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
					end
				end
			end
		end
	end

	if unit.health <= 0 then
		UnitSystem.DestroyUnit(unitId)
		return true
	end
	return false
end

function UnitSystem.DestroyUnit(unitId: string)
	local unit = allUnits[unitId]
	if not unit then
		return
	end

	if unit.part then
		unit.part:Destroy()
	end

	if playerUnits[unit.owner] then
		playerUnits[unit.owner][unitId] = nil
	end

	allUnits[unitId] = nil
	Remotes.UnitDied:FireAllClients(unitId)
end

-- Find nearest player unit to a position (used by enemies)
function UnitSystem.FindNearestUnit(player: Player, position: Vector3, maxRange: number?)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	local ids = playerUnits[player]
	if not ids then
		return nil, math.huge
	end

	for id in ids do
		local unit = allUnits[id]
		if unit and unit.part then
			local dist = (unit.part.Position - position).Magnitude
			if dist < nearestDist then
				nearest = unit
				nearestDist = dist
			end
		end
	end

	return nearest, nearestDist
end

function UnitSystem.GetPlayerUnits(player: Player)
	local result = {}
	local ids = playerUnits[player]
	if ids then
		for id in ids do
			result[id] = allUnits[id]
		end
	end
	return result
end

function UnitSystem.GetUnit(id: string)
	return allUnits[id]
end

function UnitSystem.CleanupPlayer(player: Player)
	local ids = playerUnits[player]
	if ids then
		for id in ids do
			local unit = allUnits[id]
			if unit and unit.part then
				unit.part:Destroy()
			end
			allUnits[id] = nil
		end
	end
	playerUnits[player] = nil

	-- Clean training queues for this player's buildings
	for buildingId, queue in trainingQueues do
		if #queue > 0 and queue[1].owner == player then
			trainingQueues[buildingId] = nil
		end
	end
end

return UnitSystem
