<#
.SYNOPSIS
    Vraagt de ingelogde gebruiker of de update nu uitgevoerd mag worden. NIET aanpassen per app;
    instellingen en teksten komen uit app.psd1.

.DESCRIPTION
    - Keer 1 t/m MaxPostpones: venster met "Later" / "Nu bijwerken".
    - Daarna: waarschuwing "De update start over X minuten" zonder Later-knop;
      na de aftelklok (of eerder met "Nu installeren") gaat de installatie door.
    - Autopilot (OOBE of inrichtingspagina): direct installeren, zonder vensters.
    - Geen ingelogde gebruiker: direct installeren, of wachten als NoUserAction = 'Wachten'.
    - Buiten het tijdvenster (InstallWindow): niets doen, later opnieuw.
    - Gebruiker inactief (IdleMinutes) of scherm vergrendeld: direct installeren, zonder popup.

    De uitstelstatus staat in C:\ProgramData\AppUpdates\<AppId>\PostponeState.json.
    Requirement.ps1 leest dat bestand en houdt de installatie tegen zolang er is uitgesteld.
    install.cmd verwijdert het bestand pas als de installatie echt gelukt is.

.NOTES
    Exit code 0 = installatie mag doorgaan
    Exit code 1 = installatie wordt (voor nu) overgeslagen ("Later" of geen reactie)
#>

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$maxPostpones       = [int](Get-AppSetting 'MaxPostpones' 5)
$postponeHours      = [int](Get-AppSetting 'PostponeHours' 24)
# Wachttijd zonder keuze in minuten (oudere app.psd1-bestanden met seconden blijven werken)
$waitTimeoutSeconds = if ($null -ne $script:App.ConsentTimeoutMinutes) { [int]$script:App.ConsentTimeoutMinutes * 60 }
                      else { [int](Get-AppSetting 'ConsentTimeoutSeconds' 900) }
$forcedMinutes      = [int](Get-AppSetting 'ForcedDelayMinutes' 5)

$postponeCount = 0
if (Test-Path $script:StatePath) {
    try {
        $postponeCount = [int]((Get-Content -Path $script:StatePath -Raw | ConvertFrom-Json).PostponeCount)
    }
    catch {
        Write-Log "Kon PostponeState.json niet lezen, begin met schone staat: $($_.Exception.Message)" 'consent'
    }
}

Write-Log "Gestart voor $($script:App.AppName). PostponeCount=$postponeCount (max=$maxPostpones)" 'consent'

function Save-State {
    param([int]$Count, [Nullable[datetime]]$PostponeUntil)
    [PSCustomObject]@{
        PostponeCount = $Count
        PostponeUntil = if ($PostponeUntil) { $PostponeUntil.ToString("o") } else { $null }
    } | ConvertTo-Json | Set-Content -Path $script:StatePath -Encoding UTF8 -Force
}

# ---- Nieuw apparaat via Autopilot: direct installeren, niemand om te vragen ----
$phase = Get-SetupPhase
if ($phase) {
    if ((Get-AppSetting 'InstallDuringSetup' $true) -eq $false) {
        Write-Log "Apparaat wordt ingericht ($phase); InstallDuringSetup staat uit, installatie komt na de inrichting." 'consent'
        exit 1
    }
    Write-Log "Apparaat wordt ingericht ($phase), installatie gaat door zonder te vragen." 'consent'
    exit 0
}

try { $user = Get-InteractiveUser }
catch {
    Write-Log "FOUT bij bepalen ingelogde gebruiker: $($_.Exception.Message)" 'consent'
    exit 0
}
if (-not $user) {
    if ((Get-AppSetting 'NoUserAction' 'Installeren') -eq 'Wachten') {
        Write-Log "Geen ingelogde gebruiker gevonden, installatie wacht tot er iemand is ingelogd." 'consent'
        exit 1
    }
    Write-Log "Geen ingelogde gebruiker gevonden, installatie gaat door zonder te vragen." 'consent'
    exit 0
}

# ---- Tijdvenster: alleen binnen of juist buiten werktijd ----
$window = Get-AppSetting 'InstallWindow' 'Altijd'
if (-not (Test-InTimeWindow $window (Get-AppSetting 'WorkHours' '08:00-17:00') (Get-AppSetting 'WorkDays' 'ma,di,wo,do,vr'))) {
    Write-Log "Buiten het tijdvenster ($window), installatie wordt voor nu overgeslagen (teller niet verhoogd)." 'consent'
    exit 1
}

# ---- Gebruiker niet aan het werk: direct installeren, zonder popup ----
$idleMinutes = [int](Get-AppSetting 'IdleMinutes' 0)
if ($idleMinutes -gt 0) {
    $activity = Get-UserActivity -User $user
    if ($activity.Locked) {
        Write-Log "Scherm van $($user.Name) is vergrendeld, installatie gaat door zonder te vragen." 'consent'
        exit 0
    }
    if ($null -ne $activity.IdleMinutes -and $activity.IdleMinutes -ge $idleMinutes) {
        Write-Log "$($user.Name) is $($activity.IdleMinutes) minuten inactief (grens $idleMinutes), installatie gaat door zonder te vragen." 'consent'
        exit 0
    }
    Write-Log "Gebruiker is actief (inactief: $(if ($null -ne $activity.IdleMinutes) { "$($activity.IdleMinutes) min" } else { 'onbekend' })), popup wordt getoond." 'consent'
}

# ---- Uitstellen kan niet meer: waarschuwing met aftelklok, daarna installeren ----
if ($postponeCount -ge $maxPostpones) {
    Write-Log "Maximaal aantal keer uitstellen bereikt: waarschuwing van $forcedMinutes minuten, daarna installatie." 'consent'

    if ($forcedMinutes -gt 0) {
        # +15 s: de launcher geeft het venster WaitSeconds - 15 als aftelklok
        $forcedResponse = Start-UserPopup -WaitSeconds ($forcedMinutes * 60 + 15) -Settings @{
            Mode          = 'forced'
            Heading       = $script:App.AppName
            SubHeading    = Get-AppText 'ForcedSubHeading' 'De update start over {Minuten} minuten'
            Message       = Get-AppText 'ForcedMessage' 'Je hebt de update van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt de nieuwe versie automatisch geïnstalleerd. Sla je werk op en sluit {AppName} af.'
            InfoText      = Get-AppText 'ForcedInfo' 'Wil je niet wachten? Sla je werk op, sluit {AppName} af en klik op Nu installeren.'
            ForcedMinutes = $forcedMinutes
            IsNew         = $script:IsNewInstall
        }
        Write-Log "Geforceerde installatie gaat door (reactie: '$forcedResponse')." 'consent'
    }
    exit 0
}

# ---- Normale vraag: Later / Nu bijwerken ----
$laterHint = if ($postponeHours -eq 24) { 'morgen' }
             elseif ($postponeHours % 24 -eq 0) { "over $($postponeHours / 24) dagen" }
             else { "over $postponeHours uur" }

$response = Start-UserPopup -WaitSeconds $waitTimeoutSeconds -Settings @{
    Mode          = 'consent'
    Heading       = $script:App.AppName
    SubHeading    = Get-AppText 'ConsentSubHeading' 'Er is een update beschikbaar'
    Message       = Get-AppText 'ConsentMessage' 'Er staat een nieuwe versie van {AppName} voor je klaar. Tijdens de update (een paar minuten) kun je {AppName} even niet gebruiken.'
    Remaining     = $maxPostpones - $postponeCount
    IsNew         = $script:IsNewInstall
    NowText       = if ($script:IsNewInstall) { 'Nu installeren' } else { 'Nu bijwerken' }
    LaterHint     = $laterHint
    ForcedMinutes = $forcedMinutes
}

Write-Log "Ontvangen reactie: '$response'" 'consent'

switch ($response) {
    "Yes" {
        Write-Log "Gebruiker koos Nu bijwerken, installatie gaat door." 'consent'
        exit 0
    }
    "No" {
        $newCount = $postponeCount + 1
        $postponeUntil = (Get-Date).AddHours($postponeHours)
        Write-Log "Gebruiker koos Later. PostponeCount wordt $newCount, uitgesteld tot $postponeUntil." 'consent'
        Save-State -Count $newCount -PostponeUntil $postponeUntil
        exit 1
    }
    default {
        Write-Log "Geen (geldige) reactie binnen de time-out, installatie wordt voor nu overgeslagen (teller niet verhoogd)." 'consent'
        exit 1
    }
}
