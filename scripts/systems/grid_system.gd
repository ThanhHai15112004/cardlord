@tool
class_name GridSystem
extends Node

## Hệ thống Lưới Ô cờ Logic (Grid System)
## Quản lý ma trận tọa độ Vector2i, kích thước ô cờ và trạng thái chiếm dụng

signal cell_hovered(grid_pos: Vector2i, is_valid: bool)
signal cell_selected(grid_pos: Vector2i, is_valid: bool)
signal cell_occupied_changed(grid_pos: Vector2i, occupied_by: Node)

@export var grid_size: Vector2i = Vector2i(36, 36)
@export var cell_size: float = 2.0
@export var grid_origin: Vector3 = Vector3.ZERO

## Ma trận lưu trạng thái các ô: Dictionary[Vector2i, Dictionary]
## Cấu trúc mỗi ô:
## {
##   "tile": TerrainTile,
##   "obstacle": ResourceNode,
##   "building": BuildingEntity,
##   "is_buildable": bool
## }
var _grid_data: Dictionary = {}

func _ready() -> void:
	initialize_grid()

func initialize_grid() -> void:
	_grid_data.clear()
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			_grid_data[pos] = {
				"tile": null,
				"obstacle": null,
				"building": null,
				"is_buildable": true,
				"elevation": 2,
				"slope": 0.0
			}

## Chuyển đổi tọa độ thế giới 3D sang tọa độ lưới 2D (Vector2i)
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var local_pos = world_pos - grid_origin
	var gx = int(floor((local_pos.x + cell_size * 0.5) / cell_size))
	var gy = int(floor((local_pos.z + cell_size * 0.5) / cell_size))
	return Vector2i(gx, gy)

## Chuyển đổi tọa độ lưới 2D sang tọa độ thế giới 3D (Vector3)
func grid_to_world(grid_pos: Vector2i, height: float = 0.0) -> Vector3:
	var wx = grid_origin.x + float(grid_pos.x) * cell_size
	var wz = grid_origin.z + float(grid_pos.y) * cell_size
	return Vector3(wx, height, wz)

## Kiểm tra tọa độ có nằm trong phạm vi bản đồ không
func is_inside_grid(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y

## Kiểm tra ô có sẵn sàng để đặt công trình không
func is_cell_free_for_building(grid_pos: Vector2i) -> bool:
	if not is_inside_grid(grid_pos):
		return false
	var cell = _grid_data.get(grid_pos, null)
	if cell == null:
		return false
	# Không thể xây nếu ô bị cấm xây (sông nước/đường mòn), có vật cản, đã có nhà,
	# hoặc nằm ngoài tầng đồng bằng Level 2 hay có độ dốc chênh lệch
	return (
		cell["is_buildable"]
		and cell["obstacle"] == null
		and cell["building"] == null
		and cell.get("elevation", 2) == 2
		and is_zero_approx(cell.get("slope", 0.0))
	)

## Lấy tầng cao độ của một ô (0..6)
func get_cell_elevation(grid_pos: Vector2i) -> int:
	var cell = _grid_data.get(grid_pos, null)
	if cell:
		return cell.get("elevation", 2)
	return 2

## Lấy độ dốc cục bộ của một ô
func get_cell_slope(grid_pos: Vector2i) -> float:
	var cell = _grid_data.get(grid_pos, null)
	if cell:
		return cell.get("slope", 0.0)
	return 0.0

## Đồng bộ toàn bộ dữ liệu địa hình (Elevation, Slope, Buildable) từ MapGenContext vào GridSystem
func sync_from_map_context(context: MapGenContext, config: MapGenConfig) -> void:
	if context == null or config == null:
		return
		
	grid_size = config.playable_grid_size
	cell_size = config.cell_size
	grid_origin = Vector3(float(config.playable_origin.x) * cell_size, 0.0, float(config.playable_origin.y) * cell_size)
	initialize_grid()
	
	var p_orig: Vector2i = config.playable_origin
	var p_size: Vector2i = config.playable_grid_size
	
	for py in range(p_size.y):
		for px in range(p_size.x):
			var local_coord = Vector2i(px, py)
			var world_x = p_orig.x + px
			var world_y = p_orig.y + py
			var world_idx = context.get_index(world_x, world_y)
			
			var lvl: int = context.elevation_levels[world_idx]
			var slope: float = context.slope_map[world_idx]
			var is_water: bool = (context.water_zones[world_idx] == MapGenConstants.WaterZone.WATER)
			var is_road: bool = context.road_nodes.has(Vector2i(world_x, world_y))
			
			var can_build: bool = (lvl == config.base_elevation and is_zero_approx(slope) and not is_water and not is_road)
			
			if _grid_data.has(local_coord):
				_grid_data[local_coord]["elevation"] = lvl
				_grid_data[local_coord]["slope"] = slope
				_grid_data[local_coord]["is_buildable"] = can_build

## Đăng ký một TerrainTile vào hệ thống
func register_tile(grid_pos: Vector2i, tile: Node, is_buildable: bool = true) -> void:
	if not is_inside_grid(grid_pos):
		return
	_grid_data[grid_pos]["tile"] = tile
	_grid_data[grid_pos]["is_buildable"] = is_buildable

## Đăng ký vật cản tự nhiên (Cây, Đá) vào ô
func register_obstacle(grid_pos: Vector2i, obstacle: Node) -> void:
	if not is_inside_grid(grid_pos):
		return
	_grid_data[grid_pos]["obstacle"] = obstacle
	cell_occupied_changed.emit(grid_pos, obstacle)

## Hủy đăng ký vật cản (khi cây hoặc đá bị khai thác hết)
func unregister_obstacle(grid_pos: Vector2i) -> void:
	if not is_inside_grid(grid_pos):
		return
	_grid_data[grid_pos]["obstacle"] = null
	cell_occupied_changed.emit(grid_pos, null)

## Đăng ký công trình xây dựng vào ô
func register_building(grid_pos: Vector2i, building: Node) -> void:
	if not is_inside_grid(grid_pos):
		return
	_grid_data[grid_pos]["building"] = building
	cell_occupied_changed.emit(grid_pos, building)

## Hủy đăng ký công trình
func unregister_building(grid_pos: Vector2i) -> void:
	if not is_inside_grid(grid_pos):
		return
	_grid_data[grid_pos]["building"] = null
	cell_occupied_changed.emit(grid_pos, null)

## Lấy thông tin chi tiết của một ô
func get_cell_info(grid_pos: Vector2i) -> Dictionary:
	return _grid_data.get(grid_pos, {})

## Lấy các ô lân cận (4 hướng)
func get_adjacent_cells(grid_pos: Vector2i) -> Array[Vector2i]:
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var result: Array[Vector2i] = []
	for d in dirs:
		var neighbor = grid_pos + d
		if is_inside_grid(neighbor):
			result.append(neighbor)
	return result
