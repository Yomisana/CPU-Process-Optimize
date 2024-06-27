param (
    [switch]$ShowProcessInfo = $true
)

# 設定要監測的進程名稱(預設:針對 edge 的 webview2)
$processName = "msedgewebview2"
# $processName = "chrome"

# 設定檢查間隔時間（秒）
$interval = 30

# 取得系統總的邏輯處理器數量
$totalCores = [Environment]::ProcessorCount

# 用於儲存已檢測到的進程 ID 和其使用的核心
$existingProcesses = @{}
$coreUsageCount = @{}

# 隨機選擇一個未被分配的核心，如果所有核心都被分配過，則選擇當前被使用次數最少的核心
function Get-Next-Core {
    $usedCores = $existingProcesses.Values | ForEach-Object { $_.UsedCores } | Select-Object -Unique
    $unusedCores = @(0..($totalCores - 1)) | Where-Object { $_ -notin $usedCores }

    if ($unusedCores.Count -gt 0) {
        return $unusedCores | Get-Random
    }
    else {
        $minUsage = $coreUsageCount.Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $leastUsedCores = $coreUsageCount.Keys | Where-Object { $coreUsageCount[$_] -eq $minUsage }
        return $leastUsedCores | Get-Random
    }
}

# 持續監測進程
while ($true) {
    $currentProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
    $currentProcessIds = $currentProcesses | ForEach-Object { $_.Id }
    $existingProcessIds = @($existingProcesses.Keys)

    foreach ($processId in $existingProcessIds) {
        if (-not ($currentProcessIds -contains $processId)) {
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
                $usedCores = @()
                $affinity = $process.ProcessorAffinity
                $coreIndex = 0

                while ($affinity -ne 0) {
                    if ($affinity % 2 -eq 1) {
                        $usedCores += $coreIndex
                    }
                    $affinity = [math]::Floor($affinity / 2)
                    $coreIndex++
                }

                $nextCore = Get-Next-Core
                $newAffinity = [int][math]::Pow(2, $nextCore)
                $process.ProcessorAffinity = [IntPtr]$newAffinity

                if (-not $coreUsageCount.ContainsKey($nextCore)) {
                    $coreUsageCount[$nextCore] = 0
                }
                $coreUsageCount[$nextCore]++
                $usedCores = @($nextCore)

                $existingProcesses[$process.Id] = @{
                    ProcessName = $process.ProcessName
                    UsedCores   = $usedCores
                }

                Write-Output "偵測到新的進程 ID $($process.Id)，名稱為 $($process.ProcessName)，將其設置為使用單一核心:$nextCore" (Get-Date)
            }
        }
    }

    if ($ShowProcessInfo) {
        Write-Output "`n目前已檢測到的進程信息：" (Get-Date)
        $totalProcesses = $existingProcesses.Count
        Write-Output "目前總共有 $totalProcesses 個進程："
        foreach ($processId in $existingProcesses.Keys) {
            $processInfo = $existingProcesses[$processId]
            Write-Output "進程 ID: $processId，名稱: $($processInfo.ProcessName)，使用核心: $($processInfo.UsedCores -join ', ')"
        }
    }

    Start-Sleep -Seconds $interval
}