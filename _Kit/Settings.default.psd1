# AppUpdateKit - settings for this kit (apply to all apps). Edit with Notepad.
@{
    # Folder where the "Browse..." window opens by default when choosing an installer.
    # Empty or not reachable = the folder Windows used last.
    InstallerFolder = ''   # e.g. 'I:\Software\projects\'

    # If you choose the version folder at 'Save package to', the Builder adds this subfolder:
    #   chosen : I:\Software\projects\7-Zip\versions\24.09
    #   package: I:\Software\projects\7-Zip\versions\24.09\intune-package
    # Empty = the chosen folder itself.
    PackageSubfolder = 'intune-package'
}
