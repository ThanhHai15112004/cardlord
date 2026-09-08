@tool
class_name MacroLayoutGenerator
extends RefCounted

## Máy Phát Sinh Bố Cục Vĩ Mô & Cao Độ Sa Bàn (Macro Layout & Height Generator)
## Phụ trách các bước 1 -> 5 và bước 7 trong Pipeline 16 bước:
## 1. SDF Border & Playable Masks (Mặt nạ không gian)
## 2. FastNoiseLite FBM + Ridged Multifractal Noise (Sóng núi & Địa hình nền)
## 3. Edge Mountain Rim Elevation Boost (Nâng vách núi bao bọc mép sa bàn)
## 4. Playable Area Flattening (San phẳng tâm vương quốc về cao độ chuẩn Level 2)

## Cao độ chuẩn hóa của tầng trung tâm (Level 2 trong thang 0..6: 2.0 / 6.0 = 0.333333)
const PLAYABLE_TARGET_HEIGHT: float = 0.333333

## Hàm thực thi chính của phân hệ Macro Layout & Height Generator
static func generate(context: MapGenContext, config: MapGenConfig) -> void:
	if context == null or config == null:
		push_error("MacroLayoutGenerator: context hoặc config bị null!")
		return
		
	var width: int = context.width
	var height: int = context.height
	var center_pos: Vector2 = config.get_playable_center()
	
	# --------------------------------------------------------------------------
	# 1. Khởi tạo & Cấu hình 2 Bộ Sinh Noise Độc Lập
	# --------------------------------------------------------------------------
	
	# A. FBM Noise: Tạo cấu trúc địa hình nền mềm mại, nhấp nhô tự nhiên
	var fbm_noise: FastNoiseLite = FastNoiseLite.new()
	fbm_noise.seed = config.seed
	fbm_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fbm_noise.frequency = config.noise_scale
	fbm_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	fbm_noise.fractal_octaves = config.noise_octaves
	fbm_noise.fractal_lacunarity = 2.0
	fbm_noise.fractal_gain = 0.5
	
	# B. Ridged Noise: Tạo các nếp gãy và sống núi đá sắc nhọn
	var ridge_noise: FastNoiseLite = FastNoiseLite.new()
	ridge_noise.seed = config.seed + 101 # Seed độc lập để tránh tương quan sóng
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.frequency = config.noise_scale * 1.5
	
	# Tham số giải thuật từ Config
	var border_w: float = config.border_width
	var edge_strength: float = config.edge_mountain_strength
	var r_core: float = config.playable_core_radius
	var r_falloff: float = config.playable_falloff_radius
	var flatness: float = config.flatness_strength
	
	# --------------------------------------------------------------------------
	# 2. Vòng Lặp Tính Toán Ma Trận Cao Độ 36x36
	# --------------------------------------------------------------------------
	for y in range(height):
		for x in range(width):
			var idx: int = context.get_index(x, y)
			
			# A. Tính SDF Border Mask & Nâng Vành Đai Núi (Edge Mountain Rim)
			var min_dist_edge: int = mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
			var border_factor: float = 1.0 - clampf(float(min_dist_edge) / border_w, 0.0, 1.0)
			var edge_boost: float = pow(border_factor, 1.8) * edge_strength
			
			# B. Tính SDF Playable Mask (Trọng số trung tâm vương quốc)
			var dist_center: float = Vector2(float(x), float(y)).distance_to(center_pos)
			var playable_factor: float = 1.0 - smoothstep(r_core, r_falloff, dist_center)
			
			# C. Lấy mẫu Noise
			var n_fbm: float = (fbm_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5 # Chuẩn hóa về [0.0, 1.0]
			var n_raw_ridge: float = ridge_noise.get_noise_2d(float(x), float(y))
			var n_ridge: float = pow(1.0 - absf(n_raw_ridge), 2.0) # Tạo đỉnh nhọn đơn cực [0.0, 1.0]
			
			# D. Tổng hợp cao độ thô ban đầu
			# Giảm ảnh hưởng của Noise tại vùng trung tâm để chuẩn bị san phẳng
			var noise_blend: float = (n_fbm * 0.45 + n_ridge * 0.25) * (1.0 - playable_factor * 0.60)
			var h: float = clampf(noise_blend + edge_boost, 0.0, 1.0)
			
			# E. San phẳng lãnh địa xây dựng (Playable Flattening)
			h = lerpf(h, PLAYABLE_TARGET_HEIGHT, playable_factor * flatness)
			
			# F. Phòng thủ chống lỗ thủng lòng chảo (Crater Safeguard)
			if playable_factor > 0.5:
				h = maxf(h, PLAYABLE_TARGET_HEIGHT - 0.05)
				
			# G. Ghi kết quả vào Ngữ cảnh Context
			context.raw_height_map[idx] = clampf(h, 0.0, 1.0)
			context.border_mask[idx] = border_factor
			context.playable_mask[idx] = playable_factor
