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

//+------------------------------------------------------------------+
//| Xóa lệnh Pending thừa khi đã có lệnh Trực tiếp khớp tại vị trí đó |
//+------------------------------------------------------------------+
void CleanRedundantPendingOrders()
{
    if(!inp_enable_pending_mode) return;
    
    int total_orders = OrdersTotal();
    if(total_orders == 0) return; // Khong co pending order nao
    
    int total_positions = PositionsTotal();
    if(total_positions == 0) return; // Khong co position nao de de len
    
    double tol = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point * 0.5;
    
    for(int i = total_orders - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double pend_price = OrderGetDouble(ORDER_PRICE_OPEN);
            
            ENUM_POSITION_TYPE p_type = POSITION_TYPE_BUY;
            if(order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT) p_type = POSITION_TYPE_SELL;
            
            bool is_redundant = false;
            for(int j = 0; j < total_positions; j++)
            {
                if(PositionGetSymbol(j) == _Symbol)
                {
                    ulong pos_ticket = PositionGetInteger(POSITION_TICKET);
                    if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetInteger(POSITION_TYPE) == p_type)
                    {
                        double pos_price = PositionGetDouble(POSITION_PRICE_OPEN);
                        if(MathAbs(pos_price - pend_price) < tol)
                        {
                            is_redundant = true;
                            break;
                        }
                    }
                }
            }
            
            if(is_redundant)
            {
                Log("WARNING", StringFormat("Phat hien lenh Pending thua tai %f (da co Position). Tien hanh xoa...", pend_price));
                trade.OrderDelete(ticket);
            }
        }
    }
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

// Kiểm tra xem đã có lệnh Pending nào ở gần khoảng giá mục tiêu không (Hybrid Guard)
bool HasPendingNearPrice(ENUM_POSITION_TYPE type, double target_price)
{
    // Dung sai = 0.5 * khoảng cách DCA dương (tránh check quá chặt do slippage)
    double dist_points = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point;
    double tol = dist_points * 0.5;
    
    int total_orders = OrdersTotal();
    for(int i = 0; i < total_orders; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            bool is_match = false;
            
            if(type == POSITION_TYPE_BUY && (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)) is_match = true;
            if(type == POSITION_TYPE_SELL && (order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)) is_match = true;
            
            // Chỉ check các Pending mang mác DCA DUONG (hoặc Initial) -> Đã loại bỏ filter, tất cả đều là Grid nodes
            if(is_match)
            {
                if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - target_price) < tol) return true;
            }
        }
    }
    return false;
}

// Kiểm tra xem đã có POSITION THẬT nào gần mức giá mục tiêu không (Position Guard)
bool HasPositionNearPrice(ENUM_POSITION_TYPE type, double target_price, const PositionInfo &positions[])
{
    double dist_points = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point;
    double tol = dist_points * 0.5;
    
    for(int i = 0; i < ArraySize(positions); i++)
    {
        if(positions[i].type == type)
        {
            if(MathAbs(positions[i].open_price - target_price) < tol) return true;
        }
    }
    return false;
}

// Xóa chủ động lệnh Pending gần mức giá vừa mở Market Order (Proactive Cleanup)
void DeletePendingNearPrice(ENUM_POSITION_TYPE type, double target_price)
{
    double dist_points = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point;
    double tol = dist_points * 0.5;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            bool is_match = false;
            if(type == POSITION_TYPE_BUY && (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)) is_match = true;
            if(type == POSITION_TYPE_SELL && (order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)) is_match = true;
            
            if(is_match && MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - target_price) < tol)
            {
                Log("INFO", StringFormat("Proactive Cleanup: Xoa Pending tai %f (da mo Market Order gan do).", OrderGetDouble(ORDER_PRICE_OPEN)));
                trade.OrderDelete(ticket);
            }
        }
    }
}

// Tái chế Lệnh Pending thay vì Xóa / Tạo lại (Modify-in-RAM) giảm lượng request
void RecyclePendingOrders(ENUM_POSITION_TYPE type, double initial_price)
{
    if(!inp_enable_pending_mode || inp_pending_order_count <= 0) 
    {
        DeletePendingOrdersByType(type);
        return;
    }
    
    double lot = inp_lot_dca_duong;
    double dist_pips = inp_dca_duong_distance_pips;
    double dist_points = (double)PipToPoints(dist_pips) * _Point;
    
    ulong old_tickets[];
    int total_orders = OrdersTotal();
    for(int i = total_orders - 1; i >= 0; i--) // Lap nguoc de de xoa
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            if(type == POSITION_TYPE_BUY && (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT))
            {
                if(order_type == ORDER_TYPE_BUY_STOP) {
                    int arr_sz = ArraySize(old_tickets);
                    ArrayResize(old_tickets, arr_sz + 1);
                    old_tickets[arr_sz] = ticket;
                } else {
                    trade.OrderDelete(ticket); // Khong the sua Limit thanh Stop -> Xoa
                }
            }
            else if(type == POSITION_TYPE_SELL && (order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT))
            {
                if(order_type == ORDER_TYPE_SELL_STOP) {
                    int arr_sz = ArraySize(old_tickets);
                    ArrayResize(old_tickets, arr_sz + 1);
                    old_tickets[arr_sz] = ticket;
                } else {
                    trade.OrderDelete(ticket); // Khong the sua Limit thanh Stop -> Xoa
                }
            }
        }
    }
    
    int recycled_count = 0;
    
    for(int i = 1; i <= inp_pending_order_count; i++)
    {
        double target_price = (type == POSITION_TYPE_BUY) ? (initial_price + i * dist_points) : (initial_price - i * dist_points);
        
        if(recycled_count < ArraySize(old_tickets))
        {
            ulong ticket_to_modify = old_tickets[recycled_count];
            if(OrderSelect(ticket_to_modify))
            {
                double old_price = OrderGetDouble(ORDER_PRICE_OPEN);
                if(MathAbs(old_price - target_price) > _Point) // Co su lech gia
                {
                    if(!trade.OrderModify(ticket_to_modify, target_price, 0, 0, ORDER_TIME_GTC, 0))
                    {
                        Log("WARNING", StringFormat("Modify %s Stop failed: %d. Dang xoa lenh rác cu.", EnumToString(type), trade.ResultRetcode()));
                        trade.OrderDelete(ticket_to_modify); // Xóa luôn lệnh rác để tránh kẹt trên biểu đồ
                    }
                }
            }
            recycled_count++;
        }
        else
        {
            // Phat sinh them lenh moi neu thieu
            if(type == POSITION_TYPE_BUY)
               trade.BuyStop(lot, target_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
            else
               trade.SellStop(lot, target_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
        }
    }
    
    // Xoa cac lenh thua
    for(int i = recycled_count; i < ArraySize(old_tickets); i++)
    {
        trade.OrderDelete(old_tickets[i]);
    }
}

// Tái chế Lệnh Pending XEN KẼ giữa Buy và Sell (Buy1, Sell1, Buy2, Sell2, ...)
void RecyclePendingOrdersInterleaved(double buy_initial_price, double sell_initial_price)
{
    if(!inp_enable_pending_mode || inp_pending_order_count <= 0) 
    {
        DeletePendingOrdersByType(POSITION_TYPE_BUY);
        DeletePendingOrdersByType(POSITION_TYPE_SELL);
        return;
    }
    
    double lot = inp_lot_dca_duong;
    double dist_points = (double)PipToPoints(inp_dca_duong_distance_pips) * _Point;
    
    // === PHASE 1: Thu thap lenh cu va don dep ===
    ulong old_buy_tickets[];
    ulong old_sell_tickets[];
    
    int total_orders = OrdersTotal();
    for(int i = total_orders - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            if(order_type == ORDER_TYPE_BUY_STOP)
            {
                int arr_sz = ArraySize(old_buy_tickets);
                ArrayResize(old_buy_tickets, arr_sz + 1);
                old_buy_tickets[arr_sz] = ticket;
            }
            else if(order_type == ORDER_TYPE_BUY_LIMIT)
            {
                trade.OrderDelete(ticket);
            }
            else if(order_type == ORDER_TYPE_SELL_STOP)
            {
                int arr_sz = ArraySize(old_sell_tickets);
                ArrayResize(old_sell_tickets, arr_sz + 1);
                old_sell_tickets[arr_sz] = ticket;
            }
            else if(order_type == ORDER_TYPE_SELL_LIMIT)
            {
                trade.OrderDelete(ticket);
            }
        }
    }
    
    // === PHASE 2: Dat lenh XEN KE (Buy1, Sell1, Buy2, Sell2, ...) ===
    int buy_recycled = 0;
    int sell_recycled = 0;
    
    for(int i = 1; i <= inp_pending_order_count; i++)
    {
        // --- BUY STOP ---
        double buy_target = buy_initial_price + i * dist_points;
        if(buy_recycled < ArraySize(old_buy_tickets))
        {
            ulong ticket_to_modify = old_buy_tickets[buy_recycled];
            if(OrderSelect(ticket_to_modify))
            {
                double old_price = OrderGetDouble(ORDER_PRICE_OPEN);
                if(MathAbs(old_price - buy_target) > _Point)
                {
                    if(!trade.OrderModify(ticket_to_modify, buy_target, 0, 0, ORDER_TIME_GTC, 0))
                    {
                        Log("WARNING", StringFormat("Interleaved: Modify Buy Stop failed: %d. Xoa lenh rac.", trade.ResultRetcode()));
                        trade.OrderDelete(ticket_to_modify);
                    }
                }
            }
            buy_recycled++;
        }
        else
        {
            trade.BuyStop(lot, buy_target, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
        }
        
        // --- SELL STOP ---
        double sell_target = sell_initial_price - i * dist_points;
        if(sell_recycled < ArraySize(old_sell_tickets))
        {
            ulong ticket_to_modify = old_sell_tickets[sell_recycled];
            if(OrderSelect(ticket_to_modify))
            {
                double old_price = OrderGetDouble(ORDER_PRICE_OPEN);
                if(MathAbs(old_price - sell_target) > _Point)
                {
                    if(!trade.OrderModify(ticket_to_modify, sell_target, 0, 0, ORDER_TIME_GTC, 0))
                    {
                        Log("WARNING", StringFormat("Interleaved: Modify Sell Stop failed: %d. Xoa lenh rac.", trade.ResultRetcode()));
                        trade.OrderDelete(ticket_to_modify);
                    }
                }
            }
            sell_recycled++;
        }
        else
        {
            trade.SellStop(lot, sell_target, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA DUONG");
        }
    }
    
    // === PHASE 3: Xoa lenh thua con lai ===
    for(int i = buy_recycled; i < ArraySize(old_buy_tickets); i++)
        trade.OrderDelete(old_buy_tickets[i]);
    for(int i = sell_recycled; i < ArraySize(old_sell_tickets); i++)
        trade.OrderDelete(old_sell_tickets[i]);
}

// (Da xoa: PlaceReplacementLimitOrder - da duoc thay the boi HealGridGaps)

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
            furthest_price = initial_price; // Day la highest_buy_price hoac lowest_sell_price duoc truyen vao
        }
        
        double lot = inp_lot_dca_duong;
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


        // 1. Gom Position
        for(int i = 0; i < pos_total; i++)
        {
            if(positions[i].type == current_type)
            {
                ArrayResize(price_list, price_count + 1);
                price_list[price_count] = positions[i].open_price;
                price_count++;
            }
        }
        
        // 2. Gom Pending
        for(int i = 0; i < pend_total; i++)
        {
            if(pending_orders[i].position_type == current_type)
            {
                ArrayResize(price_list, price_count + 1);
                price_list[price_count] = pending_orders[i].open_price;
                price_count++;
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
                    
                    double lot_limit = inp_lot_dca_duong;
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

// Dong bo hoa khoi luong cua lenh Pending voi thong so Lot hien tai
void SyncPendingVolume()
{
    if(!inp_enable_pending_mode) return;
    
    // Throttling: 3 seconds
    ulong current_time = GetTickCount();
    if(current_time - g_last_sync_vol_time < 3000) return;
    g_last_sync_vol_time = current_time;

    int total_orders = OrdersTotal();
    for(int i = total_orders - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double current_vol = OrderGetDouble(ORDER_VOLUME_INITIAL);
            double target_vol = 0;
            
            if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
            {
                target_vol = inp_lot_dca_duong; 
            }
            else if(order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)
            {
                target_vol = inp_lot_dca_duong; // Both sides use inp_lot_dca_duong for Pending Orders (DCA DUONG)
            }
            
            // Neu sai lech khoi luong > 0.001
            if(target_vol > 0 && MathAbs(current_vol - target_vol) > 0.001)
            {
                double price = OrderGetDouble(ORDER_PRICE_OPEN);
                string comment = OrderGetString(ORDER_COMMENT);
                
                Log("INFO", StringFormat("Phat hien lenh Pending #%I64u sai Lot (Hien tai: %.2f, Muc tieu: %.2f). Tien hanh cap nhat bang cach Xoa va Dat lai...", ticket, current_vol, target_vol));
                
                // Thu xoa lenh
                if(trade.OrderDelete(ticket))
                {
                    // Dat lai lenh moi cung vi tri
                    if(order_type == ORDER_TYPE_BUY_STOP) trade.BuyStop(target_vol, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    else if(order_type == ORDER_TYPE_BUY_LIMIT) trade.BuyLimit(target_vol, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    else if(order_type == ORDER_TYPE_SELL_STOP) trade.SellStop(target_vol, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                    else if(order_type == ORDER_TYPE_SELL_LIMIT) trade.SellLimit(target_vol, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
                }
                else
                {
                    Log("ERROR", StringFormat("Khong the xoa lenh Pending #%I64u de cap nhat Lot. Loi: %d", ticket, trade.ResultRetcode()));
                }
            }
        }
    }
}
