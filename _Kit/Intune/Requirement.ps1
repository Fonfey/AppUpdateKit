<#
.SYNOPSIS
    Intune requirement-script voor de update van {{APPNAME}}.
    Upload dit LOS in Intune (Requirements > Script), het hoort niet in het pakket.

.DESCRIPTION
    Tijdens Autopilot (OOBE of inrichtingspagina) is het altijd voldaan als InstallDuringSetup aan staat,
    ook op nieuwe laptops waar de app nog niet op staat. Staat het uit, dan wacht de app tot na de inrichting.

    Verder voldaan als:
      - de app niet open staat, EN
      - de gebruiker de update niet recent heeft uitgesteld, EN
      - het nu binnen het tijdvenster valt (InstallWindow in app.psd1), EN
      - er iemand is ingelogd, als NoUserAction = 'Wachten', EN
      - (als OnlyUpdateExisting = $true in app.psd1) de app al op het apparaat staat

    Intune-instellingen:
      Run script as 32-bit process on 64-bit clients : No
      Run this script using the logged on credentials : No
      Enforce script signature check                  : No
      Output data type : String
      Operator         : Equals
      Value            : Voldaan
#>

$AppId           = '{{APPID}}'
$Processes       = @({{PROCESSES}})
$DisplayName     = '{{DETECT_NAME}}'        # naam in "Apps en onderdelen"
$OnlyIfInstalled = '{{ONLY_IF_INSTALLED}}' -eq 'true'   # true = alleen bijwerken waar de app al staat

$InstallWindow   = '{{INSTALL_WINDOW}}'     # Altijd | Werktijd | BuitenWerktijd
$WorkHours       = '{{WORK_HOURS}}'
$WorkDays        = '{{WORK_DAYS}}'
$NoUserAction    = '{{NO_USER_ACTION}}'     # Installeren | Wachten
$CheckProcesses  = '{{CHECK_PROCESSES}}' -eq 'true'   # false = variant voor install.cmd /noprocesscheck
$DuringSetup     = '{{INSTALL_DURING_SETUP}}' -eq 'true'   # true = installeren tijdens Autopilot

function Test-InTimeWindow([string]$Window, [string]$Hours, [string]$Days, [datetime]$Now = (Get-Date)) {
    if (-not $Window -or $Window -eq 'Altijd') { return $true }
    $map = @{ 'ma' = 'Monday'; 'di' = 'Tuesday'; 'wo' = 'Wednesday'; 'do' = 'Thursday'; 'vr' = 'Friday'; 'za' = 'Saturday'; 'zo' = 'Sunday' }
    $dayList = @(($Days -split '[,; ]+') | Where-Object { $_.Length -ge 2 } | ForEach-Object { $map[$_.Trim().ToLower().Substring(0, 2)] })
    # Eén of meer blokken: '08:00-17:00' of '09:00-10:00,13:00-14:00'
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
    if ($Window -eq 'Werktijd') { return $isWorkTime }
    return -not $isWorkTime
}

function Get-SetupPhase
{
    # 'OOBE' of 'ESP' tijdens Autopilot, anders $null (zelfde controles als PSADT 4)
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

$statePath = "C:\ProgramData\AppUpdates\$AppId\PostponeState.json"

try {
    $phase = Get-SetupPhase
    if ($phase) {
        if ($DuringSetup) { Write-Host "Voldaan"; exit 0 }
        Write-Host "Inrichting bezig ($phase)"
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
            Write-Host "Niet geinstalleerd"
            exit 1
        }
    }

    # Niemand ingelogd: niemand die gestoord wordt, dus het tijdvenster telt dan niet
    $userLoggedOn = [bool](@(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue) |
        Where-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User -ne 'defaultuser0' })
    if (-not $userLoggedOn -and $NoUserAction -eq 'Wachten') {
        Write-Host "Geen gebruiker ingelogd"
        exit 1
    }
    if ($userLoggedOn -and -not (Test-InTimeWindow $InstallWindow $WorkHours $WorkDays)) {
        Write-Host "Buiten tijdvenster"
        exit 1
    }

    if (Test-Path $statePath) {
        $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
        if ($state.PostponeUntil -and (Get-Date) -lt [datetime]$state.PostponeUntil) {
            Write-Host "Uitgesteld tot $($state.PostponeUntil)"
            exit 1
        }
    }

    foreach ($p in @($Processes | Where-Object { $CheckProcesses })) {
        if (Get-Process -Name ($p -replace '\.exe$', '') -ErrorAction SilentlyContinue) {
            Write-Host "App staat open ($p)"
            exit 1
        }
    }

    Write-Host "Voldaan"
    exit 0
}
catch {
    Write-Host "Fout tijdens controle: $($_.Exception.Message)"
    exit 1
}
