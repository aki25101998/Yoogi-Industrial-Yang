//+------------------------------------------------------------------+
//|                                                     Trimming.mqh |
//|                                                 Yoogi Yin Yang   |
//|             --- T?P CH?A TO?N B? LOGIC T?A L?NH ---               |
//|      (Phi?n b?n 40.3 - S?a l?i Spam Log & B? Log Ng?n s?ch)       |
//+------------------------------------------------------------------+

// --- Khai b?o h?m ---

double AttemptEmergencyTrim(string period_type, double budget, const PositionInfo &positions[]);
bool AttemptTrimDcaDuong(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptTrimInitial(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool AttemptTrimDcaAm(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[]);
bool HasLossOfType(ENUM_POSITION_TYPE p_type, string comment_type, const PositionInfo &positions[]);

// <<< ?? X?A: H?m LogOnce kh?ng c?n du?c s? d?ng >>>

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
//| L?y qu? c?u tr?                                                  |
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
   // S?p x?p c?c l?nh trong qu? theo l?i nhu?n gi?m d?n
   int n = ArraySize(fund_array);
   for(int i = 0; i < n - 1; i++){for(int j = 0; j < n - i - 1; j++){if(fund_array[j].profit < fund_array[j+1].profit){TradeOrder temp=fund_array[j];fund_array[j]=fund_array[j+1];fund_array[j+1]=temp;}}}
}


//+------------------------------------------------------------------+
//| H?M T?A L?NH TH?NG MINH (C?NG CHI?U) - THEO QU?                    |
//| <<< C?P NH?T: D?ng qu? t?ch lu? thay v? rescue fund >>>          |
//+------------------------------------------------------------------+
bool AttemptSmartTrim(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Bu?c 1: Ki?m tra di?u ki?n k?ch ho?t
   int position_count = 0;
   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type) position_count++;
   }

   if(!inp_use_trimming || position_count < inp_trim_trigger_level)
   {
      return false;
   }

   // Bu?c 2: T?m l?nh l? xa nh?t (oldest losing position)
   ulong patient_ticket = 0;
   double patient_profit = 0;
   double patient_volume = 0;
   datetime oldest_time = D'3000.01.01';

   for(int i=0; i<ArraySize(positions); i++)
   {
      if(positions[i].type == p_type && positions[i].profit_swap < 0)
      {
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
      return false; // Kh?ng c? l?nh l?
   }
   
   double patient_loss_amount = -patient_profit; // S? duong

   // Bu?c 3: T?nh ti?n c?n thi?t
   double needed = patient_loss_amount + inp_trim_target_profit;
   
   // Bu?c 4: Ki?m tra qu?
   double current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
      if(current_fund >= needed)
   {
      // Qu? d? -> Th?c hi?n t?a
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         // T?a th�nh c�ng - RESET qu? v? 0 
         if(p_type == POSITION_TYPE_BUY)
            g_fund_trim_buy = 0;
         else
            g_fund_trim_sell = 0;
         Log("INFO", StringFormat(">>> TIA QUY: Dong lenh #%I64u (lo %.2f). Da dung quy %s (%.2f). RESET ve 0. <<<", 
             patient_ticket, patient_loss_amount, 
             (p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL", current_fund));
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
   
      return false; // Qu? chua d?, ch? t?ch lu? th?m
}

// <<< H?M AttemptCrossTrim ?? ?U?C X?A THEO Y?U C?U >>>

// <<< TO?N B? H?M DU?I ??Y ?? ?U?C THAY TH? >>>
//+------------------------------------------------------------------+
//| H?M QU?N L? T?A L?NH KH?N C?P (?? S?A L?I SPAM LOG)               |
//+------------------------------------------------------------------+
void ManageEmergencyTrimming(const PositionInfo &positions[])
{
    // Gi? d?nh tr?ng th?i ban d?u l? kh?ng c? g?
    E_EMERGENCY_MODE determined_mode = EM_NONE;
    double total_drawdown = 0; // Khai b?o ? d?y d? d?ng du?c trong kh?i log

    if(inp_emergency_trim_mode != ETM_DRAWDOWN || g_budget_week < 0)
    {
        g_current_emergency_mode = EM_NONE; // ??m b?o reset tr?ng th?i n?u t?t t?nh nang
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

            // Uu ti?n ki?m tra ch? d? TU?N tru?c
            if(abs_loss >= inp_emergency_dd2_amount && inp_emergency_dd2_amount > 0 && is_within_trading_week)
            {
                determined_mode = EM_WEEK;
                if(g_budget_week > SAFE_MARGIN)
                {
                    AttemptEmergencyTrim("TU?N", g_budget_week, positions);
                }
            }
            // N?u kh?ng ph?i ch? d? TU?N, ki?m tra ch? d? NG?Y
            else if(abs_loss >= inp_emergency_dd1_amount && inp_emergency_dd1_amount > 0)
            {
                determined_mode = EM_DAY;
                if(g_budget_day > SAFE_MARGIN)
                {
                    AttemptEmergencyTrim("NG?Y", g_budget_day, positions);
                }
            }
        }
    }
    
    g_current_emergency_mode = determined_mode;

    // --- LOGIC CH?N SPAM M?I: Ch? ghi log khi tr?ng th?i thay d?i ---
    if(g_current_emergency_mode != g_previous_emergency_mode)
    {
        switch(g_current_emergency_mode)
        {
            case EM_WEEK:
                Log("WARNING", StringFormat("--- TR?NG TH?I KH?N C?P [TU?N] K?CH HO?T (DD %.2f >= %.2f) ---", -total_drawdown, inp_emergency_dd2_amount));
                // <<< ?? X?A: Log v? ng?n s?ch kh?ng d? >>>
                break;

            case EM_DAY:
                Log("WARNING", StringFormat("--- TR?NG TH?I KH?N C?P [NG?Y] K?CH HO?T (DD %.2f >= %.2f) ---", -total_drawdown, inp_emergency_dd1_amount));
                // <<< ?? X?A: Log v? ng?n s?ch kh?ng d? >>>
                 break;

            case EM_NONE:
                 if(g_previous_emergency_mode != EM_NONE) // Ch? log khi v?a tho?t kh?i tr?ng th?i kh?n c?p
                 {
                    Log("INFO", "--- TR?NG TH?I KH?N C?P ?? K?T TH?C ---");
                 }
                 break;
        }
        
        // C?p nh?t "tr? nh?" sau khi d? x? l?
        g_previous_emergency_mode = g_current_emergency_mode;
    }
}


//+------------------------------------------------------------------+
//| H?M TH?C THI T?A L?NH KH?N C?P (?? C?P NH?T)                      |
//+------------------------------------------------------------------+
double AttemptEmergencyTrim(string period_type, double budget, const PositionInfo &positions[]) 
{ 
   // <<< ?? X?A LogOnce ? d?y, logic log m?i d? x? l? ? h?m tr?n >>>

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
       // <<< ?? x?a LogOnce ? d?y >>>
       return 0.0;
   }

   double patient_loss_amount = -patient_loss;
   g_last_close_reason = CR_EMERGENCY;

   if(budget >= patient_loss_amount) 
   { 
       // <<< ?? x?a LogOnce ? d?y >>>
       if(trade.PositionClose(patient_ticket)) 
       { 
           Log("INFO", "T?a KC th?nh c?ng, d? d?ng l?nh #" + (string)patient_ticket + "."); 
           return patient_loss_amount;
       }
       else
       {
           Log("ERROR", "T?a KC: L?i khi d?ng to?n ph?n l?nh #" + (string)patient_ticket + ". M? l?i server: " + (string)trade.ResultRetcode());
           return 0.0;
       }
   } 
   else 
   {
       double min_volume_to_close = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
       double loss_from_min_action = patient_loss_amount * (min_volume_to_close / patient_volume);

       if (budget < loss_from_min_action)
       {
           // <<< ?? x?a LogOnce ? d?y >>>
           return 0.0;
       }

       double percentage_to_close = budget / patient_loss_amount; 
       double volume_to_close = FloorLot(patient_volume * percentage_to_close); 
       
       if(volume_to_close >= min_volume_to_close) 
       { 
           double actual_loss_to_cover = patient_loss_amount * (volume_to_close / patient_volume);
           // <<< ?? x?a LogOnce ? d?y >>>
           if(trade.PositionClosePartial(patient_ticket, volume_to_close)) 
           { 
               Log("INFO", "Tia KC mot phan thanh cong cho lenh #" + (string)patient_ticket + ".");
               return actual_loss_to_cover;
           }
           else
            {
                Log("ERROR", "T?a KC: L?i khi d?ng m?t ph?n l?nh #" + (string)patient_ticket + ". M? l?i server: " + (string)trade.ResultRetcode());
                return 0.0;
            }
        }
    }
   
    return 0.0;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| H?M T?A L?NH KH?N C?P THEO PIP                                   |
//+------------------------------------------------------------------+
void ManagePipBasedEmergencyTrim(const PositionInfo &positions[])
{
    // Ki?m tra xem ch? d? PIP c? du?c b?t kh?ng
    if(inp_emergency_trim_mode != ETM_PIP)
    {
        return;
    }
    
    const double SAFE_MARGIN = 1.0;
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Duy?t t?ng l?nh d? ki?m tra kho?ng c?ch pip
    for(int i = 0; i < ArraySize(positions); i++)
    {
        double pip_distance = 0;
        
        // T?nh kho?ng c?ch pip l? (ch? pip ?m m?i c?n t?a)
        if(positions[i].type == POSITION_TYPE_BUY)
        {
            // BUY l? khi gi? di xu?ng: open_price - current_bid
            pip_distance = (positions[i].open_price - current_bid) / _Point;
        }
        else // SELL
        {
            // SELL l? khi gi? di l?n: current_ask - open_price  
            pip_distance = (current_ask - positions[i].open_price) / _Point;
        }
        
        // Chuy?n t? points sang pips (cho 5 digits)
        double pip_loss = pip_distance / ((_Digits == 3 || _Digits == 5) ? 10 : 1);
        
        // Ch? x? l? n?u l?nh dang l? >= ngu?ng pip
        if(pip_loss >= inp_pip_emergency_threshold && positions[i].profit_swap < 0)
        {
            double patient_loss_amount = -positions[i].profit_swap;
            
            Log("WARNING", StringFormat("T?a PIP KC: L?nh #%I64u l? %.1f pip (>= %.1f). ?ang t?a...", 
                positions[i].ticket, pip_loss, inp_pip_emergency_threshold));
            
            g_last_close_reason = CR_EMERGENCY;
            
            
            // --- CHE DO TIA AM: Cat lo ngay khong can budget ---
            if(inp_allow_negative_trim)
            {
                if(trade.PositionClose(positions[i].ticket))
                {
                    Log("INFO", StringFormat("Tia AM: Da dong lenh #%I64u (lo %.1f pip). Khong can budget.", positions[i].ticket, pip_loss));
                }
                else
                {
                    Log("ERROR", StringFormat("Tia AM: Loi dong lenh #%I64u. Ma loi: %d", positions[i].ticket, trade.ResultRetcode()));
                }
                return; // Chi tia 1 lenh moi tick
            }
            // Uu ti?n d?ng budget ng?y tru?c
            if(g_budget_day > SAFE_MARGIN && g_budget_day >= patient_loss_amount)
            {
                if(trade.PositionClose(positions[i].ticket))
                {
                    Log("INFO", StringFormat("T?a PIP KC: ??ng to?n b? l?nh #%I64u b?ng Budget NG?Y.", positions[i].ticket));
                }
                else
                {
                    Log("ERROR", StringFormat("T?a PIP KC: L?i d?ng l?nh #%I64u. M? l?i: %d", positions[i].ticket, trade.ResultRetcode()));
                }
                return; // Ch? t?a 1 l?nh m?i tick
            }
            // N?u budget ng?y kh?ng d?, d?ng budget tu?n
            else if(g_budget_week > SAFE_MARGIN && g_budget_week >= patient_loss_amount)
            {
                if(trade.PositionClose(positions[i].ticket))
                {
                    Log("INFO", StringFormat("T?a PIP KC: ??ng to?n b? l?nh #%I64u b?ng Budget TU?N.", positions[i].ticket));
                }
                else
                {
                    Log("ERROR", StringFormat("T?a PIP KC: L?i d?ng l?nh #%I64u. M? l?i: %d", positions[i].ticket, trade.ResultRetcode()));
                }
                return; // Ch? t?a 1 l?nh m?i tick
            }
            // N?u c? 2 budget d?u kh?ng d?, th? t?a m?t ph?n
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
                        string budget_type = (g_budget_day >= g_budget_week) ? "NG?Y" : "TU?N";
                        if(trade.PositionClosePartial(positions[i].ticket, volume_to_close))
                        {
                            Log("INFO", StringFormat("T?a PIP KC: ??ng m?t ph?n (%.2f lot) l?nh #%I64u b?ng Budget %s.", 
                                volume_to_close, positions[i].ticket, budget_type));
                        }
                        else
                        {
                            Log("ERROR", StringFormat("T?a PIP KC: L?i d?ng m?t ph?n l?nh #%I64u. M? l?i: %d", 
                                positions[i].ticket, trade.ResultRetcode()));
                        }
                        return; // Ch? t?a 1 l?nh m?i tick
                    }
                }
                
                Log("WARNING", StringFormat("T?a PIP KC: Kh?ng d? budget d? t?a l?nh #%I64u (C?n: %.2f, C?: Day=%.2f, Week=%.2f)", 
                    positions[i].ticket, patient_loss_amount, g_budget_day, g_budget_week));
            }
        }
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| HAM TIA DCA DUONG (UU TIEN 1) - THEO QUY                         |
//| <<< C?P NH?T: D?ng qu? t?ch lu? thay v? rescue fund >>>          |
//+------------------------------------------------------------------+
bool AttemptTrimDcaDuong(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Tim lenh DCA DUONG bi lo cu nhat
   ulong patient_ticket = 0;
   double patient_profit = 0;
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
            dca_duong_loss_count++;
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
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
   
   // Buoc 3: Kiem tra quy
   double current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
      if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         // T?a th�nh c�ng - RESET qu? v? 0 
         if(p_type == POSITION_TYPE_BUY)
            g_fund_trim_buy = 0;
         else
            g_fund_trim_sell = 0;
         Log("INFO", StringFormat("TIA DCA DUONG QUY: Dong lenh #%I64u (lo %.2f). RESET Quy %s ve 0.", 
             patient_ticket, patient_loss_amount, 
             (p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL", current_fund));
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
   
      return false; // Quy chua du, cho tich luy them
}

//+------------------------------------------------------------------+
//| HAM TIA INITIAL (UU TIEN 2) - THEO QUY                           |
//| <<< C?P NH?T: D?ng qu? t?ch lu? thay v? rescue fund >>>          |
//+------------------------------------------------------------------+
bool AttemptTrimInitial(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Tim lenh Initial bi lo cu nhat
   ulong patient_ticket = 0;
   double patient_profit = 0;
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
            initial_loss_count++;
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
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
   
   // Buoc 3: Kiem tra quy
   double current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
      if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         // T?a th�nh c�ng - RESET qu? v? 0 
         if(p_type == POSITION_TYPE_BUY)
            g_fund_trim_buy = 0;
         else
            g_fund_trim_sell = 0;
         Log("INFO", StringFormat("TIA INITIAL QUY: Dong lenh #%I64u (lo %.2f). RESET Quy %s ve 0.", 
             patient_ticket, patient_loss_amount, 
             (p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL", current_fund));
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
   
      return false; // Quy chua du, cho tich luy them
}

//+------------------------------------------------------------------+
//| HAM TIA DCA AM (UU TIEN 3) - THEO QUY                            |
//| <<< C?P NH?T: D?ng qu? t?ch lu? thay v? rescue fund >>>          |
//+------------------------------------------------------------------+
bool AttemptTrimDcaAm(ENUM_POSITION_TYPE p_type, const PositionInfo &positions[])
{
   // Buoc 1: Tim lenh DCA AM bi lo cu nhat
   ulong patient_ticket = 0;
   double patient_profit = 0;
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
            dca_am_loss_count++;
            if(positions[i].open_time < oldest_time)
            {
               oldest_time = positions[i].open_time;
               patient_ticket = positions[i].ticket;
               patient_profit = positions[i].profit_swap;
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
   
   // Buoc 3: Kiem tra quy
   double current_fund = (p_type == POSITION_TYPE_BUY) ? g_fund_trim_buy : g_fund_trim_sell;
   
      if(current_fund >= needed)
   {
      // Quy du -> Thuc hien tia
      g_last_close_reason = CR_TACTICAL;
      
      if(trade.PositionClose(patient_ticket))
      {
         // T?a th�nh c�ng - RESET qu? v? 0 
         if(p_type == POSITION_TYPE_BUY)
            g_fund_trim_buy = 0;
         else
            g_fund_trim_sell = 0;
         Log("INFO", StringFormat("TIA DCA AM QUY: Dong lenh #%I64u (lo %.2f). RESET Quy %s ve 0.", 
             patient_ticket, patient_loss_amount, 
             (p_type == POSITION_TYPE_BUY) ? "BUY" : "SELL", current_fund));
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
   
      return false; // Quy chua du, cho tich luy them
}

