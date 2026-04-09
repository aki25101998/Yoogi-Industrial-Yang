//+------------------------------------------------------------------+
//|                                                      Input.mqh   |
//|                             --- TỆP CHỨA TẤT CẢ CÁC INPUT ---      |
//|             (Phiên bản cập nhật - Sắp xếp logic & Thêm Stop/Limit)|
//+------------------------------------------------------------------+

#include "Globals.mqh"

//===================================================================
// = 1. CÀI ĐẶT CHUNG (GENERAL SETTINGS)                            =
//===================================================================
input group "--- 1. Cài đặt chung ---"
input ulong  inp_magic_number       = 12345;  // Magic Number
input double inp_initial_tp_pips    = 20.0;   // Take Profit cho lệnh đầu (0 = tắt)
input double inp_take_profit_usd    = 0.0;    // TP USD toàn bộ (0 = tắt)
input bool   inp_withdrawal_mode    = false;  // Chế độ Rút tiền thật

//===================================================================
// = 2. KHỐI LƯỢNG & KHOẢNG CÁCH BAN ĐẦU                            =
//===================================================================
input group "--- 2. Khối Lượng Ban Đầu ---"
input double inp_lot_dca_duong      = 0.01;   // Lot DCA Dương (Initial + DCA Dương)
input double inp_lot_dca_am         = 0.01;   // Lot DCA Âm
input double inp_dca_duong_distance_pips = 100.0; // Khoảng cách nhồi DCA Dương mặc định

//===================================================================
// = 3. CÔNG TẮC GIAO DỊCH (ENABLE / DISABLE)                       =
//===================================================================
input group "--- 3. Công Tắc Các Mũi Nhọn ---"
input bool   inp_enable_buy         = true;   // Cho phép EA mở lệnh BUY
input bool   inp_enable_sell        = true;   // Cho phép EA mở lệnh SELL
input bool   inp_enable_dca_duong   = true;   // Bật/Tắt DCA DƯƠNG (Thuận xu hướng)
input bool   inp_enable_dca_am      = true;   // Bật/Tắt DCA ÂM (Ngược xu hướng)
input bool   inp_enable_lot_balancing = true; // Bật/Tắt Cân Bằng Lot DCA Dương
input bool   inp_enable_dca_am_xlot = true;   // Bật/Tắt xLot DCA Âm (true=nhân lot, false=ban đầu)

//===================================================================
// = 4. CHẾ ĐỘ PENDING ORDERS (CHỐNG TRƯỢT GIÁ GAP LỆNH)            =
//===================================================================
input group "--- 4. Chế Độ Pending Orders ---"
input bool   inp_enable_pending_mode      = true;           // [ON/OFF] Bật Chế Độ Pending Orders (Chống Trượt MẠNH)
input int    inp_pending_order_count      = 50;             // Số lượng lệnh Stop/Limit đặt trước mỗi biên
input int    inp_pending_refill_threshold = 10;             // Số lệnh tối thiểu trước khi tự động nhồi thêm
input bool   inp_pending_auto_refill      = true;           // Tự động kích hoạt nhồi lệnh mồi khi lưới sắp hết

//===================================================================
// = 5. DCA DƯƠNG - CỤM SETUP NÂNG CAO                              =
//===================================================================
input group "--- 5. Setup Nâng Cao DCA Dương ---"
input double inp_balance_activation_dd     = 100.0; // DD kích hoạt Cân Bằng Lot (0 = luôn bật)
input double inp_lot_balance_threshold     = 0.5;   // Ngưỡng lệch Lot để kích hoạt (0 = tắt)
input bool   inp_balance_zone_enabled      = true;  // Bật/Tắt giới hạn DCA Dương theo vùng giá
input double inp_balance_zone_pips         = 10.0;  // Kích thước vùng giới hạn
input int    inp_balance_zone_max_orders   = 3;     // Số lệnh DCA Dương tối đa trong 1 vùng

//===================================================================
// = 6. DCA DƯƠNG - NÂNG/HẠ LOT THEO MỨC DRAWDOWN                   =
//===================================================================
input group "--- 6. Mức Drawdown -> Scale Lưới DCA Dương ---"
input group "Mức 1";  
input double inp_loss_level_1 = 100.0;  
input double inp_lot_level_1  = 0.02;   
input double inp_dist_level_1 = 80.0;   
input group "Mức 2";  
input double inp_loss_level_2 = 200.0;  
input double inp_lot_level_2  = 0.02;   
input double inp_dist_level_2 = 80.0;   
input group "Mức 3";  
input double inp_loss_level_3 = 300.0;  
input double inp_lot_level_3  = 0.03;   
input double inp_dist_level_3 = 70.0;   
input group "Mức 4";  
input double inp_loss_level_4 = 400.0;  
input double inp_lot_level_4  = 0.04;   
input double inp_dist_level_4 = 70.0;   
input group "Mức 5";  
input double inp_loss_level_5 = 500.0;  
input double inp_lot_level_5  = 0.04;   
input double inp_dist_level_5 = 60.0;   
input group "Mức 6";  
input double inp_loss_level_6 = 600.0;  
input double inp_lot_level_6  = 0.05;   
input double inp_dist_level_6 = 60.0;   
input group "Mức 7";  
input double inp_loss_level_7 = 700.0;  
input double inp_lot_level_7  = 0.06;   
input double inp_dist_level_7 = 50.0;   
input group "Mức 8";  
input double inp_loss_level_8 = 800.0;  
input double inp_lot_level_8  = 0.07;   
input double inp_dist_level_8 = 50.0;   
input group "Mức 9";  
input double inp_loss_level_9 = 900.0;  
input double inp_lot_level_9  = 0.08;   
input double inp_dist_level_9 = 40.0;   
input group "Mức 10"; 
input double inp_loss_level_10= 1000.0; 
input double inp_lot_level_10 = 0.10;  
input double inp_dist_level_10= 40.0;   

//===================================================================
// = 7. DCA ÂM - CỤM SETUP NÂNG CAO DÀN LƯỚI & NHÓM LỆNH            =
//===================================================================
input group "--- 7. Setup Nâng Cao DCA Âm ---"
input bool   inp_dca_am_less_drawdown_only = false; // DCA Âm cho phe lỗ ít hơn
input bool   inp_trailing_dca_am_as_dca_duong = false; // DCA Âm dùng thuộc tính DCA Dương
input group "Nhóm 1"; 
input int    inp_level_nhom_1 = 1;      input double inp_multi_nhom_1 = 1.2;    input double inp_dist_nhom_1  = 100.0;
input group "Nhóm 2"; 
input int    inp_level_nhom_2 = 5;      input double inp_multi_nhom_2 = 1.3;    input double inp_dist_nhom_2  = 100.0;
input group "Nhóm 3"; 
input int    inp_level_nhom_3 = 10;     input double inp_multi_nhom_3 = 1.5;    input double inp_dist_nhom_3  = 150.0;
input group "Nhóm 4"; 
input int    inp_level_nhom_4 = 15;     input double inp_multi_nhom_4 = 1.05;   input double inp_dist_nhom_4  = 200.0;
input group "Nhóm 5"; 
input int    inp_level_nhom_5 = 20;     input double inp_multi_nhom_5 = 1.05;   input double inp_dist_nhom_5  = 200.0;
input group "Nhóm 6"; 
input int    inp_level_nhom_6 = 25;     input double inp_multi_nhom_6 = 1.02;   input double inp_dist_nhom_6  = 300.0;
input group "Nhóm 7"; 
input int    inp_level_nhom_7 = 30;     input double inp_multi_nhom_7 = 1.02;   input double inp_dist_nhom_7  = 300.0;
input group "Nhóm 8"; 
input int    inp_level_nhom_8 = 35;     input double inp_multi_nhom_8 = 1.02;   input double inp_dist_nhom_8  = 300.0;
input group "Nhóm 9"; 
input int    inp_level_nhom_9 = 40;     input double inp_multi_nhom_9 = 1.02;   input double inp_dist_nhom_9  = 300.0;
input group "Nhóm 10"; 
input int    inp_level_nhom_10= 45;     input double inp_multi_nhom_10= 1.02;   input double inp_dist_nhom_10 = 300.0;
input group "Nhóm 11"; 
input int    inp_level_nhom_11= 50;     input double inp_multi_nhom_11= 1.01;   input double inp_dist_nhom_11 = 400.0;
input group "Nhóm 12"; 
input int    inp_level_nhom_12= 55;     input double inp_multi_nhom_12= 1.01;   input double inp_dist_nhom_12 = 400.0;
input group "Nhóm 13"; 
input int    inp_level_nhom_13= 60;     input double inp_multi_nhom_13= 1.01;   input double inp_dist_nhom_13 = 400.0;
input group "Nhóm 14"; 
input int    inp_level_nhom_14= 65;     input double inp_multi_nhom_14= 1.01;   input double inp_dist_nhom_14 = 400.0;
input group "Nhóm 15"; 
input int    inp_level_nhom_15= 70;     input double inp_multi_nhom_15= 1.01;   input double inp_dist_nhom_15 = 400.0;
input group "Nhóm 16"; 
input int    inp_level_nhom_16= 75;     input double inp_multi_nhom_16= 1.01;   input double inp_dist_nhom_16 = 500.0;
input group "Nhóm 17"; 
input int    inp_level_nhom_17= 80;     input double inp_multi_nhom_17= 1.01;   input double inp_dist_nhom_17 = 500.0;
input group "Nhóm 18"; 
input int    inp_level_nhom_18= 85;     input double inp_multi_nhom_18= 1.01;   input double inp_dist_nhom_18 = 500.0;
input group "Nhóm 19"; 
input int    inp_level_nhom_19= 90;     input double inp_multi_nhom_19= 1.01;   input double inp_dist_nhom_19 = 500.0;
input group "Nhóm 20"; 
input int    inp_level_nhom_20= 95;     input double inp_multi_nhom_20= 1.01;   input double inp_dist_nhom_20 = 500.0;

//===================================================================
// = 8. QUẢN LÝ KHÓA GIAO DỊCH (DD / EMA)                           =
//===================================================================
input group "--- 8. Hạn Chế / Khóa Phe (DD & EMA) ---"
input double inp_dd_lock_buy_amount  = 200.0; // Mức lỗ để KHÓA phe BUY (0 = tắt)
input double inp_dd_lock_sell_amount = 200.0; // Mức lỗ để KHÓA phe SELL (0 = tắt)
input bool   inp_ema_lock_buy_on_downtrend = true;   // Khóa BUY khi Giá < EMA (giảm)
input bool   inp_ema_lock_sell_on_uptrend  = true;   // Khóa SELL khi Giá > EMA (tăng)
ENUM_TIMEFRAMES inp_ema_timeframe = PERIOD_M15;
// ADX Inputs (Hidden)
bool   InpUseAdxFilter                    = true;
int    InpAdxPeriod                       = 14;
double InpAdxLevel                        = 25.0;

//===================================================================
// = 9. CÀI ĐẶT TRAILING STOP (GỒNG LỜI)                            =
//===================================================================
input group "--- 9. Trailing Stop Đơn Lẻ (Cho Initial & DCA Dương) ---"
input bool   inp_enable_individual_trailing     = true;      // Bật/Tắt Trailing Stop đơn lẻ
input double inp_individual_trailing_start_pips = 200.0;     // Số pip có lời để bắt đầu
input double inp_individual_trailing_dist_pips  = 50.0;      // Khoảng cách quét trailing

input group "--- 10. Trailing Stop Khối Nhóm (Cho DCA Âm) ---"
input bool   inp_enable_group_trailing          = true;      // Bật/Tắt Trailing Stop cấp độ Nhóm
input double inp_group_trailing_start_pips      = 20.0;      // Số pip lời tổng nhóm để bắt đầu
input double inp_group_trailing_dist_pips       = 15.0;      // Khoảng cách trailing

//===================================================================
// = 10. CHẾ ĐỘ QUẢN TRỊ RỦI RO: TỈA LỆNH (TRIMMING)                =
//===================================================================
enum ENUM_TRIM_MODE { TRIM_MODE_SAME_SIDE = 0, TRIM_MODE_CROSS_SIDE = 1 };
enum ENUM_TRIM_TRIGGER { TRIM_BY_COUNT = 0, TRIM_BY_DISTANCE = 1 };
enum ENUM_TRIM_STYLE { TRIM_STYLE_FUND = 0, TRIM_STYLE_RESCUE = 1 };

input group "--- 11. Tỉa Lệnh Tự Động (Trimming) ---"
input bool   inp_use_trimming          = true;                    // Kích hoạt Tỉa Lệnh (Bảo vệ Vốn)
input ENUM_TRIM_STYLE inp_trim_style   = TRIM_STYLE_FUND;         // Kiểu chốt (Quỹ Trực Tiếp / Gián Tiếp)
input ENUM_TRIM_MODE inp_trim_mode     = TRIM_MODE_SAME_SIDE;     // Phạm vi tỉa (Cùng chiều / Mọi hướng)
input ENUM_TRIM_TRIGGER inp_trim_trigger_mode = TRIM_BY_COUNT;    // Triger theo Số lệnh hay Khoảng độ
input int    inp_trim_trigger_level    = 10;                      // (By Count) Tổng Lệnh để kích hoạt
input bool   inp_trim_count_both_sides = false;                   // Kích hoạt dựa trên tổng cả 2 phe
input double inp_trim_pip_distance     = 50.0;                    // (By Distance) Khoảng màng Pip chạm
input double inp_trim_close_percentage = 30.0;                    // Ratio % cắt tỉa cho Volume
input double inp_trim_target_profit    = 5.0;                     // Điểm Target lời còn lại

//===================================================================
// = 11. CHẾ ĐỘ CỨU HỎA: TỈA EMERGENCY                              =
//===================================================================
enum ENUM_PIP_TRIM_STYLE { PIP_TRIM_SOFT = 0, PIP_TRIM_HARD = 1 };

input group "--- 12. Tỉa Khẩn Cấp Bắt Buộc (Emergency Trim) ---"
input ENUM_EMERGENCY_TRIM_MODE inp_emergency_trim_mode = ETM_DRAWDOWN; 
input double inp_pip_emergency_threshold      = 100.0;           
input ENUM_PIP_TRIM_STYLE inp_pip_trim_style  = PIP_TRIM_SOFT;   
input double inp_emergency_dd1_amount         = 2000.0;          // Drawdown chạm mốc lấy Quỹ Ngày
input double inp_emergency_profit_retention_day = 50.0;          // % Quỹ Ngày được xài để cứu
input double inp_emergency_dd2_amount         = 3000.0;          // Drawdown chạm mốc lấy Quỹ Tuần
input double inp_emergency_profit_retention_week= 70.0;          // % Quỹ Tuần được xài để cứu

//===================================================================
// = 12. KIỂM THỬ GIAO DỊCH (STRATEGY TESTER)                       =
//===================================================================
input group "--- 13. Cài Đặt Backtest (Tester Withdrawal) ---"
input bool   inp_tester_withdrawal_enabled   = false;  // Kéo quỹ ảo cho Tester Backtest
input double inp_tester_base_balance         = 8000.0; 
input double inp_tester_withdraw_threshold   = 1000.0; 
input double inp_tester_withdraw_amount      = 1000.0; 
