class_name KingdomMapBuilder
extends RefCounted

## Trình Xây dựng Bản đồ Sa bàn Khổng lồ (Grand Base Diorama Map Builder)
## Lắp ráp thế giới 52x52 ô (104m x 104m) với 4 phân vùng tự nhiên chuẩn Kingdom's Deck

# Packed Scenes cốt lõi
const TERRAIN_TILE_SCENE = preload("res://scenes/entities/terrain_tile.tscn")
const RESOURCE_NODE_SCENE = preload("res://scenes/entities/resource_node.tscn")
const BUILDING_ENTITY_SCENE = preload("res://scenes/entities/building_entity.tscn")

# Models Địa hình & Thiên nhiên
const MESH_SQUARE_FOREST = preload("res://assets/models/tiles/square/square_forest.glb")
const MESH_SQUARE_WATER = preload("res://assets/models/tiles/square/square_water.glb")
const MESH_WATER_STRAIGHT = preload("res://assets/models/tiles/square/square_forest_waterStraight.glb")
const MESH_MOUNTAIN = preload("res://assets/models/buildings/mountain.glb")
const MESH_FOREST_CLUSTER = preload("res://assets/models/buildings/forest.glb")
const MESH_DETAIL_FOREST = preload("res://assets/models/buildings/detail_forestA.glb")

# Models Cây, Đá, Lâu đài & Quái vật
const MESH_TREE_1 = preload("res://assets/models/forest/trees/Tree_1_A_Color1.gltf")
const MESH_TREE_2 = preload("res://assets/models/forest/trees/Tree_2_A_Color1.gltf")
const MESH_TREE_BARE = preload("res://assets/models/forest/trees/Tree_Bare_1_A_Color1.gltf")
const MESH_ROCK_LARGE = preload("res://assets/models/forest/rocks/Rock_1_A_Color1.gltf")
const MESH_ROCK_MED = preload("res://assets/models/forest/rocks/Rock_2_A_Color1.gltf")
const MESH_CASTLE = preload("res://assets/models/buildings/castle.glb")

# Skeletons
const MESH_SKEL_WARRIOR = preload("res://assets/models/enemies/characters/character_skeleton_warrior.gltf")
const MESH_SKEL_ARCHER = preload("res://assets/models/enemies/characters/character_skeleton_archer.gltf")

# Quy mô bản đồ
const WORLD_TILES: Vector2i = Vector2i(52, 52)
const GRID_START: Vector2i = Vector2i(8, 8)
const GRID_SIZE: Vector2i = Vector2i(32, 32)
const CELL_SIZE: float = 2.0

## Hàm chính xây dựng toàn bộ bản đồ sa bàn
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

	# Cấu hình grid system
	grid_system.grid_size = GRID_SIZE
	grid_system.cell_size = CELL_SIZE
	grid_system.grid_origin = Vector3(GRID_START.x * CELL_SIZE, 0.0, GRID_START.y * CELL_SIZE)
	grid_system.initialize_grid()
	
	# 1. Sinh mặt sàn địa hình & Sông suối (Zone 1 & 2)
	_build_terrain_tiles(grid_system, tiles_container)
	
	# 2. Xây dựng Dãy núi Tây Bắc (Zone 1)
	_build_mountains(decorations_container)
	
	# 3. Trồng Vành đai Rừng sâu Sinh quái ở phía Nam & Đông (Zone 4)
	_build_outer_forests(decorations_container)
	
	# 4. Đặt Lâu đài thủ phủ ở trung tâm (Zone 2)
	var castle_coord = Vector2i(16, 16) # Tọa độ logic trong lưới 32x32
	var castle_world_pos = _place_castle(grid_system, buildings_container, castle_coord)
	
	# 5. Phân bổ các cụm rừng tài nguyên & mỏ đá nội địa (Zone 2)
	_build_internal_resources(grid_system, obstacles_container)
	
	# 6. Bố trí các trinh sát quái vật rình rập ở bìa rừng (Zone 4)
	_spawn_skeleton_scouts(decorations_container)
	
	return castle_world_pos

## 1. Sinh các Tile địa hình (Sông Tây + Lưới Đất Trung Tâm)
static func _build_terrain_tiles(grid_system: GridSystem, container: Node3D) -> void:
	for x in range(WORLD_TILES.x):
		for y in range(WORLD_TILES.y):
			var world_x = float(x) * CELL_SIZE
			var world_z = float(y) * CELL_SIZE
			var tile_pos = Vector3(world_x, 0.0, world_z)
			
			# Kiểm tra xem ô này có thuộc Lưới Xây dựng Vương quốc (32x32) không
			var in_playable_grid = (
				x >= GRID_START.x and x < GRID_START.x + GRID_SIZE.x and
				y >= GRID_START.y and y < GRID_START.y + GRID_SIZE.y
			)
			
			# Dòng sông lớn chạy dọc ở cột x = 3..5 với khúc uốn lượn nhẹ
			var river_center = 4.0 + sin(float(y) * 0.2) * 1.2
			var dist_to_river = abs(float(x) - river_center)
			
			if dist_to_river < 1.1:
				# Lòng sông chính (Nước sâu)
				var water_tile = _create_static_tile(MESH_SQUARE_WATER, tile_pos + Vector3(0, -0.3, 0))
				container.add_child(water_tile)
			elif dist_to_river < 1.9:
				# Bờ sông dốc thoai thoải
				var bank_rot = 0.0 if float(x) > river_center else PI
				var bank_tile = _create_static_tile(MESH_WATER_STRAIGHT, tile_pos, bank_rot)
				container.add_child(bank_tile)
			else:
				# Mặt đất cỏ (Grass plain)
				if in_playable_grid:
					# Ô trong khu vực xây dựng -> Dùng TerrainTile có Collider & Highlight
					var local_coord = Vector2i(x - GRID_START.x, y - GRID_START.y)
					var p_tile: TerrainTile = TERRAIN_TILE_SCENE.instantiate()
					p_tile.grid_coord = local_coord
					p_tile.tile_type = TerrainTile.TileType.GRASS
					p_tile.custom_model_scene = MESH_SQUARE_FOREST
					p_tile.position = tile_pos
					container.add_child(p_tile)
					grid_system.register_tile(local_coord, p_tile, true)
				else:
					# Ô ngoại vi ngoài rìa -> Dùng Tile tĩnh để siêu nhẹ CPU/GPU
					var bg_tile = _create_static_tile(MESH_SQUARE_FOREST, tile_pos)
					container.add_child(bg_tile)

## Tạo Tile tĩnh cho cảnh quan ngoài rìa (không tốn Area3D collider)
static func _create_static_tile(mesh_scene: PackedScene, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var node = Node3D.new()
	node.position = pos
	node.rotation.y = rot_y
	var instance = mesh_scene.instantiate()
	node.add_child(instance)
	return node

## 2. Dãy Núi Đá Tây Bắc (Chặn rìa an toàn)
static func _build_mountains(container: Node3D) -> void:
	# Núi lớn ở góc trên cùng bên trái (Tây Bắc)
	var mountain_spots = [
		Vector3(2.0, 0.0, 2.0), Vector3(2.0, 0.0, 6.0), Vector3(2.0, 0.0, 10.0),
		Vector3(4.0, 0.0, 2.0), Vector3(8.0, 0.0, 2.0), Vector3(12.0, 0.0, 2.0),
		Vector3(16.0, 0.0, 2.0), Vector3(20.0, 0.0, 2.0)
	]
	for p in mountain_spots:
		var m = MESH_MOUNTAIN.instantiate()
		m.position = p
		m.scale = Vector3(1.6, 1.8, 1.6)
		container.add_child(m)
		
	# Tảng đá lởm chởm ở chân núi
	var rock_spots = [
		Vector3(4.0, 1.0, 8.0), Vector3(6.0, 1.0, 4.0), Vector3(10.0, 1.0, 5.0),
		Vector3(14.0, 1.0, 4.5), Vector3(2.0, 1.0, 14.0)
	]
	for rp in rock_spots:
		var r = MESH_ROCK_LARGE.instantiate()
		r.position = rp
		r.rotation_degrees.y = randf_range(0, 360)
		r.scale = Vector3.ONE * randf_range(1.2, 1.8)
		container.add_child(r)

## 3. Vành đai Rừng rậm Sinh quái ở rìa Nam & Đông
static func _build_outer_forests(container: Node3D) -> void:
	# Mép Nam (Y = 46..51)
	for x in range(0, WORLD_TILES.x, 3):
		for y in range(46, WORLD_TILES.y, 2):
			var pos = Vector3(float(x) * CELL_SIZE + randf_range(-1.0, 1.0), 1.0, float(y) * CELL_SIZE + randf_range(-0.5, 0.5))
			if randf() > 0.4:
				var f = MESH_FOREST_CLUSTER.instantiate()
				f.position = pos
				f.scale = Vector3.ONE * randf_range(1.0, 1.3)
				container.add_child(f)
			else:
				var t = MESH_TREE_1.instantiate()
				t.position = pos
				t.scale = Vector3.ONE * randf_range(1.2, 1.6)
				container.add_child(t)
				
	# Mép Đông (X = 46..51)
	for y in range(0, 46, 3):
		for x in range(46, WORLD_TILES.x, 2):
			var pos = Vector3(float(x) * CELL_SIZE + randf_range(-0.5, 0.5), 1.0, float(y) * CELL_SIZE + randf_range(-1.0, 1.0))
			var f = MESH_DETAIL_FOREST.instantiate()
			f.position = pos
			f.scale = Vector3.ONE * randf_range(0.9, 1.2)
			container.add_child(f)

## 4. Đặt Lâu đài thủ phủ ở trung tâm
static func _place_castle(grid_system: GridSystem, container: Node3D, coord: Vector2i) -> Vector3:
	var castle: BuildingEntity = BUILDING_ENTITY_SCENE.instantiate()
	castle.grid_coord = coord
	castle.custom_model_scene = MESH_CASTLE
	var world_pos = grid_system.grid_to_world(coord, 1.0)
	castle.position = world_pos
	container.add_child(castle)
	grid_system.register_building(coord, castle)
	return world_pos

## 5. Phân bổ Cụm Rừng Tài nguyên & Mỏ đá bên trong lưới xây dựng
static func _build_internal_resources(grid_system: GridSystem, container: Node3D) -> void:
	# 4 cụm rừng nhỏ tự nhiên để lãnh chúa chặt lấy gỗ ban đầu
	var tree_clusters = [
		# Cụm 1: Hướng Tây Nam (gần bờ sông)
		[Vector2i(6, 12), Vector2i(7, 12), Vector2i(6, 13), Vector2i(7, 13), Vector2i(8, 12)],
		# Cụm 2: Hướng Đông Bắc
		[Vector2i(22, 6), Vector2i(23, 6), Vector2i(22, 7), Vector2i(23, 7), Vector2i(24, 6)],
		# Cụm 3: Hướng Đông Nam (gần chiến tuyến)
		[Vector2i(25, 24), Vector2i(26, 24), Vector2i(25, 25), Vector2i(26, 25)],
		# Cụm 4: Hướng Tây Bắc (phía sau thủ phủ)
		[Vector2i(10, 6), Vector2i(11, 6), Vector2i(11, 7)]
	]
	
	for cluster in tree_clusters:
		for tc in cluster:
			var tree: ResourceNode = RESOURCE_NODE_SCENE.instantiate()
			tree.grid_coord = tc
			tree.node_type = ResourceNode.NodeType.TREE
			tree.resource_name = "wood"
			tree.current_resource_amount = 6
			tree.custom_model_scene = MESH_TREE_1 if randf() > 0.4 else MESH_TREE_2
			tree.position = grid_system.grid_to_world(tc, 1.0)
			container.add_child(tree)
			grid_system.register_obstacle(tc, tree)
			
	# 2 mỏ đá tự nhiên
	var rock_spots = [Vector2i(4, 4), Vector2i(18, 4), Vector2i(28, 10)]
	for rc in rock_spots:
		var rock: ResourceNode = RESOURCE_NODE_SCENE.instantiate()
		rock.grid_coord = rc
		rock.node_type = ResourceNode.NodeType.ROCK_QUARRY
		rock.resource_name = "stone"
		rock.current_resource_amount = 15
		rock.custom_model_scene = MESH_ROCK_MED
		rock.position = grid_system.grid_to_world(rc, 1.0)
		container.add_child(rock)
		grid_system.register_obstacle(rc, rock)

## 6. Đặt các trinh sát Skeleton đứng canh gác ở mép rừng sâu
static func _spawn_skeleton_scouts(container: Node3D) -> void:
	var scout_positions = [
		Vector3(48.0, 1.0, 92.0),
		Vector3(52.0, 1.0, 93.0),
		Vector3(70.0, 1.0, 94.0),
		Vector3(92.0, 1.0, 65.0),
		Vector3(93.0, 1.0, 75.0)
	]
	for sp in scout_positions:
		var scout = (MESH_SKEL_WARRIOR if randf() > 0.5 else MESH_SKEL_ARCHER).instantiate()
		scout.position = sp
		scout.rotation_degrees.y = randf_range(180, 270)
		container.add_child(scout)
