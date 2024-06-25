# 取得可用的邏輯處理器數量
$processorCount = [Environment]::ProcessorCount

# 初始化一個用於跟踪已使用核心的列表
$usedCores = @()

# 隨機選擇一個未使用的處理器核心
function Get-RandomUnusedCore {
    $availableCores = 0..($processorCount - 1) | Where-Object { $_ -notin $usedCores }
    if ($availableCores.Count -eq 0) {
        throw "沒有可用的核心。"
    }
    $random = New-Object System.Random
    $core = $availableCores[$random.Next(0, $availableCores.Count)]
    $usedCores += $core
    return $core
}

# 獲取正在運行的 msedgewebview2.exe 進程
$processes = Get-Process -Name "msedgewebview2" -ErrorAction SilentlyContinue

# 確認是否有 msedgewebview2.exe 正在運行
if ($processes) {
    foreach ($process in $processes) {
        try {
            # 獲取一個未使用的核心
            $core = Get-RandomUnusedCore

            # 設定 CPU 親和性
            $affinity = [System.IntPtr]::new([math]::Pow(2, $core))

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
