//+------------------------------------------------------------------+
//|                                            SidewayProtection.mqh |
//|                                              Yoogi Industrial Yang|
//|               --- SIDEWAY PROTECTION LAYER ---                   |
//+------------------------------------------------------------------+
#ifndef SIDEWAYPROTECTION_MQH
#define SIDEWAYPROTECTION_MQH

#include "Globals.mqh"
#include "PendingOrders.mqh"

//+------------------------------------------------------------------+
//| KIỂM TRA KHỞI TẠO LOCK (SIDEWAY DETECT)                          |
//+------------------------------------------------------------------+
void CheckSidewayLock(int total_buy_pos, int total_sell_pos)
{
    if(g_sideway_lock) return;

    if(total_buy_pos >= inp_sideway_min_positions && total_sell_pos >= inp_sideway_min_positions)
    {
        double min_pos = (double)MathMin(total_buy_pos, total_sell_pos);
        double max_pos = (double)MathMax(total_buy_pos, total_sell_pos);
        
        if(max_pos > 0)
        {
            double ratio = min_pos / max_pos;
            if(ratio >= SIDEWAY_RATIO_THRESHOLD)
            {
                g_sideway_lock = true;
                
                Log("WARNING", "[SIDEWAY] Detection triggered");
                Log("WARNING", StringFormat("BUY Positions: %d", total_buy_pos));
                Log("WARNING", StringFormat("SELL Positions: %d", total_sell_pos));
                Log("WARNING", StringFormat("Ratio: %.1f%%", ratio * 100.0));
                Log("WARNING", StringFormat("Threshold: %d", inp_sideway_min_positions));
                Log("WARNING", StringFormat("Ratio Threshold: %.1f%%", SIDEWAY_RATIO_THRESHOLD * 100.0));
                
                Log("WARNING", "[SIDEWAY] LOCK ACTIVATED");
                
                // Xoá toàn bộ Pending Orders để ngăn cản lệnh nhồi thêm
                DeleteAllPendingOrders();
                Log("WARNING", "[SIDEWAY] All pending orders deleted");
                Log("WARNING", "[SIDEWAY] New entries blocked");
                Log("WARNING", "[SIDEWAY] New DCA blocked");
                Log("WARNING", StringFormat("[SIDEWAY] Min TP active: $%.2f", inp_min_tp_usd));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| KIỂM TRA MỞ LOCK (KHI TOÀN BỘ CHU KỲ ĐÃ ĐÓNG)                    |
//+------------------------------------------------------------------+
void ResetSidewayLockIfNeeded(int total_buy_pos, int total_sell_pos)
{
    if(g_sideway_lock && total_buy_pos == 0 && total_sell_pos == 0)
    {
        g_sideway_lock = false;
        Log("INFO", "[SIDEWAY] Cycle closed");
        Log("INFO", "[SIDEWAY] Lock reset");
        Log("INFO", "[SIDEWAY] New cycle allowed");
    }
}

#endif
