//+------------------------------------------------------------------+
//|                                                  CoreLogic.mqh |
//|                        YOOGI INDUSTRIAL YANG                      |
//|              --- TỆP CHỨA LOGIC GIAO DỊCH CỐT LÕI ---            |
//+------------------------------------------------------------------+

// Forward declarations
bool HasPendingNearPrice(ENUM_POSITION_TYPE type, double target_price);
bool HasPositionNearPrice(ENUM_POSITION_TYPE type, double target_price, const PositionInfo &positions[]);
void DeletePendingNearPrice(ENUM_POSITION_TYPE type, double target_price);

//+------------------------------------------------------------------+
//| TÍNH TOÁN LOT CHO LỆNH TIẾP THEO (Dynamic Base Lot)              |
//+------------------------------------------------------------------+
void UpdateDynamicBaseLot(const PositionInfo &positions[])
{
   g_current_base_lot_buy = inp_lot_dca_duong;
   g_current_base_lot_sell = inp_lot_dca_duong;
   g_current_dca_duong_distance = inp_dca_duong_distance_pips;
}

//+------------------------------------------------------------------+
//| QUẢN LÝ LỆNH BUY — DUAL MODE (Market-First + Pending-as-Backup) |
//+------------------------------------------------------------------+
void ManageBuyPositions(const PositionInfo &positions[], int total_buy_pos, double total_buy_profit, double total_sell_profit, double hp, double lp)
{
   if(!inp_enable_buy || total_buy_pos == 0) return;
   if(!inp_enable_dca_duong) return;

   if(inp_enable_pending_mode) RefillStopOrdersIfNeeded(POSITION_TYPE_BUY, hp);
   
   double ca = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double dist_points = (double)PipToPoints(g_current_dca_duong_distance) * _Point;
   bool tp_removed = false;
   
   // Multi-level catch-up: mở TẤT CẢ mức DCA bị miss trong 1 tick
   double current_hp = hp;
   
   while(ca >= current_hp + dist_points)
   {
      double target = current_hp + dist_points;
      
      // Xóa TP khi sắp mở lệnh thứ 2 (chỉ 1 lần)
      if(!tp_removed && total_buy_pos == 1 && inp_initial_tp_pips > 0)
      {
          for(int k = 0; k < ArraySize(positions); k++)
          {
              if(positions[k].type == POSITION_TYPE_BUY)
              {
                  if(PositionSelectByTicket(positions[k].ticket))
                  {
                      double t = PositionGetDouble(POSITION_TP);
                      if(t > 0) trade.PositionModify(positions[k].ticket, 0, 0);
                  }
                  break;
              }
          }
          tp_removed = true;
      }
      
      // POSITION GUARD: Chỉ skip nếu đã có POSITION THẬT gần đó
      if(HasPositionNearPrice(POSITION_TYPE_BUY, target, positions))
      {
         current_hp = target;
         continue;
      }
      
      // Mở Market Order trực tiếp
      if(trade.Buy(g_current_base_lot_buy, _Symbol, 0, 0, 0, "DCA DUONG"))
      {
         total_buy_pos++;
         // Proactive Cleanup: xóa pending trùng gần mức giá vừa mở
         if(inp_enable_pending_mode) DeletePendingNearPrice(POSITION_TYPE_BUY, target);
      }
      else
      {
         Log("ERROR", StringFormat("Loi mo lenh DCA DUONG BUY tai muc %f. Ma loi: %d", target, (int)trade.ResultRetcode()));
         break; // Dung lai neu lenh bi reject (tranh spam)
      }
      
      current_hp = target;
   }
}

//+------------------------------------------------------------------+
//| QUẢN LÝ LỆNH SELL — DUAL MODE (Market-First + Pending-as-Backup) |
//+------------------------------------------------------------------+
void ManageSellPositions(const PositionInfo &positions[], int total_sell_pos, double total_buy_profit, double total_sell_profit, double hp, double lp)
{
   if(!inp_enable_sell || total_sell_pos == 0) return;
   if(!inp_enable_dca_duong) return;

   if(inp_enable_pending_mode) RefillStopOrdersIfNeeded(POSITION_TYPE_SELL, lp);
   
   double cb = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist_points = (double)PipToPoints(g_current_dca_duong_distance) * _Point;
   bool tp_removed = false;
   
   // Multi-level catch-up: mở TẤT CẢ mức DCA bị miss trong 1 tick
   double current_lp = lp;
   
   while(cb <= current_lp - dist_points)
   {
      double target = current_lp - dist_points;
      
      // Xóa TP khi sắp mở lệnh thứ 2 (chỉ 1 lần)
      if(!tp_removed && total_sell_pos == 1 && inp_initial_tp_pips > 0)
      {
          for(int k = 0; k < ArraySize(positions); k++)
          {
              if(positions[k].type == POSITION_TYPE_SELL)
              {
                  if(PositionSelectByTicket(positions[k].ticket))
                  {
                      double t = PositionGetDouble(POSITION_TP);
                      if(t > 0) trade.PositionModify(positions[k].ticket, 0, 0);
                  }
                  break;
              }
          }
          tp_removed = true;
      }
      
      // POSITION GUARD: Chỉ skip nếu đã có POSITION THẬT gần đó
      if(HasPositionNearPrice(POSITION_TYPE_SELL, target, positions))
      {
         current_lp = target;
         continue;
      }
      
      // Mở Market Order trực tiếp
      if(trade.Sell(g_current_base_lot_sell, _Symbol, 0, 0, 0, "DCA DUONG"))
      {
         total_sell_pos++;
         // Proactive Cleanup: xóa pending trùng gần mức giá vừa mở
         if(inp_enable_pending_mode) DeletePendingNearPrice(POSITION_TYPE_SELL, target);
      }
      else
      {
         Log("ERROR", StringFormat("Loi mo lenh DCA DUONG SELL tai muc %f. Ma loi: %d", target, (int)trade.ResultRetcode()));
         break; // Dung lai neu lenh bi reject (tranh spam)
      }
      
      current_lp = target;
   }
}

//+------------------------------------------------------------------+
//| KIỂM TRA THỜI GIAN THEO PHIÊN (Dùng giờ máy tính - TimeLocal)    |
//+------------------------------------------------------------------+
bool IsInTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   int h = dt.hour;
   
   if(inp_season_type == SUMMER_TIME)
   {
      if(h >= 6 && h < 8) return true;   // Phien A
      if(h >= 14 && h < 17) return true; // Phien Au
      if(h >= 19 && h < 21) return true; // Phien My
   }
   else // WINTER_TIME
   {
      if(h >= 6 && h < 8) return true;   // Phien A
      if(h >= 15 && h < 17) return true; // Phien Au
      if(h >= 20 && h < 22) return true; // Phien My
   }
   return false;
}

//+------------------------------------------------------------------+
//| KIỂM TRA VÀ MỞ LỆNH INITIAL                                      |
//+------------------------------------------------------------------+
void CheckAndOpenInitialTrades(int total_buy_pos, int total_sell_pos)
{
   bool need_recycle_buy = false;
   double initial_buy_ask = 0;
   bool need_recycle_sell = false;
   double initial_sell_bid = 0;

   // --- Kiem tra phien giao dich ---
   bool session_active = true;
   if(inp_enable_session)
   {
      session_active = IsInTradingSession();
   }

   // --- Xử lý mở lệnh Initial BUY ---
   if(inp_enable_buy && total_buy_pos == 0)
   {
       if(inp_withdrawal_mode)
       {
          Log("INFO", "Che do Rut tien: Da chan mo lenh Initial Buy moi.");
       }
       else if(!session_active)
       {
          Log("INFO", "Ngoai phien giao dich: Da chan mo lenh Initial Buy moi.");
       }
       else
       {
          Log("INFO", "--- CHU TRINH BUY MOI ---");
          double t = 0;
          if(inp_initial_tp_pips > 0) t = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (double)PipToPoints(inp_initial_tp_pips) * _Point;
          if(trade.Buy(g_current_base_lot_buy, _Symbol, 0.0, 0.0, t, "Initial Buy")) { 
             initial_buy_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
             need_recycle_buy = true;
          } else Log("ERROR", StringFormat("Loi mo lenh BUY ban dau. Ma loi: %d", (int)trade.ResultRetcode()));
       }
   }

   // --- Xử lý mở lệnh Initial SELL ---
   if(inp_enable_sell && total_sell_pos == 0)
   {
       if(inp_withdrawal_mode)
       {
          Log("INFO", "Che do Rut tien: Da chan mo lenh Initial Sell moi.");
       }
       else if(!session_active)
       {
          Log("INFO", "Ngoai phien giao dich: Da chan mo lenh Initial Sell moi.");
       }
       else
       {
          Log("INFO", "--- CHU TRINH SELL MOI ---");
          double t = 0;
          if(inp_initial_tp_pips > 0) t = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (double)PipToPoints(inp_initial_tp_pips) * _Point;
          if(trade.Sell(g_current_base_lot_sell, _Symbol, 0.0, 0.0, t, "Initial Sell")) { 
             initial_sell_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
             need_recycle_sell = true;
          } else Log("ERROR", StringFormat("Loi mo lenh SELL ban dau. Ma loi: %d", (int)trade.ResultRetcode()));
       }
   }
   
    // Dat lenh Pending: Xen ke Buy/Sell khi ca 2 chieu cung khoi tao
    if(need_recycle_buy && need_recycle_sell)
    {
        RecyclePendingOrdersInterleaved(initial_buy_ask, initial_sell_bid);
    }
    else
    {
        if(need_recycle_buy) RecyclePendingOrders(POSITION_TYPE_BUY, initial_buy_ask);
        if(need_recycle_sell) RecyclePendingOrders(POSITION_TYPE_SELL, initial_sell_bid);
    }
}


//+------------------------------------------------------------------+
//| CẬP NHẬT KẾ TOÁN KHI CÓ DEAL MỚI                                 |
//+------------------------------------------------------------------+
void UpdateAccountingOnDeal(double deal_profit, ENUM_DEAL_TYPE deal_type = DEAL_TYPE_BUY, string deal_comment = "")
{
   if(deal_profit == 0) return;
   
   // --- LOGIC QUY ALL ---
   if(inp_take_profit_usd > 0)
   {
      g_fund_all += deal_profit;
      Log("INFO", StringFormat(">>> QUY ALL %+.2f. Tong: %.2f <<<", deal_profit, g_fund_all));
      SaveBudget();
   }

   if(deal_profit > 0)
   {
      double profit_for_safe_day = deal_profit * (inp_emergency_profit_retention_day / 100.0);
      double profit_for_budget_day = deal_profit - profit_for_safe_day;
      g_safe_day += profit_for_safe_day;
      g_budget_day += profit_for_budget_day;
      double profit_for_safe_week = deal_profit * (inp_emergency_profit_retention_week / 100.0);
      double profit_for_budget_week = deal_profit - profit_for_safe_week;
      g_safe_week += profit_for_safe_week;
      g_budget_week += profit_for_budget_week;
   }
   else
   {
      double loss_amount = -deal_profit;
      switch(g_last_close_reason)
      {
         case CR_EMERGENCY:
         {
            g_trimmed_day += loss_amount; g_trimmed_week += loss_amount;
            g_budget_day -= loss_amount; g_budget_week -= loss_amount;
            Log("WARNING", StringFormat("Ke toan LO KHAN CAP: -%.2f.", loss_amount));
            break;
         }
         case CR_TACTICAL:
         default:
         {
            double loss_for_safe_day = loss_amount * (inp_emergency_profit_retention_day / 100.0);
            double loss_for_budget_day = loss_amount - loss_for_safe_day;
            g_safe_day -= loss_for_safe_day; g_budget_day -= loss_for_budget_day;
            double loss_for_safe_week = loss_amount * (inp_emergency_profit_retention_week / 100.0);
            double loss_for_budget_week = loss_amount - loss_for_safe_week;
            g_safe_week -= loss_for_safe_week; g_budget_week -= loss_for_budget_week;
            Log("INFO", StringFormat("Ke toan LO: -%.2f.", loss_amount));
            break;
         }
      }
   }
   Log("INFO", StringFormat("So sach cap nhat: KSN=%.2f, NSN=%.2f | KST=%.2f, NST=%.2f", g_safe_day, g_budget_day, g_safe_week, g_budget_week));
   SaveBudget();
}

//+------------------------------------------------------------------+
//| ĐÓNG TẤT CẢ LỆNH CỦA EA                                          |
//+------------------------------------------------------------------+
void CloseAllPositionsByEA(const PositionInfo &positions[])
{
   int total = ArraySize(positions);
   Log("INFO", StringFormat("TP USD: Bat dau dong %d lenh + xoa pending (Async)...", total));
   
   g_last_close_reason = CR_TACTICAL;
   int async_sent = 0;
   int pending_deleted = 0;
   int failed = 0;

   trade.SetAsyncMode(true);
   
   // BƯỚC 1: XÓA TẤT CẢ PENDING ORDERS TRƯỚC (bịt vòi - chặn lệnh mới khớp)
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
      {
         if(trade.OrderDelete(ticket))
            pending_deleted++;
      }
   }
   
   // BƯỚC 2: ĐÓNG TẤT CẢ POSITIONS (tát nước - chốt lợi nhuận)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            g_last_close_reason = CR_TACTICAL;
            AddTacticalClose(ticket);
            if(trade.PositionClose(ticket))
               async_sent++;
            else
            {
               Log("ERROR", StringFormat("Async: Loi dong lenh #%I64u. Loi: %d", ticket, trade.ResultRetcode()));
               failed++;
            }
         }
      }
   }
   
   trade.SetAsyncMode(false);
   Log("INFO", StringFormat("TP USD HOAN TAT: Xoa %d pending, gui dong %d positions (Async). Loi=%d.", pending_deleted, async_sent, failed));
}

//+------------------------------------------------------------------+
//| LƯU NGÂN SÁCH VÀO GLOBAL VARIABLES                                |
//+------------------------------------------------------------------+
void SaveBudget()
{
   string suffix = _Symbol + "_" + IntegerToString(inp_magic_number);
   
   if(!GlobalVariableSet(PREFIX_BUDGET + "SafeDay_" + suffix, g_safe_day))     Log("ERROR", "Khong the luu SafeDay");
   if(!GlobalVariableSet(PREFIX_BUDGET + "BudgetDay_" + suffix, g_budget_day)) Log("ERROR", "Khong the luu BudgetDay");
   if(!GlobalVariableSet(PREFIX_BUDGET + "SafeWeek_" + suffix, g_safe_week))   Log("ERROR", "Khong the luu SafeWeek");
   if(!GlobalVariableSet(PREFIX_BUDGET + "BudgetWeek_" + suffix, g_budget_week)) Log("ERROR", "Khong the luu BudgetWeek");
   
   if(!GlobalVariableSet(PREFIX_BUDGET + "TrimmedDay_" + suffix, g_trimmed_day)) Log("ERROR", "Khong the luu TrimmedDay");
   if(!GlobalVariableSet(PREFIX_BUDGET + "TrimmedWeek_" + suffix, g_trimmed_week)) Log("ERROR", "Khong the luu TrimmedWeek");
   
   // Luu quy TP USD
   if(!GlobalVariableSet(PREFIX_BUDGET + "FundAll_" + suffix, g_fund_all)) Log("ERROR", "Khong the luu FundAll");
   
   GlobalVariableSet(PREFIX_BUDGET + "LastDay_" + suffix, (double)g_last_known_day);
   GlobalVariableSet(PREFIX_BUDGET + "LastWeek_" + suffix, (double)g_last_known_week_start);
}

//+------------------------------------------------------------------+
//| LOAD NGÂN SÁCH TỪ GLOBAL VARIABLES                                |
//+------------------------------------------------------------------+
void LoadBudget()
{
   string suffix = _Symbol + "_" + IntegerToString(inp_magic_number);
   string check_key = PREFIX_BUDGET + "BudgetDay_" + suffix;
   
   if(GlobalVariableCheck(check_key))
   {
      g_safe_day = GlobalVariableGet(PREFIX_BUDGET + "SafeDay_" + suffix);
      g_budget_day = GlobalVariableGet(PREFIX_BUDGET + "BudgetDay_" + suffix);
      g_safe_week = GlobalVariableGet(PREFIX_BUDGET + "SafeWeek_" + suffix);
      g_budget_week = GlobalVariableGet(PREFIX_BUDGET + "BudgetWeek_" + suffix);
      g_trimmed_day = GlobalVariableGet(PREFIX_BUDGET + "TrimmedDay_" + suffix);
      g_trimmed_week = GlobalVariableGet(PREFIX_BUDGET + "TrimmedWeek_" + suffix);
      
      // Load quy TP USD
      if(GlobalVariableCheck(PREFIX_BUDGET + "FundAll_" + suffix))
          g_fund_all = GlobalVariableGet(PREFIX_BUDGET + "FundAll_" + suffix);
      else
          g_fund_all = 0.0;
       
      if(GlobalVariableCheck(PREFIX_BUDGET + "LastDay_" + suffix))
          g_last_known_day = (datetime)GlobalVariableGet(PREFIX_BUDGET + "LastDay_" + suffix);
      else
          g_last_known_day = GetStartOfDay();
          
      if(GlobalVariableCheck(PREFIX_BUDGET + "LastWeek_" + suffix))
          g_last_known_week_start = (datetime)GlobalVariableGet(PREFIX_BUDGET + "LastWeek_" + suffix);
      else
          g_last_known_week_start = GetFinancialWeekStart();

      Log("INFO", "Da khoi phuc Ngan sach tu F3.");
   }
   else
   {
      g_last_known_day = GetStartOfDay();
      g_last_known_week_start = GetFinancialWeekStart();
      Log("INFO", "Khong tim thay du lieu Ngan sach cu tren F3. Su dung gia tri mac dinh (0).");
   }
}


//+------------------------------------------------------------------+
//| QUẢN LÝ RÚT TIỀN TRONG TESTER                                    |
//+------------------------------------------------------------------+
void ManageTesterWithdrawal()
{
   if(!MQLInfoInteger(MQL_TESTER)) return;
   if(!inp_tester_withdrawal_enabled) return;

   while(true)
   {
       double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
       double excess_balance = current_balance - inp_tester_base_balance;
       if(excess_balance < inp_tester_withdraw_threshold) break;

       double amount_to_withdraw = inp_tester_withdraw_amount;
       if(amount_to_withdraw <= 0 || amount_to_withdraw > excess_balance)
           amount_to_withdraw = excess_balance;

       Log("INFO", StringFormat("TESTER WITHDRAWAL: Balance=%.2f, Excess=%.2f. Rut %.2f...", 
           current_balance, excess_balance, amount_to_withdraw));

       if(TesterWithdrawal(amount_to_withdraw))
       {
           Log("INFO", StringFormat(">>> RUT THANH CONG %.2f. Balance: %.2f -> %.2f <<<", 
               amount_to_withdraw, current_balance, AccountInfoDouble(ACCOUNT_BALANCE)));
       }
       else
       {
           Log("ERROR", "TESTER WITHDRAWAL: Rut that bai.");
           break;
       }
       if(amount_to_withdraw >= excess_balance) break;
   }
}
