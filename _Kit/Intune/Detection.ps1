<#
.SYNOPSIS
    Intune detectiescript voor {{APPNAME}}.
    Upload dit LOS in Intune (Detection rules > Use a custom detection script).

    Run script as 32-bit process on 64-bit clients : No
    Enforce script signature check                  : No

.DESCRIPTION
    Detectie (instelbaar in de Builder, tabblad 1 > Detectie):
      AppsEnOnderdelen : naam in "Apps en onderdelen" begint met $DisplayName, versie >= $MinVersion
      Bestand          : $File bestaat, bestandsversie >= $MinVersion (leeg = alleen bestaan)
      Register         : $RegKey\$RegValue bestaat, waarde >= $MinVersion (leeg = alleen bestaan)
    Iets op het scherm schrijven + exit 0 = gedetecteerd. Niets schrijven = niet gedetecteerd.
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

# Uitleg voor 'Testen op deze pc' in de Builder. Alleen als APPKIT_DETECT_DEBUG=1 en via de foutuitvoer,
# zodat Intune (dat alleen naar de gewone uitvoer kijkt) er niets van merkt.
$Explain = $env:APPKIT_DETECT_DEBUG -eq '1'
function Say([string]$Text) { if ($Explain) { [Console]::Error.WriteLine($Text) } }

function Test-MinVersion([string]$Found, [string]$What) {
    if (-not $MinVersion) { Say "$What bestaat (versie wordt niet gecontroleerd)."; return $true }
    $min = ConvertTo-Version $MinVersion
    $v = ConvertTo-Version $Found
    if (-not $v) { Say "$What bestaat, maar '$Found' is geen versienummer. Minimaal nodig: $MinVersion."; return $false }
    if ($v -gt $min) { Say "$What heeft versie ${Found}: HOGER dan de minimale versie $MinVersion."; return $true }
    if ($v -eq $min) { Say "$What heeft versie ${Found}: GELIJK aan de minimale versie $MinVersion."; return $true }
    Say "$What heeft versie ${Found}: LAGER dan de minimale versie $MinVersion."
    return $false
}

switch ($Method) {
    'Bestand' {
        $path = [Environment]::ExpandEnvironmentVariables($File)
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $info = (Get-Item -LiteralPath $path).VersionInfo
            $ver = if ($info.FileVersionRaw -and "$($info.FileVersionRaw)" -ne '0.0.0.0') { "$($info.FileVersionRaw)" } else { "$($info.ProductVersion)" }
            if (Test-MinVersion $ver "Bestand $path") { Write-Output "Gedetecteerd: $path $ver" }
        }
        elseif (Test-Path -LiteralPath $path -PathType Container) { Say "$path is een map, geen bestand." }
        else {
            Say "Bestand bestaat niet: $path"
            $dir = Split-Path $path -Parent
            if ($dir -and -not (Test-Path -LiteralPath $dir)) { Say "Ook de map bestaat niet: $dir" }
        }
    }
    'Register' {
        $key = $RegKey.TrimEnd('\') -replace '^HKEY_LOCAL_MACHINE\\', 'HKLM:\' -replace '^HKLM\\', 'HKLM:\' -replace '^HKEY_CURRENT_USER\\', 'HKCU:\' -replace '^HKCU\\', 'HKCU:\'
        # 32-bit apps staan op een 64-bit laptop onder WOW6432Node (en andersom): daar ook kijken
        $alt = if ($key -match '^HK(LM|CU):\\SOFTWARE\\WOW6432Node\\') { $key -replace '\\WOW6432Node\\', '\' }
               elseif ($key -match '^HK(LM|CU):\\SOFTWARE\\') { $key -replace '^(HK(LM|CU):\\SOFTWARE\\)', '$1WOW6432Node\' } else { $null }
        if (-not (Test-Path -LiteralPath $key) -and $alt -and (Test-Path -LiteralPath $alt)) {
            Say "Sleutel niet gevonden op $RegKey, wel op $alt (32-bit/64-bit); die wordt gebruikt."
            $key = $alt
        }
        if (Test-Path -LiteralPath $key) {
            if ($RegValue) {
                $props = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
                $val = $props.$RegValue
                if ($null -ne $val) {
                    if (Test-MinVersion "$val" "Registerwaarde $RegValue") { Write-Output "Gedetecteerd: $key\$RegValue = $val" }
                }
                else {
                    Say "Registersleutel bestaat, maar de waarde '$RegValue' niet."
                    $names = @($props.PSObject.Properties.Name | Where-Object { $_ -notlike 'PS*' })
                    if ($names.Count) { Say "Waarden in deze sleutel: $($names -join ', ')" }
                }
            }
            elseif (-not $MinVersion) { Write-Output "Gedetecteerd: $key"; Say 'Registersleutel bestaat (er is geen waarde en geen versie opgegeven).' }
            else { Say "Registersleutel bestaat, maar er is geen waarde opgegeven om de versie $MinVersion mee te vergelijken. Vul bij Waarde bijv. DisplayVersion in." }
        }
        else {
            Say "Registersleutel bestaat niet: $RegKey$(if ($alt) { " (ook niet onder $alt)" })"
            if ($key -match '\\Uninstall\\\{') { Say 'Bij een MSI is dit de sleutel van precies deze versie: is deze versie (al) geïnstalleerd op deze pc?' }
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
            Say "Geen app gevonden in Apps en onderdelen waarvan de naam begint met '$DisplayName'."
            $words = @($DisplayName -split '[\s\-_.]+' | Where-Object { $_.Length -ge 3 })
            $squash = ($DisplayName -replace '[\s\-_.]', '')
            $like = @($all | Where-Object { $n = $_.DisplayName; ($n -replace '[\s\-_.]', '') -like "*$squash*" -or @($words | Where-Object { $n -like "*$_*" }).Count } |
                      Select-Object -First 5 | ForEach-Object { "$($_.DisplayName) ($($_.DisplayVersion))" })
            if ($like.Count) { Say "Lijkt op: $($like -join '; ')"; Say "Tip: zet bij 'Naam in Apps en onderdelen' het begin van de naam precies zoals hierboven." }
        }
        else {
            $found = $null
            foreach ($n in $named) { if (Test-MinVersion $n.DisplayVersion "'$($n.DisplayName)'") { $found = $n; break } }
            if ($found) { Write-Output "Gedetecteerd: $($found.DisplayName) $($found.DisplayVersion)" }
        }
    }
}
exit 0
