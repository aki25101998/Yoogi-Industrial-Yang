//+------------------------------------------------------------------+
//|                                              Yoogi Yin Yang.mq5  |
//|                                                 Yoogi Yin Yang   |
//|                      --- TỆP EA CHÍNH (MAIN FILE) ---            |
//|               (Phiên bản 37.3 - Lưới rải siêu khôi phục)          |
//+------------------------------------------------------------------+
#property version   "37.3" // <<< CẬP NHẬT: Phiên bản siêu phục hồi
#property description "💼 Chào mừng bạn đến với Yoogi Yin Yang – Giải pháp giao dịch MT5 thông minh và cân bằng.\n\n"
"Thông tin cần biết cho lần đầu sử dụng:\n\n"
"1. Mở Tool > Options > Expert Advisors.\n\n"
"2. Tích vào ô 'Allow WebRequest for listed URL'.\n\n"
"3. Thêm địa chỉ: script.google.com\n\n"
"Vui lòng liên hệ Zalo | Telegram: 0346134678 để được kích hoạt\n\n"
"Nhấp vào Bom.so/Yoogi để truy cập trọn bộ công cụ của Yoogi\n\n";

#property link "Bom.so/Yoogi"

#include <Trade/Trade.mqh>

//--- Li�n k?t c�c t?p c?u h�nh v� logic
#include "Include/Input.mqh"
#include "Include/Globals.mqh"
#include "Include/Indicators.mqh" // Moved up
#include "Include/CoreLogic.mqh"
#include "Include/Trimming.mqh"
#include "Include/Security.mqh"
#include "Include/Panel.mqh"
#include "Include/InfoDisplay.mqh"
#include "Include/ProfitDisplay.mqh"

//--- Khai b�o d?i tu?ng giao d?ch
CTrade trade;

#include "Include/PendingOrders.mqh"

//--- Khai b�o h�m n?i b? ---
void UpdateLockStatus(const PositionInfo &positions[]);
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
void ProcessNewDeals();
void SyncOpenPositionsMemory();


//+------------------------------------------------------------------+
//| KH?I T?O                                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Ch? d?ng b? h�a th?i gian ---
   Print("Initializing EA... Waiting for server time synchronization.");
   while(TimeTradeServer() == 0 || TimeCurrent() - TimeTradeServer() > 10)
   {
      if(IsStopped()) return(INIT_FAILED);
      Sleep(200); 
   }
   Print("Server time synchronized. Continuing initialization.");

   //--- Ki?m tra b?n quy?n ---
   if(!CheckLicense())
   {
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(inp_magic_number);
   trade.SetMarginMode();
   
   InitializeGlobalVariables();
   OnInitIndicators(); //Khoi tao cac chi bao
   LoadBudget(); // <<< CAP NHAT: Load lai ngan sach tu F3
   CheckAndResetAccounting();
   UpdateProfitDisplay(); // <<< CAP NHAT: Cap nhat giao dien ngay lap tuc
   
   // "��nh d?u trang" ban d?u cho s? giao d?ch
   HistorySelect(0, TimeCurrent());
   g_last_processed_deal_count = HistoryDealsTotal();
   Log("INFO", "Kh?i t?o th�nh c�ng. �� ghi nh?n " + (string)g_last_processed_deal_count + " deal trong l?ch s?.");
   
   // �?ng b? b? nh? l?n d?u
   SyncOpenPositionsMemory();
   
   FillDcaLevels();
   FillDrawdownLevels();

   //--- T?o c�c th�nh ph?n giao di?n ---
   CreatePanel();
   CreateDisplay();
   CreateProfitDisplay();

   Log("INFO", "Yoogi Yin Yang started!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| H�M D?N D?P                                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handle_adx != INVALID_HANDLE) IndicatorRelease(handle_adx);

   Log("INFO", "EA stopped. Reason: " + IntegerToString(reason));
   
   DeletePanel();
   DeleteDisplay();
   DeleteProfitDisplay();
}

//+------------------------------------------------------------------+
//| H�M S? KI?N CH�NH (OnTick)                                       |
//+------------------------------------------------------------------+
void OnTick()
{
    // Lu�n x? l� c�c deal m?i, reset s? s�ch, v� c?p nh?t tr?ng th�i EMA tru?c
    ProcessNewDeals();
    
    // (S?a l?i K? to�n v1.5): Reset l� do d�ng l?nh SAU KHI s? s�ch d� du?c c?p nh?t
    g_last_close_reason = CR_UNKNOWN; 
    
    CheckAndResetAccounting();
    UpdateEmaLockStatus(); 

    // --- Khai b�o c�c bi?n c?c b? ---
    PositionInfo positions[];
    int total_buy_pos = 0, total_sell_pos = 0;
    double total_buy_profit = 0, total_sell_profit = 0;
    double total_buy_lots = 0, total_sell_lots = 0; 

    int total_positions_on_chart = PositionsTotal();
    ArrayResize(positions, total_positions_on_chart);
    int current_ea_pos_count = 0;

    double highest_buy_price = 0, lowest_buy_price = 9999999;
    double highest_sell_price = 0, lowest_sell_price = 9999999;
    int commentless_indices[];
    int commentless_count = 0;

    // --- PHA 1: THU TH?P D? LI?U TH� ---
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

                if(comment == "")
                {
                    ArrayResize(commentless_indices, commentless_count + 1);
                    commentless_indices[commentless_count] = current_ea_pos_count;
                    commentless_count++;
                }
                
                // Tinh hp/lp cho TOAN BO positions
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

    // --- PHA 1.5: THU TH?P D? LI?U PENDING ORDERS (V L?T) ---
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

    // --- PHA 2: SUY LU?N COMMENT CHO L?NH M? C�I ---
    for(int i = 0; i < commentless_count; i++)
    {
        int index_to_fix = commentless_indices[i];
        string inferred_comment = "";
        
        if(positions[index_to_fix].type == POSITION_TYPE_BUY)
        {
            if(highest_buy_price == 0) inferred_comment = "Initial Buy";
            else if(positions[index_to_fix].open_price > highest_buy_price) inferred_comment = "DCA DUONG";
            else inferred_comment = "DCA AM";
        }
        else
        {
            if(lowest_sell_price == 9999999) inferred_comment = "Initial Sell";
            else if(positions[index_to_fix].open_price < lowest_sell_price) inferred_comment = "DCA DUONG";
            else inferred_comment = "DCA AM";
        }
        positions[index_to_fix].comment = inferred_comment;
    }
    
    // --- PHA 2.5 �� X�A: Kh�ng c�n t�i ph�n lo?i DCA DUONG th�nh DCA H�NG ---

    // --- PHA 3: T�NH TO�N C�C TH�NG S? V?I LOGIC T�CH BI?T ---
    int pure_dca_am_buy_pos = 0, pure_dca_am_sell_pos = 0; 

    for(int i = 0; i < current_ea_pos_count; i++)
    {
        string cmt = positions[i].comment;
        
        if(positions[i].type == POSITION_TYPE_BUY)
        {
            total_buy_pos++;
            total_buy_profit += positions[i].profit_swap;
            total_buy_lots += positions[i].volume; 
            
            if(StringFind(cmt, "DCA AM") != -1)
            {
                pure_dca_am_buy_pos++;
            }
        }
        else // L?nh Sell
        {
            total_sell_pos++;
            total_sell_profit += positions[i].profit_swap;
            total_sell_lots += positions[i].volume;
            
            if(StringFind(cmt, "DCA AM") != -1)
            {
                pure_dca_am_sell_pos++;
            }
        }
    }
    
    UpdateLockStatus(positions);

// ================================================================= //
//        BỘ KIỂM TRA TỔNG LỆNH ĐỂ RESET QUỸ ALL TỰ ĐỘNG             //
// ================================================================= //
    if(total_buy_pos == 0 && total_sell_pos == 0)
    {
        if(g_fund_all != 0.0)
        {
            g_fund_all = 0.0;
            SaveBudget();
            Log("INFO", "Reset QUY ALL ve 0.0 do khong con lenh nao mo.");
        }
    }

// ================================================================= //
//        B? KI?M TRA TP THEO USD TON EA (v1.5)                     //
// ================================================================= //
    if(inp_take_profit_usd > 0)
    {
        double total_ea_profit = g_fund_all + total_buy_profit + total_sell_profit;
        if(total_ea_profit >= inp_take_profit_usd || g_is_closing_tp_usd)
        {
            if(!g_is_closing_tp_usd)
            {
               Log("INFO", StringFormat("TP USD: Da dat muc tieu $%.2f. Dang kich hoat xoa toan bo lenh...", inp_take_profit_usd));
               g_is_closing_tp_usd = true;
            }
            
            CloseAllPositionsByEA(positions);
            
            // Kiem tra thu con lenh nao khong (open va pending)
            int remaining_open = CountPositions(POSITION_TYPE_BUY) + CountPositions(POSITION_TYPE_SELL);
            int remaining_pending = CountPendingOrdersByType(POSITION_TYPE_BUY) + CountPendingOrdersByType(POSITION_TYPE_SELL);
            
            if(remaining_open == 0 && remaining_pending == 0)
            {
               Log("INFO", "TP USD: Xoa thanh cong TAT CA lenh open va pending. Reset QUY ALL ve 0.0");
               g_fund_all = 0.0;
               g_is_closing_tp_usd = false;
               SaveBudget();
            }
            else
            {
               Log("WARNING", StringFormat("TP USD: Van con %d lenh mo, %d lenh pending. Se thu lai vao tick tiep theo.", remaining_open, remaining_pending));
            }
            return; // Dừng ngay lập tức
        }
    }
// ================================================================= //
//                    H?T B? KI?M TRA TP USD                         //
// ================================================================= //


// ================================================================= //
//        B? NO QUY?T ?NH (v4.0 - Thm Uu tin 0: T?a Ch? ?nh)      //
// ================================================================= //
if(IsNewBar())
{
    // ================================================================= //
    //        UU TI�N 0: CH? �? T?A L?NH B?T BU?C (ONLY_BUY / ONLY_SELL)    //
    // ================================================================= //
    
    // --- TRIM_MODE d� x�a: EA lu�n t?a c? BUY v� SELL ---
    // Cross trim d� du?c x�a theo y�u c?u - ch? c�n t?a c�ng chi?u
    
    {
        // --- UU TI�N 1: X? l� c�c tr?ng th�i KH�A L?NH ---
//         Log("DEBUG", StringFormat("TRANG THAI KHOA: BUY_locked=%s, SELL_locked=%s", 
//             g_is_buy_locked ? "TRUE" : "FALSE", g_is_sell_locked ? "TRUE" : "FALSE"));
        
        // K?ch b?n 1.1: C? HAI phe c�ng b? kh�a
        if(g_is_buy_locked && g_is_sell_locked)
        {
            // Phe BUY ch? c� th? t? t?a b?ng T?a L?nh M?c �?nh
            if(total_buy_pos > 0 && inp_use_trimming)
            {
                AttemptSmartTrim(POSITION_TYPE_BUY, positions);
            }
            // Phe SELL ch? c� th? t? t?a b?ng T?a L?nh M?c �?nh
            if(total_sell_pos > 0 && inp_use_trimming)
            {
                AttemptSmartTrim(POSITION_TYPE_SELL, positions);
            }
        }
        // K?ch b?n 1.2: CH? phe BUY b? kh�a -> Nhi?m v? c?a phe SELL l� gi?i c?u
        else if(g_is_buy_locked && !g_is_sell_locked)
        {
            // Ki?m tra xem BUY c�n l?nh l? kh�ng
            bool buy_has_loss = HasLossOfType(POSITION_TYPE_BUY, "DCA DUONG", positions) ||
                                HasLossOfType(POSITION_TYPE_BUY, "Initial", positions) ||
                                HasLossOfType(POSITION_TYPE_BUY, "DCA AM", positions);
            
//             Log("DEBUG", StringFormat("KICH BAN 1.2: BUY bi khoa, SELL mo. buy_has_loss=%s, total_sell_pos=%d",
//                 buy_has_loss ? "TRUE" : "FALSE", total_sell_pos));
            
            if(buy_has_loss)
            {
                // BUY c�n l? -> S? d?ng t?a c�ng chi?u
                if(total_buy_pos > 0 && inp_use_trimming)
                {
//                     Log("DEBUG", "KICH BAN 1.2: BUY bi lo, dung TIA CUNG CHIEU (BUY) voi uu tien");
                    // Uu ti�n: DCA DUONG ? Initial ? DCA AM
                    bool trimmed = false;
                    if(HasLossOfType(POSITION_TYPE_BUY, "DCA DUONG", positions))
                    {
                        trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                            AttemptRescueTrimDcaDuong(POSITION_TYPE_BUY, positions) :
                            AttemptTrimDcaDuong(POSITION_TYPE_BUY, positions);
                    }
                    else if(HasLossOfType(POSITION_TYPE_BUY, "Initial", positions))
                    {
                        trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                            AttemptRescueTrimInitial(POSITION_TYPE_BUY, positions) :
                            AttemptTrimInitial(POSITION_TYPE_BUY, positions);
                    }
                    else if(HasLossOfType(POSITION_TYPE_BUY, "DCA AM", positions))
                    {
                        trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                            AttemptRescueTrimDcaAm(POSITION_TYPE_BUY, positions) :
                            AttemptTrimDcaAm(POSITION_TYPE_BUY, positions);
                    }
                }
            }
            else
            {
                // BUY h?t l? -> SELL du?c ph�p t? c?u ch�nh m�nh
//                 Log("DEBUG", "KICH BAN 1.2: BUY het lo, SELL tu tia (uu tien DCA DUONG)");
                if(total_sell_pos > 0 && inp_use_trimming)
                {
                    if(HasLossOfType(POSITION_TYPE_SELL, "DCA DUONG", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimDcaDuong(POSITION_TYPE_SELL, positions); else AttemptTrimDcaDuong(POSITION_TYPE_SELL, positions); }
                    else if(HasLossOfType(POSITION_TYPE_SELL, "Initial", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimInitial(POSITION_TYPE_SELL, positions); else AttemptTrimInitial(POSITION_TYPE_SELL, positions); }
                    else if(HasLossOfType(POSITION_TYPE_SELL, "DCA AM", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimDcaAm(POSITION_TYPE_SELL, positions); else AttemptTrimDcaAm(POSITION_TYPE_SELL, positions); }
                }
            }
        }
        // K?ch b?n 1.3: CH? phe SELL b? kh�a -> Nhi?m v? c?a phe BUY l� gi?i c?u
        else if(g_is_sell_locked && !g_is_buy_locked)
        {
            // Ki?m tra xem SELL c�n l?nh l? kh�ng
            bool sell_has_loss = HasLossOfType(POSITION_TYPE_SELL, "DCA DUONG", positions) ||
                                 HasLossOfType(POSITION_TYPE_SELL, "Initial", positions) ||
                                 HasLossOfType(POSITION_TYPE_SELL, "DCA AM", positions);
            
            if(sell_has_loss)
            {
                // SELL c�n l? -> S? d?ng t?a c�ng chi?u
                if(total_sell_pos > 0 && inp_use_trimming)
                {
                    // Uu ti�n: DCA DUONG ? Initial ? DCA AM
                    if(HasLossOfType(POSITION_TYPE_SELL, "DCA DUONG", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimDcaDuong(POSITION_TYPE_SELL, positions); else AttemptTrimDcaDuong(POSITION_TYPE_SELL, positions); }
                    else if(HasLossOfType(POSITION_TYPE_SELL, "Initial", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimInitial(POSITION_TYPE_SELL, positions); else AttemptTrimInitial(POSITION_TYPE_SELL, positions); }
                    else if(HasLossOfType(POSITION_TYPE_SELL, "DCA AM", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimDcaAm(POSITION_TYPE_SELL, positions); else AttemptTrimDcaAm(POSITION_TYPE_SELL, positions); }
                }
            }
            else
            {
                // SELL h?t l? -> BUY du?c ph�p t? c?u ch�nh m�nh
                if(total_buy_pos > 0 && inp_use_trimming)
                {
                    if(HasLossOfType(POSITION_TYPE_BUY, "DCA DUONG", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimDcaDuong(POSITION_TYPE_BUY, positions); else AttemptTrimDcaDuong(POSITION_TYPE_BUY, positions); }
                    else if(HasLossOfType(POSITION_TYPE_BUY, "Initial", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimInitial(POSITION_TYPE_BUY, positions); else AttemptTrimInitial(POSITION_TYPE_BUY, positions); }
                    else if(HasLossOfType(POSITION_TYPE_BUY, "DCA AM", positions))
                        { if(inp_trim_style == TRIM_STYLE_RESCUE) AttemptRescueTrimDcaAm(POSITION_TYPE_BUY, positions); else AttemptTrimDcaAm(POSITION_TYPE_BUY, positions); }
                }
            }
        }
        
        // --- UU TI�n 2: X? l� tr?ng th�i B�NH THU?NG (kh�ng c� phe n�o b? kh�a) ---
        else
        {
            // --- Logic cho phe BUY ---
            if(total_buy_pos > 0)
            {
                // K?ch b?n 2.1: Phe BUY dang L? -> Lu�n uu ti�n t?a l?nh d? ph�ng th?
                if(total_buy_profit < 0)
                {
                    if(inp_use_trimming)
                    {
                        AttemptSmartTrim(POSITION_TYPE_BUY, positions);
                    }
                }
                // K?ch b?n 2.2: Phe BUY dang L�I
                else
                {
                    // N?u B?T trailing -> Uu ti�n "G?ng L?i"
                    if(inp_enable_group_trailing)
                    {
                        // ExecuteDcaAmGroupTrailing(positions, POSITION_TYPE_BUY);
                    }
                    // N?u T?T trailing -> Chuy?n sang ch? d? "An Ch?c M?c B?n", t?a l?nh d? ch?t l?i non
                    else if(inp_use_trimming)
                    {
                        AttemptSmartTrim(POSITION_TYPE_BUY, positions);
                    }
                }
            }
            
            // --- Logic cho phe SELL ---
            if(total_sell_pos > 0)
            {
                // K?ch b?n 2.3: Phe SELL dang L? -> Lu�n uu ti�n t?a l?nh d? ph�ng th?
                if(total_sell_profit < 0)
                {
                    if(inp_use_trimming)
                    {
                        AttemptSmartTrim(POSITION_TYPE_SELL, positions);
                    }
                }
                // K?ch b?n 2.4: Phe SELL dang L�I
                else
                {
                    // N?u B?T trailing -> Uu ti�n "G?ng L?i"
                    if(inp_enable_group_trailing)
                    {
                        // ExecuteDcaAmGroupTrailing(positions, POSITION_TYPE_SELL);
                    }
                    // N?u T?T trailing -> Chuy?n sang ch? d? "An Ch?c M?c B?n", t?a l?nh d? ch?t l?i non
                    else if(inp_use_trimming)
                    {
                        AttemptSmartTrim(POSITION_TYPE_SELL, positions);
                    }
                }
            }
        }
    } // <<< K?T TH�C KH?I "B? N�O" M?I (if/else if/else)
}
// ================================================================= //
//                      H?T KH?I B? N�O                              //
// ================================================================= //


    // --- C�C LOGIC CH?Y M?I TICK ---
    HealGridGaps(positions, g_pending_orders);
    UpdateDynamicBaseLot(positions);
    
    double total_drawdown = total_buy_profit + total_sell_profit;

    ManageLotBalancing(total_buy_lots, total_sell_lots, total_drawdown, positions);

    // <<< KIEM TRA RUT TIEN TESTER (MOI TICK) >>>
    ManageTesterWithdrawal();

    // Tia khan cap: chay moi tick (phan ung nhanh)
    if(inp_emergency_trim_mode == ETM_PIP)
    {
        ManagePipBasedEmergencyTrim(positions);
    }
    else if(inp_emergency_trim_mode == ETM_DRAWDOWN)
    {
        ManageEmergencyTrimming(positions);
    }

    // --- XU LY DONG LENH KHA DAO CHIEU ---
    // ManageTrendReversalClosing(positions); // DA XOA THEO YEU CAU


    // Xac dinh trang thai Khoa (DD + EMA) truoc khi mo lenh moi
    UpdateLockStatus(positions);

    CheckAndOpenInitialTrades(total_buy_pos, total_sell_pos);
    ManageBuyPositions(positions, total_buy_pos, pure_dca_am_buy_pos, total_buy_profit, total_sell_profit, highest_buy_price, lowest_buy_price);
    ManageSellPositions(positions, total_sell_pos, pure_dca_am_sell_pos, total_buy_profit, total_sell_profit, highest_sell_price, lowest_sell_price);
    
    ManageTrailingStops(positions, total_buy_pos, total_sell_pos);
    
    // --- LOGIC UU TIEN (v9.0) ---
    // PHAN 1: Tia Cheo - Chi hoat dong khi CA HAI phe deu co lenh
    //         Phe thang (lai) se tia phe thua (lo)
    // PHAN 2: Tia Cung Chieu - Khi chi con 1 phe hoac cross trim khong hoat dong
    //         Thu tu: DCA DUONG -> Initial -> DCA AM -> Group Trailing
    
    // DEBUG: Log trang thai hien tai + QUY
//     Print(">>> YOOGI <<< BUY=", total_buy_pos, " SELL=", total_sell_pos, " | Quy_Buy=", DoubleToString(g_fund_trim_buy, 2), " Quy_Sell=", DoubleToString(g_fund_trim_sell, 2), " | Trigger=", inp_trim_trigger_level);
    
    // <<< CROSS TRIM �� �U?C X�A THEO Y�U C?U >>>
    // EA gi? ch? s? d?ng logic t?a c�ng chi?u (Same-side Trim)
    
    // ============================================================
    // TIA CUNG CHIEU (Same-side Trim)
    // Chi hoat dong khi:
    //   - BY_COUNT: So lenh >= trigger
    //   - BY_DISTANCE: Co lenh lo da di xa >= X pip
    // Thu tu: DCA DUONG -> Initial -> DCA AM
    // ============================================================
    
    // --- RESET QUY khi chuyen tu <trigger sang >=trigger (chi cho BY_COUNT) ---
    if(inp_trim_trigger_mode == TRIM_BY_COUNT)
    {
        // CROSS_SIDE: Reset quy doi dien (vi quy doi dien duoc dung de tia)
        if(total_buy_pos >= inp_trim_trigger_level && g_prev_buy_count < inp_trim_trigger_level)
        {
            if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
            {
                g_fund_trim_sell = 0;
                Log("INFO", StringFormat(">>> RESET QUY SELL = 0 (CROSS: BUY dat trigger %d) <<<", inp_trim_trigger_level));
            }
            else
            {
                g_fund_trim_buy = 0;
                Log("INFO", StringFormat(">>> RESET QUY BUY = 0 (so lenh tang tu %d len %d, dat trigger %d) <<<", g_prev_buy_count, total_buy_pos, inp_trim_trigger_level));
            }
            SaveBudget();
        }
        if(total_sell_pos >= inp_trim_trigger_level && g_prev_sell_count < inp_trim_trigger_level)
        {
            if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
            {
                g_fund_trim_buy = 0;
                Log("INFO", StringFormat(">>> RESET QUY BUY = 0 (CROSS: SELL dat trigger %d) <<<", inp_trim_trigger_level));
            }
            else
            {
                g_fund_trim_sell = 0;
                Log("INFO", StringFormat(">>> RESET QUY SELL = 0 (so lenh tang tu %d len %d, dat trigger %d) <<<", g_prev_sell_count, total_sell_pos, inp_trim_trigger_level));
            }
            SaveBudget();
        }
    }
    // --- RESET QUY khi lenh lo dat pip distance (chi cho BY_DISTANCE) ---
    else if(inp_trim_trigger_mode == TRIM_BY_DISTANCE)
    {
        // Kiem tra phe BUY: co lenh lo nao dat >= inp_trim_pip_distance khong?
        bool buy_has_distance = false;
        bool sell_has_distance = false;
        for(int i = 0; i < ArraySize(positions); i++)
        {
            if(positions[i].profit_swap < 0)
            {
                double pip_dist = GetPipDistanceFromEntry(positions[i]);
                if(pip_dist >= inp_trim_pip_distance)
                {
                    if(positions[i].type == POSITION_TYPE_BUY) buy_has_distance = true;
                    else sell_has_distance = true;
                }
            }
        }
        
        // BUY: lan dau dat pip distance -> reset quy
        if(buy_has_distance && !g_buy_distance_triggered)
        {
            g_buy_distance_triggered = true;
            if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
            {
                g_fund_trim_sell = 0;
                Log("INFO", StringFormat(">>> RESET QUY SELL = 0 (CROSS: BUY dat %.0f pip) <<<", inp_trim_pip_distance));
            }
            else
            {
                g_fund_trim_buy = 0;
                Log("INFO", StringFormat(">>> RESET QUY BUY = 0 (BUY dat %.0f pip) <<<", inp_trim_pip_distance));
            }
            SaveBudget();
        }
        else if(!buy_has_distance && g_buy_distance_triggered)
        {
            g_buy_distance_triggered = false; // San sang cho lan trigger tiep theo
        }
        
        // SELL: lan dau dat pip distance -> reset quy
        if(sell_has_distance && !g_sell_distance_triggered)
        {
            g_sell_distance_triggered = true;
            if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
            {
                g_fund_trim_buy = 0;
                Log("INFO", StringFormat(">>> RESET QUY BUY = 0 (CROSS: SELL dat %.0f pip) <<<", inp_trim_pip_distance));
            }
            else
            {
                g_fund_trim_sell = 0;
                Log("INFO", StringFormat(">>> RESET QUY SELL = 0 (SELL dat %.0f pip) <<<", inp_trim_pip_distance));
            }
            SaveBudget();
        }
        else if(!sell_has_distance && g_sell_distance_triggered)
        {
            g_sell_distance_triggered = false; // San sang cho lan trigger tiep theo
        }
    }

    // --- LỌC LỖ NHIỀU NHẤT CHO QUỸ ALL ---
    bool allow_buy_trim = true;
    bool allow_sell_trim = true;
    
    if(inp_take_profit_usd > 0)
    {
        if(total_buy_profit >= 0 && total_sell_profit >= 0)
        {
            allow_buy_trim = false;
            allow_sell_trim = false;
        }
        else if(total_buy_profit < total_sell_profit)
        {
            allow_sell_trim = false; // Buy đang lỗi nặng hơn
        }
        else if(total_sell_profit < total_buy_profit)
        {
            allow_buy_trim = false; // Sell đang lỗi nặng hơn
        }
    }

    // --- Phe BUY ---
    if(allow_buy_trim && 
       ((inp_trim_trigger_mode == TRIM_BY_COUNT && total_buy_pos >= inp_trim_trigger_level) ||
       (inp_trim_trigger_mode == TRIM_BY_DISTANCE && total_buy_pos > 0)))
    {
//         Log("DEBUG", "BUY: CHE DO TIA CUNG CHIEU (so lenh >= trigger)");
        
        // DEBUG: Dem so lenh theo loai comment
        int count_dca_duong = 0, count_initial = 0, count_dca_am = 0, count_other = 0;
        for(int i = 0; i < ArraySize(positions); i++)
        {
            if(positions[i].type == POSITION_TYPE_BUY)
            {
                if(StringFind(positions[i].comment, "DCA DUONG") != -1) count_dca_duong++;
                else if(StringFind(positions[i].comment, "Initial") != -1) count_initial++;
                else if(StringFind(positions[i].comment, "DCA AM") != -1) count_dca_am++;
                else 
                {
                    count_other++;
//                     Log("DEBUG", StringFormat("BUY OTHER #%I64u: comment='%s', profit=%.2f", 
//                         positions[i].ticket, positions[i].comment, positions[i].profit_swap));
                }
            }
        }
//         Log("DEBUG", StringFormat("BUY COMMENTS: DCA_DUONG=%d, Initial=%d, DCA_AM=%d, Other=%d", 
//             count_dca_duong, count_initial, count_dca_am, count_other));
        
        bool has_dca_duong_loss = HasLossOfType(POSITION_TYPE_BUY, "DCA DUONG", positions);
        bool has_initial_loss = HasLossOfType(POSITION_TYPE_BUY, "Initial", positions);
        bool has_dca_am_loss = HasLossOfType(POSITION_TYPE_BUY, "DCA AM", positions);
        
//         Log("DEBUG", StringFormat("BUY: DCA_DUONG_lo=%s, Initial_lo=%s, DCA_AM_lo=%s", 
//             has_dca_duong_loss ? "CO" : "KHONG",
//             has_initial_loss ? "CO" : "KHONG", 
//             has_dca_am_loss ? "CO" : "KHONG"));
        
        bool trimmed = false;
        
        // 1?? Uu tien 1: Tia DCA DUONG (BLOCKING - neu co DCA DUONG lo thi PHAI tia no truoc)
        if(has_dca_duong_loss)
        {
            trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                AttemptRescueTrimDcaDuong(POSITION_TYPE_BUY, positions) :
                AttemptTrimDcaDuong(POSITION_TYPE_BUY, positions);
//             Log("DEBUG", StringFormat("BUY: [1] AttemptTrimDcaDuong = %s", trimmed ? "TRUE" : "FALSE (CHO DU QUY - KHONG TIA GI KHAC)"));
            
            // NEU KHONG TIA DUOC DCA DUONG -> DUNG LAI, CHO DCA AM LAI LEN
            if(!trimmed)
            {
//                 Log("DEBUG", "BUY: Co DCA DUONG lo nhung chua du lai tu DCA AM -> CHO, khong tia gi khac");
                // KHONG lam gi ca, cho DCA AM gom lai
            }
        }
        // 2?? Uu tien 2: Tia Initial (chi khi KHONG con DCA DUONG lo)
        else if(has_initial_loss)
        {
            trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                AttemptRescueTrimInitial(POSITION_TYPE_BUY, positions) :
                AttemptTrimInitial(POSITION_TYPE_BUY, positions);
//             Log("DEBUG", StringFormat("BUY: [2] AttemptTrimInitial = %s", trimmed ? "TRUE" : "FALSE (CHO DU QUY)"));
            
            if(!trimmed)
            {
//                 Log("DEBUG", "BUY: Co Initial lo nhung chua du lai -> CHO");
            }
        }
        // 3?? Uu tien 3: Tia DCA AM (chi khi KHONG con DCA DUONG va Initial lo)
        else if(has_dca_am_loss)
        {
            trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                AttemptRescueTrimDcaAm(POSITION_TYPE_BUY, positions) :
                AttemptTrimDcaAm(POSITION_TYPE_BUY, positions);
//             Log("DEBUG", StringFormat("BUY: [3] AttemptTrimDcaAm = %s", trimmed ? "TRUE" : "FALSE"));
        }
        else
        {
//             Log("DEBUG", "BUY: Khong co lenh lo -> Cho");
        }
    }
    
    // <<< C?P NH?T: Group Trailing ch?y SONG SONG v?i Trimming >>>
    if(total_buy_pos > 0)
    {
//         Log("DEBUG", "BUY: GROUP TRAILING (song song voi Trimming)");
        ExecuteDcaAmGroupTrailing(positions, POSITION_TYPE_BUY);
    }
    
    // --- Phe SELL ---
    if(allow_sell_trim && 
       ((inp_trim_trigger_mode == TRIM_BY_COUNT && total_sell_pos >= inp_trim_trigger_level) ||
       (inp_trim_trigger_mode == TRIM_BY_DISTANCE && total_sell_pos > 0)))
    {
//         Log("DEBUG", "SELL: CHE DO TIA CUNG CHIEU (so lenh >= trigger)");
        
        bool has_dca_duong_loss = HasLossOfType(POSITION_TYPE_SELL, "DCA DUONG", positions);
        bool has_initial_loss = HasLossOfType(POSITION_TYPE_SELL, "Initial", positions);
        bool has_dca_am_loss = HasLossOfType(POSITION_TYPE_SELL, "DCA AM", positions);
        
//         Log("DEBUG", StringFormat("SELL: DCA_DUONG_lo=%s, Initial_lo=%s, DCA_AM_lo=%s", 
//             has_dca_duong_loss ? "CO" : "KHONG",
//             has_initial_loss ? "CO" : "KHONG", 
//             has_dca_am_loss ? "CO" : "KHONG"));
        
        bool trimmed = false;
        
        // 1?? Uu tien 1: Tia DCA DUONG (BLOCKING - neu co DCA DUONG lo thi PHAI tia no truoc)
        if(has_dca_duong_loss)
        {
            trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                AttemptRescueTrimDcaDuong(POSITION_TYPE_SELL, positions) :
                AttemptTrimDcaDuong(POSITION_TYPE_SELL, positions);
//             Log("DEBUG", StringFormat("SELL: [1] AttemptTrimDcaDuong = %s", trimmed ? "TRUE" : "FALSE (CHO DU QUY - KHONG TIA GI KHAC)"));
            
            // NEU KHONG TIA DUOC DCA DUONG -> DUNG LAI, CHO DCA AM LAI LEN
            if(!trimmed)
            {
//                 Log("DEBUG", "SELL: Co DCA DUONG lo nhung chua du lai tu DCA AM -> CHO, khong tia gi khac");
                // KHONG lam gi ca, cho DCA AM gom lai
            }
        }
        // 2?? Uu tien 2: Tia Initial (chi khi KHONG con DCA DUONG lo)
        else if(has_initial_loss)
        {
            trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                AttemptRescueTrimInitial(POSITION_TYPE_SELL, positions) :
                AttemptTrimInitial(POSITION_TYPE_SELL, positions);
//             Log("DEBUG", StringFormat("SELL: [2] AttemptTrimInitial = %s", trimmed ? "TRUE" : "FALSE (CHO DU QUY)"));
            
            if(!trimmed)
            {
//                 Log("DEBUG", "SELL: Co Initial lo nhung chua du lai -> CHO");
            }
        }
        // 3?? Uu tien 3: Tia DCA AM (chi khi KHONG con DCA DUONG va Initial lo)
        else if(has_dca_am_loss)
        {
            trimmed = (inp_trim_style == TRIM_STYLE_RESCUE) ?
                AttemptRescueTrimDcaAm(POSITION_TYPE_SELL, positions) :
                AttemptTrimDcaAm(POSITION_TYPE_SELL, positions);
//             Log("DEBUG", StringFormat("SELL: [3] AttemptTrimDcaAm = %s", trimmed ? "TRUE" : "FALSE"));
        }
        else
        {
//             Log("DEBUG", "SELL: Khong co lenh lo -> Cho");
        }
    }
    
    // <<< C?P NH?T: Group Trailing ch?y SONG SONG v?i Trimming >>>
    if(total_sell_pos > 0)
    {
//         Log("DEBUG", "SELL: GROUP TRAILING (song song voi Trimming)");
        ExecuteDcaAmGroupTrailing(positions, POSITION_TYPE_SELL);
    }
    
    if(GetTickCount() - g_last_ui_update_time > 2000)
    {
       UpdateDisplay(positions);
       UpdateProfitDisplay();
       g_last_ui_update_time = GetTickCount();
    }
    
    // �?ng b? b? nh? ticket ? cu?i m?i tick d? chu?n b? cho l?n ki?m tra sau
    SyncOpenPositionsMemory();
    // --- Cap nhat so lenh cho lan tick tiep theo ---
    g_prev_buy_count = total_buy_pos;
    g_prev_sell_count = total_sell_pos;

}


//+------------------------------------------------------------------+
//| H�M S? KI?N GIAO D?CH (OnTradeTransaction)                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // �? tr?ng v� ProcessNewDeals d� x? l� to�n di?n hon
}

//+------------------------------------------------------------------+
//| H�M S? KI?N BI?U �? (ChartEvent)                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   OnPanelChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| C?P NH?T TR?NG TH�I KH�A (K?T H?P DD V� EMA)                     |
//+------------------------------------------------------------------+
void UpdateLockStatus(const PositionInfo &positions[])
{
    // --- T�nh to�n l?i nhu?n c?a m?i phe ---
    double buy_profit = 0;
    double sell_profit = 0;
    int buy_count = 0;
    int sell_count = 0;
    for(int i=0; i < ArraySize(positions); i++)
    {
        if(positions[i].type == POSITION_TYPE_BUY) {
            buy_profit += positions[i].profit_swap;
            buy_count++;
        }
        else {
            sell_profit += positions[i].profit_swap;
            sell_count++;
        }
    }

    // === X? L� CHO PHE BUY ===
    bool previous_buy_lock_status = g_is_buy_locked;
    
    // 1. Ki?m tra kh�a do Drawdown
    bool is_locked_by_dd_buy = (inp_dd_lock_buy_amount > 0 && buy_profit < -inp_dd_lock_buy_amount);
    
    // 2. Quy?t d?nh tr?ng th�i kh�a cu?i c�ng (DD ho?c EMA)
    // 2. Quyet dinh trang thai khoa cuoi cung (DD hoac EMA)
    // <<< SOFT LOCK LOGIC >>>
    if(is_locked_by_dd_buy) {
        g_is_buy_locked = true;
    } else if(g_is_buy_locked_by_ema && buy_count == 0) {
        g_is_buy_locked = true; // Full Lock (No positions)
    } else {
        g_is_buy_locked = false; // Soft Lock (Has positions)
    }

    // 3. Ghi log n?u tr?ng th�i thay d?i
    if(g_is_buy_locked && !previous_buy_lock_status)
    {
        string reason = is_locked_by_dd_buy ? StringFormat("do DD (%.2f) vu?t ngu?ng %.2f", buy_profit, -inp_dd_lock_buy_amount) : "do t�n hi?u EMA";
        Log("WARNING", "PHE BUY B? KH�A " + reason + ".");
        DeletePendingOrdersByType(POSITION_TYPE_BUY);
    }
    if(!g_is_buy_locked && previous_buy_lock_status)
    {
        Log("INFO", "PHE BUY �U?C M? KH�A.");
    }

    // === X? L� CHO PHE SELL ===
    bool previous_sell_lock_status = g_is_sell_locked;
    
    // 1. Ki?m tra kh�a do Drawdown
    bool is_locked_by_dd_sell = (inp_dd_lock_sell_amount > 0 && sell_profit < -inp_dd_lock_sell_amount);

    // 2. Quy?t d?nh tr?ng th�i kh�a cu?i c�ng (DD ho?c EMA)
    // 2. Quyet dinh trang thai khoa cuoi cung (DD hoac EMA)
    // <<< SOFT LOCK LOGIC >>>
    if(is_locked_by_dd_sell) {
        g_is_sell_locked = true;
    } else if(g_is_sell_locked_by_ema && sell_count == 0) {
        g_is_sell_locked = true; // Full Lock (No positions)
    } else {
        g_is_sell_locked = false; // Soft Lock (Has positions)
    }

    // 3. Ghi log n?u tr?ng th�i thay d?i
    if(g_is_sell_locked && !previous_sell_lock_status)
    {
        string reason = is_locked_by_dd_sell ? StringFormat("do DD (%.2f) vu?t ngu?ng %.2f", sell_profit, -inp_dd_lock_sell_amount) : "do t�n hi?u EMA";
        Log("WARNING", "PHE SELL B? KH�A " + reason + ".");
        DeletePendingOrdersByType(POSITION_TYPE_SELL);
    }
    if(!g_is_sell_locked && previous_sell_lock_status)
    {
        Log("INFO", "PHE SELL �U?C M? KH�A.");
    }
}


//+------------------------------------------------------------------+
//| KI?M TRA XEM TICKET C� TRONG B? NH? T?M KH�NG                    |
//+------------------------------------------------------------------+
bool IsTicketInMemory(ulong ticket_to_check)
{
    for(int i = 0; i < ArraySize(g_open_position_tickets); i++)
    {
        if(g_open_position_tickets[i] == ticket_to_check)
        {
            return true;
        }
    }
    return false;
}


//+------------------------------------------------------------------+
//| X? L� C�C GIAO D?CH (DEAL) M?I - PHI�N B?N N�NG C?P              |
//| (X? l� c? deal c?a EA v� deal d�ng th? c�ng)                      |
//+------------------------------------------------------------------+
void ProcessNewDeals()
{
    HistorySelect(0, TimeCurrent());
    ulong current_total_deals = HistoryDealsTotal();

    // DEBUG: Print m?i 30 gi�y d? ki?m tra m� kh�ng spam
    static datetime last_debug_time = 0;
    if(TimeCurrent() - last_debug_time >= 30) {
//         Print(">>> DEAL MONITOR: current_deals=", current_total_deals, " last_processed=", g_last_processed_deal_count);
        last_debug_time = TimeCurrent();
    }

    // DEBUG: Ch? print khi c� deal m?i d? tr�nh spam
    if(current_total_deals > g_last_processed_deal_count)
    {
//         Print(">>> ProcessNewDeals: NEW DEALS! current=", current_total_deals, " last=", g_last_processed_deal_count);
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
                
                // DEBUG: Print m?i deal OUT d? ki?m tra
                string deal_comment_temp = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
//                 Print(">>> DEAL DETECTED: magic=", deal_magic, " pos_id=", position_id, 
//                       " comment='", deal_comment_temp, "' inp_magic=", inp_magic_number);

                if(deal_magic == inp_magic_number)
                {
                    should_account = true;
                    Log("INFO", "Phat hien lenh #" + (string)position_id + " cua EA da dong (tu dong). Cap nhat so sach...");
                }
                else if(deal_magic == 0)
                {
                    if(IsTicketInMemory(position_id))
                    {
                        should_account = true;
                        Log("WARNING", "Phat hien lenh #" + (string)position_id + " cua EA da dong (THU CONG). Cap nhat so sach...");
                    }
                }

                if(should_account)
                {
                    // <<< FIX BUG 2: Bỏ DEAL_COMMISSION để đồng nhất với profit_swap >>>
                    double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + 
                                         HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
                    
                    // <<< C?P NH?T: L?y th�m deal_type v� deal_comment d? t�ch lu? qu? >>>
                    ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
                    
                    // <<< FIX: L?y comment t? deal M? L?NH v� broker ghi d� comment khi d�ng b?i SL >>>
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
                    // Kh�i ph?c l?i HistorySelect to�n b?
                    HistorySelect(0, TimeCurrent());
                    
                    // DEBUG FUND: Print tr?c ti?p d? d? th?y
//                     Print(">>> FUND DEBUG: profit=", DoubleToString(deal_profit, 2), 
//                           " type=", (int)deal_type, 
//                           " original_comment='", original_comment, "'",
//                           " | Quy_Buy=", DoubleToString(g_fund_trim_buy, 2),
//                           " Quy_Sell=", DoubleToString(g_fund_trim_sell, 2));

                    // <<< FIX BUG 1: Xác định lý do đóng lệnh per-ticket thay vì dùng biến global >>>
                    g_last_close_reason = LookupCloseReason(position_id);
                    
                    UpdateAccountingOnDeal(deal_profit, deal_type, original_comment);
                }
            }
        }
        g_last_processed_deal_count = current_total_deals;
    }
}

//+------------------------------------------------------------------+
//| �?NG B? B? NH? V?I C�C L?NH �ANG M?                              |
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
//+------------------------------------------------------------------+




