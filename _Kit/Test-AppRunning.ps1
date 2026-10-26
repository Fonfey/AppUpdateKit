<#
.SYNOPSIS
    Controleert of de app open staat (procesnamen uit app.json). NIET aanpassen per app.

.NOTES
    Exit 0 = app staat niet open
    Exit 1 = app staat open (install.cmd stopt dan met 1618, Intune probeert het later opnieuw)
#>

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

foreach ($name in @($script:App.Processes)) {
    if (-not $name) { continue }
    $p = $name -replace '\.exe$', ''
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
        Write-Log "$($script:App.AppName) staat open (proces: $p), installatie wordt uitgesteld." 'check'
        exit 1
    }
}
exit 0
