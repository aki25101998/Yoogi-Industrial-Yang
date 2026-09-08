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

   if(!g_sideway_lock && inp_enable_pending_mode) RefillStopOrdersIfNeeded(POSITION_TYPE_BUY, hp);
   
   double ca = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double dist_points = (double)PipToPoints(g_current_dca_duong_distance) * _Point;
   bool tp_removed = false;
   
   // Multi-level catch-up: mở TẤT CẢ mức DCA bị miss trong 1 tick
   double current_hp = hp;
   
   if(!g_sideway_lock)
   {
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
}

//+------------------------------------------------------------------+
//| QUẢN LÝ LỆNH SELL — DUAL MODE (Market-First + Pending-as-Backup) |
//+------------------------------------------------------------------+
void ManageSellPositions(const PositionInfo &positions[], int total_sell_pos, double total_buy_profit, double total_sell_profit, double hp, double lp)
{
   if(!inp_enable_sell || total_sell_pos == 0) return;
   if(!inp_enable_dca_duong) return;

   if(!g_sideway_lock && inp_enable_pending_mode) RefillStopOrdersIfNeeded(POSITION_TYPE_SELL, lp);
   
   double cb = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist_points = (double)PipToPoints(g_current_dca_duong_distance) * _Point;
   bool tp_removed = false;
   
   // Multi-level catch-up: mở TẤT CẢ mức DCA bị miss trong 1 tick
   double current_lp = lp;
   
   if(!g_sideway_lock)
   {
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

   // --- Xử lý mở lệnh Initial BUY ---
   if(!g_sideway_lock && inp_enable_buy && total_buy_pos == 0)
   {
       if(inp_withdrawal_mode)
       {
          Log("INFO", "Che do Rut tien: Da chan mo lenh Initial Buy moi.");
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
   if(!g_sideway_lock && inp_enable_sell && total_sell_pos == 0)
   {
       if(inp_withdrawal_mode)
       {
          Log("INFO", "Che do Rut tien: Da chan mo lenh Initial Sell moi.");
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
   
   // Luu quy TP USD
   if(!GlobalVariableSet(PREFIX_BUDGET + "FundAll_" + suffix, g_fund_all)) Log("ERROR", "Khong the luu FundAll");
}

//+------------------------------------------------------------------+
//| LOAD NGÂN SÁCH TỪ GLOBAL VARIABLES                                |
//+------------------------------------------------------------------+
void LoadBudget()
{
   string suffix = _Symbol + "_" + IntegerToString(inp_magic_number);
   string check_key = PREFIX_BUDGET + "FundAll_" + suffix;
   
   if(GlobalVariableCheck(check_key))
   {
      // Load quy TP USD
      g_fund_all = GlobalVariableGet(PREFIX_BUDGET + "FundAll_" + suffix);
      Log("INFO", "Da khoi phuc Ngan sach tu F3.");
   }
   else
   {
      g_fund_all = 0.0;
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
