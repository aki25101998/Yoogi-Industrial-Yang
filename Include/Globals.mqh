//+------------------------------------------------------------------+
//| Globals.mqh |
//+------------------------------------------------------------------+
#ifndef GLOBALS_MQH
#define GLOBALS_MQH

#define PREFIX_BUDGET "Yoogi_Budget_"
struct PositionInfo
{
    ulong ticket;
    double volume;
    double open_price;
    double profit_swap;
    ENUM_POSITION_TYPE type;
    string comment;
    datetime open_time;
};

struct PendingInfo
{
    ulong ticket;
    double volume;
    double open_price;
    ENUM_ORDER_TYPE type;
    ENUM_POSITION_TYPE position_type;
    string comment;
    datetime open_time;
};

int handle_adx = INVALID_HANDLE; // Handle cho chi bao ADX
//+------------------------------------------------------------------+
//|                                                      Globals.mqh |
//|                                                 Yoogi Yin Yang   |
//|                 --- T?P CH?A BI?N TOAN C?C & HAM TI?N ICH ---    |
//|                 (Phin b?n 4.3 - Hardcode EMA Params)             |
//+------------------------------------------------------------------+



// ... Rest of content would go here but for brevity and safety I will append the rest from existing file if I can read it ... 

//+------------------------------------------------------------------+
//|                                                      Globals.mqh |
//|                                                 Yoogi Yin Yang   |
//|                 --- T?P CH?A BI?N TOÀN C?C & HÀM TI?N ÍCH ---      |
//|                 (Phiên b?n 4.3 - Hardcode EMA Params)            |
//+------------------------------------------------------------------+

// <<< ÐÃ XÓA: enum ENUM_EMA_TIMEFRAME không còn c?n thi?t >>>

//--- BI?N TOÀN C?C (C?u hình chi?n lu?c) ---
int      levels_dca_am[20];
double   multipliers_dca_am[20];
double   distances_dca_am[20];

double   loss_levels[10];
double   lot_levels[10];
double   distance_levels[10]; 

//--- BI?N TOÀN C?C (Tr?ng thái ho?t d?ng) ---
double   g_current_base_lot_buy;
double   g_current_base_lot_sell;
double   g_current_dca_duong_distance;

int      g_last_buy_dca_am_group_index;
int      g_last_sell_dca_am_group_index;

bool     g_is_buy_locked;
bool     g_is_sell_locked;

// Các bi?n tr?ng thái cho b? l?c EMA (v?n c?n thi?t)
bool     g_is_buy_locked_by_ema;   // Tr?ng thái khóa BUY do EMA
bool     g_is_sell_locked_by_ema;  // Tr?ng thái khóa SELL do EMA
// <<< ÐÃ XÓA: Bi?n g_ema_timeframe không còn c?n thi?t >>>

ulong    g_last_ui_update_time = 0;
ulong    g_last_emergency_check_time = 0;
datetime g_last_bar_time = 0;

enum E_EMERGENCY_MODE
{
   EM_NONE,    // Không ? ch? d? kh?n c?p
   EM_DAY,     // Ch? d? kh?n c?p NGÀY dang kích ho?t
   EM_WEEK     // Ch? d? kh?n c?p TU?N dang kích ho?t
};
E_EMERGENCY_MODE g_current_emergency_mode;
E_EMERGENCY_MODE g_previous_emergency_mode;

// --- LOGIC XAC DINH XU HUONG (STATE MACHINE) ---
enum ENUM_CONFIRMED_TREND
{
   TREND_NONE = 0,      // Chua xac dinh (lan dau khoi dong)
   TREND_UPTREND = 1,   // Xu huong TANG (Khoa SELL)
   TREND_DOWNTREND = 2  // Xu huong GIAM (Khoa BUY)
};

ENUM_CONFIRMED_TREND g_confirmed_trend = TREND_NONE;  // Xu huong da xac nhan
datetime g_last_trend_check_time = 0;

// --- LOGIC UU TIEN TIA LENH TRUOC TRAILING ---
bool g_has_position_to_trim = false;  // Co lenh loi can tia hay khong                  // Thoi diem check xu huong cuoi (M15) 

//--- ENUM cho dropdown ch? d? t?a kh?n c?p ---
enum ENUM_EMERGENCY_TRIM_MODE
{
   ETM_DISABLED,    // Tắt tỉa khẩn cấp
   ETM_DRAWDOWN,    // Tỉa theo Drawdown (USD)
   ETM_PIP          // Tỉa theo Pip
};

enum E_CLOSE_REASON
{
   CR_UNKNOWN,   // Giao d?ch dóng th? công, do SL/TP, ho?c không xác d?nh
   CR_TACTICAL,  // Giao d?ch dóng do T?a l?nh Thu?ng ho?c T?a Chéo
   CR_EMERGENCY  // Giao d?ch dóng do T?a l?nh Kh?n c?p
};
E_CLOSE_REASON g_last_close_reason;

//--- HỆ THỐNG TRACKING LÝ DO ĐÓNG LỆNH PER-TICKET (FIX BUG LIVE) ---
ulong    g_pending_tactical_ids[];   // Position IDs đóng do tỉa chiến thuật
ulong    g_pending_emergency_ids[];  // Position IDs đóng do tỉa khẩn cấp

void AddTacticalClose(ulong position_id)
{
   int size = ArraySize(g_pending_tactical_ids);
   ArrayResize(g_pending_tactical_ids, size + 1);
   g_pending_tactical_ids[size] = position_id;
}

void AddEmergencyClose(ulong position_id)
{
   int size = ArraySize(g_pending_emergency_ids);
   ArrayResize(g_pending_emergency_ids, size + 1);
   g_pending_emergency_ids[size] = position_id;
}

E_CLOSE_REASON LookupCloseReason(ulong position_id)
{
   // Kiểm tra tactical
   for(int i = 0; i < ArraySize(g_pending_tactical_ids); i++)
   {
      if(g_pending_tactical_ids[i] == position_id)
      {
         // Xóa khỏi danh sách sau khi tìm thấy
         for(int j = i; j < ArraySize(g_pending_tactical_ids) - 1; j++)
            g_pending_tactical_ids[j] = g_pending_tactical_ids[j+1];
         ArrayResize(g_pending_tactical_ids, ArraySize(g_pending_tactical_ids) - 1);
         return CR_TACTICAL;
      }
   }
   // Kiểm tra emergency
   for(int i = 0; i < ArraySize(g_pending_emergency_ids); i++)
   {
      if(g_pending_emergency_ids[i] == position_id)
      {
         // Xóa khỏi danh sách sau khi tìm thấy
         for(int j = i; j < ArraySize(g_pending_emergency_ids) - 1; j++)
            g_pending_emergency_ids[j] = g_pending_emergency_ids[j+1];
         ArrayResize(g_pending_emergency_ids, ArraySize(g_pending_emergency_ids) - 1);
         return CR_EMERGENCY;
      }
   }
   return CR_UNKNOWN;
}


// Logic Hybrid Tracking
ulong    g_last_processed_deal_count = 0;
ulong    g_open_position_tickets[];

//--- BIEN TOAN CUC (Cache Pending Orders & Grid Healing) ---
PendingInfo g_pending_orders[];
int      g_total_buy_pending = 0;
int      g_total_sell_pending = 0;
double   g_furthest_buy_pending_price = 0;
double   g_furthest_sell_pending_price = 0;
ulong    g_last_heal_check_time = 0;
ulong    g_last_sync_vol_time = 0;

//--- BI?N TOÀN C?C (H? th?ng S? Sách K? Toán) ---
double   g_safe_day = 0.0;
double   g_budget_day = 0.0;
double   g_safe_week = 0.0;
double   g_budget_week = 0.0;
double   g_trimmed_day = 0.0;
double   g_trimmed_week = 0.0;

//--- BIẾN TOÀN CỤC (Quỹ Tỉa Lệnh) ---
double   g_fund_trim_buy = 0.0;   // Quỹ tỉa lệnh cho phe Buy
double   g_fund_trim_sell = 0.0;  // Quỹ tỉa lệnh cho phe Sell
double   g_fund_all = 0.0;        // Quỹ All (tổng hợp khi TP USD > 0)

//--- BIẾN THEO DÕI SỐ LỆNH (Để detect khi vào chế độ trimming) ---
int      g_prev_buy_count = 0;    // Số lệnh BUY lần tick trước
int      g_prev_sell_count = 0;   // Số lệnh SELL lần tick trước
bool     g_buy_distance_triggered = false;   // BUY đã có lệnh đạt pip distance
bool     g_sell_distance_triggered = false;  // SELL đã có lệnh đạt pip distance

bool     g_is_closing_tp_usd = false;        // Trang thai dang clear lenh do dat TP USD

// Bi?n theo dõi chu k? d? reset
datetime g_last_known_day = 0;
datetime g_last_known_week_start = 0;


//--- CÁC C?U TRÚC D? LI?U ---
struct TradeOrder { ulong ticket; double profit; datetime open_time; };


//--- KHAI BÁO TRU?C CÁC HÀM TI?N ÍCH ---
datetime GetFinancialWeekStart();
double   GetRealizedProfitForPeriod(datetime start_time);
datetime GetStartOfDay();
// C?n khai báo tru?c vì Input.mqh c?n nó d? ho?t d?ng dúng
#include "Input.mqh"


//+------------------------------------------------------------------+
//| KH?I T?O CÁC BI?N TOÀN C?C                                       |
//+------------------------------------------------------------------+
void InitializeGlobalVariables()
{
   g_current_base_lot_buy = inp_lot_dca_duong;
   g_current_base_lot_sell = inp_lot_dca_duong;
   g_current_dca_duong_distance = inp_dca_duong_distance_pips;
   
   g_last_buy_dca_am_group_index = -1;
   g_last_sell_dca_am_group_index = -1;
   
   g_is_buy_locked = false;
   g_is_sell_locked = false;
   
   // Kh?i t?o các bi?n tr?ng thái EMA
   g_is_buy_locked_by_ema = false;
   g_is_sell_locked_by_ema = false;
   g_confirmed_trend = TREND_NONE;
   g_last_trend_check_time = 0;
   
   g_last_ui_update_time = 0;
   g_last_emergency_check_time = 0;
   g_last_bar_time = 0;
   
   g_current_emergency_mode = EM_NONE;
   g_previous_emergency_mode = EM_NONE;
   
   g_last_close_reason = CR_UNKNOWN;
   ArrayResize(g_pending_tactical_ids, 0);
   ArrayResize(g_pending_emergency_ids, 0);

   g_last_processed_deal_count = 0;
   ArrayResize(g_open_position_tickets, 0);
   ArrayResize(g_pending_orders, 0);
   g_total_buy_pending = 0;
   g_total_sell_pending = 0;
   g_furthest_buy_pending_price = 0;
   g_furthest_sell_pending_price = 0;
   g_last_heal_check_time = 0;
   g_last_sync_vol_time = 0;

   // Kh?i t?o các bi?n s? sách
   g_safe_day = 0.0;
   g_budget_day = 0.0;
   g_safe_week = 0.0;
   g_budget_week = 0.0;
   g_trimmed_day = 0.0;
   g_trimmed_week = 0.0;
   g_last_known_day = 0;
   g_last_known_week_start = 0;
   
   // Giu nguyen quy tia lenh (khong reset khi khoi dong)
   g_buy_distance_triggered = false;
   g_sell_distance_triggered = false;
   g_is_closing_tp_usd = false;
}


//+------------------------------------------------------------------+
//| N?P C?U HÌNH VÀO CÁC M?NG                                        |
//+------------------------------------------------------------------+
void FillDcaLevels()
{
   #define FILL_DCA_LEVEL(i) do { levels_dca_am[i-1]=inp_level_nhom_##i; multipliers_dca_am[i-1]=inp_multi_nhom_##i; distances_dca_am[i-1]=inp_dist_nhom_##i; } while(0)
   for(int i=1; i<=20; i++){ switch(i){ case 1:FILL_DCA_LEVEL(1);break; case 2:FILL_DCA_LEVEL(2);break; case 3:FILL_DCA_LEVEL(3);break; case 4:FILL_DCA_LEVEL(4);break; case 5:FILL_DCA_LEVEL(5);break; case 6:FILL_DCA_LEVEL(6);break; case 7:FILL_DCA_LEVEL(7);break; case 8:FILL_DCA_LEVEL(8);break; case 9:FILL_DCA_LEVEL(9);break; case 10:FILL_DCA_LEVEL(10);break; case 11:FILL_DCA_LEVEL(11);break; case 12:FILL_DCA_LEVEL(12);break; case 13:FILL_DCA_LEVEL(13);break; case 14:FILL_DCA_LEVEL(14);break; case 15:FILL_DCA_LEVEL(15);break; case 16:FILL_DCA_LEVEL(16);break; case 17:FILL_DCA_LEVEL(17);break; case 18:FILL_DCA_LEVEL(18);break; case 19:FILL_DCA_LEVEL(19);break; case 20:FILL_DCA_LEVEL(20);break;}}
   #undef FILL_DCA_LEVEL
}

void FillDrawdownLevels()
{
   #define FILL_DD_LEVEL(i) do { loss_levels[i-1]=inp_loss_level_##i; lot_levels[i-1]=inp_lot_level_##i; distance_levels[i-1]=inp_dist_level_##i; } while(0)
   for(int i=1; i<=10; i++){ switch(i){ case 1:FILL_DD_LEVEL(1);break; case 2:FILL_DD_LEVEL(2);break; case 3:FILL_DD_LEVEL(3);break; case 4:FILL_DD_LEVEL(4);break; case 5:FILL_DD_LEVEL(5);break; case 6:FILL_DD_LEVEL(6);break; case 7:FILL_DD_LEVEL(7);break; case 8:FILL_DD_LEVEL(8);break; case 9:FILL_DD_LEVEL(9);break; case 10:FILL_DD_LEVEL(10);break;}}
   #undef FILL_DD_LEVEL
}

//+------------------------------------------------------------------+
//| KI?M TRA VÀ RESET S? SÁCH K? TOÁN KHI B?T Ð?U CHU K? M?I         |
//+------------------------------------------------------------------+
void CheckAndResetAccounting()
{
    datetime current_day_start = GetStartOfDay();
    if(g_last_known_day != current_day_start)
    {
       Log("INFO", "Phát hi?n ngày m?i. Reset Két S?t & Ngân Sách NGÀY.");
       g_safe_day = 0.0;
       g_budget_day = 0.0;
       g_trimmed_day = 0.0;
       g_last_known_day = current_day_start;
    }

    datetime current_week_start = GetFinancialWeekStart();
    if(g_last_known_week_start != current_week_start)
    {
       Log("INFO", "Phat hien tuan moi. Reset Ket Sat & Ngan Sach TUAN.");
       g_safe_week = 0.0;
       g_budget_week = 0.0;
       g_trimmed_week = 0.0;
       g_last_known_week_start = current_week_start;
    }
}


//+------------------------------------------------------------------+
//| CÁC HÀM TI?N ÍCH                                                 |
//+------------------------------------------------------------------+
void Log(string level, string message)
{
   PrintFormat("[%s] %s", level, message);
}

double FloorLot(double lot) 
{
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lot_step <= 0) return lot;
   double final_lot = floor(lot / lot_step) * lot_step;
   if(final_lot < min_volume) final_lot = min_volume;
   if(final_lot > max_volume) final_lot = max_volume;
   return final_lot;
}

double NormalizeLot(double lot) 
{
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot = MathRound(lot / lot_step) * lot_step;
   if(lot < min_volume) lot = min_volume;
   if(lot > max_volume) lot = max_volume;
   return lot;
}

datetime GetStartOfDay() 
{ 
   MqlDateTime s; 
   TimeCurrent(s); 
   s.hour = 0; 
   s.min = 0; 
   s.sec = 0; 
   return StructToTime(s); 
}

datetime GetFinancialWeekStart()
{
    datetime now_dt = TimeCurrent();
    MqlDateTime now_s;
    TimeToStruct(now_dt, now_s);

    int day_of_week = now_s.day_of_week;
   
    int days_to_subtract = (day_of_week == 0) ? 6 : (day_of_week - 1);

    datetime today_start = now_dt - (now_s.hour * 3600) - (now_s.min * 60) - now_s.sec;
   
    datetime monday_start_of_week = today_start - (days_to_subtract * 86400);
   
    return monday_start_of_week;
}

datetime GetFinancialWeekEnd()
{
    MqlDateTime now_s;
    TimeToStruct(TimeCurrent(), now_s);
    int days_to_add = (6 - now_s.day_of_week); 
    datetime saturday_of_this_week = TimeCurrent() + (days_to_add * 86400);
    TimeToStruct(saturday_of_this_week, now_s);
    now_s.hour = 23; now_s.min = 59; now_s.sec = 59;
    datetime end_of_saturday = StructToTime(now_s);

    for(int i = 0; i < 7; i++)
    {
       datetime day_to_check = end_of_saturday - (i * 86400);
       MqlDateTime check_s;
       TimeToStruct(day_to_check, check_s);
       
       int session_count = 0;
       datetime dummy_from, dummy_to;
       for(int j = 0; j < 100; j++) 
       {
        if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)check_s.day_of_week, j, dummy_from, dummy_to))
        {
           session_count++;
        }
        else
        {
           break; 
        }
       }
       
       if(session_count > 0)
       {
        datetime session_from, session_to;
        if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)check_s.day_of_week, session_count - 1, session_from, session_to))
        {
           MqlDateTime date_part, time_part;
           TimeToStruct(day_to_check, date_part);
           TimeToStruct(session_to, time_part);
           date_part.hour = time_part.hour;
           date_part.min = time_part.min;
           date_part.sec = time_part.sec;
           return StructToTime(date_part);
        }
       }
    }
   
    Log("WARNING", "Khong the xac dinh gio ket thuc tuan cho san pham " + _Symbol);
    return 0;
}

double GetRealizedProfitForPeriod(datetime start_time) 
{ 
   if(start_time == 0) return 0;
   
   if(!HistorySelect(start_time, TimeCurrent())) 
   { 
       return 0; 
   } 
   
   double net_profit = 0; 
   uint total_deals = HistoryDealsTotal(); 
   for(uint i=0; i<total_deals; i++) 
   { 
       ulong ticket = HistoryDealGetTicket(i); 
       if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == inp_magic_number) 
       { 
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) 
        { 
           net_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT); 
           net_profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION); 
           net_profit += HistoryDealGetDouble(ticket, DEAL_SWAP); 
        } 
       } 
   } 
   return net_profit; 
}

bool IsMetal()
{
   string base = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   return (base == "XAU" || base == "XAG" || base == "XPT" || base == "XPD");
}

int PipToPoints(double pips)
{
   if(IsMetal())
      return int(pips * MathPow(10, _Digits));   // Metals: 1 pip = $1.00 (VD: _Digits=3 -> x1000)
   if(_Digits == 3 || _Digits == 5)
      return int(pips * 10);                      // Forex: 1 pip = 10 points
   return int(pips);
}

double PointsToPips(double points)
{
   if(IsMetal())
      return points / MathPow(10, _Digits);
   if(_Digits == 3 || _Digits == 5)
      return points / 10.0;
   return points;
}

int CountPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      {
          ulong ticket = PositionGetTicket(i);
          if(PositionSelectByTicket(ticket))
             {
              if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == type)
                 {
                  count++;
                 }
             }
      }
   return count;
}

int CountDcaAmPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      {
          ulong ticket = PositionGetTicket(i);
          if(PositionSelectByTicket(ticket))
             {
              if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == type && PositionGetString(POSITION_COMMENT) == "DCA ÂM")
                 {
                  count++;
                 }
             }
      }
   return count;
}

ulong GetOldestPosition(ENUM_POSITION_TYPE p_type)
{
   ulong oldest_ticket = 0;
   datetime oldest_time = D'3000.01.01';
   for(int i=PositionsTotal()-1; i>=0; i--)
      {
          ulong ticket = PositionGetTicket(i);
          if(PositionSelectByTicket(ticket))
             {
              if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == p_type)
                 {
                  if((datetime)PositionGetInteger(POSITION_TIME) < oldest_time)
                     {
                      oldest_time = (datetime)PositionGetInteger(POSITION_TIME);
                      oldest_ticket = ticket;
                     }
                 }
             }
      }
   return oldest_ticket;
}

ulong GetMostLosingPosition(ENUM_POSITION_TYPE p_type)
{
    ulong most_losing_ticket = 0;
    double most_losing_profit = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
       ulong ticket = PositionGetTicket(i);
       if(PositionSelectByTicket(ticket))
       {
        if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number &&
           PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_TYPE) == p_type)
        {
           double current_profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
           if(current_profit < most_losing_profit)
           {
              most_losing_profit = current_profit;
              most_losing_ticket = ticket;
           }
        }
       }
    }
    return most_losing_ticket;
}

int GetGroupIndex(int order_sequence_number)
{
   for(int i=19; i>=0; i--)
      {
          if(order_sequence_number >= levels_dca_am[i] && levels_dca_am[i] > 0)
             {
              return i;
             }
      }
   return -1; 
}

double GetMultiplier_ForDCA_Am(int order_sequence_number)
{
   int group_index = GetGroupIndex(order_sequence_number);
   if(group_index != -1)
      {
          return multipliers_dca_am[group_index];
      }
   return 1.0;
}

double GetDistancePips_ForDCA_Am(int order_sequence_number)
{
   int group_index = GetGroupIndex(order_sequence_number);
   if(group_index != -1)
      {
          return distances_dca_am[group_index];
      }
   return 99999.0;
}

double CalculateLot_ForDCA_Am(int order_sequence_number)
{
   if(order_sequence_number <= 0) return NormalizeLot(inp_lot_dca_am);

   double base_lot_for_multiplication = inp_lot_dca_am; 
   
   double final_normalized_lot = NormalizeLot(inp_lot_dca_am);

   int last_group_index = -1;

   for(int i = 1; i <= order_sequence_number; i++)
   {
       int current_group_index = GetGroupIndex(i);

       if(current_group_index != -1 && current_group_index > last_group_index)
       {
        double multiplier = GetMultiplier_ForDCA_Am(i);
       
        double raw_multiplied_lot = base_lot_for_multiplication * multiplier;
       
        final_normalized_lot = NormalizeLot(raw_multiplied_lot);
       
        base_lot_for_multiplication = MathMax(raw_multiplied_lot, final_normalized_lot);
       
        last_group_index = current_group_index;
       }
   }
   
   return final_normalized_lot;
}

bool IsNewBar()
{
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);
   
   if(g_last_bar_time != current_bar_time)
   {
       g_last_bar_time = current_bar_time;
       return true;
   }
   
   return false;
}

string PositionTypeToString(ENUM_POSITION_TYPE p_type)
{
    if(p_type == POSITION_TYPE_BUY)
        return "Buy";
    if(p_type == POSITION_TYPE_SELL)
        return "Sell";
   
    return "Không xác d?nh";
}
//+------------------------------------------------------------------+






double GetLotSize_ForDCA_Am(int level, double base_lot) { if(!inp_enable_dca_am_xlot) return NormalizeLot(inp_lot_dca_am); return CalculateLot_ForDCA_Am(level); }

#endif






