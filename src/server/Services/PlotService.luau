-- Nuclear'd Plot Service
-- Creates and assigns 64x64 flesh-colored baseplates to players

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Constants)
local Remotes = ReplicatedStorage.Network.Remotes

local PlotService = {}

-- State
local plots = {} -- [Player] = { baseplate: BasePart, origin: Vector3 }
local plotFolder = nil

function PlotService.Init()
	plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plots"
	plotFolder.Parent = workspace
end

function PlotService.AssignPlot(player: Player)
	if plots[player] then
		return plots[player]
	end

	-- Calculate plot position (space them out in a row for now)
	local plotIndex = 0
	for _ in plots do
		plotIndex += 1
	end
	local spacing = Constants.PLOT_SIZE + 20
	local originX = plotIndex * spacing
	local originZ = 0

	-- Create baseplate
	local baseplate = Instance.new("Part")
	baseplate.Name = player.Name .. "_Plot"
	baseplate.Size = Vector3.new(Constants.PLOT_SIZE, 1, Constants.PLOT_SIZE)
	baseplate.Position = Vector3.new(originX + Constants.PLOT_SIZE / 2, 0, originZ + Constants.PLOT_SIZE / 2)
	baseplate.Anchored = true
	baseplate.Color = Constants.PLOT_COLOR
	baseplate.Material = Constants.PLOT_MATERIAL
	baseplate.TopSurface = Enum.SurfaceType.Smooth
	baseplate.BottomSurface = Enum.SurfaceType.Smooth
	baseplate.Parent = plotFolder

	-- Add grid lines (thin parts on top of baseplate for visual reference)
	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "GridLines"
	gridFolder.Parent = baseplate

	for i = 1, Constants.GRID_SIZE - 1 do
		-- Vertical lines
		local vLine = Instance.new("Part")
		vLine.Name = "VLine_" .. i
		vLine.Size = Vector3.new(0.1, 0.05, Constants.PLOT_SIZE)
		vLine.Position = Vector3.new(
			originX + i * Constants.CELL_SIZE,
			0.525,
			originZ + Constants.PLOT_SIZE / 2
		)
		vLine.Anchored = true
		vLine.Color = Color3.fromRGB(200, 150, 140)
		vLine.Material = Enum.Material.SmoothPlastic
		vLine.Transparency = 0.7
		vLine.CanCollide = false
		vLine.Parent = gridFolder

		-- Horizontal lines
		local hLine = Instance.new("Part")
		hLine.Name = "HLine_" .. i
		hLine.Size = Vector3.new(Constants.PLOT_SIZE, 0.05, 0.1)
		hLine.Position = Vector3.new(
			originX + Constants.PLOT_SIZE / 2,
			0.525,
			originZ + i * Constants.CELL_SIZE
		)
		hLine.Anchored = true
		hLine.Color = Color3.fromRGB(200, 150, 140)
		hLine.Material = Enum.Material.SmoothPlastic
		hLine.Transparency = 0.7
		hLine.CanCollide = false
		hLine.Parent = gridFolder
	end

	-- Add SpawnLocation on the plot (so players don't fall to death)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = player.Name .. "_Spawn"
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.Position = Vector3.new(originX + Constants.PLOT_SIZE / 2, 0.5, originZ + Constants.PLOT_SIZE / 2)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Enabled = true
	spawn.Neutral = false
	spawn.TeamColor = BrickColor.new("Medium stone grey")
	spawn.Parent = plotFolder

	local plotData = {
		baseplate = baseplate,
		spawn = spawn,
		origin = Vector3.new(originX, 0, originZ),
	}
	plots[player] = plotData

	-- Notify client
	Remotes.PlotAssigned:FireClient(player, plotData.origin, Constants.PLOT_SIZE)

	print("[PlotService] Assigned plot to", player.Name, "at", plotData.origin)
	return plotData
end

function PlotService.GetPlot(player: Player)
	return plots[player]
end

function PlotService.GetPlotOrigin(player: Player): Vector3?
	local plot = plots[player]
	return plot and plot.origin or nil
end

function PlotService.RemovePlot(player: Player)
	local plot = plots[player]
	if plot then
		plot.baseplate:Destroy()
		if plot.spawn then
			plot.spawn:Destroy()
		end
		plots[player] = nil
		print("[PlotService] Removed plot for", player.Name)
	end
end

-- Check if a world position is within a player's plot
function PlotService.IsInPlot(player: Player, worldPos: Vector3): boolean
	local plot = plots[player]
	if not plot then
		return false
	end
	local origin = plot.origin
	return worldPos.X >= origin.X
		and worldPos.X <= origin.X + Constants.PLOT_SIZE
		and worldPos.Z >= origin.Z
		and worldPos.Z <= origin.Z + Constants.PLOT_SIZE
end

-- Convert world position to grid coordinates (1-based)
function PlotService.WorldToGrid(player: Player, worldPos: Vector3): (number, number)?
	local plot = plots[player]
	if not plot then
		return nil
	end
	local origin = plot.origin
	local localX = worldPos.X - origin.X
	local localZ = worldPos.Z - origin.Z
	local gridX = math.floor(localX / Constants.CELL_SIZE) + 1
	local gridZ = math.floor(localZ / Constants.CELL_SIZE) + 1

	if gridX >= 1 and gridX <= Constants.GRID_SIZE and gridZ >= 1 and gridZ <= Constants.GRID_SIZE then
		return gridX, gridZ
	end
	return nil
end

-- Convert grid coordinates to world position (center of cell)
function PlotService.GridToWorld(player: Player, gridX: number, gridZ: number): Vector3?
	local plot = plots[player]
	if not plot then
		return nil
	end
	local origin = plot.origin
	return Vector3.new(
		origin.X + (gridX - 0.5) * Constants.CELL_SIZE,
		0.5, -- top of baseplate
		origin.Z + (gridZ - 0.5) * Constants.CELL_SIZE
	)
end

return PlotService
