<#
.SYNOPSIS
    Gedeelde hulpfuncties voor het update-pakket. NIET aanpassen per app.
    Alle app-specifieke gegevens komen uit app.psd1 in dezelfde map.

.DESCRIPTION
    - Leest app.psd1 (AppId, AppName, Processes, Icon, teksten, ...).
    - Bepaalt de werkmap: C:\ProgramData\AppUpdates\<AppId>
      (uitsteltellers, log en de vensterbestanden per app gescheiden).
    - Start AppUI.ps1 als de ingelogde gebruiker via een scheduled task + VBS-launcher
      (geen zichtbaar consolevenster) en wacht optioneel op het antwoord.
#>

function ConvertTo-AppHashtable($Object)
{
    # JSON (PSCustomObject) terug naar hashtables, zodat $App.Texts['...'] blijft werken
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

# Instellingen: van de PowerShell-installer in Intune (APPKIT_CONFIG), anders app.psd1 uit het pakket
$script:App = $null
if ($env:APPKIT_CONFIG -and (Test-Path -LiteralPath $env:APPKIT_CONFIG))
{
    try { $script:App = ConvertTo-AppHashtable ([System.IO.File]::ReadAllText($env:APPKIT_CONFIG) | ConvertFrom-Json) } catch { $script:App = $null }
}
if (-not $script:App) { $script:App = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'app.psd1') }

# Standaardteksten voor alle apps (optioneel bestand naast dit script)
$script:DefaultTexts = @{}
$stdPath = Join-Path $PSScriptRoot 'Standaardteksten.psd1'
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
    # Waarde uit app.psd1, of de standaardwaarde als hij ontbreekt
    param ([string]$Name, $Default)
    $v = $script:App.$Name
    if ($null -eq $v -or "$v" -eq '') { return $Default }
    return $v
}

# Nieuwe installatie (app stond nog niet op de laptop) of update? Bepaald door install.cmd / Install.ps1.
$script:IsNewInstall = $env:APPKIT_NEWINSTALL -eq '1'
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
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programmas af.'
}

function Test-AppInstalled
{
    # Staat de app al in "Apps en onderdelen"? (DetectName, zelfde controle als Requirement.ps1)
    $name = $script:App.DetectName
    if (-not $name) { return $true }
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    return [bool](Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "$name*" })
}

function Get-AppText
{
    # Volgorde: eigen tekst in app.psd1 -> Standaardteksten.psd1 -> ingebouwde tekst.
    # Ingevuld worden: {AppName}, {Versie}, {Minuten} (waarschuwing vooraf) en {MaxUitstel}
    param ([string]$Key, [string]$Default)
    $t = $null
    if ($script:IsNewInstall)
    {
        # Eerst de tekst voor een nieuwe installatie: eigen tekst -> Standaardteksten -> ingebouwd
        $nk = "New$Key"
        if ($script:App.Texts) { $t = $script:App.Texts[$nk] }
        if (-not $t) { $t = $script:DefaultTexts[$nk] }
        if (-not $t) { $t = $script:NewInstallDefaults[$nk] }
    }
    if (-not $t -and $script:App.Texts) { $t = $script:App.Texts[$Key] }
    if (-not $t) { $t = $script:DefaultTexts[$Key] }
    if (-not $t) { $t = $Default }
    return $t.Replace('{AppName}', $script:App.AppName).
              Replace('{Versie}', [string]$script:App.Version).
              Replace('{Minuten}', [string](Get-AppSetting 'ForcedDelayMinutes' 5)).
              Replace('{MaxUitstel}', [string](Get-AppSetting 'MaxPostpones' 5))
}

function Get-SetupPhase
{
    <#
        Geeft 'OOBE' of 'ESP' terug als het apparaat nog wordt ingericht (Autopilot), anders $null.
          OOBE : Windows-installatie nog niet afgerond (ook de technician-fase van pre-provisioning)
          ESP  : de inrichtingspagina loopt nog voor de gebruiker die net inlogt
        Dezelfde controles als PSAppDeployToolkit 4 (Test-ADTOobeCompleted / Test-ADTEspActive).
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

    # De inrichtingspagina draait in wwahost.exe, in de sessie van de gebruiker
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
    # defaultuser0 is het tijdelijke account van Autopilot/OOBE: dat telt niet als gebruiker
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
        Valt dit moment binnen het tijdvenster van de app?
        -Window : 'Altijd' | 'Werktijd' | 'BuitenWerktijd'
        -Hours  : één of meer blokken, bijv. '08:00-17:00' of '09:00-10:00,13:00-14:00'
                  (over middernacht mag ook: '22:00-06:00')
        -Days   : 'ma,di,wo,do,vr'
    #>
    param ([string]$Window, [string]$Hours, [string]$Days, [datetime]$Now = (Get-Date))
    if (-not $Window -or $Window -eq 'Altijd') { return $true }

    $map = @{ 'ma' = 'Monday'; 'di' = 'Tuesday'; 'wo' = 'Wednesday'; 'do' = 'Thursday'; 'vr' = 'Friday'; 'za' = 'Saturday'; 'zo' = 'Sunday' }
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

    if ($Window -eq 'Werktijd') { return $isWorkTime }
    return -not $isWorkTime
}

function Start-UserTask
{
    # Start een verborgen PowerShell-script in de sessie van de ingelogde gebruiker.
    # Geeft de taaknaam terug; de aanroeper ruimt op met Stop-UserTask.
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
        Is de gebruiker aan het werk? Geeft terug:
          Locked      : scherm vergrendeld (LogonUI.exe draait in de sessie van de gebruiker)
          IdleMinutes : minuten sinds de laatste muis- of toetsenbordactie ($null = onbekend)
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
    catch { Write-Log "Kon inactiviteit niet bepalen: $($_.Exception.Message)" 'consent' }
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
        -Settings      : hashtable met o.a. Mode, Type, Heading, Message (zie AppUI.ps1)
        -WaitSeconds   : > 0 = wachten op antwoord (consent); geeft 'Yes'/'No'/'Timeout'/$null terug
        -LingerSeconds : bij niet wachten: zo lang wachten voor het opruimen van de tijdelijke bestanden
    #>
    param (
        [Parameter(Mandatory = $true)][hashtable]$Settings,
        [int]$WaitSeconds = 0,
        [int]$LingerSeconds = 15
    )

    $phase = Get-SetupPhase
    if ($phase)
    {
        Write-Log "Apparaat wordt ingericht ($phase), venster wordt overgeslagen."
        return $null
    }

    try { $user = Get-InteractiveUser }
    catch { Write-Log "FOUT bij bepalen ingelogde gebruiker: $($_.Exception.Message)"; return $null }

    if (-not $user)
    {
        Write-Log 'Geen ingelogde gebruiker gevonden, venster wordt overgeslagen.'
        return $null
    }
    Write-Log "Ingelogde gebruiker: $($user.Name)"

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
        Write-Log "Venster gestart (mode=$($Settings.Mode), type=$($Settings.Type))"

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
        Write-Log "FOUT bij starten venster: $($_.Exception.Message)"
    }
    finally
    {
        if ($taskName) { Stop-UserTask $taskName $id }
        Remove-Item -Path $configPath -Force -ErrorAction SilentlyContinue
        if ($responsePath) { Remove-Item -Path $responsePath -Force -ErrorAction SilentlyContinue }
    }

    return $response
}
