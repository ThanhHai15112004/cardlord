extends Node3D

## Script điều khiển tương tác xoay, zoom và Ngày/Đêm cho màn chơi 3D Isometric

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var info_label: Label = $UI/Panel/VBox/InfoLabel
@onready var time_label: Label = $UI/Panel/VBox/TimeLabel

var is_night: bool = false
var camera_angle: float = 45.0
var target_zoom: float = 12.0

func _ready() -> void:
	update_camera_transform()

func _process(delta: float) -> void:
	# Xoay camera bằng phím A/D hoặc Mũi tên trái/phải
	var rot_dir: float = Input.get_axis("ui_left", "ui_right")
	if rot_dir != 0.0:
		camera_angle += rot_dir * 90.0 * delta
		update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	# Zoom bằng con lăn chuột
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clampf(target_zoom + 1.0, 6.0, 24.0)
			camera.size = target_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clampf(target_zoom - 1.0, 6.0, 24.0)
			camera.size = target_zoom
			
	# Phím Space: Chuyển đổi Ngày / Đêm
	if event.is_action_pressed("ui_accept"):
		toggle_day_night()
		
	# Phím P: Chuyển đổi giữa Orthogonal và Perspective
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		toggle_projection()

func update_camera_transform() -> void:
	camera_pivot.rotation_degrees = Vector3(-35.264, camera_angle, 0)

func toggle_day_night() -> void:
	is_night = not is_night
	var tween = create_tween().set_parallel(true)
	
	if is_night:
		time_label.text = "THỜI GIAN: BAN ĐÊM (CHIẾN ĐẤU / PHÒNG THỦ)"
		time_label.add_theme_color_override("font_color", Color("#FF5252"))
		# Mặt trời lặn -> Ánh trăng xanh lạnh
		tween.tween_property(sun_light, "light_color", Color("#4A709C"), 0.8)
		tween.tween_property(sun_light, "light_energy", 0.35, 0.8)
		tween.tween_property(sun_light, "rotation_degrees", Vector3(-20, 120, 0), 0.8)
		$NightTorchLight.visible = true
	else:
		time_label.text = "THỜI GIAN: BAN NGÀY (XÂY DỰNG & QUY HOẠCH)"
		time_label.add_theme_color_override("font_color", Color("#FFD54F"))
		# Bình minh -> Nắng vàng ấm áp
		tween.tween_property(sun_light, "light_color", Color("#FFF6E5"), 0.8)
		tween.tween_property(sun_light, "light_energy", 1.3, 0.8)
		tween.tween_property(sun_light, "rotation_degrees", Vector3(-45, 35, 0), 0.8)
		$NightTorchLight.visible = false

func toggle_projection() -> void:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 30.0
		info_label.text = "Chế độ Camera: Perspective (Phối cảnh hẹp FOV 30°)"
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = target_zoom
		info_label.text = "Chế độ Camera: Orthogonal (Isometric Sa bàn chuẩn)"
