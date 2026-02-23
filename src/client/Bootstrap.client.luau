-- Nuclear'd Client Bootstrap
-- Initializes all client-side controllers

local Players = game:GetService("Players")
local PlayerModule = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local player = Players.LocalPlayer

print("[Nuclear'd] Client starting for", player.Name)

-- Disable default Roblox character controls (WASD should pan camera, not move avatar)
local controls = PlayerModule:GetControls()
controls:Disable()

local success, err = pcall(function()
	local Controllers = script.Parent:WaitForChild("Controllers", 10)
	if not Controllers then
		error("Controllers folder not found in PlayerScripts")
	end

	local CameraController = require(Controllers:WaitForChild("CameraController"))
	local InputController = require(Controllers:WaitForChild("InputController"))
	local UIController = require(Controllers:WaitForChild("UIController"))

	-- Initialize in order (camera first, then input, then UI)
	CameraController.Init()
	InputController.Init()
	UIController.Init(InputController)

	-- Wire cross-controller callbacks
	InputController._onBuildingClicked = function(part)
		UIController.OnBuildingClicked(part)
	end
end)

if success then
	print("[Nuclear'd] Client ready.")
else
	warn("[Nuclear'd] CLIENT INIT FAILED:", err)
end
