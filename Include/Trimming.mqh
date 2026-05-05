//+------------------------------------------------------------------+
//| Wrapper for PositionClose to support Limit Replacements          |
//+------------------------------------------------------------------+
bool MyPositionClose(ulong ticket)
{
    if(trade.PositionClose(ticket))
    {
        return true;
    }
    return false;
}

bool MyPositionClosePartial(ulong ticket, double volume)
{
    return trade.PositionClosePartial(ticket, volume);
}

//+------------------------------------------------------------------+
//|                                                     Trimming.mqh |
//|                                                 Yoogi Yin Yang   |
//|          --- CHI GIU LAI LOGIC TIA LENH KHAN CAP ---              |
//+------------------------------------------------------------------+

// --- Khai bao ham ---
double AttemptEmergencyTrim(string period_type, double budget, const PositionInfo &positions[]);

// Tinh khoang cach pip tu gia mo lenh den gia hien tai
// Tra ve so duong neu lenh dang lo (gia di nguoc)
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
//| HAM QUAN LY TIA LENH KHAN CAP THEO DRAWDOWN                      |
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
//| HAM THUC THI TIA LENH KHAN CAP (DONG LENH LO NHAT)               |
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
   double max_pip_distance = 0;
   for(int i=0; i < ArraySize(positions); i++) {
       if(positions[i].type == side_to_trim) {
           if(positions[i].profit_swap < 0) {
               // KHONG DUOC PHEP chon Initial lam muc tieu tia
               if(StringFind(positions[i].comment, "Initial") != -1) continue;
               
               double pip_dist = GetPipDistanceFromEntry(positions[i]);
               if(pip_dist > max_pip_distance) {
                   max_pip_distance = pip_dist;
                   patient_ticket = positions[i].ticket;
                   patient_loss = positions[i].profit_swap;
                   patient_volume = positions[i].volume;
               }
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
       if(MyPositionClose(patient_ticket)) 
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
           if(MyPositionClosePartial(patient_ticket, volume_to_close)) 
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
        // KHONG DUOC PHEP chon Initial lam muc tieu tia
        if(StringFind(positions[i].comment, "Initial") != -1) continue;
        
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
                if(MyPositionClose(positions[i].ticket))
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
                if(MyPositionClose(positions[i].ticket))
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
                if(MyPositionClose(positions[i].ticket))
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
                        if(MyPositionClosePartial(positions[i].ticket, volume_to_close))
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
