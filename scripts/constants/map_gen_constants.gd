class_name MapGenConstants
extends RefCounted

## Bảng Hằng số & Enums Phân hệ Sinh Bản đồ (Map Generation Constants - Level 2)
## Quy định toàn bộ các quy chuẩn toán học, phân tầng địa hình, bitmask đường mòn,
## và các enum bất biến phục vụ quy trình 16 bước Procedural Diorama Engine.

# ------------------------------------------------------------------------------
# 1. Phân tầng Cao độ & Bảng Tra Chiều Cao Y (Elevation & Verticality)
# ------------------------------------------------------------------------------

enum ElevationLevel {
	RIVER_BED = 0,      ## Đáy sông sâu (River Bed)
	LOWLAND = 1,        ## Bờ sông / Bãi bồi thấp (River Bank / Lowland)
	GRASSLAND = 2,      ## Đồng bằng trung tâm (Playable Stage)
	PLATEAU = 3,        ## Gò đồi / Bệ Lâu Đài (Castle Plateau)
	HILL = 4,           ## Đồi nhấp nhô (Intermediate Hill)
	MOUNTAIN = 5,       ## Chân núi đá (Edge Mountain Base)
	HIGH_MOUNTAIN = 6   ## Vách núi biên giới đóng hộp (High Mountain Rim)
}

## Độ chênh lệch chuẩn theo mét giữa mỗi nấc phân tầng
const LEVEL_HEIGHT_STEP: float = 0.5

## Bảng tra độ lệch Y thực tế (World Y Offset) theo từng cấp bậc Level (0..6)
const ELEVATION_Y_OFFSETS: Dictionary = {
	ElevationLevel.RIVER_BED: -0.70,
	ElevationLevel.LOWLAND: 0.00,
	ElevationLevel.GRASSLAND: 0.50,
	ElevationLevel.PLATEAU: 1.50,
	ElevationLevel.HILL: 2.50,
	ElevationLevel.MOUNTAIN: 4.00,
	ElevationLevel.HIGH_MOUNTAIN: 6.00
}

# ------------------------------------------------------------------------------
# 2. Vector Lân Cận Ô Cờ (Grid Neighborhood Offsets)
# ------------------------------------------------------------------------------

## 4 hướng chính giao nhau (North, East, South, West)
const NEIGHBOR_OFFSETS_4: Array[Vector2i] = [
	Vector2i(0, -1), # North
	Vector2i(1, 0),  # East
	Vector2i(0, 1),  # South
	Vector2i(-1, 0)  # West
]

## 8 hướng bao quanh ô cờ (kèm các hướng chéo)
const NEIGHBOR_OFFSETS_8: Array[Vector2i] = [
	Vector2i(0, -1),  # North
	Vector2i(1, -1),  # North-East
	Vector2i(1, 0),   # East
	Vector2i(1, 1),   # South-East
	Vector2i(0, 1),   # South
	Vector2i(-1, 1),  # South-West
	Vector2i(-1, 0),  # West
	Vector2i(-1, -1)  # North-West
]

# ------------------------------------------------------------------------------
# 3. Phân loại Thủy văn & Vách đá (Hydrology & Cliff Stitching)
# ------------------------------------------------------------------------------

## Đới phân chia mặt nước và kè bờ
enum WaterZone {
	LAND = 0,  ## Đất liền khô ráo
	BANK = 1,  ## Bờ dốc kè đá sông
	WATER = 2  ## Lòng sông ngập nước
}

## Hướng mặt diện vách đá cần cắm model khâu lưới (Cliff Face Orientation)
enum CliffFace {
	NORTH = 0,
	EAST = 1,
	SOUTH = 2,
	WEST = 3
}

# ------------------------------------------------------------------------------
# 4. Mạng Lưới Đường & Bitmask Tự Động Nối (Road Auto-Tiling Bitmask)
# ------------------------------------------------------------------------------

enum RoadBitmask {
	NONE = 0,
	NORTH = 1 << 0, # 1
	EAST = 1 << 1,  # 2
	SOUTH = 1 << 2, # 4
	WEST = 1 << 3   # 8
}

# ------------------------------------------------------------------------------
# 5. Phân Loại Điểm Quan Trọng (Points of Interest - POI)
# ------------------------------------------------------------------------------

enum POIType {
	NONE = 0,
	CASTLE = 1,     ## Đại bản doanh lâu đài
	BRIDGE = 2,     ## Cầu gỗ có mái che vượt sông
	QUARRY = 3,     ## Mỏ đá tự nhiên
	LUMBER = 4,     ## Rừng khai thác gỗ trù phú
	SCOUT_CAMP = 5  ## Tiền đồn / Do thám quái vật bìa rừng
}
