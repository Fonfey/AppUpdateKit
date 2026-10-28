<#
    Intune detection script for {{APPNAME}} - does the registry key exist?
    Upload this SEPARATELY in Intune: Detection rules > Use a custom detection script (32-bit: No, signature check: No).
    Writing something to the screen = detected. Writing nothing = not detected.
#>

$Key   = '{{DETECT_REGKEY}}'
$ValueName    = '{{DETECT_REGVALUE}}'   # empty = only check that the key exists
$MinVersion = '{{DETECT_VERSION}}'    # empty = any value

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

$Key = $Key.TrimEnd('\') -replace '^(HKEY_LOCAL_MACHINE|HKLM)\\', 'HKLM:\' -replace '^(HKEY_CURRENT_USER|HKCU)\\', 'HKCU:\'
# 32-bit apps on a 64-bit laptop are under WOW6432Node (and the other way round): look in both places
$places = @($Key, ($Key -replace '\\SOFTWARE\\WOW6432Node\\', '\SOFTWARE\'), ($Key -replace '\\SOFTWARE\\(?!WOW6432Node\\)', '\SOFTWARE\WOW6432Node\')) | Select-Object -Unique
foreach ($s in $places) {
    if (-not (Test-Path -LiteralPath $s)) { continue }
    if (-not $ValueName) { if (-not $MinVersion) { Write-Output "Detected: $s" }; break }
    $w = (Get-ItemProperty -LiteralPath $s -ErrorAction SilentlyContinue).$ValueName
    if ($null -ne $w -and (Test-Version "$w")) { Write-Output "Detected: $s\$ValueName = $w"; break }
}
exit 0   # Intune looks at the output; exit code 0 = script ran fine
