# 設定要監測的進程名稱
$processName = "msedgewebview2"

# 設定檢查間隔時間（秒）
$interval = 5

# 用於儲存已檢測到的進程 ID 和其使用的核心
$existingProcesses = @()

# 持續監測進程
while ($true) {
    # 獲取當前運行的進程
    $currentProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($currentProcesses) {
        foreach ($process in $currentProcesses) {
            if ($process.Id -notin ($existingProcesses.ProcessId)) {
                # 新進程被檢測到，顯示相關信息
                $usedCores = @()
                $affinity = $process.ProcessorAffinity
                $coreIndex = 0

                # 解析 ProcessorAffinity，找出使用的核心
                while ($affinity -ne 0) {
                    if ($affinity % 2 -eq 1) {
                        $usedCores += $coreIndex
                    }
                    $affinity = [math]::Floor($affinity / 2)
                    $coreIndex++
                }

                # 顯示新進程信息
                Write-Output "偵測到新的進程 ID $($process.Id)，名稱為 $($process.ProcessName)，使用核心: $($usedCores -join ', ')"

                # 將新進程加入到已檢測到的進程列表中
                $existingProcesses += [PSCustomObject]@{
                    ProcessId = $process.Id
                    UsedCores = $usedCores -join ', '
                }
            }
        }
    }

    # 等待指定的間隔時間
    Start-Sleep -Seconds $interval
}
