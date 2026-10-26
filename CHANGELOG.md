# Changelog

All notable changes to AppUpdateKit. Versions follow [semantic versioning](https://semver.org/):
**major** (1.x → 2.0) can need changes in Intune or in your apps, **minor** (1.0 → 1.1) adds features,
**patch** (1.0.0 → 1.0.1) only fixes bugs.

After updating the kit, rebuild an app to get the new kit version into its package.

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
