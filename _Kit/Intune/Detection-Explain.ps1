<#
.SYNOPSIS
    Explains the detection of {{APPNAME}}, for the 'Test on this PC' button in the Builder.
    Does NOT go to Intune: Intune gets the short script for the chosen detection
    (Detection-AppsAndFeatures.ps1, Detection-File.ps1 or Detection-Registry.ps1, as Intune\Detection.ps1).
    This script does the same check and also tells why something is or isn't found.

.DESCRIPTION
    Detection (set in the Builder, tab 1 > Detection):
      AppsAndFeatures  : name in "Apps & features" starts with $DisplayName, version >= $MinVersion
      File             : $File exists, file version >= $MinVersion (empty = only exists)
      Registry         : $RegKey\$RegValue exists, value >= $MinVersion (empty = only exists)
    Writing something to the output + exit 0 = detected. Writing nothing = not detected.
#>

$Method      = '{{DETECT_METHOD}}'
$DisplayName = '{{DETECT_NAME}}'
$MinVersion  = '{{DETECT_VERSION}}'
$File        = '{{DETECT_FILE}}'
$RegKey      = '{{DETECT_REGKEY}}'
$RegValue    = '{{DETECT_REGVALUE}}'

function ConvertTo-Version([string]$Text) {
    if ($Text -notmatch '(\d+(?:\.\d+){0,3})') { return $null }
    $parts = @($Matches[1].Split('.'))
    while ($parts.Count -lt 2) { $parts += '0' }
    try { return [version]($parts -join '.') } catch { return $null }
}

# Explanation for 'Test on this PC' in the Builder. Only if APPKIT_DETECT_DEBUG=1 and via the error output,
# so Intune (which only looks at the normal output) doesn't notice it.
$Explain = $env:APPKIT_DETECT_DEBUG -eq '1'
function Say([string]$Text) { if ($Explain) { [Console]::Error.WriteLine($Text) } }

function Test-MinVersion([string]$Found, [string]$What) {
    if (-not $MinVersion) { Say "$What exists (version is not checked)."; return $true }
    $min = ConvertTo-Version $MinVersion
    $v = ConvertTo-Version $Found
    if (-not $v) { Say "$What exists, but '$Found' is not a version number. Required at least: $MinVersion."; return $false }
    if ($v -gt $min) { Say "$What has version ${Found}: HIGHER than the minimum version $MinVersion."; return $true }
    if ($v -eq $min) { Say "$What has version ${Found}: EQUAL to the minimum version $MinVersion."; return $true }
    Say "$What has version ${Found}: LOWER than the minimum version $MinVersion."
    return $false
}

switch ($Method) {
    'File' {
        $path = [Environment]::ExpandEnvironmentVariables($File)
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $info = (Get-Item -LiteralPath $path).VersionInfo
            $ver = if ($info.FileVersionRaw -and "$($info.FileVersionRaw)" -ne '0.0.0.0') { "$($info.FileVersionRaw)" } else { "$($info.ProductVersion)" }
            if (Test-MinVersion $ver "File $path") { Write-Output "Detected: $path $ver" }
        }
        elseif (Test-Path -LiteralPath $path -PathType Container) { Say "$path is a folder, not a file." }
        else {
            Say "File does not exist: $path"
            $dir = Split-Path $path -Parent
            if ($dir -and -not (Test-Path -LiteralPath $dir)) { Say "The folder doesn't exist either: $dir" }
        }
    }
    'Registry' {
        $key = $RegKey.TrimEnd('\') -replace '^HKEY_LOCAL_MACHINE\\', 'HKLM:\' -replace '^HKLM\\', 'HKLM:\' -replace '^HKEY_CURRENT_USER\\', 'HKCU:\' -replace '^HKCU\\', 'HKCU:\'
        # 32-bit apps are under WOW6432Node on a 64-bit laptop (and vice versa): look there too
        $alt = if ($key -match '^HK(LM|CU):\\SOFTWARE\\WOW6432Node\\') { $key -replace '\\WOW6432Node\\', '\' }
               elseif ($key -match '^HK(LM|CU):\\SOFTWARE\\') { $key -replace '^(HK(LM|CU):\\SOFTWARE\\)', '$1WOW6432Node\' } else { $null }
        if (-not (Test-Path -LiteralPath $key) -and $alt -and (Test-Path -LiteralPath $alt)) {
            Say "Key not found at $RegKey, but found at $alt (32-bit/64-bit); that one is used."
            $key = $alt
        }
        if (Test-Path -LiteralPath $key) {
            if ($RegValue) {
                $props = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
                $val = $props.$RegValue
                if ($null -ne $val) {
                    if (Test-MinVersion "$val" "Registry value $RegValue") { Write-Output "Detected: $key\$RegValue = $val" }
                }
                else {
                    Say "Registry key exists, but the value '$RegValue' doesn't."
                    $names = @($props.PSObject.Properties.Name | Where-Object { $_ -notlike 'PS*' })
                    if ($names.Count) { Say "Values in this key: $($names -join ', ')" }
                }
            }
            elseif (-not $MinVersion) { Write-Output "Detected: $key"; Say 'Registry key exists (no value and no version specified).' }
            else { Say "Registry key exists, but no value was specified to compare version $MinVersion with. Fill in e.g. DisplayVersion at Value." }
        }
        else {
            Say "Registry key does not exist: $RegKey$(if ($alt) { " (not under $alt either)" })"
            if ($key -match '\\Uninstall\\\{') { Say 'For an MSI this is the key of exactly this version: is this version (already) installed on this PC?' }
        }
    }
    default {
        $paths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $all = @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName })
        $named = @($all | Where-Object { $_.DisplayName -like "$DisplayName*" })
        if (-not $named.Count) {
            Say "No app found in Apps & features whose name starts with '$DisplayName'."
            $words = @($DisplayName -split '[\s\-_.]+' | Where-Object { $_.Length -ge 3 })
            $squash = ($DisplayName -replace '[\s\-_.]', '')
            $like = @($all | Where-Object { $n = $_.DisplayName; ($n -replace '[\s\-_.]', '') -like "*$squash*" -or @($words | Where-Object { $n -like "*$_*" }).Count } |
                      Select-Object -First 5 | ForEach-Object { "$($_.DisplayName) ($($_.DisplayVersion))" })
            if ($like.Count) { Say "Similar: $($like -join '; ')"; Say "Tip: set the start of the name at 'Name in Apps & features' exactly as above." }
        }
        else {
            $found = $null
            foreach ($n in $named) { if (Test-MinVersion $n.DisplayVersion "'$($n.DisplayName)'") { $found = $n; break } }
            if ($found) { Write-Output "Detected: $($found.DisplayName) $($found.DisplayVersion)" }
        }
    }
}
exit 0
