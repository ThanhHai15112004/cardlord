class_name GameConstants
extends RefCounted

## Bảng Hằng số Toàn cục Cốt lõi (Global Game Constants - Level 1)
## Chứa các quy ước bất biến dùng chung xuyên suốt toàn bộ dự án CardLord.
## Không chứa các hằng số nghiệp vụ riêng của từng phân hệ (Map, Card, Combat).

# ------------------------------------------------------------------------------
# 1. Physics & Collision Layers (Godot 3D/2D Collision Masks)
# ------------------------------------------------------------------------------
const COLLISION_LAYER_TERRAIN: int = 1 << 0      # Bit 1 (1): Mặt sàn địa hình, Raycast chuột
const COLLISION_LAYER_BUILDING: int = 1 << 1     # Bit 2 (2): Công trình trên lưới
const COLLISION_LAYER_RESOURCE: int = 1 << 2     # Bit 3 (4): Mỏ tài nguyên thiên nhiên (Đá, Cây)
const COLLISION_LAYER_ALLY_UNIT: int = 1 << 3    # Bit 4 (8): Binh lính phe ta
const COLLISION_LAYER_ENEMY_UNIT: int = 1 << 4   # Bit 5 (16): Quái vật / Kẻ địch
const COLLISION_LAYER_PROJECTILE: int = 1 << 5   # Bit 6 (32): Đạn, tên lửa

# ------------------------------------------------------------------------------
# 2. Scene Tree Groups (Nhóm định danh Node)
# ------------------------------------------------------------------------------
const GROUP_TERRAIN_TILES: StringName = &"terrain_tiles"
const GROUP_BUILDINGS: StringName = &"buildings"
const GROUP_RESOURCES: StringName = &"resource_nodes"
const GROUP_ENEMIES: StringName = &"enemies"
const GROUP_ALLIES: StringName = &"allies"

# ------------------------------------------------------------------------------
# 3. UI Canvas Layers / Z-Index
# ------------------------------------------------------------------------------
const UI_LAYER_BACKGROUND: int = -10
const UI_LAYER_GAMEPLAY_HUD: int = 10
const UI_LAYER_CARDS_HAND: int = 20
const UI_LAYER_MODAL_POPUP: int = 100
const UI_LAYER_TOOLTIP: int = 200
