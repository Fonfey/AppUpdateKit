<#
.SYNOPSIS
    Intune-verwijderscript voor {{APPNAME}} {{VERSION}}  (AppUpdateKit)

.DESCRIPTION
    Upload dit script in Intune bij de Win32-app:
      Program > Installer type: PowerShell script > Uninstall script
    Je kunt de stappen hieronder later in Intune aanpassen zonder opnieuw te verpakken.
#>

$AppId   = '{{APPID}}'
$Melding = {{UNINSTALL_NOTIFY}}   # $true = meldingen rechtsonder: "wordt verwijderd" en daarna "verwijderd" / "niet gelukt"

# cmd-regels om de app te verwijderen (uitgevoerd vanuit de pakketmap)
$Verwijderen = @'
{{UNINSTALL}}
'@

# =============================================================================
#  VANAF HIER NIET AANPASSEN
# =============================================================================
$Pakket = (Get-Location).Path
$AppMap = Join-Path 'C:\ProgramData\AppUpdates' $AppId
if (-not (Test-Path $AppMap)) { New-Item -Path $AppMap -ItemType Directory -Force | Out-Null }
$LogPad = Join-Path $AppMap 'update.log'
Add-Content -Path $LogPad -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Start (pakket: $Pakket)" -ErrorAction SilentlyContinue

# Meldingen gebruiken de teksten uit Install.ps1 (app.json), anders uit het pakket
$config = Join-Path $AppMap 'app.json'
if (Test-Path $config) { $env:APPKIT_CONFIG = $config }
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Show-Melding([string]$Type) {
    if ($Melding -and (Test-Path (Join-Path $Pakket 'Show-Toast.ps1'))) {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Pakket 'Show-Toast.ps1') -Type $Type -Force | Out-Null
    }
}
Show-Melding 'Uninstalling'

$bestand = Join-Path $AppMap 'verwijderen.cmd'
$inhoud = "@echo off`r`ncd /d `"$Pakket`"`r`nset APP_EXITCODE=0`r`n" + ($Verwijderen -replace "`r?`n", "`r`n") + "`r`nexit /b %ERRORLEVEL%`r`n"
[System.IO.File]::WriteAllText($bestand, $inhoud, [System.Text.Encoding]::Default)
& $env:ComSpec /c $bestand | ForEach-Object { Add-Content -Path $LogPad -Value "    $_" -ErrorAction SilentlyContinue }
$rc = $LASTEXITCODE
Remove-Item -Path $bestand -Force -ErrorAction SilentlyContinue

if (@(0, 3010, 1641) -contains $rc) { Show-Melding 'Uninstalled' } else { Show-Melding 'UninstallError' }

# Update-gegevens opruimen; update.log blijft staan
Unregister-ScheduledTask -TaskName "AppUpdateKit Herstart $AppId" -Confirm:$false -ErrorAction SilentlyContinue
foreach ($naam in 'PostponeState.json', 'app.json', 'UI', 'Herstart', 'Stappen') {
    Remove-Item -Path (Join-Path $AppMap $naam) -Recurse -Force -ErrorAction SilentlyContinue
}

Add-Content -Path $LogPad -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Klaar (exitcode $rc)" -ErrorAction SilentlyContinue
exit $rc
