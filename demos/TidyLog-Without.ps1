# TidyLog-Without.ps1
# installer script - prod
# don't run this on test!!

param(
    [int]$WaitTime = 650,
	[switch]$ClearScreen
)

if ($ClearScreen) { Clear-Host }

Start-Sleep -Milliseconds 200

$env_name   = "test"
$nasHost    = "192.168.1.50"
$nasShare   = "\\NAS-01\Backup"
$nasMac     = "00:11:32:AB:CD:EF"
$destPath   = "C:\Users\alan\Downloads"
$svcName    = "MyServer"

Write-Host ""
Write-Host "--- MyScript v2.0 ---"
Write-Host ""
Write-Host "  Environment $env_name"
Write-Host "  Date        $(Get-Date -Format 'dddd MM dd yyyy HH:mm')"
Write-Host "  Free space  264.72 GB"
Write-Host ""

# ---- pre-flight ----
Write-Host "--- Pre-flight checks ---" -ForegroundColor Yellow

Write-Host "Existing install found - upgrading"
Write-Host "Service running"
Write-Host "License file found" 
Write-Host "Cert check failed" -ForegroundColor Red
Write-Host "MSVC++ installed" 
Write-Host "Java not detected" 

Write-Host ""
Write-Host "Press the key in [brackets] to select how to continue."
Write-Host "[o] Install Oracle  .  [a] Install Amazon Corretto  .  [x] exit"
Write-Host ">: a"

Write-Host " Java 21" -NoNewline
Write-Host " downloading " 
Start-Sleep -MilliSeconds $WaitTime
Write-Host " installing "
Start-Sleep -MilliSeconds $WaitTime
# invoke installer here
Write-Host " Java 21 installed" -ForegroundColor Green

Start-Sleep -MilliSeconds $WaitTime
Write-Host ""

# ---- WOL ----
# wake NAS
Write-Host "Sending WOL packet. Waiting for NAS..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 300
$up = $false
for ($i = 0; $i -lt 10; $i++) {
    Write-Host "." -NoNewline
	Start-Sleep -Milliseconds 1000    
    if ($i -eq 2) { $up = $true; break }
}

if (-not $up) {
    Write-Host " NAS not responding - giving up" -ForegroundColor Red
    exit 1
}
Write-Host " \\NAS-01 online" -ForegroundColor Green

Write-Host ""

# ---- file copy ----
Write-Host "--- File Copy ---" -ForegroundColor Cyan
Write-Host " Copying installer files from $nasShare to $destPath"
$total = 3
for ($i = 1; $i -le $total; $i++) {
	Start-Sleep -Milliseconds 600
}  

Write-Host " done" -ForegroundColor Green
Write-Host ""

Start-Sleep -Seconds 1

# ---- server install ----
Write-Host "--- Installing server ---" -ForegroundColor Magenta

Write-Host "Extracting    server-v1.2.zip...  " -NoNewline
# Expand-Archive ...
Write-Host "copy done" 

Write-Host "Config: C:\Default; 500 GB"
Write-Host "Running installer    "
Write-Host " delayed-auto set "
Write-Host " service acc set " 
Write-Host " Installed" -ForegroundColor Green

Start-Sleep -Seconds 1

Write-Host ""
Write-Host "Checkpoint: Elapsed so far 00m 09s" 
Write-Host ""

# ---- post install ----
Write-Host "--- Post install checks ---" 

Write-Host "Service not started" -ForegroundColor Red

Write-Host "Starting service...  "
Start-Sleep -Milliseconds 300
for ($i = 0; $i -lt 5; $i++) {
    Start-Sleep -Milliseconds 1000
    Write-Host "." -NoNewline
}
Write-Host " service running" -ForegroundColor Green

Write-Host "Backup check  " -NoNewline
Start-Sleep -Milliseconds 300
for ($i = 0; $i -lt 2; $i++) {
    Start-Sleep -Milliseconds 1000
    Write-Host "." -NoNewline
}
Write-Host " backup OK" -ForegroundColor Green
Start-Sleep -Seconds 1
Write-Host ""
