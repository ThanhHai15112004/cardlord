class_name KingdomMapBuilder
extends RefCounted

## Trình Xây dựng Bản đồ Sa bàn Đẳng cấp (Grand Base Diorama Map Builder)
## Kiến trúc phân tầng 4 lớp (Verticality), Khối Chân Đế Nổi (Solid Bedrock Pedestal),
## Cầu qua sông, Cối xay nước, Lâu đài thủ phủ uy nghiêm (Scale 2.4x) và Tuyến đường mòn chuẩn Kingdom's Deck.

# Packed Scenes cốt lõi
const TERRAIN_TILE_SCENE = preload("res://scenes/entities/terrain_tile.tscn")
const RESOURCE_NODE_SCENE = preload("res://scenes/entities/resource_node.tscn")
const BUILDING_ENTITY_SCENE = preload("res://scenes/entities/building_entity.tscn")

# Models Địa hình & Thiên nhiên
const MESH_SQUARE_FOREST = preload("res://assets/models/tiles/square/square_forest.glb")
const MESH_SQUARE_FOREST_DETAIL = preload("res://assets/models/tiles/square/square_forest_detail.glb")
const MESH_SQUARE_WATER = preload("res://assets/models/tiles/square/square_water.glb")
const MESH_WATER_STRAIGHT = preload("res://assets/models/tiles/square/square_forest_waterStraight.glb")
const MESH_ROAD_STRAIGHT = preload("res://assets/models/tiles/square/square_forest_roadA.glb")
const MESH_ROAD_TEE = preload("res://assets/models/tiles/square/square_forest_roadC.glb")

# Models Cảnh quan & Công trình
const MESH_MOUNTAIN = preload("res://assets/models/buildings/mountain.glb")
const MESH_HILL = preload("res://assets/models/buildings/detail_hill.glb")
const MESH_FOREST_CLUSTER = preload("res://assets/models/buildings/forest.glb")
const MESH_DETAIL_FOREST = preload("res://assets/models/buildings/detail_forestA.glb")
const MESH_BRIDGE_ROOFED = preload("res://assets/models/buildings/bridge_roofed.glb")
const MESH_WATERMILL = preload("res://assets/models/buildings/watermill.glb")
const MESH_WATCHTOWER = preload("res://assets/models/buildings/watchtower.glb")
const MESH_DETAIL_ROCKS = preload("res://assets/models/buildings/detail_rocks.glb")
const MESH_DETAIL_ROCKS_SMALL = preload("res://assets/models/buildings/detail_rocks_small.glb")

# Models Cây, Đá, Lâu đài & Quái vật
const MESH_TREE_1 = preload("res://assets/models/forest/trees/Tree_1_A_Color1.gltf")
const MESH_TREE_2 = preload("res://assets/models/forest/trees/Tree_2_A_Color1.gltf")
const MESH_ROCK_LARGE = preload("res://assets/models/forest/rocks/Rock_1_A_Color1.gltf")
const MESH_ROCK_MED = preload("res://assets/models/forest/rocks/Rock_2_A_Color1.gltf")
const MESH_CASTLE = preload("res://assets/models/buildings/castle.glb")

# Skeletons
const MESH_SKEL_WARRIOR = preload("res://assets/models/enemies/characters/character_skeleton_warrior.gltf")
const MESH_SKEL_ARCHER = preload("res://assets/models/enemies/characters/character_skeleton_archer.gltf")

# Quy mô bản đồ: 36x36 ô (72m x 72m) - Không gian bao la, mật độ dày đặc, không bị loãng
const WORLD_TILES: Vector2i = Vector2i(36, 36)
const GRID_START: Vector2i = Vector2i(8, 7)
const GRID_SIZE: Vector2i = Vector2i(20, 20) # Vùng xây dựng 20x20 ô (40m x 40m - chuẩn Kingdom's Deck)
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

	# 1. Tạo Khối Chân Đế Sa Bàn Nổi (Solid Diorama Bedrock Pedestal) - Trị dứt điểm lộ đáy rỗng
	_build_diorama_bedrock(decorations_container)

	# 2. Sinh mặt sàn địa hình, Sông sâu & Tuyến đường mòn
	_build_terrain_tiles(grid_system, tiles_container, decorations_container)

	# 3. Đặt Cây Cầu Mái Che qua sông & Cối Xay Nước
	_build_bridge_and_watermill(decorations_container)

	# 4. Xây dựng Dãy Núi Đá Hùng Vĩ Tây Bắc (Tầng cao Y = +1.5 -> +3.5m)
	_build_mountains(decorations_container)

	# 5. Đặt Đại Bản Doanh Lâu Đài (Scale 2.4x uy nghiêm trên Gò đồi đá)
	var castle_local_coord = Vector2i(9, 9) # Tọa độ logic trung tâm trong lưới 20x20
	var castle_world_pos = _place_castle(grid_system, buildings_container, decorations_container, castle_local_coord)

	# 6. Phân bổ 4 cụm rừng tài nguyên & mỏ đá nội địa
	_build_internal_resources(grid_system, obstacles_container, decorations_container)

	# 7. Trồng Vành đai Rừng sâu Sinh quái ở phía Nam & Đông
	_build_outer_forests(decorations_container)

	# 8. Bố trí các trinh sát Skeleton canh gác ở mép rừng sâu
	_spawn_skeleton_scouts(decorations_container)

	return castle_world_pos

## 1. Khối Chân Đế Sa Bàn Nổi (Solid Diorama Bedrock Pedestal)
## Biến hòn đảo thành khối sa bàn đặc ruột, không bao giờ lộ đáy rỗng hay răng cưa
static func _build_diorama_bedrock(container: Node3D) -> void:
	var total_w = float(WORLD_TILES.x) * CELL_SIZE
	var total_d = float(WORLD_TILES.y) * CELL_SIZE
	var bedrock_depth = 5.0

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "DioramaBedrock"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(total_w, bedrock_depth, total_d)
	mesh_inst.mesh = box_mesh

	# Tâm đặt tại giữa đảo, chìm xuống dưới Y = -2.5m (bề mặt tiếp giáp Y = 0.0m)
	mesh_inst.position = Vector3(total_w / 2.0, -bedrock_depth / 2.0, total_d / 2.0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.17, 0.15) # Đá bazan / đất trầm ấm sang trọng
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	container.add_child(mesh_inst)

## 2. Sinh Địa Hình, Sông Sâu & Đường Mòn
static func _build_terrain_tiles(grid_system: GridSystem, tile_container: Node3D, deco_container: Node3D) -> void:
	# Tọa độ thế giới của Lâu Đài: X = 17, Y = 16
	var castle_world_x = GRID_START.x + 9
	var castle_world_y = GRID_START.y + 9

	for x in range(WORLD_TILES.x):
		for y in range(WORLD_TILES.y):
			var world_x = float(x) * CELL_SIZE
			var world_z = float(y) * CELL_SIZE
			var tile_pos = Vector3(world_x, 0.0, world_z)

			# Kiểm tra thuộc lưới xây dựng 20x20
			var in_playable_grid = (
				x >= GRID_START.x and x < GRID_START.x + GRID_SIZE.x and
				y >= GRID_START.y and y < GRID_START.y + GRID_SIZE.y
			)

			# Sông chạy dọc ở cột X = 4..6
			if x == 5:
				# Lòng sông sâu: Y = -0.7m
				var water_tile = _create_static_tile(MESH_SQUARE_WATER, tile_pos + Vector3(0, -0.7, 0))
				deco_container.add_child(water_tile)
				continue
			elif x == 4:
				# Bờ dốc phía Tây (dốc xuống sông)
				var bank_w = _create_static_tile(MESH_WATER_STRAIGHT, tile_pos, 0.0)
				deco_container.add_child(bank_w)
				continue
			elif x == 6:
				# Bờ dốc phía Đông (dốc xuống sông)
				var bank_e = _create_static_tile(MESH_WATER_STRAIGHT, tile_pos, PI)
				deco_container.add_child(bank_e)
				continue

			# Tuyến đường mòn nối Lâu Đài -> Cầu (Y = 16, X từ 7 đến 17)
			var is_road_to_bridge = (y == castle_world_y and x >= 7 and x <= castle_world_x)
			# Tuyến đường mòn từ Lâu Đài đi về phía Nam (X = 17, Y từ 16 đến 22)
			var is_road_to_south = (x == castle_world_x and y >= castle_world_y and y <= castle_world_y + 6)

			var tile_mesh = MESH_SQUARE_FOREST
			var is_road = false

			if is_road_to_bridge or is_road_to_south:
				is_road = true
				if x == castle_world_x and y == castle_world_y:
					# Ngã 3 quảng trường trước lâu đài
					tile_mesh = MESH_ROAD_TEE
				else:
					tile_mesh = MESH_ROAD_STRAIGHT

			if in_playable_grid:
				var local_coord = Vector2i(x - GRID_START.x, y - GRID_START.y)
				var p_tile: TerrainTile = TERRAIN_TILE_SCENE.instantiate()
				p_tile.grid_coord = local_coord
				p_tile.position = tile_pos

				if is_road:
					p_tile.tile_type = TerrainTile.TileType.ROAD
					p_tile.custom_model_scene = tile_mesh
					p_tile.rotation.y = (PI / 2.0) if is_road_to_bridge and not (x == castle_world_x and y == castle_world_y) else 0.0
					tile_container.add_child(p_tile)
					grid_system.register_tile(local_coord, p_tile, false) # Không cho xây đè lên đường
				else:
					p_tile.tile_type = TerrainTile.TileType.GRASS
					# 35% ô cỏ có hoa dại và cụm cỏ nổi bật, 65% cỏ xanh mướt
					p_tile.custom_model_scene = MESH_SQUARE_FOREST_DETAIL if (randf() < 0.35) else MESH_SQUARE_FOREST
					tile_container.add_child(p_tile)
					grid_system.register_tile(local_coord, p_tile, true)
			else:
				# Ô cảnh quan ngoài rìa
				var bg_tile = _create_static_tile(
					MESH_SQUARE_FOREST_DETAIL if randf() < 0.3 else MESH_SQUARE_FOREST,
					tile_pos
				)
				deco_container.add_child(bg_tile)

## Tạo Tile tĩnh cho cảnh quan ngoài rìa
static func _create_static_tile(mesh_scene: PackedScene, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var node = Node3D.new()
	node.position = pos
	node.rotation.y = rot_y
	var instance = mesh_scene.instantiate()
	node.add_child(instance)
	return node

## 3. Cây Cầu Gỗ Mái Che & Cối Xay Nước
static func _build_bridge_and_watermill(container: Node3D) -> void:
	var bridge_y = (GRID_START.y + 9) # Khớp với trục đường mòn Y = 16

	# Cầu gỗ có mái che bắc ngang lòng sông ở X = 5, Y = 16
	var bridge = MESH_BRIDGE_ROOFED.instantiate()
	bridge.name = "RoofedBridge"
	bridge.position = Vector3(5.0 * CELL_SIZE, 0.0, float(bridge_y) * CELL_SIZE)
	bridge.rotation_degrees.y = 90.0 # Xoay ngang nối bờ Tây sang bờ Đông
	bridge.scale = Vector3(1.15, 1.15, 1.15)
	container.add_child(bridge)

	# Cối xay nước bên bờ Đông (X = 6, Y = 15), bánh xe quay sát mép nước
	var watermill = MESH_WATERMILL.instantiate()
	watermill.name = "RiverWatermill"
	watermill.position = Vector3(6.0 * CELL_SIZE + 0.3, 0.0, float(bridge_y - 1) * CELL_SIZE)
	watermill.rotation_degrees.y = -90.0
	watermill.scale = Vector3(1.2, 1.2, 1.2)
	container.add_child(watermill)

## 4. Dãy Núi Đá Tây Bắc (Tầng cao Y = +1.5 -> +3.5m)
static func _build_mountains(container: Node3D) -> void:
	var mountain_specs = [
		{"pos": Vector3(2.0, 0.5, 2.0), "scale": Vector3(2.4, 2.8, 2.4)},
		{"pos": Vector3(4.0, 0.5, 4.0), "scale": Vector3(2.0, 2.4, 2.0)},
		{"pos": Vector3(2.0, 0.5, 8.0), "scale": Vector3(2.2, 2.6, 2.2)},
		{"pos": Vector3(2.0, 0.5, 14.0), "scale": Vector3(2.5, 3.0, 2.5)},
		{"pos": Vector3(4.0, 0.3, 11.0), "scale": Vector3(1.8, 2.0, 1.8)},
		{"pos": Vector3(2.0, 0.4, 20.0), "scale": Vector3(2.2, 2.5, 2.2)},
		{"pos": Vector3(2.0, 0.3, 26.0), "scale": Vector3(2.0, 2.2, 2.0)}
	]

	for spec in mountain_specs:
		var m = MESH_MOUNTAIN.instantiate()
		m.position = spec["pos"]
		m.scale = spec["scale"]
		container.add_child(m)

	# Các gò đồi và tảng đá nhấp nhô dưới chân núi
	var hill_spots = [
		Vector3(5.0, 0.0, 2.0), Vector3(3.0, 0.0, 6.0), Vector3(5.0, 0.0, 18.0)
	]
	for hp in hill_spots:
		var h = MESH_HILL.instantiate()
		h.position = hp
		h.scale = Vector3(1.8, 1.2, 1.8)
		container.add_child(h)

	var boulder_spots = [
		Vector3(4.0, 0.5, 7.0), Vector3(3.5, 0.5, 13.0), Vector3(4.5, 0.5, 23.0),
		Vector3(2.5, 0.5, 30.0)
	]
	for bp in boulder_spots:
		var b = MESH_ROCK_LARGE.instantiate()
		b.position = bp
		b.rotation_degrees.y = randf_range(0, 360)
		b.scale = Vector3.ONE * randf_range(1.3, 1.8)
		container.add_child(b)

## 5. Đặt Đại Bản Doanh Lâu Đài (Scale 2.4x uy nghiêm trên Gò đồi)
static func _place_castle(
	grid_system: GridSystem,
	build_container: Node3D,
	deco_container: Node3D,
	coord: Vector2i
) -> Vector3:
	var world_pos = grid_system.grid_to_world(coord, 0.0)

	# 1. Bệ Gò Đất Hoàng Gia (Royal Hill Base) nâng cao cao độ
	var hill = MESH_HILL.instantiate()
	hill.position = world_pos + Vector3(0, 0.05, 0)
	hill.scale = Vector3(2.8, 0.65, 2.8)
	deco_container.add_child(hill)

	# 2. Hai Tháp Canh đá kiên cố canh gác 2 góc sau Lâu Đài
	var tower_left = MESH_WATCHTOWER.instantiate()
	tower_left.position = world_pos + Vector3(-2.8, 0.35, -2.5)
	tower_left.scale = Vector3(1.2, 1.2, 1.2)
	deco_container.add_child(tower_left)

	var tower_right = MESH_WATCHTOWER.instantiate()
	tower_right.position = world_pos + Vector3(2.8, 0.35, -2.5)
	tower_right.scale = Vector3(1.2, 1.2, 1.2)
	deco_container.add_child(tower_right)

	# 3. Tòa Lâu Đài chính phóng to 2.4x - Uy nghiêm bề thế
	var castle: BuildingEntity = BUILDING_ENTITY_SCENE.instantiate()
	castle.grid_coord = coord
	castle.custom_model_scene = MESH_CASTLE
	castle.position = world_pos + Vector3(0, 0.45, 0) # Ngự trên bệ gò cao 0.45m
	castle.scale = Vector3(2.4, 2.4, 2.4)
	build_container.add_child(castle)
	grid_system.register_building(coord, castle)

	return world_pos

## 6. Phân bổ Cụm Rừng Tài nguyên & Mỏ đá bên trong lưới xây dựng
static func _build_internal_resources(
	grid_system: GridSystem,
	obs_container: Node3D,
	deco_container: Node3D
) -> void:
	# 4 cụm rừng phong phú để khai thác gỗ
	var tree_clusters = [
		# Cụm 1: Phía Tây (gần bờ sông, cối xay nước)
		[Vector2i(3, 5), Vector2i(4, 5), Vector2i(3, 6), Vector2i(4, 6), Vector2i(3, 7)],
		# Cụm 2: Phía Bắc (hướng về núi đá)
		[Vector2i(8, 2), Vector2i(9, 2), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 2)],
		# Cụm 3: Phía Đông (bình nguyên mở rộng)
		[Vector2i(15, 6), Vector2i(16, 6), Vector2i(15, 7), Vector2i(16, 7), Vector2i(17, 6)],
		# Cụm 4: Phía Nam (tiền tuyến)
		[Vector2i(13, 15), Vector2i(14, 15), Vector2i(13, 16), Vector2i(14, 16), Vector2i(15, 15)]
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
			obs_container.add_child(tree)
			grid_system.register_obstacle(tc, tree)

	# 3 Mỏ đá tự nhiên (15 đá/mỏ)
	var rock_spots = [Vector2i(2, 2), Vector2i(15, 2), Vector2i(17, 12)]
	for rc in rock_spots:
		var rock: ResourceNode = RESOURCE_NODE_SCENE.instantiate()
		rock.grid_coord = rc
		rock.node_type = ResourceNode.NodeType.ROCK_QUARRY
		rock.resource_name = "stone"
		rock.current_resource_amount = 15
		rock.custom_model_scene = MESH_ROCK_MED
		rock.position = grid_system.grid_to_world(rc, 1.0)
		obs_container.add_child(rock)
		grid_system.register_obstacle(rc, rock)

	# Thêm đá cảnh nhỏ tạo chi tiết tự nhiên
	var deco_rocks = [
		Vector3(26.0, 0.0, 18.0), Vector3(38.0, 0.0, 24.0), Vector3(44.0, 0.0, 36.0)
	]
	for dr in deco_rocks:
		var r = MESH_DETAIL_ROCKS_SMALL.instantiate()
		r.position = dr
		r.rotation_degrees.y = randf_range(0, 360)
		deco_container.add_child(r)

## 7. Vành đai Rừng sâu Sinh quái ở rìa Nam & Đông
static func _build_outer_forests(container: Node3D) -> void:
	# Mép Nam (Y = 30..35)
	for x in range(0, WORLD_TILES.x, 2):
		for y in range(30, WORLD_TILES.y, 2):
			var pos = Vector3(
				float(x) * CELL_SIZE + randf_range(-0.5, 0.5),
				0.0,
				float(y) * CELL_SIZE + randf_range(-0.5, 0.5)
			)
			if randf() > 0.45:
				var f = MESH_FOREST_CLUSTER.instantiate()
				f.position = pos
				f.scale = Vector3.ONE * randf_range(1.1, 1.4)
				container.add_child(f)
			else:
				var t = MESH_TREE_1.instantiate()
				t.position = pos + Vector3(0, 1.0, 0)
				t.scale = Vector3.ONE * randf_range(1.3, 1.7)
				container.add_child(t)

	# Mép Đông (X = 30..35, Y = 0..30)
	for y in range(0, 30, 2):
		for x in range(30, WORLD_TILES.x, 2):
			var pos = Vector3(
				float(x) * CELL_SIZE + randf_range(-0.5, 0.5),
				0.0,
				float(y) * CELL_SIZE + randf_range(-0.5, 0.5)
			)
			var f = MESH_DETAIL_FOREST.instantiate()
			f.position = pos
			f.scale = Vector3.ONE * randf_range(1.0, 1.3)
			container.add_child(f)

## 8. Đặt các trinh sát Skeleton đứng canh gác ở mép rừng sâu
static func _spawn_skeleton_scouts(container: Node3D) -> void:
	var scout_positions = [
		Vector3(26.0, 0.0, 60.0),
		Vector3(34.0, 0.0, 61.0),
		Vector3(44.0, 0.0, 60.5),
		Vector3(56.0, 0.0, 48.0),
		Vector3(60.0, 0.0, 36.0)
	]
	for sp in scout_positions:
		var scout = (MESH_SKEL_WARRIOR if randf() > 0.5 else MESH_SKEL_ARCHER).instantiate()
		scout.position = sp
		scout.rotation_degrees.y = randf_range(180, 240)
		container.add_child(scout)
