//+------------------------------------------------------------------+
//|                                                      Input.mqh |
//|                             --- TỆP CHỨA TẤT CẢ CÁC INPUT ---   |
//|                 (Phiên bản cập nhật - Thêm chế độ Tỉa Chỉ Định)  |
//+------------------------------------------------------------------+

#include "Globals.mqh"

//--- Cài đặt chung ---
input group "---  Cài đặt chung  ---"
input ulong  inp_magic_number       = 12345;  // Magic Number
input double inp_lot_dca_duong      = 0.01;   // Lot DCA Duong (Initial + DCA Duong)
input double inp_lot_dca_am         = 0.01;   // Lot DCA Am
input double inp_initial_tp_pips    = 20.0;   // Take Profit cho lệnh đầu (0 = tắt)
input double inp_take_profit_usd    = 0.0;    // TP USD (0 = tắt)
input bool inp_withdrawal_mode = false;   // Rút tiền

//---  Kiểm Soát Chiều Giao Dịch  ---
input group "---  Kiểm Soát Chiều Giao Dịch  ---"
input bool   inp_enable_buy         = true;   // Cho phép EA mở lệnh BUY
input bool   inp_enable_sell        = true;   // Cho phép EA mở lệnh SELL
input bool   inp_enable_dca_duong   = true;   // Bật/Tắt DCA DƯƠNG (Thuận xu hướng)
input bool   inp_enable_dca_am      = true;   // Bật/Tắt DCA Âm (Ngược xu hướng)
input bool   inp_enable_lot_balancing      = true;   // Bật / Tắt Cân Bằng Lot DCA DƯƠNG
input bool   inp_enable_dca_am_xlot  = true;   // Bật / Tắt xLot DCA Am (true=nhan lot, false=lot ban dau)


//--- Trailing Stop (Lệnh Đơn - Cho DCA DƯƠNG & Lệnh Ban Đầu)
input group "---  Trailing Stop DCA DƯƠNG  ---"
input bool   inp_enable_individual_trailing = true;     // Bật/Tắt Trailing Stop DCA DƯƠNG
input double inp_individual_trailing_start_pips = 200.0;    // Lợi nhuận để bắt đầu trailing
input double inp_individual_trailing_dist_pips  = 50.0;     // Khoảng cách trailing

//--- Trailing Stop THEO NHÓM (Dùng cho chuỗi DCA Âm)
input group "---  Trailing Stop DCA Âm  ---"
input bool   inp_enable_group_trailing       = true;     // Bật/Tắt Trailing Stop DCA ÂM
input double inp_group_trailing_start_pips     = 20.0;     // Lợi nhuận để bắt đầu trailing
input double inp_group_trailing_dist_pips      = 15.0;     // Khoảng cách trailing

//--- DCA DƯƠNG ---
input group "--- DCA DƯƠNG ---"
input double inp_dca_duong_distance_pips   = 100.0; // Khoảng cách nhồi DCA DƯƠNG
// input double inp_dca_duong_reclassify_pips = 200.0; // ĐÃ XÓA: KC chuyển DCA DƯƠNG thành DCA Âm
input double inp_balance_activation_dd     = 100.0; // DD kích hoạt Cân Bằng Lot (0 = luôn bật)
input double inp_lot_balance_threshold     = 0.5;   // Ngưỡng chênh lệch Lot để kích hoạt cân bằng (0 = tắt)
//--- Hạn chế DCA Cân bằng Lot theo Vùng giá ---
input bool   inp_balance_zone_enabled      = true;    // Bật/Tắt giới hạn lệnh DCA DƯƠNG
input double inp_balance_zone_pips       = 10.0;    // Kích thước vùng giới hạn
input int    inp_balance_zone_max_orders   = 3;       // Số lệnh DCA DƯƠNG tối đa trong vùng

//--- Quản Lý Khóa DD & Tỉa Lệnh Chéo ---
input group "--- Quản Lý Khóa DD & Tỉa Lệnh Chéo ---"
input double inp_dd_lock_buy_amount  = 200.0; // Ngưỡng DD để KHÓA phe BUY (0 = tắt)
input double inp_dd_lock_sell_amount = 200.0; // Ngưỡng DD để KHÓA phe SELL (0 = tắt)
// EMA Timeframe (Hidden)
ENUM_TIMEFRAMES inp_ema_timeframe = PERIOD_M15;
input bool   inp_ema_lock_sell_on_uptrend       = true;   // Bật: Khóa SELL khi có xu hướng TĂNG
input bool   inp_ema_lock_buy_on_downtrend      = true;   // Bật: Khóa BUY khi có xu hướng GIẢM

// ADX Inputs (Hidden)
bool   InpUseAdxFilter                    = true;
int    InpAdxPeriod                       = 14;
double InpAdxLevel                        = 25.0;


//---  Nâng/Hạ Lot theo Drawdown  ---
input group "---  Nâng/Hạ Lot DCA DƯƠNG theo Drawdown  ---"
input group "Mức 1";  
input double inp_loss_level_1 = 100.0;  // DD kích hoạt mức 1
input double inp_lot_level_1  = 0.02;   // Lot áp dụng mức 1
input double inp_dist_level_1 = 80.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 1
input group "Mức 2";  
input double inp_loss_level_2 = 200.0;  // DD kích hoạt mức 2
input double inp_lot_level_2  = 0.02;   // Lot áp dụng mức 2
input double inp_dist_level_2 = 80.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 2
input group "Mức 3";  
input double inp_loss_level_3 = 300.0;  // DD kích hoạt mức 3
input double inp_lot_level_3  = 0.03;   // Lot áp dụng mức 3
input double inp_dist_level_3 = 70.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 3
input group "Mức 4";  
input double inp_loss_level_4 = 400.0;  // DD kích hoạt mức 4
input double inp_lot_level_4  = 0.04;   // Lot áp dụng mức 4
input double inp_dist_level_4 = 70.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 4
input group "Mức 5";  
input double inp_loss_level_5 = 500.0;  // DD kích hoạt mức 5
input double inp_lot_level_5  = 0.04;   // Lot áp dụng mức 5
input double inp_dist_level_5 = 60.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 5
input group "Mức 6";  
input double inp_loss_level_6 = 600.0;  // DD kích hoạt mức 6
input double inp_lot_level_6  = 0.05;   // Lot áp dụng mức 6
input double inp_dist_level_6 = 60.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 6
input group "Mức 7";  
input double inp_loss_level_7 = 700.0;  // DD kích hoạt mức 7
input double inp_lot_level_7  = 0.06;   // Lot áp dụng mức 7
input double inp_dist_level_7 = 50.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 7
input group "Mức 8";  
input double inp_loss_level_8 = 800.0;  // DD kích hoạt mức 8
input double inp_lot_level_8  = 0.07;   // Lot áp dụng mức 8
input double inp_dist_level_8 = 50.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 8
input group "Mức 9";  
input double inp_loss_level_9 = 900.0;  // DD kích hoạt mức 9
input double inp_lot_level_9  = 0.08;   // Lot áp dụng mức 9
input double inp_dist_level_9 = 40.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 9
input group "Mức 10"; 
input double inp_loss_level_10= 1000.0; // DD kích hoạt mức 10 ($)
input double inp_lot_level_10 = 0.10;  // Lot áp dụng mức 10
input double inp_dist_level_10= 40.0;   // Khoảng cách DCA DƯƠNG áp dụng mức 10

//--- Cài đặt DCA ÂM (Nghịch xu hướng)
input group "---  DCA Âm  ---"
input group "Nhóm 1"; 
input int    inp_level_nhom_1 = 1;      // Level bắt đầu nhóm 1
input double inp_multi_nhom_1 = 1.2;    // Hệ số xlot nhóm 1
input double inp_dist_nhom_1  = 100.0;   // Khoảng cách mở lệnh nhóm 1
input group "Nhóm 2"; 
input int    inp_level_nhom_2 = 5;      // Level bắt đầu nhóm 2
input double inp_multi_nhom_2 = 1.3;    // Hệ số xlot nhóm 2
input double inp_dist_nhom_2  = 100.0;   // Khoảng cách mở lệnh nhóm 2
input group "Nhóm 3"; 
input int    inp_level_nhom_3 = 10;     // Level bắt đầu nhóm 3
input double inp_multi_nhom_3 = 1.5;    // Hệ số xlot nhóm 3
input double inp_dist_nhom_3  = 150.0;   // Khoảng cách mở lệnh nhóm 3
input group "Nhóm 4"; 
input int    inp_level_nhom_4 = 15;     // Level bắt đầu nhóm 4
input double inp_multi_nhom_4 = 1.05;   // Hệ số xlot nhóm 4
input double inp_dist_nhom_4  = 200.0;   // Khoảng cách mở lệnh nhóm 4
input group "Nhóm 5"; 
input int    inp_level_nhom_5 = 20;     // Level bắt đầu nhóm 5
input double inp_multi_nhom_5 = 1.05;   // Hệ số xlot nhóm 5
input double inp_dist_nhom_5  = 200.0;   // Khoảng cách mở lệnh nhóm 5
input group "Nhóm 6"; 
input int    inp_level_nhom_6 = 25;     // Level bắt đầu nhóm 6
input double inp_multi_nhom_6 = 1.02;   // Hệ số xlot nhóm 6
input double inp_dist_nhom_6  = 300.0;   // Khoảng cách mở lệnh nhóm 6
input group "Nhóm 7"; 
input int    inp_level_nhom_7 = 30;     // Level bắt đầu nhóm 7
input double inp_multi_nhom_7 = 1.02;   // Hệ số xlot nhóm 7
input double inp_dist_nhom_7  = 300.0;   // Khoảng cách mở lệnh nhóm 7
input group "Nhóm 8"; 
input int    inp_level_nhom_8 = 35;     // Level bắt đầu nhóm 8
input double inp_multi_nhom_8 = 1.02;   // Hệ số xlot nhóm 8
input double inp_dist_nhom_8  = 300.0;   // Khoảng cách mở lệnh nhóm 8
input group "Nhóm 9"; 
input int    inp_level_nhom_9 = 40;     // Level bắt đầu nhóm 9
input double inp_multi_nhom_9 = 1.02;   // Hệ số xlot nhóm 9
input double inp_dist_nhom_9  = 300.0;   // Khoảng cách mở lệnh nhóm 9
input group "Nhóm 10"; 
input int    inp_level_nhom_10= 45;     // Level bắt đầu nhóm 10
input double inp_multi_nhom_10= 1.02;   // Hệ số xlot nhóm 10
input double inp_dist_nhom_10 = 300.0;   // Khoảng cách mở lệnh nhóm 10
input group "Nhóm 11"; 
input int    inp_level_nhom_11= 50;     // Level bắt đầu nhóm 11
input double inp_multi_nhom_11= 1.01;   // Hệ số xlot nhóm 11
input double inp_dist_nhom_11 = 400.0;   // Khoảng cách mở lệnh nhóm 11
input group "Nhóm 12"; 
input int    inp_level_nhom_12= 55;     // Level bắt đầu nhóm 12
input double inp_multi_nhom_12= 1.01;   // Hệ số xlot nhóm 12
input double inp_dist_nhom_12 = 400.0;   // Khoảng cách mở lệnh nhóm 12
input group "Nhóm 13"; 
input int    inp_level_nhom_13= 60;     // Level bắt đầu nhóm 13
input double inp_multi_nhom_13= 1.01;   // Hệ số xlot nhóm 13
input double inp_dist_nhom_13 = 400.0;   // Khoảng cách mở lệnh nhóm 13
input group "Nhóm 14"; 
input int    inp_level_nhom_14= 65;     // Level bắt đầu nhóm 14
input double inp_multi_nhom_14= 1.01;   // Hệ số xlot nhóm 14
input double inp_dist_nhom_14 = 400.0;   // Khoảng cách mở lệnh nhóm 14
input group "Nhóm 15"; 
input int    inp_level_nhom_15= 70;     // Level bắt đầu nhóm 15
input double inp_multi_nhom_15= 1.01;   // Hệ số xlot nhóm 15
input double inp_dist_nhom_15 = 400.0;   // Khoảng cách mở lệnh nhóm 15
input group "Nhóm 16"; 
input int    inp_level_nhom_16= 75;     // Level bắt đầu nhóm 16
input double inp_multi_nhom_16= 1.01;   // Hệ số xlot nhóm 16
input double inp_dist_nhom_16 = 500.0;   // Khoảng cách mở lệnh nhóm 16
input group "Nhóm 17"; 
input int    inp_level_nhom_17= 80;     // Level bắt đầu nhóm 17
input double inp_multi_nhom_17= 1.01;   // Hệ số xlot nhóm 17
input double inp_dist_nhom_17 = 500.0;   // Khoảng cách mở lệnh nhóm 17
input group "Nhóm 18"; 
input int    inp_level_nhom_18= 85;     // Level bắt đầu nhóm 18
input double inp_multi_nhom_18= 1.01;   // Hệ số xlot nhóm 18
input double inp_dist_nhom_18 = 500.0;   // Khoảng cách mở lệnh nhóm 18
input group "Nhóm 19"; 
input int    inp_level_nhom_19= 90;     // Level bắt đầu nhóm 19
input double inp_multi_nhom_19= 1.01;   // Hệ số xlot nhóm 19
input double inp_dist_nhom_19 = 500.0;   // Khoảng cách mở lệnh nhóm 19
input group "Nhóm 20"; 
input int    inp_level_nhom_20= 95;     // Level bắt đầu nhóm 20
input double inp_multi_nhom_20= 1.01;   // Hệ số xlot nhóm 20
input double inp_dist_nhom_20 = 500.0;   // Khoảng cách mở lệnh nhóm 20

// --- Chế độ tỉa lệnh ---
enum ENUM_TRIM_MODE
{
   TRIM_MODE_SAME_SIDE  = 0,   // Tỉa cùng chiều (Quỹ BUY tỉa lỗ BUY)
   TRIM_MODE_CROSS_SIDE = 1    // Tỉa chéo (Quỹ BUY tỉa lỗ SELL)
};

// --- Điều kiện kích hoạt tỉa lệnh ---
enum ENUM_TRIM_TRIGGER
{
   TRIM_BY_COUNT    = 0,   // Theo số lệnh
   TRIM_BY_DISTANCE = 1    // Theo khoảng cách pip
};

// --- Kiểu cơ chế tỉa lệnh ---
enum ENUM_TRIM_STYLE
{
   TRIM_STYLE_FUND    = 0,   // Quỹ tích lũy (Gián tiếp)
   TRIM_STYLE_RESCUE  = 1    // Rescue Fund (Trực tiếp - đóng lệnh lãi)
};

//--- Cài đặt Tỉa Lệnh (Thông thường) ---
input group "---  Tỉa Lệnh Mặc Định  ---"
input bool   inp_use_trimming          = true;      // Bật/Tắt tỉa lệnh
input ENUM_TRIM_STYLE inp_trim_style   = TRIM_STYLE_FUND; // Kiểu cơ chế tỉa lệnh
input ENUM_TRIM_MODE inp_trim_mode     = TRIM_MODE_SAME_SIDE; // Chế độ tỉa lệnh (quỹ)
input ENUM_TRIM_TRIGGER inp_trim_trigger_mode = TRIM_BY_COUNT; // Điều kiện kích hoạt tỉa
input int    inp_trim_trigger_level    = 10;        // Số lệnh để kích hoạt tỉa (BY_COUNT)
input double inp_trim_pip_distance     = 50.0;      // Khoảng cách pip kích hoạt tỉa (BY_DISTANCE)
input double inp_trim_close_percentage = 30.0;      // % khối lượng muốn tỉa
input double inp_trim_target_profit    = 5.0;       // Lợi nhuận mục tiêu sau khi tỉa

// --- Kiểu tỉa khẩn cấp theo pip ---
enum ENUM_PIP_TRIM_STYLE
{
   PIP_TRIM_SOFT = 0,   // Tỉa mềm (cần budget D/W)
   PIP_TRIM_HARD = 1    // Tỉa cứng (đóng ngay không cần budget)
};

//--- Cài đặt Tỉa Lệnh Khẩn Cấp ---
input group "--- Tỉa Lệnh Khẩn Cấp ---"
input ENUM_EMERGENCY_TRIM_MODE inp_emergency_trim_mode = ETM_DRAWDOWN; // Chế độ tỉa khẩn cấp
input double inp_pip_emergency_threshold      = 100.0;    // Ngưỡng Pip kích hoạt (cho ETM_PIP)
input ENUM_PIP_TRIM_STYLE inp_pip_trim_style  = PIP_TRIM_SOFT; // Kiểu tỉa theo pip
input double inp_emergency_dd1_amount         = 2000.0;   // DD kích hoạt tỉa theo LÃI NGÀY
input double inp_emergency_profit_retention_day = 50.0;   // % Lợi nhuận muốn giữ lại
input double inp_emergency_dd2_amount         = 3000.0;   // DD kích hoạt tỉa theo LÃI TUẦN
input double inp_emergency_profit_retention_week= 70.0;   // % Lợi nhuận muốn giữ lại

//--- Tester Withdrawal Settings ---
input group "--- Tester Withdrawal Settings ---"
input bool   inp_tester_withdrawal_enabled   = false;  // Bật chế độ rút tiền ảo trong Tester
input double inp_tester_base_balance         = 8000.0; // Số dư gốc mong muốn duy trì
input double inp_tester_withdraw_threshold   = 1000.0; // Lợi nhuận đạt được để kích hoạt rút
input double inp_tester_withdraw_amount      = 1000.0; // Số tiền rút mỗi lần





