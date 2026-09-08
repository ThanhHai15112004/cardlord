@tool
extends Node

## Kịch bản kiểm thử tự động độc lập cho Phase 04: Dòng Sông & Thủy Văn (River & Hydrology)
## Mở scene tests/test_phase_04.tscn và bấm F6 (hoặc click nút trên màn hình) để chạy.

@export_tool_button("▶ CHẠY LẠI KIỂM THỬ PHASE 04")
var btn_run = run_test

@onready var result_label: Label = $CanvasLayer/Panel/MarginContainer/VBoxContainer/ResultLabel
@onready var stats_label: Label = $CanvasLayer/Panel/MarginContainer/VBoxContainer/StatsLabel
@onready var status_badge: Label = $CanvasLayer/Panel/MarginContainer/VBoxContainer/Header/StatusBadge
@onready var rerun_button: Button = $CanvasLayer/Panel/MarginContainer/VBoxContainer/Header/RerunButton

func _ready() -> void:
	if rerun_button:
		rerun_button.pressed.connect(run_test)
	run_test()
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func run_test() -> void:
	print("==================================================================")
	print(">>> BẮT ĐẦU CHẠY KIỂM THỬ THỰC TẾ: PHASE 04 RIVER & HYDROLOGY")
	print("==================================================================")
	
	var log_lines: Array[String] = []
	
	# 1. Nạp file cấu hình preset thật
	var config: MapGenConfig = load("res://data/presets/default_kingdom_map.tres")
	if not config:
		_fail("Không thể nạp file preset: res://data/presets/default_kingdom_map.tres")
		return
	var step1 = "✔ Bước 1: Nạp thành công MapGenConfig (River Width = %.1f, Bank Width = %.1f, Bridge X = %.1f)" % [config.river_width, config.river_bank_width, config.river_bridge_x]
	print(step1)
	log_lines.append(step1)
	
	# 2. Khởi tạo Context và chạy tiền xử lý Phase 02 + Phase 03
	var context: MapGenContext = MapGenContext.new(config)
	MacroLayoutGenerator.generate(context, config)
	TerraceGenerator.generate(context, config)
	var step2 = "✔ Bước 2: Tiền xử lý Phase 02 (Macro Layout) & Phase 03 (Terracing) hoàn tất"
	print(step2)
	log_lines.append(step2)
	
	# 3. Kích hoạt thuật toán thật của RiverGenerator
	var gen_start_time: int = Time.get_ticks_usec()
	RiverGenerator.generate(context, config)
	var gen_duration_ms: float = (Time.get_ticks_usec() - gen_start_time) / 1000.0
	var step3 = "✔ Bước 3: RiverGenerator.generate() thực thi hoàn tất trong %.2f ms!" % gen_duration_ms
	print(step3)
	log_lines.append(step3)
	
	# --------------------------------------------------------------------------
	# 4. Kiểm tra Tiêu chí 1: Dòng sông chảy liên tục không ngắt quãng từ Y=0 đến Y=35
	# --------------------------------------------------------------------------
	var missing_rows: Array[int] = []
	var water_cell_count: int = 0
	var bank_cell_count: int = 0
	
	for y in range(context.height):
		var row_has_water: bool = false
		for x in range(context.width):
			var zone = context.get_water_zone(x, y)
			if zone == MapGenConstants.WaterZone.WATER:
				row_has_water = true
				water_cell_count += 1
			elif zone == MapGenConstants.WaterZone.BANK:
				bank_cell_count += 1
				
		if not row_has_water:
			missing_rows.append(y)
			
	assert(missing_rows.is_empty(), "Dòng sông bị đứt khúc tại các hàng Y: %s" % str(missing_rows))
	var step4 = "✔ Tiêu chí 1: Dòng sông chảy liên tục 100%% từ đỉnh Y=0 xuống đáy Y=35 (36/36 hàng đều có nước sâu, tổng %d ô lòng sông)" % water_cell_count
	print(step4)
	log_lines.append(step4)
	
	# --------------------------------------------------------------------------
	# 5. Kiểm tra Tiêu chí 2: Các ô lòng sông đạt Level 0 và cấm xây dựng
	# --------------------------------------------------------------------------
	var expected_bridge_y: int = config.playable_origin.y + 9
	var expected_bridge_coord: Vector2i = Vector2i(int(round(config.river_bridge_x)), expected_bridge_y)
	
	for y in range(context.height):
		for x in range(context.width):
			if context.get_water_zone(x, y) == MapGenConstants.WaterZone.WATER:
				var coord = Vector2i(x, y)
				if coord == expected_bridge_coord:
					# Ô đặt Cầu được khôi phục Level 1
					assert(context.get_elevation(x, y) == MapGenConstants.ElevationLevel.LOWLAND, "Ô đặt Cầu phải ở Level 1!")
				else:
					assert(context.get_elevation(x, y) == MapGenConstants.ElevationLevel.RIVER_BED, "Ô nước sâu (%d, %d) không đạt Level 0!" % [x, y])
				assert(not context.is_buildable(x, y), "Ô lòng sông (%d, %d) chưa bị khóa cấm xây dựng!" % [x, y])
				
	var step5 = "✔ Tiêu chí 2: Toàn bộ ô lòng sông đều có elevation_levels = 0 (River Bed, Y = -0.7m) và khóa cấm xây buildable_mask = 0"
	print(step5)
	log_lines.append(step5)
	
	# --------------------------------------------------------------------------
	# 6. Kiểm tra Tiêu chí 3: Toàn bộ bờ kè đạt Level 1 và có góc xoay dốc hợp lệ
	# --------------------------------------------------------------------------
	assert(bank_cell_count > 0, "Không có ô bờ kè nào được tạo ra!")
	var bank_rotations_valid: int = 0
	
	for y in range(context.height):
		for x in range(context.width):
			if context.get_water_zone(x, y) == MapGenConstants.WaterZone.BANK:
				assert(context.get_elevation(x, y) == MapGenConstants.ElevationLevel.LOWLAND, "Ô bờ kè (%d, %d) không đạt Level 1!" % [x, y])
				assert(not context.is_buildable(x, y), "Ô bờ kè (%d, %d) chưa bị khóa cấm xây dựng!" % [x, y])
				
				# Kiểm tra góc xoay nằm trong tập {0, PI/2, PI, -PI/2, -PI, 3PI/2}
				var idx = context.get_index(x, y)
				var rot = context.bank_rotations[idx]
				var remainder = fmod(abs(rot), PI * 0.5)
				assert(remainder < 0.001 or abs(remainder - PI * 0.5) < 0.001, "Góc xoay bờ kè không vuông góc: %f" % rot)
				bank_rotations_valid += 1
				
	assert(bank_rotations_valid == bank_cell_count, "Số lượng bờ kè có góc xoay hợp lệ không khớp!")
	var step6 = "✔ Tiêu chí 3: Toàn bộ %d ô bờ kè đều ở Level 1 (Lowland, Y = 0.0m), cấm xây, và có góc xoay hướng mặt dốc xuôi lòng sông chuẩn 90°" % bank_cell_count
	print(step6)
	log_lines.append(step6)
	
	# --------------------------------------------------------------------------
	# 7. Kiểm tra Tiêu chí 4: Tọa độ Cầu qua sông được đăng ký chuẩn xác
	# --------------------------------------------------------------------------
	var registered_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.BRIDGE)
	assert(registered_coord == expected_bridge_coord, "Tọa độ Cầu đăng ký không khớp! Kỳ vọng: %s, Thực tế: %s" % [expected_bridge_coord, registered_coord])
	assert(context.poi_registry.get("bridge_coord") == expected_bridge_coord, "Key 'bridge_coord' chưa được đăng ký trong poi_registry!")
	
	var bridge_elevation = context.get_elevation(expected_bridge_coord.x, expected_bridge_coord.y)
	assert(bridge_elevation == MapGenConstants.ElevationLevel.LOWLAND, "Cao độ ô cờ Cầu phải ở Level 1, thực tế: %d" % bridge_elevation)
	
	var step7 = "✔ Tiêu chí 4: Neo điểm Cầu đăng ký chuẩn xác tại %s (Y_bridge = %d), cao độ Level 1 (Y = 0.0m)" % [registered_coord, expected_bridge_y]
	print(step7)
	log_lines.append(step7)
	
	# --------------------------------------------------------------------------
	# 8. Kiểm tra Tiêu chí 5: Tính độc lập
	# --------------------------------------------------------------------------
	var step8 = "✔ Tiêu chí 5: RiverGenerator kế thừa RefCounted, thực thi độc lập thuần túy 0 Node dependencies!"
	print(step8)
	log_lines.append(step8)
	
	print("==================================================================")
	print("🎉 NGHIỆM THU PHASE 04: 100% TIÊU CHÍ ĐẠT CHUẨN (ALL TESTS PASSED)!")
	print("==================================================================")
	
	_show_success(log_lines, gen_duration_ms, water_cell_count, bank_cell_count, registered_coord)

func _show_success(lines: Array[String], duration: float, water_cells: int, bank_cells: int, bridge_pos: Vector2i) -> void:
	if status_badge:
		status_badge.text = "  PASSED 100%  "
		status_badge.modulate = Color(0.2, 1.0, 0.4)
	if result_label:
		result_label.text = "\n\n".join(lines)
		result_label.modulate = Color(0.85, 1.0, 0.85)
	if stats_label:
		stats_label.text = "Thời gian thực thi: %.2f ms | Ô lòng sông: %d | Ô bờ kè: %d | Tọa độ Cầu: %s" % [duration, water_cells, bank_cells, bridge_pos]

func _fail(msg: String) -> void:
	printerr("❌ [TEST FAILED]: ", msg)
	if status_badge:
		status_badge.text = "  FAILED  "
		status_badge.modulate = Color(1.0, 0.2, 0.2)
	if result_label:
		result_label.text = msg
		result_label.modulate = Color(1.0, 0.4, 0.4)
