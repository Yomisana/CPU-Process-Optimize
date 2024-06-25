param (
    # 是否開啟顯示當前監控所有進程資訊(預設開啟)
    [switch]$ShowProcessInfo = $true
    # [switch]$ShowProcessInfo = $false
)

# 設定要監測的進程名稱(預設:針對 edge 的 webview2)
$processName = "msedgewebview2"
# $processName = "chrome"

# 設定檢查間隔時間（秒）
$interval = 5

# 取得系統總的邏輯處理器數量
$totalCores = [Environment]::ProcessorCount

# 用於儲存已檢測到的進程 ID 和其使用的核心
$existingProcesses = @{}
$coreUsageCount = @{}

# 隨機選擇一個未被分配的核心，如果所有核心都被分配過，則選擇當前被使用次數最少的核心
function Get-Next-Core {
    $usedCores = $existingProcesses.Values | ForEach-Object { $_.UsedCores } | Select-Object -Unique
    $unusedCores = @(0..($totalCores-1)) | Where-Object { $_ -notin $usedCores }

    if ($unusedCores.Count -gt 0) {
        return $unusedCores | Get-Random
    } else {
        $minUsage = $coreUsageCount.Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $leastUsedCores = $coreUsageCount.Keys | Where-Object { $coreUsageCount[$_] -eq $minUsage }
        return $leastUsedCores | Get-Random
    }
}

# 持續監測進程
while ($true) {
    # 獲取當前運行的進程
    $currentProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue

    $currentProcessIds = $currentProcesses | ForEach-Object { $_.Id }

    # 複製一份現有的進程ID列表以進行迭代
    $existingProcessIds = @($existingProcesses.Keys)

    # 檢查已存在的進程是否依然運行
    foreach ($processId in $existingProcessIds) {
        if (-not ($currentProcessIds -contains $processId)) {
            # 移除已經關閉的進程
            $coreToRemove = $existingProcesses[$processId].UsedCores
            foreach ($core in $coreToRemove) {
                $coreUsageCount[$core]--
            }

            $existingProcesses.Remove($processId) | Out-Null
            Write-Output "進程 ID $processId 已關閉，從列表中移除" (Get-Date)
        }
    }

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

                # 獲取下一個核心進行分配
                $nextCore = Get-Next-Core

                # 設置進程只使用選定的核心
                $newAffinity = [int][math]::Pow(2, $nextCore)
                $process.ProcessorAffinity = [IntPtr]$newAffinity

                # 更新使用的核心信息
                if (-not $coreUsageCount.ContainsKey($nextCore)) {
                    $coreUsageCount[$nextCore] = 0
                }
                $coreUsageCount[$nextCore]++

                $usedCores = @($nextCore)

                # 將新進程加入到已檢測到的進程字典中
                $existingProcesses[$process.Id] = @{
                    ProcessName = $process.ProcessName
                    UsedCores = $usedCores
                }

                # 顯示新進程信息
                Write-Output "偵測到新的進程 ID $($process.Id)，名稱為 $($process.ProcessName)，將其設置為使用單一核心:$nextCore" (Get-Date)
            }
        }
    }

    # 如果參數設為顯示，則顯示目前已檢測到的所有進程及其信息，並添加當前的日期時間
    if ($ShowProcessInfo) {
        Write-Output "`n目前已檢測到的進程信息：" (Get-Date)
        $totalProcesses = $existingProcesses.Count
        Write-Output "目前總共有 $totalProcesses 個進程："
        foreach ($processId in $existingProcesses.Keys) {
            $processInfo = $existingProcesses[$processId]
            Write-Output "進程 ID: $processId，名稱: $($processInfo.ProcessName)，使用核心: $($processInfo.UsedCores -join ', ')"
        }
    }

    # 等待指定的間隔時間
    Start-Sleep -Seconds $interval
}