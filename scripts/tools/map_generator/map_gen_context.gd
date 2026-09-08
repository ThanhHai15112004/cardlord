@tool
class_name MapGenContext
extends RefCounted

## Ngữ Cảnh Dữ Liệu Bộ Nhớ Bản Đồ (Procedural Map Generation Context)
## Lưu trữ toàn bộ ma trận mảng phẳng (Flat Packed Arrays) và danh mục thực thể
## xuyên suốt quy trình 16 bước phát sinh sa bàn 3D (Procedural Diorama Pipeline).

# ------------------------------------------------------------------------------
# 1. Thuộc Tính Quy Mô & Cấu Hình
# ------------------------------------------------------------------------------

var config: MapGenConfig
var width: int = 36
var height: int = 36
var cell_size: float = 2.0
var total_cells: int = 1296

# ------------------------------------------------------------------------------
# 2. Các Ma Trận Dữ Liệu Mảng Phẳng (Flat Packed Arrays - Kích thước N = W * H)
# ------------------------------------------------------------------------------

## Cao độ liên tục thô sau khi tổng hợp Noise và Masks (0.0..1.0)
var raw_height_map: PackedFloat32Array

## Phân tầng cao độ nguyên rời rạc (Level 0..6)
var elevation_levels: PackedInt32Array

## Ma trận độ dốc (Gradient delta tối đa giữa các ô lân cận)
var slope_map: PackedFloat32Array

## Mặt nạ phân loại đất xây dựng (1: Cho phép đặt công trình, 0: Cấm xây)
var buildable_mask: PackedByteArray

## Đới phân loại thủy văn (0: Land, 1: Bank/Bờ kè, 2: Water/Lòng sông)
var water_zones: PackedByteArray

## Góc xoay Y (radian) của từng bờ kè đá hướng dốc xuống lòng sông
var bank_rotations: PackedFloat32Array

## Ma trận mật độ rừng tự nhiên tổng hợp từ Simplex Noise (0.0..1.0)
var foliage_density_map: PackedFloat32Array

# ------------------------------------------------------------------------------
# 3. Các Mặt Nạ Không Gian Phụ Trợ (Intermediate Spatial Masks)
# ------------------------------------------------------------------------------

## Mặt nạ vùng lãnh địa trung tâm (1.0 ở tâm -> 0.0 ở biên)
var playable_mask: PackedFloat32Array

## Mặt nạ cự ly biên (càng sát mép giá trị càng tiến tới 1.0)
var border_mask: PackedFloat32Array

## Mặt nạ vùng ưu tiên núi cao
var mountain_mask: PackedFloat32Array

## Khoảng cách từ từng ô tới spline đường cong dòng sông
var river_distance_map: PackedFloat32Array

# ------------------------------------------------------------------------------
# 4. Danh Mục Đăng Ký Thực Thể (Entity Registries & Collections)
# ------------------------------------------------------------------------------

## Bảng lưu trữ tọa độ các điểm mấu chốt POI (Key: MapGenConstants.POIType, Value: Vector2i hoặc Array[Vector2i])
var poi_registry: Dictionary = {}

## Mạng lưới các ô cờ thuộc đường mòn (Key: Vector2i, Value: Dictionary chứa bitmask, node_type, rotation_y)
var road_nodes: Dictionary = {}

## Danh sách đặc tả các vách đá cần cắm model khâu lưới (Cliff Stitching)
var cliff_specs: Array[Dictionary] = []

## Tập hợp Transform3D của toàn bộ thảm thực vật/đá sau Poisson Disk Sampling
var foliage_transforms: Array[Transform3D] = []

## Phân loại danh sách Transform3D theo từng chủng loại Asset để đưa vào MultiMesh
var categorized_foliage: Dictionary = {
	"tree_1": [] as Array[Transform3D],
	"tree_2": [] as Array[Transform3D],
	"rock_large": [] as Array[Transform3D],
	"rock_med": [] as Array[Transform3D],
	"forest_cluster": [] as Array[Transform3D]
}

# ------------------------------------------------------------------------------
# 5. Khởi Tạo & Cấp Phát Bộ Nhớ (Initialization & Allocation)
# ------------------------------------------------------------------------------

func _init(p_config: MapGenConfig = null) -> void:
	if p_config != null:
		config = p_config
		width = config.map_size.x
		height = config.map_size.y
		cell_size = config.cell_size
	else:
		config = MapGenConfig.new()
		width = 36
		height = 36
		cell_size = 2.0
		
	total_cells = width * height
	allocate_memory()

## Cấp phát trước kích thước và khởi tạo giá trị an toàn cho toàn bộ mảng phẳng
func allocate_memory() -> void:
	raw_height_map.resize(total_cells)
	raw_height_map.fill(0.0)
	
	elevation_levels.resize(total_cells)
	elevation_levels.fill(MapGenConstants.ElevationLevel.GRASSLAND) # Mặc định Level 2
	
	slope_map.resize(total_cells)
	slope_map.fill(0.0)
	
	buildable_mask.resize(total_cells)
	buildable_mask.fill(1) # Mặc định cho phép xây
	
	water_zones.resize(total_cells)
	water_zones.fill(MapGenConstants.WaterZone.LAND) # Mặc định là đất khô
	
	bank_rotations.resize(total_cells)
	bank_rotations.fill(0.0)
	
	foliage_density_map.resize(total_cells)
	foliage_density_map.fill(0.0)
	
	# Mảng trung gian
	playable_mask.resize(total_cells)
	playable_mask.fill(0.0)
	
	border_mask.resize(total_cells)
	border_mask.fill(0.0)
	
	mountain_mask.resize(total_cells)
	mountain_mask.fill(0.0)
	
	river_distance_map.resize(total_cells)
	river_distance_map.fill(9999.0)
	
	# Xóa danh mục thực thể
	poi_registry.clear()
	road_nodes.clear()
	cliff_specs.clear()
	foliage_transforms.clear()
	for key in categorized_foliage.keys():
		categorized_foliage[key].clear()

# ------------------------------------------------------------------------------
# 6. Các Phương Thức Tiện Ích Tọa Độ & Ánh Xạ Không Gian
# ------------------------------------------------------------------------------

## Tính chỉ số mảng phẳng 1D từ tọa độ 2D: y * width + x
func get_index(x: int, y: int) -> int:
	return y * width + x

## Chuyển chỉ số mảng phẳng 1D về tọa độ ô cờ Vector2i(x, y)
func get_coord(index: int) -> Vector2i:
	return Vector2i(index % width, index / width)

## Kiểm tra tọa độ (x, y) có nằm trong giới hạn bản đồ không
func is_inside(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

## Kiểm tra tọa độ Vector2i có nằm trong giới hạn bản đồ không
func is_inside_coord(coord: Vector2i) -> bool:
	return is_inside(coord.x, coord.y)

## Chuyển đổi tọa độ ô cờ 2D sang tọa độ thế giới 3D (Khớp với GridSystem)
func grid_to_world(coord: Vector2i, height_y: float = 0.0) -> Vector3:
	return Vector3(float(coord.x) * cell_size, height_y, float(coord.y) * cell_size)

## Chuyển đổi tọa độ thế giới 3D về tọa độ ô cờ 2D (Vector2i)
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var gx = int(floor((world_pos.x + cell_size * 0.5) / cell_size))
	var gz = int(floor((world_pos.z + cell_size * 0.5) / cell_size))
	return Vector2i(gx, gz)

# ------------------------------------------------------------------------------
# 7. Getters / Setters An Toàn Cho Dữ Liệu Địa Hình
# ------------------------------------------------------------------------------

## Lấy cao độ liên tục thô (an toàn ngoài biên)
func get_height(x: int, y: int) -> float:
	if not is_inside(x, y):
		return 0.0
	return raw_height_map[get_index(x, y)]

func set_height(x: int, y: int, val: float) -> void:
	if is_inside(x, y):
		raw_height_map[get_index(x, y)] = val

## Lấy tầng cao độ nguyên (0..6)
func get_elevation(x: int, y: int) -> int:
	if not is_inside(x, y):
		return MapGenConstants.ElevationLevel.GRASSLAND
	return elevation_levels[get_index(x, y)]

func set_elevation(x: int, y: int, lvl: int) -> void:
	if is_inside(x, y):
		elevation_levels[get_index(x, y)] = lvl

## Lấy độ cao trục Y thực tế thế giới thông qua bảng tra ELEVATION_Y_OFFSETS
func get_world_y_for_cell(x: int, y: int) -> float:
	var lvl = get_elevation(x, y)
	return MapGenConstants.ELEVATION_Y_OFFSETS.get(lvl, 0.50)

## Trạng thái cho phép xây dựng
func is_buildable(x: int, y: int) -> bool:
	if not is_inside(x, y):
		return false
	return buildable_mask[get_index(x, y)] == 1

func set_buildable(x: int, y: int, can_build: bool) -> void:
	if is_inside(x, y):
		buildable_mask[get_index(x, y)] = 1 if can_build else 0

## Trạng thái thủy văn (0: Land, 1: Bank, 2: Water)
func get_water_zone(x: int, y: int) -> int:
	if not is_inside(x, y):
		return MapGenConstants.WaterZone.LAND
	return water_zones[get_index(x, y)]

func set_water_zone(x: int, y: int, zone: int) -> void:
	if is_inside(x, y):
		water_zones[get_index(x, y)] = zone

## Độ dốc cục bộ
func get_slope(x: int, y: int) -> float:
	if not is_inside(x, y):
		return 0.0
	return slope_map[get_index(x, y)]

func set_slope(x: int, y: int, val: float) -> void:
	if is_inside(x, y):
		slope_map[get_index(x, y)] = val

## Mật độ rừng
func get_foliage_density(x: int, y: int) -> float:
	if not is_inside(x, y):
		return 0.0
	return foliage_density_map[get_index(x, y)]

func set_foliage_density(x: int, y: int, val: float) -> void:
	if is_inside(x, y):
		foliage_density_map[get_index(x, y)] = val

# ------------------------------------------------------------------------------
# 8. Tiện Ích Đăng Ký POI & Vách Đá (Registry Helpers)
# ------------------------------------------------------------------------------

## Đăng ký tọa độ POI đơn lẻ (ví dụ Castle, Bridge, Scout)
func register_poi(poi_type: int, coord: Vector2i) -> void:
	poi_registry[poi_type] = coord

## Đăng ký danh sách POI nhóm (ví dụ Quarries, Lumber clusters)
func register_poi_group(poi_type: int, coords: Array[Vector2i]) -> void:
	poi_registry[poi_type] = coords

## Lấy tọa độ POI đơn lẻ (trả về Vector2i(-1, -1) nếu không tìm thấy)
func get_poi_coord(poi_type: int) -> Vector2i:
	var val = poi_registry.get(poi_type, Vector2i(-1, -1))
	if val is Vector2i:
		return val
	return Vector2i(-1, -1)

## Thêm một đặc tả vách đá cần khâu lưới 3D
func add_cliff_spec(coord: Vector2i, face: int, from_lvl: int, to_lvl: int, world_transform: Transform3D) -> void:
	cliff_specs.append({
		"coord": coord,
		"face": face,
		"from_level": from_lvl,
		"to_level": to_lvl,
		"transform": world_transform
	})
