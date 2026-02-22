-- Nuclear'd Camera Controller
-- Top-down camera with WASD pan and scroll zoom

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Constants)
local Remotes = ReplicatedStorage.Network.Remotes

local CameraController = {}

-- State
local camera = workspace.CurrentCamera
local plotOrigin = nil
local plotSize = nil
local currentZoom = Constants.CAMERA_DEFAULT_ZOOM
local cameraTarget = Vector3.new(0, 0, 0)
local keysDown = {}

function CameraController.Init()
	-- Wait for plot assignment
	Remotes.PlotAssigned.OnClientEvent:Connect(function(origin, size)
		plotOrigin = origin
		plotSize = size
		-- Center camera on plot
		cameraTarget = Vector3.new(
			origin.X + size / 2,
			0,
			origin.Z + size / 2
		)
		CameraController.ApplyCamera()
	end)

	-- Input handling
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keysDown[input.KeyCode] = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keysDown[input.KeyCode] = nil
		end
	end)

	-- Scroll zoom
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			currentZoom = math.clamp(
				currentZoom - input.Position.Z * Constants.CAMERA_ZOOM_SPEED,
				Constants.CAMERA_MIN_ZOOM,
				Constants.CAMERA_MAX_ZOOM
			)
		end
	end)

	-- Update loop
	RunService.RenderStepped:Connect(function(dt)
		CameraController.Update(dt)
	end)

	-- Set camera type
	camera.CameraType = Enum.CameraType.Scriptable

	print("[CameraController] Initialized")
end

function CameraController.Update(dt: number)
	if not plotOrigin then
		return
	end

	-- WASD panning
	local moveDir = Vector3.new(0, 0, 0)
	if keysDown[Enum.KeyCode.W] or keysDown[Enum.KeyCode.Up] then
		moveDir = moveDir + Vector3.new(0, 0, -1)
	end
	if keysDown[Enum.KeyCode.S] or keysDown[Enum.KeyCode.Down] then
		moveDir = moveDir + Vector3.new(0, 0, 1)
	end
	if keysDown[Enum.KeyCode.A] or keysDown[Enum.KeyCode.Left] then
		moveDir = moveDir + Vector3.new(-1, 0, 0)
	end
	if keysDown[Enum.KeyCode.D] or keysDown[Enum.KeyCode.Right] then
		moveDir = moveDir + Vector3.new(1, 0, 0)
	end

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
		cameraTarget = cameraTarget + moveDir * Constants.CAMERA_PAN_SPEED * dt
	end

	-- Clamp camera to plot bounds (with some margin)
	local margin = 10
	cameraTarget = Vector3.new(
		math.clamp(cameraTarget.X, plotOrigin.X - margin, plotOrigin.X + plotSize + margin),
		0,
		math.clamp(cameraTarget.Z, plotOrigin.Z - margin, plotOrigin.Z + plotSize + margin)
	)

	CameraController.ApplyCamera()
end

function CameraController.ApplyCamera()
	-- Top-down with slight angle for depth perception
	local cameraPos = cameraTarget + Vector3.new(0, currentZoom, currentZoom * 0.3)
	camera.CFrame = CFrame.lookAt(cameraPos, cameraTarget)
end

-- Get the world position the mouse is pointing at on the plot plane (Y=0.5)
function CameraController.GetMouseWorldPosition(): Vector3?
	local mouse = Players.LocalPlayer:GetMouse()
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	-- Intersect with Y = 0.5 plane (top of baseplate)
	local planeY = 0.5
	if ray.Direction.Y == 0 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

return CameraController
