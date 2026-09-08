@tool
extends Node3D

## Script Điều phối Gameplay Cốt lõi (Core Gameplay Controller)
## Hỗ trợ thiết kế trực tiếp trên 3D Editor (@tool), Quản lý Camera RTS, Ngày/Đêm và Tương tác Entity

@export_group("Bản Đồ Sa Bàn (Editor Tools)")
@export_tool_button("▶ SINH SA BÀN 3D TRONG EDITOR")
var btn_gen = generate_map_in_editor

@export_tool_button("🗑 XÓA SẠCH SA BÀN")
var btn_clear = clear_map_in_editor

## Bấm nút này trong Inspector để sinh lại toàn bộ sa bàn 3D trực tiếp ra màn hình Editor
@export var tao_lai_ban_do_trong_editor: bool = false:
	set(val):
		if val and Engine.is_editor_hint():
			tao_lai_ban_do_trong_editor = false
			generate_map_in_editor()

## Bấm nút này trong Inspector để xóa sạch các node sa bàn
@export var xoa_sach_ban_do_trong_editor: bool = false:
	set(val):
		if val and Engine.is_editor_hint():
			xoa_sach_ban_do_trong_editor = false
			clear_map_in_editor()

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var grid_system: GridSystem = $Systems/GridSystem
@onready var world_node: Node3D = $World
var tiles_container: Node3D
var obstacles_container: Node3D
var buildings_container: Node3D
var decorations_container: Node3D

# UI Nodes
@onready var cell_info_label: Label = $UI/HUD/Panel/VBox/CellInfoLabel
@onready var time_label: Label = $UI/HUD/Panel/VBox/TimeLabel
@onready var wood_badge: Label = $UI/HUD/TopBar/Margin/HBox/WoodBadge
@onready var stone_badge: Label = $UI/HUD/TopBar/Margin/HBox/StoneBadge

# Camera Settings (RTS / Isometric)
var camera_angle: float = 45.0
var target_zoom: float = 28.0
var camera_pan_speed: float = 30.0
var is_dragging_camera: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# Day/Night State
var is_night: bool = false

# Player Resources
var wood_count: int = 30
var stone_count: int = 15

func _ready() -> void:
	tiles_container = _ensure_container("TilesContainer")
	obstacles_container = _ensure_container("ObstaclesContainer")
	buildings_container = _ensure_container("BuildingsContainer")
	decorations_container = _ensure_container("DecorationsContainer")

	if Engine.is_editor_hint():
		# Nếu đang mở trong Godot Editor: tự động sinh sa bàn để hiển thị trực quan trong 3D Viewport
		if tiles_container.get_child_count() == 0:
			generate_map_in_editor()
		return

	# Runtime gameplay logic
	if tiles_container.get_child_count() == 0:
		var castle_world_pos = KingdomMapBuilder.build_grand_map(
			grid_system,
			tiles_container,
			obstacles_container,
			buildings_container,
			decorations_container
		)
		camera_pivot.position = castle_world_pos
	else:
		_register_existing_nodes_to_grid()
		var castle = buildings_container.get_node_or_null("BuildingEntity")
		if castle:
			camera_pivot.position = castle.position
		else:
			camera_pivot.position = Vector3(34.0, 0.5, 32.0)

	camera.size = target_zoom
	update_camera_transform()
	_connect_interactive_signals()
	_update_hud_resources()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_handle_camera_movement(delta)

func _handle_camera_movement(delta: float) -> void:
	# Di chuyển camera bằng WASD hoặc Mũi tên
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
		
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var forward = -camera_pivot.transform.basis.z
		var right = camera_pivot.transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		
		var move_vec = (right * input_dir.x + forward * -input_dir.y) * camera_pan_speed * delta
		camera_pivot.position += move_vec
		
		# Giới hạn phạm vi camera trong ranh giới sa bàn 72m
		camera_pivot.position.x = clampf(camera_pivot.position.x, 10.0, 62.0)
		camera_pivot.position.z = clampf(camera_pivot.position.z, 10.0, 62.0)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Zoom bằng con lăn chuột (Tầm zoom 12.0 -> 55.0)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clampf(target_zoom + 2.5, 12.0, 55.0)
			camera.size = target_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clampf(target_zoom - 2.5, 12.0, 55.0)
			camera.size = target_zoom
			
		# Giữ chuột giữa kéo di chuyển camera
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging_camera = event.pressed
			last_mouse_pos = event.position
			
	if event is InputEventMouseMotion and is_dragging_camera:
		var diff = event.position - last_mouse_pos
		last_mouse_pos = event.position
		var right = camera_pivot.transform.basis.x
		var forward = camera_pivot.transform.basis.z
		right.y = 0
		forward.y = 0
		camera_pivot.position += (-right * diff.x + forward * diff.y) * 0.05
		camera_pivot.position.x = clampf(camera_pivot.position.x, 10.0, 62.0)
		camera_pivot.position.z = clampf(camera_pivot.position.z, 10.0, 62.0)
		
	# Phím Q / E: Xoay góc nhìn sa bàn 360 độ
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			camera_angle -= 45.0
			update_camera_transform()
		elif event.keycode == KEY_E:
			camera_angle += 45.0
			update_camera_transform()
			
	# Phím Space: Chuyển đổi Ngày / Đêm
	if event.is_action_pressed("ui_accept"):
		toggle_day_night()

func update_camera_transform() -> void:
	camera_pivot.rotation_degrees = Vector3(-35.264, camera_angle, 0)

func toggle_day_night() -> void:
	is_night = not is_night
	var tween = create_tween().set_parallel(true)
	
	if is_night:
		time_label.text = "THỜI GIAN: BAN ĐÊM (CHIẾN ĐẤU / PHÒNG THỦ)"
		time_label.add_theme_color_override("font_color", Color("#FF5252"))
		tween.tween_property(sun_light, "light_color", Color("#4A709C"), 0.8)
		tween.tween_property(sun_light, "light_energy", 0.35, 0.8)
		tween.tween_property(sun_light, "rotation_degrees", Vector3(-20, 120, 0), 0.8)
	else:
		time_label.text = "THỜI GIAN: BAN NGÀY (QUY HOẠCH & XÂY DỰNG)"
		time_label.add_theme_color_override("font_color", Color("#FFD54F"))
		tween.tween_property(sun_light, "light_color", Color("#FFF6E5"), 0.8)
		tween.tween_property(sun_light, "light_energy", 1.3, 0.8)
		tween.tween_property(sun_light, "rotation_degrees", Vector3(-45, 35, 0), 0.8)

## Kết nối tín hiệu tương tác
func _connect_interactive_signals() -> void:
	# Kết nối hover của các TerrainTile
	for child in tiles_container.get_children():
		if child is TerrainTile:
			child.tile_hovered.connect(_on_tile_hovered)
			child.tile_unhovered.connect(_on_tile_unhovered)
			
	# Kết nối click của các ResourceNode
	for child in obstacles_container.get_children():
		if child is ResourceNode:
			child.harvested.connect(_on_resource_harvested)
			child.depleted.connect(_on_resource_depleted)

func _on_tile_hovered(tile: TerrainTile) -> void:
	var info = grid_system.get_cell_info(tile.grid_coord)
	var status_text = "Trống (Sẵn sàng xây)"
	if not info.get("is_buildable", true):
		status_text = "Không thể xây"
	elif info.get("building") != null:
		status_text = "Đại Bản Doanh / Công trình"
	elif info.get("obstacle") != null:
		var obs: ResourceNode = info["obstacle"]
		status_text = "Có %s (Click để khai thác!)" % ("Cây lấy gỗ" if obs.node_type == ResourceNode.NodeType.TREE else "Mỏ đá")
		
	cell_info_label.text = "Ô Lưới: (%d, %d) | %s" % [tile.grid_coord.x, tile.grid_coord.y, status_text]

func _on_tile_unhovered(_tile: TerrainTile) -> void:
	cell_info_label.text = "Rê chuột vào ô cờ hoặc click cây/đá để khai thác"

func _on_resource_harvested(res_name: String, amount: int, _grid_pos: Vector2i) -> void:
	if res_name == "wood":
		wood_count += amount
	elif res_name == "stone":
		stone_count += amount
	_update_hud_resources()

func _on_resource_depleted(grid_pos: Vector2i) -> void:
	grid_system.unregister_obstacle(grid_pos)
	cell_info_label.text = "Đã khai thác xong ô (%d, %d)! Ô đất đã sẵn sàng để xây dựng." % [grid_pos.x, grid_pos.y]

func _update_hud_resources() -> void:
	if wood_badge:
		wood_badge.text = "🪵 GỖ: %d" % wood_count
	if stone_badge:
		stone_badge.text = "🧱 ĐÁ: %d" % stone_count

## Đảm bảo container tồn tại an toàn, tránh lỗi null node
func _ensure_container(container_name: String) -> Node3D:
	if not world_node:
		world_node = get_node_or_null("World")
		if not world_node:
			world_node = Node3D.new()
			world_node.name = "World"
			add_child(world_node)
	var container = world_node.get_node_or_null(container_name)
	if not container:
		container = Node3D.new()
		container.name = container_name
		world_node.add_child(container)
	return container

## Sinh bản đồ trực tiếp trong 3D Viewport của Editor để người dùng nhìn thấy và tùy biến
func generate_map_in_editor() -> void:
	tiles_container = _ensure_container("TilesContainer")
	obstacles_container = _ensure_container("ObstaclesContainer")
	buildings_container = _ensure_container("BuildingsContainer")
	decorations_container = _ensure_container("DecorationsContainer")
	
	clear_map_in_editor()
	
	var castle_pos = KingdomMapBuilder.build_grand_map(
		grid_system,
		tiles_container,
		obstacles_container,
		buildings_container,
		decorations_container
	)
	
	# Gán owner cho toàn bộ các node mới sinh để xuất hiện trong Scene Tree dock và 3D Viewport của Editor
	_set_owner_recursive(world_node, self)
	
	if camera_pivot:
		camera_pivot.position = castle_pos
	if camera:
		camera.size = target_zoom
	update_camera_transform()
	print("[CardLord] Đã khởi tạo thành công Sa Bàn 3D trực tiếp trên màn hình Editor!")

## Xóa sạch các node sa bàn trong Editor
func clear_map_in_editor() -> void:
	tiles_container = _ensure_container("TilesContainer")
	obstacles_container = _ensure_container("ObstaclesContainer")
	buildings_container = _ensure_container("BuildingsContainer")
	decorations_container = _ensure_container("DecorationsContainer")
	
	for cnt in [tiles_container, obstacles_container, buildings_container, decorations_container]:
		for c in cnt.get_children():
			cnt.remove_child(c)
			c.queue_free()

## Đệ quy gán owner để các node con xuất hiện trong Editor
func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root and node.owner == null:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)

## Đăng ký các node đã được đặt sẵn trong Editor vào GridSystem khi bắt đầu chơi
func _register_existing_nodes_to_grid() -> void:
	grid_system.initialize_grid()
	for child in tiles_container.get_children():
		if child is TerrainTile:
			grid_system.register_tile(child.grid_coord, child, child.is_buildable)
	for child in obstacles_container.get_children():
		if child is ResourceNode:
			grid_system.register_obstacle(child.grid_coord, child)
	for child in buildings_container.get_children():
		if child is BuildingEntity:
			grid_system.register_building(child.grid_coord, child)

