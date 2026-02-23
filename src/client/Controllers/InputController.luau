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
local selectedBuildingDef = nil
local ghostPart = nil
local selectedUnits = {} -- { [unitId] = Part }
local lastGridX, lastGridZ = 0, 0

function InputController.Init()
	-- Wait for plot assignment
	Remotes.PlotAssigned.OnClientEvent:Connect(function(origin, size)
		plotOrigin = origin
		plotSize = size
	end)

	-- Mouse click
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.OnLeftClick()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			InputController.OnRightClick()
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				InputController.CancelBuildMode()
				InputController.ClearSelection()
			end
		end
	end)

	-- Update ghost position
	RunService.RenderStepped:Connect(function()
		if buildMode and ghostPart and plotOrigin then
			InputController.UpdateGhost()
		end
	end)

	print("[InputController] Initialized")
end

function InputController.GetMouseWorldPosition()
	return CameraController.GetMouseWorldPosition()
end

function InputController.WorldToGrid(worldPos: Vector3): (number?, number?)
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
	ghostPart.Transparency = 0.5
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
		ghostPart.Transparency = 0.8
		return
	end

	lastGridX = gridX
	lastGridZ = gridZ

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
		-- Place building
		local worldPos = InputController.GetMouseWorldPosition()
		if not worldPos then
			return
		end

		local gridX, gridZ = InputController.WorldToGrid(worldPos)
		if not gridX or not gridZ then
			return
		end

		Remotes.BuildRequest:FireServer(selectedBuildingDef.id, gridX, gridZ)

		-- Stay in build mode for rapid placement (shift)
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

	-- Check if clicking a unit
	local isShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	if target.Name:find("Unit_") then
		if not isShift then
			InputController.ClearSelection()
		end
		InputController.SelectUnit(target)
		return
	end

	-- Check if clicking a building (for selection info)
	if target.Name:find("Building_") then
		InputController.ClearSelection()
		-- Notify UIController locally
		if InputController._onBuildingClicked then
			InputController._onBuildingClicked(target)
		end
		return
	end

	-- Clicked on ground
	InputController.ClearSelection()
end

function InputController.OnRightClick()
	-- Right click = move selected units
	if next(selectedUnits) then
		local worldPos = InputController.GetMouseWorldPosition()
		if not worldPos then
			return
		end

		local unitIds = {}
		for unitId in selectedUnits do
			table.insert(unitIds, unitId)
		end

		Remotes.MoveUnits:FireServer(unitIds, worldPos)
	end
end

function InputController.SelectUnit(part: BasePart)
	-- Extract unit ID from part name (format: Unit_DefId_uN)
	local unitId = part.Name:match("Unit_%w+_(u%d+)")
	if not unitId then
		return
	end

	selectedUnits[unitId] = part

	-- Show selection ring
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
