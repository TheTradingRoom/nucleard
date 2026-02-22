-- Nuclear'd Shared Type Annotations

export type ResourceSet = {
	Sebum: number,
	Grease: number,
	Bacteria: number,
	Sweat: number,
}

export type BuildingDef = {
	id: string,
	name: string,
	cost: ResourceSet,
	income: ResourceSet?,
	health: number,
	ageRequired: number, -- 1-4
	size: number, -- grid cells (square)
	color: Color3,
	isTurret: boolean?,
	damage: number?,
	range: number?,
	attackSpeed: number?,
	description: string,
}

export type UnitDef = {
	id: string,
	name: string,
	cost: ResourceSet,
	health: number,
	damage: number,
	attackSpeed: number, -- attacks per second
	moveSpeed: number, -- studs per second
	range: number, -- studs
	trainTime: number, -- seconds
	ageRequired: number,
	color: Color3,
	size: number, -- studs diameter
	description: string,
}

export type WaveEnemy = {
	name: string,
	health: number,
	damage: number,
	attackSpeed: number,
	moveSpeed: number,
	range: number,
	color: Color3,
	size: number,
	reward: ResourceSet,
}

export type WaveDef = {
	waveNumber: number,
	enemies: { { enemy: WaveEnemy, count: number } },
	spawnDelay: number, -- seconds between each enemy spawn
}

export type PlacedBuilding = {
	id: string,
	defId: string,
	owner: Player,
	gridX: number,
	gridZ: number,
	health: number,
	maxHealth: number,
	part: BasePart,
}

export type ActiveUnit = {
	id: string,
	defId: string,
	owner: Player,
	health: number,
	maxHealth: number,
	damage: number,
	attackSpeed: number,
	moveSpeed: number,
	range: number,
	part: BasePart,
	target: Vector3?,
	attackTarget: string?, -- id of enemy/unit being attacked
	lastAttackTime: number,
}

export type EnemyUnit = {
	id: string,
	health: number,
	maxHealth: number,
	damage: number,
	attackSpeed: number,
	moveSpeed: number,
	range: number,
	part: BasePart,
	targetBuildingId: string?,
	lastAttackTime: number,
	reward: ResourceSet,
}

return nil
