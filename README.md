# AppUpdateKit

Intune Win32-pakketten voor app-updates, met nette popups voor de gebruiker: eerst toestemming vragen, uitstellen toestaan, een waarschuwing met aftelklok en meldingen tijdens en na de installatie.

> 📖 Uitleg met screenshots op mijn blog: [AppUpdateKit: app-updates via Intune met een nette popup](https://fonferek.cloud/blog/appupdatekit-app-updates-met-popup-in-intune/).

## Aan de slag

1. Download deze repository (*Code* → *Download ZIP*) en pak hem uit, bijvoorbeeld naar `C:\AppUpdateKit`.
2. Haal de downloadblokkade weg, in PowerShell: `Get-ChildItem C:\AppUpdateKit -Recurse | Unblock-File`
3. Dubbelklik op **`Start-Builder.cmd`**. De eerste keer vraagt de Builder om een standaardmap voor je installers.

De volledige uitleg staat in **[LEESMIJ.md](LEESMIJ.md)**.

## Wat zit erin

| Map of bestand | Wat |
|---|---|
| `Start-Builder.cmd` / `AppUpdateKit-Builder.ps1` | De Builder: apps invullen, popups bekijken en het `.intunewin`-pakket bouwen |
| `1-Nieuwe-app.ps1`, `2-Bouw-pakket.ps1` | Hetzelfde zonder Builder, vanuit PowerShell |
| `_Kit\` | De vaste scripts voor elk pakket (popups, Intune-scripts) en `Instellingen.psd1` |
| `_Template\` | Het sjabloon voor een nieuwe app |
| `Apps\`, `Output\` | Leeg: hier komen je apps en gebouwde pakketten |
