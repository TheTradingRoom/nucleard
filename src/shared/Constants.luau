-- Nuclear'd Game Constants

local Constants = {
	-- Game info
	GAME_NAME = "Nuclear'd",
	MAX_PLAYERS = 20,

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

	-- Nuclear
	NUCLEAR_LAUNCH_COUNTDOWN = 30,
	NUCLEAR_BLAST_RADIUS = 100,
	CLEAN_SKIN_ZONE_DURATION = 120,
}

return Constants
