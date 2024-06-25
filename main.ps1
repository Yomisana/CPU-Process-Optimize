# 設定要監測的進程名稱
$processName = "msedgewebview2"

# 設定檢查間隔時間（秒）
$interval = 5

# 取得系統總的邏輯處理器數量
$totalCores = [Environment]::ProcessorCount

# 用於儲存已檢測到的進程 ID 和其使用的核心
$existingProcesses = @{}

# 持續監測進程
while ($true) {
    # 獲取當前運行的進程
    $currentProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if ($currentProcesses) {
        foreach ($process in $currentProcesses) {
            if (-not $existingProcesses.ContainsKey($process.Id)) {
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

                # 從可用核心中隨機選擇一個核心
                $random = New-Object System.Random
                $randomCore = $random.Next(0, $totalCores)

                # 設置進程只使用選定的核心
                $newAffinity = [int][math]::Pow(2, $randomCore)
                $process.ProcessorAffinity = [IntPtr]$newAffinity

                # 更新使用的核心信息
                $usedCores = @($randomCore)

                # 將新進程加入到已檢測到的進程字典中
                $existingProcesses[$process.Id] = @{
                    ProcessName = $process.ProcessName
                    UsedCores = $usedCores
                }

                # 顯示新進程信息
                Write-Output "偵測到新的進程 ID $($process.Id)，名稱為 $($process.ProcessName)，將其設置為使用單一核心:$randomCore"
            }
        }
    }

    # 顯示目前已檢測到的所有進程及其信息
    Write-Output "`n目前已檢測到的進程信息："
    foreach ($processId in $existingProcesses.Keys) {
        $processInfo = $existingProcesses[$processId]
        Write-Output "進程 ID: $processId，名稱: $($processInfo.ProcessName)，使用核心: $($processInfo.UsedCores -join ', ')"
    }

    # 等待指定的間隔時間
    Start-Sleep -Seconds $interval
}