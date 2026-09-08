@tool
class_name DioramaRenderer
extends RefCounted

## Trình Kết Xuất Sa Bàn 3D Toàn Diện (Procedural Diorama 3D Renderer)
## Thuộc Phân hệ 06 (Tooling & Performance) và hoàn tất Bước 16 của Pipeline.
## Xây dựng khối chân đế nổi vững chãi (Bedrock Pedestal), phân tách ô đất tương tác (20x20)
## và ô cảnh quan ngoại vi, khâu vách đá 3D xóa sổ khe hở, bố trí POIs và tích hợp GPU MultiMesh.

# Packed Scenes cốt lõi
const TERRAIN_TILE_SCENE = preload("res://scenes/entities/terrain_tile.tscn")
const RESOURCE_NODE_SCENE = preload("res://scenes/entities/resource_node.tscn")
const BUILDING_ENTITY_SCENE = preload("res://scenes/entities/building_entity.tscn")

# Models Địa hình & Cảnh quan
const MESH_SQUARE_FOREST = preload("res://assets/models/tiles/square/square_forest.glb")
const MESH_SQUARE_FOREST_DETAIL = preload("res://assets/models/tiles/square/square_forest_detail.glb")
const MESH_SQUARE_WATER = preload("res://assets/models/tiles/square/square_water.glb")
const MESH_WATER_STRAIGHT = preload("res://assets/models/tiles/square/square_forest_waterStraight.glb")
const MESH_ROAD_STRAIGHT = preload("res://assets/models/tiles/square/square_forest_roadA.glb")
const MESH_ROAD_CORNER = preload("res://assets/models/tiles/square/square_forest_roadB.glb")
const MESH_ROAD_TEE = preload("res://assets/models/tiles/square/square_forest_roadC.glb")

# Models Vách đá & Công trình
const MESH_WALL_STRAIGHT = preload("res://assets/models/buildings/wall_straight.glb")
const MESH_BRIDGE_ROOFED = preload("res://assets/models/buildings/bridge_roofed.glb")
const MESH_WATERMILL = preload("res://assets/models/buildings/watermill.glb")
const MESH_CASTLE = preload("res://assets/models/buildings/castle.glb")
const MESH_HILL = preload("res://assets/models/buildings/detail_hill.glb")
const MESH_WATCHTOWER = preload("res://assets/models/buildings/watchtower.glb")

# Models Tài nguyên & Quái vật
const MESH_TREE_1 = preload("res://assets/models/forest/trees/Tree_1_A_Color1.gltf")
const MESH_TREE_2 = preload("res://assets/models/forest/trees/Tree_2_A_Color1.gltf")
const MESH_ROCK_MED = preload("res://assets/models/forest/rocks/Rock_2_A_Color1.gltf")
const MESH_SKEL_WARRIOR = preload("res://assets/models/enemies/characters/character_skeleton_warrior.gltf")
const MESH_SKEL_ARCHER = preload("res://assets/models/enemies/characters/character_skeleton_archer.gltf")

# ------------------------------------------------------------------------------
# 1. Điểm Đầu Vào Chính (Main Rendering Entry Point)
# ------------------------------------------------------------------------------

## Kết xuất toàn bộ sa bàn 3D hoàn chỉnh vào root node
static func render_diorama(
	root_node: Node3D,
	context: MapGenContext,
	config: MapGenConfig
) -> Dictionary:
	if root_node == null or context == null or config == null:
		push_error("DioramaRenderer.render_diorama(): Tham số truyền vào có giá trị null!")
		return {}
		
	# Dọn dẹp các node cũ nếu đã tồn tại
	for child in root_node.get_children():
		child.queue_free()
		
	# Khởi tạo các Container phân loại chuyên biệt
	var bedrock_container: Node3D = Node3D.new()
	bedrock_container.name = "BedrockContainer"
	root_node.add_child(bedrock_container)
	
	var tiles_container: Node3D = Node3D.new()
	tiles_container.name = "TilesContainer"
	root_node.add_child(tiles_container)
	
	var landscape_container: Node3D = Node3D.new()
	landscape_container.name = "LandscapeContainer"
	root_node.add_child(landscape_container)
	
	var cliffs_container: Node3D = Node3D.new()
	cliffs_container.name = "CliffsContainer"
	root_node.add_child(cliffs_container)
	
	var poi_container: Node3D = Node3D.new()
	poi_container.name = "POIStructures"
	root_node.add_child(poi_container)
	
	var obstacles_container: Node3D = Node3D.new()
	obstacles_container.name = "ObstaclesContainer"
	root_node.add_child(obstacles_container)
	
	var foliage_container: Node3D = Node3D.new()
	foliage_container.name = "FoliageMultiMesh"
	root_node.add_child(foliage_container)
	
	# Task 7.2: Dựng Khối Chân Đế Sa Bàn Nổi (Solid Bedrock Pedestal)
	var bedrock_node: MeshInstance3D = build_bedrock(bedrock_container, context)
	
	# Task 7.3: Render Các Ô Đất Gameplay (20x20) & Ô Cảnh Quan Ngoại Vi
	build_terrain_tiles(tiles_container, landscape_container, context, config)
	
	# Task 7.4: Thuật toán Khâu Vách Đá 3D (Cliff Mesh Stitching)
	build_cliffs(cliffs_container, context)
	
	# Task 7.5: Đặt Các Công Trình Cốt Lõi, Cầu Qua Sông, Tài Nguyên & Quái Vật
	build_pois_and_structures(poi_container, obstacles_container, context, config)
	
	# Task 7.1: Nạp Thảm Thực Vật & Đá vào GPU MultiMesh
	MultiMeshScatterManager.build_multimeshes(foliage_container, context)
	
	return {
		"bedrock": bedrock_node,
		"tiles_container": tiles_container,
		"landscape_container": landscape_container,
		"cliffs_container": cliffs_container,
		"poi_container": poi_container,
		"obstacles_container": obstacles_container,
		"foliage_container": foliage_container
	}

# ------------------------------------------------------------------------------
# 2. Task 7.2: Dựng Khối Chân Đế Sa Bàn Nổi (Solid Bedrock Pedestal)
# ------------------------------------------------------------------------------

static func build_bedrock(container: Node3D, context: MapGenContext) -> MeshInstance3D:
	var total_w: float = float(context.width) * context.cell_size
	var total_d: float = float(context.height) * context.cell_size
	var depth: float = MapGenConstants.BEDROCK_DEPTH
	
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "DioramaBedrock"
	
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(total_w, depth, total_d)
	mesh_inst.mesh = box_mesh
	
	# Tâm đặt tại giữa sa bàn, dìm xuống dưới để mặt trên tiếp xúc chính xác Y = 0.0m
	mesh_inst.position = Vector3(total_w * 0.5, -depth * 0.5, total_d * 0.5)
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = MapGenConstants.BEDROCK_COLOR # Color(0.20, 0.17, 0.15)
	mat.roughness = MapGenConstants.BEDROCK_ROUGHNESS # 0.95
	mesh_inst.material_override = mat
	
	container.add_child(mesh_inst)
	return mesh_inst

# ------------------------------------------------------------------------------
# 3. Task 7.3: Render Các Ô Đất Gameplay & Ô Cảnh Quan Ngoại Vi
# ------------------------------------------------------------------------------

static func build_terrain_tiles(
	tiles_container: Node3D,
	landscape_container: Node3D,
	context: MapGenContext,
	config: MapGenConfig
) -> void:
	var p_orig: Vector2i = config.playable_origin
	var p_size: Vector2i = config.playable_grid_size
	
	for y in range(context.height):
		for x in range(context.width):
			var idx: int = context.get_index(x, y)
			var world_y: float = context.get_world_y_for_cell(x, y)
			var tile_pos: Vector3 = context.grid_to_world(Vector2i(x, y), world_y)
			
			var in_playable: bool = (
				x >= p_orig.x and x < p_orig.x + p_size.x and
				y >= p_orig.y and y < p_orig.y + p_size.y
			)
			
			if in_playable:
				var local_coord: Vector2i = Vector2i(x - p_orig.x, y - p_orig.y)
				var p_tile: TerrainTile = TERRAIN_TILE_SCENE.instantiate() as TerrainTile
				p_tile.name = "Tile_%d_%d" % [local_coord.x, local_coord.y]
				p_tile.grid_coord = local_coord
				p_tile.position = tile_pos
				
				# Kiểm tra nếu ô cờ nằm trên mạng lưới đường mòn
				var coord_2d: Vector2i = Vector2i(x, y)
				if context.road_nodes.has(coord_2d):
					var road_info: Dictionary = context.road_nodes[coord_2d]
					p_tile.tile_type = TerrainTile.TileType.ROAD
					p_tile.is_buildable = false
					
					var node_type = road_info.get("node_type", MapGenConstants.RoadNodeType.STRAIGHT)
					if node_type == MapGenConstants.RoadNodeType.TEE:
						p_tile.custom_model_scene = MESH_ROAD_TEE
					elif node_type == MapGenConstants.RoadNodeType.CORNER:
						p_tile.custom_model_scene = MESH_ROAD_CORNER
					else:
						p_tile.custom_model_scene = MESH_ROAD_STRAIGHT
						
					p_tile.rotation.y = road_info.get("rotation_y", 0.0)
				else:
					p_tile.tile_type = TerrainTile.TileType.GRASS
					p_tile.is_buildable = context.is_buildable(x, y)
					
					# Hàm băm xác định hoa dại / chi tiết cỏ (35% có hoa cỏ, 65% cỏ xanh mướt)
					var hash_val: int = ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF
					if (hash_val % 100) < 35:
						p_tile.custom_model_scene = MESH_SQUARE_FOREST_DETAIL
					else:
						p_tile.custom_model_scene = MESH_SQUARE_FOREST
						
				tiles_container.add_child(p_tile)
			else:
				# Vùng ngoài lưới: Cảnh quan ngoại vi (Static Tiles)
				var water_zone: int = context.get_water_zone(x, y)
				if water_zone == MapGenConstants.WaterZone.WATER:
					# Lòng sông sâu: Y = -0.7m
					var water_pos: Vector3 = Vector3(tile_pos.x, -0.7, tile_pos.z)
					var water_tile: Node3D = _create_static_tile(MESH_SQUARE_WATER, water_pos)
					landscape_container.add_child(water_tile)
				elif water_zone == MapGenConstants.WaterZone.BANK:
					# Bờ kè dốc nghiêng theo góc xoay đã tính ở Phase 04
					var bank_rot: float = context.bank_rotations[idx]
					var bank_tile: Node3D = _create_static_tile(MESH_WATER_STRAIGHT, tile_pos, bank_rot)
					landscape_container.add_child(bank_tile)
				elif context.road_nodes.has(Vector2i(x, y)):
					# Đoạn đường mòn ngoại vi nối từ ranh giới lưới tới cầu vượt sông
					var road_info: Dictionary = context.road_nodes[Vector2i(x, y)]
					var road_rot: float = road_info.get("rotation_y", 0.0)
					var road_tile: Node3D = _create_static_tile(MESH_ROAD_STRAIGHT, tile_pos, road_rot)
					landscape_container.add_child(road_tile)
				else:
					# Ô cỏ cảnh quan biên
					var bg_hash: int = ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF
					var bg_scene: PackedScene = MESH_SQUARE_FOREST_DETAIL if ((bg_hash % 100) < 30) else MESH_SQUARE_FOREST
					var bg_tile: Node3D = _create_static_tile(bg_scene, tile_pos)
					landscape_container.add_child(bg_tile)

## Tiện ích tạo node tĩnh cho cảnh quan
static func _create_static_tile(mesh_scene: PackedScene, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = pos
	node.rotation.y = rot_y
	var inst: Node = mesh_scene.instantiate()
	node.add_child(inst)
	return node

# ------------------------------------------------------------------------------
# 4. Task 7.4: Thuật Toán Khâu Vách Đá 3D (Cliff Mesh Stitching)
# ------------------------------------------------------------------------------

static func build_cliffs(cliffs_container: Node3D, context: MapGenContext) -> void:
	var cell_size: float = context.cell_size
	var neighbor_dirs: Array[Vector2i] = MapGenConstants.NEIGHBOR_OFFSETS_4
	
	# Model wall_straight.glb có chiều dài theo X = 2.0m, chiều cao H0 ≈ 1.1524m
	const WALL_BASE_HEIGHT: float = 1.1524
	
	for spec in context.cliff_specs:
		var coord: Vector2i = spec.get("coord", spec.get("cell", Vector2i.ZERO))
		var face: int = spec.get("face", spec.get("direction_idx", 0))
		var from_lvl: int = spec.get("from_level", 2)
		var to_lvl: int = spec.get("to_level", 0)
		var delta_steps: int = spec.get("height_steps", spec.get("step_difference", 1))
		
		if face < 0 or face >= neighbor_dirs.size():
			continue
			
		var dir: Vector2i = neighbor_dirs[face]
		var y_upper: float = MapGenConstants.ELEVATION_Y_OFFSETS.get(from_lvl, 0.5)
		var y_lower: float = MapGenConstants.ELEVATION_Y_OFFSETS.get(to_lvl, 0.0)
		var delta_h: float = y_upper - y_lower
		
		# Tọa độ ranh giới giữa 2 ô cờ (Seam position)
		var seam_x: float = (float(coord.x) + 0.5 * float(dir.x)) * cell_size
		var seam_z: float = (float(coord.y) + 0.5 * float(dir.y)) * cell_size
		var seam_pos: Vector3 = Vector3(seam_x, y_lower, seam_z)
		
		# Góc xoay mặt vách hướng về phía ô đất thấp
		var rot_y: float = 0.0
		match face:
			MapGenConstants.CliffFace.NORTH: # Hướng Bắc (dy = -1)
				rot_y = 0.0
			MapGenConstants.CliffFace.EAST:  # Hướng Đông (dx = +1)
				rot_y = PI * 0.5
			MapGenConstants.CliffFace.SOUTH: # Hướng Nam (dy = +1)
				rot_y = PI
			MapGenConstants.CliffFace.WEST:  # Hướng Tây (dx = -1)
				rot_y = -PI * 0.5
				
		# Tỷ lệ co giãn trục Y theo chiều cao bậc
		var scale_y: float = maxf(0.4, delta_h / WALL_BASE_HEIGHT)
		
		var wall_inst: Node3D = MESH_WALL_STRAIGHT.instantiate() as Node3D
		wall_inst.position = seam_pos
		wall_inst.rotation.y = rot_y
		wall_inst.scale = Vector3(1.0, scale_y, 1.0)
		cliffs_container.add_child(wall_inst)

# ------------------------------------------------------------------------------
# 5. Task 7.5: Đặt Các Công Trình Cốt Lõi, Cầu Qua Sông, Tài Nguyên & Quái Vật
# ------------------------------------------------------------------------------

static func build_pois_and_structures(
	poi_container: Node3D,
	obstacles_container: Node3D,
	context: MapGenContext,
	config: MapGenConfig
) -> void:
	var cell_size: float = context.cell_size
	
	# 1. Cầu Gỗ Mái Che Vượt Sông
	var bridge_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.BRIDGE)
	if bridge_coord == Vector2i(-1, -1):
		bridge_coord = Vector2i(int(round(config.river_bridge_x)), config.playable_origin.y + 9)
		
	var bridge = MESH_BRIDGE_ROOFED.instantiate() as Node3D
	bridge.name = "RoofedBridge"
	bridge.position = Vector3(float(bridge_coord.x) * cell_size, 0.0, float(bridge_coord.y) * cell_size)
	bridge.rotation_degrees.y = 90.0 # Xoay ngang bắc bờ Tây sang bờ Đông
	bridge.scale = Vector3(1.15, 1.15, 1.15)
	poi_container.add_child(bridge)
	
	# 2. Cối Xay Nước Bờ Đông (X = bridge.x + 1, Y = bridge.y - 1)
	var watermill = MESH_WATERMILL.instantiate() as Node3D
	watermill.name = "RiverWatermill"
	watermill.position = Vector3(float(bridge_coord.x + 1) * cell_size + 0.3, 0.0, float(bridge_coord.y - 1) * cell_size)
	watermill.rotation_degrees.y = -90.0
	watermill.scale = Vector3(1.2, 1.2, 1.2)
	poi_container.add_child(watermill)
	
	# 3. Đại Bản Doanh Lâu Đài (Scale 2.4x ngự trên Gò Đất Hoàng Gia)
	var castle_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.CASTLE)
	if castle_coord == Vector2i(-1, -1):
		castle_coord = config.playable_origin + Vector2i(9, 9)
		
	var castle_world_y: float = context.get_world_y_for_cell(castle_coord.x, castle_coord.y)
	var castle_pos: Vector3 = context.grid_to_world(castle_coord, castle_world_y)
	
	# Bệ gò đồi hoàng gia
	var hill = MESH_HILL.instantiate() as Node3D
	hill.name = "CastleRoyalHill"
	hill.position = castle_pos + Vector3(0, 0.05, 0)
	hill.scale = Vector3(2.8, 0.65, 2.8)
	poi_container.add_child(hill)
	
	# 2 Tháp canh đá kiên cố phía sau Lâu Đài
	var tower_left = MESH_WATCHTOWER.instantiate() as Node3D
	tower_left.position = castle_pos + Vector3(-2.8, 0.35, -2.5)
	tower_left.scale = Vector3(1.2, 1.2, 1.2)
	poi_container.add_child(tower_left)
	
	var tower_right = MESH_WATCHTOWER.instantiate() as Node3D
	tower_right.position = castle_pos + Vector3(2.8, 0.35, -2.5)
	tower_right.scale = Vector3(1.2, 1.2, 1.2)
	poi_container.add_child(tower_right)
	
	var p_orig: Vector2i = config.playable_origin
	
	# Thực thể Lâu Đài chính
	var castle: BuildingEntity = BUILDING_ENTITY_SCENE.instantiate() as BuildingEntity
	castle.name = "GrandCastle"
	castle.grid_coord = castle_coord - p_orig
	castle.custom_model_scene = MESH_CASTLE
	castle.position = castle_pos + Vector3(0, 0.45, 0)
	castle.scale = Vector3(2.4, 2.4, 2.4)
	poi_container.add_child(castle)
	
	# 4. Mỏ Đá Tự Nhiên (3 mỏ đá)
	var quarry_coords = context.poi_registry.get("quarry_coords", [])
	if quarry_coords.is_empty():
		quarry_coords = context.poi_registry.get(MapGenConstants.POIType.QUARRY, [])
		
	for i in range(quarry_coords.size()):
		var qc: Vector2i = quarry_coords[i]
		var rock_node: ResourceNode = RESOURCE_NODE_SCENE.instantiate() as ResourceNode
		rock_node.name = "Quarry_%d" % i
		rock_node.grid_coord = qc - p_orig
		rock_node.node_type = ResourceNode.NodeType.ROCK_QUARRY
		rock_node.resource_name = "stone"
		rock_node.current_resource_amount = 15
		rock_node.custom_model_scene = MESH_ROCK_MED
		rock_node.position = context.grid_to_world(qc, context.get_world_y_for_cell(qc.x, qc.y))
		obstacles_container.add_child(rock_node)
		
	# 5. Cụm Rừng Gỗ Khai Thác (4 cụm)
	var lumber_coords = context.poi_registry.get("forest_clusters", [])
	if lumber_coords.is_empty():
		lumber_coords = context.poi_registry.get(MapGenConstants.POIType.LUMBER, [])
		
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = config.seed + 707
	
	for i in range(lumber_coords.size()):
		var lc: Vector2i = lumber_coords[i]
		var tree_node: ResourceNode = RESOURCE_NODE_SCENE.instantiate() as ResourceNode
		tree_node.name = "LumberTree_%d" % i
		tree_node.grid_coord = lc - p_orig
		tree_node.node_type = ResourceNode.NodeType.TREE
		tree_node.resource_name = "wood"
		tree_node.current_resource_amount = 6
		tree_node.custom_model_scene = MESH_TREE_1 if rng.randf() > 0.4 else MESH_TREE_2
		tree_node.position = context.grid_to_world(lc, context.get_world_y_for_cell(lc.x, lc.y))
		obstacles_container.add_child(tree_node)
		
	# 6. Trinh Sát Skeleton Canh Gác Mép Rừng Sâu (5 vị trí)
	var scout_coords = context.poi_registry.get("scout_coords", [])
	if scout_coords.is_empty():
		scout_coords = context.poi_registry.get(MapGenConstants.POIType.SCOUT, [])
		
	for i in range(scout_coords.size()):
		var sc: Vector2i = scout_coords[i]
		var scout_inst: Node3D = (MESH_SKEL_WARRIOR.instantiate() if (i % 2 == 0) else MESH_SKEL_ARCHER.instantiate()) as Node3D
		scout_inst.name = "SkeletonScout_%d" % i
		var scout_pos: Vector3 = context.grid_to_world(sc, context.get_world_y_for_cell(sc.x, sc.y))
		scout_inst.position = scout_pos
		
		# Quay mặt hướng về phía trung tâm vương quốc (Lâu Đài)
		var dir_to_center: Vector3 = (castle_pos - scout_pos).normalized()
		scout_inst.rotation.y = atan2(dir_to_center.x, dir_to_center.z)
		scout_inst.scale = Vector3(1.1, 1.1, 1.1)
		poi_container.add_child(scout_inst)
