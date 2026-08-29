# Contents

- [How to use TidyLog](#how-to-use-tidylog)
  - [Header & Footer](#header--footer)
  - [Tracking Events](#tracking-events)
  - [Build Phases](#build-phases)
  - [Animate Progress](#animate-progress)
  - [Wait Functions](#wait-functions)
  - [Handle Errors](#handle-errors)
  - [Capture Input](#capture-input)
  - [Adjust Layout](#adjust-layout)
  - [Display Runtime](#display-runtime)

---

# How to use TidyLog

First run TidyLog-Demo.ps1 to see what's possible. Then come back to this reference manual to see how you can build readable logs using TidyLog functions. 

## Header & Footer

Start with a header and end with a footer to bookend the log output.

### Write-TLHeader
Prints an header banner with `-Title` and `-Summary`. Self-sizing banner, right-aligned summary. Banner width is calculated automatically from header content with minimum 60 chars, maximum 100.  Starts a timer if one is not already running.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Title` | string | Left aligned title. Will default to the caller file name minus extension.|
| `-Summary` | string[] | Right aligned summary of up to 4 words/phrases. Each entry split by `·`/`.` (Unicode/ASCII). |
| `-SummaryColor` | ConsoleColor | Sets the color of the right aligned summary. Must be a valid System.ConsoleColor. |

### Write-TLFooter 
Closing banner with optional `-Message` and elapsed runtime. Auto-renders a summary table if entries exist (see `Write-TLDetail -ShowInSummary`) and has a short pause before dropping back to the command line.  

If called without a matching `Write-TLHeader` (no timer started), the elapsed runtime is omitted. Stops and clears a running timer that was started with a previous `Write-TLHeader`.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Message` | string | Completion message. Defaults to `Done`. |

Example: 

```powershell
# call Write-TLHeader and Write-TLFooter without params for default appearance
Write-TLHeader

Write-TLPhase "SERVER" "Installing Server"
    Write-TLDetail "Server install"  "complete" -Icon Ok  -ShowInSummary	

Write-TLFooter
```

## Tracking Events
Some functions in TidyLog accept a `-ShowInSummary` parameter. This is for two reasons:  
1. It requests that a log entry be included in the summary table. The summary table is displayed when `Write-TLFooter` is called.
2. It stores the event detail and event type (`Success`, `Warning`, etc) internally so it can be later retrieved using `Get-TLEventSummary`.

The summary is a record of information from selected log entries. `Get-TLEventSummary` allows mid-script decisions to be made based on what's recorded in the summary. For example, if there is a call to `Write-TLDetail "Example" -Icon Error -ShowInSummary`, this can be retrieved from the summary using `Get-TLEventSummary -EventType Error`.

### Get-TLEventSummary

Returns events that have been recorded with `-ShowInSummary`. Without `-EventType` will return all summary events. `-EventType` allows filtering on one or more event types.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-EventType` | string[] | The type of the events to be returned. <br>Accepted values: `Success`, `Warning`, `Error`, `Exception` |

Example:

```powershell
$errorCount = @(Get-TLEventSummary -EventType "Error").Count
if ($errorCount -gt 0) {
    Write-TLDetail "Error count: $errorCount"
}

```

## Build Phases
These functions are the core of TidyLog. They build structure and show details about actions and events. Default text color is `DarkGray` with some functions allowing text highlighting.

Text is layed out in a grid using four available columns. Details of this layout system are in the [About the Grid Layout](#about-the-grid-layout) section of the function reference.

| Function | Description |
|---|---|
| `Write-TLPhase` | Structural element. Named phase tag sits at the margin. |
| `Write-TLDetail` | The main output function. Displays a label with optional detail. `-ShowInSummary` adds a line to the footer summary. |
| `Write-TLListBegin` | Begin an inline list. Useful for displaying stepped progress tasks that end in completion. |
| `Write-TLListItem` | Adds an item to an inline list.
| `Write-TLListEnd` | Complete an inline list of items with text and optional icon.  |

### Write-TLPhase 
Opens a phase with a margin aligned `-Tag` and optional `-Description`. Always preceded by a newline unless suppressed with `-SkipLeadingNewline`.
  
_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Tag`** | string | Phase title that's left aligned to `Margin` (see `Get-TLLayout`). |
| `-Description` | string | Text to the right of the `-Tag`. If not explicitly set it will be populated with `··`/`..` (Unicode/ASCII). |
| `-Color` | ConsoleColor | Sets the `-Tag` font color. Must be a valid System.ConsoleColor. <br>Default inherits `$TL.PhaseDefaultColor`. |
| `-ShowElapsed` | switch | Shows right aligned script runtime in format `00m 00s`. |
| `-SkipLeadingNewline` | switch | Suppresses the newline insertion above the `-Tag`. |

### Write-TLDetail 
Displays a `-Label` with optional `-Detail`. Sits indented within a phase. Add one or more `Write-TLDetail` to any phase. Color the `-Detail` text by specifying an `-Icon`. See [About the Grid Layout](#about-the-grid-layout) for indent overview.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Left aligned and indented summary label. |
| `-Detail` | string | Additional detail relating to the label. Positioned right of `-Label` in the column after `-Label`. |
| `-Icon` | string | Colors the `-Detail` text and appends a glyph. <br>Accepted values: `Ok`, `Warn`, `Error`, `None`. <br>Default: `None`. |
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |
| `-ShowInSummary` | switch | Shows `-Label` and `-Detail` in the footer summary table. Requires `-Icon Ok|Warn|Error`. |
| `-BeginSection` | switch | Inserts a new line above `-Label`. Useful for starting sub-sections within a phase. |
| `-EndSection` | switch | Inserts a new line below `-Detail`. |

Example:

```powershell
Write-TLPhase "SERVER" "Installing Server"
    Write-TLDetail "Java"            "21.0.3"
    Write-TLDetail "Disk space"      "low"      -Icon Warn
    Write-TLDetail "Server install"  "complete" -Icon Ok  -ShowInSummary	
```

### Write-TLListBegin

Begins an inline list of items. Useful for compact display of stepped progress tasks that end in completion.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Descriptor for the list. |
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |

Example:

```powershell
Write-TLListBegin "Installing"
Write-TLListItem  "running installer"
Write-TLListItem  "service account set"
Write-TLListEnd   -Icon Ok
```

### Write-TLListItem 

Adds an item to an inline list. First added item is positioned in the column to the right of the `-Label` created by `Write-TLListBegin`. Subsequent items appended to same line and are separated by `·`/`.` (Unicode/ASCII).

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Item`** | string | Text to be added. |

### Write-TLListEnd 

Closes the list. Accepts optional confirmation `-Message` and `-Icon`.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Message` | string |  Text for the closing message. <br>Default: `done`. |
| `-Icon` | string | Colors the `-Message` text and appends a glyph. <br>Accepted values `Ok`, `Warn`, `Error`, `None`. <br>Default: `None`. |
| `-ShowInSummary` | switch | Shows `-Message` in the footer summary table. Requires `-Icon Ok|Warn|Error`. |


## Animate Progress

Non-blocking functions to indicate incremental task progress. Control of display pacing and loop timing is done outside of these functions.

Column position can be the same 1 to 4 as described in [About the Grid Layout](#about-the-grid-layout).

| Function | Description |
|---|---|
| `Write-TLProgressDotBegin`<br>`Write-TLProgressDotAdd`<br>`Write-TLProgressDotEnd` | Manual dot-based indicator. Begin, add a dot when needed then end when done. |
| `Write-TLCounter` | In-place counter with either N of N or percentage display. |
| `Write-TLPercent` | In-place percentage. Convenience wrapper for `Write-TLCounter`. |

### Write-TLProgressDotBegin

Start the progress dot display with a left aligned `-Label`.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Left aligned label. |
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |

### Write-TLProgressDotAdd

Adds a dot to the row started by `Write-TLProgressDotBegin`. Displays a `·`/`.` (Unicode/ASCII).

_No parameters_

### Write-TLProgressDotEnd

Ends the dot sequence with closing green `-Message` and optional `-Icon`.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Message` | string | Closing message. Default: `done`. |
| `-Icon` | string | Colors the `-Message` text and appends a glyph. <br>Accepted values: `Ok`, `Warn`, `Error`, `None`. <br>Default: `None`. |

Example:

```powershell
Write-TLProgressDotBegin "Copying files"
foreach ($file in $files) {
  Write-TLProgressDotAdd
  Copy-Item $file $dest
}
Write-TLProgressDotEnd -Icon Ok
```

### Write-TLCounter

In-place counter with n of N or percentage display.

Safe to reuse across multiple loops without manual reset. Automatically detects a new sequence and resets when `-Current` is below the previous `-Current` value, or `-Total` is different from previous `-Total`. Once a sequence completes, further calls are a silent no-op until a new sequence is detected.

By default it will update the output line in place using a rewrite. PowerShell ISE doesn't support in place rewriting, so display falls back to writing each update on its own new line.

Validates input: `-Total` must be greater than 0; `-Current` must be 0 or greater. Invalid values raise a parameter error and the call is skipped.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Left aligned text. |
| **`-Current`** | double | Current progress value. |
| **`-Total`** | double | Target value. Reaching or exceeding this flags the sequence done and `-PassThru` returns `$true`. |
| `-As` | string | Display format. <br>Accepted values: `Count` `PercentWhole` `PercentExact` <br>Default: `Count` e.g. `"n of Total"`. <br>`PercentWhole` and `PercentExact` calculate `-Current` as percentage of `-Total`. <br>`PercentExact` shows 2 decimal places.|
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |
| `-PassThru` | switch | Optionally returns the sequence's done state. <br>`$true`  = `-Current` reached `-Total`. <br>`$false` = `-Current` did not reach `-Total`. |

### Write-TLCounterEnd 
Clean closure of an incomplete `Write-TLCounter` counter sequence. Use when `Write-TLCounter` exits early and the last call to `Write-TLCounter -PassThru` returned `$false`.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Message` | string | Closing message. <br>Default is `""` that closes the line cleanly. |
| `-Icon` | string | Colors the `-Message` text and appends a glyph. <br>Accepted values `Ok`, `Warn`, `Error`, `None`. <br>Default: `None`. |
| `-ShowInSummary` | switch | Saves to summary. Requires `-Message` and `-Icon Ok|Warn|Error` to create the summary line. |

Example:

```powershell
for ($i = 1; $i -le $files.Count; $i++) {
  try {
    $complete = Write-TLCounter "Copying files" $i $files.Count -PassThru
    Copy-Item $files[$i] $dest
  } catch {
    if (-not $complete) {
      Write-TLCounterEnd "copy failed at item $i" -Icon Error -ShowInSummary
    }
    break
  }
}
```

### Write-TLPercent

Display in-place percentage with a `-Label`. 

Convenience function that uses `Write-TLCounter -As PercentWhole`. Always integer display. For two-decimal precision use `Write-TLCounter` directly with `-As PercentExact`.

By default will update the output line in place using a rewrite. PowerShell ISE doesn't support in place rewriting, so display falls back to writing each update on its own new line.

Validates input: `-Percent` must be between 0 and 100. Values outside this range raise a parameter error and the call is skipped.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Left aligned text. |
| **`-Percent`** | double | 0–100 value. Accepts `[int]` or `[double]` and rounds up to the nearest whole number. |
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |
| `-PassThru` | switch | Returns the sequence's done state, `$true`/`$false`. |

### Write-TLPercentEnd

Clean closure of an incomplete percent sequence started by `Write-TLPercent`. Delegates directly to `Write-TLCounterEnd` (same parameters and requirements).

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Message` | string | Closing message. <br>Default is "" that closes the line cleanly. |
| `-Icon` | string | Colors the `-Message` text and appends a glyph. <br>Accepted values `Ok`, `Warn`, `Error`, `None`. <br>Default: `None`. |
| `-ShowInSummary` | switch | Saves to summary. Requires `-Message` and `-Icon Ok|Warn|Error` to create the summary line. |

Example:

```powershell
$pcts = @(0, 15, 33, 50)
foreach ($p in $pcts) {
  $complete = Write-TLPercent "Searching files" $p -PassThru
}
if (-not $complete) { 
  Write-TLPercentEnd "Incomplete count" -Icon Warn -ShowInSummary 
}
```

## Wait Functions

Blocking functions that display dot animation while waiting on a timer or condition. The functions control the waiting logic and only returns when the wait completes.

Column position can be the same 1 to 4 as described in [About the Grid Layout](#about-the-grid-layout).

| Function | Description |
|---|---|
| `Wait-TLTimed` | Fixed-duration wait.  |
| `Wait-TLConditional` | Polls a condition on an interval. Returns `$true`/`$false`. |

### Wait-TLTimed

Fixed-duration wait. Under 8 seconds and the dots animate in a single color. Waiting 8 seconds or more, the wait splits into color stages indicated by `-Tone` so that a long wait visibly signals progress against set time.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Left aligned text. |
| `-WaitTime` | int | Seconds to wait. <br>Default: `10`. |
| `-CompletionMessage` | string | Message shown on completion. <br>Default: `""`. |
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |
| `-Tone` | string | Sets the color tone for the dots. <br>Accepted values: `Cool`, `Warm`, `Neutral` <br>Default: `Neutral`. |
| `-ShowInSummary` | switch | Shows details from this line in the footer summary table. |

Example:

```powershell
# default wait with message
Wait-TLTimed -Label "Waiting" -CompletionMessage "service installed"
# short wait shown in summary
Wait-TLTimed -Label "Installing service" -WaitTime 5 -ShowInSummary
```

### Wait-TLConditional

Conditional wait with animated display. Exits when `-Condition` is `$true` or `-Timeout` is reached. Returns `$true`/`$false`.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Label`** | string | Left aligned text. |
| **`-Condition`** | scriptblock | Evaluated after each `-WaitInterval`. Must return `$true`/`$false`. |
| `-Timeout` | int | Timeout ceiling in milliseconds. <br>Default: `15000` (15 seconds). |
| `-CompletionMessage` | string | Message shown when `-Condition` is met. <br>Default: `None`, shows just the glyph. |
| `-TimeoutMessage` | string | Message shown if the wait times out. <br>Default: `"timed out"`. |
| `-WaitInterval` | int | Seconds between `-Condition` polls. <br>Default: `1`. |
| `-Column` | int | Column position for `-Label`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |
| `-Tone` | string | Sets the color tone for the dots. <br>Accepted values: `Cool`, `Warm`, `Neutral` <br>Default inherits `Neutral`. |
| `-ShowInSummary` | switch | Shows details from this line in the footer summary table. |

Example:
```powershell
$params = @{
    Label = "Waiting for NAS" 
    Condition = { Test-NetConnection $nas -Quiet } 
    Timeout = 60000
    }
$isNASOnline = Wait-TLConditional @params
if (-not $isNASOnline) { 
    Write-TLError "NAS unreachable" `
    -Hint "Check NAS power and network" 
}
```

## Handle Errors 

Functions to capture Errors and Exceptions and display within the grid format.

### Write-TLError

Structured error block. Pass just a `-Message` to display a one line error report. Add `-Detail` or `-Hint` to display an error block with a timestamp. `-Message` and `-Detail` are always displayed in the results summary. Call `Write-TLError` when a condition occurred that needs attention.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Message`** | string | The main error message. |
| `-Detail` | string | Detailed description of the error. |
| `-Hint` | string | Hint describing how to resolve the error. |

### Write-TLException

Structured exception block that formats a caught PS exception. The exception message is always displayed in the results summary.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-ErrorRecord`** | ErrorRecord | Object containing the exception. |
| `-Mode` | string  | Display mode dictates amount of detail displayed. <br>Accepted values: `Compact`, `Standard`, `Full` <br>Defaults to `Standard`. <br>`Compact` includes the exception name, file name and line. <br>`Standard` adds exception type and inner exception. <br>`Full` adds a stack trace. <br>All modes include optional `-Hint` and auto-timestamp. |
| `-Hint` | string | Hint describing how to resolve the exception. |

Example: 

```powershell
try { 
  Get-Item "C:\does-not-exist\file.exe" -ErrorAction Stop 
} catch {
  Write-TLException $_ `
    -Mode Compact `
    -Hint "User-facing - no stack details"
}
```

### Reporting options at a glance

Different ways to report negative outcomes.

| Function | When to use | Footer summary |
|---|---|---|
| `Write-TLDetail -Icon Error` | Expected negative outcome, handled. Recoverable. | Opt-in via `-ShowInSummary` |
| `Write-TLError` | Record a known possible fault that needs attention and may or may not be recoverable. | Always shown automatically |
| `Write-TLException` | Use when wrapping a call in `try`/`catch`. Records an unplanned exception. Assume not recoverable until investigated. | Always shown automatically |



## Capture Input

Functions to capture text and selection.

| Function | Description |
|---|---|
| `Read-TLInput` | Grid aligned keyboard input with multiple modes.  |
| `Read-TLSelection` | Displays options and captures and returns a user selection. |


### Read-TLInput

`Read-Host` wrapper with built in default value support and aligned to the detail grid. Return value depends on `-Mode`. Column position can be the same 1 to 4 as described in [About the Grid Layout](#about-the-grid-layout).

Note: `-Mask` mode uses native `Read-Host -MaskInput` on PS 7.1+ and emulates equivalent behaviors on earlier versions.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Prompt` | string | The prompt text that precedes the input. Leave blank to left align the cursor to the column. |
| `-Mode` | string  | Controls character display and return string format. <br>Accepted values: `Plain`, `Secure`, `Mask` <br>Default `Plain` makes input characters visible and returns plain text. <br>`-Secure` and `-Mask` both replace input chars with an asterisk on the console. <br>`-Secure` returns a SecureString object (System.Security.SecureString). <br>`-Mask` returns typed characters as plain text. |
| `-Default` | string | The default return value. Allows user to press enter without typing a value. |
| `-Column` | int | Column position for `-Prompt`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |

Example:

```powershell
$path = Read-TLInput -Prompt "Enter temp path" -Default "C:\Temp"
```

### Read-TLSelection

Displays options and captures a user selection. `-Options` accepts either an array or an ordered hashtable and displays the options inline or stacked.

Validates input: `-Options` must be an ordered hashtable or an array. If neither, the function will throw an error.

Return value: Returns a valid key entered in the console. See `-Options` for exact return type. Return value can be used an an index into the passed array or hashtable.

_Required parameters are **bold**._

| Parameter | Type | Description |
|---|---|---|
| **`-Prompt`** | string | The instruction that sits above the list of options. The default, which can be used in most cases, is `"Press the key in [brackets] to select the option:"`. |
| **`-Options`** | object | Accepts array or ordered hashtable. <br>Arrays: Using an array means the function will auto-display numbers next to each choice. This option is limited to 9 entries in the array. Returns the `[int]` value of the selected number. <br>Hashtable: Pass custom keys by using a hashtable. Returns the exact hashtable key that relates to the chosen option. |
| `-Default` | string | The default selection. Allows user to press enter without typing a value. |
| `-ListMode` | string | Indicates how the options should be displayed, all options on one line or one option per line. <br>Accepted values: `Inline`, `Stack`. <br>Default: `Stack`|
| `-Column` | int | Column position for `-Prompt`.  <br>Accepted values: `1`, `2`, `3`, `4` <br>Default inherits `$TL.DefaultColumn`. |

Example:

```powershell
# minimal setup, just pass an array
$options = @("Install Oracle Java", "Install Amazon Corretto", "Quit")
$choice = Read-TLSelection -Options $options

# fully configured
$options = @{
    Prompt = "Select a file" 
    Options = [ordered]@{ a = "File A"; b = "File B"; q = "Quit" }
    ListMode = "Inline"
    Default = "a"
}
$choice = Read-TLSelection @options
```

## Adjust Layout

Zero-config defaults work out of the box for many scripts. When needed, use the following functions to adjust layout and appearance.

| Function | Description |
|---|---|
| `Set-TLLayout` | Set column widths and default column.  |
| `Set-TLPhaseColor` | Set the default phase tag color.  |
| `Set-TLGlyphSet` | Set the character set used to display icons. Enables glyph fallback for ASCII terminals. |
| `Get-TLLayout` | Returns current layout values. |

Note: Calling any `Set-` function **without** params will set param values to library defaults.

### About the Grid Layout

TidyLog layout works on a grid structure. There are four columns available and each one has a dedicated width. The grid layout and default widths are represented by the table below:

| Margin | Column 1 | Column 2 | Column 3 | Column 4 |
|---|---|---|---|---|
| 2 chars | 14 chars | 18 chars | 20 chars | 20 chars |

In practice layout will look like this:

| Margin | Column 1 | Column 2 | Column 3 | Column 4 |
|---|---|---|---|---|
|  | [PHASE HEADER] | Phase Description |  |  |
|  |  | Label | Detail | Spare column |

### Set-TLLayout

Sets the layout widths and default column used by all output functions. Calling it with no parameters resets every value back to the library default.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Margin` | int | Left margin, in characters, applied before all output. Default: `2`. Valid range 2–16. |
| `-Column1Width` | int | Character width of the first column. <br>Default: `14`. Valid range 8 - 30. |
| `-Column2Width` | int | Character width of the second column. <br>Default: `18`. Valid range 12 - 40. |
| `-Column3Width` | int | Character width of the third column. <br>Default: `20`. Valid range 12 - 40. |
| `-Column4Width` | int | Character width of the fourth column. <br>Default: `20`. Valid range 12 - 40. |
| `-DefaultColumn` | int | Default column used by `Write-TLDetail` and other output functions when `-Column` isn't specified. <br>Accepted values: `1`, `2`. <br>Default: `2`. |

### Adjust the Grid Layout

Use `Set-TLLayout` to change the defaults:

```powershell
Set-TLLayout -Margin 4 -Column1Width 16 -Column2Width 20 -Column3Width 22 -Column4Width 22
Set-TLLayout -DefaultColumn 1   # set default for all output functions
Set-TLLayout                    # reset margin and widths to defaults
```

All width and margin values are validated as per the parameter table shown for `Set-TLLayout`.

`-DefaultColumn` is the default label position for all `Write-TLDetail` calls. It resets to `2` when `Write-TLPhase` and `Write-TLHeader` are called.

When content demands more room, e.g. registry paths, file paths, long labels, adjust `Column2Width` and the whole grid reflows automatically:

```powershell
Set-TLLayout -Column2Width 32   # wide label column for long registry key names
```

If setting values with variables, use a `try` / `catch` to display invalid params with clean error block.

```powershell
try {
	Set-TLLayout -Margin $margin -Column1Width $width
} catch {
	Write-TLException $_ -Hint "Check Set-TLLayout params"
}
```

### Set-TLPhaseColor

Sets the default `-Tag` color used in `Write-TLPhase` when `-Color` isn't specified. Calling it with no parameters resets the color back to `DarkCyan`.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-Default` | ConsoleColor | Default phase tag color. Must be a valid System.ConsoleColor. <br>Default: `DarkCyan`. |

### Set-TLGlyphSet

Sets the character set used for icon glyphs across all output functions. Use `-CharSet ASCII` for terminals without Unicode support. Called with no parameters resets to `Unicode`.

_No required parameters_

| Parameter | Type | Description |
|---|---|---|
| `-CharSet` | string | Character set used to render icons. <br>Accepted values: `Unicode`, `ASCII`. <br>Default: `Unicode`. |

Example:

```powershell
Set-TLGlyphSet -CharSet ASCII     # switch to ASCII glyphs
Set-TLGlyphSet                    # set to Unicode
```

Glyph table:

| Icon | Unicode | ASCII |
|---|---|---|
| Ok | ✓ | + |
| Warn | ⚠ | ! |
| Error | ✗ | x |
| Dot | · | . |
| Rule | ─ | - |


### Get-TLLayout

Returns the current layout values as a `[PSCustomObject]` containing `Margin`, `Column1Width`, `Column2Width`, `Column3Width`, `Column4Width`, and `DefaultColumn`.  


## Display Runtime

Calls to `Write-TLHeader` start a new script timer when:
- `Write-TLHeader` is first called.
- `Write-TLHeader` is called after a matching `Write-TLFooter`

Use the below functions to display the elapsed time.

| Function | Description |
|---|---|
| `Get-TLElapsed` | Returns elapsed time in format `00m 00s`. Good for mid-script checkpoints. |
| `Write-TLPhase` with `-ShowElapsed` | Right aligned display of elapsed time on the phase line. |

### Get-TLElapsed

Returns the elapsed time since the timer was started by `Write-TLHeader`. Formatted as `00m 00s`, or `00h 00m 00s` once the elapsed time exceeds an hour. Returns `00m 00s` if no timer is currently running.