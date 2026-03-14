//+------------------------------------------------------------------+
//|                                                        Panel.mqh |
//|                                                 Yoogi Yin Yang |
//|                --- TỆP QUẢN LÝ PANEL ĐIỀU KHIỂN ---               |
//|                  (Phiên bản không cần Input)                      |
//+------------------------------------------------------------------+

//--- Khai báo tên đối tượng cho các nút bấm
#define BTN_CLOSE_ALL_NAME   "YYY_Btn_CloseAll"
#define BTN_CLOSE_BUY_NAME   "YYY_Btn_CloseBuy"
#define BTN_CLOSE_SELL_NAME  "YYY_Btn_CloseSell"

//--- Khai báo các hàm sẽ được gọi từ tệp .mq5 chính
void CreatePanel(); // <<< CẬP NHẬT
void DeletePanel();
void OnPanelChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

//--- Khai báo các hàm nội bộ
void CloseAllPositions();
void CloseBuyPositions();
void CloseSellPositions();

//+------------------------------------------------------------------+
//| TẠO GIAO DIỆN PANEL                                              |
//+------------------------------------------------------------------+
// <<< CẬP NHẬT: Hàm không còn tham số, sử dụng giá trị mặc định
void CreatePanel()
{
    // --- Các giá trị mặc định cho vị trí và kích thước ---
    const int corner      = CORNER_LEFT_UPPER;
    const int x_offset    = 20;
    const int y_offset    = 50;
    const int panel_width = 250;
    const int btn_height  = 30;

    // --- Kích thước và vị trí (tính toán nội bộ) ---
    int btn_full_width = panel_width;
    int btn_half_width = btn_full_width / 2 - 1; 
    int x = x_offset;
    int y = y_offset;

    // --- Nút 1: Đóng tất cả (chiếm trọn chiều rộng) ---
    ObjectCreate(0, BTN_CLOSE_ALL_NAME, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_XSIZE, btn_full_width);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_YSIZE, btn_height);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_CORNER, corner);
    ObjectSetString(0, BTN_CLOSE_ALL_NAME, OBJPROP_TEXT, "Đóng tất cả");
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_COLOR, clrSilver);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_BGCOLOR, clrDimGray);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_STATE, false);
    ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_FONTSIZE, 10);

    // --- Cập nhật vị trí Y cho hàng tiếp theo ---
    y += btn_height + 2;

    // --- Nút 2: Đóng lệnh Buy (nửa trái) ---
    ObjectCreate(0, BTN_CLOSE_BUY_NAME, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_XSIZE, btn_half_width);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_YSIZE, btn_height);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_CORNER, corner);
    ObjectSetString(0, BTN_CLOSE_BUY_NAME, OBJPROP_TEXT, "Đóng lệnh Buy");
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_BGCOLOR, clrDodgerBlue);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_STATE, false);
    ObjectSetInteger(0, BTN_CLOSE_BUY_NAME, OBJPROP_FONTSIZE, 10);
    
    // --- Cập nhật vị trí X cho nút bên phải ---
    x += btn_half_width + 2;

    // --- Nút 3: Đóng lệnh Sell (nửa phải) ---
    ObjectCreate(0, BTN_CLOSE_SELL_NAME, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_XSIZE, btn_half_width);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_YSIZE, btn_height);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_CORNER, corner);
    ObjectSetString(0, BTN_CLOSE_SELL_NAME, OBJPROP_TEXT, "Đóng lệnh Sell");
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_BGCOLOR, clrRed);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_STATE, false);
    ObjectSetInteger(0, BTN_CLOSE_SELL_NAME, OBJPROP_FONTSIZE, 10);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| XÓA GIAO DIỆN PANEL                                              |
//+------------------------------------------------------------------+
void DeletePanel()
{
    ObjectDelete(0, BTN_CLOSE_ALL_NAME);
    ObjectDelete(0, BTN_CLOSE_BUY_NAME);
    ObjectDelete(0, BTN_CLOSE_SELL_NAME);
    ChartRedraw();
}


//+------------------------------------------------------------------+
//| XỬ LÝ SỰ KIỆN CLICK CHUỘT TRÊN PANEL                             |
//+------------------------------------------------------------------+
void OnPanelChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
        ChartRedraw();

        if(sparam == BTN_CLOSE_ALL_NAME)
        {
            Log("INFO", "Nút [Đóng tất cả] được nhấn.");
            CloseAllPositions();
        }
        else if(sparam == BTN_CLOSE_BUY_NAME)
        {
            Log("INFO", "Nút [Đóng lệnh Buy] được nhấn.");
            CloseBuyPositions();
        }
        else if(sparam == BTN_CLOSE_SELL_NAME)
        {
            Log("INFO", "Nút [Đóng lệnh Sell] được nhấn.");
            CloseSellPositions();
        }

        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        ChartRedraw();
    }
}


//+------------------------------------------------------------------+
//| LOGIC ĐÓNG LỆNH                                                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    int closed_count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                if(trade.PositionClose(ticket)) { closed_count++; }
                else { Log("ERROR", "Lỗi đóng lệnh #" + (string)ticket + ". Mã lỗi: " + (string)trade.ResultRetcode()); }
            }
        }
    }
    Log("INFO", "Đã đóng thành công " + (string)closed_count + " lệnh.");
}

void CloseBuyPositions()
{
    int closed_count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number && 
               PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                if(trade.PositionClose(ticket)) { closed_count++; }
                else { Log("ERROR", "Lỗi đóng lệnh BUY #" + (string)ticket + ". Mã lỗi: " + (string)trade.ResultRetcode()); }
            }
        }
    }
    Log("INFO", "Đã đóng thành công " + (string)closed_count + " lệnh BUY.");
}

void CloseSellPositions()
{
    int closed_count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == inp_magic_number &&
               PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                if(trade.PositionClose(ticket)) { closed_count++; }
                else { Log("ERROR", "Lỗi đóng lệnh SELL #" + (string)ticket + ". Mã lỗi: " + (string)trade.ResultRetcode()); }
            }
        }
    }
    Log("INFO", "Đã đóng thành công " + (string)closed_count + " lệnh SELL.");
}
//+------------------------------------------------------------------+



