class_name TerrainTile
extends Node3D

## Thực thể Ô địa hình (Terrain Tile Entity)
## Đại diện cho 1 ô cờ 2m x 2m trên mặt sàn sa bàn (Cỏ, Nước, Cát, Đá, Đường)

signal tile_hovered(tile: TerrainTile)
signal tile_unhovered(tile: TerrainTile)
signal tile_clicked(tile: TerrainTile, button_index: int)

enum TileType {
	GRASS,
	WATER,
	SAND,
	ROCK,
	ROAD
}

@export var tile_type: TileType = TileType.GRASS:
	set(val):
		tile_type = val
		_update_buildable_state()

@export var is_buildable: bool = true
@export var grid_coord: Vector2i = Vector2i.ZERO
@export var custom_model_scene: PackedScene

@onready var model_container: Node3D = $ModelContainer
@onready var highlight_mesh: MeshInstance3D = $HighlightMesh
@onready var area_3d: Area3D = $Area3D

var is_highlighted: bool = false

func _ready() -> void:
	_update_buildable_state()
	set_highlight(false)
	_setup_visual()
	
	if area_3d:
		area_3d.mouse_entered.connect(_on_mouse_entered)
		area_3d.mouse_exited.connect(_on_mouse_exited)
		area_3d.input_event.connect(_on_input_event)

func _update_buildable_state() -> void:
	match tile_type:
		TileType.WATER:
			is_buildable = false
		TileType.ROCK:
			is_buildable = false
		_:
			is_buildable = true

func _setup_visual() -> void:
	if not model_container:
		return
		
	# Nếu có custom scene model được gán vào thì instance
	if custom_model_scene:
		for child in model_container.get_children():
			child.queue_free()
		var instance = custom_model_scene.instantiate()
		model_container.add_child(instance)

## Đổi trạng thái hiển thị viền highlight khi chuột rê vào
func set_highlight(enabled: bool, is_valid: bool = true) -> void:
	is_highlighted = enabled
	if not highlight_mesh:
		return
		
	highlight_mesh.visible = enabled
	if enabled:
		var mat = highlight_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			if is_valid and is_buildable:
				mat.albedo_color = Color(0.2, 1.0, 0.4, 0.45) # Xanh lá: hợp lệ
			else:
				mat.albedo_color = Color(1.0, 0.25, 0.25, 0.45) # Đỏ: không thể xây
			highlight_mesh.set_surface_override_material(0, mat)

func _on_mouse_entered() -> void:
	set_highlight(true, is_buildable)
	tile_hovered.emit(self)

func _on_mouse_exited() -> void:
	set_highlight(false)
	tile_unhovered.emit(self)

func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		tile_clicked.emit(self, event.button_index)
