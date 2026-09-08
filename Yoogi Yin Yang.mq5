//+------------------------------------------------------------------+
//|                                         Yoogi Industrial Yang.mq5 |
//|                                          Yoogi Industrial Yang     |
//|                    --- PHIÊN BẢN CÔNG NGHIỆP (CÁ NHÂN) ---        |
//+------------------------------------------------------------------+
#property version   "1.0"
#property description "Yoogi Industrial Yang - Phiên bản tối ưu cho sử dụng cá nhân.\n\n"
"Tính năng: DCA Dương + TP USD + Tỉa lệnh (Fund/Rescue/Cross) + Emergency Trim\n\n";
#property link "Industrial Yang"

#include <Trade/Trade.mqh>

#include "Include/Input.mqh"
#include "Include/Globals.mqh"
#include "Include/CoreLogic.mqh"
#include "Include/SidewayProtection.mqh"

#include "Include/Panel.mqh"
#include "Include/InfoDisplay.mqh"
#include "Include/ProfitDisplay.mqh"

CTrade trade;

#include "Include/PendingOrders.mqh"

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
void ProcessNewDeals();
void SyncOpenPositionsMemory();

//+------------------------------------------------------------------+
//| KHỞI TẠO                                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Initializing EA... Waiting for server time synchronization.");
   while(TimeTradeServer() == 0 || TimeCurrent() - TimeTradeServer() > 10)
   {
      if(IsStopped()) return(INIT_FAILED);
      Sleep(200); 
   }
   Print("Server time synchronized. Continuing initialization.");

   trade.SetExpertMagicNumber(inp_magic_number);
   trade.SetMarginMode();
   
   InitializeGlobalVariables();
   LoadBudget();

   UpdateProfitDisplay();
   
   HistorySelect(0, TimeCurrent());
   g_last_processed_deal_count = HistoryDealsTotal();
   Log("INFO", "Khoi tao thanh cong. Da ghi nhan " + (string)g_last_processed_deal_count + " deal trong lich su.");
   
   SyncOpenPositionsMemory();

   CreatePanel();
   CreateDisplay();
   CreateProfitDisplay();

   Log("INFO", "Yoogi Industrial Yang started!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DỌN DẸP                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Log("INFO", "EA stopped. Reason: " + IntegerToString(reason));
   DeletePanel();
   DeleteDisplay();
   DeleteProfitDisplay();
}

//+------------------------------------------------------------------+
//| HÀM SỰ KIỆN CHÍNH (OnTick)                                       |
//+------------------------------------------------------------------+
void OnTick()
{
    if(g_trading_stopped_by_dd) return;

    ProcessNewDeals();
    g_last_close_reason = CR_UNKNOWN; 


    // --- KIỂM TRA CHÁY TÀI KHOẢN ---
    if(AccountInfoDouble(ACCOUNT_BALANCE) <= 0.0)
    {
        bool has_ea_pending = false;
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                has_ea_pending = true;
                break;
            }
        }
        
        if(has_ea_pending)
        {
            Log("WARNING", StringFormat("Phat hien TAI KHOAN CHAY (Balance: %.2f <= 0). Tien hanh xoa toan bo Pending Orders cua EA!", AccountInfoDouble(ACCOUNT_BALANCE)));
            DeleteAllPendingOrders();
        }
        return; // Dừng OnTick ở đây để không mở lệnh mới hoặc xử lý thêm
    }

    // --- Khai báo biến cục bộ ---
    PositionInfo positions[];
    int total_buy_pos = 0, total_sell_pos = 0;
    double total_buy_profit = 0, total_sell_profit = 0;
    double total_buy_lots = 0, total_sell_lots = 0; 

    int total_positions_on_chart = PositionsTotal();
    ArrayResize(positions, total_positions_on_chart);
    int current_ea_pos_count = 0;

    double highest_buy_price = 0, lowest_buy_price = DBL_MAX;
    double highest_sell_price = 0, lowest_sell_price = DBL_MAX;

    // --- PHA 1: THU THẬP DỮ LIỆU ---
    for(int i = total_positions_on_chart - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                positions[current_ea_pos_count].ticket = ticket;
                positions[current_ea_pos_count].volume = PositionGetDouble(POSITION_VOLUME);
                positions[current_ea_pos_count].open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                positions[current_ea_pos_count].profit_swap = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
                positions[current_ea_pos_count].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                string comment = PositionGetString(POSITION_COMMENT);
                positions[current_ea_pos_count].comment = comment;
                positions[current_ea_pos_count].open_time = (datetime)PositionGetInteger(POSITION_TIME);

                if(positions[current_ea_pos_count].type == POSITION_TYPE_BUY)
                {
                     if(positions[current_ea_pos_count].open_price > highest_buy_price) highest_buy_price = positions[current_ea_pos_count].open_price;
                     if(positions[current_ea_pos_count].open_price < lowest_buy_price) lowest_buy_price = positions[current_ea_pos_count].open_price;
                }
                else
                {
                     if(positions[current_ea_pos_count].open_price > highest_sell_price) highest_sell_price = positions[current_ea_pos_count].open_price;
                     if(positions[current_ea_pos_count].open_price < lowest_sell_price) lowest_sell_price = positions[current_ea_pos_count].open_price;
                }
                
                current_ea_pos_count++;
            }
        }
    }
    ArrayResize(positions, current_ea_pos_count);

    // --- PHA 1.5: THU THẬP PENDING ORDERS ---
    int total_orders_on_chart = OrdersTotal();
    ArrayResize(g_pending_orders, total_orders_on_chart);
    int current_ea_pending_count = 0;
    
    g_total_buy_pending = 0;
    g_total_sell_pending = 0;
    g_furthest_buy_pending_price = 0;
    g_furthest_sell_pending_price = 0;
    
    for(int i = total_orders_on_chart - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            g_pending_orders[current_ea_pending_count].ticket = ticket;
            g_pending_orders[current_ea_pending_count].volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            g_pending_orders[current_ea_pending_count].open_price = price;
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            g_pending_orders[current_ea_pending_count].type = order_type;
            g_pending_orders[current_ea_pending_count].comment = OrderGetString(ORDER_COMMENT);
            g_pending_orders[current_ea_pending_count].open_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            
            if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
            {
               g_pending_orders[current_ea_pending_count].position_type = POSITION_TYPE_BUY;
               if(order_type == ORDER_TYPE_BUY_STOP)
               {
                  g_total_buy_pending++;
                  if(g_furthest_buy_pending_price == 0 || price > g_furthest_buy_pending_price) g_furthest_buy_pending_price = price;
               }
            }
            else if(order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)
            {
               g_pending_orders[current_ea_pending_count].position_type = POSITION_TYPE_SELL;
               if(order_type == ORDER_TYPE_SELL_STOP)
               {
                  g_total_sell_pending++;
                  if(g_furthest_sell_pending_price == 0 || price < g_furthest_sell_pending_price) g_furthest_sell_pending_price = price;
               }
            }
            current_ea_pending_count++;
        }
    }
    ArrayResize(g_pending_orders, current_ea_pending_count);

    // --- PHA 2: TÍNH TOÁN CÁC THÔNG SỐ ---
    for(int i = 0; i < current_ea_pos_count; i++)
    {
        if(positions[i].type == POSITION_TYPE_BUY)
        {
            total_buy_pos++;
            total_buy_profit += positions[i].profit_swap;
            total_buy_lots += positions[i].volume; 
        }
        else
        {
            total_sell_pos++;
            total_sell_profit += positions[i].profit_swap;
            total_sell_lots += positions[i].volume;
        }
    }

    ResetSidewayLockIfNeeded(total_buy_pos, total_sell_pos);
    CheckSidewayLock(total_buy_pos, total_sell_pos);

    // --- RESET QUỸ ALL KHI HẾT LỆNH ---
    if(total_buy_pos == 0 && total_sell_pos == 0)
    {
        if(g_fund_all != 0.0)
        {
            g_fund_all = 0.0;
            SaveBudget();
            Log("INFO", "Reset QUY ALL ve 0.0 do khong con lenh nao mo.");
        }
    }

    double total_ea_profit = total_buy_profit + total_sell_profit;

    // --- BỘ KIỂM TRA STOPLOSS THEO DRAWDOWN ---
    if(inp_stoploss_drawdown > 0 && total_ea_profit <= -inp_stoploss_drawdown)
    {
        Log("WARNING", StringFormat("Phat hien DD ($%.2f) cham muc Stoploss ($%.2f). Dong toan bo lenh va ngung giao dich ngay lap tuc!", -total_ea_profit, inp_stoploss_drawdown));
        DeleteAllPendingOrders();
        CloseAllPositionsByEA(positions);
        g_trading_stopped_by_dd = true;
        
        UpdateDisplay(positions);
        UpdateProfitDisplay();
        ChartRedraw();
        return;
    }

    // --- BỘ KIỂM TRA TP THEO USD ---
    double current_target_tp_usd = g_sideway_lock ? inp_min_tp_usd : inp_take_profit_usd;
    if(current_target_tp_usd > 0)
    {
        if(total_ea_profit >= current_target_tp_usd || g_is_closing_tp_usd)
        {
            if(!g_is_closing_tp_usd)
            {
               Log("INFO", StringFormat("TP USD: Da dat muc tieu $%.2f. Dang kich hoat xoa toan bo lenh...", current_target_tp_usd));
               g_is_closing_tp_usd = true;
            }
            
            CloseAllPositionsByEA(positions);
            
            int remaining_open = CountPositions(POSITION_TYPE_BUY) + CountPositions(POSITION_TYPE_SELL);
            int remaining_pending = CountPendingOrdersByType(POSITION_TYPE_BUY) + CountPendingOrdersByType(POSITION_TYPE_SELL);
            
            if(remaining_open == 0 && remaining_pending == 0)
            {
                Log("INFO", "TP USD: Da dong tat ca positions va xoa tat ca pending. Reset QUY ALL.");
                g_fund_all = 0.0;
                g_is_closing_tp_usd = false;
                SaveBudget();
            }
            else
            {
                Log("WARNING", StringFormat("TP USD: Van con %d positions, %d pending. Se thu lai vao tick tiep theo.", remaining_open, remaining_pending));
                UpdateDisplay(positions);
                UpdateProfitDisplay();
                ChartRedraw();
                return;
            }
        }
    }

    // --- CÁC LOGIC CHẠY MỖI TICK ---
    if(!g_sideway_lock)
    {
        CleanRedundantPendingOrders();
        SyncPendingVolume();
        HealGridGaps(positions, g_pending_orders);
    }
    UpdateDynamicBaseLot(positions);
    
    ManageTesterWithdrawal();

    CheckAndOpenInitialTrades(total_buy_pos, total_sell_pos);
    ManageBuyPositions(positions, total_buy_pos, total_buy_profit, total_sell_profit, highest_buy_price, lowest_buy_price);
    ManageSellPositions(positions, total_sell_pos, total_buy_profit, total_sell_profit, highest_sell_price, lowest_sell_price);

    
    // --- Cập nhật giao diện ---
    if(GetTickCount() - g_last_ui_update_time > 2000)
    {
       UpdateDisplay(positions);
       UpdateProfitDisplay();
       g_last_ui_update_time = GetTickCount();
    }
    
    SyncOpenPositionsMemory();

}


//+------------------------------------------------------------------+
//| SỰ KIỆN GIAO DỊCH                                                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
}

//+------------------------------------------------------------------+
//| SỰ KIỆN BIỂU ĐỒ                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   OnPanelChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| KIỂM TRA TICKET TRONG BỘ NHỚ                                     |
//+------------------------------------------------------------------+
bool IsTicketInMemory(ulong ticket_to_check)
{
    for(int i = 0; i < ArraySize(g_open_position_tickets); i++)
    {
        if(g_open_position_tickets[i] == ticket_to_check) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| XỬ LÝ CÁC DEAL MỚI                                               |
//+------------------------------------------------------------------+
void ProcessNewDeals()
{
    HistorySelect(0, TimeCurrent());
    ulong current_total_deals = HistoryDealsTotal();

    if(current_total_deals > g_last_processed_deal_count)
    {
        for(ulong i = g_last_processed_deal_count; i < current_total_deals; i++)
        {
            ulong deal_ticket = HistoryDealGetTicket(i);
            
            ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
            if(entry_type == DEAL_ENTRY_OUT)
            {
                long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
                ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
                string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);

                if(deal_symbol != _Symbol) continue;
                
                bool should_account = false;

                if(deal_magic == inp_magic_number)
                {
                    should_account = true;
                    Log("INFO", "Phat hien lenh #" + (string)position_id + " cua EA da dong (tu dong).");
                }
                else if(deal_magic == 0)
                {
                    if(IsTicketInMemory(position_id))
                    {
                        should_account = true;
                        Log("WARNING", "Phat hien lenh #" + (string)position_id + " cua EA da dong (THU CONG).");
                    }
                }

                if(should_account)
                {
                    double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + 
                                         HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
                    
                    ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
                    
                    string original_comment = "";
                    if(HistorySelectByPosition(position_id)) {
                        int total_deals_for_pos = HistoryDealsTotal();
                        for(int d = 0; d < total_deals_for_pos; d++) {
                            ulong entry_ticket = HistoryDealGetTicket(d);
                            if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(entry_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
                                original_comment = HistoryDealGetString(entry_ticket, DEAL_COMMENT);
                                break;
                            }
                        }
                    }
                    HistorySelect(0, TimeCurrent());
                    
                    g_last_close_reason = LookupCloseReason(position_id);
                    UpdateAccountingOnDeal(deal_profit, deal_type, original_comment);
                }
            }
        }
        g_last_processed_deal_count = current_total_deals;
    }
}

//+------------------------------------------------------------------+
//| ĐỒNG BỘ BỘ NHỚ VỚI CÁC LỆNH ĐANG MỞ                            |
//+------------------------------------------------------------------+
void SyncOpenPositionsMemory()
{
    ArrayResize(g_open_position_tickets, 0); 
    int total_positions_on_chart = PositionsTotal();
    for(int i = 0; i < total_positions_on_chart; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                int last_size = ArraySize(g_open_position_tickets);
                ArrayResize(g_open_position_tickets, last_size + 1);
                g_open_position_tickets[last_size] = ticket;
            }
        }
    }
}
