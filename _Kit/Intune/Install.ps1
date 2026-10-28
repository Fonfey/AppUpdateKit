<#
.SYNOPSIS
    Intune install script for {{APPNAME}} {{VERSION}}  (AppUpdateKit)

.DESCRIPTION
    Upload this script in Intune with the Win32 app:
      Program > Installer type: PowerShell script > Install script
    It does NOT go into the .intunewin package. That way you can change it later in Intune
    (texts, postponing, times, parameters, extra steps) without repackaging.

    Repackaging is only needed for a new installer, a different logo or a new kit version.
    If you change something here in Intune, also change it in the Builder, otherwise it's gone at the next build.

    Created by the AppUpdateKit Builder on {{BUILDDATE}} (kit version {{KITVERSION}}).
#>

# =============================================================================
#  1. SWITCHES  ($true = on)
# =============================================================================
$NoProcessCheck = $false   # don't check whether the app is open
                            #   then also use Requirement-NoProcessCheck.ps1 in Intune
$NoPopup       = $false   # no popup, install right away (notifications bottom right stay)
$Silent            = $false   # no popup and no notifications

# Own switches for the steps below (available in the cmd lines as APP_<NAME>)
$Switches = @{
{{SCHAKELAARS}}
}

# =============================================================================
#  2. SETTINGS AND TEXTS  (same meaning as in app.psd1)
#     In texts: {AppName}, {Version}, {Minutes}, {MaxPostpones}. Empty ('') = default text.
# =============================================================================
$App = @{
{{INSTELLINGEN}}
}

# =============================================================================
#  3. INSTALLATION STEPS
#     Components are run in order from the package folder.
#     Command = the command line (with parameters); SuccessCodes = exit codes that count as success.
# =============================================================================
$Components = @(
{{ONDERDELEN}}
)

# cmd lines before and after the components (may stay empty)
$PreInstall = @'
{{VOOR}}
'@

$PostInstall = @'
{{NA}}
'@

# Own installation script (only used if there are no components above)
$CustomScript = @'
{{EIGEN_SCRIPT}}
'@


# =============================================================================
#  DO NOT CHANGE FROM HERE
# =============================================================================
$ErrorActionPreference = 'Stop'

# Package folder: Intune starts this script from the extracted content of the .intunewin package
$PackageDir = (Get-Location).Path
foreach ($candidate in @($PackageDir, $PSScriptRoot)) {
    if ($candidate -and (Test-Path (Join-Path $candidate 'AppUI-Launcher.ps1'))) { $PackageDir = $candidate; break }
}
$AppDataDir = Join-Path 'C:\ProgramData\AppUpdates' $App.AppId
if (-not (Test-Path $AppDataDir)) { New-Item -Path $AppDataDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $AppDataDir 'update.log'

function Write-InstallLog([string]$Text) {
    $lineText = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [install] $Text"
    Add-Content -Path $LogFile -Value $lineText -ErrorAction SilentlyContinue
    Write-Host $lineText   # Write-Host: doesn't end up in the output of functions
}

if (-not (Test-Path (Join-Path $PackageDir 'AppUI-Launcher.ps1'))) {
    Write-InstallLog "ERROR: the package content was not found (folder: $PackageDir). Does install.intunewin of $($App.AppName) belong to this script?"
    exit 1
}
Set-Location $PackageDir
Write-InstallLog "Start $($App.AppName) $($App.Version) (PowerShell installer, package: $PackageDir)"

# Prepare settings for the windows (they read this file instead of app.psd1)
$configFile = Join-Path $AppDataDir 'app.json'
[System.IO.File]::WriteAllText($configFile, ($App | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
$env:APPKIT_CONFIG = $configFile

# Pass switches on to the cmd lines
foreach ($name in @($Switches.Keys)) {
    if ($Switches[$name]) { Set-Item -Path "env:APP_$($name.ToUpper())" -Value '1' }
}
# New installation or update? (determines the texts in the windows)
$ps0 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $ps0 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackageDir 'Test-AppInstalled.ps1') | Out-Null
$env:APPKIT_NEWINSTALL = if ($LASTEXITCODE -ne 0) { '1' } else { '0' }

$switchesOn = @(@{ GeenProcescheck = $NoProcessCheck; GeenPopup = $NoPopup; Stil = $Silent }.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }) +
       @($Switches.Keys | Where-Object { $Switches[$_] })
if ($switchesOn) { Write-InstallLog "Switches on: $($switchesOn -join ', ')" }

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Invoke-KitScript([string]$name, [string[]]$ScriptArgs = @()) {
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackageDir $name) @Argumenten | Out-Null
    return $LASTEXITCODE
}

function Invoke-CmdBlock([string]$Text, [string]$name) {
    # Run cmd lines in the package folder; returns the exit code
    $stepsDir = Join-Path $AppDataDir 'Steps'
    if (-not (Test-Path $stepsDir)) { New-Item -Path $stepsDir -ItemType Directory -Force | Out-Null }
    $cmdFile = Join-Path $stepsDir "$name.cmd"
    $content = "@echo off`r`ncd /d `"$PackageDir`"`r`n" + ($Text -replace "`r?`n", "`r`n") + "`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText($cmdFile, $content, [System.Text.Encoding]::Default)
    & $env:ComSpec /c $cmdFile | ForEach-Object { Add-Content -Path $LogFile -Value "    $_" -ErrorAction SilentlyContinue }
    $rc = $LASTEXITCODE
    Remove-Item -Path $cmdFile -Force -ErrorAction SilentlyContinue
    return $rc
}

function Invoke-Installation {
    $result = 0
    if ($PreInstall.Trim()) {
        $rc = Invoke-CmdBlock $PreInstall 'pre'
        Write-InstallLog "Steps before the installation done (exit code $rc)"
    }

    $componentList = @($Components | Where-Object { $_ })
    if (-not $componentList.Count -and $CustomScript.Trim()) {
        Write-InstallLog 'Own installation script is running'
        return (Invoke-CmdBlock ("set APP_EXITCODE=0`r`n" + $CustomScript) 'custom-script')
    }

    $n = 0
    foreach ($o in $componentList) {
        $n++
        Write-InstallLog "Component $n ($($o.Name)): $($o.Command)"
        $rc = Invoke-CmdBlock $o.Command "component$n"
        $okCodes = @($o.SuccessCodes | ForEach-Object { [int]$_ })
        if (-not $okCodes.Count) { $okCodes = 0, 3010, 1641 }
        if ($okCodes -notcontains $rc) {
            Write-InstallLog "Component $n ($($o.Name)) failed with exit code $rc"
            return $rc
        }
        Write-InstallLog "Component $n ($($o.Name)) succeeded (exit code $rc)"
        if ($rc -eq 3010 -or $rc -eq 1641) { $result = $rc }
    }

    if ($PostInstall.Trim()) {
        $rc = Invoke-CmdBlock $PostInstall 'post'
        Write-InstallLog "Steps after the installation done (exit code $rc)"
    }
    return $result
}

try {
    if ($Silent) { $NoPopup = $true }

    # 1. The app must not be open (Intune tries again later)
    if (-not $NoProcessCheck -and (Invoke-KitScript 'Test-AppRunning.ps1') -ne 0) { exit 1618 }

    # 2. Ask for consent (Later = postpone: stop without installing)
    if (-not $NoPopup) {
        if ((Invoke-KitScript 'Ask-InstallConsent.ps1') -ne 0) {
            Write-InstallLog 'Installation skipped for now (postponed, outside the time window or no response).'
            exit 0
        }
        # 3. Again: the app may have been opened while the window or the countdown was running
        if (-not $NoProcessCheck -and (Invoke-KitScript 'Test-AppRunning.ps1') -ne 0) { exit 1618 }
    }

    if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Installing') | Out-Null }

    # 4. Installation steps
    $exitCode = [int](Invoke-Installation)

    # 5. Result (0, 3010, 1641 = success)
    if (@(0, 3010, 1641) -contains $exitCode) {
        Remove-Item -Path (Join-Path $AppDataDir 'PostponeState.json') -Force -ErrorAction SilentlyContinue
        if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Success') | Out-Null }
        Write-InstallLog "Installation succeeded (exit code $exitCode)"
        # Restart prompt (RestartMode); returns 0 if the kit handles the restart
        if (-not $Silent) { $exitCode = Invoke-KitScript 'Set-RestartPrompt.ps1' @('-ExitCode', "$exitCode") }
    }
    else {
        if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Error') | Out-Null }
        Write-InstallLog "Installation failed (exit code $exitCode)"
    }
    exit $exitCode
}
catch {
    Write-InstallLog "ERROR: $($_.Exception.Message)"
    exit 1
}
