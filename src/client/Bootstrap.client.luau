-- Nuclear'd Client Bootstrap
-- Initializes all client-side controllers

local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("[Nuclear'd] Client starting for", player.Name)

-- Disable default Roblox character controls (WASD should pan camera, not move avatar)
local controlSuccess, controlErr = pcall(function()
	local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule", 10))
	local controls = PlayerModule:GetControls()
	controls:Disable()
end)
if not controlSuccess then
	warn("[Nuclear'd] Controls disable failed: " .. tostring(controlErr))
end

-- Init game controllers
local success, err = pcall(function()
	local Controllers = script.Parent:WaitForChild("Controllers", 10)
	if not Controllers then
		error("Controllers folder not found in PlayerScripts")
	end

	local CameraController = require(Controllers:WaitForChild("CameraController"))
	local InputController = require(Controllers:WaitForChild("InputController"))
	local UIController = require(Controllers:WaitForChild("UIController"))

	CameraController.Init()
	InputController.Init()
	UIController.Init(InputController)

	-- Wire cross-controller callbacks
	InputController._onBuildingClicked = function(part)
		UIController.OnBuildingClicked(part)
	end
end)

if success then
	print("[Nuclear'd] Client ready")
else
	warn("[Nuclear'd] CLIENT INIT FAILED: " .. tostring(err))
end
