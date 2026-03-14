//+------------------------------------------------------------------+
//|                                                      Security.mqh  |
//|                     --- TAP KIEM TRA BAN QUYEN EA ---             |
//|       (Phien ban 38.9 - Toi uu nhan dien Loi Cau hinh)           |
//+------------------------------------------------------------------+

// Duong link Google Apps Script cua ban
#define G_SCRIPT_URL "https://script.google.com/macros/s/AKfycbwyx5wr6kP9_zhzKKPUYuXswbRkItP28mCbWLN9wQJinq8KLCdoPWC1r8SVemuR4eu4/exec"

// Ham tien ich de chuyen doi chuoi DD-MM-YYYY hoac YYYY-MM-DD thanh kieu datetime
datetime StringToDate(string date_str)
{
   // Thay the '-' bang '.' de phu hop voi dinh dang cua MQL5
   StringReplace(date_str, "-", ".");
   return StringToTime(date_str + " 00:00:00");
}

//+------------------------------------------------------------------+
//| Ham kiem tra giay phep (Phan quyen Demo/Real)                    |
//+------------------------------------------------------------------+
bool CheckLicense()
{
   // --- BUOC 1: KIEM TRA MOI TRUONG GIAO DICH ---
   // bool isTester   = (bool)MQLInfoInteger(MQL_TESTER); // Can cu vao MQLInfoInteger
   // long accMode    = AccountInfoInteger(ACCOUNT_TRADE_MODE);

   // --- BUOC 2: XU LY NHOM TAI KHOAN MIEN PHI ---
   // Neu dang Backtest hoac la Tai khoan Demo/Contest
   if (MQLInfoInteger(MQL_TESTER) || 
       AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO || 
       AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_CONTEST)
   {
       // In thong bao xac nhan hoat dong mien phi
       Print("License: Detected Demo/Tester mode. Full access granted (Mien phi).");
       return true; // Cho phep chay luon (Return True)
   }

   // --- BUOC 3: XU LY NHOM TAI KHOAN REAL (BAT BUOC KIEM TRA LICENSE) ---
   // (accMode == ACCOUNT_TRADE_MODE_REAL)
   long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
   if(account_number <= 0)
   {
       string msg = "Khong the doc so tai khoan MT5.\n\nVui long khoi dong lai phan mem MetaTrader 5.";
       MessageBox(msg, "Loi Khoi Tao", MB_OK | MB_ICONERROR);
       return false;
   }

   string url = G_SCRIPT_URL + "?account=" + (string)account_number;
   
   char post_data[];
   char result[];
   string result_headers;
   int timeout = 5000; // 5 giay
   
   ResetLastError();
   int res = WebRequest("GET", url, NULL, timeout, post_data, result, result_headers);
   
   if(res == -1)
   {
       int error_code = GetLastError();
       string msg;
       string cap = "Loi Cau Hinh";
       
       // <<< THAY DOI: Kiem tra ca hai ma loi 4060 va 4014 >>>
       if(error_code == 4060 || error_code == 4014) 
       {
           msg = "Loi: Ban chua cho phep EA ket noi Internet.\n\n"
                 "--> Cach sua:\n"
                 "1. Mo Tool > Options > Expert Advisors.\n"
                 "2. Tich vao o 'Allow WebRequest for listed URL'.\n"
                 "3. Them dia chi: script.google.com";
           MessageBox(msg, cap, MB_OK | MB_ICONINFORMATION);
       }
       else
       {
           msg = "Loi: Khong the ket noi den server xac thuc.\n\n"
                 "--> Nguyen nhan:\n"
                 "- Mat ket noi Internet.\n"
                 "- Server ban quyen dang bao tri.\n\n"
                 "--> Cach sua:\n"
                 "1. Mo Tool > Options > Expert Advisors.\n"
                 "2. Tich vao o 'Allow WebRequest for listed URL'.\n"
                 "3. Them dia chi: script.google.com";
           MessageBox(msg, "Loi Ket Noi", MB_OK | MB_ICONERROR);
       }
       return false;
   }
   else if(res == 200) // 200 = OK
   {
       string server_response = CharArrayToString(result);
       
       string parts[];
       if(StringSplit(server_response, '|', parts) < 2)
       {
            string msg = "Loi: Du lieu server tra ve khong dung dinh dang.\n\n"
                         "Vui long lien he nha cung cap de duoc ho tro.";
            MessageBox(msg, "Loi Phan Hoi Server", MB_OK | MB_ICONERROR);
            return false;
       }

       string status = parts[0];
       string deadline_str = parts[1];

       // 1. KIEM TRA "CONG TAC NGUOI CHET" TRUCC TIEN
       if(deadline_str != "NONE")
       {
           datetime deadline_date = StringToDate(deadline_str);
           datetime now = TimeTradeServer();

           if (now > deadline_date)
           {
               MessageBox("Chuc mung! EA da duoc kich hoat che do su dung mien phi vinh vien.", "Kich Hoat Mien Phi", MB_OK | MB_ICONINFORMATION);
               return true;
           }
       }
       
       // 2. NEU CONG TAC CHUA KICH HOAT, KIEM TRA BAN QUYEN NHU BINH THUONG
       if(status == "VALID")
       {
           return true;
       }
       else
       {
           string msg = "Tai khoan #" + (string)account_number + " chua duoc cap phep hoat dong.\n\n"
                        "Vui long lien he Zalo | Telegram: Admin\n\n" 
                        "de duoc kich hoat";
           MessageBox(msg, "Kich Hoat That Bai", MB_OK | MB_ICONWARNING);
           return false;
       }
   }
   
    string msg = "Loi: Server xac thuc khong phan hoi dung cach (Ma HTTP: " + (string)res + ").\n\n"
                 "Day la loi tu phia server, vui long lien he nha cung cap de duoc ho tro.";
    MessageBox(msg, "Loi Phan Hoi Server", MB_OK | MB_ICONERROR);
    return false;
}


