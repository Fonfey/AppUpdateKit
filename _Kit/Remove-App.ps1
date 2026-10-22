<#
.SYNOPSIS
    Verwijdert een app op naam, zoals hij in "Apps en onderdelen" staat. NIET aanpassen per app.

.DESCRIPTION
    Gebruik in uninstall-app.cmd:
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "Omnissa Horizon Client"

    - Zoekt in de Uninstall-registersleutels (64- en 32-bit) naar alles waarvan de naam begint met -Name.
    - MSI-installaties: msiexec /x {productcode} /qn /norestart (werkt ook als de setup.exe dat niet kan).
    - Anders: QuietUninstallString, of UninstallString met -ExeArgs (bijv. -ExeArgs "/S").
    - Niet (meer) gevonden = niets te doen = gelukt.

.NOTES
    Exit 0 / 3010 / 1641 = gelukt; anders de foutcode van het verwijderen.
#>
param (
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$ExeArgs = ''
)

$launcher = Join-Path $PSScriptRoot 'AppUI-Launcher.ps1'
if ((Test-Path $launcher) -and (Test-Path (Join-Path $PSScriptRoot 'app.psd1'))) { . $launcher }
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) { function Write-Log([string]$Text, [string]$Tag) { Write-Host "[$Tag] $Text" } }

function Get-Entries {
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "$Name*" })
}

function Invoke-Uninstall([string]$File, [string]$Arguments) {
    Write-Log "Verwijderen: $File $Arguments" 'uninstall'
    $p = Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    return $p.ExitCode
}

$entries = Get-Entries
if (-not $entries.Count) {
    Write-Log "'$Name' staat niet (meer) in Apps en onderdelen; niets te verwijderen." 'uninstall'
    exit 0
}

$result = 0
# MSI eerst: de productcode is de sleutelnaam
foreach ($e in @($entries | Where-Object { $_.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$' -and ($_.WindowsInstaller -eq 1 -or "$($_.UninstallString)" -match 'msiexec') })) {
    $rc = Invoke-Uninstall 'msiexec.exe' "/x $($e.PSChildName) /qn /norestart"
    Write-Log "$($e.DisplayName) $($e.DisplayVersion): exitcode $rc" 'uninstall'
    if ($rc -eq 1605) { $rc = 0 }                       # al weg
    if (@(0, 3010, 1641) -notcontains $rc) { exit $rc }
    if ($rc -ne 0) { $result = $rc }
}

# Wat er dan nog staat (geen MSI): eigen verwijderprogramma
foreach ($e in @(Get-Entries)) {
    $cmd = if ($e.QuietUninstallString) { $e.QuietUninstallString } elseif ($e.UninstallString) { "$($e.UninstallString) $ExeArgs".Trim() } else { $null }
    if (-not $cmd) { continue }
    if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') { $file = $Matches[1]; $args2 = $Matches[2] }
    elseif ($cmd -match '^\s*(\S+\.exe)\s*(.*)$') { $file = $Matches[1]; $args2 = $Matches[2] }
    else { Write-Log "Onbekend verwijdercommando voor $($e.DisplayName): $cmd" 'uninstall'; continue }
    if ($file -match 'msiexec') { $args2 = ($args2 -replace '(?i)/I\s*\{', '/X{') + ' /qn /norestart' }
    $rc = Invoke-Uninstall $file $args2
    Write-Log "$($e.DisplayName) $($e.DisplayVersion): exitcode $rc" 'uninstall'
    if ($rc -eq 1605) { $rc = 0 }
    if (@(0, 3010, 1641) -notcontains $rc) { exit $rc }
    if ($rc -ne 0) { $result = $rc }
}

Start-Sleep -Seconds 3
$left = Get-Entries
if ($left.Count -and $result -eq 0) {
    Write-Log "Let op: '$Name' staat na het verwijderen nog in Apps en onderdelen ($(($left | ForEach-Object { $_.DisplayName }) -join ', '))." 'uninstall'
    exit 1603
}
Write-Log "'$Name' is verwijderd (exitcode $result)." 'uninstall'
exit $result
