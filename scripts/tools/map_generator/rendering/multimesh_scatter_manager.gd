@tool
class_name MultiMeshScatterManager
extends RefCounted

## Quản Lý Phân Tán Đồ Họa Đa Lưới GPU (GPU MultiMesh Scatter Manager)
## Gom toàn bộ cây cối và tảng đá phân bổ từ Phase 06 vào các MultiMeshInstance3D
## chuyên biệt nhằm tối ưu hóa Draw Calls xuống mức tối thiểu (< 5 Draw Calls cho Foliage).

# Đường dẫn tài nguyên 3D mặc định
const MODEL_PATH_TREE_1: String = "res://assets/models/forest/trees/Tree_1_A_Color1.gltf"
const MODEL_PATH_TREE_2: String = "res://assets/models/forest/trees/Tree_2_A_Color1.gltf"
const MODEL_PATH_ROCK: String = "res://assets/models/forest/rocks/Rock_1_A_Color1.gltf"

## Lưu đệm Mesh & Material đã trích xuất để tái sử dụng
static var _mesh_cache: Dictionary = {}

# ------------------------------------------------------------------------------
# 1. Điểm Đầu Vào Chính (Main Entry Point)
# ------------------------------------------------------------------------------

## Xây dựng và gắn các node MultiMeshInstance3D vào container chỉ định
static func build_multimeshes(container: Node3D, context: MapGenContext) -> void:
	if container == null or context == null:
		push_error("MultiMeshScatterManager.build_multimeshes(): container hoặc context null!")
		return
		
	# 1. Gom nhóm danh sách ma trận biến đổi (Transform3D) theo nhóm Asset
	var tree1_transforms: Array[Transform3D] = []
	var tree2_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	
	if context.categorized_foliage.has("tree_1"):
		tree1_transforms.append_array(context.categorized_foliage["tree_1"])
	if context.categorized_foliage.has("forest_cluster"):
		tree1_transforms.append_array(context.categorized_foliage["forest_cluster"])
		
	if context.categorized_foliage.has("tree_2"):
		tree2_transforms.append_array(context.categorized_foliage["tree_2"])
		
	if context.categorized_foliage.has("rock_large"):
		rock_transforms.append_array(context.categorized_foliage["rock_large"])
	if context.categorized_foliage.has("rock_med"):
		rock_transforms.append_array(context.categorized_foliage["rock_med"])
		
	# 2. Khởi tạo và nạp từng MultiMeshInstance3D
	# MultiMesh_Tree1
	if not tree1_transforms.is_empty():
		var tree1_mesh_info = _get_or_load_mesh(MODEL_PATH_TREE_1, _create_fallback_tree_mesh())
		var mmi_tree1 = _create_multimesh_instance("MultiMesh_Tree1", tree1_mesh_info, tree1_transforms)
		container.add_child(mmi_tree1)
		
	# MultiMesh_Tree2
	if not tree2_transforms.is_empty():
		var tree2_mesh_info = _get_or_load_mesh(MODEL_PATH_TREE_2, _create_fallback_tree_mesh())
		var mmi_tree2 = _create_multimesh_instance("MultiMesh_Tree2", tree2_mesh_info, tree2_transforms)
		container.add_child(mmi_tree2)
		
	# MultiMesh_Rocks
	if not rock_transforms.is_empty():
		var rock_mesh_info = _get_or_load_mesh(MODEL_PATH_ROCK, _create_fallback_rock_mesh())
		var mmi_rocks = _create_multimesh_instance("MultiMesh_Rocks", rock_mesh_info, rock_transforms)
		container.add_child(mmi_rocks)

# ------------------------------------------------------------------------------
# 2. Khởi Tạo MultiMeshInstance3D (MultiMesh Instance Factory)
# ------------------------------------------------------------------------------

## Khởi tạo 1 MultiMeshInstance3D với số lượng và ma trận biến đổi tương ứng
static func _create_multimesh_instance(
	node_name: String,
	mesh_info: Dictionary,
	transforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_info.get("mesh", null)
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		
	mmi.multimesh = mm
	
	var mat = mesh_info.get("material", null)
	if mat != null:
		mmi.material_override = mat
		
	return mmi

# ------------------------------------------------------------------------------
# 3. Trích Xuất & Lưu Đệm Mesh / Material (Asset Extraction & Caching)
# ------------------------------------------------------------------------------

static func _get_or_load_mesh(model_path: String, fallback_mesh: Mesh) -> Dictionary:
	if _mesh_cache.has(model_path):
		return _mesh_cache[model_path]
		
	var info = _extract_mesh_from_scene(model_path, fallback_mesh)
	_mesh_cache[model_path] = info
	return info

static func _extract_mesh_from_scene(model_path: String, fallback_mesh: Mesh) -> Dictionary:
	var res = load(model_path)
	if not (res is PackedScene):
		push_warning("MultiMeshScatterManager: Không tải được PackedScene từ: %s. Sử dụng mesh fallback." % model_path)
		return {"mesh": fallback_mesh, "material": null}
		
	var inst: Node = (res as PackedScene).instantiate()
	if inst == null:
		return {"mesh": fallback_mesh, "material": null}
		
	var found_mesh: Mesh = null
	var found_mat: Material = null
	
	# Tìm MeshInstance3D đầu tiên
	var nodes_to_check: Array[Node] = [inst]
	while not nodes_to_check.is_empty():
		var curr = nodes_to_check.pop_front()
		if curr is MeshInstance3D and curr.mesh != null:
			found_mesh = curr.mesh
			if curr.material_override != null:
				found_mat = curr.material_override
			elif curr.get_surface_override_material_count() > 0 and curr.get_surface_override_material(0) != null:
				found_mat = curr.get_surface_override_material(0)
			elif found_mesh.get_surface_count() > 0:
				found_mat = found_mesh.surface_get_material(0)
			break
		for child in curr.get_children():
			nodes_to_check.append(child)
			
	# Giải phóng ngay node tạm thời để tránh rò rỉ bộ nhớ
	inst.free()
	
	if found_mesh == null:
		found_mesh = fallback_mesh
		
	return {"mesh": found_mesh, "material": found_mat}

# ------------------------------------------------------------------------------
# 4. Fallback Primitives (Khi thiếu Assets)
# ------------------------------------------------------------------------------

static func _create_fallback_tree_mesh() -> Mesh:
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.8
	cylinder.height = 2.5
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.48, 0.22) # Xanh lá đậm
	cylinder.material = mat
	return cylinder

static func _create_fallback_rock_mesh() -> Mesh:
	var box = BoxMesh.new()
	box.size = Vector3(1.2, 0.8, 1.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.48) # Xám đá
	mat.roughness = 0.9
	box.material = mat
	return box
