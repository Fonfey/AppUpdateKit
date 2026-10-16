<#
.SYNOPSIS
    {{T:Intune requirement-script voor de update van|Intune requirement script for the update of}} {{APPNAME}}.
    {{T:Upload dit LOS in Intune (Requirements > Script), het hoort niet in het pakket.|Upload this SEPARATELY in Intune (Requirements > Script); it does not belong in the package.}}

.DESCRIPTION
    {{T:Tijdens Autopilot (OOBE of inrichtingspagina) is het altijd voldaan als InstallDuringSetup aan staat,|During Autopilot (OOBE or Enrollment Status Page) it is always met when InstallDuringSetup is on,}}
    {{T:ook op nieuwe laptops waar de app nog niet op staat. Staat het uit, dan wacht de app tot na de inrichting.|also on new laptops without the app. When it is off, the app waits until setup is finished.}}

    {{T:Verder voldaan als:|Otherwise met when:}}
      - {{T:de app niet open staat, EN|the app is not running, AND}}
      - {{T:de gebruiker de update niet recent heeft uitgesteld, EN|the user has not recently postponed the update, AND}}
      - {{T:het nu binnen het tijdvenster valt (InstallWindow in app.psd1), EN|it is now inside the time window (InstallWindow in app.psd1), AND}}
      - {{T:er iemand is ingelogd, als NoUserAction = 'Wachten', EN|someone is signed in, when NoUserAction = 'Wachten', AND}}
      - {{T:(als OnlyUpdateExisting = $true in app.psd1) de app al op het apparaat staat|(when OnlyUpdateExisting = $true in app.psd1) the app is already on the device}}

    {{T:Intune-instellingen|Intune settings}}:
      Run script as 32-bit process on 64-bit clients : No
      Run this script using the logged on credentials : No
      Enforce script signature check                  : No
      Output data type : String
      Operator         : Equals
      Value            : Voldaan
    {{T:De waarde is altijd "Voldaan", ook als de kit in het Engels staat.|The value is always "Voldaan" (Dutch for "met"), also when the kit is set to English.}}
#>

$AppId           = '{{APPID}}'
$Processes       = @({{PROCESSES}})
$DisplayName     = '{{DETECT_NAME}}'        # {{T:naam in "Apps en onderdelen"|name in "Apps & features"}}
$OnlyIfInstalled = '{{ONLY_IF_INSTALLED}}' -eq 'true'   # {{T:true = alleen bijwerken waar de app al staat|true = only update where the app is installed}}

$InstallWindow   = '{{INSTALL_WINDOW}}'     # Altijd | Werktijd | BuitenWerktijd  ({{T:altijd / binnen werktijd / buiten werktijd|always / working hours / outside working hours}})
$WorkHours       = '{{WORK_HOURS}}'
$WorkDays        = '{{WORK_DAYS}}'
$NoUserAction    = '{{NO_USER_ACTION}}'     # Installeren | Wachten  ({{T:installeren / wachten|install / wait}})
$CheckProcesses  = '{{CHECK_PROCESSES}}' -eq 'true'   # {{T:false = variant voor /noprocesscheck|false = variant for /noprocesscheck}}
$DuringSetup     = '{{INSTALL_DURING_SETUP}}' -eq 'true'   # {{T:true = installeren tijdens Autopilot|true = install during Autopilot}}

function Test-InTimeWindow([string]$Window, [string]$Hours, [string]$Days, [datetime]$Now = (Get-Date)) {
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

    # The setup page (ESP) runs in wwahost.exe, in the user's session
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

try {
    $phase = Get-SetupPhase
    if ($phase) {
        if ($DuringSetup) { Write-Host "Voldaan"; exit 0 }
        Write-Host "{{T:Inrichting bezig|Setup in progress}} ($phase)"
        exit 1
    }

    if ($OnlyIfInstalled) {
        $paths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $installed = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "$DisplayName*" }
        if (-not $installed) {
            Write-Host "{{T:Niet geinstalleerd|Not installed}}"
            exit 1
        }
    }

    # Nobody signed in: nobody to disturb, so the time window does not apply
    $userLoggedOn = [bool](@(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue) |
        Where-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User -ne 'defaultuser0' })
    if (-not $userLoggedOn -and $NoUserAction -eq 'Wachten') {
        Write-Host "{{T:Geen gebruiker ingelogd|No user signed in}}"
        exit 1
    }
    if ($userLoggedOn -and -not (Test-InTimeWindow $InstallWindow $WorkHours $WorkDays)) {
        Write-Host "{{T:Buiten tijdvenster|Outside time window}}"
        exit 1
    }

    if (Test-Path $statePath) {
        $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
        if ($state.PostponeUntil -and (Get-Date) -lt [datetime]$state.PostponeUntil) {
            Write-Host "{{T:Uitgesteld tot|Postponed until}} $($state.PostponeUntil)"
            exit 1
        }
    }

    foreach ($p in @($Processes | Where-Object { $CheckProcesses })) {
        if (Get-Process -Name ($p -replace '\.exe$', '') -ErrorAction SilentlyContinue) {
            Write-Host "{{T:App staat open|App is running}} ($p)"
            exit 1
        }
    }

    Write-Host "Voldaan"
    exit 0
}
catch {
    Write-Host "{{T:Fout tijdens controle|Error during check}}: $($_.Exception.Message)"
    exit 1
}
