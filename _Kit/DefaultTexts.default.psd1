#  ===========================================================================
#   DEFAULT TEXTS for all apps with Language = 'en'
#  ===========================================================================
#   Every English app uses these texts, unless you fill in its own text in
#   app.psd1 (or in the Builder, Texts tab) for that app.
#   Edit them here or in the Builder with the "Edit default texts" button.
#   After a change: rebuild the packages.
#
#   Filled in: {AppName}, {Version}, {Minutes} and {MaxPostpones}
#  ===========================================================================
@{
    # Window "Update available" (Later / Update now)
    ConsentSubHeading = 'An update is available'
    ConsentMessage    = 'Version {Version} of {AppName} is ready for you. During the update (a few minutes) you can''t use {AppName}.'

    # Warning after the last postpone (only "Install now")
    ForcedSubHeading  = 'The update starts in {Minutes} minutes'
    ForcedMessage     = 'You have postponed the {AppName} update {MaxPostpones} times. In {Minutes} minutes version {Version} will be installed automatically. Save your work and close {AppName}.'
    ForcedInfo        = 'Don''t want to wait? Save your work, close {AppName} and click Install now.'

    # Notifications bottom right
    InstallingHeading = 'Installing update'
    InstallingMessage = '{AppName} is being updated to version {Version} and is unavailable for a moment. You don''t need to do anything; we''ll let you know when it''s done.'
    SuccessHeading    = 'Update installed'
    SuccessMessage    = '{AppName} has been updated to version {Version}. You can use the app again.'
    ErrorHeading      = 'Update failed'
    ErrorMessage      = 'Something went wrong while updating {AppName}. Is the app not working? Please contact the service desk.'

    # Restart prompt after the installation (if RestartMode is on). {Minutes} = warning time before the restart
    RestartSubHeading       = 'Restart required'
    RestartMessage          = '{AppName} has been updated. Restart your laptop to finish the update. Save your work first.'
    RestartForcedSubHeading = 'Your laptop will restart in {Minutes} minutes'
    RestartForcedMessage    = '{AppName} has been updated and your laptop needs to restart to finish the update. Save your work and close your programs.'

    # Notifications when uninstalling (if UninstallNotify is on)
    UninstallingHeading   = 'Removing {AppName}'
    UninstallingMessage   = '{AppName} is being removed from your laptop and is unavailable for a moment. You don''t need to do anything.'
    UninstalledHeading    = '{AppName} has been removed'
    UninstalledMessage    = '{AppName} is no longer on your laptop.'
    UninstallErrorHeading = 'Removal failed'
    UninstallErrorMessage = 'Something went wrong while removing {AppName}. Is this causing problems? Please contact the service desk.'

    # New installation: the app was not on the laptop yet (empty = the texts above)
    NewConsentSubHeading    = 'A new app is ready for you'
    NewConsentMessage       = '{AppName} will be installed on your laptop. This takes a few minutes.'
    NewForcedSubHeading     = 'The installation starts in {Minutes} minutes'
    NewForcedMessage        = 'You have postponed the installation of {AppName} {MaxPostpones} times. In {Minutes} minutes {AppName} will be installed automatically. Save your work.'
    NewForcedInfo           = 'Don''t want to wait? Save your work and click Install now.'
    NewInstallingHeading    = 'Installing {AppName}'
    NewInstallingMessage    = '{AppName} is being installed on your laptop. You don''t need to do anything; we''ll let you know when it''s done.'
    NewSuccessHeading       = '{AppName} has been installed'
    NewSuccessMessage       = '{AppName} is ready. You can find the app in the Start menu.'
    NewErrorHeading         = 'Installation failed'
    NewErrorMessage         = 'Something went wrong while installing {AppName}. Do you need the app? Please contact the service desk.'
    NewRestartMessage       = '{AppName} has been installed. Restart your laptop to finish the installation. Save your work first.'
    NewRestartForcedMessage = '{AppName} has been installed and your laptop needs to restart to finish the installation. Save your work and close your programs.'
}
