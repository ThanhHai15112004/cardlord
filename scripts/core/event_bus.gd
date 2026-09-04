extends Node

## Global Event Bus for decoupled communication between systems

# Turn System Signals
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)

# Card Signals
signal card_drawn(card_data: CardData)
signal card_played(card_data: CardData)
signal card_discarded(card_data: CardData)

# Resource Signals
signal resource_changed(resource_name: String, new_amount: int, delta: int)

# Kingdom / Grid Signals
signal building_placed(building_data: BuildingData, grid_pos: Vector2i)
signal building_destroyed(building_data: BuildingData, grid_pos: Vector2i)

# Combat Signals
signal combat_started()
signal combat_ended(victory: bool)
signal unit_spawned(unit_data: UnitData, pos: Vector2)
signal unit_defeated(unit_data: UnitData)
