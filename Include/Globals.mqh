//+------------------------------------------------------------------+
//|                                                      Globals.mqh |
//|                        YOOGI INDUSTRIAL YANG                      |
//|              --- TỆP CHỨA BIẾN TOÀN CỤC & HÀM TIỆN ÍCH ---      |
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

//--- BIẾN TOÀN CỤC (Trạng thái hoạt động) ---
#define SIDEWAY_RATIO_THRESHOLD 0.70
bool     g_sideway_lock = false;

bool     g_trading_stopped_by_dd = false;
double   g_current_base_lot_buy;
double   g_current_base_lot_sell;
double   g_current_dca_duong_distance;

ulong    g_last_ui_update_time = 0;
datetime g_last_bar_time = 0;
enum E_CLOSE_REASON
{
   CR_UNKNOWN,   // Giao dich dong thu cong, do SL/TP, hoac khong xac dinh
   CR_TACTICAL   // Giao dich dong do Tia lenh Thuong hoac Tia Cheo
};
E_CLOSE_REASON g_last_close_reason;

//--- HE THONG TRACKING LY DO DONG LENH PER-TICKET ---
ulong    g_pending_tactical_ids[];   // Position IDs dong do tia chien thuat

void AddTacticalClose(ulong position_id)
{
   int size = ArraySize(g_pending_tactical_ids);
   ArrayResize(g_pending_tactical_ids, size + 1);
   g_pending_tactical_ids[size] = position_id;
}

E_CLOSE_REASON LookupCloseReason(ulong position_id)
{
   // Kiem tra tactical
   for(int i = 0; i < ArraySize(g_pending_tactical_ids); i++)
   {
      if(g_pending_tactical_ids[i] == position_id)
      {
         for(int j = i; j < ArraySize(g_pending_tactical_ids) - 1; j++)
            g_pending_tactical_ids[j] = g_pending_tactical_ids[j+1];
         ArrayResize(g_pending_tactical_ids, ArraySize(g_pending_tactical_ids) - 1);
         return CR_TACTICAL;
      }
   }
   return CR_UNKNOWN;
}

// Logic Hybrid Tracking
ulong    g_last_processed_deal_count = 0;
ulong    g_open_position_tickets[];

//--- BIẾN TOÀN CỤC (Cache Pending Orders & Grid Healing) ---
PendingInfo g_pending_orders[];
int      g_total_buy_pending = 0;
int      g_total_sell_pending = 0;
double   g_furthest_buy_pending_price = 0;
double   g_furthest_sell_pending_price = 0;
ulong    g_last_heal_check_time = 0;
ulong    g_last_sync_vol_time = 0;

//--- BIEN TOAN CUC (Quy TP USD) ---
double   g_fund_all = 0.0;        // Quy All (tong hop khi TP USD > 0)

bool     g_is_closing_tp_usd = false;



//--- KHAI BÁO TRƯỚC CÁC HÀM TIỆN ÍCH ---
datetime GetFinancialWeekStart();
double   GetRealizedProfitForPeriod(datetime start_time);
datetime GetStartOfDay();
#include "Input.mqh"


//+------------------------------------------------------------------+
//| KHỞI TẠO CÁC BIẾN TOÀN CỤC                                       |
//+------------------------------------------------------------------+
void InitializeGlobalVariables()
{
   g_sideway_lock = false;
   g_trading_stopped_by_dd = false;
   g_current_base_lot_buy = inp_lot_dca_duong;
   g_current_base_lot_sell = inp_lot_dca_duong;
   g_current_dca_duong_distance = inp_dca_duong_distance_pips;
   
   g_last_ui_update_time = 0;
   g_last_bar_time = 0;
   
   g_last_close_reason = CR_UNKNOWN;
   ArrayResize(g_pending_tactical_ids, 0);

   g_last_processed_deal_count = 0;
   ArrayResize(g_open_position_tickets, 0);
   ArrayResize(g_pending_orders, 0);
   g_total_buy_pending = 0;
   g_total_sell_pending = 0;
   g_furthest_buy_pending_price = 0;
   g_furthest_sell_pending_price = 0;
   g_last_heal_check_time = 0;
   g_last_sync_vol_time = 0;
   
   g_is_closing_tp_usd = false;
}


//+------------------------------------------------------------------+
//| CÁC HÀM TIỆN ÍCH                                                 |
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
           session_count++;
        else
           break; 
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
   if(!HistorySelect(start_time, TimeCurrent())) return 0; 
   
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
      return int(pips * MathPow(10, _Digits));
   if(_Digits == 3 || _Digits == 5)
      return int(pips * 10);
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
           count++;
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
    if(p_type == POSITION_TYPE_BUY) return "Buy";
    if(p_type == POSITION_TYPE_SELL) return "Sell";
    return "Unknown";
}

#endif
