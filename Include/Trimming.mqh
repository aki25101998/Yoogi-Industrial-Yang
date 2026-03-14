//+------------------------------------------------------------------+
//|                                                     Trimming.mqh |
//|                                                 Yoogi Yin Yang   |
//|             --- TEP CHUA TOAN BO LOGIC TIA LENH ---               |
//|      (Phien ban 41.0 - Them Rescue Fund + Partial Close)          |
//+------------------------------------------------------------------+

// --- Khai bao ham ---

double AttemptEmergencyTrim(string period_type, double budget, const PositionInfo &positions[]);
bool AttemptTrimDcaDuong(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptTrimInitial(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptTrimDcaAm(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptRescueTrimDcaDuong(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptRescueTrimInitial(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptRescueTrimDcaAm(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool HasLossOfType(ENUM_POSITION_TYPE p_type, string comment_type, const PositionInfo &positions[]);
double GetPipDistanceFromEntry(const PositionInfo &pos);

// <<< DA XOA: Ham LogOnce khong con duoc su dung >>>

//+------------------------------------------------------------------+
//| Tinh khoang cach pip tu gia mo lenh den gia hien tai              |
//| Tra ve so duong neu lenh dang lo (gia di nguoc)                   |
//+------------------------------------------------------------------+
double GetPipDistanceFromEntry(const PositionInfo &pos)
{
   double current_price;
   double pip_distance;
   if(pos.type == POSITION_TYPE_BUY)
   {
      current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      pip_distance = (pos.open_price - current_price) / _Point;
   }
   else // SELL
   {
      current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      pip_distance = (current_price - pos.open_price) / _Point;
   }
   return PointsToPips(pip_distance);
}

//+------------------------------------------------------------------+
//| Kiem tra co lenh lo cua loai cu the hay khong                    |
//| Neu comment_type = "" thi kiem tra bat ky lenh lo nao            |
//+------------------------------------------------------------------+
bool HasLossOfType(ENUM_POSITION_TYPE p_type, string comment_type, const PositionInfo &positions[])
{
   for(int i = 0; i < ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && positions[i].profit_swap < 0)
      {
         // Neu comment_type rong -> bat ky lenh lo nao cung OK
         if(comment_type == "" || StringFind(positions[i].comment, comment_type) != -1)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Lay quy cuu tro (Rescue Fund)                                    |
//+------------------------------------------------------------------+
void GetRescueFund(
   ulong patient_ticket,
   ENUM_POSITION_TYPE fund_source_type,
   const PositionInfo &all_positions[], 
   TradeOrder &fund_array[]
)
{
   ArrayResize(fund_array, 0);
   for(int i = 0; i < ArraySize(all_positions); i++)
   {
      if(all_positions[i].ticket == patient_ticket) continue;
      
      if(all_positions[i].type == fund_source_type && all_positions[i].profit_swap > 0)
      {
         int last = ArraySize(fund_array);
         ArrayResize(fund_array, last + 1);
         fund_array[last].ticket = all_positions[i].ticket;
         fund_array[last].profit = all_positions[i].profit_swap;
         fund_array[last].open_time = all_positions[i].open_time; 
      }
   }
   // Sap xep cac lenh trong quy theo loi nhuan giam dan
   int n = ArraySize(fund_array);
   for(int i = 0; i < n - 1; i++){for(int j = 0; j < n - i - 1; j++){if(fund_array[j].profit < fund_array[j+1].profit){TradeOrder temp=fund_array[j];fund_array[j]=fund_array[j+1];fund_array[j+1]=temp;}}}
}


//+------------------------------------------------------------------+
//| HAM TIA LENH THONG MINH (CUNG CHIEU) - THEO QUY                  |
//| <<< Them logic tia MOT PHAN (partial close) khi quy khong du >>> |
//+------------------------------------------------------------------+
bool AttemptSmartTrim(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Kiem tra dieu kien kich hoat
   if(!inp_use_trimming) return false;
   
   if(inp_trim_trigger_mode == TRIM_BY_COUNT)
   {
      int position_count = 0;
      for(int i=0; i<ArraySize(positions); i++)
      {
         if(positions[i].type == p_type) position_count++;
      }
      if(position_count < inp_trim_trigger_level) return false;
   }
   // BY_DISTANCE: khong can kiem tra so lenh, chi can co lenh du xa

   // Buoc 2: Tim lenh lo xa nhat (oldest losing position)
   ulong patient_ticket = 0;
   double patient_profit = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';

   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && positions[i].profit_swap < 0)
      {
         // BY_DISTANCE: chi xet lenh da di xa >= X pip
         if(inp_trim_trigger_mode == TRIM_BY_DISTANCE)
         {
            if(GetPipDistanceFromEntry(positions[i]) < inp_trim_pip_distance) continue;
         }
         if(positions[i].open_time < oldest_time)
         {
            oldest_time = positions[i].open_time;
            patient_ticket = positions[i].ticket;
            patient_profit = positions[i].profit_swap;
            patient_volume = positions[i].volume;
         }
      }
   }
   
   if(patient_ticket == 0 || patient_profit >= 0)
   {
      return false; // Khong co lenh lo
   }
   
   double patient_loss_amount = -patient_profit; // So duong

   // Buoc 3: Tinh tien can thiet
   double needed = patient_loss_amount + inp_trim_target_profit;
   
   // Buoc 4: Kiem tra quy (CROSS_SIDE: dung quy doi dien)
   double current_fund;
   if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_sell : g_fund_trim_buy;
   else
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
   if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia TOAN PHAN
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
          AddTacticalClose(patient_ticket);
         if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
         }
         else
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
         }
         string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
            ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
            ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
         Log("INFO", StringFormat(">>> TIA QUY: Dong TOAN PHAN lenh #%I64u (lo %.2f). Da dung quy %s. <<<", 
             patient_ticket, patient_loss_amount, fund_name));
         SaveBudget();
         return true;
      }
      else
      {
         Log("ERROR", StringFormat("TIA QUY: Loi dong lenh #%I64u. Ma loi: %d", 
             patient_ticket, trade.ResultRetcode()));
         return false;
      }
   }
   
   // --- Quy khong du toan phan -> thu tia MOT PHAN ---
   {
      double volume_to_close = NormalizeLot(patient_volume * (inp_trim_close_percentage / 100.0));
      if(volume_to_close >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) && volume_to_close < patient_volume)
      {
         double partial_loss = patient_loss_amount * (volume_to_close / patient_volume);
         double needed_partial = partial_loss + inp_trim_target_profit;
         
         if(current_fund >= needed_partial)
         {
            g_last_close_reason = CR_TACTICAL;
            if(trade.PositionClosePartial(patient_ticket, volume_to_close))
            {
               AddTacticalClose(patient_ticket);
               if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
               }
               else
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
               }
               string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
                  ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
                  ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
               Log("INFO", StringFormat(">>> TIA QUY: Dong MOT PHAN (%.2f lot) lenh #%I64u. Da dung quy %s. <<<", 
                   volume_to_close, patient_ticket, fund_name));
               SaveBudget();
               return true;
            }
            else
            {
               Log("ERROR", StringFormat("TIA QUY: Loi dong mot phan lenh #%I64u. Ma loi: %d", 
                   patient_ticket, trade.ResultRetcode()));
               return false;
            }
         }
      }
   }
   
   return false; // Quy chua du, cho tich luy them
}

// <<< HAM AttemptCrossTrim DA DUOC XOA THEO YEU CAU >>>

// <<< TOAN BO HAM DUOI DAY DA DUOC THAY THE >>>
//+------------------------------------------------------------------+
//| HAM QUAN LY TIA LENH KHAN CAP (DA SUA LOI SPAM LOG)               |
//+------------------------------------------------------------------+
void ManageEmergencyTrimming(const PositionInfo &positions[])
{
    // Gia dinh trang thai ban dau la khong co gi
    E_EMERGENCY_MODE determined_mode = EM_NONE;
    double total_drawdown = 0; // Khai bao o day de dung duoc trong khoi log

    if(inp_emergency_trim_mode != ETM_DRAWDOWN || g_budget_week < 0)
    {
        g_current_emergency_mode = EM_NONE; // Dam bao reset trang thai neu tat tinh nang
    }
    else
    {
        for(int i=0; i < ArraySize(positions); i++) { total_drawdown += positions[i].profit_swap; }

        if(total_drawdown < 0)
        {
            double abs_loss = -total_drawdown;
            const double SAFE_MARGIN = 1.0;
            datetime end_of_financial_week = GetFinancialWeekEnd();
            bool is_within_trading_week = (end_of_financial_week == 0 || TimeCurrent() < end_of_financial_week);

            // Uu tien kiem tra che do TUAN truoc
            if(abs_loss >= inp_emergency_dd2_amount && inp_emergency_dd2_amount > 0 && is_within_trading_week)
            {
                determined_mode = EM_WEEK;
                if(g_budget_week > SAFE_MARGIN)
                {
                    AttemptEmergencyTrim("TUAN", g_budget_week, positions);
                }
            }
            // Neu khong phai che do TUAN, kiem tra che do NGAY
            else if(abs_loss >= inp_emergency_dd1_amount && inp_emergency_dd1_amount > 0)
            {
                determined_mode = EM_DAY;
                if(g_budget_day > SAFE_MARGIN)
                {
                    AttemptEmergencyTrim("NGAY", g_budget_day, positions);
                }
            }
        }
    }
    
    g_current_emergency_mode = determined_mode;

    // --- LOGIC CHAN SPAM MOI: Chi ghi log khi trang thai thay doi ---
    if(g_current_emergency_mode != g_previous_emergency_mode)
    {
        switch(g_current_emergency_mode)
        {
            case EM_WEEK:
                Log("WARNING", StringFormat("--- TRANG THAI KHAN CAP [TUAN] KICH HOAT (DD %.2f >= %.2f) ---", -total_drawdown, inp_emergency_dd2_amount));
                break;

            case EM_DAY:
                Log("WARNING", StringFormat("--- TRANG THAI KHAN CAP [NGAY] KICH HOAT (DD %.2f >= %.2f) ---", -total_drawdown, inp_emergency_dd1_amount));
                 break;

            case EM_NONE:
                 if(g_previous_emergency_mode != EM_NONE) // Chi log khi vua thoat khoi trang thai khan cap
                 {
                    Log("INFO", "--- TRANG THAI KHAN CAP DA KET THUC ---");
                 }
                 break;
        }
        
        // Cap nhat "tri nho" sau khi da xu ly
        g_previous_emergency_mode = g_current_emergency_mode;
    }
}


//+------------------------------------------------------------------+
//| HAM THUC THI TIA LENH KHAN CAP (DA CAP NHAT)                      |
//+------------------------------------------------------------------+
double AttemptEmergencyTrim(string period_type, double budget, const PositionInfo &positions[]) 
{ 
   double buy_loss = 0; 
   double sell_loss = 0; 
   for(int i=0; i < ArraySize(positions); i++) 
   { 
       if(positions[i].profit_swap < 0) 
       { 
           if(positions[i].type == POSITION_TYPE_BUY) buy_loss += positions[i].profit_swap; 
           else sell_loss += positions[i].profit_swap; 
       } 
   } 
   ENUM_POSITION_TYPE side_to_trim = (buy_loss < sell_loss) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL; 

   ulong patient_ticket = 0;
   double patient_loss = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';
   for(int i=0; i < ArraySize(positions); i++) {
       if(positions[i].type == side_to_trim) {
           if(positions[i].open_time < oldest_time && positions[i].profit_swap < 0) {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_loss = positions[i].profit_swap;
               patient_volume = positions[i].volume;
           }
       }
   }

   if(patient_ticket == 0) 
   {
       return 0.0;
   }

   double patient_loss_amount = -patient_loss;
   g_last_close_reason = CR_EMERGENCY;

   if(budget >= patient_loss_amount) 
   { 
       if(trade.PositionClose(patient_ticket)) 
       { 
           AddEmergencyClose(patient_ticket);
           Log("INFO", "Tia KC thanh cong, da dong lenh #" + (string)patient_ticket + "."); 
           return patient_loss_amount;
       }
       else
       {
           Log("ERROR", "Tia KC: Loi khi dong toan phan lenh #" + (string)patient_ticket + ". Ma loi server: " + (string)trade.ResultRetcode());
           return 0.0;
       }
   } 
   else 
   {
       double min_volume_to_close = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
       double loss_from_min_action = patient_loss_amount * (min_volume_to_close / patient_volume);

       if (budget < loss_from_min_action)
       {
           return 0.0;
       }

       double percentage_to_close = budget / patient_loss_amount; 
       double volume_to_close = FloorLot(patient_volume * percentage_to_close); 
       
       if(volume_to_close >= min_volume_to_close) 
       { 
           double actual_loss_to_cover = patient_loss_amount * (volume_to_close / patient_volume);
           if(trade.PositionClosePartial(patient_ticket, volume_to_close)) 
           { 
               AddEmergencyClose(patient_ticket);
               Log("INFO", "Tia KC mot phan thanh cong cho lenh #" + (string)patient_ticket + ".");
               return actual_loss_to_cover;
           }
           else
            {
                Log("ERROR", "Tia KC: Loi khi dong mot phan lenh #" + (string)patient_ticket + ". Ma loi server: " + (string)trade.ResultRetcode());
                return 0.0;
            }
        }
    }
   
    return 0.0;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| HAM TIA LENH KHAN CAP THEO PIP                                   |
//+------------------------------------------------------------------+
void ManagePipBasedEmergencyTrim(const PositionInfo &positions[])
{
    // Kiem tra xem che do PIP co duoc bat khong
    if(inp_emergency_trim_mode != ETM_PIP)
    {
        return;
    }
    
    const double SAFE_MARGIN = 1.0;
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Duyet tung lenh de kiem tra khoang cach pip
    for(int i = 0; i < ArraySize(positions); i++)
    {
        double pip_distance = 0;
        
        // Tinh khoang cach pip lo (chi pip am moi can tia)
        if(positions[i].type == POSITION_TYPE_BUY)
        {
            // BUY lo khi gia di xuong: open_price - current_bid
            pip_distance = (positions[i].open_price - current_bid) / _Point;
        }
        else // SELL
        {
            // SELL lo khi gia di len: current_ask - open_price  
            pip_distance = (current_ask - positions[i].open_price) / _Point;
        }
        
        double pip_loss = PointsToPips(pip_distance);
        
        // DEBUG: Log gia tri pip de kiem tra tinh toan
        if(positions[i].profit_swap < 0)
        {
            Log("INFO", StringFormat("DEBUG PIP KC: #%I64u %s | open=%.5f | pip_loss=%.1f | threshold=%.1f | _Digits=%d | _Point=%.5f | profit=%.2f", 
                positions[i].ticket, 
                (positions[i].type == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                positions[i].open_price, pip_loss, inp_pip_emergency_threshold,
                _Digits, _Point, positions[i].profit_swap));
        }
        
        // Chi xu ly neu lenh dang lo >= nguong pip
        if(pip_loss >= inp_pip_emergency_threshold && positions[i].profit_swap < 0)
        {
            double patient_loss_amount = -positions[i].profit_swap;
            
            Log("WARNING", StringFormat("Tia PIP KC: Lenh #%I64u lo %.1f pip (>= %.1f). Dang tia...", 
                positions[i].ticket, pip_loss, inp_pip_emergency_threshold));
            
            g_last_close_reason = CR_EMERGENCY;
            
            
            // --- CHE DO TIA CUNG: Dong ngay khong can budget ---
            if(inp_pip_trim_style == PIP_TRIM_HARD)
            {
                if(trade.PositionClose(positions[i].ticket))
                {
                    AddEmergencyClose(positions[i].ticket);
                    Log("INFO", StringFormat("TIA CUNG PIP: Da dong lenh #%I64u (lo %.1f pip). Khong can budget.", positions[i].ticket, pip_loss));
                }
                else
                {
                    Log("ERROR", StringFormat("TIA CUNG PIP: Loi dong lenh #%I64u. Ma loi: %d", positions[i].ticket, trade.ResultRetcode()));
                }
                return; // Chi tia 1 lenh moi tick
            }
            // Uu tien dung budget ngay truoc
            if(g_budget_day > SAFE_MARGIN && g_budget_day >= patient_loss_amount)
            {
                if(trade.PositionClose(positions[i].ticket))
                {
                    AddEmergencyClose(positions[i].ticket);
                    Log("INFO", StringFormat("Tia PIP KC: Dong toan bo lenh #%I64u bang Budget NGAY.", positions[i].ticket));
                }
                else
                {
                    Log("ERROR", StringFormat("Tia PIP KC: Loi dong lenh #%I64u. Ma loi: %d", positions[i].ticket, trade.ResultRetcode()));
                }
                return; // Chi tia 1 lenh moi tick
            }
            // Neu budget ngay khong du, dung budget tuan
            else if(g_budget_week > SAFE_MARGIN && g_budget_week >= patient_loss_amount)
            {
                if(trade.PositionClose(positions[i].ticket))
                {
                    AddEmergencyClose(positions[i].ticket);
                    Log("INFO", StringFormat("Tia PIP KC: Dong toan bo lenh #%I64u bang Budget TUAN.", positions[i].ticket));
                }
                else
                {
                    Log("ERROR", StringFormat("Tia PIP KC: Loi dong lenh #%I64u. Ma loi: %d", positions[i].ticket, trade.ResultRetcode()));
                }
                return; // Chi tia 1 lenh moi tick
            }
            // Neu ca 2 budget deu khong du, thi tia mot phan
            else
            {
                double available_budget = MathMax(g_budget_day, g_budget_week);
                if(available_budget > SAFE_MARGIN)
                {
                    double percentage_to_close = available_budget / patient_loss_amount;
                    double volume_to_close = FloorLot(positions[i].volume * percentage_to_close);
                    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                    
                    if(volume_to_close >= min_volume)
                    {
                        string budget_type = (g_budget_day >= g_budget_week) ? "NGAY" : "TUAN";
                        if(trade.PositionClosePartial(positions[i].ticket, volume_to_close))
                        {
                            AddEmergencyClose(positions[i].ticket);
                            Log("INFO", StringFormat("Tia PIP KC: Dong mot phan (%.2f lot) lenh #%I64u bang Budget %s.", 
                                volume_to_close, positions[i].ticket, budget_type));
                        }
                        else
                        {
                            Log("ERROR", StringFormat("Tia PIP KC: Loi dong mot phan lenh #%I64u. Ma loi: %d", 
                                positions[i].ticket, trade.ResultRetcode()));
                        }
                        return; // Chi tia 1 lenh moi tick
                    }
                }
                
                Log("WARNING", StringFormat("Tia PIP KC: Khong du budget de tia lenh #%I64u (Can: %.2f, Co: Day=%.2f, Week=%.2f)", 
                    positions[i].ticket, patient_loss_amount, g_budget_day, g_budget_week));
            }
        }
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| HAM TIA DCA DUONG (UU TIEN 1) - THEO QUY                         |
//| <<< Them partial close khi quy khong du toan phan >>>            |
//+------------------------------------------------------------------+
bool AttemptTrimDcaDuong(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Tim lenh DCA DUONG bi lo cu nhat
   ulong patient_ticket = 0;
   double patient_profit = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';
   
   int dca_duong_count = 0;
   int dca_duong_loss_count = 0;
   
   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && StringFind(positions[i].comment, "DCA DUONG") != -1)
      {
         dca_duong_count++;
         if(positions[i].profit_swap < 0)
         {
            // BY_DISTANCE: chi xet lenh da di xa >= X pip
            if(inp_trim_trigger_mode == TRIM_BY_DISTANCE)
            {
               if(GetPipDistanceFromEntry(positions[i]) < inp_trim_pip_distance) continue;
            }
            dca_duong_loss_count++;
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
               patient_volume = positions[i].volume;
            }
         }
      }
   }
   
   // Neu khong co DCA DUONG nao bi lo -> return false
   if(patient_ticket == 0)
   {
      return false;
   }
   
   double patient_loss_amount = -patient_profit;
   
   // Buoc 2: Tinh tien can thiet
   double needed = patient_loss_amount + inp_trim_target_profit;
   
   // Buoc 3: Kiem tra quy (CROSS_SIDE: dung quy doi dien)
   double current_fund;
   if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_sell : g_fund_trim_buy;
   else
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
   if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia TOAN PHAN
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         AddTacticalClose(patient_ticket);
         if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
         }
         else
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
         }
         string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
            ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
            ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
         Log("INFO", StringFormat("TIA DCA DUONG QUY: Dong TOAN PHAN lenh #%I64u (lo %.2f). RESET Quy %s ve 0.", 
             patient_ticket, patient_loss_amount, fund_name));
         SaveBudget();
         return true;
      }
      else
      {
         Log("ERROR", StringFormat("TIA DCA DUONG QUY: Loi dong lenh #%I64u. Ma loi: %d", 
             patient_ticket, trade.ResultRetcode()));
         return false;
      }
   }
   
   // --- Quy khong du toan phan -> thu tia MOT PHAN ---
   {
      double volume_to_close = NormalizeLot(patient_volume * (inp_trim_close_percentage / 100.0));
      if(volume_to_close >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) && volume_to_close < patient_volume)
      {
         double partial_loss = patient_loss_amount * (volume_to_close / patient_volume);
         double needed_partial = partial_loss + inp_trim_target_profit;
         
         if(current_fund >= needed_partial)
         {
            g_last_close_reason = CR_TACTICAL;
            if(trade.PositionClosePartial(patient_ticket, volume_to_close))
            {
               AddTacticalClose(patient_ticket);
               if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
               }
               else
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
               }
               string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
                  ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
                  ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
               Log("INFO", StringFormat("TIA DCA DUONG QUY: Dong MOT PHAN (%.2f lot) lenh #%I64u. RESET Quy %s ve 0.", 
                   volume_to_close, patient_ticket, fund_name));
               SaveBudget();
               return true;
            }
            else
            {
               Log("ERROR", StringFormat("TIA DCA DUONG QUY: Loi dong mot phan lenh #%I64u. Ma loi: %d", 
                   patient_ticket, trade.ResultRetcode()));
               return false;
            }
         }
      }
   }
   
   return false; // Quy chua du, cho tich luy them
}

//+------------------------------------------------------------------+
//| HAM TIA INITIAL (UU TIEN 2) - THEO QUY                           |
//| <<< Them partial close khi quy khong du toan phan >>>            |
//+------------------------------------------------------------------+
bool AttemptTrimInitial(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Tim lenh Initial bi lo cu nhat
   ulong patient_ticket = 0;
   double patient_profit = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';
   
   int initial_count = 0;
   int initial_loss_count = 0;
   
   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && StringFind(positions[i].comment, "Initial") != -1)
      {
         initial_count++;
         if(positions[i].profit_swap < 0)
         {
            // BY_DISTANCE: chi xet lenh da di xa >= X pip
            if(inp_trim_trigger_mode == TRIM_BY_DISTANCE)
            {
               if(GetPipDistanceFromEntry(positions[i]) < inp_trim_pip_distance) continue;
            }
            initial_loss_count++;
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
               patient_volume = positions[i].volume;
            }
         }
      }
   }
   
   // Neu khong co Initial nao bi lo -> return false
   if(patient_ticket == 0)
   {
      return false;
   }
   
   double patient_loss_amount = -patient_profit;
   
   // Buoc 2: Tinh tien can thiet
   double needed = patient_loss_amount + inp_trim_target_profit;
   
   // Buoc 3: Kiem tra quy (CROSS_SIDE: dung quy doi dien)
   double current_fund;
   if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_sell : g_fund_trim_buy;
   else
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
   if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia TOAN PHAN
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         AddTacticalClose(patient_ticket);
         if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
         }
         else
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
         }
         string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
            ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
            ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
         Log("INFO", StringFormat("TIA INITIAL QUY: Dong TOAN PHAN lenh #%I64u (lo %.2f). RESET Quy %s ve 0.", 
             patient_ticket, patient_loss_amount, fund_name));
         SaveBudget();
         return true;
      }
      else
      {
         Log("ERROR", StringFormat("TIA INITIAL QUY: Loi dong lenh #%I64u. Ma loi: %d", 
             patient_ticket, trade.ResultRetcode()));
         return false;
      }
   }
   
   // --- Quy khong du toan phan -> thu tia MOT PHAN ---
   {
      double volume_to_close = NormalizeLot(patient_volume * (inp_trim_close_percentage / 100.0));
      if(volume_to_close >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) && volume_to_close < patient_volume)
      {
         double partial_loss = patient_loss_amount * (volume_to_close / patient_volume);
         double needed_partial = partial_loss + inp_trim_target_profit;
         
         if(current_fund >= needed_partial)
         {
            g_last_close_reason = CR_TACTICAL;
            if(trade.PositionClosePartial(patient_ticket, volume_to_close))
            {
               AddTacticalClose(patient_ticket);
               if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
               }
               else
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
               }
               string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
                  ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
                  ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
               Log("INFO", StringFormat("TIA INITIAL QUY: Dong MOT PHAN (%.2f lot) lenh #%I64u. RESET Quy %s ve 0.", 
                   volume_to_close, patient_ticket, fund_name));
               SaveBudget();
               return true;
            }
            else
            {
               Log("ERROR", StringFormat("TIA INITIAL QUY: Loi dong mot phan lenh #%I64u. Ma loi: %d", 
                   patient_ticket, trade.ResultRetcode()));
               return false;
            }
         }
      }
   }
   
   return false; // Quy chua du, cho tich luy them
}

//+------------------------------------------------------------------+
//| HAM TIA DCA AM (UU TIEN 3) - THEO QUY                            |
//| <<< Them partial close khi quy khong du toan phan >>>            |
//+------------------------------------------------------------------+
bool AttemptTrimDcaAm(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Tim lenh DCA AM bi lo cu nhat
   ulong patient_ticket = 0;
   double patient_profit = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';
   
   int dca_am_count = 0;
   int dca_am_loss_count = 0;
   
   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && StringFind(positions[i].comment, "DCA AM") != -1)
      {
         dca_am_count++;
         if(positions[i].profit_swap < 0)
         {
            // BY_DISTANCE: chi xet lenh da di xa >= X pip
            if(inp_trim_trigger_mode == TRIM_BY_DISTANCE)
            {
               if(GetPipDistanceFromEntry(positions[i]) < inp_trim_pip_distance) continue;
            }
            dca_am_loss_count++;
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
               patient_volume = positions[i].volume;
            }
         }
      }
   }
   
   // Neu khong co DCA AM nao bi lo -> return false
   if(patient_ticket == 0)
   {
      return false;
   }
   
   double patient_loss_amount = -patient_profit;
   
   // Buoc 2: Tinh tien can thiet
   double needed = patient_loss_amount + inp_trim_target_profit;
   
   // Buoc 3: Kiem tra quy (CROSS_SIDE: dung quy doi dien)
   double current_fund;
   if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_sell : g_fund_trim_buy;
   else
      current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
   if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia TOAN PHAN
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         AddTacticalClose(patient_ticket);
         if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
         }
         else
         {
            if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
         }
         string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
            ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
            ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
         Log("INFO", StringFormat("TIA DCA AM QUY: Dong TOAN PHAN lenh #%I64u (lo %.2f). RESET Quy %s ve 0.", 
             patient_ticket, patient_loss_amount, fund_name));
         SaveBudget();
         return true;
      }
      else
      {
         Log("ERROR", StringFormat("TIA DCA AM QUY: Loi dong lenh #%I64u. Ma loi: %d", 
             patient_ticket, trade.ResultRetcode()));
         return false;
      }
   }
   
   // --- Quy khong du toan phan -> thu tia MOT PHAN ---
   {
      double volume_to_close = NormalizeLot(patient_volume * (inp_trim_close_percentage / 100.0));
      if(volume_to_close >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) && volume_to_close < patient_volume)
      {
         double partial_loss = patient_loss_amount * (volume_to_close / patient_volume);
         double needed_partial = partial_loss + inp_trim_target_profit;
         
         if(current_fund >= needed_partial)
         {
            g_last_close_reason = CR_TACTICAL;
            if(trade.PositionClosePartial(patient_ticket, volume_to_close))
            {
               AddTacticalClose(patient_ticket);
               if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_sell = 0; else g_fund_trim_buy = 0;
               }
               else
               {
                  if(p_type == POSITION_TYPE_BUY) g_fund_trim_buy = 0; else g_fund_trim_sell = 0;
               }
               string fund_name = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
                  ((p_type == POSITION_TYPE_BUY) ? "SELL(cheo)" : "BUY(cheo)") :
                  ((p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL");
               Log("INFO", StringFormat("TIA DCA AM QUY: Dong MOT PHAN (%.2f lot) lenh #%I64u. RESET Quy %s ve 0.", 
                   volume_to_close, patient_ticket, fund_name));
               SaveBudget();
               return true;
            }
            else
            {
               Log("ERROR", StringFormat("TIA DCA AM QUY: Loi dong mot phan lenh #%I64u. Ma loi: %d", 
                   patient_ticket, trade.ResultRetcode()));
               return false;
            }
         }
      }
   }
   
   return false; // Quy chua du, cho tich luy them
}


//+------------------------------------------------------------------+
//|              CÁC HÀM RESCUE FUND (TỈA TRỰC TIẾP)                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| HAM RESCUE FUND CHUNG - Logic chia se cho 3 ham uu tien          |
//| Tim patient theo comment_filter, dong rescue fund + patient      |
//+------------------------------------------------------------------+
bool ExecuteRescueTrim(
   ENUM_POSITION_TYPE p_type, 
   string comment_filter,
   string log_prefix,
   const PositionInfo &positions[]
)
{
   // Buoc 1: Tim lenh lo cu nhat theo loai comment
   ulong patient_ticket = 0;
   double patient_profit = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';

   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && StringFind(positions[i].comment, comment_filter) != -1)
      {
         if(positions[i].profit_swap < 0)
         {
            // BY_DISTANCE: chi xet lenh da di xa >= X pip
            if(inp_trim_trigger_mode == TRIM_BY_DISTANCE)
            {
               if(GetPipDistanceFromEntry(positions[i]) < inp_trim_pip_distance) continue;
            }
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
               patient_volume = positions[i].volume;
            }
         }
      }
   }
   
   if(patient_ticket == 0) return false;
   
   double patient_loss_amount = -patient_profit;

   // Buoc 2: Tim rescue fund (lenh lai cung phe hoac nguoc phe)
   ENUM_POSITION_TYPE fund_source_type;
   if(inp_trim_mode == TRIM_MODE_CROSS_SIDE)
      fund_source_type = (p_type == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   else
      fund_source_type = p_type;

   TradeOrder rescue_fund[];
   GetRescueFund(patient_ticket, fund_source_type, positions, rescue_fund);
   if(ArraySize(rescue_fund) == 0) return false;

   double available_profit = 0;
   for(int i = 0; i < ArraySize(rescue_fund); i++)
   {
      available_profit += rescue_fund[i].profit;
   }

   // Buoc 3: Thu tia TOAN PHAN
   double required_for_full = patient_loss_amount + inp_trim_target_profit;
   if(available_profit >= required_for_full)
   {
      string fund_side = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
         PositionTypeToString(fund_source_type) + "(cheo)" : PositionTypeToString(fund_source_type);
      Log("INFO", StringFormat("%s RESCUE: Quy (%.2f) tu %s DU. Bat dau TIA TOAN PHAN cho lenh #%I64u...", 
          log_prefix, available_profit, fund_side, patient_ticket));
      
      double needed_profit = required_for_full;
      double collected_profit = 0;
      
      g_last_close_reason = CR_TACTICAL;

      for(int i = 0; i < ArraySize(rescue_fund); i++)
      {
         if(trade.PositionClose(rescue_fund[i].ticket))
         {
            AddTacticalClose(rescue_fund[i].ticket);
            collected_profit += rescue_fund[i].profit;
         }
         if(collected_profit >= needed_profit) break;
      }

      if(trade.PositionClose(patient_ticket))
      {
         AddTacticalClose(patient_ticket);
         Log("INFO", StringFormat("%s RESCUE: Tia TOAN PHAN thanh cong cho lenh #%I64u!", log_prefix, patient_ticket));
      }
      return true;
   }

   // Buoc 4: Thu tia MOT PHAN
   double volume_to_close = NormalizeLot(patient_volume * (inp_trim_close_percentage / 100.0));
   if(volume_to_close < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) || volume_to_close >= patient_volume)
   {
      return false;
   }
   double partial_loss_amount = patient_loss_amount * (volume_to_close / patient_volume);
   double required_for_partial = partial_loss_amount + inp_trim_target_profit;

   if(available_profit >= required_for_partial)
   {
      string fund_side = (inp_trim_mode == TRIM_MODE_CROSS_SIDE) ? 
         PositionTypeToString(fund_source_type) + "(cheo)" : PositionTypeToString(fund_source_type);
      Log("INFO", StringFormat("%s RESCUE: Quy (%.2f) tu %s KHONG DU toan phan. Bat dau TIA MOT PHAN cho lenh #%I64u...", 
          log_prefix, available_profit, fund_side, patient_ticket));
      
      double needed_profit = required_for_partial;
      double collected_profit = 0;

      g_last_close_reason = CR_TACTICAL;

      for(int i = 0; i < ArraySize(rescue_fund); i++)
      {
         if(trade.PositionClose(rescue_fund[i].ticket))
         {
            AddTacticalClose(rescue_fund[i].ticket);
            collected_profit += rescue_fund[i].profit;
         }
         if(collected_profit >= needed_profit) break;
      }

      if(trade.PositionClosePartial(patient_ticket, volume_to_close))
      {
         AddTacticalClose(patient_ticket);
         Log("INFO", StringFormat("%s RESCUE: Tia MOT PHAN (%.2f lot) thanh cong cho lenh #%I64u!", log_prefix, volume_to_close, patient_ticket));
      }
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| RESCUE FUND: TIA DCA DUONG (UU TIEN 1)                           |
//+------------------------------------------------------------------+
bool AttemptRescueTrimDcaDuong(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   return ExecuteRescueTrim(p_type, "DCA DUONG", "DCA_DUONG", positions);
}

//+------------------------------------------------------------------+
//| RESCUE FUND: TIA INITIAL (UU TIEN 2)                              |
//+------------------------------------------------------------------+
bool AttemptRescueTrimInitial(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   return ExecuteRescueTrim(p_type, "Initial", "INITIAL", positions);
}

//+------------------------------------------------------------------+
//| RESCUE FUND: TIA DCA AM (UU TIEN 3)                               |
//+------------------------------------------------------------------+
bool AttemptRescueTrimDcaAm(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   return ExecuteRescueTrim(p_type, "DCA AM", "DCA_AM", positions);
}

