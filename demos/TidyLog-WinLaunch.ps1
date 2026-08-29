<#
.SYNOPSIS
    Launches TidyLog-Without.ps1 and TidyLog-With.ps1 side by side in Windows Terminal.

.DESCRIPTION
    Opens a single Windows Terminal window with two vertical panes:
    TidyLog-Without.ps1 on the left, TidyLog-With.ps1 on the right, for a
    direct, live before/after comparison. Both panes stay open once their
    script finishes, so the output remains visible.

.NOTES
    Requires Windows Terminal (wt.exe) on PATH. Falls back to launching two
    separate console windows if Windows Terminal isn't available.
#>

$scriptRoot    = $PSScriptRoot
$withoutScript = Join-Path $scriptRoot "TidyLog-Without.ps1"
$withScript    = Join-Path $scriptRoot "TidyLog-With.ps1"

if (-not (Test-Path $withoutScript)) {
    Write-Host "Cannot find $withoutScript" -ForegroundColor Red
    return
}
if (-not (Test-Path $withScript)) {
    Write-Host "Cannot find $withScript" -ForegroundColor Red
    return
}

if (Get-Command wt.exe -ErrorAction SilentlyContinue) {

    $sizeArgs = @("--maximized")

    $wtArgs = @(
        $sizeArgs,
        "new-tab", "--title", "Without TidyLog",
        "powershell.exe", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $withoutScript, "-ClearScreen",
        ";",
        "split-pane", "--title", "With TidyLog",
        "powershell.exe", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $withScript, "-ClearScreen"
    )

    & wt.exe @wtArgs

} else {

    Write-Host "Windows Terminal (wt.exe) not found on PATH. Falling back to two separate windows." -ForegroundColor DarkGray

    Start-Process powershell.exe -ArgumentList @(
        "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$withoutScript`""
    )
    Start-Process powershell.exe -ArgumentList @(
        "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$withScript`""
    )
}