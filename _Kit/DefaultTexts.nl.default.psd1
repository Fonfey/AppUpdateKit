#  ===========================================================================
#   STANDAARDTEKSTEN voor alle apps
#  ===========================================================================
#   Deze teksten gebruikt elke app, tenzij je in app.psd1 (of in de Builder,
#   tabblad Teksten) voor die app een eigen tekst invult.
#   Bewerken kan hier of in de Builder met de knop "Standaardteksten bewerken".
#   Na een wijziging: pakketten opnieuw bouwen.
#
#   Ingevuld worden: {AppName}, {Version}, {Minutes} en {MaxPostpones}
#  ===========================================================================
@{
    # Venster "Update beschikbaar" (Later / Nu bijwerken)
    ConsentSubHeading = 'Er is een update beschikbaar'
    ConsentMessage    = 'Versie {Version} van {AppName} staat voor je klaar. Tijdens de update (een paar minuten) kun je {AppName} even niet gebruiken.'

    # Waarschuwing na de laatste keer uitstellen (alleen "Nu installeren")
    ForcedSubHeading  = 'De update start over {Minutes} minuten'
    ForcedMessage     = 'Je hebt de update van {AppName} {MaxPostpones} keer uitgesteld. Over {Minutes} minuten wordt versie {Version} automatisch geïnstalleerd. Sla je werk op en sluit {AppName} af.'
    ForcedInfo        = 'Wil je niet wachten? Sla je werk op, sluit {AppName} af en klik op Nu installeren.'

    # Meldingen rechtsonder
    InstallingHeading = 'Update wordt geïnstalleerd'
    InstallingMessage = '{AppName} wordt bijgewerkt naar versie {Version} en is even niet beschikbaar. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    SuccessHeading    = 'Update geïnstalleerd'
    SuccessMessage    = '{AppName} is bijgewerkt naar versie {Version}. Je kunt de app weer gebruiken.'
    ErrorHeading      = 'Update niet gelukt'
    ErrorMessage      = 'Er ging iets mis bij het bijwerken van {AppName}. Werkt de app niet? Neem dan contact op met de servicedesk.'

    # Herstartmelding na de installatie (als RestartMode aan staat). {Minutes} = waarschuwingstijd voor de herstart
    RestartSubHeading       = 'Herstart nodig'
    RestartMessage          = '{AppName} is bijgewerkt. Herstart je laptop om de update af te ronden. Sla eerst je werk op.'
    RestartForcedSubHeading = 'Je laptop wordt over {Minutes} minuten herstart'
    RestartForcedMessage    = '{AppName} is bijgewerkt en je laptop moet herstarten om de update af te ronden. Sla je werk op en sluit je programma''s af.'

    # Meldingen bij het verwijderen (als UninstallNotify aan staat)
    UninstallingHeading   = '{AppName} wordt verwijderd'
    UninstallingMessage   = '{AppName} wordt van je laptop verwijderd en is even niet beschikbaar. Je hoeft niets te doen.'
    UninstalledHeading    = '{AppName} is verwijderd'
    UninstalledMessage    = '{AppName} staat niet meer op je laptop.'
    UninstallErrorHeading = 'Verwijderen niet gelukt'
    UninstallErrorMessage = 'Er ging iets mis bij het verwijderen van {AppName}. Geeft dit problemen? Neem dan contact op met de servicedesk.'

    # Nieuwe installatie: de app stond nog niet op de laptop (leeg = de teksten hierboven)
    NewConsentSubHeading    = 'Er staat een nieuwe app voor je klaar'
    NewConsentMessage       = '{AppName} wordt op je laptop geïnstalleerd. Dat duurt een paar minuten.'
    NewForcedSubHeading     = 'De installatie start over {Minutes} minuten'
    NewForcedMessage        = 'Je hebt de installatie van {AppName} {MaxPostpones} keer uitgesteld. Over {Minutes} minuten wordt {AppName} automatisch geïnstalleerd. Sla je werk op.'
    NewForcedInfo           = 'Wil je niet wachten? Sla je werk op en klik op Nu installeren.'
    NewInstallingHeading    = '{AppName} wordt geïnstalleerd'
    NewInstallingMessage    = '{AppName} wordt op je laptop geïnstalleerd. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    NewSuccessHeading       = '{AppName} is geïnstalleerd'
    NewSuccessMessage       = '{AppName} staat klaar. Je vindt de app in het startmenu.'
    NewErrorHeading         = 'Installatie niet gelukt'
    NewErrorMessage         = 'Er ging iets mis bij het installeren van {AppName}. Heb je de app nodig? Neem dan contact op met de servicedesk.'
    NewRestartMessage       = '{AppName} is geïnstalleerd. Herstart je laptop om de installatie af te ronden. Sla eerst je werk op.'
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programmas af.'
}
