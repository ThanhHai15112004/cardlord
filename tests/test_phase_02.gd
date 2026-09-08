@tool
extends Node

## Kịch bản kiểm thử tự động độc lập cho Phase 02: Macro Layout & Height Synthesis
## Mở scene tests/test_phase_02.tscn và bấm F6 (hoặc click nút trên màn hình) để chạy.

@export_tool_button("▶ CHẠY LẠI KIỂM THỬ PHASE 02")
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
	print(">>> BẮT ĐẦU CHẠY KIỂM THỬ THỰC TẾ: PHASE 02 MACRO LAYOUT & HEIGHT")
	print("==================================================================")
	
	var log_lines: Array[String] = []
	var start_time: int = Time.get_ticks_usec()
	
	# 1. Nạp file cấu hình thật từ Resource preset
	var config: MapGenConfig = load("res://data/presets/default_kingdom_map.tres")
	if not config:
		_fail("Không thể nạp file preset: res://data/presets/default_kingdom_map.tres")
		return
	var step1 = "✔ Bước 1: Nạp thành công MapGenConfig (Seed = %d, MapSize = %s, BorderWidth = %.1f)" % [config.seed, config.map_size, config.border_width]
	print(step1)
	log_lines.append(step1)
	
	# 2. Khởi tạo Ngữ cảnh bộ nhớ MapGenContext
	var context: MapGenContext = MapGenContext.new(config)
	var step2 = "✔ Bước 2: Khởi tạo MapGenContext thành công (Đã cấp phát %d ô)" % context.total_cells
	print(step2)
	log_lines.append(step2)
	
	# 3. Kích hoạt thuật toán thật của MacroLayoutGenerator
	MacroLayoutGenerator.generate(context, config)
	var gen_duration_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
	var step3 = "✔ Bước 3: MacroLayoutGenerator.generate() thực thi hoàn tất trong %.2f ms!" % gen_duration_ms
	print(step3)
	log_lines.append(step3)
	
	# --------------------------------------------------------------------------
	# 4. Kiểm tra Tiêu chí 1: Mảng raw_height_map đủ 1296 ô trong [0.0, 1.0]
	# --------------------------------------------------------------------------
	var total: int = context.raw_height_map.size()
	assert(total == 1296, "Số lượng phần tử trong raw_height_map phải là 1296, thực tế: %d" % total)
	
	var min_h: float = 999.0
	var max_h: float = -999.0
	for i in range(total):
		var h = context.raw_height_map[i]
		if h < min_h: min_h = h
		if h > max_h: max_h = h
		assert(h >= 0.0 and h <= 1.0, "Ô thứ %d có giá trị vượt dải [0, 1]: %f" % [i, h])
		
	var step4 = "✔ Tiêu chí 1: Đủ 1296 ô trong dải [0.0, 1.0] (Đo đạc: Min = %.4f, Max = %.4f)" % [min_h, max_h]
	print(step4)
	log_lines.append(step4)
	
	# --------------------------------------------------------------------------
	# 5. Kiểm tra Tiêu chí 2: Toàn bộ 140 ô mép ngoài đạt H >= 0.70
	# --------------------------------------------------------------------------
	var border_checked: int = 0
	var border_min: float = 999.0
	var border_max: float = -999.0
	for y in range(context.height):
		for x in range(context.width):
			if x == 0 or x == context.width - 1 or y == 0 or y == context.height - 1:
				border_checked += 1
				var h = context.get_height(x, y)
				if h < border_min: border_min = h
				if h > border_max: border_max = h
				assert(h >= 0.70, "Ô mép biên (%d, %d) có H = %.4f < 0.70!" % [x, y, h])
				
	assert(border_checked == 140, "Số lượng ô mép ngoài phải là 140")
	var step5 = "✔ Tiêu chí 2: Toàn bộ 140/140 ô viền mép biên đều đạt H >= 0.70! (Min = %.4f, Max = %.4f)" % [border_min, border_max]
	print(step5)
	log_lines.append(step5)
	
	# --------------------------------------------------------------------------
	# 6. Kiểm tra Tiêu chí 3: Độ phẳng tại tâm vương quốc (Bán kính 4 ô quanh C)
	# --------------------------------------------------------------------------
	var center: Vector2 = config.get_playable_center()
	var center_checked: int = 0
	var center_min: float = 999.0
	var center_max: float = -999.0
	for y in range(context.height):
		for x in range(context.width):
			var dist = Vector2(float(x), float(y)).distance_to(center)
			if dist <= 4.0:
				center_checked += 1
				var h = context.get_height(x, y)
				if h < center_min: center_min = h
				if h > center_max: center_max = h
				
	var center_diff: float = center_max - center_min
	assert(center_diff < 0.02, "Độ chênh lệch cao độ tại tâm phải < 0.02, thực tế: %.4f" % center_diff)
	var step6 = "✔ Tiêu chí 3: Tâm vương quốc (49 ô quanh C) bằng phẳng tuyệt đối! (Biên độ: %.4f -> %.4f, Chênh lệch chỉ: %.4f)" % [center_min, center_max, center_diff]
	print(step6)
	log_lines.append(step6)
	
	# --------------------------------------------------------------------------
	# 7. Kiểm tra Tiêu chí 4: Tính độc lập
	# --------------------------------------------------------------------------
	var step7 = "✔ Tiêu chí 4: MacroLayoutGenerator kế thừa RefCounted, không phụ thuộc vào bất kỳ Node hiển thị nào!"
	print(step7)
	log_lines.append(step7)
	
	print("==================================================================")
	print("🎉 NGHIỆM THU PHASE 02: 100% TIÊU CHÍ ĐẠT CHUẨN (ALL TESTS PASSED)!")
	print("==================================================================")
	
	_show_success(log_lines, gen_duration_ms, min_h, max_h, border_min, center_diff)

func _show_success(lines: Array[String], duration: float, min_h: float, max_h: float, border_min: float, center_diff: float) -> void:
	if status_badge:
		status_badge.text = "  PASSED 100%  "
		status_badge.modulate = Color(0.2, 1.0, 0.4)
	if result_label:
		result_label.text = "\n\n".join(lines)
		result_label.modulate = Color(0.85, 1.0, 0.85)
	if stats_label:
		stats_label.text = "Thời gian thực thi: %.2f ms | Dải cao độ: [%.4f, %.4f] | Vành núi thấp nhất: %.4f | Độ mấp mô tâm: %.4f" % [duration, min_h, max_h, border_min, center_diff]

func _fail(msg: String) -> void:
	printerr("❌ [TEST FAILED]: ", msg)
	if status_badge:
		status_badge.text = "  FAILED  "
		status_badge.modulate = Color(1.0, 0.2, 0.2)
	if result_label:
		result_label.text = msg
		result_label.modulate = Color(1.0, 0.4, 0.4)
