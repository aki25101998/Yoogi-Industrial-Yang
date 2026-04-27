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

// Hàm suy ngược giá Initial từ lịch sử (trường hợp gắn EA vào giữa chừng khi Initial đã bị tỉa)
double RecoverInitialPriceFromHistory(ENUM_POSITION_TYPE type)
{
    // B1: Tìm thời gian mở của lệnh cổ nhất ĐANG TỒN TẠI của chu kỳ hiện tại
    datetime oldest_open_time = 0;
    int total_pos = PositionsTotal();
    for(int i = 0; i < total_pos; i++)
    {
        ulong pos_ticket = PositionGetTicket(i);
        if(pos_ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == inp_magic_number)
        {
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
            {
               datetime t = (datetime)PositionGetInteger(POSITION_TIME);
               if(oldest_open_time == 0 || t < oldest_open_time) oldest_open_time = t;
            }
        }
    }

    if(!HistorySelect(0, TimeCurrent())) return 0.0;
    
    int total_deals = HistoryDealsTotal();
    string target_cmt = (type == POSITION_TYPE_BUY) ? "Initial Buy" : "Initial Sell";
    
    // B2: Dùng vòng lặp ngược để tìm deal Initial gần nhất
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
                    // Lớp rào chắn: Kiểm tra xem lệnh Initial này có thuộc về chu kỳ cũ không?
                    long pos_id = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                    datetime close_time = 0;
                    
                    // Tìm thời điểm đóng của lệnh Initial này
                    for(int k = total_deals - 1; k >= 0; k--)
                    {
                        ulong out_ticket = HistoryDealGetTicket(k);
                        if(HistoryDealGetInteger(out_ticket, DEAL_POSITION_ID) == pos_id && HistoryDealGetInteger(out_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                        {
                            close_time = (datetime)HistoryDealGetInteger(out_ticket, DEAL_TIME);
                            break;
                        }
                    }
                    
                    // Nếu thời điểm đóng của Initial này diễn ra TRƯỚC khi lệnh cũ nhất của chu kỳ hiện tại được mở
                    // -> Nó chắc chắn thuộc về chu kỳ cũ đã kết thúc. Không được sử dụng!
                    if(oldest_open_time > 0 && close_time > 0 && close_time < oldest_open_time)
                    {
                        Log("INFO", StringFormat("SUY NGUOC LICH SU: Phat hien %s thuoc chu ky cu (CloseTime %s < OldestOpenTime %s). Bo qua!", target_cmt, TimeToString(close_time), TimeToString(oldest_open_time)));
                        return 0.0; 
                    }
                
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
            
            // Chỉ check các Pending mang mác DCA DUONG (hoặc Initial)
            if(is_match && StringFind(OrderGetString(ORDER_COMMENT), "DCA DUONG") != -1)
            {
                if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - target_price) < tol) return true;
            }
        }
    }
    return false;
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
            bool is_dca_duong = (StringFind(OrderGetString(ORDER_COMMENT), "DCA DUONG") != -1);
            
            if(type == POSITION_TYPE_BUY && (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT) && is_dca_duong)
            {
                if(order_type == ORDER_TYPE_BUY_STOP) {
                    int arr_sz = ArraySize(old_tickets);
                    ArrayResize(old_tickets, arr_sz + 1);
                    old_tickets[arr_sz] = ticket;
                } else {
                    trade.OrderDelete(ticket); // Khong the sua Limit thanh Stop -> Xoa
                }
            }
            else if(type == POSITION_TYPE_SELL && (order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT) && is_dca_duong)
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
