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

   // --- KHỐI NGÂN SÁCH ---
   CreateProfitLabel(PROFIT_PREFIX + "WeekBudgetText", "Ngân sách Tuần:", x_offset + 90, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "WeekBudgetValue", "0.00 USD", x_offset + 70, y, clrGainsboro, ANCHOR_LEFT);
   y += line_height;
   
   CreateProfitLabel(PROFIT_PREFIX + "WeekTrimmedText", "Đã tỉa Tuần:", x_offset + 122, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "WeekTrimmedValue", "0.00 USD", x_offset + 70, y, clrGainsboro, ANCHOR_LEFT);
   y += line_height;

   CreateProfitLabel(PROFIT_PREFIX + "DayBudgetText", "Ngân sách Ngày:", x_offset + 90, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "DayBudgetValue", "0.00 USD", x_offset + 70, y, clrGainsboro, ANCHOR_LEFT);
   y += line_height;

   CreateProfitLabel(PROFIT_PREFIX + "DayTrimmedText", "Đã tỉa Ngày:", x_offset + 122, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "DayTrimmedValue", "0.00 USD", x_offset + 70, y, clrGainsboro, ANCHOR_LEFT);
   y += line_height;

   // --- KHỐI QUỸ TỈA LỆNH ---
   CreateProfitLabel(PROFIT_PREFIX + "FundBuyText", "Quy Buy:", x_offset + 135, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "FundBuyValue", "0.00 USD", x_offset + 70, y, clrGold, ANCHOR_LEFT);
   y += line_height;

   CreateProfitLabel(PROFIT_PREFIX + "FundSellText", "Quy Sell:", x_offset + 130, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "FundSellValue", "0.00 USD", x_offset + 70, y, clrGold, ANCHOR_LEFT);
   y += line_height;
   
   // Dòng phân cách
   CreateProfitLabel(PROFIT_PREFIX + "Separator1", "---------------------------------", x_offset + 105, y, clrWhite, ANCHOR_CENTER);
   y += line_height;

   // --- KHỐI KÉT SẮT ---
   CreateProfitLabel(PROFIT_PREFIX + "WeekText", "Két Sắt Tuần:", x_offset + 112, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "WeekValue", "0.00 USD", x_offset + 70, y, clrGold, ANCHOR_LEFT);
   y += line_height;
   
   CreateProfitLabel(PROFIT_PREFIX + "DayText", "Két Sắt Ngày:", x_offset + 112, y, clrWhite, ANCHOR_RIGHT);
   CreateProfitLabel(PROFIT_PREFIX + "DayValue", "0.00 USD", x_offset + 70, y, clrGold, ANCHOR_LEFT);
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
   CreateProfitLabel(PROFIT_PREFIX + "Header", "--- KÉT SẮT & NGÂN SÁCH ---", x_offset + 105, y, clrWhite, ANCHOR_CENTER);
   
   ChartRedraw();
}


//+------------------------------------------------------------------+
//| CẬP NHẬT DỮ LIỆU ĐỘNG                                            |
//+------------------------------------------------------------------+
void UpdateProfitDisplay()
{
   // --- BƯỚC 1: LẤY VÀ HIỂN THỊ LỢI NHUẬN THỰC TẾ ---
   double realized_day_profit = GetRealizedProfitForPeriod(GetStartOfDay());
   double realized_week_profit = GetRealizedProfitForPeriod(GetFinancialWeekStart());

   ObjectSetString(0, PROFIT_PREFIX + "RealProfitDValue", OBJPROP_TEXT, StringFormat("%.2f USD", realized_day_profit));
   ObjectSetString(0, PROFIT_PREFIX + "RealProfitWValue", OBJPROP_TEXT, StringFormat("%.2f USD", realized_week_profit));
   
   color real_profit_d_color = (realized_day_profit >= 0) ? clrLimeGreen : clrRed;
   color real_profit_w_color = (realized_week_profit >= 0) ? clrLimeGreen : clrRed;
   ObjectSetInteger(0, PROFIT_PREFIX + "RealProfitDValue", OBJPROP_COLOR, real_profit_d_color);
   ObjectSetInteger(0, PROFIT_PREFIX + "RealProfitWValue", OBJPROP_COLOR, real_profit_w_color);

   // --- BƯỚC 2: XỬ LÝ HIỂN THỊ DỰA TRÊN TRẠNG THÁI KHẨN CẤP ---
   double display_safe_day;
   double display_budget_day;
   double display_trimmed_day;

   if(g_current_emergency_mode == EM_WEEK)
   {
       display_safe_day = 0.0;
       display_budget_day = 0.0;
       display_trimmed_day = 0.0;
   }
   else
   {
       display_safe_day = g_safe_day;
       display_budget_day = g_budget_day;
       display_trimmed_day = g_trimmed_day;
   }
   
   // --- BƯỚC 3: CẬP NHẬT GIÁ TRỊ LÊN CÁC LABEL ---
   ObjectSetString(0, PROFIT_PREFIX + "DayValue", OBJPROP_TEXT, StringFormat("%.2f USD", display_safe_day));
   ObjectSetString(0, PROFIT_PREFIX + "DayBudgetValue", OBJPROP_TEXT, StringFormat("%.2f USD", display_budget_day));
   ObjectSetString(0, PROFIT_PREFIX + "DayTrimmedValue", OBJPROP_TEXT, StringFormat("%.2f USD", display_trimmed_day));
   
   ObjectSetString(0, PROFIT_PREFIX + "DayText", OBJPROP_TEXT, "Két Sắt Ngày:");
   ObjectSetString(0, PROFIT_PREFIX + "DayBudgetText", OBJPROP_TEXT, "Ngân sách Ngày:");

   ObjectSetString(0, PROFIT_PREFIX + "WeekValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_safe_week));
   
   // --- CẬP NHẬT QUỸ TỈA LỆNH ---
   if(inp_take_profit_usd > 0)
   {
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyText", OBJPROP_TEXT, "Quy All:");
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_fund_all));
      ObjectSetString(0, PROFIT_PREFIX + "FundSellText", OBJPROP_TEXT, " ");
      ObjectSetString(0, PROFIT_PREFIX + "FundSellValue", OBJPROP_TEXT, " ");
      
      color fund_all_color = (g_fund_all > 0) ? clrLimeGreen : (g_fund_all < 0 ? clrRed : clrGainsboro);
      ObjectSetInteger(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_COLOR, fund_all_color);
   }
   else
   {
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyText", OBJPROP_TEXT, "Quy Buy:");
      ObjectSetString(0, PROFIT_PREFIX + "FundSellText", OBJPROP_TEXT, "Quy Sell:");
      ObjectSetString(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_fund_trim_buy));
      ObjectSetString(0, PROFIT_PREFIX + "FundSellValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_fund_trim_sell));
      
      color fund_buy_color = (g_fund_trim_buy > 0) ? clrLimeGreen : clrGainsboro;
      color fund_sell_color = (g_fund_trim_sell > 0) ? clrLimeGreen : clrGainsboro;
      ObjectSetInteger(0, PROFIT_PREFIX + "FundBuyValue", OBJPROP_COLOR, fund_buy_color);
      ObjectSetInteger(0, PROFIT_PREFIX + "FundSellValue", OBJPROP_COLOR, fund_sell_color);
   }
   ObjectSetString(0, PROFIT_PREFIX + "WeekBudgetValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_budget_week));
   ObjectSetString(0, PROFIT_PREFIX + "WeekTrimmedValue", OBJPROP_TEXT, StringFormat("%.2f USD", g_trimmed_week));

   // --- BƯỚC 4: CẬP NHẬT MÀU SẮC DỰA TRÊN LOGIC MỚI ---
   color safe_day_color, budget_day_color, trimmed_day_color;

   if(g_current_emergency_mode == EM_WEEK)
   {
       // Trường hợp ngoại lệ: Chế độ Tuần được ưu tiên, tất cả mục của Ngày về màu trắng
       safe_day_color = clrWhite;
       budget_day_color = clrWhite;
       trimmed_day_color = clrWhite;
   }
   else
   {
       // Trường hợp bình thường: Logic màu của Ngày giống hệt của Tuần
       safe_day_color = (g_safe_day < 0) ? clrRed : clrGold;
       budget_day_color = (g_budget_day < 0) ? clrRed : (g_budget_day > 0 ? clrLimeGreen : clrGainsboro);
       trimmed_day_color = (g_trimmed_day > 0) ? clrOrange : clrGainsboro;
   }

   // Áp dụng màu cho các mục của Ngày
   ObjectSetInteger(0, PROFIT_PREFIX + "DayValue", OBJPROP_COLOR, safe_day_color);
   ObjectSetInteger(0, PROFIT_PREFIX + "DayBudgetValue", OBJPROP_COLOR, budget_day_color);
   ObjectSetInteger(0, PROFIT_PREFIX + "DayTrimmedValue", OBJPROP_COLOR, trimmed_day_color);

   // Giữ nguyên logic màu cho các mục của Tuần
   color safe_week_color = (g_safe_week < 0) ? clrRed : clrGold;
   ObjectSetInteger(0, PROFIT_PREFIX + "WeekValue", OBJPROP_COLOR, safe_week_color);

   color budget_week_color = (g_budget_week < 0) ? clrRed : (g_budget_week > 0 ? clrLimeGreen : clrGainsboro);
   ObjectSetInteger(0, PROFIT_PREFIX + "WeekBudgetValue", OBJPROP_COLOR, budget_week_color);

   color trimmed_week_color = (g_trimmed_week > 0) ? clrOrange : clrGainsboro;
   ObjectSetInteger(0, PROFIT_PREFIX + "WeekTrimmedValue", OBJPROP_COLOR, trimmed_week_color);
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




