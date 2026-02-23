-- Nuclear'd Unit Definitions

local function res(sebum, grease, bacteria, sweat)
	return { Sebum = sebum, Grease = grease, Bacteria = bacteria, Sweat = sweat }
end

local Units = {
	-- === AGE 1: Mild Irritation ===
	Whitehead = {
		id = "Whitehead",
		name = "Whitehead",
		cost = res(50, 0, 0, 0),
		health = 50,
		damage = 8,
		attackSpeed = 1,
		moveSpeed = 12,
		range = 4,
		trainTime = 3,
		ageRequired = 1,
		color = Color3.fromRGB(255, 255, 230),
		size = 4,
		description = "Basic melee unit. Cheap and expendable.",
	},
	Blackhead = {
		id = "Blackhead",
		name = "Blackhead",
		cost = res(80, 20, 0, 0),
		health = 80,
		damage = 5,
		attackSpeed = 1.5,
		moveSpeed = 10,
		range = 20,
		trainTime = 5,
		ageRequired = 1,
		color = Color3.fromRGB(60, 60, 60),
		size = 4,
		description = "Ranged unit. Fires dark projectiles.",
	},

	-- === AGE 2: Breakout ===
	Pustule = {
		id = "Pustule",
		name = "Pustule",
		cost = res(150, 50, 30, 0),
		health = 120,
		damage = 15,
		attackSpeed = 0.8,
		moveSpeed = 8,
		range = 6,
		trainTime = 6,
		ageRequired = 2,
		color = Color3.fromRGB(255, 255, 100),
		size = 5,
		description = "Heavy melee. Explodes on death dealing area damage.",
	},
	Papule = {
		id = "Papule",
		name = "Papule",
		cost = res(120, 40, 20, 0),
		health = 60,
		damage = 20,
		attackSpeed = 1,
		moveSpeed = 14,
		range = 25,
		trainTime = 5,
		ageRequired = 2,
		color = Color3.fromRGB(255, 130, 130),
		size = 4,
		description = "Fast ranged unit. Glass cannon.",
	},

	-- === AGE 3: Full Eruption ===
	Nodule = {
		id = "Nodule",
		name = "Nodule",
		cost = res(300, 100, 80, 30),
		health = 250,
		damage = 30,
		attackSpeed = 0.6,
		moveSpeed = 6,
		range = 6,
		trainTime = 10,
		ageRequired = 3,
		color = Color3.fromRGB(180, 60, 60),
		size = 7,
		description = "Tank unit. Slow but incredibly tough.",
	},
	Carbuncle = {
		id = "Carbuncle",
		name = "Carbuncle",
		cost = res(250, 100, 60, 50),
		health = 100,
		damage = 45,
		attackSpeed = 0.5,
		moveSpeed = 10,
		range = 35,
		trainTime = 8,
		ageRequired = 3,
		color = Color3.fromRGB(100, 20, 20),
		size = 5,
		description = "Elite ranged unit. Devastating attacks.",
	},

	-- === AGE 4: NUCLEAR AGE ===
	Abscess = {
		id = "Abscess",
		name = "Abscess",
		cost = res(500, 200, 150, 100),
		health = 500,
		damage = 50,
		attackSpeed = 0.5,
		moveSpeed = 5,
		range = 8,
		trainTime = 15,
		ageRequired = 4,
		color = Color3.fromRGB(80, 0, 80),
		size = 8,
		description = "Ultimate tank. Walking fortress of infection.",
	},
}

return Units
