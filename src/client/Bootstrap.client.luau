-- Nuclear'd Client Bootstrap
-- Initializes all client-side controllers

local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("[Nuclear'd] Client starting for", player.Name)

local CameraController = require(script.Controllers.CameraController)
local InputController = require(script.Controllers.InputController)
local UIController = require(script.Controllers.UIController)

-- Initialize in order (camera first, then input, then UI)
CameraController.Init()
InputController.Init()
UIController.Init(InputController)

-- Wire cross-controller callbacks
InputController._onBuildingClicked = function(part)
	UIController.OnBuildingClicked(part)
end

print("[Nuclear'd] Client ready.")
