<#
.SYNOPSIS
    Toont een melding rechtsonder aan de ingelogde gebruiker (ook als dit script als SYSTEM draait).
    NIET aanpassen per app; teksten komen uit app.psd1 (optioneel) of de standaardteksten hieronder.

.PARAMETER Type
    Info       : algemene melding (geef -Heading en -Message mee)
    Installing : "Update wordt geïnstalleerd" met voortgangsbalk; sluit vanzelf bij Success/Error
    Success    : "Update geïnstalleerd" (groen), sluit na 2 minuten vanzelf
    Error      : "Update niet gelukt" (rood), blijft staan tot de gebruiker sluit
    Uninstalling / Uninstalled / UninstallError : zelfde meldingen bij het verwijderen.
                 Alleen als UninstallNotify = $true in app.psd1, of met -Force.

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
    Installing = @('Update wordt geïnstalleerd',
                   '{AppName} wordt bijgewerkt en is even niet beschikbaar. Je hoeft niets te doen; we laten het weten zodra het klaar is.')
    Success    = @('Update geïnstalleerd',
                   'De nieuwe versie van {AppName} staat klaar. Je kunt de app weer gebruiken.')
    Error      = @('Update niet gelukt',
                   'Er ging iets mis bij het bijwerken van {AppName}. Werkt de app niet? Neem dan contact op met de servicedesk.')
    Uninstalling   = @('{AppName} wordt verwijderd',
                       '{AppName} wordt van je laptop verwijderd en is even niet beschikbaar. Je hoeft niets te doen.')
    Uninstalled    = @('{AppName} is verwijderd',
                       '{AppName} staat niet meer op je laptop.')
    UninstallError = @('Verwijderen niet gelukt',
                       'Er ging iets mis bij het verwijderen van {AppName}. Geeft dit problemen? Neem dan contact op met de servicedesk.')
}

if (-not $Heading) { $Heading = Get-AppText "$($Type)Heading" $defaults[$Type][0] }
if (-not $Message) { $Message = Get-AppText "$($Type)Message" $defaults[$Type][1] }

Write-Log "Show-Toast gestart. Type='$Type' Heading='$Heading'" 'toast'

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
        $settings.AutoCloseSeconds = 2700   # vangnet: na 45 minuten altijd sluiten
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

Write-Log "Show-Toast klaar" 'toast'
exit 0
