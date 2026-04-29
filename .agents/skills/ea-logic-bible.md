# 📜 YOOGI YIN YANG — KINH THÁNH LOGIC EA

> **BẮT BUỘC ĐỌC TRƯỚC KHI CHỈNH SỬA BẤT KỲ DÒNG CODE NÀO.**
> File này chứa toàn bộ logic nguyên thuỷ và bất biến (invariant) của EA.
> Mọi thay đổi code PHẢI tuân thủ các quy tắc trong file này.
> Khi tạo tính năng mới, PHẢI cập nhật file này.

---

## 1. KIẾN TRÚC FILE

```
Yoogi Yin Yang.mq5          ← Main file: OnInit, OnTick, OnDeinit, ProcessNewDeals
├── Include/Input.mqh        ← Tham số đầu vào (input)
├── Include/Globals.mqh      ← Biến toàn cục, struct, hàm tiện ích
├── Include/Indicators.mqh   ← EMA Lock + ADX Filter (State Machine)
├── Include/Corelogic.mqh    ← Logic DCA Âm, DCA Dương, Trailing, Lot Balancing
├── Include/Trimming.mqh     ← Logic tỉa lệnh (Smart Trim, Emergency, Rescue Fund)
├── Include/Security.mqh     ← Xác minh bản quyền
├── Include/Panel.mqh        ← Nút bấm giao diện
├── Include/InfoDisplay.mqh  ← Bảng thông tin trạng thái
├── Include/ProfitDisplay.mqh← Hiển thị quỹ/budget
└── Include/PendingOrders.mqh← Hybrid pending orders, Grid Healing, Refill
```

### ⛔ QUY TẮC INCLUDE
- `CTrade trade;` được khai báo trong file chính, SAU các include nhưng TRƯỚC `PendingOrders.mqh`
- `PendingOrders.mqh` PHẢI được include SAU khai báo `CTrade trade;`

---

## 2. HỆ THỐNG COMMENT PHÂN LOẠI LỆNH

### ⛔ BẤT BIẾN: Encoding comment
EA sử dụng **ASCII không dấu** cho tất cả comment lệnh:

| Comment | Loại lệnh | Mô tả |
|---------|-----------|-------|
| `"Initial Buy"` | Lệnh mở đầu BUY | Lệnh đầu tiên của chu kỳ BUY |
| `"Initial Sell"` | Lệnh mở đầu SELL | Lệnh đầu tiên của chu kỳ SELL |
| `"DCA DUONG"` | DCA Dương | Lệnh thuận xu hướng (giá đi đúng chiều) |
| `"DCA AM"` | DCA Âm | Lệnh ngược xu hướng (giá đi ngược chiều) |

> **TUYỆT ĐỐI KHÔNG sử dụng tiếng Việt có dấu** trong comment lệnh.
> KHÔNG dùng: `"DCA DƯƠNG"`, `"DCA ÂM"`, `"DCA HÀNG"`
> Khi lọc comment bằng `StringFind()`, PHẢI dùng: `"DCA DUONG"`, `"DCA AM"`, `"Initial"`

---

## 3. LUỒNG XỬ LÝ OnTick

Thứ tự xử lý trong `OnTick()` là **BẤT BIẾN** và phải tuân theo đúng trình tự:

```
1. ProcessNewDeals()           ← Cập nhật kế toán deal đóng
2. Reset g_last_close_reason   ← SAU ProcessNewDeals, KHÔNG PHẢI TRƯỚC
3. CheckAndResetAccounting()   ← Reset ngân sách nếu đầu ngày/tuần mới
4. UpdateEmaLockStatus()       ← Cập nhật xu hướng EMA

5. PHA 1: Thu thập positions[] ← Scan toàn bộ vị trí đang mở
6. PHA 1.5: Thu thập pending   ← Scan toàn bộ lệnh chờ
7. PHA 2: Suy luận comment     ← Gán comment cho lệnh mồ côi
8. PHA 3: Tính toán thống kê   ← Đếm lệnh, tính profit từng phe

9. UpdateLockStatus()          ← Xác định trạng thái khoá (DD + EMA)
10. Reset QUỸ ALL nếu 0 lệnh  ← Auto-reset khi không còn position
11. Kiểm tra TP USD            ← Đóng toàn bộ nếu đạt target

12. BỘ NÃO (IsNewBar M1):     ← Logic tỉa khi bị khoá
13. Logic chạy mỗi tick:
    - CleanRedundantPendingOrders
    - SyncPendingVolume
    - HealGridGaps
    - UpdateDynamicBaseLot
    - ManageLotBalancing
    - ManageTesterWithdrawal
    - ManageEmergencyTrimming / ManagePipBasedEmergencyTrim
    - UpdateLockStatus (lần 2)
    - CheckAndOpenInitialTrades
    - ManageBuyPositions / ManageSellPositions
    - ManageTrailingStops
    - TỈA CÙNG CHIỀU (DCA DUONG → Initial → DCA AM)
    - Group Trailing

14. UpdateDisplay + SyncOpenPositionsMemory  ← Cuối tick
```

### ⛔ QUY TẮC THỨ TỰ
- `ProcessNewDeals()` PHẢI chạy ĐẦU TIÊN trong OnTick
- `g_last_close_reason = CR_UNKNOWN` PHẢI đặt SAU `ProcessNewDeals()`
- `UpdateLockStatus()` chạy 2 lần: sau PHA 3 (lần 1) và trước mở lệnh (lần 2)
- `SyncOpenPositionsMemory()` PHẢI là thao tác CUỐI CÙNG trước kết thúc OnTick
- `g_prev_buy_count` / `g_prev_sell_count` PHẢI cập nhật cuối tick

---

## 4. HỆ THỐNG QUỸ TỈA LỆNH

### 4.1 Các loại quỹ

| Biến | Mô tả | Nguồn nạp |
|------|--------|-----------|
| `g_fund_trim_buy` | Quỹ tỉa phe BUY | Lợi nhuận từ lệnh BUY đóng |
| `g_fund_trim_sell` | Quỹ tỉa phe SELL | Lợi nhuận từ lệnh SELL đóng |
| `g_fund_all` | Quỹ ALL (khi dùng TP USD) | Lợi nhuận từ BẤT KỲ lệnh nào đóng |
| `g_budget_day` | Ngân sách ngày | Dùng cho tỉa khẩn cấp |
| `g_budget_week` | Ngân sách tuần | Dùng cho tỉa khẩn cấp |

### 4.2 Quy tắc sử dụng quỹ

| Chế độ `inp_take_profit_usd` | Quỹ dùng cho tỉa | Logic |
|-------------------------------|-------------------|-------|
| `== 0` (tắt TP USD) | `g_fund_trim_buy` / `g_fund_trim_sell` | Tuỳ `TRIM_MODE`: SAME_SIDE hoặc CROSS_SIDE |
| `> 0` (bật TP USD) | `g_fund_all` | Quỹ chung, tỉa phe lỗ NHIỀU hơn trước |

### ⛔ BẤT BIẾN: Quỹ
- Khi tỉa toàn phần thành công → **RESET quỹ về 0** (không trừ dần)
- Khi tỉa một phần thành công → **RESET quỹ về 0** (giống toàn phần)
- Khi 0 lệnh còn mở → **Reset `g_fund_all` về 0** tự động
- Khi số lệnh vượt trigger → **Reset quỹ tương ứng về 0**
- Quỹ được lưu vào **F3 GlobalVariable** để persist qua restart

### 4.3 Logic lọc phe tỉa khi dùng QUỸ ALL

```
Khi inp_take_profit_usd > 0:
  - Cả 2 phe đều lãi      → KHÔNG tỉa (giữ cho TP USD)
  - BUY lỗ nhiều hơn SELL  → Chỉ cho phép tỉa BUY
  - SELL lỗ nhiều hơn BUY  → Chỉ cho phép tỉa SELL
  - Cả 2 phe lỗ bằng nhau  → Cho phép cả 2
```

---

## 5. HỆ THỐNG TỈA LỆNH (TRIMMING)

### 5.1 Thứ tự ưu tiên tỉa cùng chiều

```
1️⃣ DCA DƯƠNG (ưu tiên cao nhất — BLOCKING)
   → Nếu có DCA DƯƠNG lỗ mà chưa đủ quỹ → DỪNG LẠI, KHÔNG tỉa loại khác
2️⃣ Initial
3️⃣ DCA ÂM (ưu tiên thấp nhất)
```

### ⛔ BẤT BIẾN: Blocking Logic
- Nếu có lệnh DCA DƯƠNG đang lỗ nhưng quỹ chưa đủ → **PHẢI CHỜ**, không được nhảy sang tỉa Initial hay DCA ÂM
- Logic này đảm bảo lệnh DCA DƯƠNG (lưới rải) luôn được ưu tiên giải cứu

### 5.2 Tiêu chí kích hoạt

| Chế độ | Điều kiện |
|--------|-----------|
| `TRIM_BY_COUNT` | Số lệnh cùng phe ≥ `inp_trim_trigger_level` |
| `TRIM_BY_DISTANCE` | Lệnh lỗ đã đi xa ≥ `inp_trim_pip_distance` pip |

### 5.3 Tỉa toàn phần vs một phần

```
Quỹ >= (số tiền lỗ + target profit) → Đóng TOÀN PHẦN
Quỹ <  trên nhưng đủ cho partial   → Đóng MỘT PHẦN (inp_trim_close_percentage%)
Quỹ không đủ cả 2                  → CHỜ tích luỹ thêm
```

### 5.4 Phong cách tỉa

| Style | Mô tả |
|-------|-------|
| `TRIM_STYLE_DEFAULT` | Dùng quỹ tích luỹ (g_fund_trim_xxx) |
| `TRIM_STYLE_RESCUE` | Dùng Rescue Fund (đóng trực tiếp lệnh lãi để bù lỗ) |

### 5.5 Bộ Não tỉa khi bị khoá (IsNewBar)

```
Khi CẢ 2 phe bị khoá    → Mỗi phe tự tỉa bằng AttemptSmartTrim
Khi CHỈ BUY bị khoá      → BUY tự tỉa (ưu tiên DCA DUONG→Initial→DCA AM)
                          → Nếu BUY hết lỗ → SELL được tự tỉa
Khi CHỈ SELL bị khoá     → Tương tự ngược lại
Khi KHÔNG ai bị khoá     → KHÔNG tỉa ở đây (để code mỗi tick xử lý)
```

### ⛔ BẤT BIẾN: Không tỉa 2 lần
- Nhánh "BÌNH THƯỜNG" (không khoá) trong IsNewBar **PHẢI ĐỂ TRỐNG**
- Logic tỉa khi bình thường được xử lý bởi code mỗi tick (dòng 650+)
- Tuyệt đối không đặt AttemptSmartTrim vào nhánh else này

### 5.6 Cơ chế Dispatch Tỉa Mặc Định (Mỗi Tick)

EA hỗ trợ 2 chế độ tỉa chạy mỗi tick: `TRIM_MODE_CROSS_SIDE` và `TRIM_MODE_SAME_SIDE`.

#### ⛔ BẤT BIẾN: Loại trừ lẫn nhau
- Khối CROSS TRIM và khối SAME-SIDE TRIM **KHÔNG BAO GIỜ** được chạy cùng lúc.
- Code PHẢI dùng guard `if(inp_trim_mode == TRIM_MODE_XXX_SIDE)` để bọc từng khối riêng biệt.
- Điều này để ngăn chặn EA tỉa 2 lệnh trong 1 tick.

#### ⛔ BẤT BIẾN: Bắt buộc kiểm tra Trigger Count
- **MỌI đường dẫn** gọi đến hàm tỉa (`AttemptTrim...`) đều PHẢI đi qua bước kiểm tra ngưỡng kích hoạt (`inp_trim_trigger_level`).
- Nếu `inp_trim_trigger_mode == TRIM_BY_COUNT`: phe bị tỉa phải có số lệnh >= ngưỡng.
- Cách đếm số lệnh kích hoạt:
  - Nếu `inp_trim_count_both_sides = false`: Chỉ đếm lệnh phe bị tỉa.
  - Nếu `inp_trim_count_both_sides = true`: Đếm tổng lệnh cả BUY và SELL.
- **Trong CROSS_SIDE mode**: 
  - Nếu BUY lãi tỉa SELL lỗ → PHẢI kiểm tra trigger count đối với phe SELL.
  - Nếu SELL lãi tỉa BUY lỗ → PHẢI kiểm tra trigger count đối với phe BUY.

---

## 6. TỈA KHẨN CẤP (EMERGENCY TRIM)

### 6.1 Chế độ Drawdown (`ETM_DRAWDOWN`)

```
DD >= Ngưỡng Tuần (dd2) → Dùng g_budget_week để tỉa
DD >= Ngưỡng Ngày (dd1) → Dùng g_budget_day để tỉa
```
- Tỉa phe có tổng lỗ LỚN HƠN
- Chọn lệnh lỗ CŨ NHẤT trong phe đó

### 6.2 Chế độ Pip (`ETM_PIP`)

```
Lệnh lỗ >= inp_pip_emergency_threshold pip → Kích hoạt tỉa
```

| Style | Hành vi |
|-------|---------|
| `PIP_TRIM_HARD` | Đóng ngay, KHÔNG cần budget |
| `PIP_TRIM_SOFT` | Cần budget (ưu tiên Ngày → Tuần → Partial) |

### ⛔ BẤT BIẾN: Tỉa khẩn cấp
- Chỉ tỉa **1 lệnh mỗi tick** (tránh đóng hàng loạt)
- `g_last_close_reason = CR_EMERGENCY` phải được set TRƯỚC khi đóng lệnh
- Phải gọi `AddEmergencyClose(ticket)` để tracking

---

## 7. HỆ THỐNG KHOÁ LỆNH (LOCK)

### 7.1 Khoá theo Drawdown

```
DD >= Ngưỡng khoá         → Khoá phe có lỗ nhiều hơn
DD < Ngưỡng khoá          → Mở khoá
```

### 7.2 Khoá theo EMA (State Machine)

```
EMA20 > EMA89 (uptrend)   → Khoá SELL (nếu bật inp_ema_lock_sell_on_uptrend)
EMA20 < EMA89 (downtrend) → Khoá BUY (nếu bật inp_ema_lock_buy_on_downtrend)
Đảo chiều                 → Cần ADX > ngưỡng để xác nhận
```

### ⛔ BẤT BIẾN: Khoá
- EMA Lock kiểm tra **chỉ khi có nến M15 mới** (throttle)
- ADX là bộ lọc xác nhận — nếu ADX yếu thì KHÔNG đảo chiều
- Khoá = KHÔNG mở lệnh mới + XOÁ pending của phe bị khoá
- Khoá KHÔNG ảnh hưởng đến tỉa lệnh (tỉa vẫn hoạt động bình thường)

---

## 8. HỆ THỐNG LỆNH CHỜ (PENDING ORDERS)

### 8.1 Chế độ Hybrid

EA sử dụng hệ thống **kết hợp Market + Pending** cho DCA Dương:
- Lệnh Initial: Mở trực tiếp (Market)
- DCA Dương: Đặt sẵn bằng **Buy Stop / Sell Stop**
- Khi giá chạm pending → khớp tự động (giảm slippage)

### 8.2 Các cơ chế tự động

| Cơ chế | Mô tả | Throttle |
|--------|-------|----------|
| `CleanRedundantPendingOrders` | Xoá pending trùng với position đã khớp | Mỗi tick |
| `SyncPendingVolume` | Đồng bộ lot của pending với input hiện tại | 3 giây |
| `HealGridGaps` | Vá lỗ hổng trong lưới giá | 5 giây |
| `RefillStopOrdersIfNeeded` | Nhồi thêm pending khi thiếu | Mỗi tick |
| `RecyclePendingOrders` | Modify giá pending cũ thay vì xoá/tạo mới | Mỗi lần gọi |

### 8.3 Gốc toạ độ lưới (Grid Anchor)

```
Ưu tiên 1: F3 GlobalVariable (LastInitialBuyPrice_SYMBOL_MAGIC)
Ưu tiên 2: Suy ngược từ lịch sử (RecoverInitialPriceFromHistory)
Ưu tiên 3: Giá thị trường hiện tại (fallback cuối cùng)
```

### ⛔ BẤT BIẾN: Pending Orders
- Dung sai kiểm tra trùng: `0.5 * khoảng cách DCA Dương`
- Gap threshold: `1.5 * khoảng cách DCA Dương`
- Pending chỉ dùng comment `"DCA DUONG"` (ASCII, không dấu)
- Khi phe bị khoá → Xoá toàn bộ pending của phe đó
- Lot pending = `inp_lot_dca_duong` (giống nhau cho cả BUY và SELL)

---

## 9. HỆ THỐNG KẾ TOÁN (DEAL TRACKING)

### 9.1 Cơ chế tracking per-ticket

```
Khi đóng lệnh chiến thuật:  AddTacticalClose(ticket)  → Lưu vào g_pending_tactical_ids
Khi đóng lệnh khẩn cấp:     AddEmergencyClose(ticket) → Lưu vào g_pending_emergency_ids
Khi ProcessNewDeals chạy:    LookupCloseReason(pos_id) → Tìm trong 2 mảng trên
```

### 9.2 Cập nhật quỹ khi deal đóng

```
Deal profit > 0:
  → Nạp vào quỹ tỉa (g_fund_trim_buy/sell hoặc g_fund_all)
  → Nạp vào budget ngày/tuần

Deal profit < 0 VÀ lý do = CR_TACTICAL:
  → KHÔNG trừ quỹ (quỹ đã reset về 0 khi tỉa)
  
Deal profit < 0 VÀ lý do = CR_EMERGENCY:
  → Trừ budget ngày/tuần

Deal profit < 0 VÀ lý do = CR_UNKNOWN (đóng thủ công):
  → Trừ budget ngày/tuần
```

### ⛔ BẤT BIẾN: Kế toán
- `HistorySelect(0, TimeCurrent())` phải dùng range từ 0 vì `g_last_processed_deal_count` là index tuyệt đối
- `g_last_processed_deal_count` PHẢI được cập nhật sau khi xử lý xong tất cả deal mới
- Dữ liệu quỹ/budget được lưu trữ trong **F3 GlobalVariable** và **persist qua restart**

---

## 10. TP USD (TAKE PROFIT THEO USD)

```
Khi bật (inp_take_profit_usd > 0):
  - total_ea_profit = tổng P/L đang mở (KHÔNG tính quỹ tỉa)
  - Nếu total_ea_profit >= target → Đóng TOÀN BỘ positions
  - Dùng cờ g_is_closing_tp_usd để retry nếu đóng chưa hết
  - Sau khi đóng hết → Reset g_fund_all, KHÔNG xoá pending (để Recycle)
  - KHÔNG return → Cho phép EA mở Initial mới ngay lập tức
```

### ⛔ BẤT BIẾN: TP USD
- Profit tính = `POSITION_PROFIT + POSITION_SWAP` (bao gồm swap)
- Sau khi TP USD đóng hết lệnh, KHÔNG xoá pending orders (chúng sẽ được Recycle)
- `g_is_closing_tp_usd` phải được reset về false sau khi đóng xong

---

## 11. DCA ÂM — LOGIC MỞ LỆNH NGƯỢC

### 11.1 Điều kiện mở DCA Âm

```
BUY DCA Âm: Giá hiện tại <= (lowest_buy_price - khoảng cách)
SELL DCA Âm: Giá hiện tại >= (highest_sell_price + khoảng cách)
```

### 11.2 Lot DCA Âm

```
Nếu inp_enable_dca_am_xlot = false → Lot cố định: inp_lot_dca_am
Nếu inp_enable_dca_am_xlot = true  → Lot tăng dần theo level: CalculateLot_ForDCA_Am(level)
```

### 11.3 Group Trailing

- DCA Âm được nhóm theo `inp_nhom_lenh` lệnh/nhóm
- Mỗi nhóm có TP trailing riêng
- Group Trailing chạy **SONG SONG** với Trimming (không loại trừ nhau)

### ⛔ BẤT BIẾN: DCA Âm
- Hàm `GetLotSize_ForDCA_Am(level)` chỉ nhận 1 tham số `level` (KHÔNG có `base_lot`)
- `pure_dca_am_buy_pos` / `pure_dca_am_sell_pos` chỉ đếm lệnh có comment `"DCA AM"`
- TP của lệnh Initial bị XOÁ khi có DCA Âm hoặc DCA Dương mới (chỉ khi `total_xxx_pos == 1`)

---

## 12. DCA DƯƠNG — LOGIC MỞ LỆNH THUẬN

### 12.1 Điều kiện mở DCA Dương

```
BUY DCA Dương: Giá hiện tại >= (highest_buy_price + khoảng cách)
SELL DCA Dương: Giá hiện tại <= (lowest_sell_price - khoảng cách)
```

### 12.2 Pending thay Market

- Khi `inp_enable_pending_mode = true`, DCA Dương được đặt bằng **Buy Stop / Sell Stop**
- EA tự động Recycle (modify giá) thay vì xoá/tạo lại

---

## 13. HIỂN THỊ (DISPLAY)

### ⛔ BẤT BIẾN: Display
- InfoDisplay dùng filter `"DCA DUONG"`, `"DCA AM"`, `"Initial"` (ASCII)
- Display cập nhật mỗi **2 giây** (throttle bằng `g_last_ui_update_time`)
- Display KHÔNG ảnh hưởng logic giao dịch — chỉ hiển thị

---

## 14. DANH SÁCH CÁC CỜ TRẠNG THÁI QUAN TRỌNG

| Biến | Mục đích | Reset khi |
|------|----------|-----------|
| `g_is_closing_tp_usd` | Đang đóng TP USD | Đóng hết positions |
| `g_is_buy_locked` | BUY bị khoá | DD giảm hoặc EMA đảo chiều |
| `g_is_sell_locked` | SELL bị khoá | DD giảm hoặc EMA đảo chiều |
| `g_is_buy_locked_by_ema` | BUY bị khoá bởi EMA | EMA đảo chiều + ADX xác nhận |
| `g_is_sell_locked_by_ema` | SELL bị khoá bởi EMA | EMA đảo chiều + ADX xác nhận |
| `g_confirmed_trend` | Xu hướng hiện tại (NONE/UP/DOWN) | Khi EMA cross + ADX confirm |
| `g_last_close_reason` | Lý do đóng lệnh gần nhất | Đầu mỗi tick (SAU ProcessNewDeals) |
| `g_current_emergency_mode` | Trạng thái khẩn cấp (NONE/DAY/WEEK) | Khi DD giảm dưới ngưỡng |
| `g_prev_buy_count` / `g_prev_sell_count` | Số lệnh tick trước | Cuối mỗi tick |

---

## 15. QUY TẮC VÀNG KHI CHỈNH SỬA CODE

1. **KHÔNG BAO GIỜ** thay đổi thứ tự xử lý trong OnTick mà không cập nhật file này
2. **KHÔNG BAO GIỜ** dùng Unicode tiếng Việt có dấu trong comment lệnh hoặc StringFind
3. **KHÔNG BAO GIỜ** đặt logic tỉa lệnh vào nhánh "BÌNH THƯỜNG" của IsNewBar
4. **KHÔNG BAO GIỜ** thay đổi cơ chế đếm deal tuyệt đối (`g_last_processed_deal_count`)
5. **KHÔNG BAO GIỜ** xoá pending orders khi TP USD đóng xong
6. **KHÔNG BAO GIỜ** trừ quỹ tỉa khi deal lỗ có lý do CR_TACTICAL
7. **LUÔN** gọi `AddTacticalClose()` hoặc `AddEmergencyClose()` TRƯỚC khi đóng lệnh
8. **LUÔN** gọi `SaveBudget()` sau khi thay đổi quỹ/budget
9. **LUÔN** cập nhật file skill này khi thêm tính năng mới

---

## CHANGELOG

| Ngày | Thay đổi |
|------|----------|
| 2026-04-26 | Tạo file skill ban đầu từ audit toàn diện v37.3 |
| 2026-04-29 | Bổ sung quy tắc 5.6 (Dispatch) sau khi fix lỗi Cross Trim bypass trigger và Same-Side chạy song song. |
