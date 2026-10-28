<#
.SYNOPSIS
    Shared helper functions for the update package. Do NOT change per app.
    All app-specific details come from app.psd1 in the same folder.

.DESCRIPTION
    - Reads app.psd1 (AppId, AppName, Processes, Icon, texts, ...).
    - Determines the working folder: C:\ProgramData\AppUpdates\<AppId>
      (postpone counters, log and the window files kept separate per app).
    - Starts AppUI.ps1 as the signed-in user via a scheduled task + VBS launcher
      (no visible console window) and optionally waits for the answer.
#>

function ConvertTo-AppHashtable($Object)
{
    # JSON (PSCustomObject) back to hashtables, so $App.Texts['...'] keeps working
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Management.Automation.PSCustomObject])
    {
        $h = @{}
        foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = ConvertTo-AppHashtable $p.Value }
        return $h
    }
    if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string])
    {
        return ,@($Object | ForEach-Object { ConvertTo-AppHashtable $_ })
    }
    return $Object
}

# Settings: from the PowerShell installer in Intune (APPKIT_CONFIG), otherwise app.psd1 from the package
$script:App = $null
if ($env:APPKIT_CONFIG -and (Test-Path -LiteralPath $env:APPKIT_CONFIG))
{
    try { $script:App = ConvertTo-AppHashtable ([System.IO.File]::ReadAllText($env:APPKIT_CONFIG) | ConvertFrom-Json) } catch { $script:App = $null }
}
if (-not $script:App) { $script:App = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'app.psd1') }
function ConvertTo-CurrentSettings($d)
{
    # Versions before 1.3 used Dutch values in app.psd1 (Altijd, Bestand, ma,di,...): convert them
    if (-not $d) { return $d }
    $maps = @{
        InstallWindow   = @{ 'Altijd' = 'Always'; 'Werktijd' = 'DuringWorkHours'; 'BuitenWerktijd' = 'OutsideWorkHours' }
        NoUserAction    = @{ 'Installeren' = 'Install'; 'Wachten' = 'Wait' }
        RestartMode     = @{ 'Nooit' = 'Never'; 'AlsNodig' = 'IfNeeded'; 'Altijd' = 'Always' }
        DetectionMethod = @{ 'AppsEnOnderdelen' = 'AppsAndFeatures'; 'Bestand' = 'File'; 'Register' = 'Registry' }
    }
    foreach ($k in $maps.Keys) { $v = "$($d[$k])"; if ($v -and $maps[$k].ContainsKey($v)) { $d[$k] = $maps[$k][$v] } }
    if ("$($d['WorkDays'])" -match '\b(ma|di|wo|do|vr|za|zo)\b')
    {
        $days = @{ 'ma' = 'mon'; 'di' = 'tue'; 'wo' = 'wed'; 'do' = 'thu'; 'vr' = 'fri'; 'za' = 'sat'; 'zo' = 'sun' }
        $d['WorkDays'] = (@("$($d['WorkDays'])" -split '[,; ]+' | Where-Object { $_ } | ForEach-Object { if ($days.ContainsKey($_)) { $days[$_] } else { $_ } }) -join ',')
    }
    return $d
}
$script:App = ConvertTo-CurrentSettings $script:App

# Default texts for all apps (optional file next to this script)
$script:DefaultTexts = @{}
$stdPath = Join-Path $PSScriptRoot 'DefaultTexts.psd1'
if (Test-Path $stdPath) { try { $script:DefaultTexts = Import-PowerShellDataFile -Path $stdPath } catch { } }

$script:AppFolder = Join-Path 'C:\ProgramData\AppUpdates' $script:App.AppId
$script:UIFolder  = Join-Path $script:AppFolder 'UI'
$script:StatePath = Join-Path $script:AppFolder 'PostponeState.json'
$script:LogPath   = Join-Path $script:AppFolder 'update.log'

if (-not (Test-Path $script:UIFolder)) { New-Item -Path $script:UIFolder -ItemType Directory -Force | Out-Null }

function Write-Log
{
    param ([string]$Text, [string]$Tag = 'ui')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$Tag] $Text"
    Add-Content -Path $script:LogPath -Value $line -ErrorAction SilentlyContinue
    Write-Host $line
}

function Get-AppSetting
{
    # Value from app.psd1, or the default value if it's missing
    param ([string]$Name, $Default)
    $v = $script:App.$Name
    if ($null -eq $v -or "$v" -eq '') { return $Default }
    return $v
}

# New installation (app was not on the laptop yet) or update? Determined by install.cmd / Install.ps1.
$script:IsNewInstall = $env:APPKIT_NEWINSTALL -eq '1'
$script:NewInstallDefaults = @{
    NewConsentSubHeading    = 'A new app is ready for you'
    NewConsentMessage       = '{AppName} will be installed on your laptop. This takes a few minutes.'
    NewForcedSubHeading     = 'The installation starts in {Minutes} minutes'
    NewForcedMessage        = 'You have postponed the installation of {AppName} {MaxPostpones} times. In {Minutes} minutes {AppName} will be installed automatically. Save your work.'
    NewForcedInfo           = 'Don''t want to wait? Save your work and click Install now.'
    NewInstallingHeading    = 'Installing {AppName}'
    NewInstallingMessage    = '{AppName} is being installed on your laptop. You don''t need to do anything; we''ll let you know when it''s done.'
    NewSuccessHeading       = '{AppName} has been installed'
    NewSuccessMessage       = '{AppName} is ready. You can find the app in the Start menu.'
    NewErrorHeading         = 'Installation failed'
    NewErrorMessage         = 'Something went wrong while installing {AppName}. Do you need the app? Please contact the service desk.'
    NewRestartMessage       = '{AppName} has been installed. Restart your laptop to finish the installation. Save your work first.'
    NewRestartForcedMessage = '{AppName} has been installed and your laptop needs to restart to finish the installation. Save your work and close your programs.'
}

function Test-AppInstalled
{
    # Is the app already in "Apps & features"? (DetectName, same check as Requirement.ps1)
    $name = $script:App.DetectName
    if (-not $name) { return $true }
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    return [bool](Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "$name*" })
}

function Get-AppText
{
    # Order: own text in app.psd1 -> DefaultTexts.psd1 -> built-in text.
    # Filled in: {AppName}, {Version} (version), {Minutes} (warning minutes) and {MaxPostpones} (max postpones)
    param ([string]$Key, [string]$Default)
    $t = $null
    if ($script:IsNewInstall)
    {
        # First the text for a new installation: own text -> default texts -> built-in
        $nk = "New$Key"
        if ($script:App.Texts) { $t = $script:App.Texts[$nk] }
        if (-not $t) { $t = $script:DefaultTexts[$nk] }
        if (-not $t) { $t = $script:NewInstallDefaults[$nk] }
    }
    if (-not $t -and $script:App.Texts) { $t = $script:App.Texts[$Key] }
    if (-not $t) { $t = $script:DefaultTexts[$Key] }
    if (-not $t) { $t = $Default }
    return $t.Replace('{AppName}', $script:App.AppName).
              Replace('{Version}', [string]$script:App.Version).
              Replace('{Minutes}', [string](Get-AppSetting 'ForcedDelayMinutes' 5)).
              Replace('{MaxPostpones}', [string](Get-AppSetting 'MaxPostpones' 5)).
              Replace('{Versie}', [string]$script:App.Version).Replace('{Minuten}', [string](Get-AppSetting 'ForcedDelayMinutes' 5)).
              Replace('{MaxUitstel}', [string](Get-AppSetting 'MaxPostpones' 5))   # placeholders of versions before 1.3
}

function Get-SetupPhase
{
    <#
        Returns 'OOBE' or 'ESP' if the device is still being set up (Autopilot), otherwise $null.
          OOBE : Windows setup not finished yet (including the technician phase of pre-provisioning)
          ESP  : the Enrollment Status Page is still running for the user who just signed in
        The same checks as PSAppDeployToolkit 4 (Test-ADTOobeCompleted / Test-ADTEspActive).
    #>
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

function Get-InteractiveUser
{
    # defaultuser0 is the temporary account of Autopilot/OOBE: that doesn't count as a user
    $explorer = $null; $owner = $null
    foreach ($e in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop))
    {
        $o = Invoke-CimMethod -InputObject $e -MethodName GetOwner
        if ($o.User -and $o.User -ne 'defaultuser0') { $explorer = $e; $owner = $o; break }
    }
    if (-not $explorer) { return $null }
    $sid   = (Invoke-CimMethod -InputObject $explorer -MethodName GetOwnerSid).Sid

    $profilePath = $null
    if ($sid)
    {
        $profilePath = (Get-CimInstance -ClassName Win32_UserProfile -Filter "SID = '$sid'" -ErrorAction SilentlyContinue).LocalPath
    }
    if (-not $profilePath) { $profilePath = Join-Path "$env:SystemDrive\Users" $owner.User }

    return [pscustomobject]@{
        Name        = "$($owner.Domain)\$($owner.User)"
        ProfilePath = $profilePath
        SessionId   = $explorer.SessionId
    }
}

function Test-InTimeWindow
{
    <#
        Is this moment within the time window of the app?
        -Window : 'Always' | 'DuringWorkHours' | 'OutsideWorkHours'
        -Hours  : one or more blocks, e.g. '08:00-17:00' or '09:00-10:00,13:00-14:00'
                  (past midnight is allowed too: '22:00-06:00')
        -Days   : 'mon,tue,wed,thu,fri'
    #>
    param ([string]$Window, [string]$Hours, [string]$Days, [datetime]$Now = (Get-Date))
    if (-not $Window -or $Window -eq 'Always') { return $true }

    $map = @{ 'mo' = 'Monday'; 'tu' = 'Tuesday'; 'we' = 'Wednesday'; 'th' = 'Thursday'; 'fr' = 'Friday'; 'sa' = 'Saturday'; 'su' = 'Sunday'
               'ma' = 'Monday'; 'di' = 'Tuesday'; 'wo' = 'Wednesday'; 'do' = 'Thursday'; 'vr' = 'Friday'; 'za' = 'Saturday'; 'zo' = 'Sunday' }   # also the Dutch days of older versions
    $dayList = @(($Days -split '[,; ]+') | Where-Object { $_.Length -ge 2 } | ForEach-Object { $map[$_.Trim().ToLower().Substring(0, 2)] })

    $t = $Now.TimeOfDay
    $inHours = $false
    $blocks = @(($Hours -split '[,;]') | Where-Object { $_ -match '^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$' })
    if (-not $blocks.Count) { $blocks = @('08:00-17:00') }
    foreach ($b in $blocks)
    {
        $null = $b -match '^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$'
        $from = [timespan]$Matches[1]; $to = [timespan]$Matches[2]
        if ($(if ($from -le $to) { $t -ge $from -and $t -lt $to } else { $t -ge $from -or $t -lt $to })) { $inHours = $true; break }
    }
    $isWorkTime = ($dayList -contains $Now.DayOfWeek.ToString()) -and $inHours

    if ($Window -eq 'DuringWorkHours') { return $isWorkTime }
    return -not $isWorkTime
}

function Start-UserTask
{
    # Starts a hidden PowerShell script in the session of the signed-in user.
    # Returns the task name; the caller cleans up with Stop-UserTask.
    param ($User, [string]$ScriptPath, [string]$Arguments, [string]$Id)
    $vbsPath = Join-Path $script:UIFolder "launch_$Id.vbs"
    $vbs = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ""$ScriptPath"" $($Arguments.Replace('"', '""'))", 0, False
"@
    Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII -Force

    $taskName  = "AppUI_$($script:App.AppId)_$Id"
    $action    = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument "`"$vbsPath`""
    $principal = New-ScheduledTaskPrincipal -UserId $User.Name -LogonType Interactive -RunLevel Limited
    $settingsT = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settingsT -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    return $taskName
}

function Stop-UserTask([string]$TaskName, [string]$Id)
{
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $script:UIFolder "launch_$Id.vbs") -Force -ErrorAction SilentlyContinue
}

function Get-UserActivity
{
    <#
        Is the user working? Returns:
          Locked      : screen locked (LogonUI.exe runs in the user's session)
          IdleMinutes : minutes since the last mouse or keyboard action ($null = unknown)
    #>
    param ($User)
    $result = [pscustomobject]@{ Locked = $false; IdleMinutes = $null }

    if (Get-Process -Name LogonUI -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $User.SessionId })
    {
        $result.Locked = $true
        return $result
    }

    $id      = Get-Random
    $outPath = Join-Path $User.ProfilePath "AppData\Local\Temp\AppIdle_$($script:App.AppId)_$id.txt"
    Copy-Item -Path (Join-Path $PSScriptRoot 'Get-IdleTime.ps1') -Destination $script:UIFolder -Force -ErrorAction SilentlyContinue
    $taskName = $null
    try
    {
        $taskName = Start-UserTask -User $User -ScriptPath (Join-Path $script:UIFolder 'Get-IdleTime.ps1') -Arguments "-OutPath `"$outPath`"" -Id $id
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and -not (Test-Path $outPath)) { Start-Sleep -Milliseconds 500 }
        if (Test-Path $outPath)
        {
            Start-Sleep -Milliseconds 200
            $ms = [double]((Get-Content -Path $outPath -Raw).Trim())
            $result.IdleMinutes = [math]::Floor($ms / 60000)
        }
    }
    catch { Write-Log "Could not determine idle time: $($_.Exception.Message)" 'consent' }
    finally
    {
        if ($taskName) { Stop-UserTask $taskName $id }
        Remove-Item -Path $outPath -Force -ErrorAction SilentlyContinue
    }
    return $result
}

function Start-UserPopup
{
    <#
        -Settings      : hashtable with e.g. Mode, Type, Heading, Message (see AppUI.ps1)
        -WaitSeconds   : > 0 = wait for a response (consent); returns 'Yes'/'No'/'Timeout'/$null
        -LingerSeconds : when not waiting: how long to wait before cleaning up the temporary files
    #>
    param (
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [int]$WaitSeconds = 0,
        [int]$LingerSeconds = 15
    )

    $phase = Get-SetupPhase
    if ($phase)
    {
        Write-Log "Device is being set up ($phase), window is skipped."
        return $null
    }

    try { $user = Get-InteractiveUser }
    catch { Write-Log "ERROR determining the signed-in user: $($_.Exception.Message)"; return $null }

    if (-not $user)
    {
        Write-Log 'No signed-in user found, window is skipped.'
        return $null
    }
    Write-Log "Signed-in user: $($user.Name)"

    $iconName = Get-AppSetting 'Icon' 'app.ico'
    Copy-Item -Path (Join-Path $PSScriptRoot 'AppUI.ps1'), (Join-Path $PSScriptRoot $iconName) `
              -Destination $script:UIFolder -Force -ErrorAction SilentlyContinue

    $id = Get-Random
    $Settings.IconPath    = Join-Path $script:UIFolder $iconName
    $Settings.LogPath     = $script:LogPath
    $Settings.AccentColor = Get-AppSetting 'AccentColor' '#185FA5'

    $responsePath = $null
    if ($WaitSeconds -gt 0)
    {
        $responsePath = Join-Path $user.ProfilePath "AppData\Local\Temp\AppUI_$($script:App.AppId)_$id.txt"
        $Settings.ResponsePath   = $responsePath
        $Settings.TimeoutSeconds = [math]::Max(30, $WaitSeconds - 15)
    }

    $configPath = Join-Path $script:UIFolder "popup_$id.json"
    [System.IO.File]::WriteAllText($configPath, ($Settings | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding $false))

    $uiScript = Join-Path $script:UIFolder 'AppUI.ps1'
    $taskName = $null
    $response = $null
    try
    {
        $taskName = Start-UserTask -User $user -ScriptPath $uiScript -Arguments "-ConfigPath `"$configPath`"" -Id $id
        Write-Log "Window started (mode=$($Settings.Mode), type=$($Settings.Type))"

        if ($WaitSeconds -gt 0)
        {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt $WaitSeconds)
            {
                if (Test-Path $responsePath)
                {
                    Start-Sleep -Milliseconds 300
                    $response = (Get-Content -Path $responsePath -Raw).Trim()
                    break
                }
                Start-Sleep -Seconds 2
            }
        }
        else
        {
            Start-Sleep -Seconds $LingerSeconds
        }
    }
    catch
    {
        Write-Log "ERROR starting window: $($_.Exception.Message)"
    }
    finally
    {
        if ($taskName) { Stop-UserTask $taskName $id }
        Remove-Item -Path $configPath -Force -ErrorAction SilentlyContinue
        if ($responsePath) { Remove-Item -Path $responsePath -Force -ErrorAction SilentlyContinue }
    }

    return $response
}
