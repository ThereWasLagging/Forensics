if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run PowerShell as Administrator!" -ForegroundColor Red
    Pause; exit
}

Write-Host "--- Forensics Cleaner ---" -ForegroundColor Cyan

Write-Host "[1] Clearing Temporary Files..." -ForegroundColor Yellow
$TempFolders = @("$env:TEMP\*", "C:\Windows\Temp\*")
foreach ($path in $TempFolders) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[2] Clearing Prefetch..." -ForegroundColor Yellow
Remove-Item -Path "C:\Windows\Prefetch\*.pf" -Force -ErrorAction SilentlyContinue

Write-Host "[3] Clearing Recent Items & JumpLists..." -ForegroundColor Yellow
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -ErrorAction SilentlyContinue

Write-Host "[4] Clearing Registry Artifacts..." -ForegroundColor Yellow
$RegArtifacts = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.Windows.App-Switch",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskManager"
)
foreach ($key in $RegArtifacts) { if (Test-Path $key) { Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue } }

Write-Host "[5] Clearing MuiCache..." -ForegroundColor Yellow
$Mui = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
if (Test-Path $Mui) { Remove-Item $Mui -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[6] Clearing AppCompatCache (ShimCache)..." -ForegroundColor Yellow
$RegAppCompat = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache",
    "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"
)
foreach ($key in $RegAppCompat) { if (Test-Path $key) { Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue } }

Write-Host "[7] Clearing BAM..." -ForegroundColor Yellow
$Bam = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
if (Test-Path $Bam) { Remove-Item $Bam -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[8] Clearing PCA Events..." -ForegroundColor Yellow
Remove-Item "C:\Windows\AppCompat\Programs\PcaEvents.evtx" -Force -ErrorAction SilentlyContinue

Write-Host "[9] Clearing ActivitiesCache (Timeline)..." -ForegroundColor Yellow
Stop-Service -Name "CDPSvc" -Force -ErrorAction SilentlyContinue
$ActivitiesPath = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"
if (Test-Path $ActivitiesPath) {
    Get-ChildItem -Path $ActivitiesPath -Recurse -Include "ActivitiesCache.db*" | Remove-Item -Force -ErrorAction SilentlyContinue
}
Start-Service -Name "CDPSvc" -ErrorAction SilentlyContinue

Write-Host "[10] Flushing DNS Cache..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null

Write-Host "[11] Clearing Task Scheduler Logs..." -ForegroundColor Yellow
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" -ErrorAction SilentlyContinue | ForEach-Object {
    [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog("Microsoft-Windows-TaskScheduler/Operational")
}
Remove-Item "C:\Windows\System32\winevt\Logs\Microsoft-Windows-TaskScheduler*Operational.evtx" -Force -ErrorAction SilentlyContinue

Write-Host "[12] Clearing SRUM..." -ForegroundColor Yellow
Stop-Service -Name "srualsvc" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\System32\SRU\*" -Force -ErrorAction SilentlyContinue
Start-Service -Name "srualsvc" -ErrorAction SilentlyContinue

Write-Host "[13] Clearing PowerShell History..." -ForegroundColor Yellow
$History = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $History) { Remove-Item $History -Force -ErrorAction SilentlyContinue }

Write-Host "[14] Deleting USN Journal..." -ForegroundColor Yellow
fsutil usn deletejournal /d C: | Out-Null

Write-Host "[15] Clearing Nvidia Timestamps..." -ForegroundColor Yellow
$Nv = "HKCU:\Software\NVIDIA Corporation\Global\NVTweak\NvAppTimestamps"
if (Test-Path $Nv) { Remove-Item $Nv -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[16] Clearing All Event Logs..." -ForegroundColor Yellow
Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
    try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName) } catch {}
}

Write-Host "[17] Clearing Amcache..." -ForegroundColor Yellow
$AmcachePath = "C:\Windows\AppCompat\Programs\Amcache.hve"
if (Test-Path $AmcachePath) {
    takeown /f $AmcachePath /a | Out-Null
    icacls $AmcachePath /grant administrators:F | Out-Null
    Remove-Item $AmcachePath -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\AppCompat\Programs\Amcache.hve.tmp*" -Force -ErrorAction SilentlyContinue
}

Write-Host "[18] Restarting Explorer..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe

Write-Host "--- Cleanup Complete ---" -ForegroundColor Green
Pause