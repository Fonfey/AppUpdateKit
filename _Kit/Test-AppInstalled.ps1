<#
.SYNOPSIS
    Staat de app al op de laptop? Bepaalt of de vensters over een installatie of een update gaan.
    NIET aanpassen per app.

.NOTES
    Exit 0 = staat er al (update)
    Exit 1 = staat er nog niet (nieuwe installatie)
#>
. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

if (Test-AppInstalled) {
    Write-Log "$($script:App.AppName) staat al op de laptop: update." 'install'
    exit 0
}
Write-Log "$($script:App.AppName) staat nog niet op de laptop: nieuwe installatie." 'install'
exit 1
