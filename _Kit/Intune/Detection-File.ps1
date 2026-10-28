<#
    Intune detection script for {{APPNAME}} - does the file exist?
    Upload this SEPARATELY in Intune: Detection rules > Use a custom detection script (32-bit: No, signature check: No).
    Writing something to the screen = detected. Writing nothing = not detected.
#>

$TargetFile   = [Environment]::ExpandEnvironmentVariables('{{DETECT_FILE}}')
$MinVersion = '{{DETECT_VERSION}}'   # empty = only check that the file exists

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

if (Test-Path -LiteralPath $TargetFile -PathType Leaf) {
    $info = (Get-Item -LiteralPath $TargetFile).VersionInfo
    $version = if ("$($info.FileVersionRaw)" -notin '', '0.0.0.0') { "$($info.FileVersionRaw)" } else { "$($info.ProductVersion)" }
    if (Test-Version $version) { Write-Output "Detected: $TargetFile $version" }
}
exit 0   # Intune looks at the output; exit code 0 = script ran fine
