<#
.SYNOPSIS
    Intune detectiescript voor Notepad++.
    Upload dit LOS in Intune (Detection rules > Use a custom detection script).
    Gedetecteerd = de app staat op versie 8.9.8.1 of hoger.

    Run script as 32-bit process on 64-bit clients : No
    Enforce script signature check                  : No
#>

$DisplayName = 'Notepad++'
$MinVersion  = '8.9.8.1'

function ConvertTo-Version([string]$Text) {
    if ($Text -notmatch '(\d+(?:\.\d+){0,3})') { return $null }
    $parts = @($Matches[1].Split('.'))
    while ($parts.Count -lt 2) { $parts += '0' }
    try { return [version]($parts -join '.') } catch { return $null }
}

$paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$min = ConvertTo-Version $MinVersion
$found = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "$DisplayName*" } |
    Where-Object { $v = ConvertTo-Version $_.DisplayVersion; $v -and $v -ge $min } |
    Select-Object -First 1

if ($found) {
    Write-Output "Gedetecteerd: $($found.DisplayName) $($found.DisplayVersion)"
}
exit 0
