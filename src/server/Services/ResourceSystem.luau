-- Nuclear'd Resource System
-- Per-player resource tracking, economy tick (1 Hz)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local ResourceSystem = {}

-- State: [Player] = { Sebum, Grease, Bacteria, Sweat }
local playerResources = {}
-- Income bonuses from buildings: [Player] = { Sebum, Grease, Bacteria, Sweat }
local playerIncome = {}

function ResourceSystem.Init()
	print("[ResourceSystem] Initialized")
end

function ResourceSystem.InitPlayer(player: Player)
	playerResources[player] = {
		Sebum = Constants.START_SEBUM,
		Grease = Constants.START_GREASE,
		Bacteria = Constants.START_BACTERIA,
		Sweat = Constants.START_SWEAT,
	}
	playerIncome[player] = {
		Sebum = 0,
		Grease = 0,
		Bacteria = 0,
		Sweat = 0,
	}
	ResourceSystem.SendUpdate(player)
end

function ResourceSystem.CleanupPlayer(player: Player)
	playerResources[player] = nil
	playerIncome[player] = nil
end

-- Called by economy tick (1 Hz)
function ResourceSystem.Tick()
	for player, resources in playerResources do
		if not player.Parent then
			continue
		end
		local income = playerIncome[player]
		if not income then
			continue
		end

		-- Apply base income + building income
		resources.Sebum += Constants.BASE_INCOME_SEBUM + income.Sebum
		resources.Grease += Constants.BASE_INCOME_GREASE + income.Grease
		resources.Bacteria += Constants.BASE_INCOME_BACTERIA + income.Bacteria
		resources.Sweat += Constants.BASE_INCOME_SWEAT + income.Sweat

		ResourceSystem.SendUpdate(player)
	end
end

function ResourceSystem.SendUpdate(player: Player)
	local resources = playerResources[player]
	local income = playerIncome[player]
	if resources then
		Remotes.ResourceUpdate:FireClient(player, resources, income)
	end
end

function ResourceSystem.GetResources(player: Player)
	return playerResources[player]
end

function ResourceSystem.CanAfford(player: Player, cost): boolean
	local resources = playerResources[player]
	if not resources then
		return false
	end
	return resources.Sebum >= (cost.Sebum or 0)
		and resources.Grease >= (cost.Grease or 0)
		and resources.Bacteria >= (cost.Bacteria or 0)
		and resources.Sweat >= (cost.Sweat or 0)
end

function ResourceSystem.Deduct(player: Player, cost): boolean
	if not ResourceSystem.CanAfford(player, cost) then
		return false
	end
	local resources = playerResources[player]
	resources.Sebum -= (cost.Sebum or 0)
	resources.Grease -= (cost.Grease or 0)
	resources.Bacteria -= (cost.Bacteria or 0)
	resources.Sweat -= (cost.Sweat or 0)
	ResourceSystem.SendUpdate(player)
	return true
end

function ResourceSystem.AddResources(player: Player, amount)
	local resources = playerResources[player]
	if not resources then
		return
	end
	resources.Sebum += (amount.Sebum or 0)
	resources.Grease += (amount.Grease or 0)
	resources.Bacteria += (amount.Bacteria or 0)
	resources.Sweat += (amount.Sweat or 0)
	ResourceSystem.SendUpdate(player)
end

function ResourceSystem.SetIncome(player: Player, income)
	playerIncome[player] = income
end

function ResourceSystem.AddIncome(player: Player, income)
	local current = playerIncome[player]
	if not current then
		return
	end
	current.Sebum += (income.Sebum or 0)
	current.Grease += (income.Grease or 0)
	current.Bacteria += (income.Bacteria or 0)
	current.Sweat += (income.Sweat or 0)
end

function ResourceSystem.RemoveIncome(player: Player, income)
	local current = playerIncome[player]
	if not current then
		return
	end
	current.Sebum -= (income.Sebum or 0)
	current.Grease -= (income.Grease or 0)
	current.Bacteria -= (income.Bacteria or 0)
	current.Sweat -= (income.Sweat or 0)
end

return ResourceSystem
