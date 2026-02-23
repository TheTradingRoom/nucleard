-- Nuclear'd Building System
-- Grid placement validation, building state, health, Part creation, turret combat

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Buildings = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Buildings"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local PlotService = require(script.Parent.PlotService)
local ResourceSystem = require(script.Parent.ResourceSystem)

local BuildingSystem = {}

-- State
local nextBuildingId = 1
local allBuildings = {} -- [id] = PlacedBuilding
local playerBuildings = {} -- [Player] = { [id] = true }
local grid = {} -- [Player] = { [gridKey] = buildingId }

local function gridKey(x, z)
	return x .. "," .. z
end

function BuildingSystem.Init()
	-- Listen for build requests
	Remotes.BuildRequest.OnServerEvent:Connect(function(player, buildingDefId, gridX, gridZ)
		BuildingSystem.HandleBuildRequest(player, buildingDefId, gridX, gridZ)
	end)

	-- Listen for sell requests
	Remotes.SellBuilding.OnServerEvent:Connect(function(player, buildingId)
		BuildingSystem.HandleSellRequest(player, buildingId)
	end)

	print("[BuildingSystem] Initialized")
end

function BuildingSystem.HandleBuildRequest(player: Player, buildingDefId: string, gridX: number, gridZ: number)
	-- Validate inputs
	if type(buildingDefId) ~= "string" or type(gridX) ~= "number" or type(gridZ) ~= "number" then
		return
	end

	-- Get building definition
	local def = Buildings[buildingDefId]
	if not def then
		return
	end

	-- Check age requirement
	local TechSystem = require(script.Parent.TechSystem)
	local playerAge = TechSystem.GetAge(player)
	if playerAge < def.ageRequired then
		return
	end

	-- Check grid bounds
	gridX = math.floor(gridX)
	gridZ = math.floor(gridZ)
	if gridX < 1 or gridZ < 1 or gridX + def.size - 1 > Constants.GRID_SIZE or gridZ + def.size - 1 > Constants.GRID_SIZE then
		return
	end

	-- Check grid is free
	local playerGrid = grid[player]
	if not playerGrid then
		playerGrid = {}
		grid[player] = playerGrid
	end

	for dx = 0, def.size - 1 do
		for dz = 0, def.size - 1 do
			if playerGrid[gridKey(gridX + dx, gridZ + dz)] then
				return -- cell occupied
			end
		end
	end

	-- Check resources
	if not ResourceSystem.CanAfford(player, def.cost) then
		return
	end

	-- All checks passed — deduct resources and place building
	ResourceSystem.Deduct(player, def.cost)

	local id = tostring(nextBuildingId)
	nextBuildingId += 1

	-- Mark grid cells
	for dx = 0, def.size - 1 do
		for dz = 0, def.size - 1 do
			playerGrid[gridKey(gridX + dx, gridZ + dz)] = id
		end
	end

	-- Calculate world position (center of building footprint)
	local centerGridX = gridX + (def.size - 1) / 2
	local centerGridZ = gridZ + (def.size - 1) / 2
	local worldPos = PlotService.GridToWorld(player, centerGridX, centerGridZ)
	if not worldPos then
		return
	end

	-- Create the Part
	local part = Instance.new("Part")
	part.Name = "Building_" .. def.id .. "_" .. id
	part.Size = Vector3.new(def.size * Constants.CELL_SIZE - 0.5, def.size * Constants.CELL_SIZE * 0.75, def.size * Constants.CELL_SIZE - 0.5)
	part.Position = Vector3.new(worldPos.X, part.Size.Y / 2 + 0.5, worldPos.Z)
	part.Anchored = true
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- Health bar (hidden until damaged — reduces visual clutter)
	local healthBarGui = Instance.new("BillboardGui")
	healthBarGui.Name = "HealthBar"
	healthBarGui.Size = UDim2.new(0, 60, 0, 6)
	healthBarGui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 0.5, 0)
	healthBarGui.AlwaysOnTop = false
	healthBarGui.Enabled = false -- hidden until damaged
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

	-- Store building in folder
	local plotFolder = workspace:FindFirstChild("Plots")
	if plotFolder then
		part.Parent = plotFolder
	end

	-- Store building data
	local building = {
		id = id,
		defId = buildingDefId,
		owner = player,
		gridX = gridX,
		gridZ = gridZ,
		health = def.health,
		maxHealth = def.health,
		part = part,
		lastAttackTime = 0,
	}
	allBuildings[id] = building

	if not playerBuildings[player] then
		playerBuildings[player] = {}
	end
	playerBuildings[player][id] = true

	-- Register income
	if def.income then
		ResourceSystem.AddIncome(player, def.income)
	end

	-- Special: Nuclear Silo triggers enrichment
	if buildingDefId == "NuclearSilo" then
		local NuclearSystem = require(script.Parent.NuclearSystem)
		NuclearSystem.StartEnrichment(player)
	end

	print("[BuildingSystem] Built", def.name, "for", player.Name, "at grid", gridX, gridZ)
end

function BuildingSystem.HandleSellRequest(player: Player, buildingId: string)
	if type(buildingId) ~= "string" then
		return
	end

	local building = allBuildings[buildingId]
	if not building or building.owner ~= player then
		return
	end

	-- Nuclear Silo cannot be sold if enriching
	if building.defId == "NuclearSilo" then
		local NuclearSystem = require(script.Parent.NuclearSystem)
		if NuclearSystem.IsEnriching(player) then
			return
		end
	end

	BuildingSystem.DestroyBuilding(buildingId)

	-- Refund 50% of cost
	local def = Buildings[building.defId]
	if def then
		local refund = {
			Sebum = math.floor((def.cost.Sebum or 0) * 0.5),
			Grease = math.floor((def.cost.Grease or 0) * 0.5),
			Bacteria = math.floor((def.cost.Bacteria or 0) * 0.5),
			Sweat = math.floor((def.cost.Sweat or 0) * 0.5),
		}
		ResourceSystem.AddResources(player, refund)
	end
end

function BuildingSystem.DestroyBuilding(buildingId: string)
	local building = allBuildings[buildingId]
	if not building then
		return
	end

	local def = Buildings[building.defId]
	local player = building.owner

	-- Remove income
	if def and def.income then
		ResourceSystem.RemoveIncome(player, def.income)
	end

	-- Clear grid
	local playerGrid = grid[player]
	if playerGrid and def then
		for dx = 0, def.size - 1 do
			for dz = 0, def.size - 1 do
				playerGrid[gridKey(building.gridX + dx, building.gridZ + dz)] = nil
			end
		end
	end

	-- Destroy part
	if building.part then
		building.part:Destroy()
	end

	-- Remove from tracking
	allBuildings[buildingId] = nil
	if playerBuildings[player] then
		playerBuildings[player][buildingId] = nil
	end

	-- Notify clients
	Remotes.BuildingDestroyed:FireAllClients(buildingId)

	-- Check for game over (no buildings left)
	local NuclearSystem = require(script.Parent.NuclearSystem)
	NuclearSystem.CheckGameOver(player)

	print("[BuildingSystem] Destroyed building", buildingId)
end

function BuildingSystem.DamageBuilding(buildingId: string, damage: number): boolean
	local building = allBuildings[buildingId]
	if not building then
		return false
	end

	building.health -= damage
	-- Update health bar (show it now that building is damaged)
	if building.part then
		local healthBar = building.part:FindFirstChild("HealthBar")
		if healthBar then
			healthBar.Enabled = true -- show on first damage
			local bg = healthBar:FindFirstChildWhichIsA("Frame")
			if bg then
				local fill = bg:FindFirstChild("Fill")
				if fill then
					local pct = math.max(0, building.health / building.maxHealth)
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

	if building.health <= 0 then
		BuildingSystem.DestroyBuilding(buildingId)
		return true -- building destroyed
	end
	return false
end

-- Turret tick — called by combat tick (2 Hz)
function BuildingSystem.TurretTick()
	local WaveSystem = require(script.Parent.WaveSystem)
	local now = tick()

	for id, building in allBuildings do
		local def = Buildings[building.defId]
		if not def or not def.isTurret then
			continue
		end

		-- Check attack cooldown
		local attackInterval = 1 / (def.attackSpeed or 1)
		if now - building.lastAttackTime < attackInterval then
			continue
		end

		-- Find nearest enemy in range
		local buildingPos = building.part and building.part.Position
		if not buildingPos then
			continue
		end

		local nearestEnemy, nearestDist = WaveSystem.FindNearestEnemy(building.owner, buildingPos, def.range)
		if nearestEnemy and nearestEnemy.part then
			building.lastAttackTime = now

			-- Visual: turret beam to enemy
			local enemyPos = nearestEnemy.part.Position
			local midPoint = (buildingPos + enemyPos) / 2
			local dist = (enemyPos - buildingPos).Magnitude

			local beam = Instance.new("Part")
			beam.Name = "TurretBeam"
			beam.Size = Vector3.new(0.4, 0.4, dist)
			beam.CFrame = CFrame.lookAt(midPoint, enemyPos)
			beam.Anchored = true
			beam.CanCollide = false
			beam.Color = Color3.fromRGB(255, 100, 100)
			beam.Material = Enum.Material.Neon
			beam.Transparency = 0.2
			beam.Parent = workspace
			task.delay(0.15, function()
				beam:Destroy()
			end)

			WaveSystem.DamageEnemy(nearestEnemy.id, def.damage, building.owner)
		end
	end
end

function BuildingSystem.Tick()
	-- Economy tick handled by ResourceSystem via income
end

function BuildingSystem.GetPlayerBuildings(player: Player)
	local result = {}
	local ids = playerBuildings[player]
	if ids then
		for id in ids do
			result[id] = allBuildings[id]
		end
	end
	return result
end

function BuildingSystem.GetBuilding(id: string)
	return allBuildings[id]
end

function BuildingSystem.GetAllBuildings()
	return allBuildings
end

-- Find the nearest building owned by a player (used by enemies)
function BuildingSystem.FindNearestBuilding(player: Player, position: Vector3, maxRange: number?)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	local ids = playerBuildings[player]
	if not ids then
		return nil, math.huge
	end

	for id in ids do
		local building = allBuildings[id]
		if building and building.part then
			local dist = (building.part.Position - position).Magnitude
			if dist < nearestDist then
				nearest = building
				nearestDist = dist
			end
		end
	end

	return nearest, nearestDist
end

-- Check if a player has a building of a specific type
function BuildingSystem.HasBuildingType(player: Player, defId: string): boolean
	local ids = playerBuildings[player]
	if not ids then
		return false
	end
	for id in ids do
		local building = allBuildings[id]
		if building and building.defId == defId then
			return true
		end
	end
	return false
end

-- Count buildings of a specific type for a player
function BuildingSystem.CountBuildingType(player: Player, defId: string): number
	local count = 0
	local ids = playerBuildings[player]
	if not ids then
		return 0
	end
	for id in ids do
		local building = allBuildings[id]
		if building and building.defId == defId then
			count += 1
		end
	end
	return count
end

function BuildingSystem.CleanupPlayer(player: Player)
	local ids = playerBuildings[player]
	if ids then
		for id in ids do
			local building = allBuildings[id]
			if building and building.part then
				building.part:Destroy()
			end
			allBuildings[id] = nil
		end
	end
	playerBuildings[player] = nil
	grid[player] = nil
end

return BuildingSystem
