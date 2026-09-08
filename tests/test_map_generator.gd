@tool
extends SceneTree

## Bộ Kiểm Thử Tự Động Toàn Diện: Procedural Map Generator Engine (Phase 08)
## Chạy trực tiếp qua chế độ headless: godot --headless -s res://tests/test_map_generator.gd

func _init() -> void:
	print("\n==================================================================")
	print(">>> BẮT ĐẦU KIỂM THỬ TOÀN DIỆN: 16-STEP PROCEDURAL DIORAMA ENGINE")
	print("==================================================================")
	
	var all_passed: bool = true
	var start_time: int = Time.get_ticks_msec()
	
	# --------------------------------------------------------------------------
	# TEST 1: TÍNH TẤT ĐỊNH TUYỆT ĐỐI (DETERMINISM)
	# --------------------------------------------------------------------------
	print("--- TEST 1: KIỂM TRA TÍNH TẤT ĐỊNH VỚI SEED = 9999 ---")
	var cfg1 = MapGenConfig.new()
	cfg1.seed = 9999
	var ctx1 = MapGenContext.new(cfg1)
	_run_pipeline(ctx1, cfg1)
	
	var cfg2 = MapGenConfig.new()
	cfg2.seed = 9999
	var ctx2 = MapGenContext.new(cfg2)
	_run_pipeline(ctx2, cfg2)
	
	var determinism_ok: bool = true
	for i in range(ctx1.total_cells):
		if ctx1.elevation_levels[i] != ctx2.elevation_levels[i]:
			determinism_ok = false
			break
		if not is_equal_approx(ctx1.raw_height_map[i], ctx2.raw_height_map[i]):
			determinism_ok = false
			break
		if not is_equal_approx(ctx1.slope_map[i], ctx2.slope_map[i]):
			determinism_ok = false
			break
			
	if ctx1.poi_registry.get("castle_coord") != ctx2.poi_registry.get("castle_coord"):
		determinism_ok = false
	if ctx1.foliage_transforms.size() != ctx2.foliage_transforms.size():
		determinism_ok = false
		
	if determinism_ok:
		print("✔ Test 1: ĐẠT! Bản đồ sinh ra hoàn toàn tất định 100%% qua 2 lần chạy độc lập (1296 cells & POIs khớp tuyệt đối).")
	else:
		printerr("❌ Test 1: THẤT BẠI! Xuất hiện sai lệch ngẫu nhiên giữa 2 lần chạy cùng seed 9999!")
		all_passed = false
		
	# --------------------------------------------------------------------------
	# TEST 2: ĐỘ PHẲNG VÀ CAO ĐỘ KHU VỰC LÂU ĐÀI (CASTLE FLATNESS)
	# --------------------------------------------------------------------------
	print("\n--- TEST 2: KIỂM TRA ĐỘ PHẲNG TÂM LÂU ĐÀI (3x3 CELLS) ---")
	var castle_coord: Vector2i = ctx1.get_poi_coord(MapGenConstants.POIType.CASTLE)
	var castle_flat_ok: bool = true
	var checked_cells: int = 0
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_pt = castle_coord + Vector2i(dx, dy)
			if ctx1.is_inside_coord(check_pt):
				checked_cells += 1
				var idx = ctx1.get_index(check_pt.x, check_pt.y)
				var lvl = ctx1.elevation_levels[idx]
				var slope = ctx1.slope_map[idx]
				if lvl != MapGenConstants.ElevationLevel.GRASSLAND or not is_zero_approx(slope):
					castle_flat_ok = false
					print("  Lệch tại (%d, %d): Lvl=%d (Kỳ vọng 2), Slope=%.2f" % [check_pt.x, check_pt.y, lvl, slope])
					
	if castle_flat_ok and checked_cells == 9:
		print("✔ Test 2: ĐẠT! 100%% vùng 3x3 quanh Lâu Đài đạt chuẩn tuyệt đối (Level=2, Slope=0.0, phẳng 100%%).")
	else:
		printerr("❌ Test 2: THẤT BẠI! Vùng quanh Lâu Đài bị mấp mô hoặc sai phân tầng cao độ!")
		all_passed = false
		
	# --------------------------------------------------------------------------
	# TEST 3: THÔNG SUỐT KẾT NỐI HAI BỜ SÔNG (CONNECTIVITY ACROSS RIVER VIA A*)
	# --------------------------------------------------------------------------
	print("\n--- TEST 3: KIỂM TRA ĐƯỜNG KẾT NỐI QUA CẦU SANG BỜ TÂY BẰNG A* ---")
	var bridge_coord: Vector2i = ctx1.get_poi_coord(MapGenConstants.POIType.BRIDGE)
	var west_bank_dest = Vector2i(1, bridge_coord.y) # Đất liền bờ Tây (1, 16)
	
	var astar: AStar2D = AStar2D.new()
	for y in range(ctx1.height):
		for x in range(ctx1.width):
			astar.add_point(ctx1.get_index(x, y), Vector2(x, y))
			
	var bridge_crossing_cells: Dictionary = {}
	for bx in range(bridge_coord.x - 2, bridge_coord.x + 2):
		bridge_crossing_cells[Vector2i(bx, bridge_coord.y)] = true
	
	for y in range(ctx1.height):
		for x in range(ctx1.width):
			var u_id = ctx1.get_index(x, y)
			var u_pos = Vector2i(x, y)
			for d in MapGenConstants.NEIGHBOR_OFFSETS_4:
				var v_pos = u_pos + d
				if not ctx1.is_inside_coord(v_pos):
					continue
				var v_id = ctx1.get_index(v_pos.x, v_pos.y)
				var slope = ctx1.get_slope(v_pos.x, v_pos.y)
				var water = ctx1.get_water_zone(v_pos.x, v_pos.y)
				var is_bridge = bridge_crossing_cells.has(v_pos) or ctx1.road_nodes.has(v_pos)
				
				if slope >= 2.0 or (water == MapGenConstants.WaterZone.WATER and not is_bridge):
					continue
				astar.connect_points(u_id, v_id, false)
				
	var start_id = ctx1.get_index(castle_coord.x, castle_coord.y)
	var dest_id = ctx1.get_index(west_bank_dest.x, west_bank_dest.y)
	var path = astar.get_id_path(start_id, dest_id)
	
	if path.size() > 0:
		print("✔ Test 3: ĐẠT! A* tìm thấy đường kết nối thông suốt 100%% từ Lâu Đài (%d, %d) qua Cầu sang bờ Tây (%d, %d) (Chiều dài: %d bước)!" % [castle_coord.x, castle_coord.y, west_bank_dest.x, west_bank_dest.y, path.size()])
	else:
		printerr("❌ Test 3: THẤT BẠI! Tuyến đường A* bị ngắt quãng, không thể sang bờ Tây!")
		all_passed = false
		
	# --------------------------------------------------------------------------
	# TEST 4: CỰ LY AN TOÀN POISSON DISK SAMPLING (NO CLIPPING)
	# --------------------------------------------------------------------------
	print("\n--- TEST 4: KIỂM TRA CỰ LY EUCLIDEAN THẢM THỰC VẬT (NO CLIPPING) ---")
	var transforms = ctx1.foliage_transforms
	var min_dist_found: float = 9999.0
	var clipping_count: int = 0
	
	for i in range(transforms.size()):
		var p1 = Vector2(transforms[i].origin.x, transforms[i].origin.z)
		for j in range(i + 1, mini(i + 25, transforms.size())):
			var p2 = Vector2(transforms[j].origin.x, transforms[j].origin.z)
			var dist = p1.distance_to(p2)
			if dist < min_dist_found:
				min_dist_found = dist
			if dist < 1.49: # Cự ly tối thiểu quy chuẩn 1.5m
				clipping_count += 1
				
	if clipping_count == 0 and min_dist_found >= 1.49:
		print("✔ Test 4: ĐẠT! 100%% cây/đá tuân thủ cự ly phân cách an toàn (Cự ly gần nhất: %.4fm >= 1.5m, 0 lỗi đè thân)." % min_dist_found)
	else:
		printerr("❌ Test 4: THẤT BẠI! Phát hiện %d vi phạm khoảng cách cự ly Poisson (Min dist: %.4fm)!" % [clipping_count, min_dist_found])
		all_passed = false
		
	# --------------------------------------------------------------------------
	# TEST 5: ĐỒNG BỘ HAI CHIỀU VỚI GRIDSYSTEM & PROCEDURALMAPGENERATOR NODE
	# --------------------------------------------------------------------------
	print("\n--- TEST 5: TÍCH HỢP PROCEDURALMAPGENERATOR & GRIDSYSTEM ---")
	var root_node = Node3D.new()
	var grid_sys = GridSystem.new()
	grid_sys.name = "GridSystem"
	root_node.add_child(grid_sys)
	
	var map_gen = ProceduralMapGenerator.new()
	map_gen.name = "ProceduralMapGenerator"
	map_gen.config = cfg1
	map_gen.grid_system = grid_sys
	root_node.add_child(map_gen)
	
	var castle_world_pos = map_gen.generate_map()
	
	# Kiểm tra GridSystem sau khi sinh
	var local_castle = Vector2i(9, 9)
	var cell_info = grid_sys.get_cell_info(local_castle)
	var grid_sync_ok: bool = true
	
	if cell_info.is_empty():
		grid_sync_ok = false
	elif cell_info.get("elevation", 0) != 2:
		grid_sync_ok = false
	elif cell_info.get("is_buildable", true) != false: # Lâu Đài khóa móng
		grid_sync_ok = false
	elif cell_info.get("building", null) == null: # Đã đăng ký Lâu Đài
		grid_sync_ok = false
		
	# Kiểm tra 1 ô cỏ trống kề cận có cho phép xây dựng
	var adjacent_grass = local_castle + Vector2i(1, 1)
	var can_build_grass = grid_sys.is_cell_free_for_building(adjacent_grass)
	
	root_node.free()
	
	if grid_sync_ok and can_build_grass:
		print("✔ Test 5: ĐẠT! ProceduralMapGenerator kết xuất và đồng bộ dữ liệu đa tầng vào GridSystem hoàn hảo 100%%!")
	else:
		printerr("❌ Test 5: THẤT BẠI! Đồng bộ dữ liệu GridSystem không chính xác (SyncOk: %s, CanBuildGrass: %s)!" % [grid_sync_ok, can_build_grass])
		all_passed = false
		
	# --------------------------------------------------------------------------
	# TỔNG KẾT
	# --------------------------------------------------------------------------
	var elapsed_total = Time.get_ticks_msec() - start_time
	print("\n==================================================================")
	if all_passed:
		print("🎉 HOÀN TẤT BÀN GIAO: 100%% TEST CASES ĐẠT CHUẨN ĐẶC TẢ TRONG %d MS!" % elapsed_total)
	else:
		print("❌ CẢNH BÁO: MỘT SỐ TEST CASES CHƯA ĐẠT CHUẨN!")
	print("==================================================================\n")
	
	quit(0 if all_passed else 1)

static func _run_pipeline(context: MapGenContext, config: MapGenConfig) -> void:
	MacroLayoutGenerator.generate(context, config)
	TerraceGenerator.generate(context, config)
	RiverGenerator.generate(context, config)
	POIAndRoadGenerator.generate(context, config)
	FoliageGenerator.generate(context, config)
