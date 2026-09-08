@tool
class_name KingdomMapBuilder
extends RefCounted

## Bộ Điều Phối Xây Dựng Sa Bàn Vương Quốc (Kingdom Map Builder Facade)
## Đóng vai trò Facade trung gian chuyển tiếp yêu cầu khởi tạo sa bàn từ Gameplay Scene
## sang Hệ thống Sinh Sa Bàn Thủ Tục 16 bước (Procedural Diorama Engine).
## Đảm bảo tương thích ngược 100% với gameplay.gd và bake_map_scene.gd.

const DEFAULT_CONFIG_PATH: String = "res://data/presets/default_kingdom_map.tres"

## Hàm chính xây dựng toàn bộ bản đồ sa bàn qua Procedural Engine
static func build_grand_map(
	grid_system: GridSystem,
	tiles_container: Node3D,
	obstacles_container: Node3D,
	buildings_container: Node3D,
	decorations_container: Node3D
) -> Vector3:
	# Phòng thủ nếu bất kỳ container nào bị null
	if not decorations_container:
		decorations_container = Node3D.new()
		decorations_container.name = "DecorationsContainer"
		if tiles_container and tiles_container.get_parent():
			tiles_container.get_parent().add_child(decorations_container)

	# 1. Nạp preset cấu hình chuẩn hoặc khởi tạo mới
	var config: MapGenConfig = null
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		config = load(DEFAULT_CONFIG_PATH) as MapGenConfig
	if config == null:
		config = MapGenConfig.new()
		
	# 2. Khởi tạo Context và chạy liên hoàn 16 bước phát sinh Procedural
	var context: MapGenContext = MapGenContext.new(config)
	MacroLayoutGenerator.generate(context, config)
	TerraceGenerator.generate(context, config)
	RiverGenerator.generate(context, config)
	POIAndRoadGenerator.generate(context, config)
	FoliageGenerator.generate(context, config)
	
	# 3. Kết xuất sa bàn 3D qua DioramaRenderer
	var temp_root: Node3D = Node3D.new()
	var render_result: Dictionary = DioramaRenderer.render_diorama(temp_root, context, config)
	
	# 4. Phân bổ các node đã sinh vào các container đích tương thích ngược
	# Bedrock, Landscape, Cliffs, Foliage -> decorations_container
	var bedrock_node = render_result.get("bedrock", null)
	if bedrock_node != null and bedrock_node.get_parent() != null:
		bedrock_node.get_parent().remove_child(bedrock_node)
		decorations_container.add_child(bedrock_node)
		
	_move_container_children(render_result.get("landscape_container", null), decorations_container)
	_move_container_children(render_result.get("cliffs_container", null), decorations_container)
	_move_container_children(render_result.get("foliage_container", null), decorations_container)
	
	# Tiles -> tiles_container
	_move_container_children(render_result.get("tiles_container", null), tiles_container)
	
	# Obstacles -> obstacles_container
	_move_container_children(render_result.get("obstacles_container", null), obstacles_container)
	
	# POI -> Tách Lâu Đài vào buildings_container, còn lại vào decorations_container
	var poi_cnt = render_result.get("poi_container", null)
	if poi_cnt != null:
		for child in poi_cnt.get_children():
			poi_cnt.remove_child(child)
			if child is BuildingEntity:
				buildings_container.add_child(child)
			else:
				decorations_container.add_child(child)
				
	temp_root.free()
	
	# 5. Đồng bộ hóa dữ liệu sang GridSystem
	if grid_system != null:
		grid_system.sync_from_map_context(context, config)
		for child in tiles_container.get_children():
			if child is TerrainTile:
				var tt: TerrainTile = child as TerrainTile
				grid_system.register_tile(tt.grid_coord, tt, tt.is_buildable)
		for child in obstacles_container.get_children():
			if child is ResourceNode:
				var rn: ResourceNode = child as ResourceNode
				grid_system.register_obstacle(rn.grid_coord, rn)
		for child in buildings_container.get_children():
			if child is BuildingEntity:
				var be: BuildingEntity = child as BuildingEntity
				grid_system.register_building(be.grid_coord, be)
				
	# Trả về tọa độ thế giới của Lâu Đài
	var castle_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.CASTLE)
	if castle_coord == Vector2i(-1, -1):
		castle_coord = config.playable_origin + Vector2i(9, 9)
	var castle_y: float = context.get_world_y_for_cell(castle_coord.x, castle_coord.y)
	return context.grid_to_world(castle_coord, castle_y)

## Tiện ích chuyển các node con từ container nguồn sang đích
static func _move_container_children(src_container: Node, dst_container: Node) -> void:
	if src_container == null or dst_container == null:
		return
	for child in src_container.get_children():
		src_container.remove_child(child)
		dst_container.add_child(child)
