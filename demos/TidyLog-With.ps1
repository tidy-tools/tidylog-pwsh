# =============================================================================
#  TidyLog-With.ps1
#  The same installer script output as TidyLog-Without.ps1, but using TidyLog functions.
#  Included in the TidyLog README to show the before/after contrast.
# =============================================================================
param(
    [int]$WaitTime = 650,
	[switch]$ClearScreen
)

$tidyLogPath = if (Test-Path "$PSScriptRoot\TidyLog.ps1") {
    "$PSScriptRoot\TidyLog.ps1"
} elseif (Test-Path "$PSScriptRoot\..\TidyLog.ps1") {
    "$PSScriptRoot\..\TidyLog.ps1"
} else {
    throw "TidyLog.ps1 not found."
}
. $tidyLogPath

if ($ClearScreen) { Clear-Host }

$NASShare    = "\\NAS-01\Backup"
$NASMac      = "00:11:32:AB:CD:EF"
$NASHost     = "192.168.1.50"
$SourceRoot  = "C:\Users\alan\Downloads"

# --- header ---
Write-TLHeader -Title "MyScript" -Summary "v2.0","prod","full install"
Write-TLDetail "Environment"  "test" -Column 1
Write-TLDetail "Date"         (Get-Date -Format "dddd MM/dd/yyyy HH:mm") -Column 1
Write-TLDetail "Free space"   "264.76 GB" -Column 1

# --- pre-flight checks ---
Write-TLPhase "CHECKS" "Pre-flight checks"
    Write-TLDetail "Existing install found - upgrading"
    Write-TLDetail "Service"  "running"   
    Write-TLDetail "License file" "found"      -Icon Ok    
    Write-TLDetail "Cert check"   "failed"     -Icon Error -ShowInSummary
	Write-TLDetail "MSVC++"       "installed"  -Icon Ok
    Write-TLDetail "Java" "not detected"    -Icon Warn 
	
	Write-TLDetail "Press the key in [brackets] to select how to continue." -BeginSection
    Write-TLDetail "[o] Install Oracle  ·  [a] Install Amazon Corretto  ·  [x] exit "
	Write-Host (" " * 14)" : a"		# simulate Read-TLInput indent
	Write-TLListBegin "Java 21"
	Write-TLListItem "downloading"
	Start-Sleep -MilliSeconds $WaitTime
	Write-TLListItem "installing"
	Start-Sleep -MilliSeconds $WaitTime
	Write-TLListEnd "Java 21 installed" -Icon Ok	

Start-Sleep -MilliSeconds $WaitTime

Write-TLPhase "WOL" "Wake NAS"

    Write-TLDetail "Target"  $NASHost    

    # Send-WOL $NASMac
    $nasOnline = Wait-TLConditional -Label "Waiting for NAS" `
        -Condition { $script:_wolAttempt++; $script:_wolAttempt -ge 4 } `
        -Timeout 10000 -WaitInterval 1 -CompletionMessage "\\NAS-01 online"
    $script:_wolAttempt = 0

    if (-not $nasOnline) {
        Write-TLError -Message "NAS unreachable — aborting" -Hint "Check NAS power and network"
        exit 1
    }


# --- installer copy ---
Write-TLPhase "file copy" "Copying installer files from NAS"
	Write-TLDetail "File source" "$NASShare"
	Write-TLDetail "Dest"        "$SourceRoot"
	$total = 3
	for ($i = 1; $i -le $total; $i++) {
		Write-TLCounter "File copy" $i $total
		Start-Sleep -Milliseconds 550
	}    	

Start-Sleep -Seconds 1

# --- package install ---
Write-TLPhase "server" "Installing server" -Color Cyan
    Write-TLListBegin "Extracting"
    Write-TLListItem  "server-v1.2.zip"
    Write-TLListEnd   
	
    Write-TLDetail "Cache path"       "C:\Default"    
    Write-TLDetail "Cache size"       "500 GB"        
	
    Write-TLListBegin "Running installer"    
    Write-TLListItem  "delayed-auto set"
    Write-TLListItem  "service acc set"
    Write-TLListEnd   "Installed "-Tick

Start-Sleep -Seconds 1


# --- status ---
Write-TLPhase "STATUS" "Post install checks" -ShowElapsed
	Write-TLError "Service not started"
    Wait-TLTimed "Starting service" 5 -CompletionMessage "service running" -ShowInSummary
    Wait-TLTimed "Backup check" 2 -CompletionMessage "backup OK" -ShowInSummary

Start-Sleep -Seconds 1


# --- summary + footer ---
Write-TLFooter -Message "Installation complete"
