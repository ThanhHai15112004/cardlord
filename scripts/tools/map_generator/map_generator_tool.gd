@tool
class_name ProceduralMapGenerator
extends Node3D

## Trình Sinh Bản Đồ Sa Bàn Nổi Thủ Tục (@tool Procedural Map Generator)
## Tích hợp toàn bộ chuỗi 16 bước phát sinh sa bàn 3D (Procedural Diorama Engine)
## vào một Node trực quan trên Godot Inspector dock, hỗ trợ Random Seed, Clear Map,
## đồng bộ GridSystem và Bake trực tiếp thành PackedScene (.tscn).

const DEFAULT_PRESET_PATH: String = "res://data/presets/default_kingdom_map.tres"

@export_group("1. Cấu Hình & Tham Số")
@export var config: MapGenConfig

@export_group("2. Liên Kết Hệ Thống")
@export var grid_system: GridSystem

@export_group("3. Thao Tác Inspector (@tool)")
@export_tool_button("▶ GENERATE MAP")
var btn_gen = generate_map

@export_tool_button("🎲 RANDOM SEED & GENERATE")
var btn_rand = random_and_generate

@export_tool_button("🗑 CLEAR MAP")
var btn_clear = clear_map

# ------------------------------------------------------------------------------
# 1. Các Phương Thức Điều Khiển Chính
# ------------------------------------------------------------------------------

## Kích hoạt toàn bộ Pipeline 16 bước và trả về tọa độ thế giới của Lâu Đài
func generate_map() -> Vector3:
	var start_time: int = Time.get_ticks_msec()
	print(">>> [ProceduralMapGenerator] Bắt đầu phát sinh sa bàn 3D...")
	
	# 1. Dọn dẹp bản đồ cũ
	clear_map()
	
	# 2. Đảm bảo cấu hình MapGenConfig hợp lệ
	_ensure_config()
	
	# 3. Khởi tạo Context lưu trữ dữ liệu
	var context: MapGenContext = MapGenContext.new(config)
	
	# 4. Chuỗi 16 bước phát sinh (Phases 02 -> 07)
	# Bước 1-4: Phân tích vi mô & Tổng hợp cao độ (Phase 02)
	MacroLayoutGenerator.generate(context, config)
	
	# Bước 5-7: Phân tầng địa hình, Độ dốc & Vách đá (Phase 03)
	TerraceGenerator.generate(context, config)
	
	# Bước 8-10: Spline Dòng sông & Thủy văn (Phase 04)
	RiverGenerator.generate(context, config)
	
	# Bước 11-13: Định vị POI & Mạng lưới đường mòn A* (Phase 05)
	POIAndRoadGenerator.generate(context, config)
	
	# Bước 14-15: Mật độ rừng & Phân tán Poisson Disk Sampling (Phase 06)
	FoliageGenerator.generate(context, config)
	
	# Bước 16: Kết xuất 3D Sa bàn, Chân đế, Vách đá & GPU MultiMesh (Phase 07)
	var render_result: Dictionary = DioramaRenderer.render_diorama(self, context, config)
	
	# 5. Đồng bộ hóa sang GridSystem (nếu có liên kết)
	_sync_grid_system(context, render_result)
	
	# 6. Thiết lập Scene Tree Ownership cho Editor để hiển thị và lưu .tscn
	_setup_editor_ownership()
	
	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	print(">>> [ProceduralMapGenerator] Hoàn tất phát sinh sa bàn trong %d ms!" % elapsed_ms)
	
	var castle_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.CASTLE)
	if castle_coord == Vector2i(-1, -1):
		castle_coord = config.playable_origin + Vector2i(9, 9)
	var castle_y: float = context.get_world_y_for_cell(castle_coord.x, castle_coord.y)
	return context.grid_to_world(castle_coord, castle_y)

## Tạo ngẫu nhiên một Seed mới và kích hoạt sinh lại bản đồ
func random_and_generate() -> Vector3:
	_ensure_config()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	config.seed = rng.randi() % 1000000
	print(">>> [ProceduralMapGenerator] Đã đổi Seed mới: %d" % config.seed)
	return generate_map()

## Xóa sạch toàn bộ node con thuộc sa bàn đã sinh
func clear_map() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	print(">>> [ProceduralMapGenerator] Đã xóa sạch sa bàn.")

# ------------------------------------------------------------------------------
# 2. Tiện Ích Nội Bộ & Đồng Bộ Hệ Thống
# ------------------------------------------------------------------------------

func _ensure_config() -> void:
	if config == null:
		if ResourceLoader.exists(DEFAULT_PRESET_PATH):
			config = load(DEFAULT_PRESET_PATH) as MapGenConfig
		if config == null:
			config = MapGenConfig.new()

func _sync_grid_system(context: MapGenContext, render_result: Dictionary) -> void:
	if grid_system == null:
		# Tự động tìm kiếm trong parent hoặc scene
		grid_system = get_node_or_null("../Systems/GridSystem") as GridSystem
		if grid_system == null:
			grid_system = get_node_or_null("GridSystem") as GridSystem
			
	if grid_system != null:
		grid_system.sync_from_map_context(context, config)
		
		# Đăng ký các TerrainTile vào GridSystem
		var tiles_cnt = render_result.get("tiles_container", null)
		if tiles_cnt != null:
			for child in tiles_cnt.get_children():
				if child is TerrainTile:
					var tt: TerrainTile = child as TerrainTile
					grid_system.register_tile(tt.grid_coord, tt, tt.is_buildable)
					
		# Đăng ký các chướng ngại vật tài nguyên vào GridSystem
		var obs_cnt = render_result.get("obstacles_container", null)
		if obs_cnt != null:
			for child in obs_cnt.get_children():
				if child is ResourceNode:
					var rn: ResourceNode = child as ResourceNode
					grid_system.register_obstacle(rn.grid_coord, rn)
					
		# Đăng ký Lâu Đài vào GridSystem
		var poi_cnt = render_result.get("poi_container", null)
		if poi_cnt != null:
			for child in poi_cnt.get_children():
				if child is BuildingEntity:
					var be: BuildingEntity = child as BuildingEntity
					grid_system.register_building(be.grid_coord, be)

func _setup_editor_ownership() -> void:
	if not Engine.is_editor_hint():
		return
		
	# Tìm root của scene hiện tại đang được chỉnh sửa
	var target_owner: Node = owner
	if target_owner == null:
		target_owner = self
		
	_set_owner_recursive(self, target_owner)

func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if scene_root == null:
		return
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
