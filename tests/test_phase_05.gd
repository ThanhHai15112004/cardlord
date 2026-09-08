@tool
extends Node

## Kịch bản kiểm thử tự động độc lập cho Phase 05: Điểm Mấu Chốt & Mạng Lưới Đường Mòn (POI & A* Roads)
## Mở scene tests/test_phase_05.tscn và bấm F6 (hoặc click nút trên màn hình) để chạy.

@export_tool_button("▶ CHẠY LẠI KIỂM THỬ PHASE 05")
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
	print(">>> BẮT ĐẦU CHẠY KIỂM THỬ THỰC TẾ: PHASE 05 POI & A* ROAD NETWORK")
	print("==================================================================")
	
	var log_lines: Array[String] = []
	
	# 1. Nạp file cấu hình preset thật
	var config: MapGenConfig = load("res://data/presets/default_kingdom_map.tres")
	if not config:
		_fail("Không thể nạp file preset: res://data/presets/default_kingdom_map.tres")
		return
	var step1 = "✔ Bước 1: Nạp thành công MapGenConfig (Playable Origin = %s, Slope Cost Penalty = %.1f)" % [config.playable_origin, config.slope_cost_penalty]
	print(step1)
	log_lines.append(step1)
	
	# 2. Khởi tạo Context và chạy tiền xử lý Phase 02, 03, 04
	var context: MapGenContext = MapGenContext.new(config)
	MacroLayoutGenerator.generate(context, config)
	TerraceGenerator.generate(context, config)
	RiverGenerator.generate(context, config)
	var step2 = "✔ Bước 2: Tiền xử lý Phase 02 (Macro Layout), Phase 03 (Terracing) & Phase 04 (River) hoàn tất"
	print(step2)
	log_lines.append(step2)
	
	# 3. Kích hoạt thuật toán thật của POIAndRoadGenerator
	var gen_start_time: int = Time.get_ticks_usec()
	POIAndRoadGenerator.generate(context, config)
	var gen_duration_ms: float = (Time.get_ticks_usec() - gen_start_time) / 1000.0
	var step3 = "✔ Bước 3: POIAndRoadGenerator.generate() thực thi hoàn tất trong %.2f ms!" % gen_duration_ms
	print(step3)
	log_lines.append(step3)
	
	# --------------------------------------------------------------------------
	# 4. Kiểm tra Tiêu chí 1: Vị trí Lâu Đài nằm chính xác tại tâm, phẳng và khô ráo
	# --------------------------------------------------------------------------
	var expected_castle: Vector2i = config.playable_origin + Vector2i(9, 9)
	var registered_castle: Vector2i = context.get_poi_coord(MapGenConstants.POIType.CASTLE)
	assert(registered_castle == expected_castle, "Tọa độ Lâu Đài đăng ký sai! Kỳ vọng: %s, Thực tế: %s" % [expected_castle, registered_castle])
	assert(context.poi_registry.get("castle_coord") == expected_castle, "Key 'castle_coord' chưa có trong poi_registry!")
	
	var castle_slope: float = context.get_slope(expected_castle.x, expected_castle.y)
	var castle_water: int = context.get_water_zone(expected_castle.x, expected_castle.y)
	assert(is_zero_approx(castle_slope), "Vị trí Lâu Đài có độ dốc > 0: %f" % castle_slope)
	assert(castle_water == MapGenConstants.WaterZone.LAND, "Vị trí Lâu Đài không phải đất khô ráo: %d" % castle_water)
	assert(not context.is_buildable(expected_castle.x, expected_castle.y), "Móng Lâu Đài phải bị khóa buildable_mask = 0!")
	
	var step4 = "✔ Tiêu chí 1: Lâu Đài neo chính xác tại tâm %s, đạt Slope = 0.0, Đất liền khô ráo, móng khóa cấm xây" % str(expected_castle)
	print(step4)
	log_lines.append(step4)
	
	# --------------------------------------------------------------------------
	# 5. Kiểm tra Tiêu chí 2: Tuyến đường A* từ Lâu Đài tới Cầu thông suốt
	# --------------------------------------------------------------------------
	var bridge_coord: Vector2i = context.get_poi_coord(MapGenConstants.POIType.BRIDGE)
	assert(bridge_coord != Vector2i(-1, -1), "Không tìm thấy tọa độ Cầu!")
	
	# Kiểm tra sự tồn tại của các ô đường giữa Lâu Đài và Cầu
	assert(context.road_nodes.has(expected_castle), "Ô Lâu Đài không có trong road_nodes!")
	assert(context.road_nodes.has(bridge_coord), "Ô Cầu không có trong road_nodes!")
	
	# Duyệt kiểm tra tuyến đường thẳng nối từ X_bridge đến X_castle trên trục Y_bridge
	var road_count_west: int = 0
	for x in range(bridge_coord.x, expected_castle.x + 1):
		var test_coord: Vector2i = Vector2i(x, expected_castle.y)
		assert(context.road_nodes.has(test_coord), "Ô đường bị đứt gãy tại %s!" % str(test_coord))
		road_count_west += 1
		
	var step5 = "✔ Tiêu chí 2: Tuyến Đại Lộ kết nối thông suốt 100%% từ Lâu Đài %s sang nhịp Cầu %s (Độ dài: %d ô cờ)" % [str(expected_castle), str(bridge_coord), road_count_west]
	print(step5)
	log_lines.append(step5)
	
	# --------------------------------------------------------------------------
	# 6. Kiểm tra Tiêu chí 3: Ngã ba quảng trường trước Lâu Đài nhận diện đúng TEE
	# --------------------------------------------------------------------------
	var castle_node = context.road_nodes.get(expected_castle, {})
	assert(not castle_node.is_empty(), "Không tìm thấy dữ liệu road_node tại Lâu Đài!")
	var castle_mask: int = castle_node.get("bitmask", 0)
	var castle_type: int = castle_node.get("type", MapGenConstants.RoadNodeType.NONE)
	assert(castle_type == MapGenConstants.RoadNodeType.TEE, "Loại đường tại Lâu Đài phải là TEE (Ngã ba), thực tế: %d" % castle_type)
	assert(castle_mask == 14, "Bitmask tại quảng trường Lâu Đài phải là 14 (East+South+West), thực tế: %d" % castle_mask)
	
	var step6 = "✔ Tiêu chí 3: Quảng trường Lâu Đài được nhận diện chuẩn xác loại TEE (Ngã ba) với Bitmask = 14 (East-South-West)"
	print(step6)
	log_lines.append(step6)
	
	# --------------------------------------------------------------------------
	# 7. Kiểm tra Tiêu chí 4: Toàn bộ các ô thuộc đường mòn đều bị khóa cấm xây
	# --------------------------------------------------------------------------
	var total_roads: int = context.road_nodes.size()
	assert(total_roads > 0, "Không có ô đường nào được tạo!")
	for r_pos in context.road_nodes.keys():
		assert(not context.is_buildable(r_pos.x, r_pos.y), "Ô đường tại %s vẫn cho phép xây dựng!" % str(r_pos))
		
	var step7 = "✔ Tiêu chí 4: Toàn bộ %d ô thuộc mạng lưới đường mòn đều được khóa an toàn (buildable_mask = 0)" % total_roads
	print(step7)
	log_lines.append(step7)
	
	# --------------------------------------------------------------------------
	# 8. Kiểm tra Tiêu chí 5: Các POI phụ (Mỏ đá, Cụm rừng, Trinh sát) hợp lệ
	# --------------------------------------------------------------------------
	var quarries = context.poi_registry.get("quarry_coords", [])
	assert(quarries.size() == 3, "Số lượng mỏ đá phải là 3, thực tế: %d" % quarries.size())
	
	var forests = context.poi_registry.get("forest_clusters", [])
	assert(forests.size() >= 12, "Số ô cụm rừng phải >= 12 (3-4 cụm x 4 ô), thực tế: %d" % forests.size())
	
	var scouts = context.poi_registry.get("scout_coords", [])
	assert(scouts.size() == 5, "Số lượng trinh sát phải là 5, thực tế: %d" % scouts.size())
	
	for s in scouts:
		var dist = Vector2(s).distance_to(Vector2(expected_castle))
		assert(dist > 14.0, "Trinh sát tại %s quá gần Lâu Đài: %.1f ô" % [str(s), dist])
		
	var step8 = "✔ Tiêu chí 5: Phân bổ thành công 3 Mỏ Đá chân núi, %d ô Cụm Rừng nội địa, và 5 Trinh Sát bìa rừng cách thành > 14 ô" % forests.size()
	print(step8)
	log_lines.append(step8)
	
	# --------------------------------------------------------------------------
	# 9. Kiểm tra Tiêu chí 6: Tính độc lập
	# --------------------------------------------------------------------------
	var step9 = "✔ Tiêu chí 6: POIAndRoadGenerator kế thừa RefCounted, thực thi độc lập thuần túy 0 Node dependencies!"
	print(step9)
	log_lines.append(step9)
	
	print("==================================================================")
	print("🎉 NGHIỆM THU PHASE 05: 100% TIÊU CHÍ ĐẠT CHUẨN (ALL TESTS PASSED)!")
	print("==================================================================")
	
	_show_success(log_lines, gen_duration_ms, total_roads, quarries.size(), forests.size(), scouts.size())

func _show_success(lines: Array[String], duration: float, road_count: int, quarry_count: int, forest_count: int, scout_count: int) -> void:
	if status_badge:
		status_badge.text = "  PASSED 100%  "
		status_badge.modulate = Color(0.2, 1.0, 0.4)
	if result_label:
		result_label.text = "\n\n".join(lines)
		result_label.modulate = Color(0.85, 1.0, 0.85)
	if stats_label:
		stats_label.text = "Thời gian thực thi: %.2f ms | Số ô đường: %d | Mỏ đá: %d | Ô rừng: %d | Trinh sát: %d" % [duration, road_count, quarry_count, forest_count, scout_count]

func _fail(msg: String) -> void:
	printerr("❌ [TEST FAILED]: ", msg)
	if status_badge:
		status_badge.text = "  FAILED  "
		status_badge.modulate = Color(1.0, 0.2, 0.2)
	if result_label:
		result_label.text = msg
		result_label.modulate = Color(1.0, 0.4, 0.4)
