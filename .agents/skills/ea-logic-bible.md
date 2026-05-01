# 📜 YOOGI YIN YANG — KINH THÁNH LOGIC EA (INDUSTRIAL VERSION)

> **BẮT BUỘC ĐỌC TRƯỚC KHI CHỈNH SỬA BẤT KỲ DÒNG CODE NÀO.**
> File này chứa toàn bộ logic nguyên thuỷ và bất biến (invariant) của phiên bản EA Industrial.
> Mọi thay đổi code PHẢI tuân thủ các quy tắc trong file này.

---

## 1. KIẾN TRÚC FILE

```
Yoogi Yin Yang.mq5          ← Main file: OnInit, OnTick, OnDeinit
├── Include/Input.mqh        ← Tham số đầu vào (input)
├── Include/Globals.mqh      ← Biến toàn cục, struct, hàm tiện ích
├── Include/Corelogic.mqh    ← Logic DCA Dương
├── Include/Panel.mqh        ← Nút bấm giao diện
├── Include/InfoDisplay.mqh  ← Bảng thông tin trạng thái
├── Include/ProfitDisplay.mqh← Hiển thị target profit
└── Include/PendingOrders.mqh← Hybrid pending orders, Grid Healing, Refill
```

### ⛔ QUY TẮC INCLUDE
- `CTrade trade;` được khai báo trong file chính, SAU các include nhưng TRƯỚC `PendingOrders.mqh`
- `PendingOrders.mqh` PHẢI được include SAU khai báo `CTrade trade;`

---

## 2. HỆ THỐNG NHẬN DIỆN LỆNH LƯỚI (GRID NODES)

### ⛔ BẤT BIẾN: Không phụ thuộc vào Comment
EA phiên bản Industrial **TUYỆT ĐỐI KHÔNG** phụ thuộc vào Comment (vd "DCA DUONG", "Initial") để phân loại hay nhận diện các lệnh trong lưới (grid) hay tính toán profit.
- Tất cả các vị thế (positions) và lệnh chờ (pending orders) khớp với `inp_magic_number` và `_Symbol` đều được coi là một mắt xích (node) hợp lệ trong lưới.
- Lý do: Sàn giao dịch (Brokers) hoặc các khoản phí Swap thường xuyên tự động thay đổi, cắt xén hoặc ghi đè Comment, dẫn đến việc EA bị "mù" nếu phụ thuộc vào Comment để Heal Grid (vá lưới).
- Cơ chế Neo Lưới (Grid Anchor): Để duy trì và vá lưới, EA sẽ tìm lệnh đang chạy có giá cao nhất (Highest Buy) hoặc thấp nhất (Lowest Sell) làm gốc tọa độ. Không sử dụng F3 GlobalVariables hay lịch sử (history) để tìm lệnh Initial cũ nữa.

---

## 3. LUỒNG XỬ LÝ OnTick

Thứ tự xử lý trong `OnTick()` là **BẤT BIẾN** và phải tuân theo đúng trình tự:

```
1. PHA 1: Thu thập positions[] ← Scan toàn bộ vị trí đang mở của EA
2. PHA 1.5: Thu thập pending   ← Scan toàn bộ lệnh chờ của EA
3. PHA 2: Tính toán thống kê   ← Đếm lệnh, tính profit tổng quan cho từng phe (Buy/Sell)

4. Kiểm tra TP USD            ← Đóng toàn bộ lệnh (EA) nếu đạt target (inp_take_profit_usd)

5. Logic chạy mỗi tick (nếu chưa chốt TP):
    - CleanRedundantPendingOrders
    - SyncPendingVolume
    - HealGridGaps
    - CheckAndOpenInitialTrades
    - ManageBuyPositions / ManageSellPositions

6. UpdateDisplay  ← Cuối tick (Cập nhật UI)
```

### ⛔ QUY TẮC THỨ TỰ
- `UpdateDisplay()` PHẢI là thao tác CUỐI CÙNG trước khi kết thúc OnTick.
- Chức năng chốt lời toàn cục (TP USD) chạy TRƯỚC các hàm quản lý lệnh/lưới (Manage, Heal).

---

<<<<<<< HEAD
## 4. TP USD (TAKE PROFIT THEO USD)
=======
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
```

### ⛔ BẤT BIẾN: Blocking Logic
- Nếu có lệnh DCA DƯƠNG đang lỗ nhưng quỹ chưa đủ → **PHẢI CHỜ**, không được nhảy sang tỉa Initial
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

### ⛔ BẤT BIẾN: Nguyên lý Rescue Fund (Tỉa Trực Tiếp)
- **Nguồn quỹ cứu trợ:** Rescue Fund sử dụng **TẤT CẢ** các lệnh đang lãi (profit > 0) của phe được chỉ định (cùng chiều hoặc chéo chiều). Điều này bao gồm cả **lệnh Initial**. Việc lệnh Initial đang lãi bị đem đi "hiến tế" để bù lỗ là **ĐÚNG LOGIC BẮT BUỘC**, tuyệt đối không được sửa đổi để bảo vệ lệnh Initial.
- **Sắp xếp nguồn quỹ:** Các lệnh lãi sẽ được sắp xếp theo thứ tự **Lãi To Nhất -> Lãi Nhỏ Nhất** và bị đem đi đóng dần cho đến khi đủ tiền bù lỗ.

### ⛔ BẤT BIẾN: Tính nhất quán của mục tiêu (Partial vs Full Trim)
- Bất kể EA đang thực hiện Tỉa Toàn Phần (Full Trim) hay Tỉa Một Phần (Partial Trim), **đối tượng Bị Lỗ (Patient) luôn luôn là MỘT.**
- Lệnh mục tiêu được xác định là lệnh **XA NHẤT SO VỚI GIÁ HIỆN TẠI (Max Pip Distance)**. EA không chọn theo USD lỗ (vì lot khác nhau sẽ làm sai lệch), mà chọn lệnh bị giá đi ngược nhiều pip nhất để ưu tiên "nhổ" cái gai lớn nhất và giải phóng margin một cách chính xác.
- Khi Tỉa Một Phần thực thi, nó sẽ xẻo một phần Volume của lệnh mục tiêu. Ở tick tiếp theo, lệnh này (với Volume đã giảm) **VẪN LÀ lệnh xa nhất**, do đó EA sẽ tiếp tục nhắm vào nó một cách nhất quán.
- **Tuyệt đối không chuyển mục tiêu:** Cho đến khi lệnh mục tiêu bị clear 100%, EA sẽ không bao giờ tự ý chuyển sang tỉa lệnh khác. Điều này đảm bảo tính tuần tự chặt chẽ: Xử lý xong 1 lệnh mới đến lệnh tiếp theo.

### ⛔ BẤT BIẾN: Bảo Vệ Lệnh Initial
- **TUYỆT ĐỐI KHÔNG TỈA LỆNH INITIAL:** Các hàm tỉa (Rescue, Smart Trim, Emergency) KHÔNG ĐƯỢC PHÉP chọn lệnh có comment chứa "Initial" làm mục tiêu cắt lỗ. Lệnh Initial là mỏ neo của lưới và phải được giữ lại cho đến khi chốt lời toàn bộ.
- **KHÔNG DÙNG INITIAL LÀM QUỸ:** Rescue Fund KHÔNG ĐƯỢC PHÉP đóng lệnh Initial đang lãi để lấy tiền đi cứu lệnh lỗ khác. Lệnh Initial lãi phải được bảo toàn.

### 5.5 Cơ chế Dispatch Tỉa Mặc Định (Mỗi Tick)

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

## 7. HỆ THỐNG LỆNH CHỜ (PENDING ORDERS)

### 7.1 Chế độ Hybrid

EA sử dụng hệ thống **kết hợp Market + Pending** cho DCA Dương:
- Lệnh Initial: Mở trực tiếp (Market)
- DCA Dương: Đặt sẵn bằng **Buy Stop / Sell Stop**
- Khi giá chạm pending → khớp tự động (giảm slippage)

### 7.2 Các cơ chế tự động

| Cơ chế | Mô tả | Throttle |
|--------|-------|----------|
| `CleanRedundantPendingOrders` | Xoá pending trùng với position đã khớp | Mỗi tick |
| `SyncPendingVolume` | Đồng bộ lot của pending với input hiện tại | 3 giây |
| `HealGridGaps` | Vá lỗ hổng trong lưới giá | 5 giây |
| `RefillStopOrdersIfNeeded` | Nhồi thêm pending khi thiếu | Mỗi tick |
| `RecyclePendingOrders` | Modify giá pending cũ thay vì xoá/tạo mới | Mỗi lần gọi |

### 7.3 Gốc toạ độ lưới (Grid Anchor)

```
Ưu tiên 1: F3 GlobalVariable (LastInitialBuyPrice_SYMBOL_MAGIC)
Ưu tiên 2: Suy ngược từ lịch sử (RecoverInitialPriceFromHistory)
Ưu tiên 3: Giá thị trường hiện tại (fallback cuối cùng)
```

### ⛔ BẤT BIẾN: Pending Orders
- Dung sai kiểm tra trùng: `0.5 * khoảng cách DCA Dương`
- Gap threshold: `1.5 * khoảng cách DCA Dương`
- Pending chỉ dùng comment `"DCA DUONG"` (ASCII, không dấu)
- Lot pending = `inp_lot_dca_duong` (giống nhau cho cả BUY và SELL)

---

## 8. HỆ THỐNG KẾ TOÁN (DEAL TRACKING)

### 8.1 Cơ chế tracking per-ticket

```
Khi đóng lệnh chiến thuật:  AddTacticalClose(ticket)  → Lưu vào g_pending_tactical_ids
Khi đóng lệnh khẩn cấp:     AddEmergencyClose(ticket) → Lưu vào g_pending_emergency_ids
Khi ProcessNewDeals chạy:    LookupCloseReason(pos_id) → Tìm trong 2 mảng trên
```

### 8.2 Cập nhật quỹ khi deal đóng

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

## 9. TP USD (TAKE PROFIT THEO USD)
>>>>>>> 849371c (Refactor: Update trimming logic to prioritize biggest loss instead of oldest order)

```
Khi bật (inp_take_profit_usd > 0):
  - total_ea_profit = tổng P/L đang mở của tất cả lệnh cùng MagicNumber
  - Nếu total_ea_profit >= target → Đóng TOÀN BỘ positions và Pending Orders liên quan
  - Dùng cờ g_is_closing_tp_usd để đảm bảo tiến trình đóng không bị gián đoạn.
  - Sau khi đóng hết → EA quay lại vòng lặp mới (Reset lưới)
```

### ⛔ BẤT BIẾN: TP USD
- Profit tính = `POSITION_PROFIT + POSITION_SWAP` (bao gồm cả phí swap để không bị lỗ ẩn).
- `g_is_closing_tp_usd` phải được reset về false sau khi đóng xong để EA hoạt động lại bình thường.

---

## 5. HỆ THỐNG LỆNH CHỜ (PENDING ORDERS) VÀ DCA DƯƠNG

### 5.1 Chế độ Hybrid

EA sử dụng hệ thống **kết hợp Market + Pending** cho chiến lược DCA Dương:
- Lệnh Initial: Mở trực tiếp bằng lệnh Market.
- Lệnh DCA Dương: Đặt trước bằng **Buy Stop / Sell Stop**.
- Lợi ích: Khi giá chạy mạnh (trượt giá/slippage), lệnh Pending khớp tự động ở server giúp vào lệnh chính xác hơn so với đặt lệnh Market từ Client.

### 5.2 Các cơ chế tự động bảo vệ lưới

| Cơ chế | Mô tả | Chu kỳ |
|--------|-------|----------|
| `CleanRedundantPendingOrders` | Xoá các lệnh pending trùng lập với position đã khớp (cùng mức giá) | Mỗi tick |
| `SyncPendingVolume` | Tự động cập nhật lại lot của pending nếu `inp_lot_dca_duong` bị thay đổi thủ công | 3 giây |
| `HealGridGaps` | Tự động vá các lỗ hổng (gap) trong lưới giá nếu phát hiện thiếu mắt xích | 5 giây |
| `RefillStopOrdersIfNeeded` | Tự động nhồi thêm lệnh pending phía trước khi giá đẩy lên gần hết lệnh chờ | Mỗi tick |
| `RecyclePendingOrders` | Cập nhật (Modify) giá của các lệnh pending cũ thừa thãi thay vì xoá/tạo mới để tối ưu tốc độ | Mỗi khi cần |

### ⛔ BẤT BIẾN: Pending Orders & Grid
- **Dung sai (Tolerance):** Khi kiểm tra trùng lệnh tại một mức giá, EA dùng sai số `0.5 * khoảng cách DCA Dương`.
- **Gap Threshold:** Khoảng cách để EA xác định là "lỗ hổng" cần vá là `1.5 * khoảng cách DCA Dương`.
- Lot pending = `inp_lot_dca_duong` (sử dụng lot tĩnh, không nhồi martingale hay volume multiplier).
- Lưới Neo (Anchor): Luôn lấy mức giá cao nhất của BUY hoặc thấp nhất của SELL đang Active để xác định hướng rải lệnh pending tiếp theo.

---

## 6. DANH SÁCH CÁC CỜ TRẠNG THÁI QUAN TRỌNG

| Biến | Mục đích | Reset khi |
|------|----------|-----------|
| `g_is_closing_tp_usd` | Khóa EA khi đang trong quá trình đóng chốt lời TP USD | Đóng hết vị thế thành công |

---

## 7. QUY TẮC VÀNG KHI CHỈNH SỬA CODE

1. **KHÔNG BAO GIỜ** thay đổi thứ tự xử lý trong OnTick mà không cập nhật file này.
2. **KHÔNG BAO GIỜ** phụ thuộc vào Comment (`OrderGetString(ORDER_COMMENT)`) để gán logic giao dịch quan trọng.
3. **LUÔN** giữ kiến trúc "Industrial": Tối giản, chạy nhẹ, tập trung vào sức mạnh của DCA Dương và chốt lời tổng cục (TP USD). Mọi tính năng rác (DCA Âm, Trimming, Break Even, Trailing, Lưới đa tầng) đã bị gỡ bỏ vĩnh viễn và không được khôi phục.
4. **LUÔN** cập nhật file skill này khi thêm tính năng mới hoặc thay đổi cơ chế cốt lõi.

---

## CHANGELOG

| Ngày | Thay đổi |
|------|----------|
| 2026-04-26 | Tạo file skill ban đầu từ audit toàn diện v37.3 |
| 2026-04-29 | Loại bỏ các phần logic rác cũ (DCA Âm, Trailing, Lock, Trimming các loại) để cấu trúc lại thành bản Industrial. |
| 2026-05-01 | Xóa bỏ sự phụ thuộc vào Order Comment. Hệ thống chuyển sang neo tự động bằng lệnh cao/thấp nhất (Grid Nodes) để vá Gap (Heal Grid) cực chuẩn. Cập nhật lại Kinh Thánh phù hợp với bản Industrial tối giản. |
