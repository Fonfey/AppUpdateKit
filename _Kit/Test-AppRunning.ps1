<#
.SYNOPSIS
    Checks whether the app is open (process names from app.json). Do NOT change per app.

.NOTES
    Exit 0 = app is not open
    Exit 1 = app is open (install.cmd then stops with 1618, Intune tries again later)
#>

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

foreach ($name in @($script:App.Processes)) {
    if (-not $name) { continue }
    $p = $name -replace '\.exe$', ''
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
        Write-Log "$($script:App.AppName) is open (process: $p), installation is postponed." 'check'
        exit 1
    }
}
exit 0
