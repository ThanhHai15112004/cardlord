@tool
extends SceneTree

func _init() -> void:
	print(">>> Bắt đầu nạp gameplay.tscn để xuất toàn bộ sa bàn trực tiếp vào Scene...")
	var scene: PackedScene = load("res://scenes/gameplay/gameplay.tscn")
	if not scene:
		printerr("Không thể nạp gameplay.tscn")
		quit(1)
		return

	var root = scene.instantiate()
	var grid_sys = root.get_node("Systems/GridSystem")
	var world_node = root.get_node("World")
	var tiles_cnt = root.get_node("World/TilesContainer")
	var obs_cnt = root.get_node("World/ObstaclesContainer")
	var bld_cnt = root.get_node("World/BuildingsContainer")
	var deco_cnt = root.get_node_or_null("World/DecorationsContainer")
	if not deco_cnt:
		deco_cnt = Node3D.new()
		deco_cnt.name = "DecorationsContainer"
		world_node.add_child(deco_cnt)

	# Dọn dẹp các node con cũ nếu có
	for cnt in [tiles_cnt, obs_cnt, bld_cnt, deco_cnt]:
		for c in cnt.get_children():
			cnt.remove_child(c)
			c.free()

	# Xây dựng bản đồ hoàn chỉnh
	var castle_pos = KingdomMapBuilder.build_grand_map(grid_sys, tiles_cnt, obs_cnt, bld_cnt, deco_cnt)
	print(">>> Đã sinh bản đồ thành công! Vị trí lâu đài: ", castle_pos)

	# Gán owner = root cho TẤT CẢ các node con để chúng hiển thị trong Scene dock và 3D Viewport của Godot Editor
	_set_owner_recursive(root, root)

	# Đóng gói và lưu đè vào file gameplay.tscn
	var packed = PackedScene.new()
	var pack_err = packed.pack(root)
	if pack_err != OK:
		printerr("Lỗi khi pack scene: ", pack_err)
		quit(1)
		return

	var save_err = ResourceSaver.save(packed, "res://scenes/gameplay/gameplay.tscn")
	if save_err != OK:
		printerr("Lỗi khi lưu gameplay.tscn: ", save_err)
		quit(1)
		return

	print(">>> HOÀN TẤT! Toàn bộ sa bàn đã được lưu trực tiếp vào scenes/gameplay/gameplay.tscn!")
	quit(0)

func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
