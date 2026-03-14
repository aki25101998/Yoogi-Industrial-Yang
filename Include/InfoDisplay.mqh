//+------------------------------------------------------------------+
//|                                              InfoDisplay.mqh |
//|                                                 Yoogi Yin Yang |
//|               --- TỆP QUẢN LÝ HIỂN THỊ BẢNG THÔNG TIN ---         |
//|      (Phiên bản cập nhật - Nối dài đường kẻ bằng 2 Label)        |
//+------------------------------------------------------------------+

//--- Khai báo tên đối tượng cho các label, có một prefix chung để dễ quản lý
#define INFO_PREFIX "YYY_Info_"

//--- Khai báo các hàm sẽ được gọi từ tệp .mq5 chính
void CreateDisplay();
void UpdateDisplay(const PositionInfo &positions[]); 
void DeleteDisplay();

//--- Khai báo hàm nội bộ
void CreateLabel(string name, string text, int x, int y, int corner, int font_size, color clr, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER);

//+------------------------------------------------------------------+
//| TẠO GIAO DIỆN BẢNG THÔNG TIN                                      |
//+------------------------------------------------------------------+
void CreateDisplay()
{
    // --- Các giá trị mặc định cho vị trí và kích thước ---
    const int corner     = CORNER_LEFT_LOWER;
    const int x_offset   = 20;
    const int y_offset   = 50;
    const int font_size  = 13;

    int y = y_offset;
    int line_height = font_size + 6;
    
    int pipe_x = x_offset;      
    int text_x = x_offset + 20; 
    int value_x = x_offset + 380; 
    int end_pipe_x = x_offset + 660;
    
    // --- CÁC BIẾN TÙY CHỈNH CHO ĐƯỜNG KẺ NỐI DÀI ---
    string border_segment_1 = "----------------------------------------------------";
    string border_segment_2 = "-------------";
    int border_segment_2_start_x = 550; // <<< ĐIỀU CHỈNH VỊ TRÍ ĐOẠN 2 TẠI ĐÂY

    //--- Quy ước màu cố định ---
    color c_buy = clrLimeGreen;
    color c_sell = clrRed;
    color c_hang = clrOrange;
    color c_text = clrWhite;

    // --- KHỐI DÒNG: Tiêu đề chính ---
    CreateLabel(INFO_PREFIX+"HeaderMain_Left", "+", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"HeaderMain_Line_1", border_segment_1, pipe_x + 9, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"HeaderMain_Line_2", border_segment_2, border_segment_2_start_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"HeaderMain_Right", "+", end_pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Title", "Yoogi Yin Yang 1.5", x_offset + 250, y, corner, font_size, c_text); 
    y += line_height;

    // --- KHỐI DÒNG: DCA Dương Buy ---
    CreateLabel(INFO_PREFIX+"DcaDuongBuy_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaDuongBuy_Text", "Tổng lệnh DCA Dương Buy:", text_x, y, corner, font_size, c_buy);
    CreateLabel(INFO_PREFIX+"DcaDuongBuy_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text); 
    CreateLabel(INFO_PREFIX+"DcaDuongBuy_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: DCA Âm Sell ---
    CreateLabel(INFO_PREFIX+"DcaAmSell_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaAmSell_Text", "Tổng lệnh DCA Âm Sell:", text_x, y, corner, font_size, c_sell);
    CreateLabel(INFO_PREFIX+"DcaAmSell_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaAmSell_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: DCA Dương Sell ---
    CreateLabel(INFO_PREFIX+"DcaDuongSell_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaDuongSell_Text", "Tổng lệnh DCA Dương Sell:", text_x, y, corner, font_size, c_sell);
    CreateLabel(INFO_PREFIX+"DcaDuongSell_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaDuongSell_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: DCA Âm Buy ---
    CreateLabel(INFO_PREFIX+"DcaAmBuy_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaAmBuy_Text", "Tổng lệnh DCA Âm Buy:", text_x, y, corner, font_size, c_buy);
    CreateLabel(INFO_PREFIX+"DcaAmBuy_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaAmBuy_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;
    
    // --- KHỐI DÒNG: Kẻ ngang phân cách ---
    CreateLabel(INFO_PREFIX+"SeparatorDca_Left", "+", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"SeparatorDca_Line_1", border_segment_1, pipe_x + 9, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"SeparatorDca_Line_2", border_segment_2, border_segment_2_start_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"SeparatorDca_Right", "+", end_pipe_x, y, corner, font_size, c_text);
    y += line_height;
    
    // --- KHỐI DÒNG: DCA HÀNG Buy ---
    CreateLabel(INFO_PREFIX+"DcaHangBuy_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaHangBuy_Text", "Tổng lệnh DCA HÀNG Buy:", text_x, y, corner, font_size, c_hang);
    CreateLabel(INFO_PREFIX+"DcaHangBuy_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaHangBuy_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: DCA HÀNG Sell ---
    CreateLabel(INFO_PREFIX+"DcaHangSell_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaHangSell_Text", "Tổng lệnh DCA HÀNG Sell:", text_x, y, corner, font_size, c_hang);
    CreateLabel(INFO_PREFIX+"DcaHangSell_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"DcaHangSell_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;
    
    // --- KHỐI DÒNG: Tiêu đề Account ---
    CreateLabel(INFO_PREFIX+"HeaderAccount_Left", "+", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"HeaderAccount_Line_1", border_segment_1, pipe_x + 9, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"HeaderAccount_Line_2", border_segment_2, border_segment_2_start_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"HeaderAccount_Right", "+", end_pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"AccountTitle", "Account Info", x_offset + 280, y, corner, font_size, c_text); 
    y += line_height;

    // --- KHỐI DÒNG: Balance ---
    CreateLabel(INFO_PREFIX+"Balance_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Balance_Text", "Balance:", text_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Balance_Value", "0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Balance_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;
    
    // --- KHỐI DÒNG: Equity ---
    CreateLabel(INFO_PREFIX+"Equity_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Equity_Text", "Equity:", text_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Equity_Value", "0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Equity_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: Profit ---
    CreateLabel(INFO_PREFIX+"Profit_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Profit_Text", "Profit:", text_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Profit_Value", "0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Profit_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: Tổng quan BUY ---
    CreateLabel(INFO_PREFIX+"TotalBuy_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"TotalBuy_Text", "Tổng Quan BUY:", text_x, y, corner, font_size, c_buy);
    CreateLabel(INFO_PREFIX+"TotalBuy_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"TotalBuy_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;
    
    // --- KHỐI DÒNG: Tổng quan SELL ---
    CreateLabel(INFO_PREFIX+"TotalSell_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"TotalSell_Text", "Tổng Quan SELL:", text_x, y, corner, font_size, c_sell);
    CreateLabel(INFO_PREFIX+"TotalSell_Value", "0 (0.00 lots) | +0.00", value_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"TotalSell_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;
    
    // --- KHỐI DÒNG: Kẻ ngang phân cách ---
    CreateLabel(INFO_PREFIX+"SeparatorEnd_Left", "+", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"SeparatorEnd_Line_1", border_segment_1, pipe_x + 9, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"SeparatorEnd_Line_2", border_segment_2, border_segment_2_start_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"SeparatorEnd_Right", "+", end_pipe_x, y, corner, font_size, c_text);
    y += line_height;
    
    // --- KHỐI DÒNG: Trạng thái Bot ---
    CreateLabel(INFO_PREFIX+"Status_Start", "|", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Status_Text", "TRẠNG THÁI BOT:", text_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Status_Value", "KHỞI TẠO", value_x, y, corner, font_size, clrGray);
    CreateLabel(INFO_PREFIX+"Status_End", "|", end_pipe_x, y, corner, font_size, c_text); y += line_height;

    // --- KHỐI DÒNG: Footer ---
    CreateLabel(INFO_PREFIX+"Footer_Left", "+", pipe_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Footer_Line_1", border_segment_1, pipe_x + 9, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Footer_Line_2", border_segment_2, border_segment_2_start_x, y, corner, font_size, c_text);
    CreateLabel(INFO_PREFIX+"Footer_Right", "+", end_pipe_x, y, corner, font_size, c_text);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| CẬP NHẬT DỮ LIỆU ĐỘNG CHO BẢNG THÔNG TIN                           |
//+------------------------------------------------------------------+
void UpdateDisplay(const PositionInfo &positions[])
{
    // --- 1. Thu thập dữ liệu lệnh ---
    // Biến cho các nhóm chi tiết
    int dca_duong_buy_count = 0, dca_duong_sell_count = 0, dca_am_buy_count = 0, dca_am_sell_count = 0;
    double dca_duong_buy_lots = 0, dca_duong_sell_lots = 0, dca_am_buy_lots = 0, dca_am_sell_lots = 0;
    int dca_hang_buy_count = 0, dca_hang_sell_count = 0;
    double dca_hang_buy_lots = 0, dca_hang_sell_lots = 0;
    double dca_duong_buy_profit = 0, dca_duong_sell_profit = 0, dca_am_buy_profit = 0, dca_am_sell_profit = 0;
    double dca_hang_buy_profit = 0, dca_hang_sell_profit = 0;
    
    // Biến tính toán tổng quan cho mỗi phe
    int total_buy_pos = 0, total_sell_pos = 0;
    double total_buy_lots = 0, total_sell_lots = 0;
    double total_buy_profit = 0, total_sell_profit = 0;

    for(int i = 0; i < ArraySize(positions); i++)
    {
        // --- Tính toán tổng quan ---
        if(positions[i].type == POSITION_TYPE_BUY)
        {
            total_buy_pos++;
            total_buy_lots += positions[i].volume;
            total_buy_profit += positions[i].profit_swap;
        }
        else
        {
            total_sell_pos++;
            total_sell_lots += positions[i].volume;
            total_sell_profit += positions[i].profit_swap;
        }
        
        // --- Phân loại chi tiết theo comment ---
        if(StringFind(positions[i].comment, "DCA DƯƠNG") != -1)
        {
            if(positions[i].type == POSITION_TYPE_BUY) { dca_duong_buy_count++; dca_duong_buy_lots += positions[i].volume; dca_duong_buy_profit += positions[i].profit_swap; }
            else { dca_duong_sell_count++; dca_duong_sell_lots += positions[i].volume; dca_duong_sell_profit += positions[i].profit_swap; }
        }
        else if(StringFind(positions[i].comment, "DCA ÂM") != -1)
        {
            if(positions[i].type == POSITION_TYPE_BUY) { dca_am_buy_count++; dca_am_buy_lots += positions[i].volume; dca_am_buy_profit += positions[i].profit_swap; }
            else { dca_am_sell_count++; dca_am_sell_lots += positions[i].volume; dca_am_sell_profit += positions[i].profit_swap; }
        }
        else if(StringFind(positions[i].comment, "DCA HÀNG") != -1)
        {
            if(positions[i].type == POSITION_TYPE_BUY) { dca_hang_buy_count++; dca_hang_buy_lots += positions[i].volume; dca_hang_buy_profit += positions[i].profit_swap; }
            else { dca_hang_sell_count++; dca_hang_sell_lots += positions[i].volume; dca_hang_sell_profit += positions[i].profit_swap; }
        }
    }

    // --- 2. Cập nhật các label ---
    #define UPDATE_LABEL(name, count, lots, profit) \
      ObjectSetString(0, INFO_PREFIX+name, OBJPROP_TEXT, StringFormat("%d (%.2f lots) | %s%.2f", count, lots, (profit >= 0 ? "+" : ""), profit))

    // Cập nhật các dòng chi tiết
    UPDATE_LABEL("DcaDuongBuy_Value", dca_duong_buy_count, dca_duong_buy_lots, dca_duong_buy_profit);
    UPDATE_LABEL("DcaDuongSell_Value", dca_duong_sell_count, dca_duong_sell_lots, dca_duong_sell_profit);
    UPDATE_LABEL("DcaAmBuy_Value", dca_am_buy_count, dca_am_buy_lots, dca_am_buy_profit);
    UPDATE_LABEL("DcaAmSell_Value", dca_am_sell_count, dca_am_sell_lots, dca_am_sell_profit);
    UPDATE_LABEL("DcaHangBuy_Value", dca_hang_buy_count, dca_hang_buy_lots, dca_hang_buy_profit);
    UPDATE_LABEL("DcaHangSell_Value", dca_hang_sell_count, dca_hang_sell_lots, dca_hang_sell_profit);
    
    // Cập nhật 2 dòng tổng quan
    UPDATE_LABEL("TotalBuy_Value", total_buy_pos, total_buy_lots, total_buy_profit);
    UPDATE_LABEL("TotalSell_Value", total_sell_pos, total_sell_lots, total_sell_profit);

    #undef UPDATE_LABEL
    
    // --- 3. Cập nhật thông tin tài khoản ---
    ObjectSetString(0, INFO_PREFIX+"Balance_Value", OBJPROP_TEXT, StringFormat("%.2f", AccountInfoDouble(ACCOUNT_BALANCE)));
    ObjectSetString(0, INFO_PREFIX+"Equity_Value", OBJPROP_TEXT, StringFormat("%.2f", AccountInfoDouble(ACCOUNT_EQUITY)));
    
    double profit = AccountInfoDouble(ACCOUNT_PROFIT);
    ObjectSetString(0, INFO_PREFIX+"Profit_Value", OBJPROP_TEXT, StringFormat("%.2f", profit));
    ObjectSetInteger(0, INFO_PREFIX+"Profit_Value", OBJPROP_COLOR, (profit >= 0) ? clrLimeGreen : clrRed);

    // --- 4. Xác định và cập nhật trạng thái ---
    string status_text = "";
    color status_color;

    if((!inp_enable_buy && !inp_enable_sell) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        status_text = "ĐÃ TẠM DỪNG";
        status_color = clrRed;
    }
    else if(g_is_buy_locked && g_is_sell_locked)
    {
        status_text = "CẢ 2 PHE BỊ KHÓA";
        status_color = clrOrangeRed;
    }
    else if(g_is_buy_locked)
    {
        status_text = "PHE BUY BỊ KHÓA";
        status_color = clrOrange;
    }
    else if(g_is_sell_locked)
    {
        status_text = "PHE SELL BỊ KHÓA";
        status_color = clrOrange;
    }
    else
    {
        status_text = "ĐANG HOẠT ĐỘNG";
        status_color = clrLimeGreen;
    }
    
    ObjectSetString(0, INFO_PREFIX+"Status_Value", OBJPROP_TEXT, status_text);
    ObjectSetInteger(0, INFO_PREFIX+"Status_Value", OBJPROP_COLOR, status_color);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| XÓA BẢNG THÔNG TIN                                                |
//+------------------------------------------------------------------+
void DeleteDisplay()
{
    ObjectsDeleteAll(0, INFO_PREFIX);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| HÀM TIỆN ÍCH ĐỂ TẠO LABEL                                         |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int corner, int font_size, color clr, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
    if(ObjectFind(0, name) != 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
    ObjectSetString(0, name, OBJPROP_FONT, "Courier New");
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
}
//+------------------------------------------------------------------+




