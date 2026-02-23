-- Nuclear'd UI Controller
-- Builds all HUD/menus programmatically: resource bar, age display, build menu, unit training, nuclear status

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Buildings = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Buildings"))
local Units = require(ReplicatedStorage:WaitForChild("GameConfig"):WaitForChild("Units"))
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")

local UIController = {}

-- References
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local InputController = nil -- set in Init

-- UI State
local currentAge = 1
local currentResources = { Sebum = 0, Grease = 0, Bacteria = 0, Sweat = 0 }
local currentIncome = { Sebum = 0, Grease = 0, Bacteria = 0, Sweat = 0 }
local nuclearState = "none"
local nuclearValue = 0
local selectedBuildingId = nil

-- UI Elements
local screenGui = nil
local resourceLabels = {}
local ageLabel = nil
local waveLabel = nil
local buildPanel = nil
local unitPanel = nil
local nuclearPanel = nil
local messageLabel = nil
local gameOverFrame = nil

-- Helper: create a styled frame
local function makeFrame(parent, props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Constants.UI_COLORS.Panel
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.new(0, 200, 0, 100)
	frame.Position = props.position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = props.anchor or Vector2.new(0, 0)
	if props.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, props.cornerRadius)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- Helper: create a styled text label
local function makeLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = props.color or Constants.UI_COLORS.Text
	label.Font = props.font or Enum.Font.GothamBold
	label.TextSize = props.textSize or 14
	label.Size = props.size or UDim2.new(1, 0, 0, 20)
	label.Position = props.position or UDim2.new(0, 0, 0, 0)
	label.Text = props.text or ""
	label.TextXAlignment = props.align or Enum.TextXAlignment.Left
	if props.textScaled then
		label.TextScaled = true
	end
	label.Parent = parent
	return label
end

-- Helper: create a styled button
local function makeButton(parent, props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = props.color or Constants.UI_COLORS.Button
	button.BorderSizePixel = 0
	button.TextColor3 = props.textColor or Constants.UI_COLORS.Text
	button.Font = props.font or Enum.Font.GothamBold
	button.TextSize = props.textSize or 14
	button.Size = props.size or UDim2.new(0, 150, 0, 36)
	button.Position = props.position or UDim2.new(0, 0, 0, 0)
	button.Text = props.text or "Button"
	button.AutoButtonColor = true
	if props.textScaled then
		button.TextScaled = true
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.Parent = parent
	return button
end

function UIController.Init(inputController)
	InputController = inputController

	-- Create main ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NucleardHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	UIController.BuildResourceBar()
	UIController.BuildBuildPanel()
	UIController.BuildUnitPanel()
	UIController.BuildNuclearPanel()
	UIController.BuildMessageArea()
	UIController.BuildGameOverScreen()
	UIController.BuildTutorial()

	-- Connect remote events
	Remotes.ResourceUpdate.OnClientEvent:Connect(function(resources, income)
		currentResources = resources
		currentIncome = income or currentIncome
		UIController.UpdateResourceBar()
	end)

	Remotes.AgeAdvanced.OnClientEvent:Connect(function(age, ageName)
		currentAge = age
		UIController.UpdateAge(age, ageName)
		UIController.RefreshBuildMenu()
	end)

	Remotes.WaveWarning.OnClientEvent:Connect(function(waveNum, timeLeft)
		UIController.ShowMessage("WAVE " .. waveNum .. " INCOMING! " .. timeLeft .. "s", Constants.UI_COLORS.Danger, 3)
	end)

	Remotes.WaveCleared.OnClientEvent:Connect(function(waveNum)
		UIController.ShowMessage("Wave " .. waveNum .. " CLEARED!", Constants.UI_COLORS.Success, 3)
	end)

	Remotes.NuclearStatus.OnClientEvent:Connect(function(status, value)
		nuclearState = status
		nuclearValue = value
		UIController.UpdateNuclearPanel()
	end)

	Remotes.GameOver.OnClientEvent:Connect(function(won)
		UIController.ShowGameOver(won)
	end)

	Remotes.BuildingDestroyed.OnClientEvent:Connect(function(buildingId)
		if selectedBuildingId == buildingId then
			UIController.HideUnitPanel()
			selectedBuildingId = nil
		end
	end)

	print("[UIController] Initialized")
end

function UIController.BuildResourceBar()
	-- Age label — separate, above the resource bar
	ageLabel = makeLabel(screenGui, {
		text = "AGE 1: Mild Irritation",
		size = UDim2.new(0, 300, 0, 24),
		position = UDim2.new(0.5, 0, 0, 6),
		textSize = 16,
		font = Enum.Font.GothamBold,
		color = Constants.UI_COLORS.Age1,
		align = Enum.TextXAlignment.Center,
	})
	ageLabel.Name = "AgeLabel"
	ageLabel.AnchorPoint = Vector2.new(0.5, 0)

	-- Resource bar
	local bar = makeFrame(screenGui, {
		size = UDim2.new(0, 540, 0, 44),
		position = UDim2.new(0.5, 0, 0, 32),
		anchor = Vector2.new(0.5, 0),
		color = Constants.UI_COLORS.Background,
		cornerRadius = 8,
	})
	bar.Name = "ResourceBar"

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = bar

	-- Resource displays
	local resourceOrder = { "Sebum", "Grease", "Bacteria", "Sweat" }
	for _, resName in resourceOrder do
		local container = Instance.new("Frame")
		container.BackgroundTransparency = 1
		container.Size = UDim2.new(0, 100, 0, 36)
		container.Parent = bar

		local icon = Instance.new("Frame")
		icon.Size = UDim2.new(0, 10, 0, 10)
		icon.Position = UDim2.new(0, 0, 0.5, -5)
		icon.BackgroundColor3 = Constants.UI_COLORS[resName]
		icon.BorderSizePixel = 0
		icon.Parent = container
		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, 5)
		iconCorner.Parent = icon

		local nameLabel = makeLabel(container, {
			text = resName,
			size = UDim2.new(1, -15, 0, 14),
			position = UDim2.new(0, 15, 0, 2),
			textSize = 10,
			color = Constants.UI_COLORS.TextDim,
		})

		local valueLabel = makeLabel(container, {
			text = "0",
			size = UDim2.new(1, -15, 0, 18),
			position = UDim2.new(0, 15, 0, 15),
			textSize = 14,
			color = Constants.UI_COLORS[resName],
		})
		valueLabel.Name = "Value"

		resourceLabels[resName] = valueLabel
	end

	-- Wave info
	waveLabel = makeLabel(bar, {
		text = "",
		size = UDim2.new(0, 70, 0, 36),
		textSize = 11,
		color = Constants.UI_COLORS.Warning,
		align = Enum.TextXAlignment.Center,
	})
	waveLabel.Name = "WaveLabel"
end

function UIController.UpdateResourceBar()
	for resName, label in resourceLabels do
		local amount = math.floor(currentResources[resName] or 0)
		local income = currentIncome[resName] or 0
		if income > 0 then
			label.Text = tostring(amount) .. " (+" .. income .. ")"
		else
			label.Text = tostring(amount)
		end
	end
end

function UIController.UpdateAge(age, ageName)
	if ageLabel then
		ageLabel.Text = "AGE " .. age .. ": " .. ageName
		local ageColors = {
			Constants.UI_COLORS.Age1,
			Constants.UI_COLORS.Age2,
			Constants.UI_COLORS.Age3,
			Constants.UI_COLORS.Age4,
		}
		ageLabel.TextColor3 = ageColors[age] or Constants.UI_COLORS.Text
	end
end

function UIController.BuildBuildPanel()
	buildPanel = makeFrame(screenGui, {
		size = UDim2.new(0, 220, 0, 400),
		position = UDim2.new(0, 10, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = Constants.UI_COLORS.Background,
		cornerRadius = 8,
	})
	buildPanel.Name = "BuildPanel"

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = buildPanel

	local title = makeLabel(buildPanel, {
		text = "BUILD",
		size = UDim2.new(1, 0, 0, 24),
		textSize = 16,
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	title.Name = "Title"

	-- Advance Age button
	local ageBtn = makeButton(buildPanel, {
		text = "Advance Age (1000 Sebum)",
		size = UDim2.new(1, 0, 0, 32),
		position = UDim2.new(0, 0, 0, 28),
		color = Constants.UI_COLORS.Warning,
		textColor = Constants.UI_COLORS.Background,
		textSize = 12,
	})
	ageBtn.Name = "AdvanceAgeBtn"
	ageBtn.MouseButton1Click:Connect(function()
		Remotes.AdvanceAge:FireServer()
	end)

	-- Scroll frame for building buttons
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "BuildingList"
	scrollFrame.Size = UDim2.new(1, 0, 1, -70)
	scrollFrame.Position = UDim2.new(0, 0, 0, 66)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = buildPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = scrollFrame

	UIController.RefreshBuildMenu()
end

function UIController.RefreshBuildMenu()
	if not buildPanel then
		return
	end

	local scrollFrame = buildPanel:FindFirstChild("BuildingList")
	if not scrollFrame then
		return
	end

	-- Clear existing buttons
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Update advance age button
	local ageBtn = buildPanel:FindFirstChild("AdvanceAgeBtn")
	if ageBtn then
		if currentAge >= #Constants.AGES then
			ageBtn.Visible = false
		else
			local nextAge = Constants.AGES[currentAge + 1]
			ageBtn.Text = "Advance to " .. nextAge.name .. " (" .. nextAge.cost .. " Sebum)"
			ageBtn.Visible = true
		end
	end

	-- Sort buildings by age then name
	local sortedBuildings = {}
	for id, def in Buildings do
		table.insert(sortedBuildings, def)
	end
	table.sort(sortedBuildings, function(a, b)
		if a.ageRequired ~= b.ageRequired then
			return a.ageRequired < b.ageRequired
		end
		return a.name < b.name
	end)

	-- Create buttons for available buildings
	for _, def in sortedBuildings do
		if def.ageRequired > currentAge then
			continue
		end

		local costText = ""
		if def.cost.Sebum > 0 then
			costText = costText .. def.cost.Sebum .. "S "
		end
		if def.cost.Grease > 0 then
			costText = costText .. def.cost.Grease .. "G "
		end
		if def.cost.Bacteria > 0 then
			costText = costText .. def.cost.Bacteria .. "B "
		end
		if def.cost.Sweat > 0 then
			costText = costText .. def.cost.Sweat .. "W "
		end

		local btn = makeButton(scrollFrame, {
			text = def.name .. "\n" .. costText,
			size = UDim2.new(1, 0, 0, 44),
			color = def.color:Lerp(Constants.UI_COLORS.Panel, 0.6),
			textSize = 11,
		})
		btn.Name = "Build_" .. def.id
		btn.TextWrapped = true

		btn.MouseButton1Click:Connect(function()
			if InputController then
				InputController.EnterBuildMode(def.id)
			end
		end)
	end
end

function UIController.BuildUnitPanel()
	unitPanel = makeFrame(screenGui, {
		size = UDim2.new(0, 300, 0, 180),
		position = UDim2.new(0.5, 0, 1, -10),
		anchor = Vector2.new(0.5, 1),
		color = Constants.UI_COLORS.Background,
		cornerRadius = 8,
	})
	unitPanel.Name = "UnitPanel"
	unitPanel.Visible = false

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = unitPanel

	local title = makeLabel(unitPanel, {
		text = "TRAIN UNITS",
		size = UDim2.new(1, 0, 0, 20),
		textSize = 14,
		align = Enum.TextXAlignment.Center,
	})
	title.Name = "Title"

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "UnitList"
	scrollFrame.Size = UDim2.new(1, 0, 1, -28)
	scrollFrame.Position = UDim2.new(0, 0, 0, 26)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = unitPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Wraps = true
	listLayout.Parent = scrollFrame
end

function UIController.ShowUnitPanel(buildingId: string, buildingDefId: string)
	if not unitPanel then
		return
	end

	selectedBuildingId = buildingId
	unitPanel.Visible = true

	local scrollFrame = unitPanel:FindFirstChild("UnitList")
	if not scrollFrame then
		return
	end

	-- Clear existing
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Determine which units this barracks can train
	local isAdvanced = buildingDefId == "AdvancedBarracks"

	local sortedUnits = {}
	for id, def in Units do
		table.insert(sortedUnits, def)
	end
	table.sort(sortedUnits, function(a, b)
		return a.ageRequired < b.ageRequired
	end)

	for _, def in sortedUnits do
		if def.ageRequired > currentAge then
			continue
		end
		if def.ageRequired >= 3 and not isAdvanced then
			continue
		end

		local costText = def.cost.Sebum .. "S"
		if def.cost.Grease > 0 then
			costText = costText .. " " .. def.cost.Grease .. "G"
		end
		if def.cost.Bacteria > 0 then
			costText = costText .. " " .. def.cost.Bacteria .. "B"
		end

		local btn = makeButton(scrollFrame, {
			text = def.name .. "\n" .. costText .. " | " .. def.trainTime .. "s",
			size = UDim2.new(0, 140, 0, 50),
			color = def.color:Lerp(Constants.UI_COLORS.Panel, 0.6),
			textSize = 11,
		})
		btn.TextWrapped = true

		btn.MouseButton1Click:Connect(function()
			Remotes.TrainUnit:FireServer(buildingId, def.id)
		end)
	end
end

function UIController.HideUnitPanel()
	if unitPanel then
		unitPanel.Visible = false
	end
	selectedBuildingId = nil
end

function UIController.BuildNuclearPanel()
	nuclearPanel = makeFrame(screenGui, {
		size = UDim2.new(0, 250, 0, 80),
		position = UDim2.new(1, -10, 0, 70),
		anchor = Vector2.new(1, 0),
		color = Constants.UI_COLORS.Background,
		cornerRadius = 8,
	})
	nuclearPanel.Name = "NuclearPanel"
	nuclearPanel.Visible = false

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = nuclearPanel

	local title = makeLabel(nuclearPanel, {
		text = "NUCLEAR STATUS",
		size = UDim2.new(1, 0, 0, 18),
		textSize = 12,
		color = Constants.UI_COLORS.Age4,
		align = Enum.TextXAlignment.Center,
	})
	title.Name = "Title"

	-- Progress bar
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, 0, 0, 16)
	barBg.Position = UDim2.new(0, 0, 0, 22)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBg.BorderSizePixel = 0
	barBg.Parent = nuclearPanel

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Constants.UI_COLORS.Age4
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local statusLabel = makeLabel(nuclearPanel, {
		text = "",
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.new(0, 0, 0, 42),
		textSize = 12,
		align = Enum.TextXAlignment.Center,
	})
	statusLabel.Name = "Status"

	-- Launch button
	local launchBtn = makeButton(nuclearPanel, {
		text = "LAUNCH THE NUCLEAR",
		size = UDim2.new(1, 0, 0, 28),
		position = UDim2.new(0, 0, 1, -32),
		color = Constants.UI_COLORS.Danger,
		textSize = 13,
	})
	launchBtn.Name = "LaunchBtn"
	launchBtn.Visible = false
	launchBtn.MouseButton1Click:Connect(function()
		Remotes.LaunchNuclear:FireServer()
	end)
end

function UIController.UpdateNuclearPanel()
	if not nuclearPanel then
		return
	end

	if nuclearState == "none" then
		nuclearPanel.Visible = false
		return
	end

	nuclearPanel.Visible = true
	local barBg = nuclearPanel:FindFirstChild("BarBg")
	local fill = barBg and barBg:FindFirstChild("Fill")
	local status = nuclearPanel:FindFirstChild("Status")
	local launchBtn = nuclearPanel:FindFirstChild("LaunchBtn")

	if nuclearState == "enriching" then
		if fill then
			fill.Size = UDim2.new(nuclearValue, 0, 1, 0)
			fill.BackgroundColor3 = Constants.UI_COLORS.Warning
		end
		if status then
			status.Text = "Enriching... " .. math.floor(nuclearValue * 100) .. "%"
		end
		if launchBtn then
			launchBtn.Visible = false
		end

	elseif nuclearState == "ready" then
		if fill then
			fill.Size = UDim2.new(1, 0, 1, 0)
			fill.BackgroundColor3 = Constants.UI_COLORS.Success
		end
		if status then
			status.Text = "ENRICHMENT COMPLETE"
			status.TextColor3 = Constants.UI_COLORS.Success
		end
		if launchBtn then
			launchBtn.Visible = true
		end

	elseif nuclearState == "launching" then
		if fill then
			fill.Size = UDim2.new(1, 0, 1, 0)
			fill.BackgroundColor3 = Constants.UI_COLORS.Danger
		end
		if status then
			status.Text = "LAUNCHING IN " .. nuclearValue .. "..."
			status.TextColor3 = Constants.UI_COLORS.Danger
		end
		if launchBtn then
			launchBtn.Visible = false
		end

	elseif nuclearState == "detonated" then
		if status then
			status.Text = "NUCLEAR DETONATED!!!"
			status.TextColor3 = Constants.UI_COLORS.Age4
		end
		if launchBtn then
			launchBtn.Visible = false
		end

	elseif nuclearState == "boss_incoming" then
		if status then
			status.Text = "THE DERMATOLOGIST APPROACHES..."
			status.TextColor3 = Constants.UI_COLORS.Danger
		end

	elseif nuclearState == "silo_destroyed" then
		if status then
			status.Text = "SILO DESTROYED! Build another."
			status.TextColor3 = Constants.UI_COLORS.Danger
		end
		if launchBtn then
			launchBtn.Visible = false
		end
	end
end

function UIController.BuildMessageArea()
	messageLabel = makeLabel(screenGui, {
		text = "",
		size = UDim2.new(0, 500, 0, 40),
		position = UDim2.new(0.5, 0, 0, 65),
		textSize = 20,
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	messageLabel.Name = "MessageLabel"
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.TextStrokeTransparency = 0.5
	messageLabel.Visible = false
end

function UIController.ShowMessage(text: string, color: Color3?, duration: number?)
	if not messageLabel then
		return
	end
	messageLabel.Text = text
	messageLabel.TextColor3 = color or Constants.UI_COLORS.Text
	messageLabel.Visible = true

	task.delay(duration or 3, function()
		if messageLabel and messageLabel.Text == text then
			messageLabel.Visible = false
		end
	end)
end

function UIController.BuildGameOverScreen()
	gameOverFrame = makeFrame(screenGui, {
		size = UDim2.new(1, 0, 1, 0),
		color = Color3.new(0, 0, 0),
		cornerRadius = 0,
	})
	gameOverFrame.Name = "GameOver"
	gameOverFrame.BackgroundTransparency = 0.4
	gameOverFrame.Visible = false

	local titleLabel = makeLabel(gameOverFrame, {
		text = "",
		size = UDim2.new(0, 600, 0, 80),
		position = UDim2.new(0.5, 0, 0.35, 0),
		textSize = 48,
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	titleLabel.Name = "Title"
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)

	local subtitleLabel = makeLabel(gameOverFrame, {
		text = "",
		size = UDim2.new(0, 600, 0, 40),
		position = UDim2.new(0.5, 0, 0.45, 0),
		textSize = 24,
		font = Enum.Font.Gotham,
		align = Enum.TextXAlignment.Center,
	})
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
end

function UIController.ShowGameOver(won: boolean)
	if not gameOverFrame then
		return
	end

	gameOverFrame.Visible = true

	local title = gameOverFrame:FindFirstChild("Title")
	local subtitle = gameOverFrame:FindFirstChild("Subtitle")

	if won then
		if title then
			title.Text = "NUCLEAR'D!"
			title.TextColor3 = Constants.UI_COLORS.Age4
		end
		if subtitle then
			subtitle.Text = "You defeated The Dermatologist! Clear skin achieved!"
			subtitle.TextColor3 = Constants.UI_COLORS.Success
		end
	else
		if title then
			title.Text = "SQUEEZED OUT"
			title.TextColor3 = Constants.UI_COLORS.Danger
		end
		if subtitle then
			subtitle.Text = "Your base was destroyed. The face remains blemished."
			subtitle.TextColor3 = Constants.UI_COLORS.TextDim
		end
	end
end

-- Called by InputController when a building is clicked
function UIController.OnBuildingClicked(part: BasePart)
	-- Extract building info from part name
	local defId = part.Name:match("Building_(%w+)_")
	local buildingId = part.Name:match("Building_%w+_(%d+)")

	if not defId or not buildingId then
		UIController.HideUnitPanel()
		return
	end

	-- Show unit panel if barracks
	if defId == "Barracks" or defId == "AdvancedBarracks" then
		UIController.ShowUnitPanel(buildingId, defId)
	else
		UIController.HideUnitPanel()
	end

	-- Start enrichment if Nuclear Silo clicked
	if defId == "NuclearSilo" and nuclearState == "none" then
		-- Nuclear system will handle this server-side when silo is built
	end
end

function UIController.BuildTutorial()
	local tutorialFrame = makeFrame(screenGui, {
		size = UDim2.new(0, 320, 0, 380),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Constants.UI_COLORS.Background,
		cornerRadius = 10,
	})
	tutorialFrame.Name = "Tutorial"

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = tutorialFrame

	local title = makeLabel(tutorialFrame, {
		text = "HOW TO PLAY",
		size = UDim2.new(1, 0, 0, 24),
		textSize = 18,
		font = Enum.Font.GothamBold,
		color = Constants.UI_COLORS.Age4,
		align = Enum.TextXAlignment.Center,
	})

	local guideText = [[CONTROLS:
  WASD / Arrows = Pan camera
  Scroll = Zoom in/out
  ESC = Cancel build / deselect

BUILDING:
  1. Click a building in the BUILD panel (left)
  2. A ghost follows your mouse on the grid
  3. Click to place it
  4. Hold SHIFT + click = place multiple
  5. Sebum Pumps = income! Build these first

UNITS:
  1. Build a Barracks first
  2. Click on the placed Barracks
  3. Unit training panel appears (bottom)
  4. Click a unit to train it
  5. Click units to select, right-click to move

AGES:
  Click "Advance Age" to unlock better stuff
  Costs Sebum (shown on the button)

WAVES:
  Enemies attack every 60s from edges
  Build Pustule Turrets (Age 2) to defend!

WIN CONDITION:
  1. Reach NUCLEAR AGE (Age 4)
  2. Build a Nuclear Silo
  3. Wait for enrichment (60s)
  4. Click LAUNCH
  5. Survive The Dermatologist boss!]]

	local guideLabel = makeLabel(tutorialFrame, {
		text = guideText,
		size = UDim2.new(1, 0, 1, -60),
		position = UDim2.new(0, 0, 0, 28),
		textSize = 11,
		font = Enum.Font.RobotoMono,
		color = Constants.UI_COLORS.Text,
		align = Enum.TextXAlignment.Left,
	})
	guideLabel.TextWrapped = true
	guideLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- Close button
	local closeBtn = makeButton(tutorialFrame, {
		text = "GOT IT (close)",
		size = UDim2.new(1, 0, 0, 28),
		position = UDim2.new(0, 0, 1, -28),
		color = Constants.UI_COLORS.Success,
		textColor = Constants.UI_COLORS.Background,
		textSize = 13,
	})
	closeBtn.MouseButton1Click:Connect(function()
		tutorialFrame.Visible = false
	end)
end

return UIController
