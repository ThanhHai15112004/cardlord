@tool
class_name TerraceGenerator
extends RefCounted

## Bộ Tạo Phân Tầng Địa Hình, Độ Dốc & Vách Đá (Procedural Terracing & Cliffs)
## Thuộc Phân hệ 02 trong quy trình 16 bước phát sinh sa bàn 3D (Procedural Diorama Engine).
## Chịu trách nhiệm lượng tử hóa cao độ thô thành 7 phân tầng rời rạc (Level 0..6),
## tính toán ma trận độ dốc lân cận 4 hướng, phát hiện toàn bộ mép vách đá khâu lưới
## và lập mặt nạ cho phép xây dựng công trình trên vùng đất đồng bằng bằng phẳng.

# ------------------------------------------------------------------------------
# 1. Điểm Đầu Vào Chính (Main Entry Point)
# ------------------------------------------------------------------------------

## Thực thi quy trình lượng tử hóa địa hình và trích xuất đặc tả vách đá
static func generate(context: MapGenContext, config: MapGenConfig) -> void:
	if context == null or config == null:
		push_error("TerraceGenerator.generate(): context hoặc config mang giá trị null!")
		return
		
	# Bước 1: Lượng tử hóa cao độ số thực [0.0, 1.0] thành 7 phân tầng nguyên [0..6]
	_quantize_elevation(context, config)
	
	# Bước 2: Tính toán ma trận sai phân độ dốc và phát hiện các mép vách đá
	_compute_slopes_and_cliffs(context, config)
	
	# Bước 3: Đánh giá và lập ma trận phân định ô đất cho phép xây dựng (buildable_mask)
	_evaluate_buildable_mask(context, config)

# ------------------------------------------------------------------------------
# 2. Các Thuật Toán Thành Phần (Sub-Algorithms)
# ------------------------------------------------------------------------------

## Bước 1: Lượng tử hóa cao độ liên tục từ raw_height_map sang elevation_levels
## Áp dụng công thức làm tròn phân đoạn chuẩn: Level = clamp(round(H * (N - 1)), 0, N - 1)
static func _quantize_elevation(context: MapGenContext, config: MapGenConfig) -> void:
	var total: int = context.total_cells
	var levels_count: int = config.terrain_levels
	var max_level: int = maxi(1, levels_count - 1)
	
	for i in range(total):
		var raw_h: float = context.raw_height_map[i]
		var quantized_lvl: int = int(clampi(int(round(raw_h * float(max_level))), 0, max_level))
		context.elevation_levels[i] = quantized_lvl

## Bước 2: Duyệt ma trận 4 hướng Von Neumann để tính sai phân độ dốc và phát hiện vách đá
static func _compute_slopes_and_cliffs(context: MapGenContext, _config: MapGenConfig) -> void:
	var width: int = context.width
	var height: int = context.height
	var dirs: Array[Vector2i] = MapGenConstants.NEIGHBOR_OFFSETS_4
	
	context.cliff_specs.clear()
	
	for y in range(height):
		for x in range(width):
			var idx: int = context.get_index(x, y)
			var current_lvl: int = context.elevation_levels[idx]
			var max_delta: int = 0
			
			for d_idx in range(dirs.size()):
				var d: Vector2i = dirs[d_idx]
				var nx: int = x + d.x
				var ny: int = y + d.y
				
				# Bỏ qua các lân cận nằm ngoài biên bản đồ sa bàn
				if not context.is_inside(nx, ny):
					continue
					
				var neighbor_idx: int = context.get_index(nx, ny)
				var neighbor_lvl: int = context.elevation_levels[neighbor_idx]
				var delta: int = current_lvl - neighbor_lvl
				var abs_delta: int = absi(delta)
				
				if abs_delta > max_delta:
					max_delta = abs_delta
				
				# Khi ô hiện tại cao hơn ô lân cận -> xuất hiện khoảng trống cần cắm vách đá
				if delta > 0:
					context.cliff_specs.append({
						"cell": Vector2i(x, y),
						"coord": Vector2i(x, y),
						"direction_idx": d_idx,
						"face": d_idx,
						"step_difference": delta,
						"height_steps": delta,
						"from_level": current_lvl,
						"to_level": neighbor_lvl
					})
			
			context.slope_map[idx] = float(max_delta)

## Bước 3: Xác định các ô đất phẳng tuyệt đối tại tầng đồng bằng cho phép đặt công trình
static func _evaluate_buildable_mask(context: MapGenContext, config: MapGenConfig) -> void:
	var total: int = context.total_cells
	var target_elevation: int = config.base_elevation
	
	for i in range(total):
		var lvl: int = context.elevation_levels[i]
		var slope: float = context.slope_map[i]
		
		# Điều kiện xây dựng: Nằm trên tầng đồng bằng trung tâm (Level 2) và phẳng tuyệt đối (Slope = 0.0)
		var can_build: bool = (lvl == target_elevation and is_zero_approx(slope))
		context.buildable_mask[i] = 1 if can_build else 0
