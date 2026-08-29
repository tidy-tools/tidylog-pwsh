# =============================================================================
#  TidyLog-Demo.ps1
#  Run this script to see every TidyLog function in action.
#  It is both a demo and a visual test. If it looks right, it works.
#
#  USAGE
#  -----
#  .\TidyLog-Demo.ps1                          # full run
#  .\TidyLog-Demo.ps1 -NoWait                  # skip wait section
#  .\TidyLog-Demo.ps1 -NoCounters              # skip counters waits
#  .\TidyLog-Demo.ps1 -NoInput                 # skip input section
#  .\TidyLog-Demo.ps1 -Phase DETAIL            # single phase only
#  .\TidyLog-Demo.ps1 -Phase COUNTERS -NoProgress
#
#  AVAILABLE PHASES
#  ----------------
#  D1  HEADER  ICONS  CONFIG  DETAIL
#  PROGRESS  TIMER  WAIT  COUNTERS  PERCENT
#  ERROR  EXCEPTION  PHASECOLOR  INPUT  LAYOUT
#
#        Comment out Section INPUT to run fully unattended.
# =============================================================================

param(
    [switch]$NoWait,
	[switch]$NoCounters,
	[switch]$NoInput,
    [string]$Phase
)

$tidyLogPath = if (Test-Path "$PSScriptRoot\TidyLog.ps1") {
    "$PSScriptRoot\TidyLog.ps1"
} elseif (Test-Path "$PSScriptRoot\..\TidyLog.ps1") {
    "$PSScriptRoot\..\TidyLog.ps1"
} else {
    throw "TidyLog.ps1 not found."
}
. $tidyLogPath

function ShouldRun { param([string]$Tag) return (-not $Phase -or $Phase -ieq $Tag) }

function Get-DeepException {
    function Invoke-Level3 {
        Get-Item "C:\does-not-exist\deep-error.key" -ErrorAction Stop
    }
    function Invoke-Level2 {
        Invoke-Level3
    }
    function Invoke-Level1 {
        Invoke-Level2
    }
    Invoke-Level1
}

# =============================================================================
#  D1 - standalone mini-demo (Column 1 flat script pattern)
# =============================================================================

if (ShouldRun "D1") {	
    Write-TLHeader -Title "TidyLog Demo #1" -Summary "v1.0","default layout","PS 5.1+" -SummaryColor Blue	
    Set-TLLayout -DefaultColumn 1 -Column1Width 18
	Write-TLDetail "Set-TLLayout" "-DefaultColumn 1 -Column1Width 18"
    Write-TLDetail "Date"        (Get-Date -Format "ddd yyyy-MM-dd HH:mm")    
    Write-TLDetail "Write-TLDetail"      "-BeginSection" -BeginSection        
	Write-TLDetail "Write-TLDetail"      "ok" -Icon ok
	Write-TLDetail "Write-TLDetail"      "warn" -Icon warn
	Write-TLDetail "Write-TLDetail"      "error" -Icon Error
	
	Write-TLError  -Message "Write-TLError"
    
    Write-TLError  -Message "Write-TLError with Detail" `
        -Detail "Detail about error" `
        -Hint   "Hint"
    
    Write-TLDetail "Package install"  "complete"  -Icon ok
    Write-TLFooter -Message "Demo #1 complete"
}



# =============================================================================
#  HEADER - main demo
# =============================================================================
if (ShouldRun "HEADER") {
	Set-TLLayout -Column2Width 20 # reset layout to defaults
	Write-TLHeader -Title "TidyLog Demo #2" -Summary "v1.0","default layout","PS 5.1+"
	Write-TLDetail "Date"    (Get-Date -Format "ddd yyyy-MM-dd HH:mm")  -Column 1
	Write-TLDetail "Server"  "XV-88"                                     -Column 1
}

# =============================================================================
#  ICONS
# =============================================================================

if (ShouldRun "ICONS") {
    Write-TLPhase "ICONS" "Write-TLPhase"	
	Write-TLDetail "Write-TLDetail"         "no icon" 
	Write-TLDetail "Write-TLDetail"         "ok" -Icon ok
	Write-TLDetail "Write-TLDetail"         "warn" -Icon warn
	Write-TLDetail "Write-TLDetail"         "error" -Icon Error
    Start-Sleep -Milliseconds 500
}

# =============================================================================
#  CONFIG
# =============================================================================

if (ShouldRun "CONFIG") {
    Write-TLPhase "CONFIG" "Write-TLPhase with -Color Cyan" -Color Cyan	
		$layout = Get-TLLayout
        Write-TLDetail "Margin"    "$($TL.Margin)"
        Write-TLDetail "Column 1 Width"    "$($layout.Column1Width)"
        Write-TLDetail "Column 2 Width"    "$($layout.Column2Width)"
        Write-TLDetail "Column 3 Width"    "$($layout.Column3Width)"
		Write-TLDetail "Column 4 Width"    "$($layout.Column4Width)"
    Start-Sleep -Milliseconds 500
}

# =============================================================================
#  DETAIL
# =============================================================================

if (ShouldRun "DETAIL") {
    Write-TLPhase "Details" "Write-TLDetail with -ShowInSummary" -Color Cyan        
        Write-TLDetail "save ok"   "running"     -Icon ok   -ShowInSummary		
        Write-TLDetail "save warn" "low"         -Icon warn -ShowInSummary
        Write-TLDetail "save error" "error"      -Icon error -ShowInSummary
		
		Write-TLDetail "Write-TLDetail with -BeginSection begins a new section within a phase by prefixing a newline." -BeginSection
		Write-TLDetail "Write-TLDetail" "Add details to the section"      
		Write-TLDetail "Write-TLDetail with -EndSection ends the section within a phase by adding trailing newline." -EndSection
		
		Write-TLDetail "Write-TLDetail" "Add more details after section end"

    Write-TLPhase "columns" "Write-TLDetail with -Column"
		Write-TLDetail "-Column 1" -Column 1
		Write-TLDetail "Label on Column 1" "Detail" -Column 1
	    Write-TLDetail "default column (-Column 2)"
        Write-TLDetail "Label on Column 2" "default column" 
        Write-TLDetail "-Column 3"       -Column 3
        Write-TLDetail "Label on Column 3" "Detail"    -Icon warn -Column 3
        Write-TLDetail "-Column 4"                -Column 4
        Write-TLDetail "Label on Column 4" "Detail"   -Icon ok   -Column 4        
		
    Write-TLPhase "lists" "Write-TLListBegin / Write-TLListItem / Write-TLListEnd"
        Write-TLListBegin "Write-TLListBegin"
        Write-TLListItem  "Write-TLListItem"
        Write-TLListEnd   "Write-TLListEnd" -Icon Ok -ShowInSummary

        Write-TLListBegin "Begin"
        Write-TLListItem  "Item"
        Write-TLListItem  "Item"
        Write-TLListItem  "Item"
        Write-TLListEnd   		
		
    Start-Sleep -Milliseconds 500
}


# =============================================================================
#  PROGRESS
# =============================================================================

if (ShouldRun "PROGRESS") {    
		
	Write-TLPhase "PROGRESS" "Write-TLProgressDotBegin / Write-TLProgressDotAdd / Write-TLProgressDotEnd"
		Write-TLDetail "Show dots while a task progresses"
		Write-TLProgressDotBegin "Progress Indicator" 
		$total = 12
		for ($i = 1; $i -le $total; $i++) {
			Write-TLProgressDotAdd
			Start-Sleep -Milliseconds 200
		}		
		Write-TLProgressDotEnd -Tick
    
}

# =============================================================================
#  TIMER
# =============================================================================

if (ShouldRun "TIMER") {
    Write-TLPhase "TIMER" "Add -ShowElapsed to Write-TLPhase. Elapsed time shown to the right >" -ShowElapsed
        Write-TLDetail "Get script elapsed time using Get-TLElapsed" (Get-TLElapsed)
    Start-Sleep -Milliseconds 500
}

# =============================================================================
#  WAIT
# =============================================================================

if (ShouldRun "WAIT") {
	if (-not $NoWait) {		
		
        Write-TLPhase "WAIT" "Blocking functions that display ""·"" during the wait."
			Write-TLDetail "Wait-TLTimed - under 8 seconds (single colour)"
            Wait-TLTimed -Label "-WaitTime 4" -WaitTime 4
        Start-Sleep -Milliseconds 500

			Write-TLDetail "Wait-TLTimed - 8 seconds and above (colour stages)" -BeginSection
            Wait-TLTimed -Label "-WaitTime 8"  -WaitTime 8 
            Wait-TLTimed -Label "-Tone Warm" -WaitTime 12 -CompletionMessage "-CompletionMessage" -Tone Warm
        Start-Sleep -Milliseconds 500

			Write-TLDetail 'Conditional: Wait-TLConditional -Condition {Test-Path "$env:TEMP\tl-demo-flag.txt"}' -BeginSection
            $job = Start-Job { Start-Sleep 3; New-Item "$env:TEMP\tl-demo-flag.txt" -Force | Out-Null }
            $result = Wait-TLConditional -Label "Waiting for file" -Condition { Test-Path "$env:TEMP\tl-demo-flag.txt" } -Timeout 10000 
            Remove-Item "$env:TEMP\tl-demo-flag.txt" -Force -ErrorAction SilentlyContinue
            Remove-Job $job -Force
            Write-TLDetail "Wait-TLConditional returned:" "$result" -EndSection
			
            $result = Wait-TLConditional -Label 'Will timeout: -Timeout 5000 -Message "service did not respond"' -Condition { $false } -Timeout 5000 -TimeoutMessage "service did not respond"
            Write-TLDetail "Wait-TLConditional returned:" "$result"
        Start-Sleep -Milliseconds 500 
		
    } else {
        Write-TLPhase "WAIT" "Skipped (-NoWait)"
    }	
}

# =============================================================================
#  COUNTERS
# =============================================================================

if (ShouldRun "COUNTERS") {
	if (-not $NoCounters) {
		Set-TLLayout -Column3Width 28
		Write-TLPhase "COUNTERS" "Write-TLCounter - in-place n of N"		
			
			$total = 5
			Write-TLDetail 'Write-TLCounter "message" $i $total -PassThru'
			for ($i = 1; $i -le $total; $i++) {
				$complete = Write-TLCounter 'message' $i $total -PassThru
				Start-Sleep -Milliseconds 550
			}
			Write-TLDetail "Write-TLCounter returned:" "$complete" -EndSection			
			
			$total = 3
			for ($i = 1; $i -le $total; $i++) {
				Write-TLCounter "A very long label that exceeds Column2Width" $i $total
				Start-Sleep -Milliseconds 550
			}						
		
			Write-TLDetail "Use -PassThru to receive counter state. Test it and use Write-TLCounterEnd if counter did not complete" -BeginSection 
			$total = 400000003
			for ($i = 400000001; $i -le $total; $i++) {
				$complete = Write-TLCounter "Incomplete counter" $i ($total+1) -PassThru
				Start-Sleep -Milliseconds 550
			}
			if (-not $complete) { Write-TLCounterEnd "Write-TLCounterEnd with optional message and -ShowInSummary" -Icon warn -ShowInSummary }
			Write-TLDetail "Write-TLCounter returned:" "$complete"  -EndSection	
						
			$total = 400000003
			for ($i = 400000001; $i -le $total; $i++) {
				$complete = Write-TLCounter "Icon error test" $i ($total+1) -PassThru
				Start-Sleep -Milliseconds 550
			}
			if (-not $complete) { Write-TLCounterEnd "Write-TLCounterEnd missing -Icon with -ShowInSummary" -ShowInSummary }			

		Start-Sleep -Milliseconds 500
    } else {
        Write-TLPhase "COUNTERS" "Skipped (-NoCounters)"
    }		
}

# =============================================================================
#  PERCENT
# =============================================================================

if (ShouldRun "PERCENT") {
	if (-not $NoCounters) {		
		Write-TLPhase "PERCENT" "Write-TLPercent - in-place percent" -SkipLeadingNewline
		
			Write-TLDetail 'Write-TLPercent "Uploading" $p -PassThru'
			$pcts = @(0, 15, 33, 50, 68, 82, 91, 100)
			foreach ($p in $pcts) {
				$complete = Write-TLPercent "Uploading" $p -PassThru
				Start-Sleep -Milliseconds 400
			}		
			Write-TLDetail "Write-TLPercent returned:" "$complete"
			
			
			Write-TLDetail "Use Write-TLCounter to convert an incremental 1-8 counter to percentage" -BeginSection
			Write-TLDetail 'Write-TLCounter "Uploading" $p 8 -As PercentExact'		
			$pcts = @(1, 2, 3, 4, 5, 6, 7, 8)
			foreach ($p in $pcts) {            
				Write-TLCounter "Uploading" $p 8 -As PercentExact
				Start-Sleep -Milliseconds 400
			}			
		
			
			Write-TLDetail "Floating point edge case test" -BeginSection
			# Simulate floating point imprecision
			# 1/3 increments never hit exactly 100 so ceiling rounds to 100 early
			$total = 3
			for ($i = 1; $i -le $total; $i++) {
				$pct = ($i / $total) * 100   # 33.33, 66.66, 100.0
				$result = Write-TLPercent "FP sequence" $pct -PassThru
				Start-Sleep -Milliseconds 400
			}		

			# try calling again after completion. Should not overwrite "done ✓" 			
			$result = Write-TLPercent "FP sequence" 99.9999    # rounds to 100 again		
			Write-TLDetail "Write-TLPercent returned:" "$result"		
		
			Write-TLDetail "Operation completes before % reaches 100"  -BeginSection 
			Write-TLDetail "Note: When the % may not reach 100, use the Write-TLPercent return value to conditionally call Write-TLPercentEnd" -Icon warn
			Write-TLDetail "This will to cleanly end the Write-TLPercent block "
			$pcts = @(0, 15, 33, 50)
			foreach ($p in $pcts) {
				$complete = Write-TLPercent "Searching files" $p -PassThru
				Start-Sleep -Milliseconds 400
			}		
			if (-not $complete) { Write-TLPercentEnd "File found" -Icon ok -ShowInSummary }
			Write-TLDetail "Write-TLPercent returned:" "$complete"		
			
		Start-Sleep -Milliseconds 500
	}
}

# =============================================================================
#  ERROR
# =============================================================================

if (ShouldRun "ERROR") {
    Write-TLPhase "ERROR" "Write-TLError"
        Write-TLError -Message "Write-TLError with -Detail and -Hint" `
            -Detail "-Detail" `
            -Hint   "-Hint"
			
        Write-TLError -Message "One line error with only Message"
		
    Start-Sleep -Milliseconds 500
}

# =============================================================================
#  EXCEPTION
# =============================================================================

if (ShouldRun "EXCEPTION") {
    Write-TLPhase "EXCEPTION" "Write-TLException - compact, standard, full" -ShowElapsed
	
		Write-TLDetail "Compact" 'Write-TLException $_ -Mode Compact -Hint "User-facing. No stack details"' -Column 1 -BeginSection
        try { Get-Item "C:\does-not-exist\file.exe" -ErrorAction Stop } catch {
            Write-TLException $_ -Mode Compact -Hint "User-facing. No stack details"
        }
		
		Write-TLDetail "Standard " "no -Mode but with -Hint" -Column 1
		try {
			Set-TLLayout -Margin 1 -Column1Width 90 -Column2Width 18 -Column3Width 18
		} catch {
			Write-TLException $_ -Hint "Check Set-TLLayout params"
		}			
		
        Write-TLDetail "Full" "Write-TLException $_ -Mode Full" -Column 1
        try { Get-DeepException } catch {
            Write-TLException $_ -Mode Full
        }
        
    Start-Sleep -Milliseconds 500
}

# =============================================================================
#  PHASE COLOR
# =============================================================================
if (ShouldRun "PHASECOLOR") {
	Set-TLPhaseColor -Default DarkGreen
	Write-TLPhase "PHASE COLOR" "Set-TLPhaseColor -Default DarkGreen" -SkipLeadingNewline
		Write-TLDetail "Changing phase default color to DarkGreen"
		Write-TLDetail "Change back to the default phase heading color by calling just 'Set-TLPhaseColor'"	
}

# =============================================================================
#  INPUT
# =============================================================================

if (ShouldRun "INPUT") {	
	if (-not $NoInput) {		
		Write-TLPhase "INPUT" "Read-TLInput - interactive prompts"
			Write-TLDetail "Read-TLInput with -Default"
			$val = Read-TLInput -Prompt "Enter root path" -Default "C:\NAS"
			Write-TLDetail "You entered" $val

			Write-TLDetail "Read-TLInput with -Mode Mask" -BeginSection
			$masked = Read-TLInput -Prompt "Enter a token" -Mode Mask
			Write-TLDetail "You entered" $masked

			Write-TLDetail "Read-TLInput with -Mode Secure" -BeginSection
			$secure = Read-TLInput -Prompt "Enter password" -Mode Secure
			Write-TLDetail "Received" "(SecureString - $($secure.Length) chars)"
		
		Write-TLPhase "SELECTION" "Read-TLSelection - selection menus"
			Write-TLDetail "Read-TLSelection default -ListMode" -BeginSection
			$options = @("Install Oracle", "Install Amazon Corretto", "Quit")
			$choice = Read-TLSelection -Options $options
				
			Write-TLDetail "Received" "$choice"			
			
			Write-TLDetail "Read-TLSelection : Inline list with custom prompt, hashtable (key/option pairs) and default option" -BeginSection
			$options = @{
				Prompt = "Select an option" 
				Options = [ordered]@{ o = "Install Oracle"; a = "Install Amazon Corretto"; q = "Quit" }
				ListMode = "Inline"
				Default = "a"
			}
			$choice = Read-TLSelection @options
				
			Write-TLDetail "Received" "$choice"			
    } else {
        Write-TLPhase "INPUT" "Skipped (-NoInput)"
    }			
}

# =============================================================================
#  LAYOUT
# =============================================================================

if (ShouldRun "LAYOUT") {
    Write-TLPhase "LAYOUT" "Custom layout using Set-TLLayout"
		Write-TLDetail "Set-TLLayout -Margin 4 -Column1Width 18 -Column2Width 18 -Column3Width 18"
		Set-TLLayout -Margin 4 -Column1Width 18 -Column2Width 18 -Column3Width 18
		
		Write-TLDetail    "Margin"	-Column 1
        Write-TLDetail    "Environment"  "staging"
        Write-TLDetail    "Build"        "passing"  -Icon ok
        Write-TLListBegin "Deploying"
        Write-TLListItem  "artifact uploaded"
        Write-TLListEnd   -Tick

	Set-TLLayout
	Write-TLDetail "Reset layout to default by calling 'Set-TLLayout'"    
	
    Start-Sleep -Milliseconds 500
}

# =============================================================================
#  SUMMARY + FOOTER - full run only
# =============================================================================
Write-TLFooter -Message "Demo complete"

