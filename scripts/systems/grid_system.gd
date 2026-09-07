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
				"is_buildable": true
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
	# Không thể xây nếu ô bị cấm xây (như sông nước), có vật cản chưa khai thác hoặc đã có nhà
	return cell["is_buildable"] and cell["obstacle"] == null and cell["building"] == null

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
