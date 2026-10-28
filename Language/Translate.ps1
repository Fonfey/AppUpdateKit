<#
.SYNOPSIS
    AppUpdateKit - languages. The scripts are written in English; this file translates them with Language\<language>.xml.

.DESCRIPTION
    There is only one set of scripts. Every text people see is in Language\<language>.xml:
    per text the English original (<en>) and the translation (e.g. <nl>).
      - The Builder, Build-Package, New-App and Update-Kit translate themselves when they start
        into the language you chose in the Builder. The translation is kept in %LOCALAPPDATA%\AppUpdateKit\Language,
        so that is only needed once (until the script or the xml changes).
      - The scripts for the laptop (_Kit) are translated into the language of the app when a package is built.
    A text that is not in the xml stays English. Language\Test-Language.ps1 shows which texts are still missing.

    Add a new language: copy nl.xml to e.g. de.xml, set code="de", rename <nl> to <de> and translate.
#>

$script:AppKitLanguageDir = $PSScriptRoot

function Get-AppKitLanguage
{
    # Language the user chose in the Builder (kept per user): 'en', 'nl', ... Default 'en'.
    # (older versions kept it in taal.txt)
    $dir = Join-Path $env:LOCALAPPDATA 'AppUpdateKit'
    $l = ''
    foreach ($name in 'language.txt', 'taal.txt')
    {
        try { $l = ([System.IO.File]::ReadAllText((Join-Path $dir $name))).Trim().ToLower() } catch { $l = '' }
        if ($l) { break }
    }
    if ($l -and $l -ne 'en' -and (Test-Path -LiteralPath (Join-Path $script:AppKitLanguageDir "$l.xml"))) { return $l }
    return 'en'
}

function Import-AppKitLanguage([string]$Lang)
{
    # Reads Language\<language>.xml. Returns per kind of text a table English -> translation (case-sensitive).
    if (-not $script:AppKitMaps) { $script:AppKitMaps = @{} }
    if ($script:AppKitMaps.ContainsKey($Lang)) { return $script:AppKitMaps[$Lang] }
    $path = Join-Path $script:AppKitLanguageDir "$Lang.xml"
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($path)
    $map = @{ Lang = $Lang; File = $path; Keep = (New-Object 'System.Collections.Generic.HashSet[string]') }
    foreach ($kind in 'Strings', 'Xaml', 'Lines', 'Comments', 'Kit')
    {
        $d = New-Object 'System.Collections.Generic.Dictionary[string,string]'
        foreach ($t in @($doc.DocumentElement.SelectNodes("$($kind.ToLower())/t")))
        {
            $en = $t.SelectSingleNode('en'); $tr = $t.SelectSingleNode($Lang)
            if ($en -and $tr) { $d[$en.InnerText] = $tr.InnerText }
        }
        $map[$kind] = $d
    }
    foreach ($k in @($doc.DocumentElement.SelectNodes('keep/en'))) { [void]$map.Keep.Add($k.InnerText) }
    $script:AppKitMaps[$Lang] = $map
    return $map
}

function Test-AppKitHumanText([string]$s)
{
    # Looks like a sentence or label for people (and not like code, a path or a regex)? Only for Test-Language.ps1.
    if (-not $s) { return $false }
    if ($s -notmatch '[A-Za-zë]{2,}\s+[A-Za-zë]{2,}') { return $false }
    if ($s -match '^\s*[\^\(\[\\]' -or $s -match '^[\w\-]+\.(ps1|cmd|psd1|json|txt|exe|msi)$') { return $false }
    return $true
}

function Get-AppKitVarRefs([string]$text)
{
    # Variables in a text (also within $(...)), to check that the translation has all of them
    $refs = [regex]::Matches($text, '\$\{[^}]+\}|\$[A-Za-z_][\w:]*(?:\.[A-Za-z_]\w*)*') | ForEach-Object { $_.Value }
    return (@($refs) | Sort-Object) -join '|'
}

function Convert-AppKitXaml([string]$Text, $Map, [string]$Where, $Report)
{
    # XAML: attribute values (Title, Text, Content, Header, ToolTip) and text between tags
    $Text = [regex]::Replace($Text, '(?<attr>\b(?:Title|Text|Content|Header|ToolTip)=")(?<val>[^"]*)(")', {
        param($m)
        $v = $m.Groups['val'].Value
        if ($Map.Xaml.ContainsKey($v)) { if ($Report) { [void]$Report.Used.Add("xaml:$v") }; return $m.Groups['attr'].Value + $Map.Xaml[$v] + '"' }
        if ($Report -and $v -match '[A-Za-zë]{2,}' -and -not $Map.Keep.Contains($v) -and $v -notmatch '^\{' -and $v -notmatch '^&#') { $Report.Missing.Add("XAML  $Where :: $v") }
        return $m.Value
    })
    $Text = [regex]::Replace($Text, '>(?<val>[^<>]*[A-Za-zë]{2,}[^<>]*)<', {
        param($m)
        $v = $m.Groups['val'].Value.Trim()
        if (-not $v) { return $m.Value }
        if ($Map.Xaml.ContainsKey($v)) { if ($Report) { [void]$Report.Used.Add("xaml:$v") }; return '>' + $m.Groups['val'].Value.Replace($v, $Map.Xaml[$v]) + '<' }
        if ($Report -and -not $Map.Keep.Contains($v)) { $Report.Missing.Add("XAML  $Where :: $v") }
        return $m.Value
    })
    return $Text
}

function Convert-AppKitLines([string]$Text, $Map, [string]$Where = '', $Report, [switch]$Check)
{
    # Line by line (.cmd files, here-strings with templates, block comments): look up the trimmed line
    $nl = if ($Text -match "`r`n") { "`r`n" } else { "`n" }
    $out = foreach ($line in ($Text -split "`r?`n"))
    {
        $t = $line.Trim()
        if ($t -and $Map.Lines.ContainsKey($t))
        {
            $new = $Map.Lines[$t]
            if ($Report)
            {
                [void]$Report.Used.Add("line:$t")
                if ($Check -and (Get-AppKitVarRefs $t) -ne (Get-AppKitVarRefs $new)) { $Report.Problems.Add("Variables differ in line ($Where): $t") }
            }
            $line.Substring(0, $line.Length - $line.TrimStart().Length) + $new
        }
        else
        {
            if ($Report -and $t -and (Test-AppKitHumanText $t) -and -not $Map.Keep.Contains($t) -and $t -notmatch '^[@{}\(\)]') { $Report.Missing.Add("LINE  $Where :: $t") }
            $line
        }
    }
    return ($out -join $nl)
}

function Convert-AppKitScript
{
    # Translates a PowerShell script (text): strings, XAML and templates in here-strings, and with -Comments also
    # comments and the fixed texts for the laptop. -ScriptRoot: replace $PSScriptRoot by this folder
    # (needed when the translation runs as a scriptblock). -Special: fixed text replacements afterwards.
    param (
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)]$Map,
        [switch]$Comments,
        [hashtable]$Special = @{},
        [string]$ScriptRoot,
        [string]$Name = 'script',
        $Report
    )
    # Templates contain {{NAME}} placeholders: replace them temporarily so the script can be parsed
    $hasPh = $Text -match '\{\{\w+\}\}'
    $Text = [regex]::Replace($Text, '\{\{(\w+)\}\}', 'PHX$1XPH')
    $tokens = $null; $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errs)
    if ($errs.Count -and -not $hasPh) { throw "Parse error in $Name : $($errs[0].Message)" }
    $reps = New-Object System.Collections.Generic.List[object]
    foreach ($t in $tokens)
    {
        $kind = "$($t.Kind)"
        $new = $null
        if ($kind -in 'StringLiteral', 'StringExpandable')
        {
            $raw = [regex]::Replace($t.Text, 'PHX(\w+?)XPH', '{{$1}}')
            if ($Comments -and $Map.Kit.ContainsKey($raw)) { $new = $Map.Kit[$raw]; if ($Report) { [void]$Report.Used.Add("kit:$raw") } }
            elseif ($Map.Strings.ContainsKey($raw))
            {
                $new = $Map.Strings[$raw]
                if ($Report)
                {
                    [void]$Report.Used.Add("str:$raw")
                    if ($kind -eq 'StringExpandable' -and (Get-AppKitVarRefs $raw) -ne (Get-AppKitVarRefs $new)) { $Report.Problems.Add("Variables differ ($Name r$($t.Extent.StartLineNumber)): $raw") }
                }
            }
            elseif ($Report -and (Test-AppKitHumanText $t.Value) -and -not $Map.Keep.Contains($raw)) { $Report.Missing.Add("STR   $Name r$($t.Extent.StartLineNumber) :: $raw") }
        }
        elseif ($kind -in 'HereStringLiteral', 'HereStringExpandable')
        {
            $raw = [regex]::Replace($t.Text, 'PHX(\w+?)XPH', '{{$1}}')
            $open = $raw.Substring(0, $raw.IndexOf("`n") + 1); $close = $raw.Substring($raw.LastIndexOf("`n"))
            $body = $raw.Substring($open.Length, $raw.Length - $open.Length - $close.Length)
            $where = "$Name r$($t.Extent.StartLineNumber)"
            $nb = if ($body -match '(?m)^\s*using System|namespace \w+\s*\{') { $body }   # C# code: don't translate
                  elseif ($body -match '^\s*<' -or $body -match '<Window |x:Key=') { Convert-AppKitXaml $body $Map $where $Report }
                  else { Convert-AppKitLines $body $Map $where $Report -Check:($kind -eq 'HereStringExpandable') }
            if ($nb -ne $body) { $new = $open + $nb + $close }
        }
        elseif ($Comments -and $kind -eq 'Comment')
        {
            $raw = [regex]::Replace($t.Text, 'PHX(\w+?)XPH', '{{$1}}')
            if ($raw.StartsWith('<#'))
            {
                $nb = Convert-AppKitLines $raw $Map "$Name r$($t.Extent.StartLineNumber)" $Report -Check
                if ($nb -ne $raw) { $new = $nb }
            }
            elseif ($Map.Comments.ContainsKey($raw)) { $new = $Map.Comments[$raw]; if ($Report) { [void]$Report.Used.Add("cmt:$raw") } }
            elseif ($Report -and (Test-AppKitHumanText $raw) -and -not $Map.Keep.Contains($raw)) { $Report.Missing.Add("CMT   $Name r$($t.Extent.StartLineNumber) :: $raw") }
        }
        elseif ($ScriptRoot -and $kind -eq 'Variable' -and $t.Name -eq 'PSScriptRoot')
        {
            $new = "'" + $ScriptRoot.Replace("'", "''") + "'"
        }
        if ($null -ne $new -and $new -ne $t.Text) { $reps.Add(@{ Start = $t.Extent.StartOffset; End = $t.Extent.EndOffset; Text = $new }) }
    }
    $sb = New-Object System.Text.StringBuilder $Text
    for ($i = $reps.Count - 1; $i -ge 0; $i--) { $r = $reps[$i]; [void]$sb.Remove($r.Start, $r.End - $r.Start); [void]$sb.Insert($r.Start, $r.Text) }
    $out = [regex]::Replace($sb.ToString(), 'PHX(\w+?)XPH', '{{$1}}')
    foreach ($k in $Special.Keys)
    {
        if ($Report -and -not $out.Contains($k)) { $Report.Problems.Add("Fixed replacement not found in $Name : $k") }
        $out = $out.Replace($k, $Special[$k])
    }
    if ($Report)
    {
        # Check: the translated script must also parse without errors
        $errs2 = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($out, [ref]$null, [ref]$errs2)
        if ($errs2.Count -and -not $hasPh) { $Report.Problems.Add("Parse error in the translation of $Name : $($errs2[0].Message) (line $($errs2[0].Extent.StartLineNumber))") }
    }
    return $out
}

function Convert-AppKitFile
{
    # A file of the kit as text, translated to the language (en = unchanged). .ps1/.psd1 as a script, the rest line by line.
    param ([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Lang, [hashtable]$Special = @{})
    $text = [System.IO.File]::ReadAllText($Path)
    if ($text.Length -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    if (-not $Lang -or $Lang -eq 'en') { return $text }
    $map = Import-AppKitLanguage $Lang
    if ([System.IO.Path]::GetExtension($Path) -in '.ps1', '.psd1') { return (Convert-AppKitScript -Text $text -Map $map -Comments -Special $Special -Name (Split-Path $Path -Leaf)) }
    return (Convert-AppKitLines $text $map)
}

function Get-AppKitTranslatedCode
{
    # Translated version of a script of the kit, from the saved translation if it is still up to date.
    param ([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Lang, [hashtable]$Special = @{}, [switch]$Comments)
    $src = [System.IO.File]::ReadAllText($Path)
    $root = Split-Path $Path -Parent
    $map = Import-AppKitLanguage $Lang
    $xml = [System.IO.File]::ReadAllText($map.File)
    $key = "v1|$Lang|$root|$($Comments.IsPresent)|$((@($Special.Keys | Sort-Object) | ForEach-Object { "$_=$($Special[$_])" }) -join ';')|$src|$xml"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key))[0..7] | ForEach-Object { $_.ToString('x2') })
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $cacheDir = Join-Path $env:LOCALAPPDATA 'AppUpdateKit\Language'
    $cache = Join-Path $cacheDir "$name.$Lang.$hash.ps1"
    if (Test-Path -LiteralPath $cache) { return [System.IO.File]::ReadAllText($cache) }
    $code = Convert-AppKitScript -Text $src -Map $map -Comments:$Comments -Special $Special -ScriptRoot $root -Name (Split-Path $Path -Leaf)
    try
    {
        New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
        Get-ChildItem -LiteralPath $cacheDir -Filter "$name.$Lang.*.ps1" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText($cache, $code, (New-Object System.Text.UTF8Encoding $true))
    }
    catch { }   # could not save: translate again next time
    return $code
}

function Get-AppKitScriptBlock
{
    # At the top of a script of the kit (after param):
    #   $translated = Get-AppKitScriptBlock $PSCommandPath; if ($translated) { . $translated @PSBoundParameters; return }   # LANGSWITCH
    # Returns the script translated to the user's language, or $null for English (then the script simply continues).
    # The line with LANGSWITCH is left out of the translated version, otherwise it would translate itself again.
    param ([string]$Path, [string]$Lang = (Get-AppKitLanguage), [hashtable]$Special = @{}, [bool]$Comments = $true)
    # -Comments `$false (the Builder): don't translate comments and the fixed laptop texts
    if (-not $Path -or -not $Lang -or $Lang -eq 'en') { return $null }
    $sp = @{} + $Special
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) { if ($line -match '#\s*LANGSWITCH\s*$') { $sp[$line] = '# (language: translated by Language\Translate.ps1)' } }
    return [scriptblock]::Create((Get-AppKitTranslatedCode -Path $Path -Lang $Lang -Special $sp -Comments:$Comments))
}
