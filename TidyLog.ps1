# =============================================================================
# TidyLog.ps1 : Spacious console output for PowerShell
# https://github.com/tidy-tools/tidylog-pwsh
# API reference: https://tidylog/reference/
# MIT License  : Copyright 2026 Nathan Kitchen
# Version: 0.9.0
# =============================================================================

# $TL is script-level state shared across all TidyLog functions.
# Functions read/modify properties only, never reassign $TL itself.
$TL = @{
	# Default vals. Ones marked ## are set at end of script
	Margin = $null			##
	Width  = @($null, $null, $null, $null)	 ## index: 0 = Column1Width, 1 = Column2Width, etc
	DefaultColumn = 2		##
	CharSet		  = $null	##  used by Get-TLIconInfo
	BannerWidth   = 70
	StartTime     = $null	# time that the Write-TLHeader was called
	CounterState  = @{Done = $false; LastValue = 0; LastTotal = 0}
	ListLabel     = ""      # stores labels from Write-TLListBegin for use in Write-TLListEnd
	Summary	      = [System.Collections.Generic.List[hashtable]]::new()
	SupportsRewrite = ($host.Name -ne "Windows PowerShell ISE Host")
	PhaseDefaultColor = $null	##
	Version = "0.9.0"
}


# -----------------------------------------------------------------------------
#  CONFIG & LAYOUT CONTROL
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Sets the layout widths and default column used by all output functions. Calling it with no parameters resets every value back to the library default.
.PARAMETER Margin
	Left margin, in characters, applied before all output. Default: 2. Valid range 2–16.
.PARAMETER Column1Width
	Character width of the first column.
	Default: 14. Valid range 8 - 30.
.PARAMETER Column2Width
	Character width of the second column.
	Default: 18. Valid range 12 - 40.
.PARAMETER Column3Width
	Character width of the third column.
	Default: 20. Valid range 12 - 40.
.PARAMETER Column4Width
	Character width of the fourth column.
	Default: 20. Valid range 12 - 40.
.PARAMETER DefaultColumn
	Default column used by Write-TLDetail and other output functions when -Column isn't specified.
	Accepted values: 1, 2.
	Default: 2.
#>
function Set-TLLayout {
	param(
		[ValidateRange(2,16)]
		[int]$Margin = 2,
		[ValidateRange(8, 30)]
		[int]$Column1Width = 14,
		[ValidateRange(12, 40)]
		[int]$Column2Width = 18,
		[ValidateRange(12, 40)]
		[int]$Column3Width = 20,
		[ValidateRange(12, 40)]
		[int]$Column4Width = 20,
		[ValidateRange(1,2)]
		[int]$DefaultColumn = 2
	)

	$TL.Margin = $Margin
	$TL.Width  = @($Column1Width, $Column2Width, $Column3Width, $Column4Width)
	$TL.DefaultColumn = $DefaultColumn
}


<#
.SYNOPSIS
	Returns the current layout values as a [PSCustomObject] containing Margin, Column1Width, Column2Width, Column3Width, Column4Width, and DefaultColumn.
#>
function Get-TLLayout {
	[OutputType([PSCustomObject])]
	param()

	return [PSCustomObject]@{
		Margin       = $TL.Margin
		Column1Width = $TL.Width[0]
		Column2Width = $TL.Width[1]
		Column3Width = $TL.Width[2]
		Column4Width = $TL.Width[3]
		DefaultColumn = $TL.DefaultColumn
	}
}


<#
.SYNOPSIS
	Sets the default -Tag color used in Write-TLPhase when -Color isn't specified. Calling it with no parameters resets the color back to DarkCyan.
.PARAMETER Default
	Default phase tag color. Must be a valid System.ConsoleColor.
	Default: DarkCyan.
#>
function Set-TLPhaseColor {
	param(
		[System.ConsoleColor]$Default = "DarkCyan"
	)
	$TL.PhaseDefaultColor = $Default
}


<#
.SYNOPSIS
	Sets the character set used for icon glyphs across all output functions.
.DESCRIPTION
	Use -CharSet ASCII for terminals without Unicode support. Called with no parameters resets to Unicode.
.PARAMETER CharSet
	Character set used to render icons.
	Accepted values: Unicode, ASCII.
	Default: Unicode.
#>
function Set-TLGlyphSet {
	param(
		[ValidateSet("Unicode","ASCII")]
		[string]$CharSet = "Unicode"
	)
	$TL.CharSet = $CharSet
}


<#
.SYNOPSIS
	Returns events that have been recorded with -ShowInSummary. Without -EventType will return all summary events. -EventType allows filtering on one or more event types.
.PARAMETER EventType
	The type of the events to be returned.
	Accepted values: Success, Warning, Error, Exception
#>
function Get-TLEventSummary {
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateSet("Success", "Warning", "Error", "Exception")]
        [string[]]$EventType
    )

	$typeToIcon = @{
		Success   = "Ok"
		Warning   = "Warn"
		Error     = "Error"
		Exception = "Exception"
	}

    $entries = if ($EventType) {
		$iconType = $EventType | ForEach-Object { $typeToIcon[$_] }
        @($TL.Summary | Where-Object { $_.Icon -in $iconType })
    } else {
		$TL.Summary
	}

	$iconToType   = @{
		Ok        = "Success"
		Warn      = "Warning"
		Error     = "Error"
		Exception = "Exception"
	}

	# repackage $TL.Summary into single Message and EventType objects
	foreach ($entry in $entries) {
        $message = if ([string]::IsNullOrEmpty($entry.Detail)) {
            $entry.Label
        } else {
			$colon = if (-not $entry.Label.TrimEnd().EndsWith(":")) { ":" }
            "$($entry.Label)$colon $($entry.Detail)"
        }

		$type = $iconToType[$entry.Icon]

        [PSCustomObject]@{
            Message   = $message
            EventType = $type
        }
    }
}


# -----------------------------------------------------------------------------
#  TIMER
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Returns the elapsed time since the timer was started by Write-TLHeader.
.DESCRIPTION
	Formatted as 00m 00s, or 00h 00m 00s once the elapsed time exceeds an hour. Returns 00m 00s if no timer is currently running.
#>
function Get-TLElapsed {
	[OutputType([string])]
	param()

	if ($null -eq $TL.StartTime) { return "00m 00s" }

	$ts    = New-TimeSpan -Start $TL.StartTime
	$hours = [int]$ts.TotalHours
	$mins  = [int]$ts.TotalMinutes - ($hours * 60)

	$elapsedTime = "$("{0:D2}" -f $mins)m $("{0:D2}" -f $ts.Seconds)s"

	if ($hours -gt 0) {
		$elapsedTime = "$("{0:D2}" -f $hours)h $elapsedTime"
	}

	return $elapsedTime
}

# -----------------------------------------------------------------------------
#  STRUCTURE
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Prints an header banner with -Title and -Summary.
.DESCRIPTION
	Self-sizing banner, right-aligned summary. Banner width is calculated automatically from header content with minimum 60 chars, maximum 100. Starts a timer if one is not already running.
.PARAMETER Title
	Left aligned title. Will default to the caller file name minus extension.
.PARAMETER Summary
	Right aligned summary. Each entry split by ·/. (Unicode/ASCII). Max 4 entries.
.PARAMETER SummaryColor
	Sets the color of the right aligned summary. Must be a valid System.ConsoleColor.
#>
function Write-TLHeader {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Title = "",
		[ValidateCount(1, 4)]
		[string[]]$Summary = "",
		[System.ConsoleColor]$SummaryColor = "DarkGray"
	)

	# default the title to calling script name if not provided
	if ([string]::IsNullOrEmpty($Title)) {
		$scriptPath = (Get-PSCallStack)[1].ScriptName
		$Title = if (-not [string]::IsNullOrEmpty($scriptPath)) {
			[System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
		} else {
			"Script"
		}
	}

	# only start timer if not already running, preserves elapsed time across multiple headers
	if ($null -eq $TL.StartTime) { $TL.StartTime = Get-Date }

	$TL.DefaultColumn = 2	# deliberate reset

	$titlePart   = $Title
	$summaryPart = ""

	if ($Summary -and $Summary.Count -gt 0) {
		$summaryPart = $Summary -join " $((Get-TLIconInfo Dot).Glyph) "
	}

	# size banner to the content, within reason
	$contentLen = $titlePart.Length + $summaryPart.Length
	$tableWidth = [Math]::Max($TL.BannerWidth, [Math]::Min(100, $contentLen + 6))	# 6 is min centre gap between title and summary

	while ($contentLen -gt $tableWidth - 6) {
		# truncate longest strings to fit within $tableWidth
		$titlePart   = Get-HeaderPart $titlePart $summaryPart
		$summaryPart = Get-HeaderPart $summaryPart $titlePart
		$contentLen  = $titlePart.Length + $summaryPart.Length
	}

	$gap = [Math]::Max(6, $tableWidth - $titlePart.Length - $summaryPart.Length)

	Write-Host ""
	Write-Host (Get-TLPaddedText $titlePart 1).TrimEnd() -NoNewline -ForegroundColor White
	Write-Host ((" " * $gap) + $summaryPart) -ForegroundColor $SummaryColor

	Write-TLBanner $tableWidth
	Write-Host ""
}


<#
.SYNOPSIS
	Closing banner with optional -Message and elapsed runtime.
.DESCRIPTION
	Auto-renders a summary table if entries exist (see Write-TLDetail -ShowInSummary) and has a short pause before dropping back to the command line. If called without a matching Write-TLHeader (no timer started), the elapsed runtime is omitted. Stops and clears a running timer that was started with a previous Write-TLHeader.
.PARAMETER Message
	Completion message. Defaults to Done.
#>
function Write-TLFooter {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Message = "Done"
	)

	# set here for variable visibility outside of summary building section
	$tableWidth = $TL.BannerWidth

	if ($TL.Summary.Count -gt 0) {	# auto-create summary if entries exist
		$entries = $TL.Summary.ToArray()

		# count the types of entries and build a string for output
		$eventTypes = @("Success", "Warning", "Error", "Exception")
		$parts = @()

		foreach ($type in $eventTypes) {
			$count = @(Get-TLEventSummary -EventType $type).Count
			if ($count -gt 0) {
				$plural = if ($count -gt 1 -and $type -ne "Success") { "s" }
				$parts += "$count $type$plural"
			}
		}

		$countSummary = if (@(Get-TLEventSummary -EventType Warning,Error,Exception).Count -eq 0) {
			"All Ok"
		} else {
			$parts -join " $((Get-TLIconInfo Dot).Glyph) "
		}

		# calculate the content length and use it to size $TL.BannerWidth
		$longestLabelLen = 0; $longestDetailLen = 0

		foreach ($entry in $entries) {
			$labelDisplayLen  = $entry.Label.Length
			$detailDisplayLen = $entry.Detail.Length

			$longestLabelLen  = [Math]::Max($labelDisplayLen, $longestLabelLen)
			$longestDetailLen = [Math]::Max($detailDisplayLen, $longestDetailLen)
		}

		# if needed, adjust $tableWidth to fit content
		$dotGap    = (" " * 3)
		$iconSpace = 2
		$buffer    = ($dotGap.Length * 2) + $iconSpace

		$contentLen = [Math]::Min(100 - $buffer, ($longestLabelLen + $longestDetailLen))
		$contentLen = [Math]::Max($TL.BannerWidth - $buffer, $contentLen)
		$tableWidth = [Math]::Max($TL.BannerWidth, $contentLen + $buffer)

		# write the summary header
		$title  = "Results"
		$gap	= [Math]::Max(1, $tableWidth - $title.Length - $countSummary.Length)
		$errors = @(Get-TLEventSummary -EventType Error,Exception).Count
		$countSummaryColor = if ($errors -gt 0) { (Get-TLIconInfo "Error").Color } elseif (@(Get-TLEventSummary -EventType Warning).Count -gt 0) { (Get-TLIconInfo "Warn").Color } else { (Get-TLIconInfo "Ok").Color }

		Write-Host ""
		Write-TLBanner $tableWidth
		Write-Host (Get-TLPaddedText $title 1).TrimEnd() -NoNewline -ForegroundColor Gray
		Write-Host ((" " * $gap) + $countSummary) -ForegroundColor $countSummaryColor
		Write-TLBanner $tableWidth
		Write-Host ""

		# write out each summary line
		$minDots   = 4
		foreach ($entry in $entries) {
			$displayLabel  = $entry.Label
			$displayDetail = $entry.Detail
			$contentLen    = $displayLabel.Length + $displayDetail.Length + $buffer + $minDots		# include minDots as these are added later

			while ($contentLen -gt $tableWidth) {
				# truncate longest strings to fit
				$displayLabel  = Get-HeaderPart $displayLabel $displayDetail -MaxLength ($displayLabel.Length)
				$displayDetail = Get-HeaderPart $displayDetail $displayLabel -MaxLength $displayDetail.Length
				$contentLen    = $displayLabel.Length + $displayDetail.Length + $buffer + $minDots
			}

			$contentLen  = $displayLabel.Length + $displayDetail.Length + $buffer	# remove minDots to get the accurate content length
			$dotCount = [Math]::Max($minDots, ($tableWidth - $contentLen))
			$dots	  = "." * $dotCount
			$iconInfo = Get-TLIconInfo $entry.Icon

			Write-Host ((Get-TLIndentSpacing 1) + $displayLabel + $dotGap) -NoNewline -ForegroundColor DarkGray
			Write-Host ($dots + $dotGap)				   -NoNewline -ForegroundColor DarkGray
			Write-Host "$displayDetail $($iconInfo.Glyph)" -ForegroundColor $iconInfo.Color
		}

		$TL.Summary.Clear()		# clear now the info has been displayed
	}	# end summary table

	# summary done, display banner, message and elapsed time
	Write-Host ""
	Write-TLBanner $tableWidth

	$leftPad = [Math]::Max(0, $tableWidth / 2 - "$Message  |".Length)
	if ($null -eq $TL.StartTime) {
		$leftPad = [Math]::Max(0, ($tableWidth / 2) - [Math]::Floor($Message.Length / 2))
	}

	$paddedMessage = (" " * $leftPad) + (Get-TLPaddedText $Message 1).TrimEnd()
	Write-Host $paddedMessage -NoNewline -ForegroundColor Gray

	if ($null -ne $TL.StartTime) {
		$elapsed        = Get-TLElapsed
		$TL.StartTime = $null
		Write-Host "  |" -NoNewline -ForegroundColor DarkGray
		Write-Host ("  " + $elapsed) -ForegroundColor DarkGray
	} else {
		Write-Host ""
	}

	Write-Host ""
	Start-Sleep -Milliseconds 650
}

# -----------------------------------------------------------------------------
#  PHASE
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Opens a phase with a margin aligned -Tag and optional -Description. Always preceded by a newline unless suppressed with -SkipLeadingNewline.
.PARAMETER Tag
	Phase title that's left aligned to Margin (see Get-TLLayout).
.PARAMETER Description
	Text to the right of the -Tag. If left blank will be populated with ··/.. (Unicode/ASCII).
.PARAMETER Color
	Sets the -Tag font color. Must be a valid System.ConsoleColor.
	Default inherits $TL.PhaseDefaultColor.
.PARAMETER ShowElapsed
	Shows right aligned script runtime in format 00m 00s.
.PARAMETER SkipLeadingNewline
	Suppresses the newline insertion above the -Tag.
#>
function Write-TLPhase {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Tag,
		[string]$Description = "",
		[System.ConsoleColor]$Color=$TL.PhaseDefaultColor,
		[switch]$ShowElapsed,
		[switch]$SkipLeadingNewline
	)

	$TL.DefaultColumn = 2	# reset at each phase call
	if (-not $SkipLeadingNewline) { Write-Host "" }
	$glyph		 = $(Get-TLIconInfo Dot).Glyph
	$description = if ([string]::IsNullOrEmpty($Description)) { $glyph * 2 } else { $Description }	# replace blank description

	# wrap and pad the tag
	$tag = Get-TLPaddedText -Text ("[" + $Tag.ToUpper() + "]") -Column 1
	Write-Host $tag -NoNewline -ForegroundColor $Color

	if ($ShowElapsed -and $null -ne $TL.StartTime) {
		# show the elapsed time on the right side
		$windowWidth	= $Host.UI.RawUI.WindowSize.Width - 10
		$line	 		= $tag + $description
		$elapsedPad		= " " * [Math]::Max(1, $windowWidth - $line.Length)

		Write-Host $description -ForegroundColor Gray -NoNewline
		Write-Host ($elapsedPad + (Get-TLElapsed)) -ForegroundColor DarkGray
	} else {
		Write-Host $description	-ForegroundColor Gray
	}
}


<#
.SYNOPSIS
	Displays a -Label with optional -Detail.
.DESCRIPTION
	Sits indented within a phase. Add one or more Write-TLDetail to any phase. Color the -Detail text by specifying an -Icon. See About the Grid Layout for indent overview.
.PARAMETER Label
	Left aligned and indented summary label.
.PARAMETER Detail
	Additional detail relating to the label. Positioned right of -Label in the column after -Label.
.PARAMETER Icon
	Colors the -Detail text and appends a glyph.
	Accepted values: Ok, Warn, Error, None.
	Default: None.
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
.PARAMETER ShowInSummary
	Shows -Label and -Detail in the footer summary table. Requires -Icon Ok|Warn|Error.
.PARAMETER BeginSection
	Inserts a new line above -Label. Useful for starting sub-sections within a phase.
.PARAMETER EndSection
	Inserts a new line below -Detail.
#>
function Write-TLDetail {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[string]$Detail = "",
		[ValidateSet("Ok","Warn","Error","None")]
		[string]$Icon = "None",
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn,
		[switch]$ShowInSummary,
		[switch]$BeginSection,
		[switch]$EndSection
	)

	if ($ShowInSummary) { Add-TLSummaryLine -Label $Label -Detail $Detail -Icon $Icon }
	if ($BeginSection) { Write-Host "" }

	$iconInfo    = Get-TLIconInfo $Icon

	if ([string]::IsNullOrEmpty($Detail)) {
		$paddedLabel = Get-TLPaddedText -Text $Label -Column $Column -Icon $Icon
		Write-Host $paddedLabel -ForegroundColor $iconInfo.Color
	} else {
		$paddedLabel = Get-TLPaddedText -Text $Label -Column $Column
		Write-Host $paddedLabel -NoNewline -ForegroundColor DarkGray
		Write-Host (Get-TLPaddedText -Text $Detail -Icon $Icon) -ForegroundColor $iconInfo.Color
	}

	if ($EndSection) {Write-Host ""}
}


# -----------------------------------------------------------------------------
#  LIST
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Begins an inline list of items. Useful for compact display of stepped progress tasks that end in completion.
.PARAMETER Label
	Descriptor for the list.
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
#>
function Write-TLListBegin {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn
	)

	$TL.ListLabel = $Label	# used in TLListEnd when -ShowInSummary is passed

	$paddedLabel  = Get-TLPaddedText -Text $Label -Column $Column
	Write-Host $paddedLabel -NoNewline -ForegroundColor DarkGray
}


<#
.SYNOPSIS
	Adds an item to an inline list.
.DESCRIPTION
	First added item is positioned in the column to the right of the -Label created by Write-TLListBegin. Subsequent items appended to same line and are separated by ·/. (Unicode/ASCII).
.PARAMETER Item
	Text to be added.
#>
function Write-TLListItem {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Item
	)
	$iconDot = Get-TLIconInfo Dot
	Write-Host "$Item $($iconDot.Glyph) " -NoNewline -ForegroundColor DarkGray
}


<#
.SYNOPSIS
	Closes the list. Accepts optional confirmation -Message and -Icon.
.PARAMETER Message
	Text for the closing message. Defaults to done.
.PARAMETER Icon
	Colors the -Message text and appends a glyph.
	Accepted values Ok, Warn, Error, None.
	Default: None.
.PARAMETER ShowInSummary
	Shows -Message in the footer summary table. Requires -Icon Ok|Warn|Error.
#>
function Write-TLListEnd {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Message = "done",
		[ValidateSet("Ok","Warn","Error","None")]
		[string]$Icon = "None",
		[switch]$ShowInSummary
	)

	if ($ShowInSummary) { Add-TLSummaryLine -Label $TL.ListLabel -Detail $Message -Icon $Icon }

	$iconInfo = Get-TLIconInfo $Icon
	Write-Host "$Message $($iconInfo.Glyph)" -ForegroundColor $iconInfo.Color
}

# -----------------------------------------------------------------------------
#  PROGRESS
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Start the progress dot display with a left aligned -Label.
.PARAMETER Label
	Left aligned label.
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
#>
function Write-TLProgressDotBegin {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn
	)
	Write-TLListBegin $Label $Column
	Start-Sleep -Milliseconds 300	# pause to allow label to register before displaying dots
}


<#
.SYNOPSIS
	Adds a dot to the row started by Write-TLProgressDotBegin. Displays a ·/. (Unicode/ASCII).
#>
function Write-TLProgressDotAdd {
	$dot = (Get-TLIconInfo Dot).Glyph
	Write-Host $dot -NoNewline -ForegroundColor DarkGray
}


<#
.SYNOPSIS
	Ends the dot sequence with closing green -Message and optional -Tick.
.PARAMETER Message
	Closing message. Default: done.
.PARAMETER Icon
	Colors the -Message text and appends a glyph.
	Accepted values: Ok, Warn, Error, None.
	Default: None.
#>
function Write-TLProgressDotEnd {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Message = "done",
		[ValidateSet("Ok","Warn","Error","None")]
		[string]$Icon = "None"
	)

	Write-TLListEnd -Message " $Message" -Icon $Icon
}


# -----------------------------------------------------------------------------
#  WAITING
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Fixed-duration wait.
.DESCRIPTION
	Under 8 seconds and the dots animate in a single color. Waiting 8 seconds or more, the wait splits into color stages indicated by -Tone so a long wait visibly signals progress against set time.
.PARAMETER Label
	Left aligned text.
.PARAMETER WaitTime
	Seconds to wait.
	Default: 10.
.PARAMETER CompletionMessage
	Message shown on completion.
	Default: "".
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
.PARAMETER Tone
	Sets the color tone for the dots.
	Accepted values: Cool, Warm, Neutral
	Default: Cool.
.PARAMETER ShowInSummary
	Shows details from this line in the footer summary table.
#>
function Wait-TLTimed {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[ValidateRange(1, 86400)]	# max timeout 24 hours
		[int]$WaitTime			  = 10,
		[string]$CompletionMessage  = "",
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn,
		[ValidateSet("Warm","Cool","Neutral")]
		[string]$Tone = "Neutral",
		[switch]$ShowInSummary
	)

	# setup the wait, display the dots, then output completion message
	Invoke-TLWait -Label $Label -Column $Column
	Invoke-TLDotDisplay -Duration $WaitTime -Tone $Tone

	$iconOK = Get-TLIconInfo "Ok"

	Write-Host (" $CompletionMessage ").TrimEnd() $iconOK.Glyph -ForegroundColor $iconOK.Color
	if ($ShowInSummary) { Add-TLSummaryLine -Label $Label -Detail $CompletionMessage -Icon $iconOK.Word }
}


<#
.SYNOPSIS
	Conditional wait with animated display.
.DESCRIPTION
	Exits when -Condition is $true or -Timeout is reached. Returns $true/$false.
.PARAMETER Label
	Left aligned text.
.PARAMETER Condition
	Evaluated after each -WaitInterval. Must return $true/$false.
.PARAMETER Timeout
	Timeout ceiling in milliseconds.
	Default: 15000 (15 seconds).
.PARAMETER CompletionMessage
	Message shown when -Condition is met.
	Default: None, shows just the glyph.
.PARAMETER TimeoutMessage
	Message shown if the wait times out.
	Default: "timed out".
.PARAMETER WaitInterval
	Seconds between -Condition polls.
	Default: 1.
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
.PARAMETER Tone
	Sets the color tone for the dots.
	Accepted values: Cool, Warm, Neutral
	Default inherits Cool.
.PARAMETER ShowInSummary
	Shows details from this line in the footer summary table.
#>
function Wait-TLConditional {
	[OutputType([bool])]
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Condition,
		[ValidateRange(1, 86400000)]		# max timeout 24 hours
		[int]$Timeout               = 15000,
		[string]$CompletionMessage  = "",
		[string]$TimeoutMessage   	= "timed out",
		[ValidateRange(1, 60)]				# max polling interval is 1 min
		[int]$WaitInterval 			= 1,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn,
		[ValidateSet("Warm","Cool","Neutral")]
		[string]$Tone = "Neutral",
		[switch]$ShowInSummary
	)

	Invoke-TLWait -Label $Label -Column $Column

	# display dots while waiting for condition to be met
	$timeoutSeconds = $Timeout / 1000
	$conditionMet   = Invoke-TLDotDisplay -Duration $timeoutSeconds -WaitInterval $WaitInterval -Condition $Condition -Tone $Tone

	# output the result based on $conditionMet
	$msg = $CompletionMessage
	$iconInfo = Get-TLIconInfo "Ok"

	if (-not $conditionMet) {
		$iconInfo = Get-TLIconInfo "Warn"
		$msg = $TimeoutMessage
	}

	Write-Host (" $msg ").TrimEnd() $iconInfo.Glyph -ForegroundColor $iconInfo.Color
	if ($ShowInSummary) {Add-TLSummaryLine -Label $Label -Detail $msg -Icon $iconInfo.Word}

	return $conditionMet
}


# -----------------------------------------------------------------------------
#  IN-PLACE COUNTERS
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	In-place counter with n of N or percentage display.
.DESCRIPTION
	Automatically detects a new sequence and resets when -Current is below the previous -Current value, or -Total is different from previous -Total. Safe to reuse across multiple loops without manual reset. Once a sequence completes, further calls are a silent no-op until a new sequence is detected. By default will update the output line in place using a rewrite. PowerShell ISE doesn't support in place rewriting, so display falls back to writing each update on its own new line. Validates input: -Total must be greater than 0; -Current must be 0 or greater. Invalid values raise a parameter error and the call is skipped.
.PARAMETER Label
	Left aligned text.
.PARAMETER Current
	Current progress value.
.PARAMETER Total
	Target value. Reaching or exceeding this flags the sequence done and -PassThru returns $true.
.PARAMETER As
	Display format.
	Accepted values: Count PercentWhole PercentExact
	Default: Count e.g. "n of Total".
	PercentWhole and PercentExact calculate -Current as percentage of -Total.
	PercentExact shows 2 decimal places.
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
.PARAMETER PassThru
	Optionally returns the sequence's done state.
	$true  = -Current reached -Total.
	$false = -Current did not reach -Total.
#>
function Write-TLCounter {
	[OutputType([bool])]
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[Parameter(Mandatory)]
		[ValidateRange(0.0, [double]::MaxValue)]
		[double]$Current,
		[Parameter(Mandatory)]
		[ValidateRange(1.0, [double]::MaxValue)]
		[double]$Total,
		[ValidateSet("Count","PercentWhole","PercentExact")]
		[string]$As = "Count",
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn,
		[switch]$PassThru
	)

	# reset counter if counting a different set
	if ($Current -lt $TL.CounterState.LastValue -or $TL.CounterState.LastTotal -ne $Total	) {
		$TL.CounterState.Done = $false
	}

	if ($TL.CounterState.Done) {
		return $(if ($PassThru) { $TL.CounterState.Done })
	}

	$TL.CounterState.LastValue = $Current	# record latest values for future comparison, see above ^
	$TL.CounterState.LastTotal = $Total

	$iconInfo  = Get-TLIconInfo Ok
	$outText   = "$Current of $Total  ", "$Current of $Total $($iconInfo.Glyph) "

	if ($As.Contains("Percent")) {
		$pct = ([double]$Current / [double]$Total) * 100
		$pct = if ("PercentExact" -eq $As) { "{0:F2}" -f [Math]::Round($pct, 2) } else { [Math]::Ceiling($pct) }

		$outText = "$pct%  ", "done $($iconInfo.Glyph)  "
	}

	$outText = if ($Current -ge $Total) { $outText[1] } else { $outText[0] }
	$paddedLabel = Get-TLPaddedText $Label $Column

	# adjust output format depnding on console support
	$rewrite   = if ($TL.SupportsRewrite) { "`r" } else { "" }
	$noNewline = if ($TL.SupportsRewrite) { $true } else { $false }

	if ($Current -ge $Total) {
		# write completion message
		Write-Host ($rewrite + $paddedLabel) -NoNewline -ForegroundColor DarkGray
		Write-Host $outText -ForegroundColor $iconInfo.Color

		$TL.CounterState.Done = $true
	} else {
		# write out the progress number on a newline for ISE hosts
		Write-Host ($rewrite + $paddedLabel + $outText) -NoNewline:$noNewline -ForegroundColor DarkGray
		$TL.CounterState.Done = $false
	}

	if ($PassThru) { return $TL.CounterState.Done }
}


<#
.SYNOPSIS
	Display in-place percentage with a -Label.
.DESCRIPTION
	Convenience function that uses Write-TLCounter -As PercentWhole. Always integer display. For two-decimal precision use Write-TLCounter directly with -As PercentExact. By default will update the output line in place using a rewrite. PowerShell ISE doesn't support in place rewriting, so display falls back to writing each update on its own new line. Validates input: -Percent must be between 0 and 100. Values outside this range raise a parameter error and the call is skipped.
.PARAMETER Label
	Left aligned text.
.PARAMETER Percent
	0–100 value. Accepts [int] or [double] and rounds up to the nearest whole number.
.PARAMETER Column
	Column position for -Label.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
.PARAMETER PassThru
	Returns the sequence's done state, $true/$false.
#>
function Write-TLPercent {
	[OutputType([bool])]
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[Parameter(Mandatory)]
		[ValidateRange(0.0, 100.0)]
		[double]$Percent,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn,
		[switch]$PassThru
	)

	$pct = [Math]::Ceiling($Percent)
	$result = Write-TLCounter -Label $Label -Current $pct -Total 100 -As PercentWhole -Column $Column -PassThru:$PassThru
	if ($PassThru) { return $result }
}


<#
.SYNOPSIS
	Clean closure of an incomplete Write-TLCounter counter sequence. Use when Write-TLCounter exits early and the last call to Write-TLCounter -PassThru returned $false.
.PARAMETER Message
	Closing message.
	Default is "" that closes the line cleanly.
.PARAMETER Icon
	Colors the -Message text and appends a glyph.
	Accepted values Ok, Warn, Error, None.
	Default: None.
.PARAMETER ShowInSummary
	Saves to summary. Requires -Message and -Icon Ok|Warn|Error to create the summary line.
#>
function Write-TLCounterEnd {
	param(
		[string]$Message = "",
		[ValidateSet("Ok","Warn","Error","None")]
		[string]$Icon = "None",
		[switch]$ShowInSummary
	)

	if ($TL.CounterState.Done) { return }

	if (-not [string]::IsNullOrEmpty($Message)) {
		$iconInfo = Get-TLIconInfo $Icon
		$fallbackIndent = if ($TL.SupportsRewrite) {" "} else {Get-TLIndentSpacing}

		Write-Host ($fallbackIndent + $Message) $iconInfo.Glyph -ForegroundColor $iconInfo.Color
		if ($ShowInSummary) {Add-TLSummaryLine -Label $Message -Icon $Icon}
	} else {
		Write-Host ""	# blank line to end the unfinished -NoNewline from Write-TLPercent
	}

	$TL.CounterState.LastValue = 0	# reset for next call. $TL.CounterState.Done is already false
	$TL.CounterState.LastTotal = 0
}


<#
.SYNOPSIS
	Clean closure of an incomplete percent sequence started by Write-TLPercent. Delegates directly to Write-TLCounterEnd (same parameters and requirements).
.PARAMETER Message
	Closing message.
	Default is "" that closes the line cleanly.
.PARAMETER Icon
	Colors the -Detail text and appends a glyph.
	Accepted values Ok, Warn, Error, None.
	Default: None.
.PARAMETER ShowInSummary
	Saves to summary. Requires -Message and -Icon Ok|Warn|Error to create the summary line.
#>
function Write-TLPercentEnd {
	param(
		[string]$Message = "",
		[ValidateSet("Ok","Warn","Error","None")]
		[string]$Icon = "None",
		[switch]$ShowInSummary
	)
	Write-TLCounterEnd $Message $Icon -ShowInSummary:$ShowInSummary
}


# -----------------------------------------------------------------------------
#  INPUT
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Read-Host wrapper with built in default value support and aligned to the detail grid.
.DESCRIPTION
	Return value depends on -Mode. Column position can be the same 1 to 4 as described in About the Grid Layout. Note: -Mask mode uses native Read-Host -MaskInput on PS 7.1+ and emulates equivalent behaviors on earlier versions.
.PARAMETER Prompt
	The prompt text that precedes the input. Leave blank to left align the cursor to the column.
.PARAMETER Mode
	Controls character display and return string format.
	Accepted values: Plain, Secure, Mask
	Default Plain makes input characters visible and returns plain text.
	-Secure and -Mask both replace input chars with an asterisk on the console.
	-Secure returns a SecureString object (System.Security.SecureString).
	-Mask returns typed characters as plain text.
.PARAMETER Default
	The default return value. Allows user to press enter without typing a value.
.PARAMETER Column
	Column position for -Prompt.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
#>
function Read-TLInput {
	[OutputType([string])]
	param(
		[string]$Prompt = "",
		[ValidateSet("Secure", "Mask", "Plain")]
		[string]$Mode = "Plain",
		[string]$Default = "",
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn
	)

	$promptText	  = if (-not [string]::IsNullOrEmpty($Default)) { "$Prompt [$Default]" } else { $Prompt }
	$paddedPrompt = (Get-TLIndentSpacing $Column) + $promptText

	if ($Mode -eq "Secure") { return (Read-Host $paddedPrompt -AsSecureString) }

	if ($Mode -eq "Mask") {
		if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 1) {
			return (Read-Host $paddedPrompt -MaskInput)
		} else {
			# use secure string to mask input, then return a plain string
			$secureString = (Read-Host $paddedPrompt -AsSecureString)
			$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
			return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
		}
	}

	# plain input
	$result = Read-Host $paddedPrompt
	if ([string]::IsNullOrEmpty($result) -and -not [string]::IsNullOrEmpty($Default)) {
		return $Default
	}

	return $result
}


<#
.SYNOPSIS
	Displays options and captures a user selection. -Options accepts either an array or an ordered hashtable and displays the options inline or stacked.
.DESCRIPTION
	Validates input: -Options must be an ordered hashtable or an array. If neither, the function will throw an error. Return value: Returns a valid key entered in the console. See -Options for exact return type. Return value can be used an an index into the passed array or hashtable.
.PARAMETER Prompt
	The instruction that sits above the list of options. The default, which can be used in most cases, is "Press the key in [brackets] to select the option:".
.PARAMETER Options
	Accepts array or ordered hashtable.
	Arrays: Using an array means the function will auto-display numbers next to each choice. This option is limited to 9 entries in the array. Returns the [int] value of the selected number.
	Hashtable: Pass custom keys by using a hashtable. Returns the exact hashtable key that relates to the chosen option.
.PARAMETER Default
	The default selection. Allows user to press enter without typing a value.
.PARAMETER ListMode
	Indicates how the options should be displayed, all options on one line or one option per line.
	Accepted values: Inline, Stack.
	Default: Stack
.PARAMETER Column
	Column position for -Prompt.
	Accepted values: 1, 2, 3, 4
	Default inherits $TL.DefaultColumn.
#>
function Read-TLSelection {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Prompt = "Press the key in [brackets] to select the option:",
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object]$Options,
		[string]$Default = "",
		[ValidateSet("Inline","Stack")]
		[string]$ListMode = "Stack",
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn
	)

    # determine path from type
    if ($Options -is [array]) {
        # cap options at 9
		if ($Options.Count -gt 9) {
			throw "Read-TLSelection: numbered options are limited to 9 items. For larger option sets consider grouping related items into separate prompts."
		}

        # build numbered display list
        $displayItems = 0..($Options.Count - 1) | ForEach-Object { "[$($_ + 1)] $($Options[$_])" }
        $validKeys    = 1..$Options.Count | ForEach-Object { "$_" }

    } elseif ($Options -is [System.Collections.IDictionary]) {
        # build keyed display items
        $displayItems = $Options.Keys | ForEach-Object { "[$_] $($Options[$_])" }
        $validKeys    = $Options.Keys | ForEach-Object { $_.ToLower() }

	} else {
		throw "Read-TLSelection: -Options must be an array or ordered hashtable."
	}

	# check supplied $Default is a valid key
	if (-not [string]::IsNullOrEmpty($Default)) {
		if ($Default.ToLower() -notin $validKeys) {
			throw "Read-TLSelection: Supplied -Default value '$Default' is not a valid option."
		}
	}

    Write-TLDetail $Prompt -BeginSection

    # display the options
    $dot = (Get-TLIconInfo Dot).Glyph
    if ($ListMode -eq "Inline") {
        Write-TLDetail ($displayItems -join "  $dot  ")
    } else {
		# stack items on newlines
		$displayItems | ForEach-Object { Write-TLDetail $_ }
    }

    # validation, re-prompt on invalid input
    while ($true) {
		$promptText = if (-not [string]::IsNullOrEmpty($Default)) { "Press Enter to select" } else { "" }
        $response   = Read-TLInput -Prompt $promptText -Column $Column -Default $Default
        if ($response.ToLower() -in $validKeys) {
			Write-Host ""	# create space below this block
            if ($Options -is [array]) {
                return [int]$response
            } else {
                return ($Options.Keys | Where-Object { $_.ToLower() -eq $response.ToLower() } | Select-Object -First 1)
            }
        }
    }
}


# -----------------------------------------------------------------------------
#  ERROR BLOCKS
# -----------------------------------------------------------------------------


<#
.SYNOPSIS
	Structured error block.
.DESCRIPTION
	Pass just a -Message to display a one line error report. Add -Detail or -Hint to display an error block with a timestamp. -Message and -Detail are always displayed in the results summary. Call Write-TLError when a condition occurred that needs attention.
.PARAMETER Message
	The main error message.
.PARAMETER Detail
	Detailed description of the error.
.PARAMETER Hint
	Hint describing how to resolve the error.
#>
function Write-TLError {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Message,
		[string]$Detail = "",
		[string]$Hint = ""
	)

	$hasDetail = (-not [string]::IsNullOrEmpty($Detail)) -or (-not [string]::IsNullOrEmpty($Hint))

	if ($hasDetail) {
		Write-TLDetail -Label $Message -Icon Error -BeginSection

		if (-not [string]::IsNullOrEmpty($Detail)) { Write-TLDetail "Detail" $Detail }
		if (-not [string]::IsNullOrEmpty($Hint))   { Write-TLDetail "Hint"   $Hint   }

		$ts = Get-Date -Format "HH:mm:ss"
		Write-TLDetail "Time" $ts -EndSection
	} else {
		# message only, output single line, no timestamp
		Write-TLDetail -Label $Message -Icon Error
	}

	Add-TLSummaryLine -Label $Message -Detail $Detail -Icon Error
}


<#
.SYNOPSIS
	Structured exception block that formats a caught PS exception. The exception message is always displayed in the results summary.
.PARAMETER ErrorRecord
	Object containing the exception.
.PARAMETER Mode
	Display mode dictates amount of detail displayed.
	Accepted values: Compact, Standard, Full
	Defaults to Standard.
	Compact includes the exception name, file name and line.
	Standard adds exception type and inner exception.
	Full adds a stack trace.
	All modes include optional -Hint and auto-timestamp.
.PARAMETER Hint
	Hint describing how to resolve the exception.
#>
function Write-TLException {
	param(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.ErrorRecord]$ErrorRecord,
		[ValidateSet("Full","Compact","Standard")]
		[string]$Mode = "Standard",
		[string]$Hint = ""
	)

	# get the error message parts
	$primaryMsg 	= $ErrorRecord.Exception.Message
	$innerException = $ErrorRecord.Exception.InnerException | Select-Object -ExpandProperty Message -ErrorAction SilentlyContinue
	$scriptName = $ErrorRecord.InvocationInfo.ScriptName
	$lineNum	= $ErrorRecord.InvocationInfo.ScriptLineNumber

	if ($Mode -eq "Compact") {
		# split sentences of $primaryMsg so they each have a new line
		Write-TLDetailMultiLine -Message $primaryMsg -Delimiter period -BeginSection
		$file = [System.IO.Path]::GetFileName($scriptName)
		Write-TLDetail -Label "Location" -Detail "${file}: line $lineNum"
	}

	# remove from $primaryMsg any duplication of Exception.InnerException prior to displaying in standard/full mode
	$primaryMsg = if ($null -ne $innerException -and $primaryMsg.Contains($innerException) -and $primaryMsg -ne $innerException) {
		$primaryMsg.Replace($innerException, "").Trim(" .")
	} else {
		$primaryMsg
	}

	Add-TLSummaryLine -Label $primaryMsg -Icon Exception

	# standard mode output
	if ($Mode -ne "Compact") {
		$typeName 	= $ErrorRecord.Exception.GetType().Name

		Write-TLDetail $primaryMsg -Icon Error -BeginSection
		Write-TLDetail "Type" $typeName

		if (-not [string]::IsNullOrEmpty($scriptName)) {
			Write-TLDetail "Location" "${scriptName}: line $lineNum"
		}
		if (-not [string]::IsNullOrEmpty($innerException)) {
			Write-TLDetailMultiLine -Label "Inner Exception" -Message $innerException -Delimiter period -Column 3
		}
	}

	if ($Mode -eq "Full") {
		$codeLine   = $ErrorRecord.InvocationInfo.Line.Trim()

		if (-not [string]::IsNullOrEmpty($codeLine)) {
			Write-TLDetail "Line" $codeLine
		}
		if (-not [string]::IsNullOrEmpty($ErrorRecord.ScriptStackTrace)) {
			Write-TLDetailMultiLine -Label "Stack Trace" -Message $ErrorRecord.ScriptStackTrace -Delimiter newline -Column 3
		}
	}

	if (-not [string]::IsNullOrEmpty($Hint)) { Write-TLDetail "Hint" $Hint }
	Write-TLDetail "Time" (Get-Date -Format "HH:mm:ss") -EndSection
}


# -----------------------------------------------------------------------------
#  INTERNAL HELPERS
#  Internal helpers section, not part of the public function set.
#  Do not call these directly. Use the public functions above.
# -----------------------------------------------------------------------------

function Write-TLBanner {
	param(
		$BannerWidth = $TL.BannerWidth
	)
	Write-Host ((" " * $TL.Margin) + ($(Get-TLIconInfo Rule).Glyph * $BannerWidth)) -ForegroundColor DarkGray
}

# returns $Text padded left and right
function Get-TLPaddedText {
	param(
		[string]$Text = "",
		[int]$Column = 0,
		[string]$Icon = "None"
	)

	# first indent the text if indent specified
	if ($Column -gt 0 ) {
		$indentSpacing = Get-TLIndentSpacing $Column
		$paddedText = $indentSpacing + $Text
	} else {
		$paddedText = $Text
	}

	# add icon if specified
	if ($Icon -ne "None") {
		$iconInfo   = Get-TLIconInfo $Icon
		$paddedText = $paddedText + " " +  $iconInfo.Glyph
	}

	# then pad right
	if ($Column -gt 0) {
		# pad right based on indent width
		$indentSpaces = Get-TLIndentSpacing -Column $Column -ColumnIncrease 1
		$buffer = if (1 -eq $Column) { 1 } else { 2 }

		if ($paddedText.Length -le ($indentSpaces.Length - $buffer)) {
			$padding = $indentSpaces.Substring( $paddedText.Length )
		} else {
			$padding = "  "		# give 2 space buffer if needed to show text separation
		}
	}

	return ($paddedText + $padding)
}


# get a string of spaces that indents equivalent to the given $Column
function Get-TLIndentSpacing {
	param(
		[ValidateNotNullOrEmpty()]
		[int]$Column = $TL.DefaultColumn,
		[int]$ColumnIncrease = 0
	)

	$index   = ($Column - 1) + $ColumnIncrease

    if ($index -lt 0 -or $index -gt 4) {
        throw "Get-TLIndentSpacing: Column plus ColumnIncrease out of the supported range. Column=$Column, ColumnIncrease=$ColumnIncrease."
    }

	$indents = (@($TL.Margin) + $TL.Width)

    $indentSum = if ($index -le 4) {
        ($indents[0..($index)] | Measure-Object -Sum).Sum
    }

    return (" " * $indentSum)
}

# add summary line with given $Icon to the $TL.Summary
function Add-TLSummaryLine {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[string]$Detail = "",
		[ValidateSet("Ok","Warn","Error","Exception","None")]
		[string]$Icon = "None"
	)

	# RLDetail and TLCounterEnd could pass a "None" value in that come from the user.
	# so accept the param, but display an error
	if ("None" -eq $Icon) {
		$errorDetails = @{
			Message = "-ShowInSummary requires -Icon Ok, Warn, or Error."
			Hint = "Add -Icon parameter with Ok, Warn, or Error to the function call."
		}
		Write-TLError @errorDetails

		return
	}

	# prefix allows easier identification in the summary table
	$prefix = switch ($Icon) {
		"Error" { "Err: " }
		"Exception" { "Exep: " }
	}

	$Icon = (Get-Culture).TextInfo.ToTitleCase($Icon)

	$TL.Summary.Add(@{
		Label = "$prefix$Label"
		Detail = if ([string]::IsNullOrEmpty($Detail)) { "" } else { $Detail }
		Icon = $Icon
	})
}

# splits long lines over multiple rows and maintains an $Column
# flexible line length based on console width
function Split-LongLine {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Text,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn
	)

	# wrap at console width if under 120, adjust buffer according to console width
	$consoleWidth = $Host.UI.RawUI.WindowSize.Width
	$rightBuffer  = if ($consoleWidth -gt 0 -and $consoleWidth -lt 120 ) { 2 } else { 10 }
	$maxWidth = $consoleWidth - ((Get-TLIndentSpacing $Column).Length + $rightBuffer)
	$maxWidth = [Math]::Max($maxWidth, 20)	# preserve min line width

	if ($Text.Length -le $maxWidth) { return @($Text) }

	$lines   = @()
	$words   = $Text -split ' '
	$currentLine = ""

	# build line array. add words to lines while each line len is < $maxWidth
	foreach ($word in $words) {
		$updatedLine = "$currentLine $word".TrimStart()
		if ($updatedLine.Length -gt $maxWidth) {
			if ($currentLine) { $lines += $currentLine.TrimEnd() }
			$currentLine = $word		# reset current line
		} else {
			$currentLine = $updatedLine	# keep building
		}
	}
	if ($currentLine) { $lines += $currentLine.TrimEnd() }

	return $lines
}


function Write-TLDetailMultiLine {
	param(
		[string]$Label,
		[ValidateNotNullOrEmpty()]
		[string]$Message,
		[ValidateSet("newline","period")]
		[string]$Delimiter,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn,
		[switch]$BeginSection
	)

	$regex = @'
(?:(?<=[a-z0-9'"])\. (?=[A-Z])|(?<=")\. (?=[A-Z])|\r?\n)
'@
	if ("newline" -eq $Delimiter) { $regex = "`n" }

	# ScriptStackTrace uses \r\n line endings on Windows
	# splitting on \n leaves trailing \r on each line
	# trimEnd removes the \r to prevent cursor overwrite artefacts
	$separated = @($Message -split $regex | ForEach-Object { $_.TrimEnd("`r") })

	# reinstate period at end of lines split by period (not newline-split lines)
	if ("period" -eq $Delimiter -and $separated.Count -gt 1) {
		foreach ($i in 0..($separated.Count - 2)) {
			if (-not $separated[$i].TrimEnd().EndsWith('.')) {
				$separated[$i] += "."
			}
		}
	}

	# keep trace lines unbroken but pass other
	# lines through Split-LongLine to wrap at word boundaries
	if ("period" -eq $Delimiter) {
		$separated = @($separated | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
			Split-LongLine -Text $_.Trim() -Column $Column
		})
	}

	if (-not [string]::IsNullOrEmpty($Label)) {
		Write-TLDetail $Label $separated[0] -BeginSection:$BeginSection		# no icon for labelled lines
	} else {
		Write-TLDetail $separated[0] -Icon Error -BeginSection:$BeginSection
	}

	$column = if ([string]::IsNullOrEmpty($Label)) { $TL.DefaultColumn } else { 3 }
	$separated | Select-Object -Skip 1 | ForEach-Object {
		Write-TLDetail $_ -Column $column
	}
}


# get details about a given icon
function Get-TLIconInfo {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$IconWord
	)

	$icon = if (-not [string]::IsNullOrEmpty($IconWord)) { $IconWord } else { "None" }

	$sets = @{
		Unicode = @{
			Ok   = @{ Glyph = "✓"; Color = "DarkGreen" }
			Warn = @{ Glyph = "⚠"; Color = "DarkYellow" }
			Error = @{ Glyph = "✗"; Color = "Red" } #✘
			Exception = @{ Glyph = "‼"; Color = "Red" }
			Dot  = @{ Glyph = "·"; Color = "DarkGray" }
			Rule = @{ Glyph = "─"; Color = "DarkGray" }
			None = @{ Glyph = ""; Color = "DarkGray" }
		}
		ASCII = @{
			Ok   = @{ Glyph = "+"; Color = "DarkGreen" }
			Warn = @{ Glyph = "!"; Color = "DarkYellow" }
			Error = @{ Glyph = "x"; Color = "Red" }
			Exception = @{ Glyph = "X"; Color = "Red" }
			Dot  = @{ Glyph = "."; Color = "DarkGray" }
			Rule = @{ Glyph = "-"; Color = "DarkGray" }
			None = @{ Glyph = ""; Color = "DarkGray" }
		}
	}

	$set   = $sets[$TL.CharSet]
	$entry = $set[$icon]
	return @{ Glyph = $entry.Glyph; Color = $entry.Color; Word = $icon }
}

# shared code for waiting functions
function Invoke-TLWait {
	param(
		[ValidateNotNullOrEmpty()]
		[string]$Label,
		[ValidateRange(1,4)]
		[int]$Column = $TL.DefaultColumn
	)

	$paddedLabel = Get-TLPaddedText $Label $Column
	Write-Host $paddedLabel -NoNewline -ForegroundColor DarkGray
	Start-Sleep -Milliseconds 300	# pause to allow label to register before displaying dots
}

# called from waiting functions to display dots based on incoming timer values
function Invoke-TLDotDisplay {
	param(
		[int]$Duration,			# time in seconds it takes the function to complete, unless interrupted by $Condition being met
		[int]$WaitInterval = 1,	# wait time between poll events
		[scriptblock]$Condition = $null,
		[ValidateSet("Warm","Cool","Neutral")]
		[string]$Tone = "Neutral"
	)

	[ConsoleColor[]]$colors = @("DarkGreen")

	if ($Duration -gt 7) {
		# select tone
		$colors = switch ($Tone) {
			"Cool" { @("DarkBlue","Blue","Cyan","Gray") }
			"Warm" { @("Red","DarkYellow","Yellow","Gray") }
			"Neutral" { @("DarkGray","Gray","White") }
		}
	}

	$elapsed   = 0
	$stageSize = $Duration / $colors.Count
	$conditionMet = $false

	while ($elapsed -lt $Duration) {
		if ($null -ne $Condition) {
			$conditionMet = (& $Condition)
			if ($conditionMet) { break }
		}

		$dot = (Get-TLIconInfo Dot).Glyph

		$stage = [Math]::Min($colors.Count - 1, [Math]::Floor($elapsed / $stageSize))
		Write-Host $dot -NoNewline -ForegroundColor $colors[$stage]
		Start-Sleep -Seconds $WaitInterval
		$elapsed += $WaitInterval
	}

	if ($PSBoundParameters.ContainsKey('Condition')) {return $conditionMet}
}

# gets truncated header title or summary
function Get-HeaderPart {
	param(
		[ValidateNotNull()]
		[string]$Part,
		[string]$PartCompare,
		[int]$MaxLength = 47
	)

	if (0 -eq $Part.Length) { return $Part }

	# 100 max banner - 6 padding between title and summery = 94; 94/2 = 47 max chars per side
	# if Part truncated, set 45 chars as allowable len to make space for the ..
	$maxLen = if ($Part.Length -ge $PartCompare.Length) { $MaxLength - 2 } else { $MaxLength }

	$addDots = $Part.EndsWith("..")
	$Part = $Part.replace("..", "")		# remove to allow accurate comparison

	if ($Part.Length -ge $maxLen) {
		$Part = $Part.Substring( 0, ([Math]::Max($maxLen, $Part.Length) - 1) )
		$Part = $Part.TrimEnd()
		$addDots = $true
	}

	if ($addDots) {
		$Part += ".."
	}

	return $Part
}


# initialise layout/config with defaults
Set-TLLayout
Set-TLPhaseColor
Set-TLGlyphSet