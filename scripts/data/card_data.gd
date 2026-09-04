class_name CardData
extends Resource

enum CardType {
	BUILDING,
	UNIT,
	TACTIC,
	UPGRADE,
	ECONOMIC
}

enum CardRarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

enum TargetType {
	NONE,
	GRID_CELL,
	BUILDING,
	UNIT,
	ENEMY
}

@export_group("Identity")
@export var id: String = ""
@export var card_name: String = ""
@export var card_type: CardType = CardType.BUILDING
@export var rarity: CardRarity = CardRarity.COMMON
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Costs")
@export var command_cost: int = 1
@export var gold_cost: int = 0
@export var food_cost: int = 0
@export var material_cost: int = 0
@export var population_cost: int = 0

@export_group("Targeting & Effect")
@export var target_type: TargetType = TargetType.NONE
@export var effect_id: String = ""
@export var tags: Array[String] = []
@export var upgrade_id: String = ""
