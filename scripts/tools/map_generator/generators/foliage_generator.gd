@tool
class_name FoliageGenerator
extends RefCounted

## Bộ Tạo Mật Độ Rừng & Phân Rải Poisson Disk (Foliage & Poisson Scattering)
## Thuộc Phân hệ 05 trong quy trình 16 bước phát sinh sa bàn 3D (Procedural Diorama Engine).
## Chịu trách nhiệm tạo ma trận mật độ rừng Simplex Cluster Noise, áp dụng Vignette Gradient,
## lấy mẫu vị trí cây đá bằng Poisson Disk O(N) chống đè lấn, và điều biến Transform3D.

# ------------------------------------------------------------------------------
# 1. Điểm Đầu Vào Chính (Main Entry Point)
# ------------------------------------------------------------------------------

## Thực thi quy trình sinh thảm thực vật và phân rải Poisson Disk
static func generate(context: MapGenContext, config: MapGenConfig) -> void:
	if context == null or config == null:
		push_error("FoliageGenerator.generate(): context hoặc config mang giá trị null!")
		return
		
	# Bước 1: Tính toán ma trận mật độ rừng cụm và áp dụng vùng cấm tuyệt đối
	_calculate_density_map(context, config)
	
	# Bước 2: Lấy mẫu vị trí phân rải hữu cơ bằng thuật toán Poisson Disk Sampling O(N)
	var points_2d: Array[Vector2] = _sample_poisson_points(context, config)
	
	# Bước 3: Điều biến Transform3D (Scale, Rotation, World Y) và phân loại MultiMesh
	_modulate_and_categorize(context, config, points_2d)

# ------------------------------------------------------------------------------
# 2. Ma Trận Mật Độ Rừng & Vùng Cấm Tuyệt Đối (Density Map & Exclusion)
# ------------------------------------------------------------------------------

static func _calculate_density_map(context: MapGenContext, config: MapGenConfig) -> void:
	var width: int = context.width
	var height: int = context.height
	
	var cluster_noise: FastNoiseLite = FastNoiseLite.new()
	cluster_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cluster_noise.seed = config.seed + 202
	cluster_noise.frequency = config.cluster_scale
	
	var castle_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.CASTLE)
	var center: Vector2 = Vector2(float(width) * 0.5, float(height) * 0.5)
	var max_radius: float = center.length()
	var quarries: Array = context.poi_registry.get("quarry_coords", [])
	
	for y in range(height):
		for x in range(width):
			var idx: int = context.get_index(x, y)
			var coord: Vector2i = Vector2i(x, y)
			
			# Vùng cấm tuyệt đối: Lòng sông, Bờ kè, Đường mòn, Quanh Lâu Đài (bán kính 4 ô), Mỏ đá
			var is_water: bool = (context.get_water_zone(x, y) != MapGenConstants.WaterZone.LAND)
			var is_road: bool = context.road_nodes.has(coord)
			var is_castle_area: bool = (Vector2(coord).distance_to(Vector2(castle_coord)) <= 4.0)
			var is_quarry: bool = quarries.has(coord)
			
			if is_water or is_road or is_castle_area or is_quarry:
				context.foliage_density_map[idx] = 0.0
				continue
				
			# Noise tạo cụm tự nhiên
			var noise_val: float = (cluster_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			
			# Hệ số Vignette tập trung viền rừng mép biên sa bàn
			var d_norm: float = clampf(Vector2(float(x), float(y)).distance_to(center) / max_radius, 0.0, 1.0)
			var vignette: float = pow(d_norm, 1.6)
			
			# Mật độ tổng hợp
			var density: float = noise_val * 0.35 + vignette * 0.65
			context.foliage_density_map[idx] = density

# ------------------------------------------------------------------------------
# 3. Thuật Toán Lấy Mẫu Đĩa Poisson O(N) Bridson (Poisson Disk Sampling)
# ------------------------------------------------------------------------------

static func _sample_poisson_points(context: MapGenContext, config: MapGenConfig) -> Array[Vector2]:
	var r_min: float = config.min_tree_distance
	var cell_size: float = context.cell_size
	var map_size_meters: Vector2 = Vector2(float(context.width) * cell_size, float(context.height) * cell_size)
	
	# Lưới gia tốc phụ (Acceleration Grid)
	var cell_sub_size: float = r_min / sqrt(2.0)
	var cols: int = int(ceil(map_size_meters.x / cell_sub_size))
	var rows: int = int(ceil(map_size_meters.y / cell_sub_size))
	
	var accel_grid: PackedInt32Array = PackedInt32Array()
	accel_grid.resize(cols * rows)
	accel_grid.fill(-1)
	
	var points_2d: Array[Vector2] = []
	var active_list: Array[int] = []
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = config.seed + 505
	
	# Hàm kiểm tra tính hợp lệ của điểm ứng viên
	var is_valid_point = func(pt: Vector2) -> bool:
		if pt.x < 1.0 or pt.x >= map_size_meters.x - 1.0 or pt.y < 1.0 or pt.y >= map_size_meters.y - 1.0:
			return false
		var gx: int = int(pt.x / cell_size)
		var gy: int = int(pt.y / cell_size)
		if not context.is_inside(gx, gy):
			return false
		var d: float = context.get_foliage_density(gx, gy)
		if d < config.forest_density:
			return false
		return rng.randf() < (d * 0.60)
		
	# Tìm các điểm hạt giống ban đầu
	for attempt in range(50):
		var init_pt: Vector2 = Vector2(
			rng.randf_range(2.0, map_size_meters.x - 2.0),
			rng.randf_range(2.0, map_size_meters.y - 2.0)
		)
		if is_valid_point.call(init_pt):
			var p_idx: int = points_2d.size()
			points_2d.append(init_pt)
			active_list.append(p_idx)
			var ac: int = int(init_pt.x / cell_sub_size)
			var ar: int = int(init_pt.y / cell_sub_size)
			accel_grid[ar * cols + ac] = p_idx
			if active_list.size() >= 5:
				break
				
	var k: int = 20
	var max_points: int = 550
	
	# Vòng lặp lấy mẫu Poisson
	while not active_list.is_empty() and points_2d.size() < max_points:
		var rand_list_idx: int = rng.randi() % active_list.size()
		var p_idx: int = active_list[rand_list_idx]
		var p: Vector2 = points_2d[p_idx]
		var found: bool = false
		
		for _trial in range(k):
			var angle: float = rng.randf() * TAU
			var dist: float = rng.randf_range(r_min, 2.0 * r_min)
			var candidate: Vector2 = p + Vector2(cos(angle), sin(angle)) * dist
			
			if not is_valid_point.call(candidate):
				continue
				
			var c_idx: int = int(candidate.x / cell_sub_size)
			var r_idx: int = int(candidate.y / cell_sub_size)
			var too_close: bool = false
			
			# Quét 5x5 mắt lưới phụ lân cận trong O(1)
			for dr in range(-2, 3):
				for dc in range(-2, 3):
					var nc: int = c_idx + dc
					var nr: int = r_idx + dr
					if nc >= 0 and nc < cols and nr >= 0 and nr < rows:
						var neighbor_id: int = accel_grid[nr * cols + nc]
						if neighbor_id != -1:
							if candidate.distance_to(points_2d[neighbor_id]) < r_min:
								too_close = true
								break
				if too_close:
					break
					
			if not too_close:
				var new_idx: int = points_2d.size()
				points_2d.append(candidate)
				active_list.append(new_idx)
				accel_grid[r_idx * cols + c_idx] = new_idx
				found = true
				break
				
		if not found:
			active_list.remove_at(rand_list_idx)
			
	return points_2d

# ------------------------------------------------------------------------------
# 4. Điều Biến Transform3D & Phân Loại MultiMesh (Modulation & Categorization)
# ------------------------------------------------------------------------------

static func _modulate_and_categorize(context: MapGenContext, config: MapGenConfig, points_2d: Array[Vector2]) -> void:
	context.foliage_transforms.clear()
	for key in context.categorized_foliage.keys():
		context.categorized_foliage[key].clear()
		
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = config.seed + 606
	
	var cell_size: float = context.cell_size
	
	for pt in points_2d:
		var gx: int = int(pt.x / cell_size)
		var gy: int = int(pt.y / cell_size)
		
		var world_y: float = context.get_world_y_for_cell(gx, gy)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var scale_val: float = rng.randf_range(0.9, 1.3)
		
		# Khởi tạo Transform3D có điều biến góc và tỷ lệ
		var t: Transform3D = Transform3D()
		t = t.scaled(Vector3.ONE * scale_val)
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = Vector3(pt.x, world_y, pt.y)
		
		context.foliage_transforms.append(t)
		
		# Phân loại theo mật độ và cao độ địa hình
		var density: float = context.get_foliage_density(gx, gy)
		var lvl: int = context.get_elevation(gx, gy)
		
		if density >= MapGenConstants.FOREST_DENSE_THRESHOLD:
			if rng.randf() < 0.40:
				context.categorized_foliage["forest_cluster"].append(t)
			else:
				context.categorized_foliage["tree_1"].append(t)
		elif lvl >= 4 and rng.randf() < 0.25:
			if rng.randf() < 0.50:
				context.categorized_foliage["rock_large"].append(t)
			else:
				context.categorized_foliage["rock_med"].append(t)
		else:
			if rng.randf() < 0.50:
				context.categorized_foliage["tree_1"].append(t)
			else:
				context.categorized_foliage["tree_2"].append(t)
