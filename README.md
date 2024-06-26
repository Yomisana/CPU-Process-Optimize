# 如何使用
1. 僅支援 Windows
2. 可以自訂要監控的處理程序名稱，設定好你要限制執行續的處理程序
```
param (
    # 是否開啟顯示當前監控所有進程資訊(預設開啟)
    [switch]$ShowProcessInfo = $true,
    # 是否顯示詳細資料
    [switch]$ShowLiteInfo = $true
)

# 設定要監測的進程名稱(預設:針對 edge 的 webview2)
$processName = "msedgewebview2"
# 這是範例可以限制你已知道的 exe 檔名即可，無須添加副檔名.exe
# $processName = "chrome"

# 設定檢查間隔時間（秒）
# 設定多久(週期)檢查一次執行中的進程
$interval = 5
```
3. 執行 run.bat 或是 run-group.bat
```
- 如果CPU少於64核心，請執行 run.bat
- 如果CPU多於64核心，請執行 run-group.bat

why? 因為 Windows 當 CPU 超過64核心時，會自動分群組，在一般情況下，等於少於64核心的 CPU，意義上是在群組0但微軟就是沒有提到這個問題...
```
# DEMO
![demo](./demo.gif)
