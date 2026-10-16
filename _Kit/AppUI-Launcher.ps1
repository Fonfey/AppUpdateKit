<#
.SYNOPSIS
    Shared helper functions for the update package. Do NOT edit per app.
    All app-specific data comes from app.psd1 next to this script (or app.json from Install.ps1).

.DESCRIPTION
    - Loads the app settings (AppId, AppName, Processes, Icon, texts, ...).
    - Working folder per app: C:\ProgramData\AppUpdates\<AppId> (postpone counter, log, popup files).
    - Starts AppUI.ps1 as the logged-on user through a scheduled task + VBS launcher
      (no visible console window) and optionally waits for the answer.
    - Languages:
        popups : language of the logged-on user's Windows (PopupLanguage = Auto | nl | en)
        logs   : language chosen in the Builder (KitLanguage = nl | en)
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

# Standard texts for all apps (optional file next to this script); English texts are in the 'En' section
$script:DefaultTexts = @{}
$stdPath = Join-Path $PSScriptRoot 'Standaardteksten.psd1'
if (Test-Path $stdPath) { try { $script:DefaultTexts = Import-PowerShellDataFile -Path $stdPath } catch { } }
$script:DefaultTextsEn = if ($script:DefaultTexts['En'] -is [hashtable]) { $script:DefaultTexts['En'] } else { @{} }

$script:AppFolder = Join-Path 'C:\ProgramData\AppUpdates' $script:App.AppId
$script:UIFolder  = Join-Path $script:AppFolder 'UI'
$script:StatePath = Join-Path $script:AppFolder 'PostponeState.json'
$script:LogPath   = Join-Path $script:AppFolder 'update.log'

if (-not (Test-Path $script:UIFolder)) { New-Item -Path $script:UIFolder -ItemType Directory -Force | Out-Null }

# Language of the log files and admin messages (chosen in the Builder)
$script:KitLang = if ("$($script:App.KitLanguage)" -eq 'en') { 'en' } else { 'nl' }

function L([string]$Nl, [string]$En)
{
    # Text in the kit language (logs)
    if ($script:KitLang -eq 'en') { return $En } else { return $Nl }
}

function Write-Log
{
    param ([string]$Text, [string]$Tag = 'ui')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$Tag] $Text"
    Add-Content -Path $script:LogPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $line
}

function Get-AppSetting
{
    # Value from the app settings, or the default when it is missing
    param ([string]$Name, $Default)
    $v = $script:App.$Name
    if ($null -eq $v -or "$v" -eq '') { return $Default }
    return $v
}

# New installation (app was not on the device yet) or update? Set by install.cmd / Install.ps1.
$script:IsNewInstall = $env:APPKIT_NEWINSTALL -eq '1'

# Built-in Dutch texts for a new installation (the update texts are passed by the callers)
$script:NewInstallDefaults = @{
    NewConsentSubHeading    = 'Er staat een nieuwe app voor je klaar'
    NewConsentMessage       = '{AppName} wordt op je laptop geïnstalleerd. Dat duurt een paar minuten.'
    NewForcedSubHeading     = 'De installatie start over {Minuten} minuten'
    NewForcedMessage        = 'Je hebt de installatie van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt {AppName} automatisch geïnstalleerd. Sla je werk op.'
    NewForcedInfo           = 'Wil je niet wachten? Sla je werk op en klik op Nu installeren.'
    NewInstallingHeading    = '{AppName} wordt geïnstalleerd'
    NewInstallingMessage    = '{AppName} wordt op je laptop geïnstalleerd. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    NewSuccessHeading       = '{AppName} is geïnstalleerd'
    NewSuccessMessage       = '{AppName} staat klaar. Je vindt de app in het startmenu.'
    NewErrorHeading         = 'Installatie niet gelukt'
    NewErrorMessage         = 'Er ging iets mis bij het installeren van {AppName}. Heb je de app nodig? Neem dan contact op met de servicedesk.'
    NewRestartMessage       = '{AppName} is geïnstalleerd. Herstart je laptop om de installatie af te ronden. Sla eerst je werk op.'
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programma''s af.'
}

# Built-in English texts (used when the user's Windows is English)
$script:EnglishDefaults = @{
    ConsentSubHeading       = 'An update is available'
    ConsentMessage          = 'A new version of {AppName} is ready for you. During the update (a few minutes) you cannot use {AppName}.'
    ForcedSubHeading        = 'The update starts in {Minutes} minutes'
    ForcedMessage           = 'You have postponed the update of {AppName} {MaxPostpones} times. In {Minutes} minutes the new version will be installed automatically. Save your work and close {AppName}.'
    ForcedInfo              = 'Do not want to wait? Save your work, close {AppName} and click Install now.'
    InstallingHeading       = 'Installing update'
    InstallingMessage       = '{AppName} is being updated and is briefly unavailable. You do not need to do anything; we will let you know when it is done.'
    SuccessHeading          = 'Update installed'
    SuccessMessage          = 'The new version of {AppName} is ready. You can use the app again.'
    ErrorHeading            = 'Update failed'
    ErrorMessage            = 'Something went wrong while updating {AppName}. Is the app not working? Please contact the service desk.'
    RestartSubHeading       = 'Restart required'
    RestartMessage          = '{AppName} has been updated. Restart your laptop to finish the update. Save your work first.'
    RestartForcedSubHeading = 'Your laptop will restart in {Minutes} minutes'
    RestartForcedMessage    = '{AppName} has been updated and your laptop needs to restart to finish the update. Save your work and close your programs.'
    UninstallingHeading     = 'Removing {AppName}'
    UninstallingMessage     = '{AppName} is being removed from your laptop and is briefly unavailable. You do not need to do anything.'
    UninstalledHeading      = '{AppName} has been removed'
    UninstalledMessage      = '{AppName} is no longer on your laptop.'
    UninstallErrorHeading   = 'Removal failed'
    UninstallErrorMessage   = 'Something went wrong while removing {AppName}. Does this cause problems? Please contact the service desk.'
    NewConsentSubHeading    = 'A new app is ready for you'
    NewConsentMessage       = '{AppName} will be installed on your laptop. This takes a few minutes.'
    NewForcedSubHeading     = 'The installation starts in {Minutes} minutes'
    NewForcedMessage        = 'You have postponed the installation of {AppName} {MaxPostpones} times. In {Minutes} minutes {AppName} will be installed automatically. Save your work.'
    NewForcedInfo           = 'Do not want to wait? Save your work and click Install now.'
    NewInstallingHeading    = 'Installing {AppName}'
    NewInstallingMessage    = '{AppName} is being installed on your laptop. You do not need to do anything; we will let you know when it is done.'
    NewSuccessHeading       = '{AppName} has been installed'
    NewSuccessMessage       = '{AppName} is ready. You can find the app in the Start menu.'
    NewErrorHeading         = 'Installation failed'
    NewErrorMessage         = 'Something went wrong while installing {AppName}. Do you need the app? Please contact the service desk.'
    NewRestartMessage       = '{AppName} has been installed. Restart your laptop to finish the installation. Save your work first.'
    NewRestartForcedMessage = '{AppName} has been installed and your laptop needs to restart to finish the installation. Save your work and close your programs.'
}

function Get-UserLanguage
{
    # UI language of the user: PreferredUILanguages in the user's hive, otherwise the Windows language
    param ($User)
    $lang = $null
    if ($User -and $User.Sid)
    {
        $base = "Registry::HKEY_USERS\$($User.Sid)\Control Panel"
        try
        {
            $pref = (Get-ItemProperty -Path "$base\Desktop" -Name PreferredUILanguages -ErrorAction SilentlyContinue).PreferredUILanguages
            if ($pref) { $lang = @($pref)[0] }
            if (-not $lang) { $lang = (Get-ItemProperty -Path "$base\Desktop\MuiCached" -Name MachinePreferredUILanguages -ErrorAction SilentlyContinue).MachinePreferredUILanguages | Select-Object -First 1 }
        }
        catch { }
    }
    if (-not $lang) { $lang = [System.Globalization.CultureInfo]::InstalledUICulture.Name }
    return "$lang"
}

$script:PopupLang = $null
function Get-PopupLanguage
{
    # 'en' for English Windows, otherwise 'nl'. PopupLanguage in the app settings can force a language.
    if ($script:PopupLang) { return $script:PopupLang }
    $setting = "$(Get-AppSetting 'PopupLanguage' 'Auto')"
    if ($setting -in 'nl', 'en') { $script:PopupLang = $setting; return $script:PopupLang }
    if ($env:APPKIT_POPUPLANG -in 'nl', 'en') { $script:PopupLang = $env:APPKIT_POPUPLANG; return $script:PopupLang }

    $user = $null
    try { $user = Get-InteractiveUser } catch { }
    $culture = Get-UserLanguage $user
    $script:PopupLang = if ($culture -like 'en*') { 'en' } else { 'nl' }
    return $script:PopupLang
}

function T([string]$Nl, [string]$En)
{
    # Text in the popup language of the logged-on user
    if ((Get-PopupLanguage) -eq 'en') { return $En } else { return $Nl }
}

function Test-AppInstalled
{
    # Is the app already listed in "Apps & features"? (DetectName, same check as Requirement.ps1)
    $name = $script:App.DetectName
    if (-not $name) { return $true }
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    return [bool](Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "$name*" })
}

function Get-AppText
{
    <#
        Popup text in the user's language.
          Dutch  : own text (Texts) -> Standaardteksten.psd1 -> -Default
          English: own text (TextsEn) -> Standaardteksten.psd1 (En) -> built-in English text
        For a new installation the 'New...' variant of the key is tried first.
        Tokens: {AppName}, {Versie}/{Version}, {Minuten}/{Minutes}, {MaxUitstel}/{MaxPostpones}
    #>
    param ([string]$Key, [string]$Default)
    $en = (Get-PopupLanguage) -eq 'en'
    $own = if ($en) { $script:App.TextsEn } else { $script:App.Texts }
    $std = if ($en) { $script:DefaultTextsEn } else { $script:DefaultTexts }
    $builtin = if ($en) { $script:EnglishDefaults } else { $script:NewInstallDefaults }

    $keys = @($Key)
    if ($script:IsNewInstall) { $keys = @("New$Key", $Key) }

    $t = $null
    foreach ($k in $keys)
    {
        if ($own -is [hashtable] -and $own[$k]) { $t = $own[$k] }
        elseif ($std[$k]) { $t = $std[$k] }
        elseif ($builtin[$k]) { $t = $builtin[$k] }
        if ($t) { break }
    }
    if (-not $t) { $t = if ($en -and $script:EnglishDefaults[$Key]) { $script:EnglishDefaults[$Key] } else { $Default } }

    $minutes = [string](Get-AppSetting 'ForcedDelayMinutes' 5)
    $max     = [string](Get-AppSetting 'MaxPostpones' 5)
    return $t.Replace('{AppName}', $script:App.AppName).
              Replace('{Versie}', [string]$script:App.Version).Replace('{Version}', [string]$script:App.Version).
              Replace('{Minuten}', $minutes).Replace('{Minutes}', $minutes).
              Replace('{MaxUitstel}', $max).Replace('{MaxPostpones}', $max)
}

function Get-SetupPhase
{
    <#
        Returns 'OOBE' or 'ESP' while the device is still being set up (Autopilot), otherwise $null.
          OOBE : Windows setup not finished yet (also the technician phase of pre-provisioning)
          ESP  : the Enrollment Status Page is still running for the user who just signed in
        Same checks as PSAppDeployToolkit 4 (Test-ADTOobeCompleted / Test-ADTEspActive).
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
    # defaultuser0 is the temporary Autopilot/OOBE account: it does not count as a user
    $explorer = $null; $owner = $null
    foreach ($e in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop))
    {
        $o = Invoke-CimMethod -InputObject $e -MethodName GetOwner
        if ($o.User -and $o.User -ne 'defaultuser0') { $explorer = $e; $owner = $o; break }
    }
    if (-not $explorer) { return $null }
    $sid = (Invoke-CimMethod -InputObject $explorer -MethodName GetOwnerSid).Sid

    $profilePath = $null
    if ($sid)
    {
        $profilePath = (Get-CimInstance -ClassName Win32_UserProfile -Filter "SID = '$sid'" -ErrorAction SilentlyContinue).LocalPath
    }
    if (-not $profilePath) { $profilePath = Join-Path "$env:SystemDrive\Users" $owner.User }

    return [pscustomobject]@{
        Name        = "$($owner.Domain)\$($owner.User)"
        Sid         = $sid
        ProfilePath = $profilePath
        SessionId   = $explorer.SessionId
    }
}

function Test-InTimeWindow
{
    <#
        Is this moment inside the app's time window?
        -Window : 'Altijd' (always) | 'Werktijd' (working hours) | 'BuitenWerktijd' (outside working hours)
        -Hours  : '08:00-17:00'  (across midnight is allowed: '22:00-06:00')
        -Days   : 'ma,di,wo,do,vr' (Dutch) or 'mo,tu,we,th,fr' (English)
    #>
    param ([string]$Window, [string]$Hours, [string]$Days, [datetime]$Now = (Get-Date))
    if (-not $Window -or $Window -eq 'Altijd') { return $true }

    $map = @{ 'ma' = 'Monday'; 'di' = 'Tuesday'; 'wo' = 'Wednesday'; 'do' = 'Thursday'; 'vr' = 'Friday'; 'za' = 'Saturday'; 'zo' = 'Sunday'
              'mo' = 'Monday'; 'tu' = 'Tuesday'; 'we' = 'Wednesday'; 'th' = 'Thursday'; 'fr' = 'Friday'; 'sa' = 'Saturday'; 'su' = 'Sunday' }
    $dayList = @(($Days -split '[,; ]+') | Where-Object { $_.Length -ge 2 } | ForEach-Object { $map[$_.Trim().ToLower().Substring(0, 2)] })

    $from = [timespan]'08:00'; $to = [timespan]'17:00'
    if ($Hours -match '^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$') { $from = [timespan]$Matches[1]; $to = [timespan]$Matches[2] }

    $t = $Now.TimeOfDay
    $inHours = if ($from -le $to) { $t -ge $from -and $t -lt $to } else { $t -ge $from -or $t -lt $to }
    $isWorkTime = ($dayList -contains $Now.DayOfWeek.ToString()) -and $inHours

    if ($Window -eq 'Werktijd') { return $isWorkTime }
    return -not $isWorkTime
}

function Start-UserTask
{
    # Starts a hidden PowerShell script in the logged-on user's session.
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
          IdleMinutes : minutes since the last mouse or keyboard input ($null = unknown)
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
    catch { Write-Log (L "Kon inactiviteit niet bepalen: $($_.Exception.Message)" "Could not determine idle time: $($_.Exception.Message)") 'consent' }
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
        -Settings      : hashtable with Mode, Type, Heading, Message, ... (see AppUI.ps1)
        -WaitSeconds   : > 0 = wait for an answer (consent); returns 'Yes'/'No'/'Timeout'/$null
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
        Write-Log (L "Apparaat wordt ingericht ($phase), venster wordt overgeslagen." "Device is being set up ($phase), popup skipped.")
        return $null
    }

    try { $user = Get-InteractiveUser }
    catch { Write-Log (L "FOUT bij bepalen ingelogde gebruiker: $($_.Exception.Message)" "ERROR determining the logged-on user: $($_.Exception.Message)"); return $null }

    if (-not $user)
    {
        Write-Log (L 'Geen ingelogde gebruiker gevonden, venster wordt overgeslagen.' 'No logged-on user found, popup skipped.')
        return $null
    }
    Write-Log (L "Ingelogde gebruiker: $($user.Name) (taal popups: $(Get-PopupLanguage))" "Logged-on user: $($user.Name) (popup language: $(Get-PopupLanguage))")

    $iconName = Get-AppSetting 'Icon' 'app.ico'
    Copy-Item -Path (Join-Path $PSScriptRoot 'AppUI.ps1'), (Join-Path $PSScriptRoot $iconName) `
              -Destination $script:UIFolder -Force -ErrorAction SilentlyContinue

    $id = Get-Random
    $Settings.IconPath    = Join-Path $script:UIFolder $iconName
    $Settings.LogPath     = $script:LogPath
    $Settings.AccentColor = Get-AppSetting 'AccentColor' '#185FA5'
    $Settings.Lang        = Get-PopupLanguage

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
        Write-Log (L "Venster gestart (mode=$($Settings.Mode), type=$($Settings.Type))" "Popup started (mode=$($Settings.Mode), type=$($Settings.Type))")

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
        Write-Log (L "FOUT bij starten venster: $($_.Exception.Message)" "ERROR starting popup: $($_.Exception.Message)")
    }
    finally
    {
        if ($taskName) { Stop-UserTask $taskName $id }
        Remove-Item -Path $configPath -Force -ErrorAction SilentlyContinue
        if ($responsePath) { Remove-Item -Path $responsePath -Force -ErrorAction SilentlyContinue }
    }

    return $response
}
