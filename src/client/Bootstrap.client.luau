-- Nuclear'd Client Bootstrap
-- Initializes all client-side controllers

local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

print("[Nuclear'd] Client starting for", player.Name)

-- On-screen debug log (top-right corner, shows errors/warnings)
local debugGui = Instance.new("ScreenGui")
debugGui.Name = "DebugLog"
debugGui.ResetOnSpawn = false
debugGui.DisplayOrder = 100
debugGui.Parent = player:WaitForChild("PlayerGui")

local debugFrame = Instance.new("ScrollingFrame")
debugFrame.Size = UDim2.new(0, 500, 0, 300)
debugFrame.Position = UDim2.new(1, -510, 0, 80)
debugFrame.BackgroundColor3 = Color3.new(0, 0, 0)
debugFrame.BackgroundTransparency = 0.3
debugFrame.BorderSizePixel = 0
debugFrame.ScrollBarThickness = 4
debugFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
debugFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
debugFrame.Parent = debugGui

local debugLayout = Instance.new("UIListLayout")
debugLayout.SortOrder = Enum.SortOrder.LayoutOrder
debugLayout.Parent = debugFrame

local debugPad = Instance.new("UIPadding")
debugPad.PaddingLeft = UDim.new(0, 4)
debugPad.PaddingTop = UDim.new(0, 4)
debugPad.Parent = debugFrame

local logOrder = 0
local function addDebugLine(text, color)
	logOrder += 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 11
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.LayoutOrder = logOrder
	label.Parent = debugFrame
	-- Auto-scroll to bottom
	debugFrame.CanvasPosition = Vector2.new(0, 99999)
end

-- Capture all log output
LogService.MessageOut:Connect(function(message, messageType)
	if message:find("Nuclear") or message:find("FAIL") or message:find("error") or message:find("Error") then
		local color = Color3.new(1, 1, 1)
		if messageType == Enum.MessageType.MessageWarning then
			color = Color3.new(1, 1, 0)
		elseif messageType == Enum.MessageType.MessageError then
			color = Color3.new(1, 0.3, 0.3)
		elseif messageType == Enum.MessageType.MessageInfo then
			color = Color3.new(0.5, 1, 0.5)
		end
		addDebugLine(message, color)
	end
end)

addDebugLine("=== Nuclear'd Debug Log ===", Color3.new(0.5, 0.5, 1))

-- Disable default Roblox character controls (WASD should pan camera, not move avatar)
local controlSuccess, controlErr = pcall(function()
	local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule", 10))
	local controls = PlayerModule:GetControls()
	controls:Disable()
	addDebugLine("Controls disabled OK", Color3.new(0.5, 1, 0.5))
end)
if not controlSuccess then
	addDebugLine("Controls disable failed: " .. tostring(controlErr), Color3.new(1, 1, 0))
end

-- Listen for server log messages
pcall(function()
	local Remotes = ReplicatedStorage:WaitForChild("Network", 10)
	if Remotes then
		Remotes = Remotes:WaitForChild("Remotes", 10)
		if Remotes then
			local gameState = Remotes:WaitForChild("GameState", 5)
			if gameState then
				gameState.OnClientEvent:Connect(function(msg)
					addDebugLine(tostring(msg), Color3.new(0.3, 0.7, 1))
				end)
			end
		end
	end
end)

-- Init game controllers
local success, err = pcall(function()
	addDebugLine("Waiting for Controllers folder...", Color3.new(0.7, 0.7, 0.7))
	local Controllers = script.Parent:WaitForChild("Controllers", 10)
	if not Controllers then
		error("Controllers folder not found in PlayerScripts")
	end
	addDebugLine("Controllers folder found", Color3.new(0.5, 1, 0.5))

	addDebugLine("Loading CameraController...", Color3.new(0.7, 0.7, 0.7))
	local CameraController = require(Controllers:WaitForChild("CameraController"))
	addDebugLine("Loading InputController...", Color3.new(0.7, 0.7, 0.7))
	local InputController = require(Controllers:WaitForChild("InputController"))
	addDebugLine("Loading UIController...", Color3.new(0.7, 0.7, 0.7))
	local UIController = require(Controllers:WaitForChild("UIController"))

	addDebugLine("Initializing CameraController...", Color3.new(0.7, 0.7, 0.7))
	CameraController.Init()
	addDebugLine("Initializing InputController...", Color3.new(0.7, 0.7, 0.7))
	InputController.Init()
	addDebugLine("Initializing UIController...", Color3.new(0.7, 0.7, 0.7))
	UIController.Init(InputController)

	-- Wire cross-controller callbacks
	InputController._onBuildingClicked = function(part)
		UIController.OnBuildingClicked(part)
	end
end)

if success then
	addDebugLine("CLIENT READY", Color3.new(0, 1, 0))
else
	addDebugLine("CLIENT INIT FAILED: " .. tostring(err), Color3.new(1, 0, 0))
end
