@tool
class_name RiverGenerator
extends RefCounted

## Bộ Tạo Dòng Sông & Hệ Thống Thủy Văn (Procedural River & Hydrology)
## Thuộc Phân hệ 03 trong quy trình 16 bước phát sinh sa bàn 3D (Procedural Diorama Engine).
## Chịu trách nhiệm sinh tuyến đường cong Spline Catmull-Rom dọc theo sườn Tây,
## khoét sâu lòng sông xuống Level 0 bằng Distance Field, phân loại 3 đới thủy văn,
## tính góc xoay xuôi dòng cho bờ kè đá và định vị điểm neo Cầu qua sông.

# ------------------------------------------------------------------------------
# 1. Điểm Đầu Vào Chính (Main Entry Point)
# ------------------------------------------------------------------------------

## Thực thi quy trình sinh dòng sông và phân đới thủy văn
static func generate(context: MapGenContext, config: MapGenConfig) -> void:
	if context == null or config == null:
		push_error("RiverGenerator.generate(): context hoặc config mang giá trị null!")
		return
		
	# Nếu tính năng sông bị vô hiệu hóa trong cấu hình, thoát sớm
	if not config.river_enabled:
		return
		
	var bridge_y: int = config.playable_origin.y + 9
	
	# Bước 1: Khởi tạo tuyến Spline tham số hóa 5 điểm chốt kiểm soát
	var curve: Curve2D = _build_river_spline(context, config, bridge_y)
	
	# Bước 2: Quét ma trận ô cờ, đào lòng sông bằng Distance Field và phân đới thủy văn
	_carve_distance_field(context, config, curve)
	
	# Bước 3: Đăng ký tọa độ Cầu và khôi phục cao độ Level 1 tại điểm giao
	_register_bridge_poi(context, config, bridge_y)

# ------------------------------------------------------------------------------
# 2. Các Thuật Toán Thành Phần (Sub-Algorithms)
# ------------------------------------------------------------------------------

## Bước 1: Xây dựng tuyến Spline Curve2D với tiếp tuyến mượt và chốt thẳng góc tại Cầu
static func _build_river_spline(context: MapGenContext, config: MapGenConfig, bridge_y: int) -> Curve2D:
	var curve: Curve2D = Curve2D.new()
	curve.bake_interval = 0.5
	
	var cell_size: float = context.cell_size
	var map_height: float = float(context.height)
	var x_start: float = config.river_start_x
	var x_bridge: float = config.river_bridge_x
	var x_end: float = 5.5
	
	# Sử dụng RNG có seed tất định để tạo dao động uốn lượn tự nhiên
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = config.seed + 400
	var jitter1: float = rng.randf_range(-0.6, 0.6)
	var jitter2: float = rng.randf_range(-0.6, 0.6)
	
	# 5 Điểm chốt thế giới (World space positions)
	var p0: Vector2 = Vector2(x_start * cell_size, 0.0)
	var p1: Vector2 = Vector2((x_bridge + jitter1) * cell_size, float(bridge_y) * 0.5 * cell_size)
	var p_bridge: Vector2 = Vector2(x_bridge * cell_size, float(bridge_y) * cell_size)
	var p2: Vector2 = Vector2((x_bridge + jitter2) * cell_size, (float(bridge_y) + map_height) * 0.5 * cell_size)
	var p3: Vector2 = Vector2(x_end * cell_size, map_height * cell_size)
	
	# Thêm điểm và thiết lập tiếp tuyến Catmull-Rom
	# Tại P_bridge, ép tiếp tuyến thẳng đứng (x = 0) để dòng chảy thẳng góc qua nhịp Cầu
	var bridge_tangent_len: float = (p2.y - p1.y) * 0.25
	
	curve.add_point(p0, Vector2.ZERO, (p1 - p0) * 0.25)
	curve.add_point(p1, -(p_bridge - p0) * 0.25, (p_bridge - p0) * 0.25)
	curve.add_point(p_bridge, Vector2(0.0, -bridge_tangent_len), Vector2(0.0, bridge_tangent_len))
	curve.add_point(p2, -(p3 - p_bridge) * 0.25, (p3 - p_bridge) * 0.25)
	curve.add_point(p3, -(p3 - p2) * 0.25, Vector2.ZERO)
	
	return curve

## Bước 2: Đào lòng sông theo khoảng cách vuông góc ngắn nhất tới Spline và phân đới thủy văn
static func _carve_distance_field(context: MapGenContext, config: MapGenConfig, curve: Curve2D) -> void:
	var width: int = context.width
	var height: int = context.height
	var cell_size: float = context.cell_size
	
	var river_w: float = config.river_width * cell_size
	var bank_w: float = config.river_bank_width * cell_size
	var total_reach: float = river_w + bank_w
	
	for y in range(height):
		for x in range(width):
			var idx: int = context.get_index(x, y)
			
			# Tọa độ tâm ô cờ trong không gian thế giới (Cell center)
			var pos_2d: Vector2 = Vector2((float(x) + 0.5) * cell_size, (float(y) + 0.5) * cell_size)
			var closest_pt: Vector2 = curve.get_closest_point(pos_2d)
			var dist: float = pos_2d.distance_to(closest_pt)
			
			context.river_distance_map[idx] = dist
			
			if dist < river_w:
				# 1. Đới Nước sâu (Water Zone 2)
				context.water_zones[idx] = MapGenConstants.WaterZone.WATER
				context.elevation_levels[idx] = MapGenConstants.ElevationLevel.RIVER_BED # Level 0
				context.buildable_mask[idx] = 0
			elif dist < total_reach:
				# 2. Đới Bờ kè dốc (Bank Zone 1)
				context.water_zones[idx] = MapGenConstants.WaterZone.BANK
				context.elevation_levels[idx] = MapGenConstants.ElevationLevel.LOWLAND # Level 1
				context.buildable_mask[idx] = 0
				
				# Tính góc xoay Y hướng dốc vào tâm lòng sông
				var vec_to_water: Vector2 = closest_pt - pos_2d
				if vec_to_water.length_squared() > 0.001:
					var angle: float = atan2(vec_to_water.x, vec_to_water.y) # Trong 3D: atan2(x, z)
					# Làm tròn về 4 hướng trực giao gần nhất (bội số của PI/2)
					var snapped_angle: float = round(angle / (PI * 0.5)) * (PI * 0.5)
					context.bank_rotations[idx] = snapped_angle
			else:
				# 3. Đới Đất liền khô ráo (Land Zone 0)
				context.water_zones[idx] = MapGenConstants.WaterZone.LAND

## Bước 3: Đăng ký điểm neo Cầu qua sông và khôi phục cao độ bằng mặt bờ kè
static func _register_bridge_poi(context: MapGenContext, config: MapGenConfig, bridge_y: int) -> void:
	var bridge_coord: Vector2i = Vector2i(int(round(config.river_bridge_x)), bridge_y)
	
	context.register_poi(MapGenConstants.POIType.BRIDGE, bridge_coord)
	context.poi_registry["bridge_coord"] = bridge_coord
	
	# Khôi phục cao độ tại ô Cầu về Level 1 (Y = 0.0m) để cầu gỗ bắc ngang không bị chìm xuống nước
	var bridge_idx: int = context.get_index(bridge_coord.x, bridge_coord.y)
	context.elevation_levels[bridge_idx] = MapGenConstants.ElevationLevel.LOWLAND
