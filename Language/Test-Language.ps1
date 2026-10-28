<#
.SYNOPSIS
    Checks a translation (Language\<language>.xml) against all scripts of the kit.

.DESCRIPTION
    After a change to the scripts: run this script and add what is missing to the xml.
      Language\missing.txt  texts that have no translation yet (they stay English)
      Language\unused.txt   translations that no longer occur in the scripts (can be removed)
    With -Export it also writes the translated scripts to a folder, to read them through.

.EXAMPLE
    .\Language\Test-Language.ps1
    .\Language\Test-Language.ps1 -Language nl -Export C:\Temp\AppUpdateKit-nl
#>
[CmdletBinding()]
param ([string]$Language = 'nl', [string]$Export, [switch]$Strict)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Translate.ps1')
$map = Import-AppKitLanguage $Language
$report = @{
    Used     = (New-Object 'System.Collections.Generic.HashSet[string]')
    Missing  = (New-Object System.Collections.Generic.List[string])
    Problems = (New-Object System.Collections.Generic.List[string])
}

function Test-KitFile([string]$Rel, [switch]$Comments, [hashtable]$Special = @{})
{
    $path = Join-Path $Root $Rel
    $text = [System.IO.File]::ReadAllText($path)
    if ($text.Length -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $out = if ($Rel -match '\.(ps1|psd1)$') { Convert-AppKitScript -Text $text -Map $map -Comments:$Comments -Special $Special -Name (Split-Path $Rel -Leaf) -Report $report }
           else { Convert-AppKitLines $text $map (Split-Path $Rel -Leaf) $report }
    if ($Export)
    {
        $target = Join-Path $Export $Rel
        New-Item -Path (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
        [System.IO.File]::WriteAllText($target, $out, (New-Object System.Text.UTF8Encoding $true))
    }
}

# The Builder (without comments: those stay English) and the other scripts in the kit folder
Test-KitFile 'AppUpdateKit-Builder.ps1' -Special @{ ('$ThisBuilderLang = ''en''   # LANG' + 'CODE') = ('$ThisBuilderLang = ''' + $Language + '''   # LANG' + 'CODE') }
foreach ($f in 'Build-Package.ps1', 'New-App.ps1', 'Update-Kit.ps1') { Test-KitFile $f -Comments }
# Scripts for the laptop and the template for a new app
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root '_Kit') -Recurse -File -Include *.ps1, *.cmd)
{
    Test-KitFile $f.FullName.Substring($Root.Length + 1) -Comments
}
Test-KitFile (Join-Path '_Template' 'app.psd1') -Comments
foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') { Test-KitFile (Join-Path '_Template' $f) }

# Report
$missing = @($report.Missing | Select-Object -Unique)
[System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'missing.txt'), [string[]]$missing)
$unused = foreach ($kind in @(@('Strings', 'str'), @('Xaml', 'xaml'), @('Lines', 'line'), @('Comments', 'cmt'), @('Kit', 'kit')))
{
    $map[$kind[0]].Keys | Where-Object { -not $report.Used.Contains("$($kind[1]):$_") }
}
[System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'unused.txt'), [string[]]@($unused))
$total = 0; foreach ($k in 'Strings', 'Xaml', 'Lines', 'Comments', 'Kit') { $total += $map[$k].Count }
Write-Host "Translations ($Language): $total, used: $($report.Used.Count), unused: $(@($unused).Count) (unused.txt)"
Write-Host "Not translated yet: $($missing.Count) (missing.txt)"
if ($Export) { Write-Host "Translated scripts: $Export" }
if ($report.Problems.Count) { $report.Problems | ForEach-Object { Write-Host "PROBLEM: $_" -ForegroundColor Red }; if ($Strict) { exit 1 } }
