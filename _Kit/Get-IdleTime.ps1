<#
.SYNOPSIS
    Writes how many milliseconds the user hasn't used the mouse or keyboard.
    Runs in the user's session (started by AppUI-Launcher.ps1). Do NOT change per app.
#>
param ([Parameter(Mandatory = $true)][string]$OutPath)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AppKitIdle
{
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
    [DllImport("kernel32.dll")] static extern uint GetTickCount();
    public static uint IdleMs()
    {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref info)) { return 0; }
        return unchecked(GetTickCount() - info.dwTime);
    }
}
'@

$tmp = "$OutPath.tmp"
[System.IO.File]::WriteAllText($tmp, [string][AppKitIdle]::IdleMs())
Move-Item -Path $tmp -Destination $OutPath -Force
