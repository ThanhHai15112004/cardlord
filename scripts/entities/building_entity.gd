@tool
class_name BuildingEntity
extends Node3D

## Thực thể Công trình (Building Entity)
## Đại diện cho các công trình đặt trên lưới (Lâu đài, Tháp canh, Nông trại, Xưởng cưa...)

signal building_clicked(building: BuildingEntity)
signal building_damaged(current_hp: int, max_hp: int)
signal building_destroyed(building: BuildingEntity)

@export var building_data: BuildingData
@export var grid_coord: Vector2i = Vector2i.ZERO
@export var custom_model_scene: PackedScene:
	set(val):
		custom_model_scene = val
		if is_inside_tree():
			_setup_model()

@onready var model_container: Node3D = $ModelContainer
@onready var area_3d: Area3D = $Area3D

var current_hp: int = 100
var max_hp: int = 100

func _ready() -> void:
	if building_data:
		max_hp = building_data.max_hp
		current_hp = max_hp
		
	_setup_model()
	if not Engine.is_editor_hint():
		play_placement_animation()
	
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

## Hoạt ảnh nảy khi đặt công trình xuống (Juice)
func play_placement_animation() -> void:
	if not model_container:
		return
	model_container.scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(model_container, "scale", Vector3.ONE, 0.5)

## Nhận sát thương khi bị quái tấn công
func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	building_damaged.emit(current_hp, max_hp)
	
	# Rung nhẹ báo hiệu trúng đòn
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(model_container, "position:x", 0.08, 0.05)
	tween.tween_property(model_container, "position:x", -0.08, 0.05)
	tween.tween_property(model_container, "position:x", 0.0, 0.05)
	
	if current_hp <= 0:
		_on_destroyed()

## Khi công trình sụp đổ
func _on_destroyed() -> void:
	building_destroyed.emit(self)
	if model_container:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(model_container, "scale:y", 0.05, 0.3)
		tween.parallel().tween_property(model_container, "scale:x", 1.2, 0.3)
		tween.parallel().tween_property(model_container, "scale:z", 1.2, 0.3)
		tween.finished.connect(queue_free)
	else:
		queue_free()

func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		building_clicked.emit(self)
