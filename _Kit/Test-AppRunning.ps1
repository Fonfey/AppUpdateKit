<#
.SYNOPSIS
    Checks whether the app is running (process names from the app settings). Do NOT edit per app.

.NOTES
    Exit 0 = app is not running
    Exit 1 = app is running (the installer then stops with 1618, Intune retries later)
#>

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

foreach ($name in @($script:App.Processes)) {
    if (-not $name) { continue }
    $p = $name -replace '\.exe$', ''
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
        Write-Log (L "$($script:App.AppName) staat open (proces: $p), installatie wordt uitgesteld." "$($script:App.AppName) is running (process: $p), installation postponed.") 'check'
        exit 1
    }
}
exit 0
