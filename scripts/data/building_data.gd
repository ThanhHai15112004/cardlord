class_name BuildingData
extends Resource

@export_group("Identity")
@export var id: String = ""
@export var building_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var texture: Texture2D

@export_group("Stats")
@export var max_hp: int = 100
@export var size: Vector2i = Vector2i(1, 1)

@export_group("Economy")
## Dictionary mapping resource name (e.g. "gold", "food", "material") to production per turn
@export var production: Dictionary = {}
## Dictionary mapping resource name to upkeep cost per turn
@export var upkeep: Dictionary = {}

@export_group("Rules & Effects")
@export var placement_rules: Array[String] = []
@export var adjacency_effects: Array[Dictionary] = []
@export var attack_data: Dictionary = {}
@export var upgrade_path: String = ""
