-- Nuclear'd Camera Controller
-- Top-down camera with WASD pan and scroll zoom

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local CameraController = {}

-- State
local plotOrigin = nil
local plotSize = nil
local currentZoom = Constants.CAMERA_DEFAULT_ZOOM
local cameraTarget = Vector3.new(32, 0, 32) -- default center
local keysDown = {}

function CameraController.Init()
	-- Wait for plot assignment
	Remotes:WaitForChild("PlotAssigned").OnClientEvent:Connect(function(origin, size)
		plotOrigin = origin
		plotSize = size
		cameraTarget = Vector3.new(
			origin.X + size / 2,
			0,
			origin.Z + size / 2
		)
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

	-- Update loop — force camera every single frame
	RunService.RenderStepped:Connect(function(dt)
		CameraController.Update(dt)
	end)

	print("[CameraController] Initialized")
end

function CameraController.Update(dt: number)
	-- Force camera to scriptable EVERY frame (Roblox tries to reset it)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	camera.CameraSubject = nil

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
	if plotOrigin and plotSize then
		local margin = 10
		cameraTarget = Vector3.new(
			math.clamp(cameraTarget.X, plotOrigin.X - margin, plotOrigin.X + plotSize + margin),
			0,
			math.clamp(cameraTarget.Z, plotOrigin.Z - margin, plotOrigin.Z + plotSize + margin)
		)
	end

	-- Apply top-down with slight angle for depth perception
	local cameraPos = cameraTarget + Vector3.new(0, currentZoom, currentZoom * 0.3)
	camera.CFrame = CFrame.lookAt(cameraPos, cameraTarget)
end

-- Get the world position the mouse is pointing at on the plot plane (Y=0.5)
function CameraController.GetMouseWorldPosition()
	local camera = workspace.CurrentCamera
	local mouse = Players.LocalPlayer:GetMouse()
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
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
