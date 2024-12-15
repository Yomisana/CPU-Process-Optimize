# How to Use
- Only supports Windows.
- You can customize the process name to monitor, set the processes you want to limit.

```powershell
param (
    # Whether to display the current monitoring of all process information (default is enabled)
    [switch]$ShowProcessInfo = $true,
    # Whether to show detailed information
    [switch]$ShowLiteInfo = $true
)

# Set the process name to monitor (default: targeting edge's webview2)
$processName = "msedgewebview2"
# This is an example; you can limit any known exe file name without adding the .exe extension
# $processName = "chrome"

# Set the check interval time (in seconds)
# Configure how often (as a cycle) to check running processes
$interval = 5
```

- Execute run.bat or run-group.bat
```
- If the CPU has less than 64 cores, please execute run.bat
- If the CPU has more than 64 cores, please execute run-group.bat
```
> :point_right: Why? Because when the CPU exceeds 64 cores, Windows automatically groups them. In general, this means that a CPU with less than 64 cores is essentially in group 0, but Microsoft has not mentioned this issue...

# DEMO
![demo](./demo.gif)
