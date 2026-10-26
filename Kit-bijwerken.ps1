<#
.SYNOPSIS
    Werkt deze AppUpdateKit bij naar de nieuwste versie op GitHub (github.com/Fonfey/AppUpdateKit).

.DESCRIPTION
    Je eigen werk blijft staan:
      - Apps\ en Output\                     (je apps en gebouwde pakketten)
      - _Kit\Instellingen.psd1                (standaardmap voor installers, submap voor het pakket)
      - _Kit\Standaardteksten.psd1            (je eigen standaardteksten)
      - IntuneWinAppUtil.exe en andere eigen bestanden in de kit-map

    Je krijgt de nieuwste release (een vaste, geteste versie, bijv. 1.2.0), niet elke tussentijdse wijziging.
    Met -Ontwikkel krijg je de laatste stand van de branch main.

    Twee manieren, het script kiest zelf:
      - Is de kit met Git opgehaald (git clone) en staat Git op deze computer: git fetch en bijwerken naar de release.
      - Anders: de release downloaden als zip en de kit-bestanden vervangen.

    Starten: dubbelklik op Kit-bijwerken.cmd, of in de Builder op "Kit bijwerken...".

.PARAMETER Ontwikkel
    De laatste stand van main ophalen in plaats van de nieuwste release.

.PARAMETER HerstartBuilder
    Na het bijwerken de Builder opnieuw starten (gebruikt door de knop in de Builder).
#>
[CmdletBinding()]
param (
    [switch]$HerstartBuilder,
    [switch]$Ontwikkel,
    [string]$Repo   = 'Fonfey/AppUpdateKit',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$eigen   = @('_Kit\Instellingen.psd1', '_Kit\Standaardteksten.psd1')          # nooit overschrijven
$overslaan = '^(Apps|Output)(\\|$)|^\.git(\\|$)|^_Kit\\(Instellingen|Standaardteksten)\.psd1$'

function Write-Stap([string]$Tekst, [string]$Kleur = 'Gray') { Write-Host $Tekst -ForegroundColor $Kleur }

function Wait-Einde([int]$Code)
{
    if ($HerstartBuilder -and $Code -eq 0)
    {
        Write-Stap "`nDe Builder wordt opnieuw gestart..." 'Cyan'
        Start-Sleep -Seconds 2
        Start-Process -FilePath (Join-Path $KitRoot 'Start-Builder.cmd') -WorkingDirectory $KitRoot
    }
    else
    {
        Write-Host ''
        Read-Host 'Druk op Enter om dit venster te sluiten' | Out-Null
    }
    exit $Code
}

function Save-EigenBestanden
{
    # Eigen instellingen tijdelijk bewaren (ook als een oudere kit ze nog in Git had staan)
    $bewaar = @{}
    foreach ($rel in $eigen)
    {
        $p = Join-Path $KitRoot $rel
        if (Test-Path -LiteralPath $p) { $bewaar[$rel] = [System.IO.File]::ReadAllBytes($p) }
    }
    return $bewaar
}

function Restore-EigenBestanden($Bewaar)
{
    foreach ($rel in $Bewaar.Keys) { [System.IO.File]::WriteAllBytes((Join-Path $KitRoot $rel), $Bewaar[$rel]) }
    # Nog niet aanwezig (nieuwe kit)? Dan aanmaken uit de standaardversie
    foreach ($n in 'Instellingen', 'Standaardteksten')
    {
        $p = Join-Path $KitRoot "_Kit\$n.psd1"; $std = Join-Path $KitRoot "_Kit\$n.standaard.psd1"
        if (-not (Test-Path -LiteralPath $p) -and (Test-Path -LiteralPath $std)) { Copy-Item -LiteralPath $std -Destination $p }
    }
}

function Get-KitVersion
{
    try { return ([System.IO.File]::ReadAllText((Join-Path $KitRoot 'VERSION'))).Trim() } catch { return '' }
}
function ConvertTo-Version([string]$v) { try { return [version](($v.TrimStart('v') -replace '[^0-9.].*$', '')) } catch { return $null } }

Write-Stap "AppUpdateKit bijwerken vanaf github.com/$Repo" 'Cyan'
Write-Stap "Kit-map: $KitRoot"
$huidig = Get-KitVersion
Write-Stap "Huidige versie: $(if ($huidig) { $huidig } else { 'onbekend' })`n"

try
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy(); $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
    [System.Net.WebRequest]::DefaultWebProxy = $proxy

    # ---------- Welke versie halen we op? ----------
    $tag = $null; $notes = ''
    if (-not $Ontwikkel)
    {
        try
        {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'AppUpdateKit' }
            $tag = "$($rel.tag_name)"; $notes = "$($rel.body)"
        }
        catch { Write-Stap 'Geen release gevonden (of GitHub niet bereikbaar): de laatste stand van main wordt gebruikt.' 'Yellow' }
    }
    if ($tag)
    {
        $nieuwV = ConvertTo-Version $tag; $huidigV = ConvertTo-Version $huidig
        if ($nieuwV -and $huidigV -and $huidigV -ge $nieuwV)
        {
            Write-Stap "De kit is al de nieuwste versie ($huidig)." 'Green'
            Wait-Einde 0
        }
        Write-Stap "Nieuwe versie: $($tag.TrimStart('v'))" 'Green'
        if ($notes.Trim())
        {
            Write-Stap "`nWat is er nieuw:" 'Cyan'
            ($notes -split "`r?`n" | Select-Object -First 30) | ForEach-Object { Write-Host "  $_" }
            Write-Host ''
        }
    }

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ((Test-Path (Join-Path $KitRoot '.git')) -and $git)
    {
        # ---------- Met Git ----------
        Write-Stap 'Opgehaald met Git: bijwerken met git.'
        $bewaar = Save-EigenBestanden
        Push-Location $KitRoot
        # Git schrijft voortgang naar stderr; Windows PowerShell 5.1 ziet dat anders als fout
        $ErrorActionPreference = 'Continue'
        try
        {
            # Stond een eigen bestand nog in Git (oudere kit)? Wijziging even terugzetten, anders weigert git.
            foreach ($rel in $eigen)
            {
                $gitPad = $rel.Replace('\', '/')
                & git ls-files --error-unmatch -- $gitPad 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { & git checkout -- $gitPad 2>$null }
            }
            $voor = (& git rev-parse --short HEAD).Trim()
            & git fetch --tags origin $Branch 2>&1 | ForEach-Object { Write-Host "  $_" }
            if ($tag) { & git merge --ff-only $tag 2>&1 | ForEach-Object { Write-Host "  $_" } }
            else      { & git merge --ff-only "origin/$Branch" 2>&1 | ForEach-Object { Write-Host "  $_" } }
            if ($LASTEXITCODE -ne 0) { throw "Bijwerken met git is mislukt (exitcode $LASTEXITCODE). Heb je zelf kit-bestanden aangepast? Kijk dan met 'git status' in $KitRoot." }
            $na = (& git rev-parse --short HEAD).Trim()
        }
        finally { Pop-Location; Restore-EigenBestanden $bewaar; $ErrorActionPreference = 'Stop' }
        if ($voor -eq $na) { Write-Stap "`nDe kit is al bijgewerkt ($(Get-KitVersion))." 'Green' }
        else { Write-Stap "`nBijgewerkt naar versie $(Get-KitVersion)." 'Green' }
        Wait-Einde 0
    }

    # ---------- Zonder Git: zip downloaden ----------
    $url = if ($tag) { "https://github.com/$Repo/archive/refs/tags/$tag.zip" } else { "https://github.com/$Repo/archive/refs/heads/$Branch.zip" }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppUpdateKit_$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -Path $tmp -ItemType Directory -Force | Out-Null
    try
    {
        $zip = Join-Path $tmp 'kit.zip'
        Write-Stap "Downloaden van $url ..."
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'uit') -Force
        $bron = Get-ChildItem -LiteralPath (Join-Path $tmp 'uit') -Directory | Select-Object -First 1
        if (-not $bron -or -not (Test-Path (Join-Path $bron.FullName 'AppUpdateKit-Builder.ps1'))) { throw 'De download bevat geen AppUpdateKit (AppUpdateKit-Builder.ps1 ontbreekt).' }

        $bewaar = Save-EigenBestanden
        $n = 0
        foreach ($f in Get-ChildItem -LiteralPath $bron.FullName -Recurse -File -Force)
        {
            $rel = $f.FullName.Substring($bron.FullName.Length).TrimStart('\', '/').Replace('/', '\')
            if ($rel -match $overslaan) { continue }
            if ($rel -in '.gitattributes', '.gitignore') { continue }
            $doel = Join-Path $KitRoot $rel
            $map = Split-Path $doel -Parent
            if (-not (Test-Path -LiteralPath $map)) { New-Item -Path $map -ItemType Directory -Force | Out-Null }
            Copy-Item -LiteralPath $f.FullName -Destination $doel -Force
            $n++
        }
        Restore-EigenBestanden $bewaar
        # Downloadblokkade weghalen, anders vraagt Windows bij elk script om toestemming
        Get-ChildItem -LiteralPath $KitRoot -Recurse -File -Include *.ps1, *.psd1, *.cmd -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(Apps|Output)\\' } | Unblock-File -ErrorAction SilentlyContinue
        Write-Stap "`nBijgewerkt naar versie $(Get-KitVersion): $n bestanden vervangen." 'Green'
        Write-Stap 'Je apps, gebouwde pakketten en instellingen zijn niet aangeraakt.'
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Wait-Einde 0
}
catch
{
    Write-Stap "`nFOUT: $($_.Exception.Message)" 'Red'
    Write-Stap 'Geen internet of een proxy die GitHub blokkeert? Download dan zelf de zip via github.com/Fonfey/AppUpdateKit (Code > Download ZIP) en kopieer alles behalve Apps\ en Output\ over je kit heen.' 'Yellow'
    Wait-Einde 1
}
