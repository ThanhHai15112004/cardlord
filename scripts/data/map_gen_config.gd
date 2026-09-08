@tool
class_name MapGenConfig
extends Resource

## Cấu Hình Sinh Bản Đồ Sa Bàn (Procedural Diorama Map Generation Config)
## Chứa toàn bộ các tham số cấu hình (tweakable) để Game Designer tinh chỉnh
## và lưu trữ thành các Preset Resource (.tres) trong thư mục data/presets/.

# ------------------------------------------------------------------------------
# 1. Cấu Hình Chung (General Settings)
# ------------------------------------------------------------------------------
@export_group("1. General")
@warning_ignore("shadowed_global_identifier")
@export var seed: int = 124856
@export var map_size: Vector2i = Vector2i(36, 36)
@export_range(1.0, 5.0, 0.5) var cell_size: float = 2.0

# ------------------------------------------------------------------------------
# 2. Địa Hình & Noise (Terrain & Noise)
# ------------------------------------------------------------------------------
@export_group("2. Terrain & Noise")
@export_range(0.005, 0.150, 0.005) var noise_scale: float = 0.035
@export_range(1, 6, 1) var noise_octaves: int = 4
@export_range(3, 10, 1) var terrain_levels: int = 7
@export_range(0.0, 1.0, 0.01) var terrace_strength: float = 0.85

# ------------------------------------------------------------------------------
# 3. Khu Vực Vương Quốc Xây Dựng (Playable Area)
# ------------------------------------------------------------------------------
@export_group("3. Playable Area")
@export var playable_grid_size: Vector2i = Vector2i(20, 20)
@export var playable_origin: Vector2i = Vector2i(8, 7)
@export_range(2.0, 15.0, 0.5) var playable_core_radius: float = 7.0
@export_range(4.0, 20.0, 0.5) var playable_falloff_radius: float = 11.0
@export_range(0.0, 1.0, 0.01) var flatness_strength: float = 0.92
@export_range(0, 6, 1) var base_elevation: int = 2

# ------------------------------------------------------------------------------
# 4. Vành Đai Núi Hậu Cảnh (Mountains & Rim)
# ------------------------------------------------------------------------------
@export_group("4. Mountains & Rim")
@export_range(2.0, 12.0, 0.5) var border_width: float = 6.0
@export_range(0.0, 1.0, 0.01) var edge_mountain_strength: float = 0.60

# ------------------------------------------------------------------------------
# 5. Hệ Thống Thủy Văn & Sông Ngòi (River System)
# ------------------------------------------------------------------------------
@export_group("5. River System")
@export var river_enabled: bool = true
@export_range(0.5, 6.0, 0.1) var river_width: float = 2.2
@export_range(0.2, 3.0, 0.1) var river_depth: float = 1.0
@export_range(0.5, 4.0, 0.1) var river_bank_width: float = 1.2
@export var river_start_x: float = 5.0
@export var river_bridge_x: float = 5.0

# ------------------------------------------------------------------------------
# 6. Thảm Thực Vật & Rải Đối Tượng (Foliage & Scattering)
# ------------------------------------------------------------------------------
@export_group("6. Foliage & Scattering")
@export_range(0.0, 1.0, 0.01) var forest_density: float = 0.40
@export_range(0.02, 0.30, 0.01) var cluster_scale: float = 0.08
@export_range(0.8, 4.0, 0.1) var min_tree_distance: float = 1.5
@export_range(0.8, 5.0, 0.1) var min_rock_distance: float = 2.0

# ------------------------------------------------------------------------------
# 7. Mạng Lưới Tuyến Đường (Roads & Pathfinding Cost)
# ------------------------------------------------------------------------------
@export_group("7. Roads")
@export_range(1.0, 10.0, 0.5) var slope_cost_penalty: float = 4.0
@export_range(1.0, 10.0, 0.5) var forest_cost_penalty: float = 3.0

# ------------------------------------------------------------------------------
# 8. Phương Thức Tiện Ích & Ràng Buộc Hình Học (Helpers & Validations)
# ------------------------------------------------------------------------------

## Tổng số ô cờ trên sa bàn (ví dụ: 36 x 36 = 1296)
func get_total_cells() -> int:
	return map_size.x * map_size.y

## Kích thước thực tế của toàn bộ sa bàn theo mét (ví dụ: 72.0m x 72.0m)
func get_world_size_meters() -> Vector2:
	return Vector2(map_size) * cell_size

## Tọa độ tâm hình học của vùng xây dựng lãnh địa (Floating-point)
func get_playable_center() -> Vector2:
	return Vector2(playable_origin) + Vector2(playable_grid_size) * 0.5

## Kiểm tra một ô cờ (grid_coord) có nằm trọn trong vùng quy hoạch lãnh địa không
func is_coord_in_playable(coord: Vector2i) -> bool:
	return (
		coord.x >= playable_origin.x
		and coord.x < playable_origin.x + playable_grid_size.x
		and coord.y >= playable_origin.y
		and coord.y < playable_origin.y + playable_grid_size.y
	)

## Kiểm tra tính hợp lệ toán học của các tham số cấu hình trước khi chạy pipeline
func validate_config() -> bool:
	var is_valid: bool = true
	
	if playable_core_radius >= playable_falloff_radius:
		push_warning("MapGenConfig: playable_core_radius (%.1f) phải nhỏ hơn playable_falloff_radius (%.1f) để smoothstep hoạt động chính xác!" % [playable_core_radius, playable_falloff_radius])
		is_valid = false
		
	if playable_origin.x + playable_grid_size.x > map_size.x or playable_origin.y + playable_grid_size.y > map_size.y:
		push_warning("MapGenConfig: Vùng lãnh địa xây dựng (playable_origin + playable_grid_size) vượt quá map_size!")
		is_valid = false
		
	if map_size.x <= 0 or map_size.y <= 0:
		push_warning("MapGenConfig: map_size phải có giá trị dương!")
		is_valid = false
		
	return is_valid
