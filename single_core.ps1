# 取得可用的邏輯處理器數量
$processorCount = [Environment]::ProcessorCount

# 隨機選擇一個處理器核心 (0 到 processorCount - 1)
$random = New-Object System.Random
$core = $random.Next(0, $processorCount)

# 設定 CPU 親和性
$affinity = [System.IntPtr]::new([math]::Pow(2, $core))

# 獲取正在運行的 msedgewebview2.exe 進程
$processes = Get-Process -Name "msedgewebview2" -ErrorAction SilentlyContinue

# 確認是否有 msedgewebview2.exe 正在運行
if ($processes) {
    foreach ($process in $processes) {
        try {
            # 設置 CPU 親和性
            $process.ProcessorAffinity = $affinity
            Write-Output "已成功將進程 ID $($process.Id) 設置為單核心 $core"
        } catch {
            Write-Error "無法設置進程 ID $($process.Id) 的 CPU 親和性: $_"
        }
    }
} else {
    Write-Error "未找到正在運行的 msedgewebview2.exe 進程"
}
