//+------------------------------------------------------------------+
//|                                                ProfitDisplay.mqh   |
//|                                                 Yoogi Yin Yang   |
//|                 --- TỆP HIỂN THỊ KÉT SẮT & NGÂN SÁCH ---           |
//|         (Phiên bản 39.7 - Cập nhật Logic Màu động có Điều kiện)    |
//+------------------------------------------------------------------+

//--- Khai báo tên đối tượng cho các label
#define PROFIT_PREFIX "YYY_ProfitDisp_"

//--- Khai báo các hàm sẽ được gọi từ tệp .mq5 chính
void CreateProfitDisplay();
void UpdateProfitDisplay(); 
void DeleteProfitDisplay();

//--- Khai báo hàm nội bộ
void CreateProfitLabel(string name, string text, int x, int y, color clr, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT);

//+------------------------------------------------------------------+
//| TẠO GIAO DIỆN BẢNG THÔNG TIN                                      |
//+------------------------------------------------------------------+
void CreateProfitDisplay()
{
   // --- Các giá trị cố định cho vị trí và kích thước ---
   const int corner      = CORNER_RIGHT_LOWER;
   const int x_offset    = 50; 
   const int y_offset    = 50; 
   const int font_size   = 20;
   const int line_height = font_size + 4;
   
   int y = y_offset;

   // --- KHỐI QUỸ ALL ---
   CreateProfitLabel(PROFIT_PREFIX + "FundBuyText", "Quy All:", x_offset + 135, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "FundBuyValue", "0.00 USD", x_offset + 70, y, clrGold, ANCHOR_LEFT);
   y += line_height;
   
   // --- KHỐI LỢI NHUẬN THỰC TẾ ---
   CreateProfitLabel(PROFIT_PREFIX + "Separator2", "---------------------------------", x_offset + 105, y, clrWhite, ANCHOR_CENTER);
   y += line_height;

   CreateProfitLabel(PROFIT_PREFIX + "RealProfitWText", "Profit W:", x_offset + 144, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "RealProfitWValue", "0.00 USD", x_offset + 70, y, clrCyan, ANCHOR_LEFT);
   y += line_height;

   CreateProfitLabel(PROFIT_PREFIX + "RealProfitDText", "Profit D:", x_offset + 148, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "RealProfitDValue", "0.00 USD", x_offset + 70, y, clrCyan, ANCHOR_LEFT);
   y += line_height;
   
   // --- Dòng Tiêu đề ---
   CreateProfitLabel(PROFIT_PREFIX + "Header", "--- LỢI NHUẬN & QUỸ ---", x_offset + 105, y, clrWhite, ANCHOR_CENTER);
   
   ChartRedraw();
}


//+------------------------------------------------------------------+
//| CẬP NHẬT DỮ LIỆU ĐỘNG                                            |
//+------------------------------------------------------------------+
void UpdateProfitDisplay()
{
   // --- LẤY VÀ HIỂN THỊ LỢI NHUẬN THỰC TẾ ---
   double realized_day_profit = GetRealizedProfitForPeriod(GetStartOfDay());
   double realized_week_profit = GetRealizedProfitForPeriod(GetFinancialWeekStart());

   ObjectSetString(0, PROFIT_PREFIX + "RealProfitDValue", OBJPROP_TEXT, StringFormat("%.2f USD", realized_day_profit));
   ObjectSetString(0, PROFIT_PREFIX + "RealProfitWValue", OBJPROP_TEXT, StringFormat("%.2f USD", realized_week_profit));
   
   color real_profit_d_color = (realized_day_profit >= 0) ? clrLimeGreen : clrRed;
   color real_profit_w_color = (realized_week_profit >= 0) ? clrLimeGreen : clrRed;
   ObjectSetInteger(0, PROFIT_PREFIX + "RealProfitDValue", OBJPROP_COLOR, real_profit_d_color);
   ObjectSetInteger(0, PROFIT_PREFIX + "RealProfitWValue", OBJPROP_COLOR, real_profit_w_color);

   // --- CẬP NHẬT QUỸ ALL ---
   if(inp_take_profit_usd > 0)
   {
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyText", OBJPROP_TEXT, "Quy All:");
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_fund_all));
      
      color fund_all_color = (g_fund_all > 0) ? clrLimeGreen : (g_fund_all < 0 ? clrRed : clrGainsboro);
      ObjectSetInteger(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_COLOR, fund_all_color);
   }
   else
   {
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyText", OBJPROP_TEXT, " ");
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_TEXT, " ");
   }
}


//+------------------------------------------------------------------+
//| XÓA BẢNG THÔNG TIN                                               |
//+------------------------------------------------------------------+
void DeleteProfitDisplay()
{
   ObjectsDeleteAll(0, PROFIT_PREFIX);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| HÀM TIỆN ÍCH ĐỂ TẠO LABEL                                        |
//+------------------------------------------------------------------+
void CreateProfitLabel(string name, string text, int x, int y, color clr, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT)
{
   const int corner      = CORNER_RIGHT_LOWER;
   const int font_size   = 11;

   if(ObjectFind(0, name) != 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}




