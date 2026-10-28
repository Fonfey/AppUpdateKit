# Changelog

All notable changes to AppUpdateKit. Versions follow [semantic versioning](https://semver.org/):
**major** (1.x → 2.0) can need changes in Intune or in your apps, **minor** (1.0 → 1.1) adds features,
**patch** (1.0.0 → 1.0.1) only fixes bugs.

After updating the kit, rebuild an app to get the new kit version into its package.

## [1.3.1] - 2026-10-28

### Fixed
- **Autopilot: apps in the Enrollment Status Page were skipped.** During setup the requirement script wrote its reason to the error output. Intune counts any error output as exit code -1, so the requirement was "not met", the ESP moved on without the app, and after sign-in the app came with a popup. The reason now goes to `C:\ProgramData\AppUpdates\<AppId>\requirement.log` (one line per change), and the script never writes to the error output. Rebuild the app and upload the new `Intune\Requirement.ps1` in Intune; the package itself doesn't change.

## [1.3.0] - 2026-10-28

### Changed
- **Everything in English.** The scripts are written in English now: texts, comments, variable and function names. The Dutch version comes from `Language\nl.xml` (English original and Dutch translation side by side), so the Builder, the command-line scripts and the scripts on the laptop work in Dutch exactly as before. `Language\Test-Language.ps1` checks the translation.
- **English file names**: `Build-Package.ps1`, `New-App.ps1`, `Update-Kit.cmd`/`.ps1`, `_Kit\Settings.psd1`, `_Kit\DefaultTexts.psd1` (English) and `_Kit\DefaultTexts.nl.psd1` (Dutch); in a build `BuildInfo.txt`, `Intune-settings.txt`, `Package\`, `Source\`, `_archive\`, `PackageLocation.txt` and `Intune\Requirement-NoProcessCheck.ps1`; with an ADMX `<name>-settings.reg` and `<name>.choices.json`.
- **English setting values** in `app.psd1`: `InstallWindow` `Always` / `DuringWorkHours` / `OutsideWorkHours`, `NoUserAction` `Install` / `Wait`, `RestartMode` `Never` / `IfNeeded` / `Always`, `DetectionMethod` `AppsAndFeatures` / `File` / `Registry` / `Script`, `WorkDays` `mon,tue,...`. Placeholders in texts: `{Version}`, `{Minutes}`, `{MaxPostpones}`.
- On the laptop: the folders `Restart` and `Steps` and the scheduled task `AppUpdateKit Restart <AppId>`.
- The default language for new users and new apps is English. The language choice is stored in `%LOCALAPPDATA%\AppUpdateKit\language.txt`.

### Upgrading from an older version
- Nothing to convert by hand. The kit moves `_Kit\Instellingen.psd1` and `_Kit\Standaardteksten(.en).psd1` to the new names (and renames `InstallerMap` / `PakketSubmap` inside), reads the Dutch values and placeholders of older apps and converts them when you save, still shows builds made with older versions (`Bouwinfo.txt`, `Bron\`, `_archief\`), keeps the name of an existing `-instellingen.reg`, and reuses your earlier language choice.
- Files under their old Dutch names are removed when you update with `Update-Kit` or start the Builder.
- A new package removes the old restart task (`AppUpdateKit Herstart <AppId>`) and the folders `Herstart` and `Stappen` from the laptop. Apps without `Language` (made before 1.2) stay Dutch.

## [1.2.1] - 2026-10-28

### Changed
- **One set of scripts, texts in `Language\en.xml`.** The separate English copies of the scripts are gone. Every text people see is listed in `Language\en.xml`, with the Dutch original and the translation side by side. `Language\Translate.ps1` translates the Builder and the scripts when they start (cached per user in `%LOCALAPPDATA%\AppUpdateKit\Taal`), and the scripts for the laptop when a package is built. `Language\Test-Taal.ps1` lists texts that still need a translation. Another language is one more xml file.
- **Shorter detection script.** `Intune\Detection.ps1` now only contains the detection you chose (Apps & features, file or registry): about 30 lines instead of 115, so it is easy to read in Intune. *Test on this PC* in the Builder still explains why an app is or isn't found, using a separate script that doesn't go to Intune.
- **Edit ADMX settings later.** Once an app has settings from an ADMX, *Instellingen uit ADMX...* (*Settings from ADMX...*) opens a menu to edit them, or to import another ADMX. Double-clicking the `<name>-instellingen.reg` row in the table opens them too.

## [1.2.0] - 2026-10-26

### Added
- **English Builder.** The first time you start the Builder, it asks which language you want (Nederlands or English) and remembers it per user (`%LOCALAPPDATA%\AppUpdateKit\taal.txt`). Switch any time with the **Taal / Language** button at the bottom left. `Start-Builder.cmd` stays the way to start it.
- **Language per app** (*Language on the laptop* in tab 3, or `Language = 'en'` in `app.psd1`). An English app gets English popups and buttons, English default texts (`_Kit\Standaardteksten.en.psd1`) and English scripts on the laptop, including `Install.ps1`, `Uninstall.ps1` and the logs.
- `2-Bouw-pakket`, `1-Nieuwe-app`, `Kit-bijwerken` and the app template follow the chosen language too.

### Changed
- Apps made with either Builder open in the other one: the generated steps are recognised in both languages.
- Existing apps without `Language` stay Dutch. Nothing changes until you choose English for an app.

## [1.1.0] - 2026-10-26

### Added
- **Settings from an ADMX** (optional): in tab 2, *Instellingen uit ADMX...* (or add a `.admx` with *Toevoegen...*) opens a window with all policies of the app's ADMX, with the texts from the ADML. Choose *Enabled* / *Disabled* and fill in the values; the Builder saves them as `<name>-instellingen.reg`, installed as a component after the app. Uninstalling removes the values again, and policy keys that are empty afterwards.
- Your choices, the ADMX and the ADML are kept in `Apps\<AppId>\_admx\`, so you can change them later. This folder is not copied to the laptop.
- User-only policies (class *User*) are shown but can't be chosen: the installation runs as SYSTEM.

### Changed
- `.reg` components are imported with `reg.exe import ... /reg:64`, and uninstalled with `/reg:64`, so they always land in the 64-bit registry, like Group Policy.

## [1.0.0] - 2026-10-26

First release.

### Popups and install flow
- Consent popup with **Later** (postpone) and **Update now**, with a configurable limit and duration.
- Final warning with countdown after the last postpone.
- Notifications while installing (with progress) and afterwards (installed / failed), also for uninstall (optional).
- Separate texts for a new install and for an update; default texts for all apps, own texts per app.
- Process check: if the app is open, Intune retries later (exit 1618).
- Time window (during / outside working hours), install when idle or locked, install when nobody is logged on.
- Restart prompt (never / when needed / always) with Later, a deadline and a countdown.
- Autopilot: silent install during OOBE/ESP.

### Builder
- Reads `.msi` and `.exe` installers (MSI, NSIS, Inno Setup, InstallShield, WiX): name, version, silent switches, logo.
- One table for components (installed in order, own parameters and exit codes) and other files (copy to a folder, logo, include only).
- Generates install and uninstall steps, detection script (Apps and features, file, registry or own script) and requirement script (Boolean).
- Uninstall steps for extra components, including steps derived from your own `.ps1` and `.cmd` scripts (shortcuts, files, folders, registry, scheduled tasks, services, firewall rules, environment variables).
- Checks before building, such as msiexec switches that don't exist (exit code 1639).
- PowerShell script installer: `Install.ps1` / `Uninstall.ps1` hold settings, texts and steps, so you can change them in Intune without repackaging.
- Version history: every build is kept, with an archive for rebuilt versions.
- **Kit bijwerken...**: update the kit to the latest release from GitHub; your apps, packages and settings stay.
