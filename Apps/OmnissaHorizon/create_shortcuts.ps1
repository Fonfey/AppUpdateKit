$WshShell = New-Object -ComObject WScript.Shell

function New-Shortcut {
    param (
        [string]$Path,
        [string]$Script
    )

    $Shortcut = $WshShell.CreateShortcut($Path)
    $Shortcut.TargetPath = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.Arguments = "-executionpolicy bypass -windowstyle hidden -file `"$Script`""
    $Shortcut.IconLocation = "C:\Program Files\cctg\Omnissa Client Snelkoppeling\v2.0\horizon-client.ico"
    $Shortcut.WindowStyle = 7
    $Shortcut.Save()
}

New-Shortcut -Path "C:\Users\Public\Desktop\Inloggen VDI werkplek.lnk" `
             -Script "C:\Program Files\cctg\Omnissa Client Snelkoppeling\v2.0\starthorizon.ps1"

New-Shortcut -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Inloggen VDI werkplek.lnk" `
             -Script "C:\Program Files\cctg\Omnissa Client Snelkoppeling\v2.0\starthorizon.ps1"

New-Shortcut -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Inloggen VDI testwerkplek.lnk" `
             -Script "C:\Program Files\cctg\Omnissa Client Snelkoppeling\v2.0\starthorizon-test.ps1"