-- Nuclear'd Server Bootstrap
-- Initializes all server-side game systems

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

print("[Nuclear'd] Server starting...")

-- Disable default character movement controls (we use WASD for camera)
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
StarterPlayer.EnableMouseLockOption = false
StarterPlayer.CameraMode = Enum.CameraMode.Classic

-- Safety net: hide character even if game systems fail
local function hideCharacter(player, character)
	task.wait(0.5) -- small delay to let character fully load

	-- Kill ForceField
	local ff = character:FindFirstChildOfClass("ForceField")
	if ff then ff:Destroy() end
	character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") then child:Destroy() end
	end)

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)

	if humanoid then
		humanoid.MaxHealth = 99999
		humanoid.Health = 99999
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end

	if rootPart then
		rootPart.CFrame = CFrame.new(32, -50, 32)
		rootPart.Anchored = true
	end

	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.CanCollide = false
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		end
	end
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.CanCollide = false
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		end
	end)
end

-- Character hiding runs independently of game systems
Players.PlayerAdded:Connect(function(player)
	if player.Character then
		task.spawn(hideCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(hideCharacter, player, character)
	end)
end)
for _, player in Players:GetPlayers() do
	if player.Character then
		task.spawn(hideCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(hideCharacter, player, character)
	end)
end

-- Send server errors to clients via GameState remote
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function serverLog(msg)
	print("[Server] " .. msg)
	pcall(function()
		local Remotes = ReplicatedStorage:WaitForChild("Network", 5)
		if Remotes then
			Remotes = Remotes:WaitForChild("Remotes", 5)
			if Remotes then
				local gameState = Remotes:FindFirstChild("GameState")
				if gameState then
					for _, p in Players:GetPlayers() do
						gameState:FireClient(p, "SERVER: " .. msg)
					end
				end
			end
		end
	end)
end

-- Now init game systems
local success, err = pcall(function()
	serverLog("Looking for Services folder...")
	local Services = script.Parent:WaitForChild("Services", 10)
	if not Services then
		error("Services folder not found in ServerScriptService")
	end
	serverLog("Services folder found")

	local GameManager = require(Services:WaitForChild("GameManager"))
	GameManager.Init()
end)

if success then
	serverLog("SERVER READY - all systems go")
else
	serverLog("SERVER INIT FAILED: " .. tostring(err))
	warn("[Nuclear'd] SERVER INIT FAILED:", err)
end
