<#
.SYNOPSIS
    Intune requirement script for the update of {{APPNAME}}.
    Upload this SEPARATELY in Intune (Requirements > Script); it doesn't go into the package.

.DESCRIPTION
    During Autopilot (OOBE or Enrollment Status Page) it is always met if InstallDuringSetup is on,
    also on new laptops that don't have the app yet. If it's off, the app waits until after setup.

    Otherwise met if:
      - the app is not open, AND
      - the user hasn't postponed the update recently, AND
      - it is now within the time window (InstallWindow in app.psd1), AND
      - someone is signed in, if NoUserAction = 'Wait', AND
      - (if OnlyUpdateExisting = $true in app.psd1) the app is already on the device

    Intune settings:
      Run script as 32-bit process on 64-bit clients : No
      Run this script using the logged on credentials : No
      Enforce script signature check                  : No
      Output data type : Boolean
      Operator         : Equals
      Value            : Yes

    The script returns True (met) or False (not met). The reason goes to
    C:\ProgramData\AppUpdates\<AppId>\requirement.log, never to the error output:
    Intune treats any error output as 'not met', also during Autopilot.
#>

$AppId           = '{{APPID}}'
$Processes       = @({{PROCESSES}})
$DisplayName     = '{{DETECT_NAME}}'        # name in "Apps & features"
$OnlyIfInstalled = '{{ONLY_IF_INSTALLED}}' -eq 'true'   # true = only update where the app is already installed

$InstallWindow   = '{{INSTALL_WINDOW}}'     # Always | DuringWorkHours | OutsideWorkHours
$WorkHours       = '{{WORK_HOURS}}'
$WorkDays        = '{{WORK_DAYS}}'
$NoUserAction    = '{{NO_USER_ACTION}}'     # Install | Wait
$CheckProcesses  = '{{CHECK_PROCESSES}}' -eq 'true'   # false = variant for install.cmd /noprocesscheck
$DuringSetup     = '{{INSTALL_DURING_SETUP}}' -eq 'true'   # true = install during Autopilot

# No error messages to the error output: Intune then counts the requirement as not met (exit code -1)
$ErrorActionPreference = 'SilentlyContinue'

function Test-InTimeWindow([string]$Window, [string]$Hours, [string]$Days, [datetime]$Now = (Get-Date)) {
    if (-not $Window -or $Window -eq 'Always') { return $true }
    $map = @{ 'mo' = 'Monday'; 'tu' = 'Tuesday'; 'we' = 'Wednesday'; 'th' = 'Thursday'; 'fr' = 'Friday'; 'sa' = 'Saturday'; 'su' = 'Sunday'
             'ma' = 'Monday'; 'di' = 'Tuesday'; 'wo' = 'Wednesday'; 'do' = 'Thursday'; 'vr' = 'Friday'; 'za' = 'Saturday'; 'zo' = 'Sunday' }   # also the Dutch days of older versions
    $dayList = @(($Days -split '[,; ]+') | Where-Object { $_.Length -ge 2 } | ForEach-Object { $map[$_.Trim().ToLower().Substring(0, 2)] })
    # One or more blocks: '08:00-17:00' or '09:00-10:00,13:00-14:00'
    $t = $Now.TimeOfDay
    $inHours = $false
    $blocks = @(($Hours -split '[,;]') | Where-Object { $_ -match '^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$' })
    if (-not $blocks.Count) { $blocks = @('08:00-17:00') }
    foreach ($b in $blocks) {
        $null = $b -match '^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$'
        $from = [timespan]$Matches[1]; $to = [timespan]$Matches[2]
        if ($(if ($from -le $to) { $t -ge $from -and $t -lt $to } else { $t -ge $from -or $t -lt $to })) { $inHours = $true; break }
    }
    $isWorkTime = ($dayList -contains $Now.DayOfWeek.ToString()) -and $inHours
    if ($Window -eq 'DuringWorkHours') { return $isWorkTime }
    return -not $isWorkTime
}

function Get-SetupPhase
{
    # 'OOBE' or 'ESP' during Autopilot, otherwise $null (same checks as PSADT 4)
    try
    {
        if (-not ('AppKitOobe' -as [type]))
        {
            Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class AppKitOobe { [DllImport("kernel32.dll")] public static extern bool OOBEComplete(ref int isComplete); }'
        }
        $done = 0
        if ([AppKitOobe]::OOBEComplete([ref]$done) -and $done -eq 0) { return 'OOBE' }
    }
    catch { }

    # The Enrollment Status Page runs in wwahost.exe, in the user's session
    foreach ($p in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'WWAHost.exe'" -ErrorAction SilentlyContinue))
    {
        $sid = (Invoke-CimMethod -InputObject $p -MethodName GetOwnerSid -ErrorAction SilentlyContinue).Sid
        if (-not $sid) { continue }
        $sync = @(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\*\FirstSync\$sid" -ErrorAction SilentlyContinue)
        if ($sync.Count -and -not ($sync | Where-Object { $_.IsSyncDone })) { return 'ESP' }
    }
    return $null
}

$statePath = "C:\ProgramData\AppUpdates\$AppId\PostponeState.json"

function Set-Result([bool]$Ok, [string]$Reason = '') {
    # Intune only reads the normal output: True or False. Nothing may go to the error output:
    # then Intune sees exit code -1 and the requirement as not met. The reason goes to requirement.log.
    $result = $(if ($Ok) { 'True' } else { 'False' })
    try {
        $logDir = "C:\ProgramData\AppUpdates\$AppId"
        if (-not (Test-Path $logDir)) { $null = New-Item -Path $logDir -ItemType Directory -Force }
        $logPath = Join-Path $logDir 'requirement.log'
        $text = ("$result $Reason" -replace '\s+', ' ').Trim()
        $lines = @(if (Test-Path $logPath) { Get-Content -Path $logPath -Encoding UTF8 })
        # Only a new line when the result changes, so the log stays short
        if (-not $lines.Count -or $lines[-1].Substring([Math]::Min(22, $lines[-1].Length)) -ne $text) {
            $lines = @($lines | Select-Object -Last 199) + "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $text"
            Set-Content -Path $logPath -Value $lines -Encoding UTF8
        }
    }
    catch { }
    Write-Output $result
    exit 0
}

try {
    $phase = Get-SetupPhase
    if ($phase) {
        if ($DuringSetup) { Set-Result $true "Setup in progress ($phase): install right away" }
        Set-Result $false "Setup in progress ($phase)"
    }

    if ($OnlyIfInstalled) {
        $paths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $installed = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "$DisplayName*" }
        if (-not $installed) {
            Set-Result $false 'Not installed'
        }
    }

    # Nobody signed in: nobody is disturbed, so the time window doesn't count then
    $userLoggedOn = [bool](@(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue) |
        Where-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User -ne 'defaultuser0' })
    if (-not $userLoggedOn -and $NoUserAction -eq 'Wait') {
        Set-Result $false 'No user signed in'
    }
    if ($userLoggedOn -and -not (Test-InTimeWindow $InstallWindow $WorkHours $WorkDays)) {
        Set-Result $false 'Outside time window'
    }

    if (Test-Path $statePath) {
        $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
        if ($state.PostponeUntil -and (Get-Date) -lt [datetime]$state.PostponeUntil) {
            Set-Result $false "Postponed until $($state.PostponeUntil)"
        }
    }

    foreach ($p in @($Processes | Where-Object { $CheckProcesses })) {
        if (Get-Process -Name ($p -replace '\.exe$', '') -ErrorAction SilentlyContinue) {
            Set-Result $false "App is open ($p)"
        }
    }

    Set-Result $true
}
catch {
    Set-Result $false "Error during check: $($_.Exception.Message)"
}
