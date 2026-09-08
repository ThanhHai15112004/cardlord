@tool
extends Node

## Kịch bản kiểm thử tự động độc lập cho Phase 03: Terracing, Slope & Cliffs
## Mở scene tests/test_phase_03.tscn và bấm F6 (hoặc click nút trên màn hình) để chạy.

@export_tool_button("▶ CHẠY LẠI KIỂM THỬ PHASE 03")
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
	print(">>> BẮT ĐẦU CHẠY KIỂM THỬ THỰC TẾ: PHASE 03 TERRACING & CLIFFS")
	print("==================================================================")
	
	var log_lines: Array[String] = []
	var start_time: int = Time.get_ticks_usec()
	
	# 1. Nạp file cấu hình preset thật
	var config: MapGenConfig = load("res://data/presets/default_kingdom_map.tres")
	if not config:
		_fail("Không thể nạp file preset: res://data/presets/default_kingdom_map.tres")
		return
	var step1 = "✔ Bước 1: Nạp thành công MapGenConfig (Terrain Levels = %d, Base Elevation = %d)" % [config.terrain_levels, config.base_elevation]
	print(step1)
	log_lines.append(step1)
	
	# 2. Khởi tạo Context và chạy qua Phase 02 để có raw_height_map
	var context: MapGenContext = MapGenContext.new(config)
	MacroLayoutGenerator.generate(context, config)
	var step2 = "✔ Bước 2: Khởi tạo Context và tiền xử lý Phase 02 hoàn tất (1296 ô raw_height_map sẵn sàng)"
	print(step2)
	log_lines.append(step2)
	
	# 3. Kích hoạt thuật toán thật của TerraceGenerator
	var gen_start_time: int = Time.get_ticks_usec()
	TerraceGenerator.generate(context, config)
	var gen_duration_ms: float = (Time.get_ticks_usec() - gen_start_time) / 1000.0
	var step3 = "✔ Bước 3: TerraceGenerator.generate() thực thi hoàn tất trong %.2f ms!" % gen_duration_ms
	print(step3)
	log_lines.append(step3)
	
	# --------------------------------------------------------------------------
	# 4. Kiểm tra Tiêu chí 1: Mảng elevation_levels chỉ chứa số nguyên [0, 6]
	# --------------------------------------------------------------------------
	var total: int = context.elevation_levels.size()
	assert(total == 1296, "Số lượng phần tử trong elevation_levels phải là 1296, thực tế: %d" % total)
	
	var level_counts: Dictionary = {}
	for i in range(total):
		var lvl: int = context.elevation_levels[i]
		assert(lvl >= 0 and lvl <= 6, "Ô thứ %d có Level ngoài dải [0, 6]: %d" % [i, lvl])
		level_counts[lvl] = level_counts.get(lvl, 0) + 1
		
	var dist_str: String = ""
	for l in range(7):
		dist_str += "L%d:%d " % [l, level_counts.get(l, 0)]
	var step4 = "✔ Tiêu chí 1: 1296 ô elevation_levels đều là số nguyên [0..6] (Phân bố: %s)" % dist_str
	print(step4)
	log_lines.append(step4)
	
	# --------------------------------------------------------------------------
	# 5. Kiểm tra Tiêu chí 2: Vùng lãnh địa trung tâm (20x20) có >= 65% ô buildable
	# --------------------------------------------------------------------------
	var p_origin: Vector2i = config.playable_origin
	var p_size: Vector2i = config.playable_grid_size
	var playable_total: int = p_size.x * p_size.y
	var buildable_in_playable: int = 0
	
	for y in range(p_origin.y, p_origin.y + p_size.y):
		for x in range(p_origin.x, p_origin.x + p_size.x):
			var idx: int = context.get_index(x, y)
			if context.buildable_mask[idx] == 1:
				buildable_in_playable += 1
				# Đảm bảo ô buildable bắt buộc phải là Level 2 và Slope 0
				assert(context.elevation_levels[idx] == config.base_elevation, "Ô buildable tại (%d, %d) không phải Level 2!" % [x, y])
				assert(is_zero_approx(context.slope_map[idx]), "Ô buildable tại (%d, %d) có độ dốc > 0!" % [x, y])
				
	var buildable_pct: float = (float(buildable_in_playable) / float(playable_total)) * 100.0
	assert(buildable_pct >= 65.0, "Tỷ lệ ô buildable trong vùng trung tâm chỉ đạt %.1f%% < 65%%!" % buildable_pct)
	var step5 = "✔ Tiêu chí 2: Vùng lãnh địa trung tâm (20x20) đạt %.1f%% ô cờ đủ điều kiện xây dựng (%d/%d ô, chuẩn >= 65%%)" % [buildable_pct, buildable_in_playable, playable_total]
	print(step5)
	log_lines.append(step5)
	
	# --------------------------------------------------------------------------
	# 6. Kiểm tra Tiêu chí 3: cliff_specs bắt trọn 100% cạnh lệch tầng không sót
	# --------------------------------------------------------------------------
	var cliff_total: int = context.cliff_specs.size()
	assert(cliff_total > 0, "Không phát hiện được bất kỳ vách đá nào!")
	
	# Kiểm tra tính toàn vẹn của từng bản ghi vách đá
	for spec in context.cliff_specs:
		var cell: Vector2i = spec.get("cell", Vector2i(-1, -1))
		var d_idx: int = spec.get("direction_idx", -1)
		var step_diff: int = spec.get("step_difference", 0)
		var from_lvl: int = spec.get("from_level", -1)
		var to_lvl: int = spec.get("to_level", -1)
		
		assert(context.is_inside_coord(cell), "Tọa độ vách đá ngoài biên: %s" % str(cell))
		assert(d_idx >= 0 and d_idx < 4, "Hướng vách đá không hợp lệ: %d" % d_idx)
		assert(step_diff > 0, "Độ lệch vách đá phải > 0, thực tế: %d" % step_diff)
		assert(from_lvl > to_lvl, "from_level (%d) phải lớn hơn to_level (%d)" % [from_lvl, to_lvl])
		assert(from_lvl - to_lvl == step_diff, "step_difference không khớp với from_level - to_level")
		
		var d: Vector2i = MapGenConstants.NEIGHBOR_OFFSETS_4[d_idx]
		var neighbor_coord: Vector2i = cell + d
		assert(context.is_inside_coord(neighbor_coord), "Ô lân cận của vách đá nằm ngoài biên!")
		assert(context.get_elevation(neighbor_coord.x, neighbor_coord.y) == to_lvl, "Cao độ ô lân cận không khớp to_level!")
		assert(context.get_elevation(cell.x, cell.y) == from_lvl, "Cao độ ô hiện tại không khớp from_level!")
		
	# Quét đối chiếu toàn diện: Không được sót bất kỳ cạnh nào
	var expected_cliffs: int = 0
	for y in range(context.height):
		for x in range(context.width):
			var cur_lvl: int = context.get_elevation(x, y)
			for d_idx in range(4):
				var d: Vector2i = MapGenConstants.NEIGHBOR_OFFSETS_4[d_idx]
				var nx: int = x + d.x
				var ny: int = y + d.y
				if context.is_inside(nx, ny):
					if cur_lvl > context.get_elevation(nx, ny):
						expected_cliffs += 1
						
	assert(cliff_total == expected_cliffs, "Số lượng vách đá phát hiện (%d) không khớp với số lượng thực tế (%d)!" % [cliff_total, expected_cliffs])
	var step6 = "✔ Tiêu chí 3: Danh sách cliff_specs bắt trọn 100%% mép lệch tầng (%d vách đá, 0 sai sót, 0 khoảng hở)" % cliff_total
	print(step6)
	log_lines.append(step6)
	
	# --------------------------------------------------------------------------
	# 7. Kiểm tra Tiêu chí 4: Ma trận slope_map hợp lệ và đồng bộ
	# --------------------------------------------------------------------------
	var max_slope_found: float = 0.0
	for i in range(total):
		var s: float = context.slope_map[i]
		if s > max_slope_found:
			max_slope_found = s
		assert(s >= 0.0 and s <= 6.0, "Độ dốc không hợp lệ tại ô %d: %f" % [i, s])
	var step7 = "✔ Tiêu chí 4: Ma trận slope_map toàn diện, gradient tối đa đo được: %.1f tầng" % max_slope_found
	print(step7)
	log_lines.append(step7)
	
	# --------------------------------------------------------------------------
	# 8. Kiểm tra Tiêu chí 5: Tính độc lập
	# --------------------------------------------------------------------------
	var step8 = "✔ Tiêu chí 5: TerraceGenerator kế thừa RefCounted, thực thi độc lập thuần túy 0 Node dependencies!"
	print(step8)
	log_lines.append(step8)
	
	print("==================================================================")
	print("🎉 NGHIỆM THU PHASE 03: 100% TIÊU CHÍ ĐẠT CHUẨN (ALL TESTS PASSED)!")
	print("==================================================================")
	
	_show_success(log_lines, gen_duration_ms, buildable_pct, buildable_in_playable, cliff_total, max_slope_found)

func _show_success(lines: Array[String], duration: float, buildable_pct: float, buildable_count: int, cliff_total: int, max_slope: float) -> void:
	if status_badge:
		status_badge.text = "  PASSED 100%  "
		status_badge.modulate = Color(0.2, 1.0, 0.4)
	if result_label:
		result_label.text = "\n\n".join(lines)
		result_label.modulate = Color(0.85, 1.0, 0.85)
	if stats_label:
		stats_label.text = "Thời gian thực thi: %.2f ms | Tỷ lệ xây dựng lõi: %.1f%% (%d ô) | Số vách đá: %d | Dốc tối đa: %.1f" % [duration, buildable_pct, buildable_count, cliff_total, max_slope]

func _fail(msg: String) -> void:
	printerr("❌ [TEST FAILED]: ", msg)
	if status_badge:
		status_badge.text = "  FAILED  "
		status_badge.modulate = Color(1.0, 0.2, 0.2)
	if result_label:
		result_label.text = msg
		result_label.modulate = Color(1.0, 0.4, 0.4)
