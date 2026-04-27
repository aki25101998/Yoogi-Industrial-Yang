//+------------------------------------------------------------------+
//|                                                 Indicators.mqh |
//|                                                 Yoogi Yin Yang   |
//|               --- TAP TINH TOAN CHI BAO & LOC XU HUONG ---        |
//|         (Phien ban 3.0 - State Machine Trend Detection)          |
//+------------------------------------------------------------------+

#include "Input.mqh"
#include "Globals.mqh"

//--- Khai bao ham ---
void UpdateEmaLockStatus();
void OnInitIndicators();

//+------------------------------------------------------------------+
//| KHOI TAO CAC CHI BAO (ADX)                                       |
//+------------------------------------------------------------------+
void OnInitIndicators()
{
   // Khoi tao ADX neu chua co
   if(handle_adx == INVALID_HANDLE)
   {
      // Su dung timeframe cua EMA cho dong nhat
      handle_adx = iADX(_Symbol, inp_ema_timeframe, InpAdxPeriod);

      if(handle_adx == INVALID_HANDLE)
      {
         Print("Loi: Khong the khoi tao chi bao ADX. Ma loi: ", GetLastError());
      }
      else
      {
         Print("Khoi tao ADX thanh cong. Handle: ", handle_adx);
      }
   }
   
   // Reset trang thai xu huong khi khoi dong
   g_confirmed_trend = TREND_NONE;
   g_last_trend_check_time = 0;
}

//+------------------------------------------------------------------+
//| CAP NHAT TRANG THAI KHOA THEO BO LOC EMA & ADX (STATE MACHINE)   |
//+------------------------------------------------------------------+
void UpdateEmaLockStatus()
{
   // --- Buoc 0: Kiem tra nen M15 moi ---
   datetime current_bar_time = iTime(_Symbol, PERIOD_M15, 0);
   bool is_new_bar = (current_bar_time != g_last_trend_check_time);
   
   // Neu khong phai nen M15 moi VA da co xu huong -> bo qua
   if(!is_new_bar && g_confirmed_trend != TREND_NONE)
      return;
   
   g_last_trend_check_time = current_bar_time;

   // --- Buoc 1: Kiem tra tinh nang co bat khong ---
   if (!inp_ema_lock_buy_on_downtrend && !inp_ema_lock_sell_on_uptrend)
   {
      g_is_buy_locked_by_ema = false;
      g_is_sell_locked_by_ema = false;
      g_confirmed_trend = TREND_NONE; // Reset de lan sau check lai
      return;
   }

   // --- Buoc 2: Lay gia tri EMA ---
   ENUM_TIMEFRAMES timeframe = inp_ema_timeframe;
   int fast_period = 20;
   int slow_period = 89;

   double fast_ema_buffer[], slow_ema_buffer[];

   if (CopyBuffer(iMA(_Symbol, timeframe, fast_period, 0, MODE_EMA, PRICE_CLOSE), 0, 1, 1, fast_ema_buffer) < 1 ||
       CopyBuffer(iMA(_Symbol, timeframe, slow_period, 0, MODE_EMA, PRICE_CLOSE), 0, 1, 1, slow_ema_buffer) < 1)
   {
      return; // Loi lay du lieu
   }

   double fast_ema = fast_ema_buffer[0];
   double slow_ema = slow_ema_buffer[0];

   bool ema_uptrend = (fast_ema > slow_ema);
   bool ema_downtrend = (fast_ema < slow_ema);

   // --- Buoc 3: XU LY LAN DAU (Chua co xu huong) ---
   if(g_confirmed_trend == TREND_NONE)
   {
      if(ema_uptrend)
      {
         g_confirmed_trend = TREND_UPTREND;
         g_is_buy_locked_by_ema = false;
         if(inp_ema_lock_sell_on_uptrend)
            g_is_sell_locked_by_ema = true;
         else
            g_is_sell_locked_by_ema = false;
         Log("INFO", StringFormat("Xu huong ban dau: TANG (EMA20=%.5f > EMA89=%.5f). Khoa SELL.", fast_ema, slow_ema));
      }
      else if(ema_downtrend)
      {
         g_confirmed_trend = TREND_DOWNTREND;
         g_is_sell_locked_by_ema = false;
         if(inp_ema_lock_buy_on_downtrend)
            g_is_buy_locked_by_ema = true;
         else
            g_is_buy_locked_by_ema = false;
         Log("INFO", StringFormat("Xu huong ban dau: GIAM (EMA20=%.5f < EMA89=%.5f). Khoa BUY.", fast_ema, slow_ema));
      }
      else
      {
         // EMA bang nhau -> chua xac dinh, doi nen tiep theo
         Log("INFO", "EMA20 = EMA89. Chua xac dinh xu huong.");
      }
      return;
   }

   // --- Buoc 4: XU LY DOI CHIEU (Da co xu huong, can kiem tra ADX) ---
   
   // Kiem tra xem EMA co bao hieu dao chieu khong
   bool ema_signals_reversal = false;
   if(g_confirmed_trend == TREND_UPTREND && ema_downtrend) ema_signals_reversal = true;
   if(g_confirmed_trend == TREND_DOWNTREND && ema_uptrend) ema_signals_reversal = true;
   
   if(!ema_signals_reversal)
   {
      // EMA van dung xu huong -> khong can lam gi
      return;
   }

   // EMA bao hieu dao chieu -> kiem tra ADX de xac nhan
   double adx_value = 0.0;
   
   if(InpUseAdxFilter)
   {
      if(handle_adx == INVALID_HANDLE)
      {
         handle_adx = iADX(_Symbol, timeframe, InpAdxPeriod);
         if(handle_adx == INVALID_HANDLE) return;
      }

      double adx_buffer[];
      if(CopyBuffer(handle_adx, 0, 1, 1, adx_buffer) < 1) return;
      adx_value = adx_buffer[0];
   }
   else
   {
      // Neu khong dung ADX filter -> luon cho phep dao chieu
      adx_value = 100.0; // Gia tri lon de vuot nguong
   }

   // --- Dang TANG, muon chuyen sang GIAM ---
   if(g_confirmed_trend == TREND_UPTREND && ema_downtrend)
   {
      if(adx_value > InpAdxLevel)
      {
         // Ca 2 dieu kien thoa man -> DAO CHIEU
         g_confirmed_trend = TREND_DOWNTREND;
         g_is_sell_locked_by_ema = false;
         if(inp_ema_lock_buy_on_downtrend)
            g_is_buy_locked_by_ema = true;
         else
            g_is_buy_locked_by_ema = false;
         Log("WARNING", StringFormat("DAO CHIEU: TANG -> GIAM. EMA20=%.5f < EMA89=%.5f. ADX=%.2f > %.2f. KHOA BUY.", 
             fast_ema, slow_ema, adx_value, InpAdxLevel));
      }
      else
      {
         // ADX yeu -> giu nguyen xu huong TANG
         Log("INFO", StringFormat("EMA bao giam nhung ADX yeu (%.2f <= %.2f). GIU NGUYEN xu huong TANG.", 
             adx_value, InpAdxLevel));
      }
   }
   // --- Dang GIAM, muon chuyen sang TANG ---
   else if(g_confirmed_trend == TREND_DOWNTREND && ema_uptrend)
   {
      if(adx_value > InpAdxLevel)
      {
         // Ca 2 dieu kien thoa man -> DAO CHIEU
         g_confirmed_trend = TREND_UPTREND;
         g_is_buy_locked_by_ema = false;
         if(inp_ema_lock_sell_on_uptrend)
            g_is_sell_locked_by_ema = true;
         else
            g_is_sell_locked_by_ema = false;
         Log("WARNING", StringFormat("DAO CHIEU: GIAM -> TANG. EMA20=%.5f > EMA89=%.5f. ADX=%.2f > %.2f. KHOA SELL.", 
             fast_ema, slow_ema, adx_value, InpAdxLevel));
      }
      else
      {
         // ADX yeu -> giu nguyen xu huong GIAM
         Log("INFO", StringFormat("EMA bao tang nhung ADX yeu (%.2f <= %.2f). GIU NGUYEN xu huong GIAM.", 
             adx_value, InpAdxLevel));
      }
   }
}

// (Da xoa: CheckEmaReversal - khong duoc goi o dau trong codebase)