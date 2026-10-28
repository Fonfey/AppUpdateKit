<#
.SYNOPSIS
    Asks the signed-in user whether the update may run now. Do NOT change per app;
    settings and texts come from app.psd1.

.DESCRIPTION
    - Time 1 to MaxPostpones: window with "Later" / "Update now".
    - After that: warning "The update starts in X minutes" without a Later button;
      after the countdown (or earlier with "Install now") the installation continues.
    - Autopilot (OOBE or Enrollment Status Page): install right away, without windows.
    - No signed-in user: install right away, or wait if NoUserAction = 'Wait'.
    - Outside the time window (InstallWindow): do nothing, try again later.
    - User idle (IdleMinutes) or screen locked: install right away, without popup.

    The postpone state is in C:\ProgramData\AppUpdates\<AppId>\PostponeState.json.
    Requirement.ps1 reads that file and blocks the installation as long as it is postponed.
    install.cmd only deletes the file when the installation really succeeded.

.NOTES
    Exit code 0 = installation may continue
    Exit code 1 = installation is skipped (for now) ("Later" or no response)
#>

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$maxPostpones       = [int](Get-AppSetting 'MaxPostpones' 5)
$postponeHours      = [int](Get-AppSetting 'PostponeHours' 24)
# Waiting time without a choice in minutes (older app.psd1 files with seconds keep working)
$waitTimeoutSeconds = if ($null -ne $script:App.ConsentTimeoutMinutes) { [int]$script:App.ConsentTimeoutMinutes * 60 }
                      else { [int](Get-AppSetting 'ConsentTimeoutSeconds' 900) }
$forcedMinutes      = [int](Get-AppSetting 'ForcedDelayMinutes' 5)

$postponeCount = 0
if (Test-Path $script:StatePath) {
    try {
        $postponeCount = [int]((Get-Content -Path $script:StatePath -Raw | ConvertFrom-Json).PostponeCount)
    }
    catch {
        Write-Log "Could not read PostponeState.json, starting with a clean state: $($_.Exception.Message)" 'consent'
    }
}

Write-Log "Started for $($script:App.AppName). PostponeCount=$postponeCount (max=$maxPostpones)" 'consent'

function Save-State {
    param([int]$Count, [Nullable[datetime]]$PostponeUntil)
    [PSCustomObject]@{
        PostponeCount = $Count
        PostponeUntil = if ($PostponeUntil) { $PostponeUntil.ToString("o") } else { $null }
    } | ConvertTo-Json | Set-Content -Path $script:StatePath -Encoding UTF8 -Force
}

# ---- New device via Autopilot: install right away, nobody to ask ----
$phase = Get-SetupPhase
if ($phase) {
    if ((Get-AppSetting 'InstallDuringSetup' $true) -eq $false) {
        Write-Log "Device is being set up ($phase); InstallDuringSetup is off, the installation comes after setup." 'consent'
        exit 1
    }
    Write-Log "Device is being set up ($phase), installation continues without asking." 'consent'
    exit 0
}

try { $user = Get-InteractiveUser }
catch {
    Write-Log "ERROR determining the signed-in user: $($_.Exception.Message)" 'consent'
    exit 0
}
if (-not $user) {
    if ((Get-AppSetting 'NoUserAction' 'Install') -eq 'Wait') {
        Write-Log "No signed-in user found, installation waits until someone signs in." 'consent'
        exit 1
    }
    Write-Log "No signed-in user found, installation continues without asking." 'consent'
    exit 0
}

# ---- Time window: only within or only outside working hours ----
$window = Get-AppSetting 'InstallWindow' 'Always'
if (-not (Test-InTimeWindow $window (Get-AppSetting 'WorkHours' '08:00-17:00') (Get-AppSetting 'WorkDays' 'mon,tue,wed,thu,fri'))) {
    Write-Log "Outside the time window ($window), installation is skipped for now (counter not increased)." 'consent'
    exit 1
}

# ---- User not working: install right away, without popup ----
$idleMinutes = [int](Get-AppSetting 'IdleMinutes' 0)
if ($idleMinutes -gt 0) {
    $activity = Get-UserActivity -User $user
    if ($activity.Locked) {
        Write-Log "Screen of $($user.Name) is locked, installation continues without asking." 'consent'
        exit 0
    }
    if ($null -ne $activity.IdleMinutes -and $activity.IdleMinutes -ge $idleMinutes) {
        Write-Log "$($user.Name) has been idle for $($activity.IdleMinutes) minutes (limit $idleMinutes), installation continues without asking." 'consent'
        exit 0
    }
    Write-Log "User is active (idle: $(if ($null -ne $activity.IdleMinutes) { "$($activity.IdleMinutes) min" } else { 'unknown' })), popup is shown." 'consent'
}

# ---- Postponing no longer possible: warning with countdown, then install ----
if ($postponeCount -ge $maxPostpones) {
    Write-Log "Maximum number of postpones reached: warning of $forcedMinutes minutes, then installation." 'consent'

    if ($forcedMinutes -gt 0) {
        # +15 s: the launcher gives the window WaitSeconds - 15 as countdown
        $forcedResponse = Start-UserPopup -WaitSeconds ($forcedMinutes * 60 + 15) -Settings @{
            Mode          = 'forced'
            Heading       = $script:App.AppName
            SubHeading    = Get-AppText 'ForcedSubHeading' 'The update starts in {Minutes} minutes'
            Message       = Get-AppText 'ForcedMessage' 'You have postponed the {AppName} update {MaxPostpones} times. In {Minutes} minutes the new version will be installed automatically. Save your work and close {AppName}.'
            InfoText      = Get-AppText 'ForcedInfo' 'Don''t want to wait? Save your work, close {AppName} and click Install now.'
            ForcedMinutes = $forcedMinutes
            IsNew         = $script:IsNewInstall
        }
        Write-Log "Forced installation continues (response: '$forcedResponse')." 'consent'
    }
    exit 0
}

# ---- Normal question: Later / Update now ----
$laterHint = if ($postponeHours -eq 24) { 'tomorrow' }
             elseif ($postponeHours % 24 -eq 0) { "in $($postponeHours / 24) days" }
             else { "in $postponeHours hours" }

$response = Start-UserPopup -WaitSeconds $waitTimeoutSeconds -Settings @{
    Mode          = 'consent'
    Heading       = $script:App.AppName
    SubHeading    = Get-AppText 'ConsentSubHeading' 'An update is available'
    Message       = Get-AppText 'ConsentMessage' 'A new version of {AppName} is ready for you. During the update (a few minutes) you can''t use {AppName}.'
    Remaining     = $maxPostpones - $postponeCount
    IsNew         = $script:IsNewInstall
    NowText       = if ($script:IsNewInstall) { 'Install now' } else { 'Update now' }
    LaterHint     = $laterHint
    ForcedMinutes = $forcedMinutes
}

Write-Log "Response received: '$response'" 'consent'

switch ($response) {
    "Yes" {
        Write-Log "User chose Update now, installation continues." 'consent'
        exit 0
    }
    "No" {
        $newCount = $postponeCount + 1
        $postponeUntil = (Get-Date).AddHours($postponeHours)
        Write-Log "User chose Later. PostponeCount becomes $newCount, postponed until $postponeUntil." 'consent'
        Save-State -Count $newCount -PostponeUntil $postponeUntil
        exit 1
    }
    default {
        Write-Log "No (valid) response within the time-out, installation is skipped for now (counter not increased)." 'consent'
        exit 1
    }
}
