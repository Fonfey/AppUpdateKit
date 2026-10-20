<#
.SYNOPSIS
    Checks why the Builder does not switch language (or other start-up problems).
    Changes nothing. Writes the result to Diagnose-Builder.txt and opens it in Notepad.
    Start with Diagnose-Builder.cmd (double-click).
#>

$KitRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$lines = New-Object System.Collections.Generic.List[string]
function Add([string]$Text) { $lines.Add($Text) }
function Try-Run([string]$Label, [scriptblock]$Block)
{
    try { Add ("{0,-28}: {1}" -f $Label, ((& $Block) -join ' | ')) }
    catch { Add ("{0,-28}: ERROR - {1}" -f $Label, $_.Exception.Message) }
}

Add "AppUpdateKit - Diagnose  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add ('=' * 70)
Try-Run 'PowerShell'            { "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" }
Try-Run 'Windows'               { (Get-CimInstance Win32_OperatingSystem).Caption + ' ' + (Get-CimInstance Win32_OperatingSystem).Version }
Try-Run 'Windows language (UI)' { (Get-UICulture).Name }
Try-Run 'Kit folder'            { $KitRoot }
Try-Run 'Builder file date'     { (Get-Item (Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')).LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
Try-Run 'Builder is new version'{ [bool](Select-String -Path (Join-Path $KitRoot 'AppUpdateKit-Builder.ps1') -Pattern '\$xamlText' -Quiet) }
Try-Run 'Builder blocked (web)' { [bool](Get-Item (Join-Path $KitRoot 'AppUpdateKit-Builder.ps1') -Stream Zone.Identifier -ErrorAction SilentlyContinue) }
Try-Run 'Execution policy'      { (Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) }
Try-Run 'APPKIT_LANG variable'  { if ($env:APPKIT_LANG) { $env:APPKIT_LANG } else { '(not set)' } }

$settings = Join-Path $KitRoot '_Kit\Settings.psd1'
Add ''
Try-Run 'Settings.psd1 exists'  { Test-Path $settings }
Try-Run 'Settings.psd1 content' { (Get-Content $settings) }
Try-Run 'Settings.psd1 Language'{ (Import-PowerShellDataFile $settings).Language }
Try-Run 'Settings.psd1 read-only'{ (Get-Item $settings).IsReadOnly }
Try-Run 'Settings.psd1 writable'{ $f = [System.IO.File]::Open($settings, 'Open', 'ReadWrite', 'None'); $f.Close(); 'yes' }
Try-Run 'Kit folder writable'   { $t = Join-Path $KitRoot ('_write_test_' + [guid]::NewGuid().ToString('N') + '.tmp'); [System.IO.File]::WriteAllText($t, 'x'); Remove-Item $t; 'yes' }

Add ''
$lnk = Join-Path $KitRoot 'AppUpdateKit Builder.lnk'
Try-Run 'Shortcut in kit folder' { if (Test-Path $lnk) { (New-Object -ComObject WScript.Shell).CreateShortcut($lnk).Arguments } else { '(none)' } }
foreach ($desk in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')))
{
    Get-ChildItem $desk -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
        $a = (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).Arguments
        if ($a -match 'AppUpdateKit') { Add ("{0,-28}: {1}" -f "Desktop shortcut $($_.BaseName)", $a) }
    }
}

# Load the Builder's functions (no window) and test the translation
Add ''
$builderErr = $null
try
{
    $env:APPKIT_NOGUI = '1'
    . (Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')
}
catch { $builderErr = $_.Exception.Message }
finally { Remove-Item Env:APPKIT_NOGUI -ErrorAction SilentlyContinue }
Try-Run 'Builder functions loaded' { if ($builderErr) { "NO - $builderErr" } else { 'yes' } }
Try-Run 'Language in the Builder' { $Lang }
Try-Run 'T() returns'           { T 'Nederlands' 'English' }
$script:LangSaved = $Lang; $script:Lang = 'en'   # translation tests always in English
Try-Run 'Dictionary entries'    { $UiTextEn.Count }
Try-Run 'Lookup Opslaan'        { $UiTextEn['Opslaan'] }
Try-Run 'Translation test (en)'      { Convert-XamlLanguage '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Button Content="Opslaan"/><TabItem Header="1. Basis"/></Window>' }

# Same test on the real Builder window text
try
{
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $KitRoot 'AppUpdateKit-Builder.ps1'), [ref]$null, [ref]$null)
    $asg = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] -and $args[0].Left.Extent.Text -eq '$xamlText' }, $true) | Select-Object -First 1
    if ($asg)
    {
        . ([scriptblock]::Create($asg.Extent.Text))
        $out = Convert-XamlLanguage $xamlText
        Add ("{0,-28}: {1}" -f 'Window: Save button', ([regex]::Match($out, 'Name="BtnSave"[^>]*Content="([^"]*)"').Groups[1].Value))
        Add ("{0,-28}: {1}" -f 'Window: first tab', ([regex]::Match($out, '<TabItem Header="([^"]*)"').Groups[1].Value))
    }
    else { Add "Window test                 : old Builder version (no `$xamlText)" }
}
catch { Add "Window test                 : ERROR - $($_.Exception.Message)" }

$script:Lang = $script:LangSaved

$errLog = @('Builder-errors.log', 'Builder-fouten.log') | ForEach-Object { Join-Path $KitRoot $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($errLog)
{
    Add ''
    Add "Last lines of $(Split-Path $errLog -Leaf):"
    Get-Content $errLog -Tail 25 | ForEach-Object { Add "  $_" }
}

$outFile = Join-Path $KitRoot 'Diagnose-Builder.txt'
try { [System.IO.File]::WriteAllLines($outFile, $lines) }
catch { $outFile = Join-Path ([System.IO.Path]::GetTempPath()) 'Diagnose-Builder.txt'; [System.IO.File]::WriteAllLines($outFile, $lines) }
$lines | ForEach-Object { Write-Host $_ }
Start-Process notepad.exe $outFile
