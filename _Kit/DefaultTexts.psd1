#  ===========================================================================
#   STANDARD TEXTS  -  for all apps
#  ===========================================================================
#   Every app uses these texts unless you enter its own text (Builder, Texts tab).
#   Dutch at the top, English under "En". Users get English when their Windows is
#   English. After a change: rebuild the packages.
#
#   Dutch texts  : {AppName}, {Versie}, {Minuten}, {MaxUitstel}
#   English texts: {AppName}, {Version}, {Minutes}, {MaxPostpones}  (both forms work)
#  ===========================================================================
@{

    # "Update available" window (Later / Update now)
    ConsentSubHeading       = 'Er is een update beschikbaar'
    ConsentMessage          = 'Versie {Versie} van {AppName} staat voor je klaar. Tijdens de update (een paar minuten) kun je {AppName} even niet gebruiken.'

    # Warning after the last postpone
    ForcedSubHeading        = 'De update start over {Minuten} minuten'
    ForcedMessage           = 'Je hebt de update van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt versie {Versie} automatisch geïnstalleerd. Sla je werk op en sluit {AppName} af.'
    ForcedInfo              = 'Wil je niet wachten? Sla je werk op, sluit {AppName} af en klik op Nu installeren.'

    # Notifications bottom right
    InstallingHeading       = 'Update wordt geïnstalleerd'
    InstallingMessage       = '{AppName} wordt bijgewerkt naar versie {Versie} en is even niet beschikbaar. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    SuccessHeading          = 'Update geïnstalleerd'
    SuccessMessage          = '{AppName} is bijgewerkt naar versie {Versie}. Je kunt de app weer gebruiken.'
    ErrorHeading            = 'Update niet gelukt'
    ErrorMessage            = 'Er ging iets mis bij het bijwerken van {AppName}. Werkt de app niet? Neem dan contact op met de servicedesk.'

    # Restart prompt ({Minuten} = warning time)
    RestartSubHeading       = 'Herstart nodig'
    RestartMessage          = '{AppName} is bijgewerkt. Herstart je laptop om de update af te ronden. Sla eerst je werk op.'
    RestartForcedSubHeading = 'Je laptop wordt over {Minuten} minuten herstart'
    RestartForcedMessage    = '{AppName} is bijgewerkt en je laptop moet herstarten om de update af te ronden. Sla je werk op en sluit je programma''s af.'

    # Notifications when removing
    UninstallingHeading     = '{AppName} wordt verwijderd'
    UninstallingMessage     = '{AppName} wordt van je laptop verwijderd en is even niet beschikbaar. Je hoeft niets te doen.'
    UninstalledHeading      = '{AppName} is verwijderd'
    UninstalledMessage      = '{AppName} staat niet meer op je laptop.'
    UninstallErrorHeading   = 'Verwijderen niet gelukt'
    UninstallErrorMessage   = 'Er ging iets mis bij het verwijderen van {AppName}. Geeft dit problemen? Neem dan contact op met de servicedesk.'

    # New installation (app was not on the device yet)
    NewConsentSubHeading    = 'Er staat een nieuwe app voor je klaar'
    NewConsentMessage       = '{AppName} wordt op je laptop geïnstalleerd. Dat duurt een paar minuten.'
    NewForcedSubHeading     = 'De installatie start over {Minuten} minuten'
    NewForcedMessage        = 'Je hebt de installatie van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt {AppName} automatisch geïnstalleerd. Sla je werk op.'
    NewForcedInfo           = 'Wil je niet wachten? Sla je werk op en klik op Nu installeren.'
    NewInstallingHeading    = '{AppName} wordt geïnstalleerd'
    NewInstallingMessage    = '{AppName} wordt op je laptop geïnstalleerd. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    NewSuccessHeading       = '{AppName} is geïnstalleerd'
    NewSuccessMessage       = '{AppName} staat klaar. Je vindt de app in het startmenu.'
    NewErrorHeading         = 'Installatie niet gelukt'
    NewErrorMessage         = 'Er ging iets mis bij het installeren van {AppName}. Heb je de app nodig? Neem dan contact op met de servicedesk.'
    NewRestartMessage       = '{AppName} is geïnstalleerd. Herstart je laptop om de installatie af te ronden. Sla eerst je werk op.'
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programma''s af.'

    # ======================= English =======================
    En = @{

        # "Update available" window (Later / Update now)
        ConsentSubHeading       = 'An update is available'
        ConsentMessage          = 'A new version of {AppName} is ready for you. During the update (a few minutes) you cannot use {AppName}.'

        # Warning after the last postpone
        ForcedSubHeading        = 'The update starts in {Minutes} minutes'
        ForcedMessage           = 'You have postponed the update of {AppName} {MaxPostpones} times. In {Minutes} minutes the new version will be installed automatically. Save your work and close {AppName}.'
        ForcedInfo              = 'Do not want to wait? Save your work, close {AppName} and click Install now.'

        # Notifications bottom right
        InstallingHeading       = 'Installing update'
        InstallingMessage       = '{AppName} is being updated and is briefly unavailable. You do not need to do anything; we will let you know when it is done.'
        SuccessHeading          = 'Update installed'
        SuccessMessage          = 'The new version of {AppName} is ready. You can use the app again.'
        ErrorHeading            = 'Update failed'
        ErrorMessage            = 'Something went wrong while updating {AppName}. Is the app not working? Please contact the service desk.'

        # Restart prompt ({Minutes} = warning time)
        RestartSubHeading       = 'Restart required'
        RestartMessage          = '{AppName} has been updated. Restart your laptop to finish the update. Save your work first.'
        RestartForcedSubHeading = 'Your laptop will restart in {Minutes} minutes'
        RestartForcedMessage    = '{AppName} has been updated and your laptop needs to restart to finish the update. Save your work and close your programs.'

        # Notifications when removing
        UninstallingHeading     = 'Removing {AppName}'
        UninstallingMessage     = '{AppName} is being removed from your laptop and is briefly unavailable. You do not need to do anything.'
        UninstalledHeading      = '{AppName} has been removed'
        UninstalledMessage      = '{AppName} is no longer on your laptop.'
        UninstallErrorHeading   = 'Removal failed'
        UninstallErrorMessage   = 'Something went wrong while removing {AppName}. Does this cause problems? Please contact the service desk.'

        # New installation (app was not on the device yet)
        NewConsentSubHeading    = 'A new app is ready for you'
        NewConsentMessage       = '{AppName} will be installed on your laptop. This takes a few minutes.'
        NewForcedSubHeading     = 'The installation starts in {Minutes} minutes'
        NewForcedMessage        = 'You have postponed the installation of {AppName} {MaxPostpones} times. In {Minutes} minutes {AppName} will be installed automatically. Save your work.'
        NewForcedInfo           = 'Do not want to wait? Save your work and click Install now.'
        NewInstallingHeading    = 'Installing {AppName}'
        NewInstallingMessage    = '{AppName} is being installed on your laptop. You do not need to do anything; we will let you know when it is done.'
        NewSuccessHeading       = '{AppName} has been installed'
        NewSuccessMessage       = '{AppName} is ready. You can find the app in the Start menu.'
        NewErrorHeading         = 'Installation failed'
        NewErrorMessage         = 'Something went wrong while installing {AppName}. Do you need the app? Please contact the service desk.'
        NewRestartMessage       = '{AppName} has been installed. Restart your laptop to finish the installation. Save your work first.'
        NewRestartForcedMessage = '{AppName} has been installed and your laptop needs to restart to finish the installation. Save your work and close your programs.'
    }
}
