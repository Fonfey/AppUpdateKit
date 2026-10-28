<#
.SYNOPSIS
    Updates this AppUpdateKit to the latest version on GitHub (github.com/Fonfey/AppUpdateKit).

.DESCRIPTION
    Your own work is kept:
      - Apps\ and Output\                    (your apps and built packages)
      - _Kit\Settings.psd1                 (default folder for installers, subfolder for the package)
      - _Kit\DefaultTexts.psd1             (your own default texts, and DefaultTexts.nl.psd1 for Dutch apps)
      - IntuneWinAppUtil.exe and other own files in the kit folder

    You get the latest release (a fixed, tested version, e.g. 1.2.0), not every change in between.
    With -Dev you get the latest state of the main branch.

    Two ways, the script chooses itself:
      - If the kit was fetched with Git (git clone) and Git is on this computer: git fetch and update to the release.
      - Otherwise: download the release as a zip and replace the kit files.

    Start: double-click Update-Kit.cmd, or click "Update kit..." in the Builder.

.PARAMETER Dev
    Get the latest state of main instead of the latest release.

.PARAMETER RestartBuilder
    Restart the Builder after updating (used by the button in the Builder).
#>
[CmdletBinding()]
param (
    [switch]$RestartBuilder,
    [switch]$Dev,
    [string]$Repo   = 'Fonfey/AppUpdateKit',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
# Language: in another language (chosen in the Builder) this script runs translated, with Language\<language>.xml
$langScript = Join-Path (Join-Path $KitRoot 'Language') 'Translate.ps1'
if (Test-Path $langScript) { . $langScript; $translated = Get-AppKitScriptBlock $PSCommandPath; if ($translated) { . $translated @PSBoundParameters; return } }   # LANGSWITCH
# Never overwrite (also the Dutch names of versions before 1.3)
$ownFiles   = @('_Kit\Settings.psd1', '_Kit\DefaultTexts.psd1', '_Kit\DefaultTexts.nl.psd1', '_Kit\Instellingen.psd1', '_Kit\Standaardteksten.psd1', '_Kit\Standaardteksten.en.psd1')
$skipPattern = '^(Apps|Output)(\\|$)|^\.git(\\|$)|^_Kit\\(Settings|DefaultTexts|DefaultTexts\.nl|Instellingen|Standaardteksten|Standaardteksten\.en)\.psd1$'
# Files of versions before 1.3 that no longer exist under this name (removed after a zip update)
$obsolete = @('1-Nieuwe-app.ps1', '2-Bouw-pakket.ps1', 'Kit-bijwerken.ps1', 'Kit-bijwerken.cmd', 'AppUpdateKit-Builder.en.ps1', '1-Nieuwe-app.en.ps1', '2-Bouw-pakket.en.ps1',
              'Kit-bijwerken.en.ps1', '_Kit\Instellingen.standaard.psd1', '_Kit\Standaardteksten.standaard.psd1', '_Kit\Standaardteksten.en.standaard.psd1',
              '_Kit\Intune\Detection.ps1', '_Kit\Intune\Detection-AppsEnOnderdelen.ps1', '_Kit\Intune\Detection-Bestand.ps1', '_Kit\Intune\Detection-Register.ps1',
              '_Kit\Intune\Detection-uitleg.ps1', '_Kit\en', '_Template\en', '_Vertaling', 'Language\en.xml', 'Language\Test-Taal.ps1', 'Apps\LEESMIJ.txt', 'Output\LEESMIJ.txt')

function Write-Step([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Wait-End([int]$Code)
{
    if ($RestartBuilder -and $Code -eq 0)
    {
        Write-Step "`nThe Builder is restarting..." 'Cyan'
        Start-Sleep -Seconds 2
        Start-Process -FilePath (Join-Path $KitRoot 'Start-Builder.cmd') -WorkingDirectory $KitRoot
    }
    else
    {
        Write-Host ''
        Read-Host 'Press Enter to close this window' | Out-Null
    }
    exit $Code
}

function Save-OwnFiles
{
    # Keep own settings temporarily (also if an older kit still had them in Git)
    $saved = @{}
    foreach ($rel in $ownFiles)
    {
        $p = Join-Path $KitRoot $rel
        if (Test-Path -LiteralPath $p) { $saved[$rel] = [System.IO.File]::ReadAllBytes($p) }
    }
    return $saved
}

function Restore-OwnFiles($saved)
{
    foreach ($rel in $saved.Keys) { [System.IO.File]::WriteAllBytes((Join-Path $KitRoot $rel), $saved[$rel]) }
    # Not there yet (new kit)? Then create them from the default version
    foreach ($n in 'Settings', 'DefaultTexts', 'DefaultTexts.nl')
    {
        $p = Join-Path $KitRoot "_Kit\$n.psd1"; $std = Join-Path $KitRoot "_Kit\$n.default.psd1"
        if (-not (Test-Path -LiteralPath $p) -and (Test-Path -LiteralPath $std)) { Copy-Item -LiteralPath $std -Destination $p }
    }
}

function Get-KitVersion
{
    try { return ([System.IO.File]::ReadAllText((Join-Path $KitRoot 'VERSION'))).Trim() } catch { return '' }
}
function ConvertTo-Version([string]$v) { try { return [version](($v.TrimStart('v') -replace '[^0-9.].*$', '')) } catch { return $null } }

Write-Step "Updating AppUpdateKit from github.com/$Repo" 'Cyan'
Write-Step "Kit folder: $KitRoot"
$current = Get-KitVersion
Write-Step "Current version: $(if ($current) { $current } else { 'unknown' })`n"

try
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy(); $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
    [System.Net.WebRequest]::DefaultWebProxy = $proxy

    # ---------- Which version do we get? ----------
    $tag = $null; $notes = ''
    if (-not $Dev)
    {
        try
        {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'AppUpdateKit' }
            $tag = "$($rel.tag_name)"; $notes = "$($rel.body)"
        }
        catch { Write-Step 'No release found (or GitHub unreachable): the latest state of main is used.' 'Yellow' }
    }
    if ($tag)
    {
        $newV = ConvertTo-Version $tag; $currentV = ConvertTo-Version $current
        if ($newV -and $currentV -and $currentV -ge $newV)
        {
            Write-Step "The kit is already the latest version ($current)." 'Green'
            Wait-End 0
        }
        Write-Step "New version: $($tag.TrimStart('v'))" 'Green'
        if ($notes.Trim())
        {
            Write-Step "`nWhat's new:" 'Cyan'
            ($notes -split "`r?`n" | Select-Object -First 30) | ForEach-Object { Write-Host "  $_" }
            Write-Host ''
        }
    }

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ((Test-Path (Join-Path $KitRoot '.git')) -and $git)
    {
        # ---------- With Git ----------
        Write-Step 'Fetched with Git: updating with git.'
        $saved = Save-OwnFiles
        Push-Location $KitRoot
        # Git writes progress to stderr; Windows PowerShell 5.1 would otherwise see that as an error
        $ErrorActionPreference = 'Continue'
        try
        {
            # Was an own file still in Git (older kit)? Undo the change for a moment, otherwise git refuses.
            foreach ($rel in $ownFiles)
            {
                $gitPad = $rel.Replace('\', '/')
                & git ls-files --error-unmatch -- $gitPad 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { & git checkout -- $gitPad 2>$null }
            }
            $before = (& git rev-parse --short HEAD).Trim()
            & git fetch --tags origin $Branch 2>&1 | ForEach-Object { Write-Host "  $_" }
            if ($tag) { & git merge --ff-only $tag 2>&1 | ForEach-Object { Write-Host "  $_" } }
            else      { & git merge --ff-only "origin/$Branch" 2>&1 | ForEach-Object { Write-Host "  $_" } }
            if ($LASTEXITCODE -ne 0) { throw "Updating with git failed (exit code $LASTEXITCODE). Did you change kit files yourself? Then check with 'git status' in $KitRoot." }
            $after = (& git rev-parse --short HEAD).Trim()
        }
        finally { Pop-Location; Restore-OwnFiles $saved; $ErrorActionPreference = 'Stop' }
        if ($before -eq $after) { Write-Step "`nThe kit is already up to date ($(Get-KitVersion))." 'Green' }
        else { Write-Step "`nUpdated to version $(Get-KitVersion)." 'Green' }
        Wait-End 0
    }

    # ---------- Without Git: download zip ----------
    $url = if ($tag) { "https://github.com/$Repo/archive/refs/tags/$tag.zip" } else { "https://github.com/$Repo/archive/refs/heads/$Branch.zip" }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppUpdateKit_$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -Path $tmp -ItemType Directory -Force | Out-Null
    try
    {
        $zip = Join-Path $tmp 'kit.zip'
        Write-Step "Downloading $url ..."
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'off') -Force
        $extracted = Get-ChildItem -LiteralPath (Join-Path $tmp 'off') -Directory | Select-Object -First 1
        if (-not $extracted -or -not (Test-Path (Join-Path $extracted.FullName 'AppUpdateKit-Builder.ps1'))) { throw "The download doesn't contain AppUpdateKit (AppUpdateKit-Builder.ps1 is missing)." }

        $saved = Save-OwnFiles
        $n = 0
        foreach ($f in Get-ChildItem -LiteralPath $extracted.FullName -Recurse -File -Force)
        {
            $rel = $f.FullName.Substring($extracted.FullName.Length).TrimStart('\', '/').Replace('/', '\')
            if ($rel -match $skipPattern) { continue }
            if ($rel -in '.gitattributes', '.gitignore') { continue }
            $destination = Join-Path $KitRoot $rel
            $map = Split-Path $destination -Parent
            if (-not (Test-Path -LiteralPath $map)) { New-Item -Path $map -ItemType Directory -Force | Out-Null }
            Copy-Item -LiteralPath $f.FullName -Destination $destination -Force
            $n++
        }
        Restore-OwnFiles $saved
        foreach ($rel in $obsolete) { $p = Join-Path $KitRoot $rel; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue } }
        # Remove the download block, otherwise Windows asks for permission for every script
        Get-ChildItem -LiteralPath $KitRoot -Recurse -File -Include *.ps1, *.psd1, *.cmd -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(Apps|Output)\\' } | Unblock-File -ErrorAction SilentlyContinue
        Write-Step "`nUpdated to version $(Get-KitVersion): $n files replaced." 'Green'
        Write-Step 'Your apps, built packages and settings have not been touched.'
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Wait-End 0
}
catch
{
    Write-Step "`nERROR: $($_.Exception.Message)" 'Red'
    Write-Step 'No internet, or a proxy that blocks GitHub? Then download the zip yourself via github.com/Fonfey/AppUpdateKit (Code > Download ZIP) and copy everything except Apps\ and Output\ over your kit.' 'Yellow'
    Wait-End 1
}
