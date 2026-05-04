//+------------------------------------------------------------------+
//|                                                      Input.mqh |
//|                      --- YOOGI INDUSTRIAL YANG - INPUT ---       |
//|          (Phiên bản Industrial - Tối ưu cho sử dụng cá nhân)     |
//+------------------------------------------------------------------+

#include "Globals.mqh"

//===================================================================
// = 1. CÀI ĐẶT CHUNG TỔNG QUAN                                     =
//===================================================================
input group "--- 1. Cài đặt chung ---"
input ulong  inp_magic_number       = 12345;  // Magic Number
input double inp_initial_tp_pips    = 20.0;   // Take Profit cho lệnh đầu (0 = tắt)
input double inp_take_profit_usd    = 0.0;    // TP USD (0 = tắt)
input bool inp_withdrawal_mode = false;   // Rút tiền

//===================================================================
// = 2. KHỐI LƯỢNG & KHOẢNG CÁCH CƠ BẢN                             =
//===================================================================
input group "--- 2. Khối Lượng Ban Đầu ---"
input double inp_lot_dca_duong      = 0.01;   // Lot DCA Duong (Initial + DCA Duong)
input double inp_dca_duong_distance_pips   = 100.0; // Khoảng cách nhồi DCA DƯƠNG

//===================================================================
// = 3. CÔNG TẮC MŨI NHỌN GIAO DỊCH                                 =
//===================================================================
input group "--- 3. Kiểm Soát Chiều Giao Dịch ---"
input bool   inp_enable_buy         = true;   // Cho phép EA mở lệnh BUY
input bool   inp_enable_sell        = true;   // Cho phép EA mở lệnh SELL
input bool   inp_enable_dca_duong   = true;   // Bật/Tắt DCA DƯƠNG (Thuận xu hướng)

//===================================================================
// = 4. CHẾ ĐỘ VÀO LỆNH PENDING (CHỐNG TRƯỢT GIÁ)                   =
//===================================================================
input group "--- 4. Chế Độ Pending Orders ---"
input bool   inp_enable_pending_mode      = true;    // Bật Chế Độ Pending Orders (Chống Trượt Giá)
input int    inp_pending_order_count      = 50;      // Số lượng lệnh Stop/Limit đặt trước mỗi biên
input int    inp_pending_refill_threshold = 10;      // Số lệnh tối thiểu trước khi tự động nhồi thêm
input bool   inp_pending_auto_refill      = true;    // Tự động đặt thêm khi hết

//===================================================================
// = 5. TỈA LỆNH TỰ ĐỘNG BẢO VỆ VỐN                                =
//===================================================================
// --- Che do tia lenh ---
enum ENUM_TRIM_MODE
{
   TRIM_MODE_SAME_SIDE  = 0,   // Tia cung chieu (Quy BUY tia lo BUY)
   TRIM_MODE_CROSS_SIDE = 1    // Tia cheo (Quy BUY tia lo SELL)
};

// --- Dieu kien kich hoat tia lenh ---
enum ENUM_TRIM_TRIGGER
{
   TRIM_BY_COUNT    = 0,   // Theo so lenh
   TRIM_BY_DISTANCE = 1    // Theo khoang cach pip
};

// --- Kieu co che tia lenh ---
enum ENUM_TRIM_STYLE
{
   TRIM_STYLE_FUND    = 0,   // Quy tich luy (Gian tiep)
   TRIM_STYLE_RESCUE  = 1    // Rescue Fund (Truc tiep - dong lenh lai)
};

input group "--- 5. Tia Lenh Mac Dinh ---"
input bool   inp_use_trimming          = false;     // Bat/Tat tia lenh
input ENUM_TRIM_STYLE inp_trim_style   = TRIM_STYLE_FUND; // Kieu co che tia lenh
input ENUM_TRIM_MODE inp_trim_mode     = TRIM_MODE_SAME_SIDE; // Che do tia lenh (quy)
input ENUM_TRIM_TRIGGER inp_trim_trigger_mode = TRIM_BY_COUNT; // Dieu kien kich hoat tia
input int    inp_trim_trigger_level    = 10;        // So lenh de kich hoat tia (BY_COUNT)
input bool   inp_trim_count_both_sides = false;     // Kich hoat tia dua tren TONG lenh Buy+Sell
input double inp_trim_pip_distance     = 50.0;      // Khoang cach pip kich hoat tia (BY_DISTANCE)
input double inp_trim_close_percentage = 30.0;      // % khoi luong muon tia
input double inp_trim_target_profit    = 5.0;       // Loi nhuan muc tieu sau khi tia

//===================================================================
// = 6. TỈA LỆNH KHẨN CẤP THEO VÙNG GẦN CHÁY TÀI KHOẢN             =
//===================================================================
// --- Kieu tia khan cap theo pip ---
enum ENUM_PIP_TRIM_STYLE
{
   PIP_TRIM_SOFT = 0,   // Tia mem (can budget D/W)
   PIP_TRIM_HARD = 1    // Tia cung (dong ngay khong can budget)
};

input group "--- 6. Tia Lenh Khan Cap ---"
input ENUM_EMERGENCY_TRIM_MODE inp_emergency_trim_mode = ETM_DISABLED; // Che do tia khan cap
input double inp_pip_emergency_threshold      = 100.0;    // Nguong Pip kich hoat (cho ETM_PIP)
input ENUM_PIP_TRIM_STYLE inp_pip_trim_style  = PIP_TRIM_SOFT; // Kieu tia theo pip
input double inp_emergency_dd1_amount         = 2000.0;   // DD kich hoat tia theo LAI NGAY
input double inp_emergency_profit_retention_day = 50.0;   // % Loi nhuan muon giu lai
input double inp_emergency_dd2_amount         = 3000.0;   // DD kich hoat tia theo LAI TUAN
input double inp_emergency_profit_retention_week= 70.0;   // % Loi nhuan muon giu lai

//===================================================================
// = 7. SETTING MÔ PHỎNG ĐÁNH GIÁ (STRATEGY TESTER)                =
//===================================================================
input group "--- 7. Tester Withdrawal Settings ---"
input bool   inp_tester_withdrawal_enabled   = false;  // Bật chế độ rút tiền ảo trong Tester
input double inp_tester_base_balance         = 8000.0; // Số dư gốc mong muốn duy trì
input double inp_tester_withdraw_threshold   = 1000.0; // Lợi nhuận đạt được để kích hoạt rút
input double inp_tester_withdraw_amount      = 1000.0; // Số tiền rút mỗi lần
