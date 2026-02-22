-- Nuclear'd Wave Enemy Tables

local function res(sebum, grease, bacteria, sweat)
	return { Sebum = sebum, Grease = grease, Bacteria = bacteria, Sweat = sweat }
end

-- Enemy templates
local Enemies = {
	CottonSwab = {
		name = "Cotton Swab",
		health = 40,
		damage = 5,
		attackSpeed = 1,
		moveSpeed = 10,
		range = 4,
		color = Color3.fromRGB(240, 240, 255),
		size = 2,
		reward = res(10, 0, 0, 0),
	},
	SalicylicDrop = {
		name = "Salicylic Drop",
		health = 25,
		damage = 10,
		attackSpeed = 1.5,
		moveSpeed = 14,
		range = 18,
		color = Color3.fromRGB(150, 220, 255),
		size = 2,
		reward = res(15, 5, 0, 0),
	},
	BenzoylBlob = {
		name = "Benzoyl Blob",
		health = 80,
		damage = 12,
		attackSpeed = 0.8,
		moveSpeed = 7,
		range = 5,
		color = Color3.fromRGB(200, 200, 255),
		size = 3,
		reward = res(20, 10, 5, 0),
	},
	RetinoidRoller = {
		name = "Retinoid Roller",
		health = 150,
		damage = 20,
		attackSpeed = 0.6,
		moveSpeed = 5,
		range = 6,
		color = Color3.fromRGB(255, 200, 100),
		size = 4,
		reward = res(40, 20, 10, 5),
	},
	LaserBeam = {
		name = "Laser Beam",
		health = 60,
		damage = 40,
		attackSpeed = 0.3,
		moveSpeed = 16,
		range = 30,
		color = Color3.fromRGB(255, 50, 50),
		size = 2,
		reward = res(30, 15, 10, 5),
	},
	TheDermatologist = {
		name = "The Dermatologist",
		health = 2000,
		damage = 80,
		attackSpeed = 0.5,
		moveSpeed = 4,
		range = 15,
		color = Color3.fromRGB(255, 255, 255),
		size = 8,
		reward = res(0, 0, 0, 0), -- you win!
	},
}

-- Wave definitions: escalating difficulty
local Waves = {
	{
		waveNumber = 1,
		spawnDelay = 1.5,
		enemies = {
			{ enemy = Enemies.CottonSwab, count = 5 },
		},
	},
	{
		waveNumber = 2,
		spawnDelay = 1.2,
		enemies = {
			{ enemy = Enemies.CottonSwab, count = 8 },
			{ enemy = Enemies.SalicylicDrop, count = 2 },
		},
	},
	{
		waveNumber = 3,
		spawnDelay = 1.0,
		enemies = {
			{ enemy = Enemies.CottonSwab, count = 6 },
			{ enemy = Enemies.SalicylicDrop, count = 5 },
			{ enemy = Enemies.BenzoylBlob, count = 2 },
		},
	},
	{
		waveNumber = 4,
		spawnDelay = 0.8,
		enemies = {
			{ enemy = Enemies.SalicylicDrop, count = 8 },
			{ enemy = Enemies.BenzoylBlob, count = 5 },
		},
	},
	{
		waveNumber = 5,
		spawnDelay = 0.8,
		enemies = {
			{ enemy = Enemies.BenzoylBlob, count = 8 },
			{ enemy = Enemies.RetinoidRoller, count = 3 },
		},
	},
	{
		waveNumber = 6,
		spawnDelay = 0.6,
		enemies = {
			{ enemy = Enemies.SalicylicDrop, count = 10 },
			{ enemy = Enemies.BenzoylBlob, count = 6 },
			{ enemy = Enemies.RetinoidRoller, count = 4 },
			{ enemy = Enemies.LaserBeam, count = 2 },
		},
	},
	{
		waveNumber = 7,
		spawnDelay = 0.5,
		enemies = {
			{ enemy = Enemies.RetinoidRoller, count = 8 },
			{ enemy = Enemies.LaserBeam, count = 5 },
		},
	},
	{
		waveNumber = 8,
		spawnDelay = 0.4,
		enemies = {
			{ enemy = Enemies.BenzoylBlob, count = 10 },
			{ enemy = Enemies.RetinoidRoller, count = 6 },
			{ enemy = Enemies.LaserBeam, count = 8 },
		},
	},
}

-- Boss wave (triggered by nuclear launch)
local BossWave = {
	waveNumber = 99,
	spawnDelay = 0.3,
	enemies = {
		{ enemy = Enemies.TheDermatologist, count = 1 },
		{ enemy = Enemies.LaserBeam, count = 10 },
		{ enemy = Enemies.RetinoidRoller, count = 8 },
	},
}

return {
	Enemies = Enemies,
	Waves = Waves,
	BossWave = BossWave,
}
