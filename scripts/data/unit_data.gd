class_name UnitData
extends Resource

enum UnitRole {
	INFANTRY,
	ARCHER,
	CAVALRY,
	SIEGE,
	SPECIAL
}

@export_group("Identity")
@export var id: String = ""
@export var unit_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var role: UnitRole = UnitRole.INFANTRY

@export_group("Combat Stats")
@export var max_hp: int = 50
@export var attack: int = 10
@export var defense: int = 2
@export var attack_speed: float = 1.0
@export var attack_range: float = 1.0
@export var target_priority: String = "nearest"

@export_group("Economy & Upkeep")
@export var population_cost: int = 1
@export var food_upkeep: int = 1

@export_group("Tags & Traits")
@export var tags: Array[String] = []
