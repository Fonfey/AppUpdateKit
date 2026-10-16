<#
.SYNOPSIS
    Shows the update popups to the logged-on user (runs AS the user). Do NOT edit per app.

.DESCRIPTION
    Started by AppUI-Launcher.ps1 (running as SYSTEM) through a scheduled task.
    All texts and settings come from a JSON file (-ConfigPath), so no text has to be pasted
    into a script (no trouble with quotes or accented characters).

    Mode 'consent' : "Update available" window with the buttons Later / Update now.
                     Writes 'Yes', 'No' or 'Timeout' to ResponsePath.
    Mode 'forced'  : same window without "Later": the update starts after the countdown,
                     or earlier with "Install now". Writes 'Yes' or 'Timeout'.
    Mode 'toast'   : notification in the bottom-right corner, Windows 11 style.
                     Type: info | installing | success | error
    Lang           : 'nl' or 'en' (language of the built-in button and helper texts)
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

$cfg = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

function T([string]$Nl, [string]$En)
{
    # Built-in texts in the user's language
    if ($cfg.Lang -eq 'en') { return $En } else { return $Nl }
}

# Colour of the header and the main button (AccentColor in app.psd1)
$accent = if ($cfg.AccentColor -match '^#[0-9A-Fa-f]{6}$') { $cfg.AccentColor } else { '#185FA5' }

function Write-PopupLog
{
    param ([string]$Text)
    if (-not $cfg.LogPath) { return }
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [popup] $Text"
    Add-Content -Path $cfg.LogPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Set-Response
{
    param ([string]$Value)
    if ($cfg.ResponsePath)
    {
        [System.IO.File]::WriteAllText($cfg.ResponsePath, $Value, (New-Object System.Text.UTF8Encoding $false))
    }
}

function Get-Brush
{
    param ([string]$Hex)
    return (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Hex)
}

function Set-Icon
{
    param ($ImageControl)
    if ($cfg.IconPath -and (Test-Path $cfg.IconPath))
    {
        try { $ImageControl.Source = New-Object System.Windows.Media.Imaging.BitmapImage ([uri]$cfg.IconPath) } catch { }
    }
}

# Shared button style (rounded corners)
$buttonStyle = @'
<Style x:Key="Btn" TargetType="Button">
  <Setter Property="Padding" Value="18,8"/>
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="FontSize" Value="14"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.85"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.7"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
'@

##================================================
## Consent window: "Update available"
##================================================
$consentXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Update" Width="500" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" Topmost="True" ShowInTaskbar="True" ShowActivated="False"
        WindowStartupLocation="Manual" Left="-10000" Top="-10000" Opacity="0"
        FontFamily="Segoe UI" FontSize="14">
  <Window.Resources>
    $buttonStyle
  </Window.Resources>
  <Border Margin="16" CornerRadius="10" Background="#FFFFFF" BorderBrush="#C8C8C8" BorderThickness="1">
    <Border.Effect><DropShadowEffect BlurRadius="20" ShadowDepth="3" Opacity="0.28"/></Border.Effect>
    <StackPanel>
      <Border Name="Header" Background="$accent" CornerRadius="9,9,0,0" Padding="20,16">
        <DockPanel>
          <Border Width="52" Height="52" CornerRadius="10" Background="#FFFFFF" Margin="0,0,14,0">
            <Image Name="Icon" Width="38" Height="38"/>
          </Border>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Name="Heading" Foreground="#FFFFFF" FontSize="19" FontWeight="SemiBold"/>
            <TextBlock Name="SubHeading" Foreground="#D6E6F7" FontSize="13" Margin="0,2,0,0"/>
          </StackPanel>
        </DockPanel>
      </Border>
      <StackPanel Margin="22,18,22,20">
        <TextBlock Name="Message" TextWrapping="Wrap" Foreground="#1F1F1F" LineHeight="21"/>
        <Border Name="InfoBox" CornerRadius="6" Padding="12,10" Margin="0,14,0,0" Background="#E6F1FB">
          <DockPanel>
            <TextBlock Name="InfoGlyph" FontFamily="Segoe MDL2 Assets" FontSize="16" Margin="0,1,10,0" Foreground="$accent" Text="&#xE946;"/>
            <TextBlock Name="InfoText" TextWrapping="Wrap" Foreground="#0C447C" FontSize="13" LineHeight="19"/>
          </DockPanel>
        </Border>
        <TextBlock Name="Countdown" Foreground="#6B6B6B" FontSize="12" Margin="0,12,0,0" TextWrapping="Wrap"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
          <Button Name="BtnLater" Style="{StaticResource Btn}" Background="#FFFFFF" BorderBrush="#B0B0B0"
                  BorderThickness="1" Foreground="#1F1F1F" Content="Later" Margin="0,0,10,0"/>
          <Button Name="BtnNow" Style="{StaticResource Btn}" Background="$accent" BorderBrush="$accent"
                  BorderThickness="1" Foreground="#FFFFFF" Content="Nu bijwerken"/>
        </StackPanel>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
"@

##================================================
## Toast notification, bottom right
##================================================
$toastXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Melding" Width="410" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" Topmost="True" ShowInTaskbar="False" ShowActivated="False"
        WindowStartupLocation="Manual" Left="-10000" Top="-10000" Opacity="0"
        FontFamily="Segoe UI">
  <Window.Resources>
    $buttonStyle
  </Window.Resources>
  <Border Margin="12" CornerRadius="8" Background="#2B2B2B" BorderBrush="#454545" BorderThickness="1" Padding="16,12,16,16">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.4"/></Border.Effect>
    <StackPanel>
      <DockPanel Margin="0,0,0,12">
        <Button Name="BtnX" DockPanel.Dock="Right" Style="{StaticResource Btn}" Padding="6,4" Background="Transparent"
                BorderThickness="0" Foreground="#C8C8C8" FontFamily="Segoe MDL2 Assets" FontSize="10"
                Content="&#xE711;" ToolTip="Sluiten"/>
        <Image Name="SmallIcon" Width="16" Height="16" Margin="0,0,8,0" VerticalAlignment="Center"/>
        <TextBlock Name="Sender" Foreground="#C8C8C8" FontSize="12" VerticalAlignment="Center"/>
      </DockPanel>
      <DockPanel>
        <Grid Width="48" Height="48" Margin="0,0,14,0" VerticalAlignment="Top">
          <Image Name="Icon" Width="48" Height="48"/>
          <Border Name="Badge" Width="22" Height="22" CornerRadius="11" HorizontalAlignment="Right" VerticalAlignment="Bottom"
                  Margin="0,0,-5,-5" BorderBrush="#2B2B2B" BorderThickness="2" Background="#378ADD">
            <TextBlock Name="BadgeGlyph" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#FFFFFF"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
        </Grid>
        <StackPanel>
          <TextBlock Name="Heading" Foreground="#FFFFFF" FontSize="14" FontWeight="SemiBold" TextWrapping="Wrap"/>
          <TextBlock Name="Message" Foreground="#D0D0D0" FontSize="13" TextWrapping="Wrap" Margin="0,4,0,0" LineHeight="19"/>
          <ProgressBar Name="Progress" IsIndeterminate="True" Height="4" Margin="0,12,0,0" Foreground="#378ADD"
                       Background="#3C3C3C" BorderThickness="0" Visibility="Collapsed"/>
        </StackPanel>
      </DockPanel>
      <Button Name="BtnClose" Style="{StaticResource Btn}" Margin="0,14,0,0" Background="#3C3C3C" BorderBrush="#4A4A4A"
              BorderThickness="1" Foreground="#F3F3F3" Content="Sluiten" FontSize="13" Padding="0,7"/>
    </StackPanel>
  </Border>
</Window>
"@

function New-Window
{
    param ([string]$Xaml)
    [xml]$x = $Xaml
    return [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
}

function Show-Consent
{
    $w = New-Window $consentXaml
    $c = @{}
    'Header', 'Icon', 'Heading', 'SubHeading', 'Message', 'InfoBox', 'InfoGlyph', 'InfoText', 'Countdown', 'BtnLater', 'BtnNow' |
        ForEach-Object { $c[$_] = $w.FindName($_) }

    Set-Icon $c.Icon
    $c.Heading.Text    = $cfg.Heading
    $c.SubHeading.Text = $cfg.SubHeading
    $c.Message.Text    = $cfg.Message
    $c.BtnLater.Content = T 'Later' 'Later'
    $c.BtnNow.Content   = T 'Nu bijwerken' 'Update now'

    $forced = ($cfg.Mode -eq 'forced')
    $setWarning = {
        param ([string]$Text)
        $c.InfoBox.Background = Get-Brush '#FAEEDA'
        $c.InfoGlyph.Foreground = Get-Brush '#854F0B'
        $c.InfoGlyph.Text = [char]0xE7BA
        $c.InfoText.Foreground = Get-Brush '#633806'
        $c.InfoText.Text = $Text
    }

    $remaining = [int]$cfg.Remaining
    $what = if ($cfg.IsNew) { T 'de installatie' 'the installation' } else { T 'de update' 'the update' }
    if ($cfg.InfoOverride)
    {
        # Own info text (e.g. the restart prompt) instead of the postpone text
        if ($cfg.InfoWarning) { & $setWarning $cfg.InfoOverride } else { $c.InfoText.Text = $cfg.InfoOverride }
        if ($forced) { $c.BtnLater.Visibility = 'Collapsed' }
    }
    elseif ($forced)
    {
        # Postponing is no longer possible: only "Install now", otherwise it starts after the countdown
        $c.BtnLater.Visibility = 'Collapsed'
        $c.BtnNow.Content = T 'Nu installeren' 'Install now'
        & $setWarning $cfg.InfoText
    }
    elseif ($remaining -le 1)
    {
        $extra = if ([int]$cfg.ForcedMinutes -gt 0) { T ", met $($cfg.ForcedMinutes) minuten waarschuwing vooraf" ", with $($cfg.ForcedMinutes) minutes warning in advance" } else { '' }
        & $setWarning (T "Dit is de laatste keer dat je $what kunt uitstellen. Daarna wordt $($cfg.Heading) automatisch geïnstalleerd$extra." "This is the last time you can postpone $what. After that $($cfg.Heading) will be installed automatically$extra.")
    }
    else
    {
        $when = if ($cfg.LaterHint) { $cfg.LaterHint } else { T 'morgen' 'tomorrow' }
        $c.InfoText.Text = T "Je kunt $what nog $remaining keer uitstellen. Kies je Later, dan vragen we het $when opnieuw." "You can postpone $what $remaining more times. If you choose Later, we will ask again $when."
    }

    if ($cfg.NowText)   { $c.BtnNow.Content = $cfg.NowText }
    if ($cfg.LaterText) { $c.BtnLater.Content = $cfg.LaterText }

    $script:decided = $false
    $deadline = (Get-Date).AddSeconds([int]$cfg.TimeoutSeconds)

    $finish = {
        param ($answer)
        $script:decided = $true
        Set-Response $answer
        Write-PopupLog "Choice: $answer"
        $w.Close()
    }

    $c.BtnNow.Add_Click({ & $finish 'Yes' })
    $c.BtnLater.Add_Click({ & $finish 'No' })
    $c.Header.Add_MouseLeftButtonDown({ try { $w.DragMove() } catch { } })

    # Close only through the buttons (Alt+F4 does not count as a choice)
    $w.Add_Closing({ param($s, $e) if (-not $script:decided) { $e.Cancel = $true } })

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        $left = $deadline - (Get-Date)
        if ($left.TotalSeconds -le 0)
        {
            $timer.Stop()
            & $finish 'Timeout'
            return
        }
        $clock = '{0:mm\:ss}' -f $left
        if ($forced)
        {
            $c.Countdown.Text = if ($cfg.CountdownText) { $cfg.CountdownText.Replace('{tijd}', $clock) } else { T "De installatie start automatisch over $clock." "The installation starts automatically in $clock." }
        }
        else
        {
            $c.Countdown.Text = if ($cfg.TimeoutText) { $cfg.TimeoutText.Replace('{tijd}', $clock) } else { T "Maak je geen keuze, dan vragen we het later opnieuw ($clock)." "If you do not choose, we will ask again later ($clock)." }
        }
    })
    $timer.Start()

    # Bottom right above the taskbar, without taking focus (no accidental Enter while typing)
    $w.Add_ContentRendered({ Move-ToBottomRight $w })
    $w.Add_Closed({ $w.Dispatcher.InvokeShutdown() })
    $w.Show()
    [System.Windows.Threading.Dispatcher]::Run()
}

function Move-ToBottomRight
{
    param ($Window)
    $wa = [System.Windows.SystemParameters]::WorkArea
    $Window.Left = $wa.Right - $Window.ActualWidth
    $Window.Top  = $wa.Bottom - $Window.ActualHeight
    $dur  = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(250))
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation ([double]0, [double]1, $dur)
    $Window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
}

function Show-ToastWindow
{
    $w = New-Window $toastXaml
    $c = @{}
    'BtnX', 'SmallIcon', 'Sender', 'Icon', 'Badge', 'BadgeGlyph', 'Heading', 'Message', 'Progress', 'BtnClose' |
        ForEach-Object { $c[$_] = $w.FindName($_) }

    Set-Icon $c.Icon
    Set-Icon $c.SmallIcon
    $c.Sender.Text  = $cfg.Sender
    $c.Heading.Text = $cfg.Heading
    $c.Message.Text = $cfg.Message
    $c.BtnClose.Content = T 'Sluiten' 'Close'
    $c.BtnX.ToolTip     = T 'Sluiten' 'Close'

    switch ($cfg.Type)
    {
        'installing' { $c.Badge.Background = Get-Brush '#378ADD'; $c.BadgeGlyph.Text = [char]0xE895; $c.Progress.Visibility = 'Visible'; $c.BtnClose.Content = T 'Verbergen' 'Hide' }
        'success'    { $c.Badge.Background = Get-Brush '#3B9C3B'; $c.BadgeGlyph.Text = [char]0xE73E }
        'error'      { $c.Badge.Background = Get-Brush '#D13438'; $c.BadgeGlyph.Text = [char]0xE711 }
        default      { $c.Badge.Background = Get-Brush '#378ADD'; $c.BadgeGlyph.Text = [char]0xE946 }
    }

    $c.BtnX.Add_Click({ $w.Close() })
    $c.BtnClose.Add_Click({ $w.Close() })

    # Place bottom right above the taskbar and fade in
    $w.Add_ContentRendered({ Move-ToBottomRight $w })
    $w.Add_Closed({ $w.Dispatcher.InvokeShutdown() })

    $start = Get-Date
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        $elapsed = ((Get-Date) - $start).TotalSeconds
        # 'installing' closes by itself once the installation is done
        if ($cfg.CloseFlagPath -and (Test-Path $cfg.CloseFlagPath)) { $timer.Stop(); $w.Close(); return }
        if ([int]$cfg.AutoCloseSeconds -gt 0 -and $elapsed -ge [int]$cfg.AutoCloseSeconds) { $timer.Stop(); $w.Close() }
    })
    $timer.Start()

    # Show() instead of ShowDialog(): the notification does not steal focus
    $w.Show()
    [System.Windows.Threading.Dispatcher]::Run()
}

try
{
    Write-PopupLog "Started: mode=$($cfg.Mode) type=$($cfg.Type) lang=$($cfg.Lang)"
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    if ($cfg.Mode -in @('consent', 'forced')) { Show-Consent } else { Show-ToastWindow }
    Write-PopupLog 'Popup closed'
}
catch
{
    # Fall back to a standard Windows message box when the window cannot be built
    Write-PopupLog "ERROR in popup, falling back to MessageBox: $($_.Exception.Message)"
    try
    {
        Add-Type -AssemblyName PresentationFramework
        if ($cfg.Mode -eq 'consent')
        {
            $question = if ($cfg.FallbackQuestion) { $cfg.FallbackQuestion } else { T 'Wil je nu bijwerken?' 'Do you want to update now?' }
            $r = [System.Windows.MessageBox]::Show("$($cfg.Message)`n`n$question", $cfg.Heading, 'YesNo', 'Question')
            Set-Response $r.ToString()
        }
        elseif ($cfg.Mode -eq 'forced')
        {
            # The installation starts after the countdown anyway
            [void][System.Windows.MessageBox]::Show($cfg.Message, $cfg.Heading, 'OK', 'Warning')
            Set-Response 'Yes'
        }
        else
        {
            [void][System.Windows.MessageBox]::Show($cfg.Message, $cfg.Heading, 'OK', 'Information')
        }
    }
    catch
    {
        Set-Response 'Error'
    }
}
