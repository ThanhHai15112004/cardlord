# CARDLORD

> **BUILD • GROW • DEFEND • ADAPT**

**CARDLORD** là tựa game chiến thuật kết hợp độc đáo giữa **Card Strategy (Thẻ bài chiến thuật)**, **Kingdom Building (Xây dựng vương quốc)**, **Base Defense (Phòng thủ căn cứ)** và các yếu tố **Roguelite** chơi lại theo lượt.

Trong vai một Lãnh chúa bắt đầu với một Thủ phủ (Capital) nhỏ, một bộ bài khởi điểm và lượng tài nguyên hạn chế, người chơi phải tính toán từng nước đi: mở rộng kinh tế để tăng trưởng dài hạn hay dồn tài nguyên củng cố quân sự để chống chọi các đợt tấn công ngày càng dồn dập từ kẻ địch.

---

## 🌟 Tính Năng Nổi Bật (Key Features)

- 🃏 **Thẻ bài là Hành động (Cards as Actions)**: Mỗi lá bài đại diện cho một quyết định: xây dựng công trình, chiêu mộ binh sĩ, thu thuế, gia cố phòng tuyến hoặc kích hoạt các chiến thuật can thiệp tức thời.
- 🏰 **Quy hoạch Vương quốc trên Lưới (Grid-based Kingdom)**: Công trình được đặt trực tiếp lên bản đồ và tồn tại lâu dài, tạo hiệu ứng cộng hưởng vị trí (adjacency bonus) và sản lượng tài nguyên qua từng lượt.
- ⚖️ **Kinh tế 4 Tài nguyên Cốt lõi**:
  - **Gold (Vàng)**: Chiêu mộ quân, nâng cấp, bảo dưỡng và trả phí sự kiện.
  - **Food (Lương thực)**: Duy trì dân số và tiếp tế quân đội; thiếu hụt sẽ làm giảm sức chiến đấu (*Low Supply*).
  - **Materials (Vật liệu)**: Xây dựng cơ sở hạ tầng, thành lũy và công sự kiên cố.
  - **Population (Dân số)**: Giới hạn năng lực điều động công nhân và quân ngũ.
- ⚔️ **Chiến đấu Đội hình (Squad-based Combat)**: Các đơn vị chiến đấu theo cơ chế squad gọn gàng, hỗ trợ khắc chế binh chủng (Bộ binh, Xạ thủ, Kỵ binh, Công thành).
- 🔄 **Vòng lặp Roguelite Cuốn hút**: Thua cuộc để học hỏi, mở khóa thêm các thẻ bài mới, chỉ số nền và các thử thách độ khó cao hơn.

---

## 🔁 Vòng Lặp Lối Chơi (Core Gameplay Loop)

```
[ RÚT THẺ BÀI ] ─► [ XÂY DỰNG & QUY HOẠCH ] ─► [ SẢN XUẤT TÀI NGUYÊN ]
       ▲                                                    │
       │                                                    ▼
[ PHÁT TRIỂN / MỞ RỘNG ] ◄── [ CHIẾN THẮNG / THƯỞNG ] ◄── [ CHIẾN ĐẤU / PHÒNG THỦ ]
```

---

## 🛠️ Công Nghệ & Nền Tảng (Tech Stack)

- **Game Engine**: [Godot Engine 4.x](https://godotengine.org/) (Forward Plus / D3D12)
- **Physics Engine**: Jolt Physics 3D (tối ưu hiệu năng và ổn định)
- **Ngôn ngữ**: GDScript
- **Phong cách đồ họa**: 2D Isometric / 3/4 Top-down, Stylized Medieval Fantasy

---

## 📁 Cấu Trúc Thư Mục Dự Án (Project Structure)

```text
.
├── project.godot                  # Cấu hình dự án & Autoloads
├── .gitignore                     # Cấu hình bỏ qua các file tạm/cache
├── README.md                      # Tài liệu giới thiệu dự án
├── assets/                        # Tài nguyên đa phương tiện
│   ├── audio/                     # Nhạc nền (BGM) và hiệu ứng âm thanh (SFX)
│   ├── fonts/                     # Phông chữ UI
│   └── sprites/                   # Đồ họa 2D (Cards, Buildings, Units, Environment, UI)
├── data/                          # Các file định nghĩa dữ liệu Game (.tres)
│   ├── buildings/
│   ├── cards/
│   ├── enemies/
│   ├── events/
│   └── units/
├── scenes/                        # Các màn chơi / Scene Godot (.tscn)
│   ├── cards/
│   ├── combat/
│   ├── gameplay/
│   ├── kingdom/
│   ├── main/
│   └── ui/
├── scripts/                       # Mã nguồn GDScript
│   ├── core/                      # Hệ thống lõi (EventBus singleton, GameManager, TurnSystem)
│   ├── data/                      # Định nghĩa Custom Resource (CardData, BuildingData, UnitData)
│   ├── entities/                  # Logic thực thể game
│   ├── systems/                   # Logic các phân hệ (CardSystem, ResourceSystem, GridSystem)
│   └── ui/                        # Logic giao diện người dùng
└── tests/                         # Scripts kiểm thử và nguyên mẫu (Prototypes)
```

---

## 🏛️ Kiến Trúc Hệ Thống (Architecture)

1. **Event-Driven Architecture**:
   - Sử dụng `EventBus` (`scripts/core/event_bus.gd`) làm trạm trung chuyển signal toàn cục, giảm phụ thuộc trực tiếp (loose coupling) giữa Card UI, Bản đồ, Kinh tế và Chiến đấu.
2. **Data-Driven Design (Resource-Based)**:
   - Toàn bộ nội dung game (Thẻ bài, Công trình, Binh lính) được định nghĩa qua Godot `Resource` (`CardData`, `BuildingData`, `UnitData`), giúp dễ dàng mở rộng nội dung và cân bằng chỉ số mà không cần sửa code.

---

## 🚀 Hướng Dẫn Chạy Dự Án (Getting Started)

1. **Yêu cầu**: Cài đặt **Godot Engine 4.x** (khuyến nghị bản 4.3 trở lên).
2. **Khởi động dự án**:
   - Mở Godot Engine.
   - Chọn **Import** -> Trỏ tới thư mục chứa file `project.godot`.
   - Bấm **Import & Edit**.

---

## 🗺️ Lộ Trình Phát Triển (Roadmap)

- [x] Khởi tạo dự án Godot 4
- [x] Quy hoạch cấu trúc thư mục chuẩn hóa
- [x] Thiết lập EventBus và các Custom Resource nền tảng (CardData, BuildingData, UnitData)
- [ ] Xây dựng Prototype MVP:
  - [ ] Hệ thống Quản lý Tài nguyên (Resource Manager)
  - [ ] Hệ thống Rút bài / Đánh bài (Card System UI & Drag-Drop)
  - [ ] Lưới xây dựng cơ bản (Grid & Building Placement)
  - [ ] Vòng lặp lượt đi và đợt tấn công của kẻ địch (Turn Loop & Wave Defense)
- [ ] Hoàn thiện hệ thống chiến đấu và AI
- [ ] Tích hợp đồ họa và âm thanh hoàn chỉnh
