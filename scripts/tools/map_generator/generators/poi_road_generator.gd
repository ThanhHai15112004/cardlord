@tool
class_name POIAndRoadGenerator
extends RefCounted

## Bộ Định Vị POI & Mạng Lưới Đường Mòn A* (Procedural POI & A* Road Network)
## Thuộc Phân hệ 04 trong quy trình 16 bước phát sinh sa bàn 3D (Procedural Diorama Engine).
## Sàng lọc vị trí Lâu Đài, Mỏ Đá, Cụm Rừng, Trinh Sát theo bài toán thỏa mãn ràng buộc;
## tìm 2 tuyến đường mòn bằng Weighted A* và tự động phân loại khớp nối Auto-tiling Bitmask.

# ------------------------------------------------------------------------------
# 1. Điểm Đầu Vào Chính (Main Entry Point)
# ------------------------------------------------------------------------------

## Thực thi quy trình sinh POI và mạng lưới đường mòn
static func generate(context: MapGenContext, config: MapGenConfig) -> void:
	if context == null or config == null:
		push_error("POIAndRoadGenerator.generate(): context hoặc config mang giá trị null!")
		return
		
	# Bước 1: Định vị Đại bản doanh Lâu Đài tại tâm vương quốc
	var castle_coord: Vector2i = _place_castle(context, config)
	
	# Bước 2: Xây dựng đồ thị và tìm 2 tuyến đường mòn huyết mạch bằng Weighted A*
	_generate_roads(context, config, castle_coord)
	
	# Bước 3: Sàng lọc và phân bổ các tài nguyên tự nhiên (Mỏ Đá, Cụm Rừng) và Quái Trinh Sát
	_place_secondary_pois(context, config, castle_coord)

# ------------------------------------------------------------------------------
# 2. Định Vị Đại Bản Doanh Lâu Đài (Castle Placement)
# ------------------------------------------------------------------------------

static func _place_castle(context: MapGenContext, config: MapGenConfig) -> Vector2i:
	var castle_coord: Vector2i = config.playable_origin + Vector2i(9, 9)
	
	# Xác thực vị trí Lâu Đài
	if not context.is_inside_coord(castle_coord):
		castle_coord = Vector2i(context.width / 2, context.height / 2)
		
	# Đăng ký vào bảng tra POI
	context.register_poi(MapGenConstants.POIType.CASTLE, castle_coord)
	context.poi_registry["castle_coord"] = castle_coord
	
	# Khóa móng Lâu Đài không cho phép xây nhà đè lên
	context.set_buildable(castle_coord.x, castle_coord.y, false)
	
	return castle_coord

# ------------------------------------------------------------------------------
# 3. Mạng Lưới Đường Mòn Weighted A* & Auto-Tiling Bitmask
# ------------------------------------------------------------------------------

static func _generate_roads(context: MapGenContext, config: MapGenConfig, castle_coord: Vector2i) -> void:
	var bridge_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.BRIDGE)
	if bridge_coord == Vector2i(-1, -1):
		bridge_coord = Vector2i(int(round(config.river_bridge_x)), config.playable_origin.y + 9)
		
	# Xác định các ô nhịp cầu hợp lệ bắc qua toàn bộ tiết diện lòng sông (từ bờ Tây sang bờ Đông)
	var bridge_crossing_cells: Dictionary = {}
	for bx in range(bridge_coord.x - 2, bridge_coord.x + 2):
		bridge_crossing_cells[Vector2i(bx, bridge_coord.y)] = true
		
	# 1. Khởi tạo đồ thị AStar2D
	var astar: AStar2D = AStar2D.new()
	var width: int = context.width
	var height: int = context.height
	var dirs: Array[Vector2i] = MapGenConstants.NEIGHBOR_OFFSETS_4
	
	for y in range(height):
		for x in range(width):
			astar.add_point(context.get_index(x, y), Vector2(x, y))
			
	for y in range(height):
		for x in range(width):
			var u_id: int = context.get_index(x, y)
			var u_pos: Vector2i = Vector2i(x, y)
			
			for d in dirs:
				var v_pos: Vector2i = u_pos + d
				if not context.is_inside_coord(v_pos):
					continue
					
				var v_id: int = context.get_index(v_pos.x, v_pos.y)
				var slope: float = context.get_slope(v_pos.x, v_pos.y)
				var water: int = context.get_water_zone(v_pos.x, v_pos.y)
				var is_bridge: bool = bridge_crossing_cells.has(v_pos)
				
				# Vách đứng (Slope >= 2.0) và nước sâu (không có cầu) bị ngắt cạnh vĩnh viễn
				if slope >= 2.0 or (water == MapGenConstants.WaterZone.WATER and not is_bridge):
					continue
					
				var cost: float = 1.0
				if slope >= 1.0:
					cost += config.slope_cost_penalty
				if is_bridge:
					cost = 1.0
					
				astar.connect_points(u_id, v_id, false)
				astar.set_point_weight_scale(v_id, cost)
				
	# 2. Tìm 2 tuyến đường chính
	var start_id: int = context.get_index(castle_coord.x, castle_coord.y)
	var bridge_id: int = context.get_index(bridge_coord.x, bridge_coord.y)
	var path1_ids: PackedInt64Array = astar.get_id_path(start_id, bridge_id)
	
	var south_target: Vector2i = castle_coord + Vector2i(0, 6)
	if not context.is_inside_coord(south_target):
		south_target = Vector2i(castle_coord.x, height - 2)
	var south_id: int = context.get_index(south_target.x, south_target.y)
	var path2_ids: PackedInt64Array = astar.get_id_path(start_id, south_id)
	
	# Tập hợp danh sách các ô đường
	var road_set: Dictionary = {}
	for pid in path1_ids:
		road_set[context.get_coord(int(pid))] = true
	for pid in path2_ids:
		road_set[context.get_coord(int(pid))] = true
		
	# Bổ sung ô thềm đông Lâu Đài để tạo nút giao ngã ba TEE tại quảng trường
	var east_plaza_step: Vector2i = castle_coord + Vector2i(1, 0)
	if context.is_inside_coord(east_plaza_step):
		road_set[east_plaza_step] = true
		
	# 3. Phân loại Auto-Tiling Bitmask
	context.road_nodes.clear()
	
	for c in road_set.keys():
		var mask: int = 0
		if road_set.has(c + Vector2i(0, -1)): mask |= MapGenConstants.RoadBitmask.NORTH # 1
		if road_set.has(c + Vector2i(1, 0)):  mask |= MapGenConstants.RoadBitmask.EAST  # 2
		if road_set.has(c + Vector2i(0, 1)):  mask |= MapGenConstants.RoadBitmask.SOUTH # 4
		if road_set.has(c + Vector2i(-1, 0)): mask |= MapGenConstants.RoadBitmask.WEST  # 8
		
		var node_type: int = MapGenConstants.RoadNodeType.STRAIGHT
		var rot_y: float = 0.0
		
		match mask:
			1, 2, 4, 8:
				node_type = MapGenConstants.RoadNodeType.DEAD_END
				if mask == 1: rot_y = 0.0
				elif mask == 2: rot_y = PI * 0.5
				elif mask == 4: rot_y = PI
				elif mask == 8: rot_y = -PI * 0.5
			5: # North + South
				node_type = MapGenConstants.RoadNodeType.STRAIGHT
				rot_y = 0.0
			10: # East + West
				node_type = MapGenConstants.RoadNodeType.STRAIGHT
				rot_y = PI * 0.5
			3: # North + East
				node_type = MapGenConstants.RoadNodeType.CORNER
				rot_y = 0.0
			6: # East + South
				node_type = MapGenConstants.RoadNodeType.CORNER
				rot_y = PI * 0.5
			12: # South + West
				node_type = MapGenConstants.RoadNodeType.CORNER
				rot_y = PI
			9: # North + West
				node_type = MapGenConstants.RoadNodeType.CORNER
				rot_y = -PI * 0.5
			7: # North + East + South
				node_type = MapGenConstants.RoadNodeType.TEE
				rot_y = PI * 0.5
			14: # East + South + West
				node_type = MapGenConstants.RoadNodeType.TEE
				rot_y = PI
			13: # North + South + West
				node_type = MapGenConstants.RoadNodeType.TEE
				rot_y = -PI * 0.5
			11: # North + East + West
				node_type = MapGenConstants.RoadNodeType.TEE
				rot_y = 0.0
			15:
				node_type = MapGenConstants.RoadNodeType.CROSS
				rot_y = 0.0
				
		context.road_nodes[c] = {
			"bitmask": mask,
			"type": node_type,
			"rotation_y": rot_y
		}
		
		# Khóa cấm đặt móng nhà đè lên đường mòn
		context.set_buildable(c.x, c.y, false)

# ------------------------------------------------------------------------------
# 4. Sàng Lọc POI Phụ (Mỏ Đá, Cụm Rừng, Trinh Sát)
# ------------------------------------------------------------------------------

static func _place_secondary_pois(context: MapGenContext, config: MapGenConfig, castle_coord: Vector2i) -> void:
	# A. Mỏ Đá Tự Nhiên (3 vị trí chân núi Tây Bắc)
	var quarry_coords: Array[Vector2i] = []
	var q_min_x: int = 5
	var q_max_x: int = mini(context.width - 1, castle_coord.x)
	var q_min_y: int = 4
	var q_max_y: int = mini(context.height - 1, castle_coord.y - 2)
	
	for y in range(q_min_y, q_max_y + 1):
		for x in range(q_min_x, q_max_x + 1):
			var coord: Vector2i = Vector2i(x, y)
			if context.road_nodes.has(coord) or coord == castle_coord:
				continue
				
			var lvl: int = context.get_elevation(x, y)
			var slope: float = context.get_slope(x, y)
			var water: int = context.get_water_zone(x, y)
			
			if (lvl == 3 or lvl == 4) and slope >= 1.0 and water == MapGenConstants.WaterZone.LAND:
				# Kiểm tra cự ly giãn cách với các mỏ đá đã chọn
				var well_spaced: bool = true
				for existing_q in quarry_coords:
					if Vector2(coord).distance_to(Vector2(existing_q)) < 3.0:
						well_spaced = false
						break
				if well_spaced:
					quarry_coords.append(coord)
					context.set_buildable(x, y, false)
					if quarry_coords.size() >= 3:
						break
		if quarry_coords.size() >= 3:
			break
			
	context.register_poi_group(MapGenConstants.POIType.QUARRY, quarry_coords)
	context.poi_registry["quarry_coords"] = quarry_coords
	
	# B. Cụm Rừng Tài Nguyên Gỗ (4 cụm tại 4 góc chiến thuật)
	var p_orig: Vector2i = config.playable_origin
	var p_size: Vector2i = config.playable_grid_size
	var half_w: int = p_size.x / 2
	var half_h: int = p_size.y / 2
	
	# 4 Vùng góc (Tây-Bắc, Đông-Bắc, Tây-Nam, Đông-Nam)
	var quadrant_boxes: Array[Rect2i] = [
		Rect2i(p_orig.x + 1, p_orig.y + 1, half_w - 2, half_h - 2),
		Rect2i(p_orig.x + half_w + 1, p_orig.y + 1, half_w - 2, half_h - 2),
		Rect2i(p_orig.x + 1, p_orig.y + half_h + 1, half_w - 2, half_h - 2),
		Rect2i(p_orig.x + half_w + 1, p_orig.y + half_h + 1, half_w - 2, half_h - 2)
	]
	
	var forest_clusters: Array[Vector2i] = []
	
	for box in quadrant_boxes:
		var cluster_placed: bool = false
		for cy in range(box.position.y, box.position.y + box.size.y):
			for cx in range(box.position.x, box.position.x + box.size.x):
				var center_cand: Vector2i = Vector2i(cx, cy)
				if context.road_nodes.has(center_cand) or center_cand == castle_coord or quarry_coords.has(center_cand):
					continue
				if context.get_water_zone(cx, cy) != MapGenConstants.WaterZone.LAND:
					continue
				if not context.is_buildable(cx, cy):
					continue
					
				# Tạo cụm 4 ô cờ xung quanh tâm
				var local_cells: Array[Vector2i] = [
					center_cand,
					center_cand + Vector2i(1, 0),
					center_cand + Vector2i(0, 1),
					center_cand + Vector2i(1, 1)
				]
				
				var all_valid: bool = true
				for lc in local_cells:
					if not context.is_inside_coord(lc) or context.road_nodes.has(lc) or lc == castle_coord:
						all_valid = false
						break
					if context.get_water_zone(lc.x, lc.y) != MapGenConstants.WaterZone.LAND:
						all_valid = false
						break
						
				if all_valid:
					for lc in local_cells:
						forest_clusters.append(lc)
						context.set_buildable(lc.x, lc.y, false)
					cluster_placed = true
					break
			if cluster_placed:
				break
				
	context.register_poi_group(MapGenConstants.POIType.LUMBER, forest_clusters)
	context.poi_registry["forest_clusters"] = forest_clusters
	
	# C. Trinh Sát Kẻ Địch (5 vị trí mép Nam và mép Đông, cách Lâu Đài > 14 ô)
	var scout_coords: Array[Vector2i] = []
	for y in range(context.height):
		for x in range(context.width):
			if y >= 30 or x >= 30:
				var coord: Vector2i = Vector2i(x, y)
				if context.get_water_zone(x, y) != MapGenConstants.WaterZone.LAND:
					continue
				if context.road_nodes.has(coord) or coord == castle_coord:
					continue
				var dist_to_castle: float = Vector2(coord).distance_to(Vector2(castle_coord))
				if dist_to_castle > 14.0:
					# Giãn cách các trinh sát tối thiểu 4 ô
					var well_spaced: bool = true
					for s in scout_coords:
						if Vector2(coord).distance_to(Vector2(s)) < 4.0:
							well_spaced = false
							break
					if well_spaced:
						scout_coords.append(coord)
						if scout_coords.size() >= 5:
							break
		if scout_coords.size() >= 5:
			break
			
	context.register_poi_group(MapGenConstants.POIType.SCOUT, scout_coords)
	context.poi_registry["scout_coords"] = scout_coords
