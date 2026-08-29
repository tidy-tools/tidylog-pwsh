# =============================================================================
# TidyLog-Tests.ps1
# Custom test runner for TidyLog.ps1
# Tests all public functions with happy path and non-happy path variations.
# Run: .\TidyLog-Tests.ps1
# =============================================================================

param(
    [string]$TestPhase    = "",    # run only a specific phase e.g. -TestPhase "counters"
    [switch]$TestInput,            # include interactive Read-TLInput tests
    [switch]$ConfirmVisuals        # pause after visual tests for manual confirmation
)

. ..\TidyLog.ps1

$testCount       = 0
$testsPassed     = 0
$testsFailed     = 0
$summaryExpected = 0   # incremented each time -ShowInSummary is used

function ShouldRun {
    param([string]$Phase)
	$script:summaryExpected = 0
    return ([string]::IsNullOrEmpty($TestPhase) -or $TestPhase.ToLower() -ieq $Phase.ToLower())
}

function Confirm-TLVisual {
    param([string]$Check)
    if (-not $ConfirmVisuals) { return }

	Write-Host ""
    $response = Read-TLInput -Prompt "Visual Check >> $Check - Enter = pass · x = fail"

    if ($response -ieq "x") {
        throw "Visual Check failed ## $Check"
    }
}

function Test-TL {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
	$script:testCount++
	$testNum = "TEST $("{0:D2}" -f [int]$script:testCount)"
	Write-TLDetail "TEST $("{0:D2}" -f $script:testCount) : $Name" -Column 1

    try {

        & $Test
        Write-TLDetail "$testNum : PASS : $Name" -Icon ok -Column 1
        $script:testsPassed++

		if ($Test.ToString() -match "Write-TLError" -or `
			$Test.ToString() -match "Write-TLException" -or `
			$Test.ToString() -match "-ShowInSummary") {
			$script:summaryExpected++	## increase count because the test calls Write-TLError/TLException directly
		}

    } catch {
		$parts = $_ -split " ## "
		Write-TLError -Message "$testNum : $($parts[0])"  $parts[1]
        Write-TLDetail "$testNum : FAIL : $Name" -Icon Error  -Column 1
        $script:testsFailed++
		$script:summaryExpected++
    }
	Write-Host ""
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = "")
    if ($Expected -ne $Actual) {
        throw "Expected '$Expected' but got '$Actual'. $Message"
    }
}

function Assert-True {
    param($Value, [string]$Message = "")
    if (-not $Value) { throw "Expected true. $Message" }
}

function Assert-Throws {
    param([scriptblock]$ScriptBlock, [string]$Message = "")
    $threw = $false
    try { & $ScriptBlock } catch { $threw = $true }
    if (-not $threw) { throw "Expected exception but none was thrown. $Message" }
}

function Write-EventSummary {
	$types = "Success", "Warning", "Error", "Exception"
	Write-TLListBegin "Get-TLSummary:"			
	foreach ($type in $types) {
		Write-TLListItem ("$type = " + @(Get-TLEventSummary -EventType $type).Count)
	}	
	Write-TLListEnd ("Total = " + @(Get-TLEventSummary).Count)
}

function Invoke-TLSummaryCheck {

	# =============================================================================
	# SUMMARY DIAGNOSTIC - assert count and display raw contents
	# =============================================================================
	
	#Write-TLListItem "TL.Summary.Count = $TL.Summary.Count"

	if ($TL.Summary.Count -gt 0 -or $script:summaryExpected -gt 0) {
		Write-TLPhase "SUMMARY CHECK" "Asserting summary count and displaying entries"

		Write-EventSummary

		Write-TLDetail "Expected / Actual" "$script:summaryExpected / $($TL.Summary.Count)" -Icon $(if ($TL.Summary.Count -eq $script:summaryExpected) { "ok" } else { "error" })

		Write-TLDetail "Summary contents" -BeginSection
		$i = 0
		foreach ($entry in $TL.Summary) {
			$i++
			Write-TLDetail "#$i  Label: $($entry.Label);" "Detail: $($entry.Detail); Icon: $($entry.Icon)"
		}
		Write-TLDetail "End of summary" -EndSection

		Test-TL "Summary - entry count matches ShowInSummary calls" {
			Assert-Equal $script:summaryExpected $TL.Summary.Count "Summary Mismatch: Expected $script:summaryExpected entries - got $($TL.Summary.Count)"
		}		
	}
	
	$script:summaryExpected = 0	# reset reader for next section	
}


# =============================================================================
$headerSummary = @("full suite")
if (-not [string]::IsNullOrEmpty($TestPhase)) { $headerSummary = @("phase: $TestPhase") }
if ($TestInput)       { $headerSummary += "input tests" }
if ($ConfirmVisuals)  { $headerSummary += "visual confirmation" }
Write-TLHeader -Title "TidyLog Tests" -Summary $headerSummary
# =============================================================================


# -----------------------------------------------------------------------------
if (ShouldRun "event") {
	Write-TLHeader -Title "Event Log"
	Write-TLPhase "EVENT" "Check Get-TLSummary return values"

	# test with no events
	Test-TL "Get-TLEventSummary - 0 event count" {
		Write-EventSummary
		Assert-Equal 0  @(Get-TLEventSummary).Count    "All events"
	}

	# add some events
	Write-TLDetail "Status ok"   "confirmed"  -Icon ok -ShowInSummary	
	Write-TLDetail "Status warn" "low"        -Icon warn -ShowInSummary	
	Write-TLDetail "Status error" "not found"  -Icon Error -ShowInSummary
	Write-TLError "Error message"

	Test-TL "Get-TLEventSummary - event count" {
		Write-EventSummary
		Assert-Equal 1  @(Get-TLEventSummary -EventType "Success").Count  "Success events"
		Assert-Equal 1  @(Get-TLEventSummary -EventType "Warning").Count  "Warn events"
		Assert-Equal 2  @(Get-TLEventSummary -EventType "Error").Count    "Error events"
	}
	
	Write-TLDetail "Status ok"   "confirmed"  -Icon ok -ShowInSummary	
	Write-TLDetail "Status warn" "low"        -Icon warn -ShowInSummary	
	Write-TLDetail "Status error" "not found"  -Icon Error -ShowInSummary			
	Write-TLError "Error message"
	
	Test-TL "Set-TLLayout - default values" {
		Write-EventSummary
		Assert-Equal 2  @(Get-TLEventSummary -EventType "Success").Count  "Success events"
		Assert-Equal 2  @(Get-TLEventSummary -EventType "Warning").Count  "Warn events"
		Assert-Equal 4  @(Get-TLEventSummary -EventType "Error").Count    "Error events"
	}	
	
	$script:summaryExpected = 8
	
	Invoke-TLSummaryCheck	
	Write-TLFooter		
}


# -----------------------------------------------------------------------------
if (ShouldRun "config") {
	Write-TLHeader -Title "Config Tests"
	Write-TLPhase "CONFIG" "Set-TLLayout / Get-TLLayout / Set-TLPhaseColor / Set-TLGlyphSet"
	# -----------------------------------------------------------------------------

	Test-TL "Set-TLLayout - default values" {
		Set-TLLayout
		$layout = Get-TLLayout
		Assert-Equal 2  $layout.Margin    "Margin"
		Assert-Equal 14 $layout.Column1Width   "Column1Width"
		Assert-Equal 18 $layout.Column2Width   "Column2Width"
		Assert-Equal 20 $layout.Column3Width   "Column3Width"
		Assert-Equal 20 $layout.Column4Width   "Column4Width"
		Assert-Equal 2 $layout.DefaultColumn "DefaultColumn"
	}

	Test-TL "Set-TLLayout - custom values" {
		Set-TLLayout -Margin 4 -Column1Width 16 -Column2Width 20 -Column3Width 22 -Column4Width 22
		$layout = Get-TLLayout
		Assert-Equal 4  $layout.Margin
		Assert-Equal 16 $layout.Column1Width
		Assert-Equal 20 $layout.Column2Width
		Assert-Equal 22 $layout.Column3Width
		Assert-Equal 22 $layout.Column4Width
		Set-TLLayout   # reset
	}

	Test-TL "Set-TLLayout - DefaultColumn 1" {
		Set-TLLayout -DefaultColumn 1
		Assert-Equal 1 $TL.DefaultColumn
		Set-TLLayout   # reset
	}

	Test-TL "Set-TLLayout - invalid Margin (too low)" {
		$before = $TL.Margin
		try {
			Set-TLLayout -Margin 1   # should show error and return without changing
		} catch {
			Write-TLException $_ -Hint "Check Set-TLLayout params" -Mode Compact
		}
		Assert-Equal $before $TL.Margin "Margin should not have changed"
		Set-TLLayout
	}

	Test-TL "Set-TLLayout - invalid Column1Width (too low)" {
		$before = $TL.Width[0]
		try {
			Set-TLLayout -Column1Width 1   # should show error and return without changing
		} catch {
			Write-TLException $_ -Hint "Check Set-TLLayout params" -Mode Compact
		}
		Assert-Equal $before $TL.Width[0] "Column1Width should not have changed"
		Set-TLLayout
	}

	Test-TL "Set-TLPhaseColor - custom colour" {
		Set-TLPhaseColor -Default "Magenta"
		Assert-Equal "Magenta" $TL.PhaseDefaultColor
		Set-TLPhaseColor   # reset to DarkCyan
	}

	Test-TL "Set-TLPhaseColor - reset to default" {
		Set-TLPhaseColor
		Assert-Equal "DarkCyan" $TL.PhaseDefaultColor
	}

	Test-TL "Set-TLGlyphSet - ASCII" {
		Set-TLGlyphSet -CharSet ASCII
		Assert-Equal "ASCII" $TL.CharSet
		Set-TLGlyphSet   # reset
	}

	Test-TL "Set-TLGlyphSet - Unicode" {
		Set-TLGlyphSet -CharSet Unicode
		Assert-Equal "Unicode" $TL.CharSet
	}

	Test-TL "Get-TLLayout - returns PSCustomObject" {
		$layout = Get-TLLayout
		Assert-True ($layout -is [PSCustomObject]) "Should return PSCustomObject"
		Assert-True ($layout.PSObject.Properties.Name -contains "Margin") "Should contain Margin"
		Assert-True ($layout.PSObject.Properties.Name -contains "Column1Width") "Should contain Column1Width"
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
# -----------------------------------------------------------------------------
}

$section = "Timer"
if (ShouldRun $section) {
	Write-TLHeader -Title "$section Tests"
	Write-TLPhase $section "Get-TLElapsed"

	Test-TL "Get-TLElapsed - no timer returns 00m 00s" {
		$TL.StartTime = $null
		$result = Get-TLElapsed
		Assert-Equal "00m 00s" $result
	}

	Test-TL "Get-TLElapsed - running timer returns formatted string in m s format" {
		$TL.StartTime = (Get-Date).AddSeconds(-65)
		$result = Get-TLElapsed
		Write-TLDetail "Time format" $result
		Assert-True ($result -match "\d{2}m \d{2}s") "Should match 00m 00s format"
	}

	Test-TL "Get-TLElapsed - over an hour returns h m s format" {
		$TL.StartTime = (Get-Date).AddHours(-1).AddMinutes(-5)
		$result = Get-TLElapsed
		Write-TLDetail "Time format" $result
		Assert-True ($result -match "\d{2}h \d{2}m \d{2}s") "Should match 00h 00m 00s format"
	}

	Write-TLFooter
}

$section = "Header"
if (ShouldRun $section) {
	Write-TLHeader -Title "$section Tests"
	Write-TLPhase $section "Get-TLElapsed"

	Test-TL "Write-TLHeader - starts timer" {
		$TL.StartTime = $null
		Write-TLHeader -Title "Test"
		Assert-True ($null -ne $TL.StartTime) "Timer should have started"
	}

	Test-TL "Write-TLHeader - sets BannerWidth from content" {
		Write-TLHeader -Title "MyTool" -Summary "v2.0","prod","full install"
	}

	Test-TL "Write-TLHeader - does not reset running timer" {
		$TL.StartTime = (Get-Date).AddSeconds(-30)
		$before = $TL.StartTime
		Write-TLHeader -Title "Second header"
		Assert-Equal $before $TL.StartTime "Timer should not reset on second header"
	}

	Test-TL "Write-TLHeader - resets DefaultColumn to 2" {
		$TL.DefaultColumn = 1
		Write-TLHeader -Title "Test"
		Assert-Equal 2 $TL.DefaultColumn
	}

	Test-TL "Write-TLHeader - Default title is calling script name" {
		Write-TLHeader
		Confirm-TLVisual "Header contains calling file name minus extension."
	}

	Test-TL "Write-TLHeader - Long header both" {
		Write-TLHeader -Title "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBCCCC" -Summary "v2.0","prod","full install 1111111111111111222222222222222","more summaryddddddddddddddd-"
		Confirm-TLVisual "Header accommodate long file name."
	}

	Test-TL "Write-TLHeader - Long header -Title" {
		Write-TLHeader -Title ("Ab" * 70) -Summary "v2.0","prod","full install "
		Confirm-TLVisual "Header accommodate long file name."
	}

	Test-TL "Write-TLHeader - Long header -Summary" {
		Write-TLHeader -Title ("Ab" * 10) -Summary "v2.0","prod","full install 1111111111111111222222222222222","more summaryddddddddddddddd-"
		Confirm-TLVisual "Header accommodate long file name."
	}

	Write-TLFooter

}

$section = "Phase"
if (ShouldRun $section) {
	Write-TLHeader -Title "$section Tests"
	Write-TLPhase $section "Get-TLElapsed"

	Test-TL "Write-TLPhase - resets DefaultColumn to 2" {
		$TL.DefaultColumn = 1
		Write-TLPhase "TEST" "Testing"
		Assert-Equal 2 $TL.DefaultColumn
	}

	Test-TL "Write-TLPhase - empty description shows dot dot" {
		Write-TLPhase "TEST"   # no description - should show ··
		Confirm-TLVisual "Phase tag followed by ·· in terminal default colour"
	}

	Test-TL "Write-TLPhase - ShowElapsed with running timer" {
		$TL.StartTime = (Get-Date).AddSeconds(-10)
		Write-TLPhase "TEST" "With elapsed" -ShowElapsed
		Confirm-TLVisual "Elapsed time visible right-aligned on phase line in DarkGray"
		$TL.StartTime = $null
	}

	Test-TL "Write-TLPhase - ShowElapsed with no timer" {
		$TL.StartTime = $null
		Write-TLPhase "TEST" "No elapsed" -ShowElapsed   # should render without elapsed
		$TL.StartTime = (Get-Date).AddSeconds(-10)
	}

	Test-TL "Write-TLPhase - SkipLeadingNewline" {
		Write-TLPhase "TEST" "Skip newline" -SkipLeadingNewline
	}

	Test-TL "Write-TLPhase - custom colour" {
		Write-TLPhase "TEST" "Custom colour" -Color "Yellow"
	}

	Test-TL "Write-TLPhase - one char gap" {
		Write-TLPhase ("Q" * ($TL.Width[0] - $TL.Margin - 1)) "< Should be 1 space gap"
	}
	
	Test-TL "Visual" {
		Confirm-TLVisual "Check 1) no timer, 2) skip newline, 3) yellow phase tag"
	}

	Write-TLFooter
}

$section = "Detail"
if (ShouldRun $section) {
	Write-TLHeader -Title "$section Tests"
	Write-TLPhase $section "Get-TLElapsed"

	Test-TL "Write-TLDetail - label only" {
		Write-TLDetail "Label only" -Icon Warn -ShowInSummary
	}

	Test-TL "Write-TLDetail - label and detail" {
		Write-TLDetail "Java" "21.0.3"
	}

	Test-TL "Write-TLDetail - long label with dynamic space before detail" {
		Write-TLDetail "long label with dynamic space before detail" "21.0.3"
	}

	Test-TL "Write-TLDetail - all icons" {
		Write-TLDetail "Status ok"   "confirmed"  -Icon ok
		Write-TLDetail "Status warn" "low"        -Icon warn
		Write-TLDetail "Status error" "not found"  -Icon Error -ShowInSummary
		Confirm-TLVisual "ok=green tick, warn=amber warning, fail=red cross - all glyphs after value"
	}

	Test-TL "Write-TLDetail - all indent levels" {
		Write-TLDetail "column 1 label" "value" -Column 1
		Write-TLDetail "column 2 label" "value" -Column 2
		Write-TLDetail "column 3 label" "value" -Column 3
		Write-TLDetail "column 4 label" "value" -Column 4
		Confirm-TLVisual "Each label progressively indented further right column 1 through to column 4"
	}

	# Regression test for the col 5 padding calculation. Write-TLDetail at -Column 4
	# with a non-empty -Detail internally asks Get-TLIndentSpacing for one level
	# past 4.
	# Calling the private helper directly here is deliberate: this needs a
	# precise, automatic assertion, not a visual check a human could miss.
	Test-TL "Get-TLIndentSpacing - IndentIncrease past column 4 sums all four widths" {
		Set-TLLayout   # ensure known default widths
		$spacing = Get-TLIndentSpacing -Column 4 -ColumnIncrease 1
		$expectedLength = $TL.Margin + ($TL.Width[0..3] | Measure-Object -Sum).Sum
		Assert-Equal $expectedLength $spacing.Length "-Column 4 plus one indent level should sum all four column widths"
	}

	Test-TL "Write-TLDetail - ShowInSummary adds to summary" {
		Write-TLDetail "Service" "running" -Icon ok -ShowInSummary
		Assert-Equal "Service" $TL.Summary[$script:summaryExpected].Label
		Assert-Equal "ok"      $TL.Summary[$script:summaryExpected].Icon
	}

	Test-TL "Write-TLDetail - ShowInSummary without Icon shows error" {
		Write-TLDetail "No icon" "value" -ShowInSummary   # should show TLError
	}

	Test-TL "Write-TLDetail - BeginSection adds space above" {
		Write-TLDetail "Before section" "value"
		Write-TLDetail "Begin section" "value" -BeginSection
		Confirm-TLVisual "Blank line above 'Begin section' line - no blank line above 'Before section'"
	}

	Test-TL "Write-TLDetail - EndSection adds space below" {
		Write-TLDetail "End section" "value" -EndSection
		Write-TLDetail "After section" "value"
		Confirm-TLVisual "Blank line below 'End section' line - no blank line below 'After section'"
	}

	Test-TL "Write-TLDetail - DefaultColumn 1 used when no Indent passed" {
		Set-TLLayout -DefaultColumn 1
		Write-TLDetail "Uses column 1 default" "value"
		Confirm-TLVisual "Label placed at column 1 (left margin) not 2"
		Set-TLLayout   # reset
	}

	Test-TL "Write-TLDetail - long label truncates in summary" {
		$longLabel = "Abcde" * 10
		Write-TLDetail $longLabel ("Ab" * 19) -Icon ok -ShowInSummary
	}


	Test-TL "Write-TLDetail - long label truncates in summary" {
		for ($i=1; $i -le 11; $i++) {$longLabel += "$i-AB-"}
		for ($i=1; $i -le 11; $i++) {$longDetail += "$i-GE-"}
		Write-TLDetail $longLabel $longDetail -Icon ok -ShowInSummary
	}

	Test-TL "Write-TLDetail - long label truncates in summary" {
		for ($i=1; $i -le 20; $i++) {$longLabel += "$i-AB-"}
		for ($i=1; $i -le 7; $i++) {$longDetail += "$i-GE-"}
		Write-TLDetail $longLabel $longDetail -Icon ok -ShowInSummary
	}

	Test-TL "Write-TLDetail - label exact length of Column2Width" {
		$longLabel = "Q" * $TL.Width[1]
		Write-TLDetail $longLabel "< check for two spaces after Label" -Icon ok
	}	

	Invoke-TLSummaryCheck
	Write-TLFooter
	
	
	Write-TLHeader "All OK Check"
	Write-TLPhase $section "Get-TLElapsed"

	Test-TL "Write-TLDetail - OK Check" {
		Write-TLDetail "Label" "Info" -Icon Ok -ShowInSummary
	}
	Invoke-TLSummaryCheck
	Write-TLFooter	
}

if (ShouldRun "list") {
	Write-TLHeader "LIST"
	Write-TLPhase "LIST" "Write-TLListBegin / Item / End"

	Test-TL "Write-TLList - happy path with Tick" {
		Write-TLListBegin "Copying files"
		Write-TLListItem "hub.exe"
		Write-TLListItem "sb.exe"
		Write-TLListItem "config.xml"
		Write-TLListEnd -Icon Ok
		Confirm-TLVisual "Items separated by · on one line, ending with done ✓"
	}

	Test-TL "Write-TLList - no tick" {
		Write-TLListBegin "Services"
		Write-TLListItem "CscService"
		Write-TLListItem "DiagTrack"
		Write-TLListEnd
		Confirm-TLVisual "Items separated by · on one line, ending with 'done' - no tick"
	}

	Test-TL "Write-TLList - custom end text" {
		Write-TLListBegin "Packages"
		Write-TLListItem "package-a"
		Write-TLListEnd "complete" 
		Confirm-TLVisual "Ends with 'complete' not 'done'"
	}

	Test-TL "Write-TLList - aligned at Column 1" {
		Write-TLListBegin "Column 1 list" -Column 1
		Write-TLListItem "item"
		Write-TLListEnd  -Icon Ok
		Confirm-TLVisual "List begins at margin indent - further left than usual"
	}
	
	Test-TL "Write-TLList - show in summary" {
		Write-TLListBegin "Services restarting"
		Write-TLListItem -Item "Spooler"
		Write-TLListItem -Item "BITS"
		Write-TLListItem -Item "WinRM"
		Write-TLListEnd -Message "all restarted" -Icon Ok -ShowInSummary	
		Confirm-TLVisual "Ends with 'all restarted ✓' not 'done ✓'"
	}	
	
	Test-TL "Write-TLList - show in summary" {
		Write-TLListBegin "Adding to security groups"
		Write-TLListItem -Item "Finance-Mgmt"
		Write-TLListItem -Item "Office-North"		
		Write-TLListEnd -Message "2 groups failed" -Icon Error -ShowInSummary
		Confirm-TLVisual "Ends with '2 groups failed ✗' not 'done ✓'"
	}		

	Invoke-TLSummaryCheck
	Write-TLFooter
}

if (ShouldRun "progress") {
	Write-TLHeader "PROGRESS"
	Write-TLPhase "PROGRESS" "Write-TLProgressDotBegin / Add / End"
	# -----------------------------------------------------------------------------

	Test-TL "Write-TLProgressDot - happy path" {
		Write-TLProgressDotBegin "Processing items"
		Write-TLProgressDotAdd
		Write-TLProgressDotAdd
		Write-TLProgressDotAdd
		Write-TLProgressDotEnd -Icon Ok
		Confirm-TLVisual "Label then three dots then done ✓ - all on one line"
	}

	Test-TL "Write-TLProgressDot - custom completion message with 2 dots and no tick" {
		Write-TLProgressDotBegin "Installing"
		Write-TLProgressDotAdd
		Write-TLProgressDotAdd
		Write-TLProgressDotEnd "installed" 
	}

	Test-TL "Write-TLProgressDot - no dots (immediate completion)" {
		Write-TLProgressDotBegin "Quick task"
		Write-TLProgressDotEnd -Icon Ok
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
	
	Test-TL "Visual on Summary Table" {	
		Confirm-TLVisual "Confirm progress lines display as expected."
	}
}

if (ShouldRun "wait") {
	Write-TLHeader "WAIT"
	Write-TLPhase "WAIT" "Wait-TLTimed / Wait-TLConditional"
	# -----------------------------------------------------------------------------

	Test-TL "Wait-TLTimed - short wait (4 seconds, single colour)" {
		Wait-TLTimed "Short wait" -WaitTime 4
	}

	Test-TL "Wait-TLTimed - long wait (10 seconds, colour stages)" {
		Wait-TLTimed "Long wait" -WaitTime 10 -CompletionMessage "complete" 
		Confirm-TLVisual "Dots progress through DarkGray → Gray → White stages (default Cool tone)"
	}

	Test-TL "Wait-TLTimed - Warm tone colour stages" {
		Wait-TLTimed "Warm tone wait" -WaitTime 10 -CompletionMessage "complete" -Tone Warm
		Confirm-TLVisual "Dots progress through Red → DarkYellow → Yellow → Gray stages"
	}

	Test-TL "Wait-TLTimed - Neutral tone colour stages" {
		Wait-TLTimed "Neutral tone wait" -WaitTime 10 -CompletionMessage "complete" -Tone Cool
		Confirm-TLVisual "Dots progress through DarkBlue → Blue → DarkGreen → Cyan → Gray stages"
	}

	Test-TL "Wait-TLTimed - negative seconds (error)" {
		$threw = $false
		try {
			Wait-TLTimed "Negative wait" -WaitTime -5
		} catch {
			$threw = $true
			Write-TLException $_ -Hint "Check -WaitTime" -Mode Compact
		}
		Assert-True $threw "Should throw for negative -WaitTime"
	}

	Test-TL "Wait-TLTimed - WaitTime exceeds max (error)" {
		$threw = $false
		try {
			Wait-TLTimed "Too high - 88400" -WaitTime 88400
		} catch {
			$threw = $true
			Write-TLException $_ -Hint "Check -WaitTime" -Mode Compact
		}
		Assert-True $threw "Should throw when -WaitTime exceeds 86400"
	}

	Test-TL "Wait-TLTimed - ShowInSummary" {
		Wait-TLTimed "Summary wait" -WaitTime 2 -CompletionMessage "done" -ShowInSummary
	}

	Test-TL "Visual - Wait-TLTimed calls" {
		Confirm-TLVisual "Wait-TLTimed calls display as expected"
	}


	Test-TL "Wait-TLConditional - condition met immediately" {
		$result = Wait-TLConditional "Immediate" -Condition { $true } -Timeout 10000
		Assert-True $result "Should return true when condition met"
	}

	Test-TL "Wait-TLConditional - condition met after delay" {
		$script:counter = 0
		$result = Wait-TLConditional "Delayed condition" -Condition {
			$script:counter++
			$script:counter -ge 3
		} -Timeout 10000
		Assert-True $result "Should return true when condition eventually met"
	}

	Test-TL "Wait-TLConditional - condition never met (timeout)" {
		$result = Wait-TLConditional "Timeout test" -Condition { $false } -Timeout 3000 -TimeoutMessage "timed out as expected"
		Assert-True (-not $result) "Should return false on timeout"
	}

	Test-TL "Wait-TLConditional - custom WaitInterval" {
		$script:counter = 0
		$result = Wait-TLConditional "2s interval" -Condition {
			$script:counter++
			$script:counter -ge 4
		} -Timeout 10000 -WaitInterval 2
		Assert-True $result
		Confirm-TLVisual "Dots appeared roughly 2 seconds apart, not back to back"
	}

	Test-TL "Wait-TLConditional - Tone parameter passed through" {
		# Timeout must exceed 7000ms for the multi-stage palette to engage at
		# all, otherwise this silently falls back to the single-colour path
		# regardless of -Tone, and the visual check below would be checking
		# for something that was never actually possible to see.
		$result = Wait-TLConditional "Tone check" -Condition { $false } -Timeout 8000 -Tone Warm -TimeoutMessage "timed out"
		Assert-True (-not $result) "Should time out as expected"
		Confirm-TLVisual "Dots during this wait used the Warm palette (Red/DarkYellow/Gray/Yellow), not the default Cool"
	}

	Test-TL "Wait-TLConditional - ShowInSummary on success" {
		Wait-TLConditional "Summary condition" -Condition { $true } -Timeout 5000 -CompletionMessage "online" -ShowInSummary | Out-Null
	}

	Test-TL "Wait-TLConditional - ShowInSummary on timeout" {
		Wait-TLConditional "Timeout summary" -Condition { $false } -Timeout 2000 -TimeoutMessage "offline" -ShowInSummary | Out-Null
		Assert-Equal "warn" $TL.Summary[$script:summaryExpected].Icon "Timeout should save as warn"
	}
	
	Test-TL "Visual - Wait-TLConditional calls" {
		Confirm-TLVisual "Wait-TLConditional call display as expected"
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
}

if (ShouldRun "counter") {
	Write-TLHeader "COUNTER"
	Write-TLPhase "COUNTER" "Write-TLCounter"
	# -----------------------------------------------------------------------------

	Test-TL "Write-TLCounter - Count mode happy path" {
		for ($i = 1; $i -le 5; $i++) {
			Write-TLCounter "Count mode" $i 5
			Start-Sleep -Milliseconds 100
		}
	}

	Test-TL "Write-TLCounter - PercentWhole mode" {
		for ($i = 1; $i -le 5; $i++) {
			Write-TLCounter "PercentWhole" $i 5 -As PercentWhole
			Start-Sleep -Milliseconds 400
		}
	}

	Test-TL "Write-TLCounter - PercentExact mode" {
		for ($i = 1; $i -le 5; $i++) {
			Write-TLCounter "PercentExact" $i 5 -As PercentExact
			Start-Sleep -Milliseconds 400
		}
	}

	Test-TL "Visual - Wait-TLCounter calls" {
		Confirm-TLVisual "Confirm Wait-TLCounter PercentWhole and PercentExact display as expected"
	}

	Test-TL "Write-TLCounter - PassThru returns done state" {
		for ($i = 1; $i -le 3; $i++) {
			$done = Write-TLCounter "Files" $i 3 -PassThru
			Start-Sleep -Milliseconds 300
		}
		Assert-True $done "PassThru should return true on completion"
	}

	Test-TL "Write-TLCounter - zero Total shows error" {
		$threw = $false
		try {
			Write-TLCounter "Files" 1 0
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for zero -Total"
	}

	Test-TL "Write-TLCounter - negative Total shows error" {
		$threw = $false
		try {
			Write-TLCounter "Files" 1 -5
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for negative -Total"
	}

	Test-TL "Write-TLCounter - negative Current shows error" {
		$threw = $false
		try {
			Write-TLCounter "Files" -1 10
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for negative -Current"
	}

	Test-TL "Write-TLCounter - multi-sequence reset" {
		for ($i = 1; $i -le 3; $i++) { Write-TLCounter "Sequence 1" $i 3; Start-Sleep -Milliseconds 100 }
		for ($i = 1; $i -le 3; $i++) { Write-TLCounter "Sequence 2" $i 3; Start-Sleep -Milliseconds 100 }
	}

	Test-TL "Write-TLCounter - early exit with CounterEnd" {
		for ($i = 1; $i -le 5; $i++) {
			Write-TLCounter "Searching" $i 10
			Start-Sleep -Milliseconds 100
			if ($i -eq 3) {
				Write-TLCounterEnd -Message "found at item 3" -Icon ok
				break
			}
		}
	}

	Test-TL "Write-TLCounter - Different column placements" {
		for ($i = 1; $i -le 3; $i++) { Write-TLCounter "Sequence 1" $i 3 "Count" 1; Start-Sleep -Milliseconds 100 }
		for ($i = 1; $i -le 3; $i++) { Write-TLCounter "Sequence 2" $i 3 "Count" 3; Start-Sleep -Milliseconds 100 }
	}

	Test-TL "Visual - Wait-TLCounter calls" {
		Confirm-TLVisual "Confirm Wait-TLCounter calls display as expected"
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
}

if (ShouldRun "percent") {
	Write-TLHeader "PERCENT"
	Write-TLPhase "PERCENT" "Write-TLPercent"
	# -----------------------------------------------------------------------------

	Test-TL "Write-TLPercent - happy path" {
		for ($p = 0; $p -le 100; $p += 20) {
			Write-TLPercent "Progress" $p
			Start-Sleep -Milliseconds 200
		}
	}

	Test-TL "Write-TLPercent - PassThru returns done state" {
		$done = $false
		for ($p = 0; $p -le 100; $p += 25) {
			$done = Write-TLPercent "Upload" $p -PassThru
			Start-Sleep -Milliseconds 200
		}
		Assert-True $done "PassThru should return true at 100%"
	}

	Test-TL "Write-TLPercent - below zero shows error" {
		$threw = $false
		try {
			Write-TLPercent "Invalid" -10
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for -Percent below 0"
	}

	Test-TL "Write-TLPercent - above 100 shows error" {
		$threw = $false
		try {
			Write-TLPercent "Invalid" 110
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for -Percent above 100"
	}

	Test-TL "Write-TLPercent - rounding below range" {
		$threw = $false
		try {
			Write-TLPercent "Invalid" -0.4
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for -Percent below 0, even fractionally"
	}

	Test-TL "Write-TLPercent - rounding above range" {
		$threw = $false
		try {
			Write-TLPercent "Invalid" 100.4
		} catch {
			$threw = $true
			Write-TLException $_ -Mode Compact
		}
		Assert-True $threw "Should throw for -Percent above 100, even fractionally"
	}

	Test-TL "Write-TLPercent - floating point boundary" {
		$total = 3
		for ($i = 1; $i -le $total; $i++) {
			Write-TLPercent "FP test" (($i / $total) * 100)
			Start-Sleep -Milliseconds 200
		}
		# post-completion calls - should be silently ignored
		Write-TLPercent "FP test" 99.9999
		Confirm-TLVisual "FP test still done, not 99.9999"
	}

	Test-TL "Write-TLPercent - multi-sequence reset" {
		for ($p = 0; $p -le 100; $p += 25) { Write-TLPercent "First" $p; Start-Sleep -Milliseconds 50 }
		for ($p = 0; $p -le 100; $p += 25) { Write-TLPercent "Second" $p; Start-Sleep -Milliseconds 50 }
	}

	Test-TL "Write-TLPercentEnd - incomplete sequence" {
		for ($p = 0; $p -le 50; $p += 10) {
			Write-TLPercent "Incomplete" $p
			Start-Sleep -Milliseconds 50
		}
		Write-TLPercentEnd -Message "process interrupted" -Icon warn
	}

	Test-TL "Write-TLPercentEnd - on completed sequence (no-op)" {
		for ($p = 0; $p -le 100; $p += 25) { Write-TLPercent "Complete" $p; Start-Sleep -Milliseconds 50 }
		Write-TLPercentEnd -Message "should not appear"   # already done, should be no-op
		Confirm-TLVisual "Text 'should not appear' is not visible"
	}

	Test-TL "Write-TLCounter - no PassThru returns nothing to pipeline" {
		$result = $null
		for ($i = 1; $i -le 3; $i++) {
			$result = Write-TLCounter "Files" $i 3
			Start-Sleep -Milliseconds 100
		}
		Assert-Equal $null $result "Should return nothing without -PassThru"
	}

	Test-TL "Write-TLPercent - no PassThru returns nothing to pipeline" {
		$result = $null
		for ($p = 0; $p -le 100; $p += 25) {
			$result = Write-TLPercent "Upload" $p
			Start-Sleep -Milliseconds 50
		}
		Assert-Equal $null $result "Should return nothing without -PassThru"
	}

	Test-TL "Write-TLCounterEnd - completed sequence returns nothing" {
		for ($i = 1; $i -le 3; $i++) { Write-TLCounter "Seq" $i 3; Start-Sleep -Milliseconds 100 }
		$result = Write-TLCounterEnd -Message "should not appear"
		Assert-Equal $null $result "No-op CounterEnd should return nothing"
	}

	Test-TL "Write-TLPercentEnd - completed sequence returns nothing" {
		for ($p = 0; $p -le 100; $p += 25) { Write-TLPercent "Complete2" $p; Start-Sleep -Milliseconds 50 }
		$result = Write-TLPercentEnd -Message "should not appear"
		Assert-Equal $null $result "No-op PercentEnd should return nothing"
	}

	Test-TL "Visual - Percent and Counter calls" {
		Confirm-TLVisual "Percent and Counter test returned as expected"
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
}

if (ShouldRun "error") {
	Write-TLHeader "ERROR"
	Write-TLPhase "ERROR" "Write-TLError / Write-TLException"
	# -----------------------------------------------------------------------------

	Test-TL "Write-TLError - message only" {
		Write-TLError "Service failed to start"
		Confirm-TLVisual "Single red line - message with ✗ glyph - no extra lines"
	}

	Test-TL "Write-TLError - with Detail and Hint" {
		Write-TLError "Key file not found" -Detail "Expected C:\temp\*.key" -Hint "Copy licence file before running"
		Confirm-TLVisual "Full error block - message, Detail, Hint, Time - blank lines above and below"
	}

	Test-TL "Write-TLError - with Detail only" {
		Write-TLError "Connection failed" -Detail "192.168.1.50 unreachable"
		Confirm-TLVisual "Error block - message, Detail, Time - no Hint line"
	}

	Test-TL "Write-TLError - with Hint only" {
		Write-TLError "Permission denied" -Hint "Run as administrator"
		Confirm-TLVisual "Error block - message, Hint, Time - no Detail line"
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
}


if (ShouldRun "exception") {
	Write-TLHeader "Exception"
	Write-TLPhase "Exception" "Write-TLException"
	# -----------------------------------------------------------------------------

	Test-TL "Write-TLException - standard mode" {
		try { Get-Item "C:\does-not-exist\file.key" -ErrorAction Stop } catch {
			Write-TLException $_
		}
		Confirm-TLVisual "Exception block - message, Type, Location, Time - no stack trace"
	}

	Test-TL "Write-TLException - Full mode" {
		try { Get-Item "C:\does-not-exist\file.key" -ErrorAction Stop } catch {
			Write-TLException $_ -Mode Full
		}
		Confirm-TLVisual "Full exception - message, Type, Location, Line, Trace, Time"
	}

	Test-TL "Write-TLException - Compact mode" {
		try { Get-Item "C:\does-not-exist\file.key" -ErrorAction Stop } catch {
			Write-TLException $_ -Mode Compact
		}
		Confirm-TLVisual "Compact - message, file name and time - no Type"
	}

	Test-TL "Write-TLException - with Hint" {
		try { Get-Item "C:\does-not-exist\file.key" -ErrorAction Stop } catch {
			Write-TLException $_ -Hint "Copy the licence file before running"
		}
		Confirm-TLVisual "Standard mode with Hint line visible before Time"
	}

	Test-TL "Write-TLException - deep stack trace" {
		function Invoke-Level3 { Get-Item "C:\does-not-exist\deep.key" -ErrorAction Stop }
		function Invoke-Level2 { Invoke-Level3 }
		function Invoke-Level1 { Invoke-Level2 }
		try { Invoke-Level1 } catch { Write-TLException $_ -Mode Full }
		Confirm-TLVisual "Multiple Trace lines visible - call chain shows Level1, Level2, Level3"
	}

	Test-TL "Write-TLException - multi line Message" {
		try {
			Set-TLLayout -Margin 1
		} catch {
			Write-TLException $_ -Mode Compact
		}
		Confirm-TLVisual "Compact mode multi line Message split one line per sentence"
	}

	Test-TL "Write-TLException - multi line Inner Exception" {
		try {
			Set-TLLayout -Margin 1
		} catch {
			Write-TLException $_ -Hint "Check Set-TLLayout params" -Mode Full
		}
		Confirm-TLVisual "Full mode multi line Inner Exception"
	}

	Test-TL "Write-TLException - multi line Inner Exception" {
		try {
			Set-TLPhaseColor "Pink"
		} catch {
			Write-TLException $_ -Hint "Check Set-TLLayout params" -Mode Full
		}
		Confirm-TLVisual "Full mode multi line Inner Exception"
	}

	Invoke-TLSummaryCheck
	Write-TLFooter
} #end ERRORS


if (ShouldRun "input") {
	Write-TLHeader "INPUT"
	Write-TLPhase "SELECTION VALIDATION" "Read-TLSelection - non-interactive validation"
	# -----------------------------------------------------------------------------

	Test-TL "Read-TLSelection - more than 9 array options throws" {
		$tooMany = 1..10 | ForEach-Object { "Option $_" }
		Assert-Throws { Read-TLSelection -Options $tooMany } "Should throw when array exceeds 9 items"
	}

	Test-TL "Read-TLSelection - invalid Options type throws" {
		Assert-Throws { Read-TLSelection -Options "not an array or hashtable" } "Should throw for unsupported -Options type"
	}

	Test-TL "Read-TLSelection - invalid Default value throws" {
		$options = @("Yes", "No")
		Assert-Throws { Read-TLSelection -Options $options -Default "z" } "Should throw when -Default doesn't match a valid key"
	}

	Test-TL "Read-TLSelection - empty string Indent throws" {
		$options = @("Yes", "No")
		Assert-Throws { Read-TLSelection -Options $options -Column "" } "Should throw, empty string is no longer a valid -Column value"
	}
}

if ((ShouldRun "input") -or $TestInput) {
	# -----------------------------------------------------------------------------
	Write-TLPhase "INPUT" "Read-TLInput"
	# -----------------------------------------------------------------------------

    Write-TLDetail "Interactive tests enabled" "-TestInput flag passed" -Icon ok

    Test-TL "Read-TLInput - default accepted (press Enter)" {
        $result = Read-TLInput -Prompt "Press Enter to accept default" -Default "accepted"
		Write-TLDetail "You entered" $result
        Assert-Equal "accepted" $result "Should return default when Enter pressed"
    }

    Test-TL "Read-TLInput - plain input no default" {
        $result = Read-TLInput -Prompt "Enter any text"
        Write-TLDetail "You entered" $result
		Assert-True (-not [string]::IsNullOrEmpty($result)) "Should return a value"
    }

    Test-TL "Read-TLInput - Secure mode returns SecureString" {
        $result = Read-TLInput -Prompt "Enter a password" -Mode Secure
		Assert-True ($result -is [System.Security.SecureString]) "Should return SecureString"

		$decrypted = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($result)
		$result = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($decrypted)
		Write-TLDetail "You entered" $result

    }

    Test-TL "Read-TLInput - Mask mode returns plain string" {
        $result = Read-TLInput -Prompt "Enter a token (masked)" -Mode Mask
		Write-TLDetail "You entered" $result
        Assert-True ($result -is [string]) "Should return plain string"
        Assert-True (-not [string]::IsNullOrEmpty($result)) "Should not be empty"
    }

    Test-TL "Read-TLInput - Column 1 placement" {
        $result = Read-TLInput -Prompt "Column 1 prompt" -Column 1
        Write-TLDetail "You entered" $result
    }

	Write-TLPhase "INPUT" "Read-TLSelection"

	Test-TL "Read-TLSelection - array mode returns an int matching a valid position" {
		$options = @("Install Oracle", "Install Amazon Corretto", "Quit")
		Write-TLDetail "List options to display" ($options -join ', ')
		$choice = Read-TLSelection -Options $options
		Assert-True ($choice -is [int]) "Should return an int for array-mode options"
		Assert-True ($choice -ge 1 -and $choice -le $options.Count) "Returned int should be a valid option position"
		Write-TLDetail "You entered" $choice
	}

	Test-TL "Read-TLSelection - -Prompt -Options -ListMode -Default all correct." {
		Write-TLDetail "Read-TLSelection : Inine list with custom prompt, hashtable (key/option pairs) and default option" -BeginSection
		$options = @{
			Prompt = "Select an option"
			Options = [ordered]@{ o = "Install Oracle"; a = "Install Amazon Corretto"; q = "Quit" }
			ListMode = "Inline"
			Default = "a"
		}
		$choice = Read-TLSelection @options
		Write-TLDetail "You entered" $choice
		Assert-True ($choice -in @("o","a","q")) "Should return one of the valid hashtable keys"
	}

	# Note: the re-prompt-on-invalid-key loop inside Read-TLSelection is not
	# covered here. It reads from Read-Host in a while loop with no injection
	# point for scripted input, so exercising it would need an architectural
	# change to the function, not just a new test.

	Invoke-TLSummaryCheck
	Write-TLFooter

} elseif ("" -eq $TestPhase) {
    Write-TLDetail "Input tests skipped" "pass -TestInput to enable" -Icon warn
    Write-TLDetail "To test manually" "Read-TLInput -Prompt '...' -Default '...'"
    Write-TLDetail "               " "Read-TLInput -Prompt '...' -Mode Secure"
    Write-TLDetail "               " "Read-TLInput -Prompt '...' -Mode Mask"
}


if (ShouldRun "glyphs") {
	Write-TLPhase "GLYPHS" "Set-TLGlyphSet - ASCII vs Unicode"
	# -----------------------------------------------------------------------------

	Test-TL "ASCII glyph set - all icons" {
		Set-TLGlyphSet -CharSet ASCII
		Write-TLDetail "ok in ASCII"   "confirmed" -Icon ok
		Write-TLDetail "warn in ASCII" "low"       -Icon warn
		Write-TLDetail "error in ASCII" "not found" -Icon Error
		Confirm-TLVisual "Icons show as + ! x instead of ✓ ⚠ ✗"
		Set-TLGlyphSet   # reset to Unicode
	}

	Test-TL "Unicode glyph set - all icons" {
		Set-TLGlyphSet -CharSet Unicode
		Write-TLDetail "ok in Unicode"   "confirmed" -Icon ok
		Write-TLDetail "warn in Unicode" "low"       -Icon warn
		Write-TLDetail "error in Unicode" "not found" -Icon Error
	}

	Test-TL "ASCII glyph set - list" {
		Set-TLGlyphSet -CharSet ASCII
		Write-TLListBegin "ASCII list"
		Write-TLListItem "item one"
		Write-TLListItem "item two"
		Write-TLListEnd -Tick
		Set-TLGlyphSet
	}
}


# =============================================================================
# RESULTS
# =============================================================================

## put a final test header and footer here showing how many sections passed and failed
# eg total error count and in which phase
# log each phase as its entered, then increment a counter per error. error sections may skip this.

$footerMsg = if ($testsFailed -eq 0) { "All tests passed" } else { "$script:testCount tests / $testsFailed failed" }
Write-TLFooter -Message $footerMsg


if ("" -eq $TestPhase) {
	if ($script:summaryExpected -gt 0) {
		Test-TL "Visual - Summary dot leaders" {
			Confirm-TLVisual "Summary dot leaders aligned - labels left, values right, icons semantic"
		}
	}

	Test-TL "Visual - Footer" {
		Confirm-TLVisual "Footer shows centred pipe - message | elapsed - banner above"
	}
	
	# =============================================================================
	# PSSA
	# =============================================================================


	Write-TLPhase "PSSA" "Invoke-ScriptAnalyzer on TidyLog.ps1"

	$analysisResults = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\TidyLog.ps1" -Settings "$PSScriptRoot\..\PSScriptAnalyzerSettings.psd1"

	if ($analysisResults.Count -eq 0) {
		Write-TLDetail "PSSA passed" "zero findings" -Icon ok -ShowInSummary
	} else {
		Write-TLDetail "PSSA findings" "$($analysisResults.Count) issue(s)" -Icon Error -ShowInSummary
		foreach ($finding in $analysisResults) {
			Write-TLDetail "$($finding.Severity)" "$($finding.RuleName): $($finding.Message) (line $($finding.Line))" -Icon warn
		}
	}
}

Write-Output ""