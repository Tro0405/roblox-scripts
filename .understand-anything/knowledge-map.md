# TvFruit — Knowledge Map
> Sinh bởi phân tích thủ công (thay cho plugin Understand-Anything, vì môi trường không có `/plugin`).
> Cập nhật: 2026-06-04

## 1. Tổng quan
Bộ script Roblox executor (Delta) phân phối qua GitHub raw + `loadstring`. Kiến trúc **router đa game**: 1 entry duy nhất, tự nhận diện game và nạp script con tương ứng.

```
loadstring(HttpGet(".../main/TvFruit.lua"))()   ← entry point cố định
        │
        ▼
  TvFruit.lua (ROUTER)  ── đọc game.PlaceId ──► GAMES[placeId] ──► HttpGet games/<file> ──► loadstring + chạy
```

## 2. Đồ thị thành phần (nodes & dependencies)

| Node | File | Vai trò | Phụ thuộc |
|------|------|---------|-----------|
| **Router** | `TvFruit.lua` (54 dòng) | Dispatcher: PlaceId → file. Có notify + xử lý lỗi HttpGet/loadstring | → games/*.lua |
| **Theme Lib** | `games/lib/theme.lua` (172) | UI framework dùng chung. Màu chính CYAN `(6,206,227)`. Exports: Colors, Corner, L, Btn, Scroll, Section, Card, Toggle, Slider, `:Window()` | (không) — READABLE |
| **Game: GAG** | `src/grow_a_garden.lua` (186) | BizzyBee Hive Manager — auto re-roll trứng ong | → theme.lua, DataService, BizzyBeeEvent RE |
| **Game: Speed** | `src/speed_escape.lua` (274) | +1 Speed Escape: Fly/Noclip/AutoWalk/AutoWin | → theme.lua |
| **Builder** | `build.py` (70) | Obfuscator: src/ → games/ (XOR + \ddd, wrap loadstring) | Python 3.13 |
| **Hook** | `hooks/pre-commit` | Auto chạy build.py + git add games/ trước mỗi commit | → build.py |
| **⚠ Orphan** | `fly_tool.lua` (686) | Fly+Noclip+SavePos+SpeedSlider standalone | KHÔNG nối router |

## 3. Pipeline build (quan trọng)
```
src/<name>.lua   (READABLE — sửa ở đây)
      │  python build.py  (TARGETS = grow_a_garden, speed_escape)
      ▼
games/<name>.lua (OBFUSCATED — router nạp cái này, KHÔNG sửa tay)
```
- GIỮ READABLE: `TvFruit.lua` (router) + `games/lib/theme.lua` (vì nạp trực tiếp qua HttpGet).
- pre-commit hook tự obfuscate khi commit.

## 4. Bản đồ PlaceId
| PlaceId | Game | File |
|---------|------|------|
| `118941584817777` | +1 Speed Keyboard Escape | speed_escape.lua |
| `126884695634066` | Grow a Garden (BizzyBee) | grow_a_garden.lua |

## 5. Chi tiết logic: grow_a_garden.lua (BizzyBee)
- **Mục tiêu:** auto re-roll trứng ong để săn con ong mong muốn cho từng slot tổ (1–21).
- **POOL:** 4 loại trứng (Common/Rare/Mythical/Transcendent) → bee + weight; tự tính % drop.
- **UI tabs:** Home, Hive (chọn slot→bee), ESP (tên ong trên slot), Settings (DELAY, MAX_PER_SLOT).
- **Remotes:** `BizzyBeeEvent.PlaceBeeEggRE`, `ReplaceBeeRE`. Đọc state qua `DataService:GetData()`.
- **Vòng lặp START:** equip trứng → nếu slot trống thì Place, có rồi thì Replace → chờ slot đổi → lặp tới khi trúng target hoặc hết trứng. Cờ chạy: `getgenv().BeeRunning`.

## 6. Phát hiện / điểm cần lưu ý
- `fly_tool.lua` **không** nằm trong GAMES table cũng không trong build TARGETS → file mồ côi (có thể là nguồn gốc của speed_escape, hoặc tool rời). Cân nhắc: thêm vào router, gộp vào src/, hoặc xoá.
- Obfuscation chỉ cản sao chép thường (reversible XOR); theme.lua + router là plaintext công khai → bảo mật thấp (đã chấp nhận).
- `games/*.lua` chỉ 7 dòng (loader stub) → đúng kỳ vọng output obfuscated.

## 7. Cách thêm game mới
1. Viết `src/<name>.lua` (dùng `Lib:Window` từ theme.lua).
2. Thêm `[placeId] = "<name>.lua"` vào GAMES (TvFruit.lua).
3. Thêm `"<name>.lua"` vào TARGETS (build.py).
4. `git commit` → hook tự obfuscate + push.
