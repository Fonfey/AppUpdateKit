<#
    Intune detection script for {{APPNAME}} - is the app in Apps & features?
    Upload this SEPARATELY in Intune: Detection rules > Use a custom detection script (32-bit: No, signature check: No).
    Writing something to the screen = detected. Writing nothing = not detected.
#>

$name      = '{{DETECT_NAME}}'      # name starts with this
$MinVersion = '{{DETECT_VERSION}}'   # empty = any version

function ConvertTo-VersionNumber([string]$Text) {
    # Only the digits, e.g. "8.9.8.1 (x64)" -> 8.9.8.1
    $v = [regex]::Match($Text, '\d+(\.\d+){0,3}').Value
    if (-not $v) { return $null }
    if ($v -notmatch '\.') { $v += '.0' }
    try { return [version]$v } catch { return $null }
}
function Test-Version([string]$Found) {
    if (-not $MinVersion) { return $true }   # no version given: existing is enough
    $v = ConvertTo-VersionNumber $Found
    return ($v -and $v -ge (ConvertTo-VersionNumber $MinVersion))
}

$apps = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                               'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "$name*" }
foreach ($app in $apps) {
    if (Test-Version $app.DisplayVersion) { Write-Output "Detected: $($app.DisplayName) $($app.DisplayVersion)"; break }
}
exit 0   # Intune looks at the output; exit code 0 = script ran fine
