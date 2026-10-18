# AppUpdateKit – update packages with popups, for any app

*Nederlands: zie [LEESMIJ.md](LEESMIJ.md).*

> 📖 Walkthrough with screenshots on my blog (in Dutch): [AppUpdateKit: app updates via Intune with a clean popup](https://fonferek.cloud/blog/appupdatekit-app-updates-met-popup-in-intune/).

Every app gets the same popups:
- **"Update available"** bottom right, with the app's logo and the buttons *Later* / *Update now*.
- **After the last postpone**: a warning "The update starts in 5 minutes", with a countdown and only the button *Install now*.
- **Notification during the installation**, with a progress bar.
- **Notification afterwards**: "installed" (green) or "failed" (red).

## The easiest way: the Builder

Once, after unpacking, in PowerShell: `Get-ChildItem C:\AppUpdateKit -Recurse | Unblock-File`

Then double-click **`Start-Builder.cmd`**. After the first time you can also use the **AppUpdateKit Builder** shortcut.

**Language:** pick *Nederlands* or *English* at the top right of the Builder. See [Dutch and English](#dutch-and-english).

1. Click **+ New app** and enter an AppId (e.g. `7Zip`). Or pick an existing app on the left.
2. **Tab 1 – Basics.** Click *Browse...* next to Installer. Name, version, type (MSI/NSIS/Inno) and silent parameters are detected and filled in. Then fill in the processes and pick a logo and a colour. The logo can be an `.svg`, `.png`, `.jpg` or `.ico`. An SVG is converted with Microsoft Edge to a sharp 256×256 icon, and the original is kept as `logo.svg` in the app folder.
3. **Tab 2 – Installation.**
   - **Components:** everything this package installs, in order. For example a runtime first, then the app. For each component you set its own **parameters** and the **exit codes that count as success**. Double-click to change them. The main component is the app itself. When a component fails, the installation stops and the user gets "Update failed".
   - **Extra steps before and after** the components, for example shortcuts or copying a configuration file.
   - `install-app.cmd` is created from this automatically. To write everything by hand, switch off *create automatically*.
4. **Tab 3 – Texts.** Fill in your own texts or leave them empty, in Dutch and in English. With the preview buttons you see each popup bottom right on your screen; nothing is installed.
5. **Tab 4 – Postponing.** How often, how long and how many minutes of warning. Under *When may the update come?* you set:
   - **Time window:** *always*, *only during working hours* or *only outside working hours* (evening, night, weekend), with your own times and working days. Outside the window there is no popup and no installation. Intune tries again at a later check, so the update does not start exactly on the minute.
   - **Idle:** install right away, without popup, when the user has done nothing for a number of minutes or the screen is locked. If the app is open, the installation simply waits.
   - **Nobody signed in:** install right away (also outside the window; needed for Autopilot) or wait until someone signs in.
   - **Restart after the installation:** *never*, *only when the installer asks for it* (exit code 3010/1641) or *always*. The user gets a popup with **Restart now** and **Later**:
     - *Later* means the prompt comes back after a set number of minutes.
     - After the deadline (for example 24 hours) a warning with a countdown follows, and then the laptop restarts.
     - If nobody is signed in, the laptop restarts right away.
     - Intune then gets exit code 0, so there is no second restart prompt.
     - During Autopilot the setup page (ESP) handles the restart.
     - The reminder is a scheduled task (*AppUpdateKit Herstart <AppId>*) that removes itself after the restart.
   - **Uninstall:** with *Show notifications when the app is removed through Intune* the user sees "Removing …" bottom right, then "… has been removed" (green) or "Removal failed" (red). It is off by default. You change the texts in tab 3. With the PowerShell installer you also switch it on or off with `$Notify` in `Uninstall.ps1`. Uninstalling also cleans up the counter, the settings and any restart reminder; `update.log` stays.
6. Click **Build package**. The first time, the Builder offers to download IntuneWinAppUtil.exe from Microsoft. After that `install.intunewin` is ready in `Output\<AppId>\<version>\`, together with the Intune scripts and a list of settings.
7. **Tab 5 – Versions.** All builds are kept, with a full copy (including the installers). When you build a version again, the previous build of that version goes to the archive and is listed as "(replaced)". Click a build to see how it was made: settings, components, steps, texts, build info and what differs from now. With *Preview this version* you see the popups of that time.
   - **Copy and edit:** sets up a full copy of the selected build as the working version, also of an older or archived build. Change only what is needed and build again:
     - **same version number** = improve that version (the previous build goes to the archive);
     - **new installer or new version number** = a new version.

**Shortcut with its own icon:** at every start the Builder creates the **AppUpdateKit Builder** shortcut in the kit folder, with its own icon. Drag it to your desktop or taskbar.

**In Intune after a fix of the same version:** open the existing app → *Properties* → *App information* → *Edit* → *Select file to update* and pick the new `install.intunewin`. Add a **new version** as a new Win32 app, with supersedence on the previous one.

**New version of an app?** Pick the new installer in tab 1. The Builder fills in the new version and offers to remove the old installer from the app folder. Change the texts if needed and click *Build package*. The previous version is kept.

**Standard texts for all apps** are edited in tab 3 with *Edit standard texts for all apps...*. They are in `_Kit\DefaultTexts.psd1` (English under `En`). An app's own text always comes first.

Everything the Builder does, you can also do by hand. That is described below.

## PowerShell installer in Intune (recommended)

Every build creates, next to `install.intunewin`, also **`Intune\Install.ps1`** and **`Intune\Uninstall.ps1`**. Upload these separately in Intune:
*Program* → *Installer type*: **PowerShell script** → *Install script* and *Uninstall script* (32-bit: No, signature check: No).

The advantage: the settings, texts, installation parameters and extra steps are in that script, not in the package. When you change something there, you do it directly in Intune, without repackaging. Repackaging is only needed for a new installer, another logo or a new kit version.

At the top of `Install.ps1` is what you may change:
1. **Switches:** `$NoProcessCheck`, `$NoPopup` and `$Silent` (no popup and no notifications), plus your own switches in `$Switches`, such as `NOSHORTCUTS` for Omnissa.
2. **Settings and texts** in `$App`: the same fields as `app.psd1`, with `Texts` (Dutch) and `TextsEn` (English).
3. **Installation steps** in `$Components`: for each component the command line (`Command`) and the exit codes that count as success (`SuccessCodes`), plus the extra cmd lines in `$PreInstall` and `$PostInstall`.

Note:
- A change you only make in Intune is not in the Builder. Copy it there too, otherwise it is gone after the next build.
- Processes, time window and Autopilot are also in `Requirement.ps1`. If you change them, do it in both scripts.
- The script may be at most 50 KB; the build warns when it gets bigger.
- `install.cmd` still works as a *Command line* installer, with the parameters below.

## Parameters in Intune (Command line installer)

You can put parameters after `install.cmd` in Intune, for example `install.cmd /noshortcuts /noprocesscheck`. They can be combined.

| Parameter | What it does |
|---|---|
| `/noprocesscheck` | Do not check whether the app is running. Then upload **`Intune\Requirement-NoProcessCheck.ps1`** as the requirement script, otherwise the normal script still blocks the installation. The installer itself must be able to handle a running app. |
| `/noconsent` | No popup, install right away. The notifications bottom right remain. |
| `/silent` | No popup and no notifications. |
| `/<own name>` | Available in `install-app.cmd` as `APP_<NAME>`. For example `/noshortcuts` gives `APP_NOSHORTCUTS`. |

Skipping a step with your own parameter (in *Extra steps* or in `install-app.cmd`):
```
if defined APP_NOSHORTCUTS goto after_shortcuts
... steps for the shortcuts ...
:after_shortcuts
```
The parameters an app uses are listed in `Intune-Settings.txt`. They are also logged in `update.log`.

Want to use the same package with different parameters, for example without shortcuts for a certain group? Create a second Win32 app in Intune with the same `install.intunewin` and a different install command.

## New laptops through Autopilot

When **Install on new laptops (Autopilot)** is on in tab 1 (on by default), the package detects that a laptop is still being set up. It checks whether the Windows setup (OOBE) is still running and whether the setup page (ESP) is still busy for the user who signs in. These are the same checks as in PSAppDeployToolkit 4. During setup:
- the app is installed right away, without popup or notifications;
- *only update where the app is installed*, the time window and postponing do not apply.

So you have one app in Intune for both updates and new laptops.

In Intune:
1. Assign the app as **Required** to a **device group** with the Autopilot laptops, for example a dynamic group on `ZTDId`. It then installs during the device phase.
2. Must the app be there before the user can work? Add it in the ESP profile under **Block device use until these required apps are installed**.
3. For large packages, watch the ESP time-out (60 minutes by default).

When the option is off, the package skips setup and the app comes afterwards, with popup.

## Without the Builder: a new app in 4 steps

```powershell
# 1. Create a new app folder from the template (English template with -Lang en)
.\1-New-App.ps1 -AppId 7Zip -AppName '7-Zip' -Lang en
```

2. **Complete `Apps\7Zip\`:**
   - `app.psd1`: version, processes, colour, postpone rules and texts. Every field is explained.
   - `app.ico`: the logo.
   - The installer(s) and any extra files (config, scripts, shortcuts).
   - `install-app.cmd`: your installation steps with their parameters. The file has examples for MSI, NSIS, Inno and other installers.
   - `uninstall-app.cmd`: your uninstall steps. If uninstalling through the setup.exe does not work (exit code 1605, as with Omnissa), use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "<name in Apps & features>"`. It looks the app up and removes it through the MSI product code or its own uninstaller.

```powershell
# 3. Build the package (also checks that everything is correct)
.\2-Build-Package.ps1 -App 7Zip -Lang en
```

4. **Upload in Intune.** Everything is in `Output\7Zip\<version>\`:

| File | What to do with it |
|---|---|
| `<version>\install.intunewin` | Upload as Win32 app. Only created automatically when `IntuneWinAppUtil.exe` is next to the scripts. |
| `Intune\Install.ps1`, `Intune\Uninstall.ps1` | Upload under *Program* (PowerShell script installer) |
| `Intune\Requirement.ps1` | Upload under *Requirements* (Output: String, Equals, `Voldaan`) |
| `Intune\Detection.ps1` | Upload under *Detection rules* |
| `Intune-Settings.txt` | All other Intune settings in one list |
| `Source\` and `BuildInfo.txt` | The settings, texts and logo of this version, plus when and by whom it was built and the SHA-256 of every file |

## What you fill in per app, and what not

| Per app (in `Apps\<AppId>\`) | The same for every app (in `_Kit\`) |
|---|---|
| `app.psd1`: details, logo, colour, texts | The popups (`AppUI.ps1`) |
| `install-app.cmd` / `uninstall-app.cmd` | Process check, consent, postponing, warning |
| Installers, logo, own files | `install.cmd` / `uninstall.cmd` (call your `-app.cmd`) |
| | Requirement and detection script |

When you change something in `_Kit\`, for example the design, build the apps again with `2-Build-Package.ps1` and they all get the change.

## Dutch and English

The kit works in two languages.

- **The Builder and the generated files.** Pick *Nederlands* or *English* at the top right of the Builder. The Builder then restarts in that language. The same language applies to the messages, the log files (`update.log`), the comments in `Install.ps1` and the other scripts, `Intune-Settings.txt` and new apps from the template. The choice is stored in `_Kit\Settings.psd1` (`Language = 'nl'` or `'en'`). Without the Builder, pass the language with `-Lang en`, for example `.\2-Build-Package.ps1 -App 7Zip -Lang en`.
- **The popups for users** follow the Windows language of the signed-in user: English Windows gives English popups, any other language gives Dutch. If you do not want that, pick *Always Dutch* or *Always English* under *Popup language* in tab 1 (`PopupLanguage` in `app.psd1`: `Auto`, `nl` or `en`).
- **English texts** are filled in in tab 3: pick *English* under *Texts and previews in*. They are stored in `app.psd1` under `TextsEn`. An empty field means: the English standard text. The English standard texts are in `_Kit\DefaultTexts.psd1` under `En`. The preview buttons show the popups in the selected language.

The fixed values in the files stay Dutch in both languages: `Altijd` (always), `Werktijd` (working hours), `BuitenWerktijd` (outside working hours), `Nooit` (never), `AlsNodig` (when needed), `Installeren` (install), `Wachten` (wait), the working days `ma,di,wo,do,vr` (Mon–Fri; `mon,tue,...` also works) and the requirement output `Voldaan`. The script and file names are English in both languages (`2-Build-Package.ps1`, `Intune-Settings.txt`, `BuildInfo.txt`, `Source\`, ...).

## Texts
- **Standard texts for all apps** are in `_Kit\DefaultTexts.psd1`. Edit them in the Builder or by hand.
- **Per app and version** you fill in your own texts under `Texts` (Dutch) and `TextsEn` (English) in `app.psd1`, or in the Builder (tab 3). An empty field (`''`) means: use the standard text.

**New installation or update?** Before installing, the package checks whether the app is already in "Apps & features" (the name under *Apps & features* in tab 1). If it is not there yet, the popups are about an **installation**: "A new app is ready for you", the button "Install now" and the notification "… has been installed". If it is already there, they are about an **update**. The texts for a new installation are at the bottom of tab 3 ("New installation - ..."). With *Show previews as a new installation* you see what they look like.

These words are filled in automatically:
- `{AppName}`: the name of the app
- `{Version}`: the version of this package
- `{Minutes}`: how many minutes of warning in advance
- `{MaxPostpones}`: how often the user may postpone

The Dutch forms `{Versie}`, `{Minuten}` and `{MaxUitstel}` work too.

## Getting started
`Apps\` and `Output\` are empty. Create your first app with **+ New app** in the Builder, or with `.\1-New-App.ps1`. Built packages appear in `Output\`.

## Testing on a laptop
- Log and counter per app: `C:\ProgramData\AppUpdates\<AppId>\` (`update.log`, `PostponeState.json`).
- Test the 5-minute warning right away: set `PostponeCount` to 5 and `PostponeUntil` in the past, and run `.\Ask-InstallConsent.ps1` in an admin PowerShell in the package folder.
- Reset the counter: delete `PostponeState.json`.
- Time window and idle: `update.log` records each time why there was or was not a popup, for example "Outside the time window" or "has been idle for 15 minutes". To test idle: set *Idle* to 1 minute, lock the screen (Windows key + L) and start the installation from Company Portal or with `.\install.cmd`.
- Test the English popups on a Dutch laptop: set *Popup language* to *Always English* in tab 1 and build again.
