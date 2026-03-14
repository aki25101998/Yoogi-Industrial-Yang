---
description: Compile EA Yoogi Yin Yang bằng MetaEditor64 từ command line (không mở GUI)
---

# Compile EA Yoogi Yin Yang

## Thông tin quan trọng
- **MetaEditor path**: `C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe`
- **Thư mục compile**: `D:\YoogiCompile`
- **Thư mục project**: `d:\Project\yoogi yin yang`
- **Cú pháp đúng**: Dùng `/compile:path` (có dấu hai chấm, KHÔNG có khoảng trắng) và `/log:path`
- **Lưu ý quan trọng**: MetaEditor KHÔNG compile được file có khoảng trắng trong tên. Phải tạo bản copy tạm `YoogiYY.mq5` rồi xoá sau khi compile xong.

## Các bước compile

// turbo-all

### Bước 1: Sync TẤT CẢ files từ project sang thư mục compile

```powershell
[System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Trimming.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Trimming.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Corelogic.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Corelogic.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Globals.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Globals.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Input.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Input.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Indicators.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Indicators.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\ProfitDisplay.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\ProfitDisplay.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\InfoDisplay.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\InfoDisplay.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Security.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Security.mqh")); [System.IO.File]::WriteAllText("D:\YoogiCompile\Include\Panel.mqh", [System.IO.File]::ReadAllText("d:\Project\yoogi yin yang\Include\Panel.mqh")); Write-Host "Synced all include files"
```

### Bước 2: Copy file .mq5 chính (tạo bản tạm không có khoảng trắng)

```powershell
Copy-Item "d:\Project\yoogi yin yang\Yoogi Yin Yang.mq5" "D:\YoogiCompile\YoogiTemp.mq5" -Force; Write-Host "Created temp compile file"
```

> File tạm `YoogiTemp.mq5` sẽ bị xoá sau khi compile xong.

### Bước 3: Compile bằng MetaEditor command line

```powershell
$p = Start-Process -FilePath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" -ArgumentList '/compile:D:\YoogiCompile\YoogiTemp.mq5','/log:D:\YoogiCompile\errors.log' -PassThru; $p | Wait-Process -Timeout 30 -ErrorAction SilentlyContinue; if(!$p.HasExited){$p.Kill()}; Write-Host "Exit:$($p.ExitCode)"
```

### Bước 4: Kiểm tra kết quả compile

```powershell
Get-Content "D:\YoogiCompile\errors.log" -Tail 5
```

Kết quả mong đợi: `Result: 0 errors, X warnings`

Nếu có errors thì đọc toàn bộ log để xem lỗi chi tiết:
```powershell
Get-Content "D:\YoogiCompile\errors.log" | Select-String "error"
```

### Bước 5: Copy .ex5 về thư mục project với đúng tên gốc

```powershell
Copy-Item "D:\YoogiCompile\YoogiTemp.ex5" "d:\Project\yoogi yin yang\Yoogi Yin Yang.ex5" -Force; Write-Host "Copied .ex5 to project"
```

### Bước 6: Dọn dẹp file tạm

```powershell
Remove-Item "D:\YoogiCompile\YoogiTemp.mq5" -Force -ErrorAction SilentlyContinue; Remove-Item "D:\YoogiCompile\YoogiTemp.ex5" -Force -ErrorAction SilentlyContinue; Remove-Item "D:\YoogiCompile\errors.log" -Force -ErrorAction SilentlyContinue; Write-Host "Cleaned up temp files"
```

### Bước 7: Xác nhận file .ex5 đã cập nhật

```powershell
Get-Item "d:\Project\yoogi yin yang\Yoogi Yin Yang.ex5" | Select-Object Name, Length, LastWriteTime
```

## Xử lý lỗi

- **100 errors**: Thường do Include files chưa sync. Chạy lại Bước 1.
- **File bị lock khi sync**: Dùng `[System.IO.File]::WriteAllText()` thay vì `Copy-Item`.
- **MetaEditor mở GUI**: PHẢI dùng `/compile:path` (dấu hai chấm nối liền), KHÔNG dùng `/compile path` (khoảng trắng).
