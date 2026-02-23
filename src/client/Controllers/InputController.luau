-- Nuclear'd Input Controller
-- Mouse raycasting, grid snapping, placement ghost, unit selection/movement

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Buildings = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Buildings"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local CameraController = require(script.Parent.CameraController)

local InputController = {}

-- State
local player = Players.LocalPlayer
local plotOrigin = nil
local plotSize = nil
local buildMode = false
local buildModeFrameCount = 0
local selectedBuildingDef = nil
local ghostPart = nil
local selectedUnits = {} -- { [unitId] = Part }
local lastGridX, lastGridZ = 0, 0

-- Read plot data from player attributes (set by server, no race condition)
local function readPlotFromAttributes()
	local ox = player:GetAttribute("PlotOriginX")
	local oz = player:GetAttribute("PlotOriginZ")
	local sz = player:GetAttribute("PlotSize")
	if ox and oz and sz then
		plotOrigin = Vector3.new(ox, 0, oz)
		plotSize = sz
		return true
	end
	return false
end

function InputController.Init()
	-- Try reading plot data from attributes first (already set if server assigned before client loaded)
	if not readPlotFromAttributes() then
		-- Not set yet — listen for attribute changes
		player:GetAttributeChangedSignal("PlotOriginX"):Connect(function()
			readPlotFromAttributes()
		end)
	end

	-- Also listen for the event (belt and suspenders)
	Remotes:WaitForChild("PlotAssigned").OnClientEvent:Connect(function(origin, size)
		plotOrigin = origin
		plotSize = size
	end)

	-- Mouse click
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if gameProcessed then
				return
			end
			InputController.OnLeftClick()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if gameProcessed then return end
			InputController.OnRightClick()
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			if gameProcessed then return end
			if input.KeyCode == Enum.KeyCode.Escape then
				InputController.CancelBuildMode()
				InputController.ClearSelection()
			end
		end
	end)

	-- Update ghost position every frame
	RunService.RenderStepped:Connect(function()
		if buildMode then
			buildModeFrameCount = buildModeFrameCount + 1
		end

		if buildMode and ghostPart and plotOrigin then
			InputController.UpdateGhost()
		end
	end)

	print("[InputController] Initialized")
end

function InputController.GetMouseWorldPosition()
	return CameraController.GetMouseWorldPosition()
end

function InputController.WorldToGrid(worldPos: Vector3)
	if not plotOrigin then
		return nil, nil
	end
	local localX = worldPos.X - plotOrigin.X
	local localZ = worldPos.Z - plotOrigin.Z
	local gridX = math.floor(localX / Constants.CELL_SIZE) + 1
	local gridZ = math.floor(localZ / Constants.CELL_SIZE) + 1

	if gridX >= 1 and gridX <= Constants.GRID_SIZE and gridZ >= 1 and gridZ <= Constants.GRID_SIZE then
		return gridX, gridZ
	end
	return nil, nil
end

function InputController.GridToWorld(gridX: number, gridZ: number): Vector3
	return Vector3.new(
		plotOrigin.X + (gridX - 0.5) * Constants.CELL_SIZE,
		0.5,
		plotOrigin.Z + (gridZ - 0.5) * Constants.CELL_SIZE
	)
end

-- Build mode
function InputController.EnterBuildMode(defId: string)
	local def = Buildings[defId]
	if not def then
		return
	end

	InputController.CancelBuildMode()
	InputController.ClearSelection()

	buildMode = true
	buildModeFrameCount = 0
	selectedBuildingDef = def

	-- Create ghost
	ghostPart = Instance.new("Part")
	ghostPart.Name = "BuildGhost"
	ghostPart.Size = Vector3.new(
		def.size * Constants.CELL_SIZE - 0.5,
		def.size * Constants.CELL_SIZE * 0.75,
		def.size * Constants.CELL_SIZE - 0.5
	)
	ghostPart.Anchored = true
	ghostPart.CanCollide = false
	ghostPart.Color = def.color
	ghostPart.Material = Enum.Material.SmoothPlastic
	-- Start fully invisible — only show once mouse is over the grid
	ghostPart.Transparency = 1

	-- Park it underground so it's not visible at (0,0,0)
	ghostPart.Position = Vector3.new(0, -100, 0)
	ghostPart.Parent = workspace
end

function InputController.CancelBuildMode()
	buildMode = false
	selectedBuildingDef = nil
	if ghostPart then
		ghostPart:Destroy()
		ghostPart = nil
	end
end

function InputController.UpdateGhost()
	local worldPos = InputController.GetMouseWorldPosition()
	if not worldPos then
		return
	end

	local gridX, gridZ = InputController.WorldToGrid(worldPos)
	if not gridX or not gridZ then
		-- Mouse is off the grid — hide ghost
		ghostPart.Transparency = 1
		ghostPart.Position = Vector3.new(0, -100, 0)
		return
	end

	-- Track grid cell changes
	if gridX ~= lastGridX or gridZ ~= lastGridZ then
		lastGridX = gridX
		lastGridZ = gridZ
	end

	-- Snap ghost to grid
	local def = selectedBuildingDef
	local centerX = gridX + (def.size - 1) / 2
	local centerZ = gridZ + (def.size - 1) / 2
	local snapPos = Vector3.new(
		plotOrigin.X + (centerX - 0.5) * Constants.CELL_SIZE,
		ghostPart.Size.Y / 2 + 0.5,
		plotOrigin.Z + (centerZ - 0.5) * Constants.CELL_SIZE
	)
	ghostPart.Position = snapPos

	-- Check if placement is valid (within bounds)
	local valid = gridX >= 1 and gridZ >= 1
		and gridX + def.size - 1 <= Constants.GRID_SIZE
		and gridZ + def.size - 1 <= Constants.GRID_SIZE

	ghostPart.Transparency = valid and 0.4 or 0.8
	ghostPart.Color = valid and def.color or Color3.fromRGB(255, 50, 50)
end

function InputController.OnLeftClick()
	if buildMode and selectedBuildingDef then
		if buildModeFrameCount < 2 then
			return
		end

		local worldPos = InputController.GetMouseWorldPosition()
		if not worldPos then
			return
		end

		local gridX, gridZ = InputController.WorldToGrid(worldPos)
		if not gridX or not gridZ then
			return
		end

		Remotes:WaitForChild("BuildRequest"):FireServer(selectedBuildingDef.id, gridX, gridZ)

		if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			InputController.CancelBuildMode()
		end
		return
	end

	-- Unit/building selection
	local mouse = player:GetMouse()
	local target = mouse.Target
	if not target then
		InputController.ClearSelection()
		return
	end

	local isShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	if target.Name:find("Unit_") then
		if not isShift then
			InputController.ClearSelection()
		end
		InputController.SelectUnit(target)
		return
	end

	if target.Name:find("Building_") then
		InputController.ClearSelection()
		if InputController._onBuildingClicked then
			InputController._onBuildingClicked(target)
		end
		return
	end

	InputController.ClearSelection()
end

function InputController.OnRightClick()
	if next(selectedUnits) then
		local worldPos = InputController.GetMouseWorldPosition()
		if not worldPos then
			return
		end

		local unitIds = {}
		for unitId in selectedUnits do
			table.insert(unitIds, unitId)
		end

		Remotes:WaitForChild("MoveUnits"):FireServer(unitIds, worldPos)
	end
end

function InputController.SelectUnit(part: BasePart)
	local unitId = part.Name:match("Unit_%w+_(u%d+)")
	if not unitId then
		return
	end

	selectedUnits[unitId] = part

	local ring = part:FindFirstChild("SelectionRing")
	if ring then
		ring.Transparency = 0.3
	end
end

function InputController.ClearSelection()
	for unitId, part in selectedUnits do
		if part and part.Parent then
			local ring = part:FindFirstChild("SelectionRing")
			if ring then
				ring.Transparency = 1
			end
		end
	end
	selectedUnits = {}
end

function InputController.IsInBuildMode(): boolean
	return buildMode
end

function InputController.GetSelectedUnits()
	return selectedUnits
end

return InputController
