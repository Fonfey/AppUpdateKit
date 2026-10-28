<#
.SYNOPSIS
    Shows a notification bottom right to the signed-in user (also when this script runs as SYSTEM).
    Do NOT change per app; texts come from app.psd1 (optional) or the default texts below.

.PARAMETER Type
    Info       : general notification (pass -Heading and -Message)
    Installing : "Installing update" with progress bar; closes by itself on Success/Error
    Success    : "Update installed" (green), closes by itself after 2 minutes
    Error      : "Update failed" (red), stays until the user closes it
    Uninstalling / Uninstalled / UninstallError : the same notifications when uninstalling.
                 Only if UninstallNotify = $true in app.psd1, or with -Force.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File Show-Toast.ps1 -Type Installing
#>

param(
    [ValidateSet('Info', 'Installing', 'Success', 'Error', 'Uninstalling', 'Uninstalled', 'UninstallError')]
    [string]$Type = 'Info',
    [string]$Heading,
    [string]$Message,
    [switch]$Force
)

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

if ($Type -like 'Uninstall*' -and -not $Force -and (Get-AppSetting 'UninstallNotify' $false) -ne $true) { exit 0 }

$flagPath = Join-Path $script:UIFolder 'install-finished.flag'

$defaults = @{
    Info       = @('{AppName}', '')
    Installing = @('Installing update',
                   '{AppName} is being updated and is unavailable for a moment. You don''t need to do anything; we''ll let you know when it''s done.')
    Success    = @('Update installed',
                   'The new version of {AppName} is ready. You can use the app again.')
    Error      = @('Update failed',
                   'Something went wrong while updating {AppName}. Is the app not working? Please contact the service desk.')
    Uninstalling   = @('Removing {AppName}',
                       '{AppName} is being removed from your laptop and is unavailable for a moment. You don''t need to do anything.')
    Uninstalled    = @('{AppName} has been removed',
                       '{AppName} is no longer on your laptop.')
    UninstallError = @('Removal failed',
                       'Something went wrong while removing {AppName}. Is this causing problems? Please contact the service desk.')
}

if (-not $Heading) { $Heading = Get-AppText "$($Type)Heading" $defaults[$Type][0] }
if (-not $Message) { $Message = Get-AppText "$($Type)Message" $defaults[$Type][1] }

Write-Log "Show-Toast started. Type='$Type' Heading='$Heading'" 'toast'

$visual = @{ Uninstalling = 'Installing'; Uninstalled = 'Success'; UninstallError = 'Error' }[$Type]
if (-not $visual) { $visual = $Type }

$settings = @{
    Mode    = 'toast'
    Type    = @{ Uninstalling = 'installing'; Uninstalled = 'success'; UninstallError = 'error' }[$Type]
    Sender  = $script:App.AppName
    Heading = $Heading
    Message = $Message
}

if (-not $settings.Type) { $settings.Type = $Type.ToLower() }

switch ($visual) {
    'Installing' {
        Remove-Item -Path $flagPath -Force -ErrorAction SilentlyContinue
        $settings.CloseFlagPath    = $flagPath
        $settings.AutoCloseSeconds = 2700   # safety net: always close after 45 minutes
    }
    'Success' {
        New-Item -Path $flagPath -ItemType File -Force | Out-Null
        $settings.AutoCloseSeconds = 120
    }
    'Error' {
        New-Item -Path $flagPath -ItemType File -Force | Out-Null
    }
}

[void](Start-UserPopup -Settings $settings)

Write-Log "Show-Toast done" 'toast'
exit 0
