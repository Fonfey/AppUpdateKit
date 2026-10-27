🇬🇧 **English** | 🇳🇱 Nederlands hieronder

# Contributing

Thanks for helping out! Issues and pull requests in English and Dutch are both welcome.

## Reporting a bug

1. Check the [existing issues](../../issues) first.
2. Open a [new issue](../../issues/new/choose) and choose **Bug report**.
3. Include:
   - the kit version (`VERSION`, or the top of the Builder) and whether you use the PowerShell script installer or the command line installer;
   - what you expected and what happened;
   - the relevant lines from `C:\ProgramData\AppUpdates\<AppId>\update.log`, and from `IntuneManagementExtension.log` if Intune is involved;
   - for Builder problems: the installer type (MSI, NSIS, Inno Setup, InstallShield, WiX or other).

**Remove data from your own tenant** before sharing logs or `app.psd1`: tenant IDs, device names, user names, internal paths and server names.

## Suggesting an idea

Open an issue with **Feature request** and describe the problem you want to solve, not only the solution.

## Pull requests

1. Fork the repository and create a branch with a clear name, such as `fix/postpone-reset`.
2. Make your change and **test it on a test device** through Intune, or at least with `install.cmd` as SYSTEM (for example with PsExec `-s`).
3. Keep everything compatible with **Windows PowerShell 5.1**; that is what Intune runs.
4. Update the documentation: [`README.md`](README.md) and the Dutch manual [`LEESMIJ.md`](LEESMIJ.md) where relevant, and add a line to [`CHANGELOG.md`](CHANGELOG.md).
5. Open a pull request and fill in the template.

### Guidelines

- Shared behaviour belongs in `_Kit\`, so every app gets it after a rebuild. Per-app settings belong in `app.psd1`.
- Don't break existing `app.psd1` files: add new settings with a sensible default.
- Never trust input in anything that runs as SYSTEM: quote paths, don't build commands from text with `Invoke-Expression`, and don't write to places a standard user can change.
- Texts the user sees go in `Standaardteksten.standaard.psd1`, so they can be translated and changed per app.
- No personal data or data from your own tenant in examples, screenshots or tests.

## Code of Conduct and licence

By contributing you agree to the [Code of Conduct](CODE_OF_CONDUCT.md) and to license your work under the [MIT License](LICENSE). Security problems go through [SECURITY.md](SECURITY.md), not a public issue.

---

# Bijdragen (Nederlands)

Leuk dat je wilt helpen! Meld een bug via een [nieuw issue](../../issues/new/choose) met de kitversie, wat je verwachtte en wat er gebeurde, en de regels uit `C:\ProgramData\AppUpdates\<AppId>\update.log`. Haal eerst gegevens uit je eigen tenant weg (tenant-ID's, apparaat- en gebruikersnamen, interne paden).

Voor een pull request: test op een testapparaat, houd alles compatibel met **Windows PowerShell 5.1**, werk `README.md`, `LEESMIJ.md` en `CHANGELOG.md` bij waar nodig, en voeg nieuwe instellingen toe met een standaardwaarde zodat bestaande `app.psd1`-bestanden blijven werken. Alles wat als SYSTEM draait, gaat zorgvuldig om met invoer. Beveiligingsproblemen meld je via [SECURITY.md](SECURITY.md).
