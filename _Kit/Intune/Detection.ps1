<#
.SYNOPSIS
    {{T:Intune detectiescript voor|Intune detection script for}} {{APPNAME}}.
    {{T:Upload dit LOS in Intune (Detection rules > Use a custom detection script).|Upload this SEPARATELY in Intune (Detection rules > Use a custom detection script).}}
    {{T:Gedetecteerd = de app staat op versie|Detected = the app is at version}} {{VERSION}} {{T:of hoger.|or higher.}}

    Run script as 32-bit process on 64-bit clients : No
    Enforce script signature check                  : No
#>

$DisplayName = '{{DETECT_NAME}}'
$MinVersion  = '{{VERSION}}'

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
    Write-Output "{{T:Gedetecteerd|Detected}}: $($found.DisplayName) $($found.DisplayVersion)"
}
exit 0
