<#
.SYNOPSIS
    Is the app already on the laptop? Determines whether the windows are about an installation or an update.
    Do NOT change per app.

.NOTES
    Exit 0 = already there (update)
    Exit 1 = not there yet (new installation)
#>
. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

if (Test-AppInstalled) {
    Write-Log "$($script:App.AppName) is already on the laptop: update." 'install'
    exit 0
}
Write-Log "$($script:App.AppName) is not on the laptop yet: new installation." 'install'
exit 1
