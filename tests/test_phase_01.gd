extends Node

## Kịch bản kiểm thử tự động cho Phase 01: Core Foundation & Data Context
## Mở scene tests/test_phase_01.tscn và bấm phím F6 trong Godot Editor để chạy.

@onready var result_label: Label = $CanvasLayer/Panel/ResultLabel

func _ready() -> void:
	run_all_tests()
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func run_all_tests() -> void:
	print("==================================================")
	print(">>> BẮT ĐẦU KIỂM THỬ AUTOMATED TEST: PHASE 01")
	print("==================================================")
	
	var log_lines: Array[String] = []
	
	# 1. Nạp Preset cấu hình mặc định
	var config: MapGenConfig = load("res://data/presets/default_kingdom_map.tres")
	if not config:
		var err_msg = "❌ [FAILED] Không thể nạp preset res://data/presets/default_kingdom_map.tres!"
		printerr(err_msg)
		_show_result(false, err_msg)
		return
		
	var step1 = "✔ 1. Nạp MapGenConfig thành công: map_size = %s, cell_size = %.1fm" % [config.map_size, config.cell_size]
	print(step1)
	log_lines.append(step1)
	
	# 2. Khởi tạo Ngữ cảnh MapGenContext
	var ctx = MapGenContext.new(config)
	var step2 = "✔ 2. Khởi tạo MapGenContext thành công!"
	print(step2)
	log_lines.append(step2)
	
	# 3. Kiểm tra kích thước toàn bộ các mảng phẳng (N = 36 x 36 = 1296)
	var expected_cells: int = config.map_size.x * config.map_size.y
	assert(ctx.total_cells == expected_cells, "total_cells phải là 1296")
	assert(ctx.raw_height_map.size() == expected_cells, "raw_height_map size lỗi")
	assert(ctx.elevation_levels.size() == expected_cells, "elevation_levels size lỗi")
	assert(ctx.slope_map.size() == expected_cells, "slope_map size lỗi")
	assert(ctx.buildable_mask.size() == expected_cells, "buildable_mask size lỗi")
	assert(ctx.water_zones.size() == expected_cells, "water_zones size lỗi")
	assert(ctx.bank_rotations.size() == expected_cells, "bank_rotations size lỗi")
	assert(ctx.foliage_density_map.size() == expected_cells, "foliage_density_map size lỗi")
	assert(ctx.playable_mask.size() == expected_cells, "playable_mask size lỗi")
	assert(ctx.border_mask.size() == expected_cells, "border_mask size lỗi")
	assert(ctx.mountain_mask.size() == expected_cells, "mountain_mask size lỗi")
	assert(ctx.river_distance_map.size() == expected_cells, "river_distance_map size lỗi")
	
	var step3 = "✔ 3. Đã xác minh: TOÀN BỘ 11 mảng phẳng đều được cấp phát chính xác %d phần tử!" % expected_cells
	print(step3)
	log_lines.append(step3)
	
	# 4. Kiểm tra tiện ích tọa độ 2D <-> 3D
	var test_coord = Vector2i(10, 15)
	var world_pos = ctx.grid_to_world(test_coord, 1.5)
	assert(world_pos == Vector3(20.0, 1.5, 30.0), "grid_to_world tính sai!")
	var back_coord = ctx.world_to_grid(world_pos)
	assert(back_coord == test_coord, "world_to_grid tính sai!")
	
	var step4 = "✔ 4. Tiện ích tọa độ 2D <-> 3D chuẩn xác 100%!"
	print(step4)
	log_lines.append(step4)
	
	# 5. Kiểm tra hàm validate_config()
	assert(config.validate_config() == true, "validate_config phải trả về true")
	var step5 = "✔ 5. Hàm validate_config() hoạt động chuẩn xác!"
	print(step5)
	log_lines.append(step5)
	
	# 6. Kiểm tra các hằng số MapGenConstants
	assert(MapGenConstants.ELEVATION_Y_OFFSETS[MapGenConstants.ElevationLevel.GRASSLAND] == 0.50)
	assert(MapGenConstants.NEIGHBOR_OFFSETS_4.size() == 4)
	assert(MapGenConstants.NEIGHBOR_OFFSETS_8.size() == 8)
	var step6 = "✔ 6. Bảng hằng số MapGenConstants sẵn sàng và chính xác!"
	print(step6)
	log_lines.append(step6)
	
	print("==================================================")
	print("🎉 TẤT CẢ TIÊU CHÍ PHASE 01 ĐỀU ĐẠT CHUẨN (PASSED)!")
	print("==================================================")
	
	_show_result(true, "\n".join(log_lines))

func _show_result(passed: bool, details: String) -> void:
	if result_label:
		if passed:
			result_label.text = "🎉 PHASE 01 AUTOMATED TEST: PASSED (100% THÀNH CÔNG)\n\n" + details
			result_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			result_label.text = "❌ PHASE 01 AUTOMATED TEST: FAILED\n\n" + details
			result_label.modulate = Color(1.0, 0.3, 0.3)
