# AppUpdateKit – update-pakketten met popup, voor elke app

*English: see [README.md](README.md).*

Elke app krijgt dezelfde vensters als Omnissa:
- **"Update beschikbaar"** rechtsonder, met het logo van de app en de knoppen *Later* / *Nu bijwerken*.
- **Na de laatste keer uitstellen**: een waarschuwing "De update start over 5 minuten", met aftelklok en alleen de knop *Nu installeren*.
- **Melding tijdens de installatie** met voortgangsbalk.
- **Melding na afloop**: "geïnstalleerd" (groen) of "niet gelukt" (rood).

## De makkelijkste manier: de Builder

Eenmalig na het uitpakken, in PowerShell: `Get-ChildItem C:\AppUpdateKit -Recurse | Unblock-File`

Dubbelklik daarna op **`Start-Builder.cmd`**. Na de eerste keer kun je ook de snelkoppeling **AppUpdateKit Builder** gebruiken.

1. Klik op **+ Nieuwe app** en geef een AppId op (bijv. `7Zip`). Of kies links een bestaande app.
2. **Tabblad 1 – Basis.** Klik op *Kiezen...* bij Installer. Naam, versie, type (MSI/NSIS/Inno) en stille parameters worden herkend en ingevuld. Vul daarna de processen in en kies een logo en een kleur. Het logo mag een `.svg`, `.png`, `.jpg` of `.ico` zijn. Een SVG wordt met Microsoft Edge omgezet naar een scherp icoon van 256×256, en het origineel blijft als `logo.svg` in de app-map bewaard.
3. **Tabblad 2 – Installatie.**
   - **Onderdelen:** alles wat in dit pakket geïnstalleerd wordt, in volgorde. Bijvoorbeeld eerst een runtime, dan de app. Per onderdeel stel je eigen **parameters** in en de **exitcodes die als geslaagd tellen**. Wijzigen doe je door te dubbelklikken. Het hoofdonderdeel is de app zelf. Mislukt een onderdeel, dan stopt de installatie en krijgt de gebruiker "Update niet gelukt".
   - **Extra stappen vóór en na** de onderdelen, bijvoorbeeld snelkoppelingen of een configuratiebestand kopiëren.
   - Hieruit wordt `install-app.cmd` automatisch gemaakt. Wil je alles met de hand schrijven, zet dan *automatisch maken* uit.
4. **Tabblad 3 – Teksten.** Vul eigen teksten in of laat ze leeg. Met de voorbeeldknoppen zie je elke popup rechtsonder op je scherm; er wordt niets geïnstalleerd.
5. **Tabblad 4 – Uitstellen.** Hoe vaak, hoe lang en hoeveel minuten waarschuwing. Onder *Wanneer mag de update komen?* stel je in:
   - **Tijdvenster:** *altijd*, *alleen binnen werktijd* of *alleen buiten werktijd* (avond, nacht, weekend), met eigen tijden en werkdagen. Buiten het venster komt er geen popup en geen installatie. Intune probeert het bij een volgende controle opnieuw, dus de update start niet precies op de minuut.
   - **Inactief:** direct installeren, zonder popup, als de gebruiker een aantal minuten niets doet of het scherm vergrendeld is. Staat de app open, dan wacht de installatie gewoon.
   - **Niemand ingelogd:** direct installeren (ook buiten het venster; nodig voor Autopilot) of wachten tot er iemand is ingelogd.
   - **Herstart na de installatie:** *nooit*, *alleen als de installer erom vraagt* (exitcode 3010/1641) of *altijd*. De gebruiker krijgt een venster met **Nu herstarten** en **Later**:
     - *Later* betekent dat de melding na een ingesteld aantal minuten terugkomt.
     - Na de deadline (bijvoorbeeld 24 uur) volgt een waarschuwing met aftelklok, en daarna wordt de laptop herstart.
     - Is niemand ingelogd, dan herstart de laptop direct.
     - Intune krijgt dan exitcode 0, zodat er geen tweede herstartmelding komt.
     - Tijdens Autopilot regelt de inrichtingspagina de herstart.
     - De herinnering is een geplande taak (*AppUpdateKit Herstart <AppId>*), die zichzelf opruimt na de herstart.
   - **Verwijderen:** met *Meldingen tonen als de app via Intune wordt verwijderd* ziet de gebruiker rechtsonder "… wordt verwijderd", en daarna "… is verwijderd" (groen) of "Verwijderen niet gelukt" (rood). Standaard staat dit uit. De teksten pas je aan in tabblad 3. Bij de PowerShell-installer zet je het ook aan of uit met `$Notify` in `Uninstall.ps1`. Bij het verwijderen worden de teller, de instellingen en een eventuele herstartherinnering opgeruimd; `update.log` blijft staan.
6. Klik op **Bouw pakket**. De eerste keer vraagt de Builder om IntuneWinAppUtil.exe van Microsoft te downloaden. Daarna staat `install.intunewin` klaar in `Output\<AppId>\<versie>\`, samen met de Intune-scripts en een lijst met instellingen.
7. **Tabblad 5 – Versies.** Alle builds blijven bewaard, met een volledige kopie (ook de installers). Bouw je een versie opnieuw, dan gaat de vorige build van die versie naar het archief en staat hij in de lijst als "(vervangen)". Klik op een build om te zien hoe die gemaakt is: instellingen, onderdelen, stappen, teksten, bouwinfo en wat er anders is dan nu. Met *Voorbeeld van deze versie* zie je de popups van toen.
   - **Kopie maken en aanpassen:** zet een volledige kopie van de gekozen build klaar als werkversie, ook van een oudere of gearchiveerde build. Pas alleen aan wat nodig is en bouw opnieuw:
     - **zelfde versienummer** = die versie verbeteren (de vorige build gaat naar het archief);
     - **nieuwe installer of nieuw versienummer** = een nieuwe versie.

**Snelkoppeling met eigen icoon:** bij elke start maakt de Builder in de kit-map de snelkoppeling **AppUpdateKit Builder**, met een eigen icoon. Sleep die naar je bureaublad of taakbalk.

**In Intune na een fix van dezelfde versie:** open de bestaande app → *Properties* → *App information* → *Edit* → *Select file to update* en kies de nieuwe `install.intunewin`. Een **nieuwe versie** voeg je toe als nieuwe Win32-app, met supersedence op de vorige.

**Nieuwe versie van een app?** Kies in tabblad 1 de nieuwe installer. De Builder vult de nieuwe versie in en biedt aan de oude installer uit de app-map te halen. Pas eventueel de teksten aan en klik op *Bouw pakket*. De vorige versie blijft gewoon bewaard.

**Standaardteksten voor alle apps** bewerk je in tabblad 3 met *Standaardteksten voor alle apps bewerken...*. Ze staan in `_Kit\Standaardteksten.psd1`. Een eigen tekst bij een app gaat altijd voor.

Alles wat de Builder doet, kun je ook met de hand doen. Dat staat hieronder.

## PowerShell-installer in Intune (aanbevolen)

Elke build maakt naast `install.intunewin` ook **`Intune\Install.ps1`** en **`Intune\Uninstall.ps1`**. Die upload je los in Intune:
*Program* → *Installer type*: **PowerShell script** → *Install script* en *Uninstall script* (32-bit: No, signature check: No).

Het voordeel: de instellingen, teksten, installatieparameters en extra stappen staan in dat script, niet in het pakket. Pas je daar iets aan, dan doe je dat direct in Intune, zonder opnieuw te verpakken. Opnieuw verpakken is alleen nodig bij een nieuwe installer, een ander logo of een nieuwe kit-versie.

Bovenaan `Install.ps1` staat wat je mag aanpassen:
1. **Schakelaars:** `$NoProcessCheck` (geen procescheck), `$NoPopup` (geen popup) en `$Silent` (geen popup en geen meldingen), plus eigen schakelaars in `$Switches`, zoals `NOSHORTCUTS` voor Omnissa.
2. **Instellingen en teksten** in `$App`: zelfde velden als `app.psd1`, met `Texts` (Nederlands) en `TextsEn` (Engels).
3. **Installatiestappen** in `$Components`: per onderdeel de opdrachtregel (`Command`) en de exitcodes die als gelukt tellen (`SuccessCodes`), plus de extra cmd-regels in `$PreInstall` en `$PostInstall`.

Let op:
- Een wijziging die je alleen in Intune doet, staat niet in de Builder. Neem hem daar ook over, anders is hij bij de volgende build weg.
- Processen, tijdvenster en Autopilot staan ook in `Requirement.ps1`. Pas je die aan, doe het dan in beide scripts.
- Het script mag maximaal 50 KB zijn; de build waarschuwt als het groter wordt.
- `install.cmd` werkt nog steeds als *Command line*-installer, met de parameters hieronder.

## Parameters in Intune (Command line-installer)

Achter `install.cmd` kun je in Intune parameters zetten, bijvoorbeeld `install.cmd /noshortcuts /noprocesscheck`. Combineren mag.

| Parameter | Wat het doet |
|---|---|
| `/noprocesscheck` | Niet controleren of de app open staat. Upload dan **`Intune\Requirement-zonder-procescheck.ps1`** als requirement-script, anders houdt het gewone script de installatie nog tegen. De installer moet zelf met een open app om kunnen gaan. |
| `/noconsent` | Geen popup, direct installeren. De meldingen rechtsonder blijven. |
| `/silent` | Geen popup en geen meldingen. |
| `/<eigen naam>` | Beschikbaar in `install-app.cmd` als `APP_<NAAM>`. Bijvoorbeeld `/noshortcuts` geeft `APP_NOSHORTCUTS`. |

Een stap overslaan met een eigen parameter (in *Extra stappen* of in `install-app.cmd`):
```
if defined APP_NOSHORTCUTS goto na_snelkoppelingen
... stappen voor de snelkoppelingen ...
:na_snelkoppelingen
```
Welke parameters een app gebruikt, staat in `Intune-instellingen.txt`. De parameters staan ook in `update.log`.

Wil je hetzelfde pakket met verschillende parameters gebruiken, bijvoorbeeld zonder snelkoppelingen voor een bepaalde groep? Maak dan in Intune een tweede Win32-app met hetzelfde `install.intunewin` en een ander install command.

## Nieuwe laptops via Autopilot

Staat **Installeren op nieuwe laptops (Autopilot)** aan in tabblad 1 (standaard aan), dan herkent het pakket dat een laptop nog wordt ingericht. Het kijkt daarvoor of de Windows-installatie (OOBE) nog loopt en of de inrichtingspagina (ESP) nog bezig is voor de gebruiker die inlogt. Dit zijn dezelfde controles als in PSAppDeployToolkit 4. Tijdens de inrichting:
- wordt de app direct geïnstalleerd, zonder popup of meldingen;
- tellen *alleen bijwerken waar de app al staat*, het tijdvenster en uitstellen niet.

Zo heb je één app in Intune voor zowel de updates als nieuwe laptops.

In Intune:
1. Wijs de app **Required** toe aan een **apparaatgroep** met de Autopilot-laptops, bijvoorbeeld een dynamische groep op `ZTDId`. Dan installeert hij al in de apparaatfase.
2. Moet de app er staan voordat de gebruiker kan werken? Zet hem in het ESP-profiel bij **Block device use until these required apps are installed**.
3. Let bij grote pakketten op de ESP-time-out (standaard 60 minuten).

Staat de optie uit, dan slaat het pakket de inrichting over en komt de app daarna gewoon, met popup.

## Zonder Builder: een nieuwe app in 4 stappen

```powershell
# 1. Nieuwe app-map maken vanuit het sjabloon
.\1-Nieuwe-app.ps1 -AppId 7Zip -AppName '7-Zip'
```

2. **Vul `Apps\7Zip\` aan:**
   - `app.psd1`: versie, processen, kleur, uitstelregels en teksten. Elk veld heeft uitleg erbij.
   - `app.ico`: het logo.
   - De installer(s) en eventuele extra bestanden (config, scripts, snelkoppelingen).
   - `install-app.cmd`: je installatiestappen met hun parameters. Voorbeelden voor MSI, NSIS, Inno en andere installers staan in het bestand.
   - `uninstall-app.cmd`: je verwijderstappen. Lukt verwijderen via de setup.exe niet (exitcode 1605, zoals bij Omnissa), gebruik dan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "<naam in Apps en onderdelen>"`. Dat zoekt de app op en verwijdert hem via de MSI-productcode of het eigen verwijderprogramma.

```powershell
# 3. Pakket bouwen (controleert ook of alles klopt)
.\2-Bouw-pakket.ps1 -App 7Zip
```

4. **Uploaden in Intune.** Alles staat in `Output\7Zip\<versie>\`:

| Bestand | Wat ermee doen |
|---|---|
| `<versie>\install.intunewin` | Uploaden als Win32-app. Wordt alleen automatisch gemaakt als `IntuneWinAppUtil.exe` naast de scripts staat. |
| `Intune\Requirement.ps1` | Uploaden bij *Requirements* (Output: String, Equals, `Voldaan`) |
| `Intune\Detection.ps1` | Uploaden bij *Detection rules* |
| `Intune-instellingen.txt` | Alle overige instellingen op een rij |
| `Bron\` en `Bouwinfo.txt` | De instellingen, teksten en het logo van deze versie, plus wanneer en door wie hij gebouwd is en de SHA-256 van elk bestand |

## Wat je per app invult, en wat niet

| Per app (in `Apps\<AppId>\`) | Hetzelfde voor elke app (in `_Kit\`) |
|---|---|
| `app.psd1`: gegevens, logo, kleur, teksten | De vensters (`AppUI.ps1`) |
| `install-app.cmd` / `uninstall-app.cmd` | Procescheck, toestemming, uitstellen, waarschuwing |
| Installers, logo, eigen bestanden | `install.cmd` / `uninstall.cmd` (roepen jouw `-app.cmd` aan) |
| | Requirement- en detectiescript |

Pas je iets aan in `_Kit\`, bijvoorbeeld de vormgeving, dan bouw je de apps opnieuw met `2-Bouw-pakket.ps1` en krijgen ze allemaal de wijziging.

## Nederlands en Engels

De kit werkt in twee talen.

- **De Builder en de gemaakte bestanden.** Kies rechtsboven in de Builder *Nederlands* of *English*. De Builder start dan opnieuw in die taal. Dezelfde taal geldt voor de meldingen, de logbestanden (`update.log`), de commentaren in `Install.ps1` en de andere scripts, `Intune-instellingen.txt` en nieuwe apps uit het sjabloon. De keuze staat in `_Kit\Settings.psd1` (`Language = 'nl'` of `'en'`). Zonder Builder geef je de taal mee met `-Lang en`, bijvoorbeeld `.\2-Bouw-pakket.ps1 -App 7Zip -Lang en`.
- **De popups voor gebruikers** volgen de Windows-taal van de gebruiker die is ingelogd: Engelse Windows geeft Engelse popups, elke andere taal Nederlands. Wil je dat niet, kies dan in tabblad 1 bij *Taal van de popups* voor *Altijd Nederlands* of *Altijd Engels* (`PopupLanguage` in `app.psd1`: `Auto`, `nl` of `en`).
- **Engelse teksten** vul je in tabblad 3 in: kies bij *Teksten en voorbeelden in* voor *Engels*. Ze staan in `app.psd1` onder `TextsEn`. Een leeg veld betekent: de Engelse standaardtekst. De Engelse standaardteksten staan in `_Kit\Standaardteksten.psd1` onder `En`. Met de voorbeeldknoppen zie je de popups in de gekozen taal.

De vaste waarden in de bestanden blijven Nederlands, in beide talen: `Altijd`, `Werktijd`, `BuitenWerktijd`, `Nooit`, `AlsNodig`, `Installeren`, `Wachten`, de werkdagen `ma,di,wo,do,vr` en de requirement-uitkomst `Voldaan`. De bestandsnamen blijven ook gelijk.

## Teksten
- **Standaardteksten voor alle apps** staan in `_Kit\Standaardteksten.psd1`. Je bewerkt ze in de Builder of met de hand.
- **Per app en versie** vul je eigen teksten in onder `Texts` (Nederlands) en `TextsEn` (Engels) in `app.psd1`, of in de Builder (tabblad 3). Een leeg veld (`''`) betekent: de standaardtekst gebruiken.

**Nieuwe installatie of update?** Voor de installatie kijkt het pakket of de app al in "Apps en onderdelen" staat (de naam bij *Apps en onderdelen* in tabblad 1). Staat hij er nog niet, dan gaan de vensters over een **installatie**: "Er staat een nieuwe app voor je klaar", de knop "Nu installeren" en de melding "… is geïnstalleerd". Staat hij er al, dan gaan ze over een **update**. De teksten voor een nieuwe installatie staan onderaan in tabblad 3 ("Nieuwe installatie - ..."). Met *Voorbeelden tonen als nieuwe installatie* zie je hoe ze eruitzien.

Deze woorden worden automatisch ingevuld:
- `{AppName}`: de naam van de app
- `{Versie}`: de versie van dit pakket
- `{Minuten}`: hoeveel minuten waarschuwing vooraf
- `{MaxUitstel}`: hoe vaak je mag uitstellen

In de Engelse teksten gebruik je `{Version}`, `{Minutes}` en `{MaxPostpones}`. Beide vormen werken in beide talen.

## Beginnen
`Apps\` en `Output\` zijn leeg. Maak je eerste app met **+ Nieuwe app** in de Builder, of met `.\1-Nieuwe-app.ps1`. Gebouwde pakketten komen in `Output\`.

## Testen op een laptop
- Log en teller per app: `C:\ProgramData\AppUpdates\<AppId>\` (`update.log`, `PostponeState.json`).
- Waarschuwing van 5 minuten direct testen: zet `PostponeCount` op 5 en `PostponeUntil` in het verleden, en voer in een admin-PowerShell in de pakketmap `.\Ask-InstallConsent.ps1` uit.
- Teller resetten: verwijder `PostponeState.json`.
- Tijdvenster en inactief: in `update.log` staat per keer waarom er wel of geen popup kwam, bijvoorbeeld "Buiten het tijdvenster" of "15 minuten inactief". Om het inactief-zijn te testen: zet *Inactief* op 1 minuut, vergrendel het scherm (Windows-toets + L) en start de installatie vanuit de Bedrijfsportal of met `.\install.cmd`.
