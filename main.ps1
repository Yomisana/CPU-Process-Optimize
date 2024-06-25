# 設定要監測的進程名稱
$processName = "msedgewebview2"

# 設定檢查間隔時間（秒）
$interval = 5

# 用於儲存已檢測到的進程 ID
$existingProcessIds = @()

# 持續監測進程
while ($true) {
    # 獲取當前運行的進程
    $currentProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($currentProcesses) {
        foreach ($process in $currentProcesses) {
            if ($process.Id -notin $existingProcessIds) {
                # 新進程被檢測到，通知用戶
                Write-Output "偵測到新的進程 ID $($process.Id)，名稱為 $($process.ProcessName)"

                # 將新進程 ID 添加到已檢測到的進程列表中
                $existingProcessIds += $process.Id
            }
        }
    }

    # 等待指定的間隔時間
    Start-Sleep -Seconds $interval
}
