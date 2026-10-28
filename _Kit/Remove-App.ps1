<#
.SYNOPSIS
    Removes an app by name, as it appears in "Apps & features". Do NOT change per app.

.DESCRIPTION
    Use in uninstall-app.cmd:
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "7-Zip"

    - Searches the Uninstall registry keys (64- and 32-bit) for everything whose name starts with -Name.
    - MSI installations: msiexec /x {productcode} /qn /norestart (also works when the setup.exe can't).
    - Otherwise: QuietUninstallString, or UninstallString with -ExeArgs (e.g. -ExeArgs "/S").
    - Not found (anymore) = nothing to do = success.

.NOTES
    Exit 0 / 3010 / 1641 = success; otherwise the error code of the removal.
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
    Write-Log "Uninstalling: $File $Arguments" 'uninstall'
    $p = Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    return $p.ExitCode
}

$entries = Get-Entries
if (-not $entries.Count) {
    Write-Log "'$Name' is not (or no longer) in Apps & features; nothing to remove." 'uninstall'
    exit 0
}

$result = 0
# MSI first: the product code is the key name
foreach ($e in @($entries | Where-Object { $_.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$' -and ($_.WindowsInstaller -eq 1 -or "$($_.UninstallString)" -match 'msiexec') })) {
    $rc = Invoke-Uninstall 'msiexec.exe' "/x $($e.PSChildName) /qn /norestart"
    Write-Log "$($e.DisplayName) $($e.DisplayVersion): exitcode $rc" 'uninstall'
    if ($rc -eq 1605) { $rc = 0 }                       # already gone
    if (@(0, 3010, 1641) -notcontains $rc) { exit $rc }
    if ($rc -ne 0) { $result = $rc }
}

# What is still there (no MSI): own uninstaller
foreach ($e in @(Get-Entries)) {
    $cmd = if ($e.QuietUninstallString) { $e.QuietUninstallString } elseif ($e.UninstallString) { "$($e.UninstallString) $ExeArgs".Trim() } else { $null }
    if (-not $cmd) { continue }
    if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') { $file = $Matches[1]; $args2 = $Matches[2] }
    elseif ($cmd -match '^\s*(\S+\.exe)\s*(.*)$') { $file = $Matches[1]; $args2 = $Matches[2] }
    else { Write-Log "Unknown uninstall command for $($e.DisplayName): $cmd" 'uninstall'; continue }
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
    Write-Log "Note: '$Name' is still in Apps & features after removal ($(($left | ForEach-Object { $_.DisplayName }) -join ', '))." 'uninstall'
    exit 1603
}
Write-Log "'$Name' has been removed (exit code $result)." 'uninstall'
exit $result
