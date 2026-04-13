//+------------------------------------------------------------------+
//|                                                PendingOrders.mqh |
//|                                                 Yoogi Yin Yang   |
//|               --- XỬ LÝ LỆNH CHỜ (STOP / LIMIT) ---              |
//+------------------------------------------------------------------+

// Đếm số lượng lệnh pending (theo chiều) đang mở
int CountPendingOrdersByType(ENUM_POSITION_TYPE type)
{
    if(type == POSITION_TYPE_BUY) return g_total_buy_pending;
    else if(type == POSITION_TYPE_SELL) return g_total_sell_pending;
    return 0;
}

// Hàm suy ngược giá Initial từ lịch sử (trường hợp gắn EA vào giữa chừng khi Initial đã bị tỉa)
double RecoverInitialPriceFromHistory(ENUM_POSITION_TYPE type)
{
    if(!HistorySelect(0, TimeCurrent())) return 0.0;
    
    int total_deals = HistoryDealsTotal();
    string target_cmt = (type == POSITION_TYPE_BUY) ? "Initial Buy" : "Initial Sell";
    
    // Dùng vòng lặp ngược để tìm deal Initial gần nhất
    for(int i = total_deals - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) == inp_magic_number && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
                string cmt = HistoryDealGetString(ticket, DEAL_COMMENT);
                if(StringFind(cmt, target_cmt) != -1)
                {
                    double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
                    Log("INFO", StringFormat("SUY NGUOC LICH SU: Da phuc hoi gia %s la %.5f", target_cmt, price));
                    return price;
                }
            }
        }
    }
    return 0.0;
}

// Xóa tất cả các lệnh pending
void DeleteAllPendingOrders()
{
    int total_orders = OrdersTotal();
    for(int i = total_orders - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0)
        {
            if(OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                if(!trade.OrderDelete(ticket))
                {
                    Log("ERROR", StringFormat("Khong the xoa lenh pending #%I64u. Ma loi: %d", ticket, trade.ResultRetcode()));
                }
            }
        }
    }
}

// Xóa lệnh pending theo chiều (khi Lock by DD/EMA)
void DeletePendingOrdersByType(ENUM_POSITION_TYPE type)
{
    int total_orders = OrdersTotal();
    for(int i = total_orders - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0)
        {
            if(OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                bool should_delete = false;
                if(type == POSITION_TYPE_BUY && (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)) should_delete = true;
                if(type == POSITION_TYPE_SELL && (order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)) should_delete = true;
                
                if(should_delete)
                {
                    if(!trade.OrderDelete(ticket))
                    {
                        Log("ERROR", StringFormat("Khong the xoa lenh pending %s #%I64u. Ma loi: %d", EnumToString(type), ticket, trade.ResultRetcode()));
                    }
                }
            }
        }
    }
}

// Đặt batch lệnh Stop mồi
void PlaceInitialStopOrders(ENUM_POSITION_TYPE type, double initial_price)
{
    if(!inp_enable_pending_mode || inp_pending_order_count <= 0) return;
    
    // Vô hiệu hóa Drawdown Scaling nếu bật mode Stop/Limit - Sử dụng Lot góc
    double lot = (type == POSITION_TYPE_BUY) ? inp_lot_dca_duong : inp_lot_dca_duong;
    double dist_pips = inp_dca_duong_distance_pips;
    double dist_points = (double)PipToPoints(dist_pips) * _Point;
    long min_stop_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    Log("INFO", StringFormat("Bat dau dat %d lenh %s Stop cach %f pips", inp_pending_order_count, EnumToString(type), dist_pips));
    
    for(int i = 1; i <= inp_pending_order_count; i++)
    {
        double target_price = 0;
        if(type == POSITION_TYPE_BUY)
        {
            target_price = initial_price + i * dist_points;
            // Kiem tra min_stop_level de phong broker reject (Mac du dat target stop nen rat kho cham mask price)
            if(!trade.BuyStop(lot, target_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG"))
            {
                Log("ERROR", StringFormat("Dat lenh Buy Stop #%d that bai. Loi: %d", i, trade.ResultRetcode()));
            }
        }
        else // SELL
        {
            target_price = initial_price - i * dist_points;
            // Sell stop
            if(!trade.SellStop(lot, target_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG"))
            {
                Log("ERROR", StringFormat("Dat lenh Sell Stop #%d that bai. Loi: %d", i, trade.ResultRetcode()));
            }
        }
    }
}

// Đặt Limit khi một lệnh bị tỉa ra
void PlaceReplacementLimitOrder(ENUM_POSITION_TYPE type, double at_price)
{
    // Ham nay da duoc thay the bang tinh nang tu dong va (HealGridGaps)
}

// Refill (nhồi lệnh vào đuôi của Stop list)
void RefillStopOrdersIfNeeded(ENUM_POSITION_TYPE type, double initial_price)
{
    if(!inp_enable_pending_mode || !inp_pending_auto_refill) return;
    
    int current_count = CountPendingOrdersByType(type);
    if(current_count < inp_pending_refill_threshold)
    {
        // Tinh toan khoang trong can refill:
        int fill_missing_count = inp_pending_order_count - current_count;
        if(fill_missing_count <= 0) return;
        
        Log("INFO", StringFormat("Luoi Stop lenh %s chi con %d. Bat dau Refill them %d lenh vao duoi.", EnumToString(type), current_count, fill_missing_count));
        
        // Tim lenh co gia xa nhat (su dung cache Phase 1)
        double furthest_price = (type == POSITION_TYPE_BUY) ? g_furthest_buy_pending_price : g_furthest_sell_pending_price;
        bool found = (furthest_price != 0);
        
        if(!found) {
            // Thay vi lay market price lam goc (initial_price), ta uu tien lay goc tu F3 neu co
            string prefix = (type == POSITION_TYPE_BUY) ? "LastInitialBuyPrice_" : "LastInitialSellPrice_";
            string f3_name = prefix + _Symbol + "_" + IntegerToString(inp_magic_number);
            if(GlobalVariableCheck(f3_name) && GlobalVariableGet(f3_name) > 0)
            {
                furthest_price = GlobalVariableGet(f3_name); // Gia tri F3
            }
            else
            {
                double recovered_price = RecoverInitialPriceFromHistory(type);
                if(recovered_price > 0)
                {
                    GlobalVariableSet(f3_name, recovered_price);
                    furthest_price = recovered_price;
                }
                else
                {
                    furthest_price = initial_price; // Gia thi truong neu chua co Initial Trade nao trong F3 (va ca history)
                    GlobalVariableSet(f3_name, -1.0); // Danh dau de khoi tim lai lan sau neu hoan toan khong co
                }
            }
        }
        
        double lot = (type == POSITION_TYPE_BUY) ? inp_lot_dca_duong : inp_lot_dca_duong;
        double dist_points = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point;

        for(int i = 1; i <= fill_missing_count; i++)
        {
            double target_price = 0;
            if(type == POSITION_TYPE_BUY)
            {
                target_price = furthest_price + i * dist_points;
                trade.BuyStop(lot, target_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
            }
            else // SELL
            {
                target_price = furthest_price - i * dist_points;
                trade.SellStop(lot, target_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
            }
        }
    }
}

// Thuat toan Healing (Va gap trong luoi gia DCA duong)
void HealGridGaps(PositionInfo &positions[], PendingInfo &pending_orders[])
{
    if(!inp_enable_pending_mode) return;
    
    // Throttling: 5 seconds
    ulong current_time = GetTickCount();
    if(current_time - g_last_heal_check_time < 5000) return;
    g_last_heal_check_time = current_time;

    int pos_total = ArraySize(positions);
    int pend_total = ArraySize(pending_orders);
    
    for(int side = 0; side < 2; side++)
    {
        ENUM_POSITION_TYPE current_type = (side == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        double price_list[];
        int price_count = 0;

        // --- BUOC 0: LAY GIA KHOI DIEM TU F3 DE GIU GOC GRID ---
        string prefix = (current_type == POSITION_TYPE_BUY) ? "LastInitialBuyPrice_" : "LastInitialSellPrice_";
        string f3_name = prefix + _Symbol + "_" + IntegerToString(inp_magic_number);
        if(GlobalVariableCheck(f3_name))
        {
            double f3_price = GlobalVariableGet(f3_name);
            if(f3_price > 0)
            {
               ArrayResize(price_list, price_count + 1);
               price_list[price_count] = f3_price;
               price_count++;
            }
        }
        else
        {
            // NEW LOGIC: Suy nguoc he toa do neu F3 bi mat
            double recovered_price = RecoverInitialPriceFromHistory(current_type);
            if(recovered_price > 0)
            {
               GlobalVariableSet(f3_name, recovered_price);
               ArrayResize(price_list, price_count + 1);
               price_list[price_count] = recovered_price;
               price_count++;
            }
            else 
            {
               GlobalVariableSet(f3_name, -1.0); // set -1 de khong scan lich su nua neu thuc su k co
            }
        }
        
        // 1. Gom Position
        for(int i = 0; i < pos_total; i++)
        {
            if(positions[i].type == current_type)
            {
                if(StringFind(positions[i].comment, "DCA DUONG") != -1 || StringFind(positions[i].comment, "Initial") != -1)
                {
                    ArrayResize(price_list, price_count + 1);
                    price_list[price_count] = positions[i].open_price;
                    price_count++;
                }
            }
        }
        
        // 2. Gom Pending
        for(int i = 0; i < pend_total; i++)
        {
            if(pending_orders[i].position_type == current_type)
            {
                if(StringFind(pending_orders[i].comment, "DCA DUONG") != -1)
                {
                    ArrayResize(price_list, price_count + 1);
                    price_list[price_count] = pending_orders[i].open_price;
                    price_count++;
                }
            }
        }
        
        if(price_count < 2) continue; // Khong du luoi
        
        // 3. Sort ascending
        ArraySort(price_list);
        
        double dist_points = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point;
        // Dung sai kiem tra Gap: > 1.5 * dist
        double gap_threshold = dist_points * 1.5; 
        
        // 4. Kiem tra gap
        for(int i = 0; i < price_count - 1; i++)
        {
            double diff = price_list[i+1] - price_list[i];
            if(diff > gap_threshold)
            {
                int missing_slots = (int)MathFloor(diff / dist_points);
                for(int m = 1; m <= missing_slots; m++)
                {
                    double missing_price = price_list[i] + m * dist_points;
                    
                    // Xac nhan khoang cach thuc su con lai voi mep tren (tranh trung lep qua sat)
                    if((price_list[i+1] - missing_price) < (dist_points * 0.5)) continue;
                    
                    double lot_limit = (current_type == POSITION_TYPE_BUY) ? inp_lot_dca_duong : inp_lot_dca_duong;
                    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    
                    if(current_type == POSITION_TYPE_BUY)
                    {
                        if(current_ask < missing_price)
                        {
                            trade.BuyStop(lot_limit, missing_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
                            Log("INFO", StringFormat("Heal Grid Gap: Dat Buy Stop bu lo hong tai gia %f", missing_price));
                        }
                        else
                        {
                            trade.BuyLimit(lot_limit, missing_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
                            Log("INFO", StringFormat("Heal Grid Gap: Dat Buy Limit bu lo hong tai gia %f", missing_price));
                        }
                    }
                    else // SELL
                    {
                        if(current_bid > missing_price)
                        {
                            trade.SellStop(lot_limit, missing_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
                            Log("INFO", StringFormat("Heal Grid Gap: Dat Sell Stop bu lo hong tai gia %f", missing_price));
                        }
                        else
                        {
                            trade.SellLimit(lot_limit, missing_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
                            Log("INFO", StringFormat("Heal Grid Gap: Dat Sell Limit bu lo hong tai gia %f", missing_price));
                        }
                    }
                }
            }
        }
    }
}
