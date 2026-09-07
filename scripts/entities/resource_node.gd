@tool
class_name ResourceNode
extends Node3D

## Thực thể Tài nguyên & Chướng ngại Tự nhiên (Cây, Đá, Bụi, Núi)
## Quản lý trữ lượng tài nguyên, phản hồi tương tác khai thác (Juice) và giải phóng ô đất

signal node_clicked(node: ResourceNode)
signal harvested(resource_name: String, amount: int, grid_pos: Vector2i)
signal depleted(grid_pos: Vector2i)

enum NodeType {
	TREE,
	ROCK_QUARRY,
	BUSH,
	CLIFF
}

@export var node_type: NodeType = NodeType.TREE
@export var resource_name: String = "materials"
@export var current_resource_amount: int = 10
@export var is_destructible: bool = true
@export var grid_coord: Vector2i = Vector2i.ZERO
@export var custom_model_scene: PackedScene:
	set(val):
		custom_model_scene = val
		if is_inside_tree():
			_setup_model()

@onready var model_container: Node3D = $ModelContainer
@onready var area_3d: Area3D = $Area3D

var is_depleted: bool = false
var _is_animating: bool = false

func _ready() -> void:
	_setup_model()
	if area_3d and not Engine.is_editor_hint():
		area_3d.input_event.connect(_on_input_event)

func _setup_model() -> void:
	if not model_container:
		return
	if custom_model_scene:
		for child in model_container.get_children():
			child.queue_free()
		var instance = custom_model_scene.instantiate()
		model_container.add_child(instance)

## Gọi khi người chơi hoặc công nhân chặt cây / đập đá
func harvest(amount: int = 5) -> int:
	if is_depleted:
		return 0
		
	var gathered = mini(amount, current_resource_amount)
	current_resource_amount -= gathered
	
	# Hiệu ứng rung rinh khi bị tác động (Juice)
	_play_wobble_animation()
	
	harvested.emit(resource_name, gathered, grid_coord)
	
	if current_resource_amount <= 0 and is_destructible:
		_on_depleted()
		
	return gathered

## Hoạt ảnh rung rinh nảy (Squash & Stretch)
func _play_wobble_animation() -> void:
	if _is_animating or not model_container:
		return
	_is_animating = true
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(model_container, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	tween.tween_property(model_container, "scale", Vector3(0.9, 1.15, 0.9), 0.1)
	tween.tween_property(model_container, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	tween.finished.connect(func(): _is_animating = false)

## Khi tài nguyên cạn kiệt: tan biến và giải phóng ô đất
func _on_depleted() -> void:
	is_depleted = true
	depleted.emit(grid_coord)
	
	if model_container:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(model_container, "scale", Vector3.ZERO, 0.35)
		tween.parallel().tween_property(model_container, "position:y", -0.5, 0.35)
		tween.finished.connect(queue_free)
	else:
		queue_free()

func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(self)
		# Tự động chặt thử nghiệm 2 đơn vị gỗ/đá khi click chuột
		harvest(2)
