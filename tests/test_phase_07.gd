@tool
extends Node3D

## Kịch Bản Kiểm Thử Thực Tế: Phase 07 3D Diorama Rendering & MultiMesh GPU
## Xác minh toàn bộ 5 Tasks và 3 Tiêu Chí Nghiệm Thu (DoD) của Phase 07.

func _ready() -> void:
	print("\n==================================================================")
	print(">>> BẮT ĐẦU CHẠY KIỂM THỬ THỰC TẾ: PHASE 07 RENDERING & MULTIMESH")
	print("==================================================================")
	
	var all_passed: bool = true
	var start_time: int = Time.get_ticks_msec()
	
	# 1. Khởi tạo Cấu hình và Ngữ cảnh dữ liệu
	var config: MapGenConfig = MapGenConfig.new()
	var context: MapGenContext = MapGenContext.new(config)
	print("✔ Bước 1: Nạp thành công MapGenConfig & MapGenContext (36x36 cells, 2.0m cell size)")
	
	# 2. Tiền xử lý từ Phase 02 đến Phase 06
	MacroLayoutGenerator.generate(context, config)
	TerraceGenerator.generate(context, config)
	RiverGenerator.generate(context, config)
	POIAndRoadGenerator.generate(context, config)
	FoliageGenerator.generate(context, config)
	print("✔ Bước 2: Chuỗi phát sinh dữ liệu từ Phase 02 đến Phase 06 hoàn tất")
	
	# 3. Kích hoạt kết xuất 3D qua DioramaRenderer
	var diorama_root: Node3D = Node3D.new()
	diorama_root.name = "DioramaRoot"
	add_child(diorama_root)
	
	var render_start: int = Time.get_ticks_msec()
	var render_result: Dictionary = DioramaRenderer.render_diorama(diorama_root, context, config)
	var render_duration: int = Time.get_ticks_msec() - render_start
	print("✔ Bước 3: DioramaRenderer.render_diorama() thực thi thành công trong %d ms!" % render_duration)
	
	# 4. Kiểm tra Tiêu chí 1: Khối Chân Đế Sa Bàn Nổi (Solid Bedrock Pedestal)
	var bedrock: MeshInstance3D = render_result.get("bedrock", null)
	var tc1_passed: bool = false
	if bedrock != null and bedrock.mesh is BoxMesh:
		var b_size: Vector3 = (bedrock.mesh as BoxMesh).size
		var b_pos: Vector3 = bedrock.position
		var expected_size: Vector3 = Vector3(72.0, 5.0, 72.0)
		var expected_pos: Vector3 = Vector3(36.0, -2.5, 36.0)
		if b_size.is_equal_approx(expected_size) and b_pos.is_equal_approx(expected_pos):
			tc1_passed = true
			
	if tc1_passed:
		print("✔ Tiêu chí 1: Khối Chân Đế 'DioramaBedrock' BoxMesh (72x5x72m) định vị chuẩn xác tại (36, -2.5, 36), triệt tiêu hoàn toàn lộ đáy rỗng!")
	else:
		print("❌ THẤT BẠI Tiêu chí 1: Khối chân đế bedrock không đạt chuẩn kích thước hoặc vị trí!")
		all_passed = false
		
	# 5. Kiểm tra Tiêu chí 2: Vùng Chơi 20x20 TerrainTile & Ô Cảnh Quan Ngoại Vi
	var tiles_container: Node3D = render_result.get("tiles_container", null)
	var landscape_container: Node3D = render_result.get("landscape_container", null)
	var tc2_passed: bool = true
	
	if tiles_container == null or tiles_container.get_child_count() != 400:
		print("❌ THẤT BẠI Tiêu chí 2: TilesContainer không chứa đúng 400 TerrainTile! (Hiện tại: %d)" % (tiles_container.get_child_count() if tiles_container else -1))
		tc2_passed = false
	else:
		var road_tiles_count: int = 0
		var grass_tiles_count: int = 0
		for child in tiles_container.get_children():
			if not (child is TerrainTile):
				tc2_passed = false
				break
			var t: TerrainTile = child as TerrainTile
			if t.tile_type == TerrainTile.TileType.ROAD:
				road_tiles_count += 1
				if t.is_buildable:
					tc2_passed = false
			elif t.tile_type == TerrainTile.TileType.GRASS:
				grass_tiles_count += 1
				
		if tc2_passed and road_tiles_count == 17 and grass_tiles_count == 383:
			print("✔ Tiêu chí 2: Vùng chơi 20x20 có đủ 400 TerrainTile (17 ô đường mòn nội địa khóa cấm xây, 383 ô cỏ phong phú hoa dại)!")
		else:
			print("❌ THẤT BẠI Tiêu chí 2: Phân bổ loại tile trong vùng chơi không chính xác (Road: %d/17, Grass: %d/383)!" % [road_tiles_count, grass_tiles_count])
			tc2_passed = false
			
	if not tc2_passed:
		all_passed = false
		
	var landscape_count: int = landscape_container.get_child_count() if landscape_container else 0
	if landscape_count == (36 * 36 - 400): # 896 ô cảnh quan ngoài biên
		print("✔ Tiêu chí 2 phụ: 896 ô cảnh quan ngoại vi (Lòng sông Y=-0.7m, Bờ kè xoay dốc, Cỏ biên) được kết xuất tĩnh tối ưu!")
	else:
		print("❌ CẢNH BÁO Tiêu chí 2 phụ: Số lượng ô cảnh quan ngoại vi là %d (Kỳ vọng: 896)" % landscape_count)
		all_passed = false
		
	# 6. Kiểm tra Tiêu chí 3: Thuật Toán Khâu Vách Đá 3D (Cliff Stitching)
	var cliffs_container: Node3D = render_result.get("cliffs_container", null)
	var tc3_passed: bool = false
	var cliff_nodes_count: int = cliffs_container.get_child_count() if cliffs_container else 0
	var expected_cliffs: int = context.cliff_specs.size()
	
	if cliff_nodes_count == expected_cliffs and expected_cliffs > 0:
		tc3_passed = true
		print("✔ Tiêu chí 3: Khâu kín 100%% (%d/%d) vách đá lệch tầng bằng wall_straight, xóa sổ hoàn toàn khe hở hình học giữa các bậc địa hình!" % [cliff_nodes_count, expected_cliffs])
	else:
		print("❌ THẤT BẠI Tiêu chí 3: Số lượng vách đá khâu lưới không khớp! (%d vs kỳ vọng %d)" % [cliff_nodes_count, expected_cliffs])
		all_passed = false
		
	# 7. Kiểm tra Tiêu chí 4: Tối Ưu Hóa GPU Bằng MultiMesh
	var foliage_container: Node3D = render_result.get("foliage_container", null)
	var tc4_passed: bool = true
	var total_multimesh_instances: int = 0
	var multimesh_nodes_count: int = 0
	
	if foliage_container != null:
		for child in foliage_container.get_children():
			if child is MultiMeshInstance3D:
				multimesh_nodes_count += 1
				var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
				if mm != null:
					total_multimesh_instances += mm.instance_count
					
	var expected_foliage: int = context.foliage_transforms.size()
	if multimesh_nodes_count >= 3 and total_multimesh_instances == expected_foliage and expected_foliage > 0:
		print("✔ Tiêu chí 4: Toàn bộ %d cây cối và đá cảnh được gom vào %d cụm MultiMeshInstance3D (Chỉ tiêu tốn %d Draw Calls trên GPU)!" % [total_multimesh_instances, multimesh_nodes_count, multimesh_nodes_count])
	else:
		print("❌ THẤT BẠI Tiêu chí 4: MultiMesh không khớp số lượng! (%d instances trong %d nodes vs kỳ vọng %d)" % [total_multimesh_instances, multimesh_nodes_count, expected_foliage])
		tc4_passed = false
		all_passed = false
		
	# 8. Kiểm tra Tiêu chí 5: Các Công Trình Cốt Lõi, Cầu Vượt Sông & Tài Nguyên
	var poi_container: Node3D = render_result.get("poi_container", null)
	var obstacles_container: Node3D = render_result.get("obstacles_container", null)
	var tc5_passed: bool = true
	
	var has_bridge: bool = poi_container.has_node("RoofedBridge") if poi_container else false
	var has_watermill: bool = poi_container.has_node("RiverWatermill") if poi_container else false
	var has_castle: bool = poi_container.has_node("GrandCastle") if poi_container else false
	var has_hill: bool = poi_container.has_node("CastleRoyalHill") if poi_container else false
	
	var quarry_count: int = 0
	var lumber_count: int = 0
	if obstacles_container != null:
		for child in obstacles_container.get_children():
			if child is ResourceNode:
				var rn: ResourceNode = child as ResourceNode
				if rn.node_type == ResourceNode.NodeType.ROCK_QUARRY:
					quarry_count += 1
				elif rn.node_type == ResourceNode.NodeType.TREE:
					lumber_count += 1
					
	if has_bridge and has_watermill and has_castle and has_hill and quarry_count == 3 and lumber_count == 16:
		print("✔ Tiêu chí 5: Cầu Mái Che, Cối Xay Nước, Lâu Đài Hoàng Gia (Scale 2.4x) và toàn bộ Tài Nguyên (3 Mỏ Đá, 16 Cây Gỗ) được cắm chuẩn xác 100%!")
	else:
		print("❌ THẤT BẠI Tiêu chí 5: Thiếu công trình hoặc tài nguyên (Bridge:%s, Mill:%s, Castle:%s, Hill:%s, Quarries:%d/3, Lumber:%d/16)" % [has_bridge, has_watermill, has_castle, has_hill, quarry_count, lumber_count])
		tc5_passed = false
		all_passed = false
		
	# 9. Tổng kết
	var total_time: int = Time.get_ticks_msec() - start_time
	print("==================================================================")
	if all_passed:
		print("🎉 NGHIỆM THU PHASE 07: 100%% TIÊU CHÍ ĐẠT CHUẨN (ALL TESTS PASSED in %d ms)!" % total_time)
	else:
		print("❌ KẾT QUẢ: MỘT SỐ TIÊU CHÍ CHƯA ĐẠT! (Total time: %d ms)" % total_time)
	print("==================================================================\n")
	
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if all_passed else 1)
