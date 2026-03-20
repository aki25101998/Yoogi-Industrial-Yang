//+------------------------------------------------------------------+
//|                                                  CoreLogic.mqh |
//|                             --- T?P CH?A LOGIC GIAO D?CH C?T LOI ---   |
//|                 (Phin b?n 41.3 - Fix Syntax Error Switch-Case) |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| KI?M TRA XEM L?NH CAN B?NG LOT CO DU?C PHP TRONG VUNG GIA KHONG   |
//+------------------------------------------------------------------+
bool IsBalanceOrderAllowedInZone(ENUM_POSITION_TYPE trade_type, const PositionInfo &positions[])
{
   // N?u tnh nang b? t?t, lun cho php
   if(!inp_balance_zone_enabled || inp_balance_zone_max_orders <= 0)
   {
      return true;
   }

   // --- Bu?c 1: Tm l?nh cn b?ng ("DCA DUONG") g?n nh?t c?a cng phe ---
   datetime last_order_time = 0;
   double last_order_price = 0;

   for(int i = 0; i < ArraySize(positions); i++)
   {
      if(positions[i].type == trade_type && StringFind(positions[i].comment, "DCA DUONG") != -1)
      {
         if(positions[i].open_time > last_order_time)
         {
            last_order_time = positions[i].open_time;
            last_order_price = positions[i].open_price;
         }
      }
   }

   // N?u khng c l?nh cn b?ng no tru?c d, cho php m? l?nh d?u tin
   if(last_order_time == 0)
   {
      return true;
   }

   // --- Bu?c 2: Xc d?nh vng gi v d?m s? l?nh trong vng ---
   double zone_radius_in_points = (double)PipToPoints(inp_balance_zone_pips);
   double zone_upper_bound = last_order_price + zone_radius_in_points * _Point;
   double zone_lower_bound = last_order_price - zone_radius_in_points * _Point;

   int orders_in_zone = 0;
   for(int i = 0; i < ArraySize(positions); i++)
   {
      if(positions[i].type == trade_type && StringFind(positions[i].comment, "DCA DUONG") != -1)
      {
         if(positions[i].open_price >= zone_lower_bound && positions[i].open_price <= zone_upper_bound)
         {
            orders_in_zone++;
         }
      }
   }

   // --- Bu?c 3: Ki?m tra xem c vu?t qu gi?i h?n khng ---
   if(orders_in_zone >= inp_balance_zone_max_orders)
   {
      Log("INFO", StringFormat("Channel DCA DUONG (%s): Vung gia nay da co %d lenh. Gioi han la %d. BO QUA.", 
          EnumToString(trade_type), orders_in_zone, inp_balance_zone_max_orders));
      return false; // Ch?n l?nh
   }

   return true; // Cho php
}



//+------------------------------------------------------------------+
//| TNH TOAN LOT CHO L?NH TI?P THEO (Dynamic Base Lot)              |
//+------------------------------------------------------------------+
// Logics: Base lot s? tang len n?u nhu:
// 1. Lot hien tai qua nho so voi von (Risk qu th?p) -> Tang an ton
// 2. Hoac co the giu nguyen. O phien ban nay ta giu nguyen logic
//    la Base Lot = inp_initial_lots (Co dinh).
//    Nhung tuong lai co the Update ? day.
void UpdateDynamicBaseLot(const PositionInfo &positions[])
{
   g_current_base_lot_buy = inp_lot_dca_duong;
   g_current_base_lot_sell = inp_lot_dca_duong;
   g_current_dca_duong_distance = inp_dca_duong_distance_pips;

   // Co the them logic tu dong tang lot neu so du lon
}


//+------------------------------------------------------------------+
//| QU?N LY CAN B?NG LOT (LOT BALANCING / HEDGING)                   |
//+------------------------------------------------------------------+
void ManageLotBalancing(double total_buy_lots, double total_sell_lots, double current_drawdown, const PositionInfo &positions[])
{
   // Ki?m tra di?u ki?n kch ho?t: DD ph?i d? l?n
   if(!inp_enable_lot_balancing) return; // Tinh nang can bang lot bi tat
   if(inp_balance_activation_dd > 0 && current_drawdown > -inp_balance_activation_dd) return; // DD chua du am (luu y DD la so am)
   if(inp_lot_balance_threshold <= 0) return; // T?t tnh nang

   // --- K?ch b?n 1: Phe BUY dang n?ng hon phe SELL ---
   double diff_buy_vs_sell = total_buy_lots - total_sell_lots;
   if(diff_buy_vs_sell > inp_lot_balance_threshold)
   {
      // Phe Buy n?ng hon -> Can m? thm DCA DUONG cho phe SELL d? cn
      if(inp_enable_sell && inp_enable_dca_duong)
      {
         if(g_is_sell_locked)
         {
            Log("INFO", "Can Bang Lot (SELL) bi chan do phe Sell dang bi khoa DD.");
            return;
         }

         if(!IsBalanceOrderAllowedInZone(POSITION_TYPE_SELL, positions))
         {
            return; // B? ch?n b?i gi?i h?n vng gi
         }

         Log("INFO", StringFormat("Can bang Lot (SELL): Tong lot Buy (%.2f) > Tong lot Sell (%.2f). Mo lenh DCA Duong cho SELL.", total_buy_lots, total_sell_lots));
         if(!trade.Sell(g_current_base_lot_sell, _Symbol, 0, 0, 0, "DCA DUONG"))
         {
            Log("ERROR", StringFormat("Loi mo lenh Can Bang Lot SELL. Ma loi: %d", (int)trade.ResultRetcode()));
         }
         return;
      }
   }

   // --- K?ch b?n 2: Phe SELL dang n?ng hon phe BUY ---
   double diff_sell_vs_buy = total_sell_lots - total_buy_lots;
   if(diff_sell_vs_buy > inp_lot_balance_threshold)
   {
      if(inp_enable_buy && inp_enable_dca_duong)
      {
         if(g_is_buy_locked)
         {
            Log("INFO", "Can Bang Lot (BUY) bi chan do phe Buy dang bi khoa DD.");
            return;
         }

         if(!IsBalanceOrderAllowedInZone(POSITION_TYPE_BUY, positions))
         {
            return; // B? ch?n b?i gi?i h?n vng gi
         }

         Log("INFO", StringFormat("Can bang Lot (BUY): Tong lot Sell (%.2f) > Tong lot Buy (%.2f). Mo lenh DCA Duong cho BUY.", total_sell_lots, total_buy_lots));
         if(!trade.Buy(g_current_base_lot_buy, _Symbol, 0, 0, 0, "DCA DUONG"))
         {
            Log("ERROR", StringFormat("Loi mo lenh Can Bang Lot BUY. Ma loi: %d", (int)trade.ResultRetcode()));
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| QU?N LY TRAILING STOP T?NG L?NH (FIXED 10011 NORMALIZE)          |
//+------------------------------------------------------------------+
void ManageTrailingStops(const PositionInfo &positions[], int total_buy_positions, int total_sell_positions)
{
   if(inp_enable_individual_trailing && inp_individual_trailing_start_pips > 0 && inp_individual_trailing_dist_pips > 0)
   {
      double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Kho?ng cch t?i thi?u
      double min_step_points = 10 * _Point; 

      for(int i = 0; i < ArraySize(positions); i++)
      {
         if(!inp_trailing_dca_am_as_dca_duong && StringFind(positions[i].comment, "DCA AM") != -1) continue;
         
         double open_price = positions[i].open_price;
         
         if(positions[i].type == POSITION_TYPE_BUY)
         {
            if((bid_price - open_price) / _Point >= PipToPoints(inp_individual_trailing_start_pips))
            {
               double raw_sl = bid_price - (double)PipToPoints(inp_individual_trailing_dist_pips) * _Point;
               double new_sl = NormalizeDouble(raw_sl, _Digits);
               
               if(PositionSelectByTicket(positions[i].ticket))
               {
                  double current_sl = PositionGetDouble(POSITION_SL);
                  
                  if(new_sl > open_price && new_sl > (current_sl + min_step_points))
                  {
                     if(!trade.PositionModify(positions[i].ticket, new_sl, PositionGetDouble(POSITION_TP)))
                     {
                        Log("ERROR", StringFormat("Trailing Lo Buy that bai #%I64u. SL Moi: %f. Err: %d", positions[i].ticket, new_sl, trade.ResultRetcode()));
                     }
                  }
               }
            }
         }
         else // SELL
         {
            if((open_price - ask_price) / _Point >= PipToPoints(inp_individual_trailing_start_pips))
            {
               double raw_sl = ask_price + (double)PipToPoints(inp_individual_trailing_dist_pips) * _Point;
               double new_sl = NormalizeDouble(raw_sl, _Digits);
               
               if(PositionSelectByTicket(positions[i].ticket))
               {
                  double current_sl = PositionGetDouble(POSITION_SL);
                  
                  if(new_sl < open_price && (current_sl == 0 || new_sl < (current_sl - min_step_points)))
                  {
                     if(!trade.PositionModify(positions[i].ticket, new_sl, PositionGetDouble(POSITION_TP)))
                     {
                        Log("ERROR", StringFormat("Trailing Lo Sell that bai #%I64u. SL Moi: %f. Err: %d", positions[i].ticket, new_sl, trade.ResultRetcode()));
                     }
                  }
               }
            }
         }
      }
   }
}

void ManageBuyPositions(const PositionInfo &positions[], int total_buy_pos, int pure_dca_am_buy_pos, double total_buy_profit, double total_sell_profit)
{
   if(g_is_buy_locked) return;

   if(!inp_enable_buy || total_buy_pos == 0) return;

   double hp=0,lp=999999;
   for(int i = 0; i < ArraySize(positions); i++){
      if(positions[i].type == POSITION_TYPE_BUY) {
         if(positions[i].open_price > hp) hp = positions[i].open_price;
         if(positions[i].open_price < lp) lp = positions[i].open_price;
      }
   }
   double ca=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   bool ad=ca>=(hp+(double)PipToPoints(g_current_dca_duong_distance)*_Point);
   double dca_am_distance_pips = inp_trailing_dca_am_as_dca_duong ? inp_dca_duong_distance_pips : GetDistancePips_ForDCA_Am(pure_dca_am_buy_pos+1);
   bool aa=ca<=(lp-(double)PipToPoints(dca_am_distance_pips)*_Point);

   if((ad||aa) && total_buy_pos==1){
       if(inp_initial_tp_pips>0){
           double t=PositionGetDouble(POSITION_TP);
           if(t>0)trade.PositionModify(positions[0].ticket,0,0);
       }
   }

   if(inp_enable_dca_duong && ad)
   {
      // <<< CHA CHAN DCA DUONG KHI BI SOFT-LOCK BOI EMA >>>
      if(g_is_buy_locked_by_ema) return; 

      if(!IsBalanceOrderAllowedInZone(POSITION_TYPE_BUY, positions)) return;
      if(!trade.Buy(g_current_base_lot_buy,_Symbol,0,0,0,"DCA DUONG")) Log("ERROR",StringFormat("Loi mo lenh DCA DUONG BUY. Ma loi: %d", (int)trade.ResultRetcode()));
   }

   if(inp_enable_dca_am && aa)
   {
      // --- KIỂM TRA ĐIỀU KIỆN DCA ÂM KHI LỖ ÍT HƠN ---
      if(inp_dca_am_less_drawdown_only)
      {
         // Kiểm tra nếu Buy lỗ NHIỀU HƠN Sell thì KHÓA
         if(total_buy_profit < total_sell_profit)
         {
            Log("DEBUG", StringFormat("DCA AM BUY bi khoa do phe Buy (%.2f) lo nhieu hon phe Sell (%.2f).", total_buy_profit, total_sell_profit));
            return;
         }
      }

      // Logic bổ sung DCA Am
      int next_level = pure_dca_am_buy_pos + 1;
      double next_lot = GetLotSize_ForDCA_Am(next_level, g_current_base_lot_buy);

      // DEBUG LOG - Xem giá trị đếm và lot
      Log("DEBUG", StringFormat("DCA AM BUY: pure_dca_am_buy_pos=%d, next_level=%d, next_lot=%.2f, group=%d", 
          pure_dca_am_buy_pos, next_level, next_lot, GetGroupIndex(next_level)));

      // Kiem tra nhom de reset trailing
      int group_idx = GetGroupIndex(next_level);
      if(group_idx != g_last_buy_dca_am_group_index) {
          // Reset Trailing here if Needed (Logic hien tai khong can reset vi trailing tinh theo pips)
          g_last_buy_dca_am_group_index = group_idx;
          Log("INFO",StringFormat("Chuyen sang DCA Am Nhom %d (Buy).", group_idx));
      }
      
      if(!trade.Buy(next_lot,_Symbol,0,0,0,"DCA AM")) Log("ERROR",StringFormat("Loi mo lenh DCA Am BUY. Lot du tinh: %.2f. Ma loi: %d", next_lot, (int)trade.ResultRetcode()));
   }
}

void ManageSellPositions(const PositionInfo &positions[], int total_sell_pos, int pure_dca_am_sell_pos, double total_buy_profit, double total_sell_profit)
{
   if(g_is_sell_locked) return;
   
   if(!inp_enable_sell || total_sell_pos == 0) return;

   double hp=0,lp=999999;
   for(int i = 0; i < ArraySize(positions); i++){
      if(positions[i].type == POSITION_TYPE_SELL) {
         if(positions[i].open_price > hp) hp = positions[i].open_price;
         if(positions[i].open_price < lp) lp = positions[i].open_price;
      }
   }
   double cb=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   bool ad=cb<=(lp-(double)PipToPoints(g_current_dca_duong_distance)*_Point);
   double dca_am_distance_pips = inp_trailing_dca_am_as_dca_duong ? inp_dca_duong_distance_pips : GetDistancePips_ForDCA_Am(pure_dca_am_sell_pos+1);
   bool aa=cb>=(hp+(double)PipToPoints(dca_am_distance_pips)*_Point);
   
   if((ad||aa) && total_sell_pos==1){
       if(inp_initial_tp_pips>0){
           double t=PositionGetDouble(POSITION_TP);
           if(t>0)trade.PositionModify(positions[0].ticket,0,0);
       }
   }

   if(inp_enable_dca_duong && ad)
   {
      // <<< CHA CHAN DCA DUONG KHI BI SOFT-LOCK BOI EMA >>>
      if(g_is_sell_locked_by_ema) return;

      if(!IsBalanceOrderAllowedInZone(POSITION_TYPE_SELL, positions)) return;
      if(!trade.Sell(g_current_base_lot_sell,_Symbol,0,0,0,"DCA DUONG")) Log("ERROR",StringFormat("Loi mo lenh DCA DUONG SELL. Ma loi: %d", (int)trade.ResultRetcode()));
   }
   
   if(inp_enable_dca_am && aa)
   {
      // --- KIỂM TRA ĐIỀU KIỆN DCA ÂM KHI LỖ ÍT HƠN ---
      if(inp_dca_am_less_drawdown_only)
      {
         // Kiểm tra nếu Sell lỗ NHIỀU HƠN Buy thì KHÓA
         if(total_sell_profit < total_buy_profit)
         {
            Log("DEBUG", StringFormat("DCA AM SELL bi khoa do phe Sell (%.2f) lo nhieu hon phe Buy (%.2f).", total_sell_profit, total_buy_profit));
            return;
         }
      }

      int next_level = pure_dca_am_sell_pos + 1;
      double next_lot = GetLotSize_ForDCA_Am(next_level, g_current_base_lot_sell);

      // DEBUG LOG - Xem giá trị đếm và lot
      Log("DEBUG", StringFormat("DCA AM SELL: pure_dca_am_sell_pos=%d, next_level=%d, next_lot=%.2f, group=%d", 
          pure_dca_am_sell_pos, next_level, next_lot, GetGroupIndex(next_level)));

      int group_idx = GetGroupIndex(next_level);
      if(group_idx != g_last_sell_dca_am_group_index) {
          g_last_sell_dca_am_group_index = group_idx;
          Log("INFO",StringFormat("Chuyen sang DCA Am Nhom %d (Sell).", group_idx));
      }

      if(!trade.Sell(next_lot,_Symbol,0,0,0,"DCA AM")) Log("ERROR",StringFormat("Loi mo lenh DCA Am SELL. Lot du tinh: %.2f. Ma loi: %d", next_lot, (int)trade.ResultRetcode()));
   }
}

void CheckAndOpenInitialTrades(int total_buy_pos, int total_sell_pos)
{
   // --- Xu ly mo lenh Initial BUY ---
   if(inp_enable_buy && total_buy_pos == 0 && !g_is_buy_locked)
   {
      if(inp_withdrawal_mode)
      {
         Log("INFO", "Che do Rut tien: Da chan mo lenh Initial Buy moi.");
      }
      else
      {
         g_last_buy_dca_am_group_index = -1;
         Log("INFO","--- CHU TRINH BUY MOI ---");
         double t=0;
         if(inp_initial_tp_pips>0){t=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+(double)PipToPoints(inp_initial_tp_pips)*_Point;}
         if(!trade.Buy(g_current_base_lot_buy,_Symbol,0.0,0.0,t,"Initial Buy")) Log("ERROR",StringFormat("Loi mo lenh BUY ban dau. Ma loi: %d",(int)trade.ResultRetcode()));
      }
   }

   // --- Xu ly mo lenh Initial SELL ---
   if(inp_enable_sell && total_sell_pos == 0 && !g_is_sell_locked)
   {
      if(inp_withdrawal_mode)
      {
         Log("INFO", "Che do Rut tien: Da chan mo lenh Initial Sell moi.");
      }
      else
      {
         g_last_sell_dca_am_group_index = -1;
         Log("INFO","--- CHU TRINH SELL MOI ---");
         double t=0;
         if(inp_initial_tp_pips>0){t=SymbolInfoDouble(_Symbol,SYMBOL_BID)-(double)PipToPoints(inp_initial_tp_pips)*_Point;}
         if(!trade.Sell(g_current_base_lot_sell,_Symbol,0.0,0.0,t,"Initial Sell")) Log("ERROR",StringFormat("Loi mo lenh SELL ban dau. Ma loi: %d",(int)trade.ResultRetcode()));
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER: Xác định lệnh thuộc nhóm nào dựa trên level              |
//| Level 1 = lệnh DCA AM đầu tiên (theo thời gian mở)               |
//+------------------------------------------------------------------+
int GetGroupForLevel(int level)
{
   // Tra bảng nhóm dựa trên level
   if(inp_level_nhom_20 > 0 && level >= inp_level_nhom_20) return 20;
   if(inp_level_nhom_19 > 0 && level >= inp_level_nhom_19) return 19;
   if(inp_level_nhom_18 > 0 && level >= inp_level_nhom_18) return 18;
   if(inp_level_nhom_17 > 0 && level >= inp_level_nhom_17) return 17;
   if(inp_level_nhom_16 > 0 && level >= inp_level_nhom_16) return 16;
   if(inp_level_nhom_15 > 0 && level >= inp_level_nhom_15) return 15;
   if(inp_level_nhom_14 > 0 && level >= inp_level_nhom_14) return 14;
   if(inp_level_nhom_13 > 0 && level >= inp_level_nhom_13) return 13;
   if(inp_level_nhom_12 > 0 && level >= inp_level_nhom_12) return 12;
   if(inp_level_nhom_11 > 0 && level >= inp_level_nhom_11) return 11;
   if(inp_level_nhom_10 > 0 && level >= inp_level_nhom_10) return 10;
   if(inp_level_nhom_9 > 0 && level >= inp_level_nhom_9) return 9;
   if(inp_level_nhom_8 > 0 && level >= inp_level_nhom_8) return 8;
   if(inp_level_nhom_7 > 0 && level >= inp_level_nhom_7) return 7;
   if(inp_level_nhom_6 > 0 && level >= inp_level_nhom_6) return 6;
   if(inp_level_nhom_5 > 0 && level >= inp_level_nhom_5) return 5;
   if(inp_level_nhom_4 > 0 && level >= inp_level_nhom_4) return 4;
   if(inp_level_nhom_3 > 0 && level >= inp_level_nhom_3) return 3;
   if(inp_level_nhom_2 > 0 && level >= inp_level_nhom_2) return 2;
   return 1; // Mặc định nhóm 1
}

//+------------------------------------------------------------------+
//| QUẢN LÝ TRAILING STOP THEO TỪNG NHÓM DCA ÂM ĐỘC LẬP              |
//| Mỗi nhóm có break-even riêng và SL trailing riêng                |
//+------------------------------------------------------------------+
void ExecuteDcaAmGroupTrailing(const PositionInfo &positions[], ENUM_POSITION_TYPE type)
{
   if(!inp_enable_group_trailing || inp_group_trailing_start_pips <= 0 || inp_group_trailing_dist_pips <= 0) return;
   if(inp_trailing_dca_am_as_dca_duong) return; // Khoa Trailing Group khi dung Trailing don (lenh giong DCA Duong)

   // Bước 1: Thu thập tất cả lệnh DCA AM + Initial và sắp xếp theo thời gian
   ulong tickets[];
   datetime open_times[];
   double volumes[];
   double prices[];
   int count = 0;
   
   for(int i = 0; i < ArraySize(positions); i++) {
      if(positions[i].type == type && 
         (StringFind(positions[i].comment, "DCA AM") != -1 || StringFind(positions[i].comment, "Initial") != -1)) {
         ArrayResize(tickets, count + 1);
         ArrayResize(open_times, count + 1);
         ArrayResize(volumes, count + 1);
         ArrayResize(prices, count + 1);
         tickets[count] = positions[i].ticket;
         open_times[count] = positions[i].open_time;
         volumes[count] = positions[i].volume;
         prices[count] = positions[i].open_price;
         count++;
      }
   }
   
   if(count == 0) return;
   
   // Bước 2: Sắp xếp theo thời gian mở (oldest first) để xác định level
   for(int i = 0; i < count - 1; i++) {
      for(int j = i + 1; j < count; j++) {
         if(open_times[j] < open_times[i]) {
            // Swap
            ulong tmp_ticket = tickets[i]; tickets[i] = tickets[j]; tickets[j] = tmp_ticket;
            datetime tmp_time = open_times[i]; open_times[i] = open_times[j]; open_times[j] = tmp_time;
            double tmp_vol = volumes[i]; volumes[i] = volumes[j]; volumes[j] = tmp_vol;
            double tmp_price = prices[i]; prices[i] = prices[j]; prices[j] = tmp_price;
         }
      }
   }
   
   // Bước 3: Xác định các nhóm có lệnh và tính break-even cho từng nhóm
   // group_data[group_id] = {volume_sum, cost_sum, ticket_list}
   double group_volume[21], group_cost[21];
   int group_ticket_count[21];
   ArrayInitialize(group_volume, 0);
   ArrayInitialize(group_cost, 0);
   ArrayInitialize(group_ticket_count, 0);
   
   // Mảng lưu ticket thuộc từng nhóm
   ulong group_tickets[21][100]; // max 100 tickets per group
   
   for(int i = 0; i < count; i++) {
      int level = i + 1; // Level 1 = lệnh đầu tiên
      int group = GetGroupForLevel(level);
      
      group_volume[group] += volumes[i];
      group_cost[group] += prices[i] * volumes[i];
      group_tickets[group][group_ticket_count[group]] = tickets[i];
      group_ticket_count[group]++;
   }
   
   // Bước 4: Trailing từng nhóm độc lập
   double min_step_points = 10 * _Point;
   double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   for(int g = 1; g <= 20; g++) {
      if(group_ticket_count[g] == 0) continue; // Nhóm này không có lệnh
      
      double break_even = group_cost[g] / group_volume[g];
      double profit_pips = 0;
      double new_sl = 0;
      bool should_trail = false;
      
      if(type == POSITION_TYPE_BUY) {
         profit_pips = (current_price - break_even) / _Point;
         if(profit_pips >= PipToPoints(inp_group_trailing_start_pips)) {
            new_sl = NormalizeDouble(current_price - PipToPoints(inp_group_trailing_dist_pips) * _Point, _Digits);
            if(new_sl > break_even) should_trail = true;
         }
      }
      else { // SELL
         profit_pips = (break_even - current_price) / _Point;
         if(profit_pips >= PipToPoints(inp_group_trailing_start_pips)) {
            new_sl = NormalizeDouble(current_price + PipToPoints(inp_group_trailing_dist_pips) * _Point, _Digits);
            if(new_sl < break_even) should_trail = true;
         }
      }
      
      if(should_trail) {
         for(int t = 0; t < group_ticket_count[g]; t++) {
            if(PositionSelectByTicket(group_tickets[g][t])) {
               double current_sl = PositionGetDouble(POSITION_SL);
               bool need_update = false;
               
               if(type == POSITION_TYPE_BUY) {
                  if(new_sl > (current_sl + min_step_points)) need_update = true;
               }
               else {
                  if(current_sl == 0 || new_sl < (current_sl - min_step_points)) need_update = true;
               }
               
               if(need_update) {
                  if(!trade.PositionModify(group_tickets[g][t], new_sl, 0)) {
                     Log("ERROR", StringFormat("Trailing Nhom %d %s that bai #%I64u. Err: %d", 
                         g, (type == POSITION_TYPE_BUY) ? "BUY" : "SELL", group_tickets[g][t], trade.ResultRetcode()));
                  }
                  else {
                     Log("INFO", StringFormat(">>> TRAILING NHOM %d %s: #%I64u SL=%.5f (BE=%.5f, Profit=%.0f pips) <<<", 
                         g, (type == POSITION_TYPE_BUY) ? "BUY" : "SELL", group_tickets[g][t], new_sl, break_even, profit_pips));
                  }
               }
            }
         }
      }
   }
}

// <<< HAM NAY DA DU?C S?A L?I CU PHAP SWITCH-CASE >>>
// <<< CẬP NHẬT: Thêm tham số position_type và comment để tích luỹ quỹ >>>
void UpdateAccountingOnDeal(double deal_profit, ENUM_DEAL_TYPE deal_type = DEAL_TYPE_BUY, string deal_comment = "")
{
   if(deal_profit == 0) return;
   
   // --- LOGIC QUỸ ALL MỚI ---
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
      
      // <<< TÍCH LŨY QUỸ TỈA LỆNH >>>
      // Chỉ cộng vào quỹ khi lệnh có lời và KHÔNG phải lệnh đóng do trimming/emergency
      if(g_last_close_reason != CR_TACTICAL && g_last_close_reason != CR_EMERGENCY)
      {
         // Tích luỹ từ DCA AM, Initial, và DCA DUONG
         bool is_dca_am = (StringFind(deal_comment, "DCA AM") != -1);
         bool is_initial = (StringFind(deal_comment, "Initial") != -1);
         bool is_dca_duong = (StringFind(deal_comment, "DCA DUONG") != -1);
         
         if(is_dca_am || is_initial || is_dca_duong)
         {
            if(inp_take_profit_usd == 0) // Chỉ chạy quỹ riêng khi TP USD đang tắt
            {
               // Xác định phe dựa trên deal_type
               if(deal_type == DEAL_TYPE_SELL) // SELL close = BUY position was closed
               {
                  g_fund_trim_buy += deal_profit;
                  Log("INFO", StringFormat(">>> QUY BUY +%.2f. Tong: %.2f <<<", deal_profit, g_fund_trim_buy));
                  SaveBudget();
               }
               else if(deal_type == DEAL_TYPE_BUY) // BUY close = SELL position was closed
               {
                  g_fund_trim_sell += deal_profit;
                  Log("INFO", StringFormat(">>> QUY SELL +%.2f. Tong: %.2f <<<", deal_profit, g_fund_trim_sell));
                  SaveBudget();
               }
            }
         }
      }
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
           {
              // Lệnh đóng do trimming - CHỈ trừ ngân sách, KHÔNG trừ quỹ tỉa
              // (Quỹ tỉa đã được reset về 0 ngay tại hàm Trim rồi)
              double loss_for_safe_day = loss_amount * (inp_emergency_profit_retention_day / 100.0);
              double loss_for_budget_day = loss_amount - loss_for_safe_day;
              g_safe_day -= loss_for_safe_day; g_budget_day -= loss_for_budget_day;
              double loss_for_safe_week = loss_amount * (inp_emergency_profit_retention_week / 100.0);
              double loss_for_budget_week = loss_amount - loss_for_safe_week;
              g_safe_week -= loss_for_safe_week; g_budget_week -= loss_for_budget_week;
              Log("INFO", StringFormat("Ke toan LO TIA LENH: -%.2f. (Khong tru quy vi da reset tai ham Trim)", loss_amount));
              break;
           }
           default:
           {
              double loss_for_safe_day = loss_amount * (inp_emergency_profit_retention_day / 100.0);
              double loss_for_budget_day = loss_amount - loss_for_safe_day;
              g_safe_day -= loss_for_safe_day; g_budget_day -= loss_for_budget_day;
              double loss_for_safe_week = loss_amount * (inp_emergency_profit_retention_week / 100.0);
              double loss_for_budget_week = loss_amount - loss_for_safe_week;
               g_safe_week -= loss_for_safe_week; g_budget_week -= loss_for_budget_week;
              
               // <<< Trừ quỹ khi DCA AM/Initial/DCA DUONG đóng lỗ do trailing (CR_UNKNOWN) >>>
               if(g_last_close_reason == CR_UNKNOWN)
               {
                  bool is_dca_am_loss = (StringFind(deal_comment, "DCA AM") != -1);
                  bool is_initial_loss = (StringFind(deal_comment, "Initial") != -1);
                  bool is_dca_duong_loss = (StringFind(deal_comment, "DCA DUONG") != -1);
                  if(is_dca_am_loss || is_initial_loss || is_dca_duong_loss)
                  {
                     if(deal_type == DEAL_TYPE_SELL)
                     {
                        g_fund_trim_buy += deal_profit; // deal_profit is negative here, so it subtracts
                        Log("INFO", StringFormat(">>> QUY BUY %.2f (lo trailing). Tong: %.2f <<<", deal_profit, g_fund_trim_buy));
                     }
                     else if(deal_type == DEAL_TYPE_BUY)
                     {
                        g_fund_trim_sell += deal_profit; // deal_profit is negative here, so it subtracts
                        Log("INFO", StringFormat(">>> QUY SELL %.2f (lo trailing). Tong: %.2f <<<", deal_profit, g_fund_trim_sell));
                     }
                     SaveBudget();
                  }
               }
              
               Log("INFO", StringFormat("Ke toan LO CHIEN THUAT: -%.2f.", loss_amount));
             break;
          }
      }
   }
   Log("INFO", StringFormat("So sach cap nhat: KSN=%.2f, NSN=%.2f | KST=%.2f, NST=%.2f", g_safe_day, g_budget_day, g_safe_week, g_budget_week));
   SaveBudget(); // <<< CAP NH?T: Luu ngay lap tuc
}

void CloseAllPositionsByEA(const PositionInfo &positions[])
{
   Log("INFO", StringFormat("TP USD: Da dat muc tieu $%.2f. Bat dau dong tat ca %d lenh...", inp_take_profit_usd, ArraySize(positions)));
   g_last_close_reason = CR_TACTICAL;
   int failed_closes = 0;
   for(int i = 0; i < ArraySize(positions); i++)
   {
      g_last_close_reason = CR_TACTICAL;
      AddTacticalClose(positions[i].ticket); // <<< FIX BUG 1 >>>
      if(!trade.PositionClose(positions[i].ticket)) {
         Log("ERROR", StringFormat("TP USD: L?i khi dng l?nh #%I64u. Ma l?i: %d", positions[i].ticket, (int)trade.ResultRetcode()));
         failed_closes++;
      }
   }
   if(failed_closes == 0) Log("INFO", "TP USD: Da dng thnh cng t?t c? cc l?nh.");
   else Log("WARNING", StringFormat("TP USD: Hon t?t, nhung c %d l?nh khng th? dng.", failed_closes));
}

// <<< CAP NH?T: Ham luu ngan sach vao Global Variables >>>
void SaveBudget()
{
   string suffix = _Symbol + "_" + IntegerToString(inp_magic_number);
   
   if(!GlobalVariableSet(PREFIX_BUDGET + "SafeDay_" + suffix, g_safe_day))     Log("ERROR", "Khong the luu SafeDay");
   if(!GlobalVariableSet(PREFIX_BUDGET + "BudgetDay_" + suffix, g_budget_day)) Log("ERROR", "Khong the luu BudgetDay");
   if(!GlobalVariableSet(PREFIX_BUDGET + "SafeWeek_" + suffix, g_safe_week))   Log("ERROR", "Khong the luu SafeWeek");
   if(!GlobalVariableSet(PREFIX_BUDGET + "BudgetWeek_" + suffix, g_budget_week)) Log("ERROR", "Khong the luu BudgetWeek");
   
   if(!GlobalVariableSet(PREFIX_BUDGET + "TrimmedDay_" + suffix, g_trimmed_day)) Log("ERROR", "Khong the luu TrimmedDay");
   if(!GlobalVariableSet(PREFIX_BUDGET + "TrimmedWeek_" + suffix, g_trimmed_week)) Log("ERROR", "Khong the luu TrimmedWeek");
   
   // Luu quy tia lenh
   if(!GlobalVariableSet(PREFIX_BUDGET + "FundBuy_" + suffix, g_fund_trim_buy)) Log("ERROR", "Khong the luu FundBuy");
   if(!GlobalVariableSet(PREFIX_BUDGET + "FundSell_" + suffix, g_fund_trim_sell)) Log("ERROR", "Khong the luu FundSell");
   if(!GlobalVariableSet(PREFIX_BUDGET + "FundAll_" + suffix, g_fund_all)) Log("ERROR", "Khong the luu FundAll");
   
   // Luu timestamp de tranh reset oan khi khoi dong lai
   GlobalVariableSet(PREFIX_BUDGET + "LastDay_" + suffix, (double)g_last_known_day);
   GlobalVariableSet(PREFIX_BUDGET + "LastWeek_" + suffix, (double)g_last_known_week_start);
   
   // Log("INFO", "Da luu ngan sach vao F3.");
}

// <<< CAP NH?T: Ham load ngan sach tu Global Variables >>>
void LoadBudget()
{
   string suffix = _Symbol + "_" + IntegerToString(inp_magic_number);
   string check_key = PREFIX_BUDGET + "BudgetDay_" + suffix;
   
   if(GlobalVariableCheck(check_key))
   {
      double old_safe_day = g_safe_day; // Debug info
      
      g_safe_day = GlobalVariableGet(PREFIX_BUDGET + "SafeDay_" + suffix);
      g_budget_day = GlobalVariableGet(PREFIX_BUDGET + "BudgetDay_" + suffix);
      g_safe_week = GlobalVariableGet(PREFIX_BUDGET + "SafeWeek_" + suffix);
      g_budget_week = GlobalVariableGet(PREFIX_BUDGET + "BudgetWeek_" + suffix);
      g_trimmed_day = GlobalVariableGet(PREFIX_BUDGET + "TrimmedDay_" + suffix);
      g_trimmed_week = GlobalVariableGet(PREFIX_BUDGET + "TrimmedWeek_" + suffix);
      
      // Load quy tia lenh
      if(GlobalVariableCheck(PREFIX_BUDGET + "FundBuy_" + suffix))
          g_fund_trim_buy = GlobalVariableGet(PREFIX_BUDGET + "FundBuy_" + suffix);
      else
          g_fund_trim_buy = 0.0;
          
      if(GlobalVariableCheck(PREFIX_BUDGET + "FundSell_" + suffix))
          g_fund_trim_sell = GlobalVariableGet(PREFIX_BUDGET + "FundSell_" + suffix);
      else
           g_fund_trim_sell = 0.0;
           
      if(GlobalVariableCheck(PREFIX_BUDGET + "FundAll_" + suffix))
          g_fund_all = GlobalVariableGet(PREFIX_BUDGET + "FundAll_" + suffix);
      else
           g_fund_all = 0.0;
       
      // Load thoi gian Last Known Day/Week neu co
      if(GlobalVariableCheck(PREFIX_BUDGET + "LastDay_" + suffix))
          g_last_known_day = (datetime)GlobalVariableGet(PREFIX_BUDGET + "LastDay_" + suffix);
      else
          g_last_known_day = GetStartOfDay(); // Neu khong co, assume la hom nay de tranh reset oan
          
      if(GlobalVariableCheck(PREFIX_BUDGET + "LastWeek_" + suffix))
          g_last_known_week_start = (datetime)GlobalVariableGet(PREFIX_BUDGET + "LastWeek_" + suffix);
      else
          g_last_known_week_start = GetFinancialWeekStart();

      Log("INFO", StringFormat("Da khoi phuc Ngan sach tu F3. Truoc: %.2f => Sau: %.2f", old_safe_day, g_safe_day));
   }
   else
   {
      // Lan dau chay hoac mat du lieu -> Set ngay hien tai de tranh reset ngay lap tuc sau do
      g_last_known_day = GetStartOfDay();
      g_last_known_week_start = GetFinancialWeekStart();
      Log("INFO", "Khong tim thay du lieu Ngan sach cu tren F3. Su dung gia tri mac dinh (0).");
   }
}


//+------------------------------------------------------------------+
//| XU LY DONG LENH KHI XU HUONG DAO CHIEU (EMA CROSS)               |
//| (DA XOA THEO YEU CAU)                                            |
//+------------------------------------------------------------------+
/*
void ManageTrendReversalClosing(const PositionInfo &positions[])
{
    // ... DA XOA ...
}
*/



//+------------------------------------------------------------------+
//| QUẢN LÝ RÚT TIỀN TRONG TESTER                                    |
//+------------------------------------------------------------------+
void ManageTesterWithdrawal()
{
   if(!MQLInfoInteger(MQL_TESTER)) return; // Chỉ chạy trong Tester
   if(!inp_tester_withdrawal_enabled) return;

   // Vòng lặp rút liên tục cho đến khi balance < base + threshold
   while(true)
   {
       double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
       double excess_balance = current_balance - inp_tester_base_balance;

       // Nếu phần dư chưa đạt ngưỡng → dừng
       if(excess_balance < inp_tester_withdraw_threshold) break;

       // Xác định số tiền rút mỗi lần
       // Nếu inp_tester_withdraw_amount > 0 → rút theo từng đợt
       // Nếu = 0 hoặc lớn hơn excess → rút toàn bộ phần dư
       double amount_to_withdraw = inp_tester_withdraw_amount;
       if(amount_to_withdraw <= 0 || amount_to_withdraw > excess_balance)
           amount_to_withdraw = excess_balance;

       Log("INFO", StringFormat("TESTER WITHDRAWAL: Balance=%.2f, Excess=%.2f (Nguong %.2f). Rut %.2f...", 
           current_balance, excess_balance, inp_tester_withdraw_threshold, amount_to_withdraw));

       if(TesterWithdrawal(amount_to_withdraw))
       {
           Log("INFO", StringFormat(">>> RUT THANH CONG %.2f. Balance: %.2f -> %.2f <<<", 
               amount_to_withdraw, current_balance, AccountInfoDouble(ACCOUNT_BALANCE)));
       }
       else
       {
           Log("ERROR", "TESTER WITHDRAWAL: Rut that bai. Kiem tra lai.");
           break; // Thoát vòng lặp nếu rút thất bại
       }

       // Nếu đã rút toàn bộ phần dư → thoát
       if(amount_to_withdraw >= excess_balance) break;
   }
}
