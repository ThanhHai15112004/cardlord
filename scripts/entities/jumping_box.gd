extends CharacterBody2D

## Script điều khiển Box nhảy trên nền tảng

const JUMP_VELOCITY: float = -600.0
const GRAVITY: float = 1200.0

@onready var color_rect: ColorRect = $ColorRect
@onready var face_label: Label = $Face

var jump_count: int = 0

func _physics_process(delta: float) -> void:
	# Thêm trọng lực khi box ở trên không
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		# Khi chạm đất (đang nằm trên box dài), tự động nhảy lên!
		jump()

	# Cho phép người dùng bấm phím Space / Enter để kích hoạt nhảy
	if Input.is_action_just_pressed("ui_accept"):
		jump()

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Click chuột bất kỳ đâu cũng kích hoạt nhảy
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		jump()

func jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_count += 1
	
	# Hiệu ứng nảy (Squash & Stretch) dùng Tween cho sinh động
	var tween = create_tween()
	# Co lại lúc chuẩn bị phóng
	scale = Vector2(1.35, 0.75)
	# Dãn dài ra khi bay lên không trung
	tween.tween_property(self, "scale", Vector2(0.85, 1.25), 0.08)
	# Trở lại kích thước bình thường
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Đổi biểu cảm nháy mắt khi nhảy
	if face_label:
		face_label.text = "> _ <"
		get_tree().create_timer(0.25).timeout.connect(func():
			if is_instance_valid(face_label):
				face_label.text = "^ _ ^"
		)
