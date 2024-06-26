##########  設定  ##########
param (
    # 是否開啟顯示當前監控所有進程資訊(預設開啟)
    [switch]$ShowProcessInfo = $true,
    # 是否顯示詳細資料
    [switch]$ShowLiteInfo = $true
)

# 設定要監測的進程名稱(預設:針對 edge 的 webview2)
$processName = "msedgewebview2"
# $processName = "chrome"

# 設定檢查間隔時間（秒）
$interval = 5

##########  設定  ##########
# 檢查 MyProcessorGroupInfo 類型是否已經存在
if (-not ([System.Management.Automation.PSTypeName]'MyProcessorGroupInfo').Type) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public static class MyProcessorGroupInfo {
        [DllImport("kernel32.dll")]
        private static extern ushort GetActiveProcessorGroupCount();
    
        [DllImport("kernel32.dll")]
        private static extern ushort GetActiveProcessorCount(ushort GroupNumber);

        public static int GetGroupCount() {
            return GetActiveProcessorGroupCount();
        }

        public static int GetProcessorCount(int groupNumber) {
            if (groupNumber < 0 || groupNumber >= GetActiveProcessorGroupCount()) {
                throw new ArgumentOutOfRangeException("groupNumber", "Group number is out of range.");
            }
            return GetActiveProcessorCount((ushort)groupNumber);
        }
    }
"@
}

# 獲取系統中的群組數量
$groupCount = [MyProcessorGroupInfo]::GetGroupCount()
Write-Output "系統中的CPU群組數量: $groupCount"

# 用於儲存已檢測到的進程 ID 和其使用的核心
$existingProcesses = @{}
$coreUsageCount = @{}

# 隨機選擇一個未被分配的核心，如果所有核心都被分配過，則選擇當前被使用次數最少的核心
function Get-Next-Core {
    $usedCores = $existingProcesses.Values | ForEach-Object { $_.UsedCores } | Select-Object -Unique
    $unusedCores = @()

    for ($group = 0; $group -lt $groupCount; $group++) {
        $groupCores = @(0..([MyProcessorGroupInfo]::GetProcessorCount($group) - 1))
        $unusedCores += $groupCores | Where-Object { $_ -notin $usedCores }
    }

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
    # 獲取當前運行的進程
    $currentProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($currentProcesses) {
        # 獲取當前運行的進程數量
        $currentProcessCount = $currentProcesses.Count
        Write-Output "偵測到 $currentProcessCount 個 $processName 進程運行中"
    }
    else {
        Write-Output "$processName 進程未運行"
    }

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

                # 解析 ProcessorAffinity，找出使用的核心
                $affinityValue = $affinity.ToInt64()  # 將 IntPtr 轉換為長整數

                for ($group = 0; $group -lt $groupCount; $group++) {
                    $groupProcessorCount = [MyProcessorGroupInfo]::GetProcessorCount($group)
                    for ($coreIndex = 0; $coreIndex -lt $groupProcessorCount; $coreIndex++) {
                        if (($affinityValue -shr $coreIndex) -band 1) {
                            $usedCores += $coreIndex + ($group * $groupProcessorCount)
                        }
                    }
                }

                # 獲取下一個核心進行分配
                $nextCore = Get-Next-Core
                
                # 設置進程只使用選定的核心
                $newAffinity = [IntPtr]([int64]1 -shl $nextCore)
                $process.ProcessorAffinity = $newAffinity

                # 更新使用的核心信息
                if (-not $coreUsageCount.ContainsKey($nextCore)) {
                    $coreUsageCount[$nextCore] = 0
                }
                $coreUsageCount[$nextCore]++

                $usedCores = @($nextCore)

                # 將新進程加入到已檢測到的進程字典中
                $existingProcesses[$process.Id] = @{
                    ProcessName = $process.ProcessName
                    UsedCores   = $usedCores
                }

                # 顯示新進程信息
                Write-Output "偵測到新的進程 ID $($process.Id)，名稱為 $($process.ProcessName)，將其設置為使用單一核心:$nextCore" (Get-Date)
            }
        }
    }
    

    # 如果參數設為顯示，則顯示目前已檢測到的所有進程及其信息，並添加當前的日期時間
    if ($ShowProcessInfo) {
        if ($ShowLiteInfo) {
            Write-Output "`n目前已檢測到的進程信息：" (Get-Date)
            $totalProcesses = $existingProcesses.Count
            Write-Output "目前總共有 $totalProcesses 個進程"
        }
        else {
            Write-Output "`n目前已檢測到的進程信息：" (Get-Date)
            $totalProcesses = $existingProcesses.Count
            Write-Output "目前總共有 $totalProcesses 個進程："
            foreach ($processId in $existingProcesses.Keys) {
                $processInfo = $existingProcesses[$processId]
                Write-Output "進程 ID: $processId，名稱: $($processInfo.ProcessName)，使用核心: $($processInfo.UsedCores -join ', ')"
            }
        }
    }

    # 等待指定的間隔時間
    Start-Sleep -Seconds $interval
}