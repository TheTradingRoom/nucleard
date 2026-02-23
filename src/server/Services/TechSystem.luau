-- Nuclear'd Tech System
-- Age tracking, advancement validation, cost deduction

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local ResourceSystem = require(script.Parent.ResourceSystem)

local TechSystem = {}

-- State: [Player] = age number (1-4)
local playerAge = {}

function TechSystem.Init()
	Remotes.AdvanceAge.OnServerEvent:Connect(function(player)
		TechSystem.HandleAdvanceAge(player)
	end)

	print("[TechSystem] Initialized")
end

function TechSystem.InitPlayer(player: Player)
	playerAge[player] = 1
	Remotes.AgeAdvanced:FireClient(player, 1, Constants.AGES[1].name)
end

function TechSystem.CleanupPlayer(player: Player)
	playerAge[player] = nil
end

function TechSystem.GetAge(player: Player): number
	return playerAge[player] or 1
end

function TechSystem.HandleAdvanceAge(player: Player)
	local currentAge = playerAge[player]
	if not currentAge then
		return
	end

	-- Already at max age
	if currentAge >= #Constants.AGES then
		return
	end

	local nextAge = currentAge + 1
	local ageDef = Constants.AGES[nextAge]

	-- Check cost (Sebum)
	local cost = { Sebum = ageDef.cost, Grease = 0, Bacteria = 0, Sweat = 0 }
	if not ResourceSystem.CanAfford(player, cost) then
		return
	end

	-- Deduct and advance
	ResourceSystem.Deduct(player, cost)
	playerAge[player] = nextAge

	-- Notify client
	Remotes.AgeAdvanced:FireClient(player, nextAge, ageDef.name)

	print("[TechSystem]", player.Name, "advanced to age", nextAge, "-", ageDef.name)
end

return TechSystem
