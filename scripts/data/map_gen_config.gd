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
@export var cell_size: float = 2.0

# ------------------------------------------------------------------------------
# 2. Địa Hình & Noise (Terrain & Noise)
# ------------------------------------------------------------------------------
@export_group("2. Terrain & Noise")
@export var noise_scale: float = 0.035
@export var noise_octaves: int = 4
@export var terrain_levels: int = 7
@export_range(0.0, 1.0) var terrace_strength: float = 0.85

# ------------------------------------------------------------------------------
# 3. Khu Vực Vương Quốc Xây Dựng (Playable Area)
# ------------------------------------------------------------------------------
@export_group("3. Playable Area")
@export var playable_grid_size: Vector2i = Vector2i(20, 20)
@export var playable_origin: Vector2i = Vector2i(8, 7)
@export var playable_core_radius: float = 7.0
@export var playable_falloff_radius: float = 11.0
@export_range(0.0, 1.0) var flatness_strength: float = 0.92
@export var base_elevation: int = 2

# ------------------------------------------------------------------------------
# 4. Vành Đai Núi Hậu Cảnh (Mountains & Rim)
# ------------------------------------------------------------------------------
@export_group("4. Mountains & Rim")
@export var border_width: float = 6.0
@export_range(0.0, 1.0) var edge_mountain_strength: float = 0.60

# ------------------------------------------------------------------------------
# 5. Hệ Thống Thủy Văn & Sông Ngòi (River System)
# ------------------------------------------------------------------------------
@export_group("5. River System")
@export var river_enabled: bool = true
@export var river_width: float = 2.2
@export var river_depth: float = 1.0
@export var river_bank_width: float = 1.2
@export var river_start_x: float = 5.0
@export var river_bridge_x: float = 5.0

# ------------------------------------------------------------------------------
# 6. Thảm Thực Vật & Rải Đối Tượng (Foliage & Scattering)
# ------------------------------------------------------------------------------
@export_group("6. Foliage & Scattering")
@export_range(0.0, 1.0) var forest_density: float = 0.40
@export var cluster_scale: float = 0.08
@export var min_tree_distance: float = 1.5
@export var min_rock_distance: float = 2.0

# ------------------------------------------------------------------------------
# 7. Mạng Lưới Tuyến Đường (Roads & Pathfinding Cost)
# ------------------------------------------------------------------------------
@export_group("7. Roads")
@export var slope_cost_penalty: float = 4.0
@export var forest_cost_penalty: float = 3.0
