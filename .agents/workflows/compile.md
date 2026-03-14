---
description: Compile EA Yoogi Yin Yang bằng MetaEditor64 từ command line (không mở GUI)
---

## Steps

// turbo-all

1. Delete old log file:
```powershell
Remove-Item "d:\Project\yoogi yin yang\YoogiYY.log" -Force -ErrorAction SilentlyContinue
```

2. Compile EA:
```powershell
Start-Process -FilePath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" -ArgumentList '/compile:"d:\Project\yoogi yin yang\Yoogi Yin Yang.mq5"','/log:"d:\Project\yoogi yin yang\YoogiYY.log"','/inc:"C:\Users\Admin\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06\MQL5"' -Wait -NoNewWindow
```

3. Check compile result:
```powershell
Get-Content "d:\Project\yoogi yin yang\YoogiYY.log" -Encoding Unicode -ErrorAction SilentlyContinue | Select-Object -Last 5
```

4. Verify .ex5 file was updated:
```powershell
Get-ChildItem "d:\Project\yoogi yin yang\*.ex5" | Select-Object FullName,LastWriteTime,Length
```
