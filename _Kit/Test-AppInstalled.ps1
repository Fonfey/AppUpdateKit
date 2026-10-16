<#
.SYNOPSIS
    Is the app already on the device? Decides whether the popups talk about an installation or an update.
    Do NOT edit per app.

.NOTES
    Exit 0 = already installed (update)
    Exit 1 = not installed yet (new installation)
#>
. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

if (Test-AppInstalled) {
    Write-Log (L "$($script:App.AppName) staat al op de laptop: update." "$($script:App.AppName) is already on the device: update.") 'install'
    exit 0
}
Write-Log (L "$($script:App.AppName) staat nog niet op de laptop: nieuwe installatie." "$($script:App.AppName) is not on the device yet: new installation.") 'install'
exit 1
