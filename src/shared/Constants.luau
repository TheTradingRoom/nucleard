-- Nuclear'd Game Constants

local Constants = {
	-- Game info
	GAME_NAME = "Nuclear'd",
	MAX_PLAYERS = 20,

	-- Grid / Plot
	CELL_SIZE = 4, -- studs per grid cell
	GRID_SIZE = 16, -- cells per side (16x16 = 256 cells)
	PLOT_SIZE = 64, -- studs per side (CELL_SIZE * GRID_SIZE)

	-- Resources
	RESOURCES = {
		SEBUM = "Sebum",
		GREASE = "Grease",
		BACTERIA = "Bacteria",
		SWEAT = "Sweat",
	},

	-- Starting resources
	START_SEBUM = 500,
	START_GREASE = 100,
	START_BACTERIA = 0,
	START_SWEAT = 50,

	-- Base passive income (per second)
	BASE_INCOME_SEBUM = 2,
	BASE_INCOME_GREASE = 0,
	BASE_INCOME_BACTERIA = 0,
	BASE_INCOME_SWEAT = 0,

	-- Ages
	AGES = {
		{ name = "Mild Irritation", cost = 0 },
		{ name = "Breakout", cost = 1000 },
		{ name = "Full Eruption", cost = 3000 },
		{ name = "NUCLEAR AGE", cost = 8000 },
	},

	-- Tick rates (per second)
	MOVEMENT_TICK_RATE = 10,
	COMBAT_TICK_RATE = 2,
	ECONOMY_TICK_RATE = 1,

	-- Wave timing
	FIRST_WAVE_DELAY = 90, -- seconds before first wave
	WAVE_INTERVAL = 60, -- seconds between waves
	WAVE_WARNING_TIME = 10, -- seconds of warning before wave arrives

	-- Nuclear
	NUCLEAR_ENRICH_TIME = 60, -- seconds to enrich
	NUCLEAR_LAUNCH_COUNTDOWN = 30,
	NUCLEAR_BLAST_RADIUS = 100,

	-- Camera
	CAMERA_MIN_ZOOM = 40,
	CAMERA_MAX_ZOOM = 120,
	CAMERA_DEFAULT_ZOOM = 70,
	CAMERA_PAN_SPEED = 60, -- studs per second
	CAMERA_ZOOM_SPEED = 10, -- studs per scroll tick

	-- Plot appearance
	PLOT_COLOR = Color3.fromRGB(240, 180, 160), -- flesh-colored
	PLOT_MATERIAL = Enum.Material.SmoothPlastic,

	-- UI Colors
	UI_COLORS = {
		Sebum = Color3.fromRGB(255, 223, 135),
		Grease = Color3.fromRGB(180, 180, 60),
		Bacteria = Color3.fromRGB(100, 200, 100),
		Sweat = Color3.fromRGB(100, 150, 255),
		Background = Color3.fromRGB(30, 30, 40),
		Panel = Color3.fromRGB(45, 45, 60),
		Button = Color3.fromRGB(70, 70, 90),
		ButtonHover = Color3.fromRGB(90, 90, 120),
		Text = Color3.fromRGB(240, 240, 240),
		TextDim = Color3.fromRGB(160, 160, 160),
		Danger = Color3.fromRGB(255, 80, 80),
		Success = Color3.fromRGB(80, 255, 80),
		Warning = Color3.fromRGB(255, 200, 50),
		Age1 = Color3.fromRGB(200, 200, 200),
		Age2 = Color3.fromRGB(255, 200, 100),
		Age3 = Color3.fromRGB(255, 100, 50),
		Age4 = Color3.fromRGB(255, 50, 255),
	},
}

return Constants
