🇬🇧 **English** | 🇳🇱 Nederlands hieronder

# Security policy

## Supported versions

Only the latest release is supported. Update with **Update kit...** in the Builder (or `Update-Kit.cmd`) and rebuild your apps to get the fix into their packages.

## What to report

AppUpdateKit runs on managed laptops **as SYSTEM**, through Intune, and shows popups in the user's session. Please report anything that could let a user or another process abuse that, for example:

- a standard user being able to change what the SYSTEM install runs, such as files or folders under `C:\ProgramData\AppUpdates\`, `PostponeState.json`, the package cache, or the scripts the popups start;
- values from `app.psd1`, `Install.ps1` parameters or texts that end up executed as a command (command injection);
- the user-session popups being usable to run code as SYSTEM, or the other way round;
- the Builder or **Update kit** downloading or running files without checking where they come from;
- secrets, tokens or personal data ending up in logs (`update.log`, `BuildInfo.txt`) or in the built package.

Ordinary bugs without a security impact can go in a normal [issue](../../issues/new/choose).

## How to report

**Please don't open a public issue for a security problem.** Use **Report a vulnerability** on the [Security tab](../../security/advisories/new) of this repository. Only the maintainer can see your report.

Include the kit version (`VERSION`, or the top of the Builder), the file or setting involved, how to reproduce it and what the impact is. Leave out data from your own tenant, such as tenant IDs, device names and user names.

## What to expect

This is a project maintained in spare time. You'll get a first response within about a week. Confirmed issues are fixed as soon as possible in a new release and then disclosed, with credit if you'd like.

---

# Beveiligingsbeleid (Nederlands)

Alleen de laatste release wordt ondersteund. AppUpdateKit draait via Intune **als SYSTEM** op beheerde laptops. Meld daarom alles waarmee een gebruiker of ander proces dat zou kunnen misbruiken: schrijfbare bestanden of mappen die de SYSTEM-installatie gebruikt (zoals `C:\ProgramData\AppUpdates\`), instellingen of teksten die als opdracht worden uitgevoerd, de popups in de gebruikerssessie, downloads door de Builder of *Kit bijwerken*, en gevoelige gegevens in logboeken of pakketten.

**Meld een beveiligingsprobleem niet in een openbaar issue**, maar via **Report a vulnerability** op het tabblad [Security](../../security/advisories/new). Vermeld de kitversie, het bestand of de instelling, hoe je het kunt reproduceren en wat het gevolg is, zonder gegevens uit je eigen tenant. Je krijgt binnen ongeveer een week een reactie.
