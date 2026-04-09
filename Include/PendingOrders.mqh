//+------------------------------------------------------------------+
//|                                                PendingOrders.mqh |
//|                                                 Yoogi Yin Yang   |
//|               --- XỬ LÝ LỆNH CHỜ (STOP / LIMIT) ---              |
//+------------------------------------------------------------------+

// Đếm số lượng lệnh pending (theo chiều) đang mở
int CountPendingOrdersByType(ENUM_POSITION_TYPE type)
{
    int count = 0;
    int total_orders = OrdersTotal();
    for(int i = 0; i < total_orders; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0)
        {
            if(OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if(type == POSITION_TYPE_BUY && order_type == ORDER_TYPE_BUY_STOP) count++;
                if(type == POSITION_TYPE_SELL && order_type == ORDER_TYPE_SELL_STOP) count++;
            }
        }
    }
    return count;
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
void PlaceLimitOrderDCA_Am(ENUM_POSITION_TYPE type, double at_price, int dca_am_level_virtual)
{
    if(!inp_enable_pending_mode) return; // Chi mo khi dang On Che Do Pending
    
    // Tinh toan Khoi luong tuong ung DCA am level:
    double lot_limit = GetLotSize_ForDCA_Am(dca_am_level_virtual, (type == POSITION_TYPE_BUY) ? inp_lot_dca_duong : inp_lot_dca_duong);
    
    Log("INFO", StringFormat("Tia lenh %s thanh cong tao gia %f. Dat %s Limit (Lot: %f) de cho vao lai DCA Am.",
        EnumToString(type), at_price, (type == POSITION_TYPE_BUY ? "Buy" : "Sell"), lot_limit));
        
    if(type == POSITION_TYPE_BUY)
    {
        if(!trade.BuyLimit(lot_limit, at_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA AM"))
             Log("ERROR", StringFormat("DCA Am (Buy Limit Thay The) That bai, Ma Loi: %d", trade.ResultRetcode()));
    }
    else
    {
        if(!trade.SellLimit(lot_limit, at_price, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "DCA AM"))
             Log("ERROR", StringFormat("DCA Am (Sell Limit Thay The) That bai, Ma Loi: %d", trade.ResultRetcode()));
    }
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
        
        // Tim lenh co gia xa nhat
        double furthest_price = 0;
        int total_orders = OrdersTotal();
        bool found = false;
        
        for(int i = 0; i < total_orders; i++)
        {
            ulong ticket = OrderGetTicket(i);
            if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == inp_magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                double price = OrderGetDouble(ORDER_PRICE_OPEN);
                if(type == POSITION_TYPE_BUY && order_type == ORDER_TYPE_BUY_STOP)
                {
                    if(!found || price > furthest_price) { furthest_price = price; found = true; }
                }
                else if(type == POSITION_TYPE_SELL && order_type == ORDER_TYPE_SELL_STOP)
                {
                    if(!found || price < furthest_price) { furthest_price = price; found = true; }
                }
            }
        }
        
        if(!found) {
            furthest_price = initial_price; // Neu broker ngat ca lenh stop hoac mat
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
