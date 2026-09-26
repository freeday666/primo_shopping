#requires -Version 5.1
<#
    FreddoDev.ps1
    Modern Windows 11 Toolkit GUI - single file PowerShell/WPF app

    Functies:
    - Windows 11-style GUI
    - Realtime CPU / RAM / schijf / netwerk
    - Uptime
    - Windows health scan
    - Smart Fix
    - DISM RestoreHealth
    - SFC /SCANNOW
    - Windows Update openen/scannen
    - Driver overzicht
    - GPU / Graphics overzicht
    - Apparaatproblemen detecteren
    - Network diagnostics
    - DNS / Winsock reset
    - Temp cleanup
    - Prullenbak legen
    - Startup apps
    - Live Console / Debug
    - 🤖FreddoDevBot
    - FiveM detectie
    - Borderless animated UI
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$script:App = [ordered]@{
    Name      = 'FreddoDev'
    Root      = Join-Path $env:LOCALAPPDATA 'FreddoDev'
    LogDir    = Join-Path $env:LOCALAPPDATA 'FreddoDev\logs'
    LogFile   = Join-Path $env:LOCALAPPDATA 'FreddoDev\logs\freddodev-live.log'
    Window    = $null
    PageHost  = $null
    PageTitle = $null
    PageSubtitle = $null
    StatusText = $null
    ConsoleBox = $null
    BotChat = $null
    BotInput = $null
    Timer = $null
    Started = Get-Date
    Busy = $false
}

foreach ($d in @(
    $script:App.Root,
    $script:App.LogDir
)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

# ============================================================
# LOGGING
# ============================================================

function Write-LiveLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','OK','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    $line = "[{0}] [{1}] {2}" -f (
        Get-Date -Format 'HH:mm:ss'
    ), $Level, $Message

    try {
        Add-Content `
            -LiteralPath $script:App.LogFile `
            -Value $line `
            -Encoding UTF8
    }
    catch {}

    try {
        if ($script:App.ConsoleBox) {
            $script:App.ConsoleBox.AppendText(
                $line + [Environment]::NewLine
            )

            $script:App.ConsoleBox.ScrollToEnd()
        }
    }
    catch {}
}

# ============================================================
# UI HELPERS
# ============================================================

function New-Brush {
    param(
        [string]$Hex
    )

    return (
        New-Object System.Windows.Media.BrushConverter
    ).ConvertFromString($Hex)
}

function T {
    param(
        [string]$Text,
        [double]$Size = 13,
        [string]$Weight = 'Normal',
        [string]$Color = '#F7F3FC'
    )

    $x = New-Object System.Windows.Controls.TextBlock

    $x.Text = $Text
    $x.FontFamily = 'Segoe UI'
    $x.FontSize = $Size
    $x.FontWeight = $Weight
    $x.Foreground = New-Brush $Color
    $x.TextWrapping = 'Wrap'

    return $x
}

function Add-Card {
    param(
        [string]$Title,
        [string]$Value,
        [string]$Sub,
        [int]$Width = 235
    )

    $b = New-Object System.Windows.Controls.Border

    $b.Width = $Width
    $b.Margin = '0,0,14,14'
    $b.Padding = '17'
    $b.CornerRadius = '16'
    $b.Background = New-Brush '#17131E'
    $b.BorderBrush = New-Brush '#2C2635'
    $b.BorderThickness = '1'

    $s = New-Object System.Windows.Controls.StackPanel

    $s.Children.Add(
        (T $Title 10 'SemiBold' '#9B90A9')
    ) | Out-Null

    $s.Children.Add(
        (T $Value 25 'Bold' '#FFFFFF')
    ) | Out-Null

    $c = T $Sub 11 'Normal' '#837A90'
    $c.Margin = '0,5,0,0'

    $s.Children.Add($c) | Out-Null

    $b.Child = $s

    return $b
}

function Add-Button {
    param(
        [string]$Label,
        [scriptblock]$Action,
        [int]$Width = 175,
        [string]$Icon = '•'
    )

    $b = New-Object System.Windows.Controls.Button

    $b.Content = "$Icon  $Label"
    $b.Width = $Width
    $b.Height = 42
    $b.Margin = '0,0,10,10'
    $b.Padding = '13,7'
    $b.FontFamily = 'Segoe UI'
    $b.FontSize = 12
    $b.FontWeight = 'SemiBold'
    $b.Foreground = New-Brush '#F8F4FF'
    $b.Background = New-Brush '#2B2142'
    $b.BorderBrush = New-Brush '#453561'
    $b.BorderThickness = '1'
    $b.Cursor = [System.Windows.Input.Cursors]::Hand

    $b.Add_Click($Action)

    $b.Template = [System.Windows.Markup.XamlReader]::Parse(@"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 TargetType="Button">

  <Border x:Name="bd"
          Background="{TemplateBinding Background}"
          BorderBrush="{TemplateBinding BorderBrush}"
          BorderThickness="{TemplateBinding BorderThickness}"
          CornerRadius="10">

    <ContentPresenter
        HorizontalAlignment="Center"
        VerticalAlignment="Center"/>

  </Border>

  <ControlTemplate.Triggers>

    <Trigger Property="IsMouseOver" Value="True">
      <Setter TargetName="bd"
              Property="Background"
              Value="#3B2C5B"/>

      <Setter TargetName="bd"
              Property="BorderBrush"
              Value="#7A5CC1"/>
    </Trigger>

    <Trigger Property="IsPressed" Value="True">
      <Setter TargetName="bd"
              Property="Opacity"
              Value="0.85"/>
    </Trigger>

    <Trigger Property="IsEnabled" Value="False">
      <Setter TargetName="bd"
              Property="Opacity"
              Value="0.45"/>
    </Trigger>

  </ControlTemplate.Triggers>

</ControlTemplate>
"@)

    return $b
}

function Add-NavButton {
    param(
        [string]$Label,
        [string]$Icon,
        [scriptblock]$Action
    )

    $b = New-Object System.Windows.Controls.Button

    $b.Content = "$Icon  $Label"
    $b.HorizontalContentAlignment = 'Left'
    $b.Height = 42
    $b.Margin = '0,0,0,6'
    $b.Padding = '13,0'
    $b.FontFamily = 'Segoe UI'
    $b.FontSize = 12
    $b.FontWeight = 'SemiBold'
    $b.Foreground = New-Brush '#BDB3C7'
    $b.Background = New-Brush '#14111A'
    $b.BorderThickness = '0'
    $b.Cursor = [System.Windows.Input.Cursors]::Hand

    $b.Add_Click($Action)

    $b.Template = [System.Windows.Markup.XamlReader]::Parse(@"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 TargetType="Button">

  <Border x:Name="bd"
          Background="{TemplateBinding Background}"
          CornerRadius="9">

    <ContentPresenter
        Margin="{TemplateBinding Padding}"
        HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
        VerticalAlignment="Center"/>

  </Border>

  <ControlTemplate.Triggers>

    <Trigger Property="IsMouseOver" Value="True">
      <Setter TargetName="bd"
              Property="Background"
              Value="#211A2D"/>

      <Setter Property="Foreground"
              Value="#FFFFFF"/>
    </Trigger>

  </ControlTemplate.Triggers>

</ControlTemplate>
"@)

    return $b
}

# ============================================================
# CONFIRM / ADMIN
# ============================================================

function Ask-Confirm {
    param(
        [string]$Title,
        [string]$Message
    )

    $result = [System.Windows.MessageBox]::Show(
        $Message,
        $Title,
        'YesNo',
        'Warning'
    )

    return ($result -eq 'Yes')
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()

        $p = New-Object Security.Principal.WindowsPrincipal($id)

        return $p.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    }
    catch {
        return $false
    }
}

function Invoke-ElevatedSelf {
    param(
        [string]$ArgumentList = ''
    )

    if (Test-IsAdmin) {
        return $true
    }

    try {
        $arg =
            "-NoProfile " +
            "-ExecutionPolicy Bypass " +
            "-File `"$($PSCommandPath)`" " +
            $ArgumentList

        Start-Process `
            powershell.exe `
            -Verb RunAs `
            -ArgumentList $arg | Out-Null

        Write-LiveLog `
            'Administratorrechten aangevraagd.' `
            'OK'

        return $false
    }
    catch {
        Write-LiveLog `
            "Elevated start mislukt: $($_.Exception.Message)" `
            'ERROR'

        return $false
    }
}

# ============================================================
# CPU / RAM / DISK / UPTIME
# ============================================================

function Get-CPUPercent {

    try {

        $m = Get-CimInstance Win32_Processor |
            Measure-Object LoadPercentage -Average

        if ($null -ne $m.Average) {

            return [int][math]::Round(
                $m.Average,
                0
            )
        }
    }
    catch {}

    return 0
}

function Get-MemoryInfo {

    try {

        $os = Get-CimInstance Win32_OperatingSystem

        $total = [double]$os.TotalVisibleMemorySize
        $free  = [double]$os.FreePhysicalMemory

        if ($total -gt 0) {

            $used =
                [math]::Round(
                    (1 - ($free / $total)) * 100,
                    0
                )

            return [pscustomobject]@{

                UsedPercent = $used

                TotalGB =
                    [math]::Round(
                        $total / 1MB,
                        1
                    )

                FreeGB =
                    [math]::Round(
                        $free / 1MB,
                        1
                    )
            }
        }

    }
    catch {}

    return [pscustomobject]@{
        UsedPercent = 0
        TotalGB = 0
        FreeGB = 0
    }
}

function Get-DiskInfo {

    try {

        $d = Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'"

        if ($d -and $d.Size) {

            $total =
                [double]$d.Size / 1GB

            $free =
                [double]$d.FreeSpace / 1GB

            return [pscustomobject]@{

                UsedPercent =
                    [int][math]::Round(
                        (1 - ($free / $total)) * 100,
                        0
                    )

                TotalGB =
                    [math]::Round(
                        $total,
                        1
                    )

                FreeGB =
                    [math]::Round(
                        $free,
                        1
                    )
            }
        }

    }
    catch {}

    return [pscustomobject]@{
        UsedPercent = 0
        TotalGB = 0
        FreeGB = 0
    }
}

function Get-UptimeText {

    try {

        $os =
            Get-CimInstance Win32_OperatingSystem

        $span =
            (Get-Date) - $os.LastBootUpTime

        return (
            '{0}d {1}u {2}m' -f
            [int]$span.TotalDays,
            $span.Hours,
            $span.Minutes
        )
    }
    catch {

        return 'Onbekend'
    }
}

# ============================================================
# OS
# ============================================================

function Get-OSInfo {

    try {

        $os =
            Get-CimInstance Win32_OperatingSystem

        return [pscustomobject]@{

            Caption =
                [string]$os.Caption

            Version =
                [string]$os.Version

            Build =
                [string]$os.BuildNumber

            LastBoot =
                [datetime]$os.LastBootUpTime

            InstallDate =
                [datetime]$os.InstallDate
        }
    }
    catch {

        return [pscustomobject]@{
            Caption = 'Windows'
            Version = ''
            Build = ''
            LastBoot = $null
            InstallDate = $null
        }
    }
}

# ============================================================
# GPU / DRIVERS
# ============================================================

function Get-GPUInfo {

    try {

        $gpus = @(
            Get-CimInstance Win32_VideoController |
            Select-Object `
                Name,
                DriverVersion,
                VideoModeDescription,
                AdapterRAM,
                Status
        )

        return $gpus
    }
    catch {

        return @()
    }
}

function Get-ProblemDevices {

    try {

        return @(
            Get-CimInstance Win32_PnPEntity |
            Where-Object {
                $_.ConfigManagerErrorCode -and
                $_.ConfigManagerErrorCode -ne 0
            } |
            Select-Object `
                Name,
                ConfigManagerErrorCode,
                Status
        )
    }
    catch {

        return @()
    }
}

function Get-DriverSnapshot {

    try {

        return @(
            Get-CimInstance Win32_PnPSignedDriver |
            Where-Object {
                $_.DeviceName
            } |
            Select-Object `
                DeviceName,
                DriverVersion,
                DriverDate,
                Manufacturer,
                IsSigned |
            Sort-Object DeviceName
        )
    }
    catch {

        return @()
    }
}

# ============================================================
# NETWORK
# ============================================================

function Get-NetworkSnapshot {

    $out = [ordered]@{

        Online = $false

        AdapterCount = 0

        Gateway = ''

        DNS = @()
    }

    try {

        $adapters = @(
            Get-NetAdapter `
                -Physical `
                -ErrorAction Stop |
            Where-Object {
                $_.Status -eq 'Up'
            }
        )

        $out.AdapterCount =
            $adapters.Count
    }
    catch {}

    try {

        $test =
            Test-NetConnection `
                -ComputerName 1.1.1.1 `
                -InformationLevel Quiet `
                -WarningAction SilentlyContinue

        $out.Online =
            [bool]$test
    }
    catch {}

    try {

        $routes = @(
            Get-NetRoute `
                -DestinationPrefix '0.0.0.0/0' |
            Sort-Object RouteMetric |
            Select-Object -First 1
        )

        if ($routes.Count -gt 0) {

            $out.Gateway =
                [string]$routes[0].NextHop
        }
    }
    catch {}

    try {

        $out.DNS = @(
            Get-DnsClientServerAddress `
                -AddressFamily IPv4 |
            ForEach-Object {
                $_.ServerAddresses
            } |
            Where-Object {
                $_
            } |
            Select-Object -Unique
        )
    }
    catch {}

    return [pscustomobject]$out
}

# ============================================================
# WINDOWS UPDATE
# ============================================================

function Get-WindowsUpdateServiceStatus {

    try {

        $s =
            Get-Service `
                -Name wuauserv

        return [string]$s.Status
    }
    catch {

        return 'Onbekend'
    }
}

function Open-WindowsUpdate {

    try {

        Start-Process `
            'ms-settings:windowsupdate'

        Write-LiveLog `
            'Windows Update geopend.' `
            'OK'
    }
    catch {

        Write-LiveLog `
            "Windows Update openen mislukt: $($_.Exception.Message)" `
            'ERROR'
    }
}

function Start-WindowsUpdateScan {

    if (-not (Test-IsAdmin)) {

        [void](
            Invoke-ElevatedSelf `
                '-UpdateScan'
        )

        return
    }

    Write-LiveLog `
        'Windows Update scan gestart.' `
        'DEBUG'

    try {

        Start-Process `
            "$env:WINDIR\System32\UsoClient.exe" `
            -ArgumentList 'StartScan' `
            -WindowStyle Hidden | Out-Null

        Write-LiveLog `
            'UsoClient StartScan aangeroepen.' `
            'OK'
    }
    catch {

        Write-LiveLog `
            "Update scan mislukt: $($_.Exception.Message)" `
            'WARN'
    }
}

# ============================================================
# PROCESS RUNNER
# ============================================================

function Run-ProcessCapture {

    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $psi =
        New-Object System.Diagnostics.ProcessStartInfo

    $psi.FileName =
        $FilePath

    $psi.UseShellExecute =
        $false

    $psi.RedirectStandardOutput =
        $true

    $psi.RedirectStandardError =
        $true

    $psi.CreateNoWindow =
        $true

    $safeArgs = @()

    foreach ($a in $Arguments) {

        if ($a -match '\s') {

            $safeArgs +=
                '"' +
                $a.Replace('"','\"') +
                '"'
        }
        else {

            $safeArgs += $a
        }
    }

    $psi.Arguments =
        $safeArgs -join ' '

    $p =
        New-Object System.Diagnostics.Process

    $p.StartInfo =
        $psi

    [void]$p.Start()

    $stdout =
        $p.StandardOutput.ReadToEnd()

    $stderr =
        $p.StandardError.ReadToEnd()

    $p.WaitForExit()

    return [pscustomobject]@{

        ExitCode =
            $p.ExitCode

        StdOut =
            $stdout

        StdErr =
            $stderr
    }
}

# ============================================================
# DISM
# ============================================================

function Run-DismHealth {

    if (-not (Test-IsAdmin)) {

        return [pscustomobject]@{
            ExitCode = -1
            Output = 'Administratorrechten vereist.'
        }
    }

    Write-LiveLog `
        'DISM RestoreHealth gestart.' `
        'DEBUG'

    $r =
        Run-ProcessCapture `
            'DISM.exe' `
            @(
                '/Online',
                '/Cleanup-Image',
                '/RestoreHealth'
            )

    $text =
        (
            $r.StdOut +
            [Environment]::NewLine +
            $r.StdErr
        ).Trim()

    if ($text) {

        Write-LiveLog `
            $text `
            'DEBUG'
    }

    Write-LiveLog `
        "DISM voltooid met exitcode $($r.ExitCode)." `
        $(if ($r.ExitCode -eq 0) {
            'OK'
        } else {
            'WARN'
        })

    return [pscustomobject]@{

        ExitCode = $r.ExitCode

        Output = $text
    }
}

# ============================================================
# SFC
# ============================================================

function Run-SfcScan {

    if (-not (Test-IsAdmin)) {

        return [pscustomobject]@{
            ExitCode = -1
            Output = 'Administratorrechten vereist.'
        }
    }

    Write-LiveLog `
        'SFC /SCANNOW gestart.' `
        'DEBUG'

    $r =
        Run-ProcessCapture `
            'sfc.exe' `
            @('/scannow')

    $text =
        (
            $r.StdOut +
            [Environment]::NewLine +
            $r.StdErr
        ).Trim()

    if ($text) {

        Write-LiveLog `
            $text `
            'DEBUG'
    }

    Write-LiveLog `
        "SFC voltooid met exitcode $($r.ExitCode)." `
        $(if ($r.ExitCode -eq 0) {
            'OK'
        } else {
            'WARN'
        })

    return [pscustomobject]@{

        ExitCode = $r.ExitCode

        Output = $text
    }
}

# ============================================================
# TEMP CLEANUP
# ============================================================

function Get-TempTargets {

    return @(
        [Environment]::GetEnvironmentVariable('TEMP')
        [Environment]::GetEnvironmentVariable('TMP')
        (Join-Path $env:LOCALAPPDATA 'Temp')
        (Join-Path $env:WINDIR 'Temp')
    ) |
    Where-Object {
        $_ -and
        (Test-Path -LiteralPath $_ -PathType Container)
    } |
    Select-Object -Unique
}

function Invoke-TempCleanup {

    param(
        [switch]$Silent
    )

    if (-not $Silent) {

        if (-not (
            Ask-Confirm `
                'Tijdelijke bestanden opschonen' `
@"
FreddoDev verwijdert alleen tijdelijke bestanden uit bekende
Temp-mappen.

Persoonlijke documenten worden niet aangeraakt.

Bestanden die in gebruik zijn worden overgeslagen.

Doorgaan?
"@
        )) {

            return
        }
    }

    $targets =
        Get-TempTargets

    $deleted = 0
    $bytes = [int64]0

    foreach ($folder in $targets) {

        Write-LiveLog `
            "Temp cleanup: $folder" `
            'DEBUG'

        try {

            $files = @(
                Get-ChildItem `
                    -LiteralPath $folder `
                    -File `
                    -Force `
                    -Recurse `
                    -ErrorAction SilentlyContinue
            )

            foreach ($f in $files) {

                try {

                    $bytes +=
                        [int64]$f.Length

                    Remove-Item `
                        -LiteralPath $f.FullName `
                        -Force `
                        -ErrorAction Stop

                    $deleted++
                }
                catch {}
            }
        }
        catch {}
    }

    $mb =
        [math]::Round(
            $bytes / 1MB,
            1
        )

    Write-LiveLog `
        "Temp cleanup klaar: $deleted bestanden, ongeveer $mb MB." `
        'OK'

    if (-not $Silent) {

        [System.Windows.MessageBox]::Show(
            "Cleanup klaar.`n`n" +
            "$deleted bestanden verwijderd`n" +
            "Ongeveer $mb MB vrijgemaakt.",
            'FreddoDev',
            'OK',
            'Information'
        ) | Out-Null
    }
}

# ============================================================
# RECYCLE BIN
# ============================================================

function Invoke-RecycleBinCleanup {

    if (-not (
        Ask-Confirm `
            'Prullenbak legen' `
            'Weet je zeker dat je alle items uit de Windows Prullenbak wilt verwijderen?'
    )) {

        return
    }

    try {

        Clear-RecycleBin `
            -Force `
            -ErrorAction Stop

        Write-LiveLog `
            'Prullenbak geleegd.' `
            'OK'
    }
    catch {

        Write-LiveLog `
            "Prullenbak kon niet worden geleegd: $($_.Exception.Message)" `
            'WARN'
    }
}

# ============================================================
# NETWORK RESET
# ============================================================

function Invoke-NetworkReset {

    if (-not (
        Ask-Confirm `
            'Netwerk reset' `
@"
Dit voert uit:

- ipconfig /flushdns
- netsh winsock reset
- netsh int ip reset

Je netwerk kan tijdelijk wegvallen.

Een herstart kan nodig zijn.

Doorgaan?
"@
    )) {

        return
    }

    if (-not (Test-IsAdmin)) {

        [void](
            Invoke-ElevatedSelf `
                '-NetworkReset'
        )

        return
    }

    Write-LiveLog `
        'Netwerkreset gestart.' `
        'WARN'

    try {

        ipconfig.exe /flushdns |
            ForEach-Object {
                Write-LiveLog $_ 'DEBUG'
            }

        netsh.exe winsock reset |
            ForEach-Object {
                Write-LiveLog $_ 'DEBUG'
            }

        netsh.exe int ip reset |
            ForEach-Object {
                Write-LiveLog $_ 'DEBUG'
            }

        Write-LiveLog `
            'Netwerkreset uitgevoerd.' `
            'OK'
    }
    catch {

        Write-LiveLog `
            "Netwerkreset fout: $($_.Exception.Message)" `
            'ERROR'
    }
}

# ============================================================
# SMART FIX
# ============================================================

function Invoke-SmartFix {

    if ($script:App.Busy) {
        return
    }

    if (-not (
        Ask-Confirm `
            'FreddoDev Smart Fix' `
@"
Smart Fix voert een onderhoudsronde uit:

1. DISM Windows health
2. SFC systeembestanden
3. Windows Update service controle
4. Netwerkdiagnose
5. Temp cleanup
6. Driver/problem-device controle

Persoonlijke documenten worden niet verwijderd.

Doorgaan?
"@
    )) {

        return
    }

    $script:App.Busy = $true

    try {

        Write-LiveLog `
            '=== SMART FIX START ===' `
            'INFO'

        if (-not (Test-IsAdmin)) {

            Write-LiveLog `
                'App draait niet als administrator; admin-reparaties worden overgeslagen.' `
                'WARN'
        }
        else {

            [void](Run-DismHealth)

            [void](Run-SfcScan)
        }

        Write-LiveLog `
            "Windows Update-service: $(Get-WindowsUpdateServiceStatus)" `
            'INFO'

        $net =
            Get-NetworkSnapshot

        Write-LiveLog `
            (
                "Netwerk online={0}, adapters={1}, gateway={2}" -f
                $net.Online,
                $net.AdapterCount,
                $net.Gateway
            ) `
            'INFO'

        Invoke-TempCleanup -Silent

        $problem =
            @(Get-ProblemDevices)

        Write-LiveLog `
            "Problem devices gevonden: $($problem.Count)" `
            $(if ($problem.Count -eq 0) {
                'OK'
            } else {
                'WARN'
            })

        Write-LiveLog `
            '=== SMART FIX KLAAR ===' `
            'OK'

        [System.Windows.MessageBox]::Show(
            'Smart Fix is afgerond. Bekijk Live Console voor details.',
            'FreddoDev',
            'OK',
            'Information'
        ) | Out-Null

        Show-Dashboard
    }
    finally {

        $script:App.Busy = $false
    }
}

# ============================================================
# QUICK HEALTH
# ============================================================

function Run-HealthQuickScan {

    if ($script:App.Busy) {
        return
    }

    $script:App.Busy = $true

    try {

        Write-LiveLog `
            'Quick health scan gestart.' `
            'INFO'

        $os =
            Get-OSInfo

        $ram =
            Get-MemoryInfo

        $disk =
            Get-DiskInfo

        $net =
            Get-NetworkSnapshot

        $problems =
            @(Get-ProblemDevices)

        Write-LiveLog `
            "Windows: $($os.Caption) build $($os.Build)"

        Write-LiveLog `
            "CPU: $(Get-CPUPercent)%"

        Write-LiveLog `
            "RAM: $($ram.UsedPercent)% gebruikt / $($ram.TotalGB) GB"

        Write-LiveLog `
            "Disk: $($disk.UsedPercent)% gebruikt / $($disk.FreeGB) GB vrij"

        Write-LiveLog `
            "Netwerk: online=$($net.Online), adapters=$($net.AdapterCount)"

        Write-LiveLog `
            "Problem devices: $($problems.Count)" `
            $(if ($problems.Count -eq 0) {
                'OK'
            } else {
                'WARN'
            })

        Write-LiveLog `
            'Quick health scan klaar.' `
            'OK'

        [System.Windows.MessageBox]::Show(
            'Quick health scan afgerond.',
            'FreddoDev',
            'OK',
            'Information'
        ) | Out-Null

        Show-Scan
    }
    finally {

        $script:App.Busy = $false
    }
}

# ============================================================
# DRIVER / DEVICE TOOLS
# ============================================================

function Refresh-DriverDetection {

    $problem =
        @(Get-ProblemDevices)

    $gpu =
        @(Get-GPUInfo)

    Write-LiveLog `
        "Driver check: $($problem.Count) problem device(s), $($gpu.Count) GPU(s)." `
        $(if ($problem.Count -eq 0) {
            'OK'
        } else {
            'WARN'
        })

    return $problem
}

function Open-DeviceManager {

    try {

        Start-Process devmgmt.msc

        Write-LiveLog `
            'Apparaatbeheer geopend.' `
            'OK'
    }
    catch {

        Write-LiveLog `
            "Apparaatbeheer openen mislukt: $($_.Exception.Message)" `
            'ERROR'
    }
}

# ============================================================
# STARTUP
# ============================================================

function Open-StartupApps {

    try {

        Start-Process `
            'ms-settings:startupapps'

        Write-LiveLog `
            'Startup apps geopend.' `
            'OK'
    }
    catch {}
}

# ============================================================
# RESTART
# ============================================================

function Restart-PC {

    if (-not (
        Ask-Confirm `
            'Pc herstarten' `
            'De pc wordt opnieuw opgestart. Sla eerst al je werk op. Doorgaan?'
    )) {

        return
    }

    Write-LiveLog `
        'Pc-herstart aangevraagd.' `
        'WARN'

    try {

        Restart-Computer -Force
    }
    catch {}
}

# ============================================================
# LOG OPENEN
# ============================================================

function Open-LocalLog {

    try {

        Start-Process `
            notepad.exe `
            -ArgumentList "`"$($script:App.LogFile)`""
    }
    catch {}
}

# ============================================================
# BOT
# ============================================================

function Bot-Reply {

    param(
        [string]$Question
    )

    $q =
        $Question.Trim().ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($q)) {

        return `
            'Typ bijvoorbeeld: fix, update, drivers, graphics, uptime, schoonmaken, netwerk, FiveM, logs of help.'
    }

    if ($q -match '^(hoi|hey|hello|hallo|yo)\b') {

        return `
            'Hoi 👋 Ik ben 🤖FreddoDevBot. Stel je vraag of geef een commando.'
    }

    if ($q -match 'fix|repareer|herstel|repair|problemen') {

        return `
            'Gebruik Smart Fix. Deze controleert Windows, netwerk, Temp en problem devices. Voor echte systeemreparaties kan administratorrechten nodig zijn.'
    }

    if ($q -match 'schoon|clean|opruimen|temp|tijdelijke') {

        return `
            'Gebruik Temp Cleanup. Die ruimt bekende tijdelijke Windows-mappen op en slaat bestanden over die in gebruik zijn.'
    }

    if ($q -match 'update|windows update') {

        return `
            'Open Windows Update voor beschikbare updates. De knop Update Scan start ook een Windows Update scan.'
    }

    if ($q -match 'driver|drivers|stuurprogramma') {

        $problems =
            @(Get-ProblemDevices)

        if ($problems.Count -eq 0) {

            return `
                'Ik zie geen apparaten met een ConfigManager-fout. Voor updates kun je Windows Update of Apparaatbeheer gebruiken.'
        }

        return `
            "Ik zie $($problems.Count) apparaat/apparaten met een Windows device error. Open Drivers & Graphics."
    }

    if ($q -match 'graphics|gpu|videokaart|video') {

        $gpu =
            @(Get-GPUInfo)

        if ($gpu.Count -eq 0) {

            return `
                'Ik kon geen GPU-informatie uitlezen.'
        }

        return (
            $gpu |
            ForEach-Object {
                "GPU: $($_.Name) | Driver: $($_.DriverVersion) | Status: $($_.Status)"
            }
        ) -join ' || '
    }

    if ($q -match 'uptime|up time|hoe lang|boot') {

        $os =
            Get-OSInfo

        if ($os.LastBoot) {

            return `
                "Je pc draait ongeveer $(Get-UptimeText). Laatste boot: $($os.LastBoot.ToString('dd-MM-yyyy HH:mm'))."
        }

        return `
            "Uptime: $(Get-UptimeText)."
    }

    if ($q -match '\bcpu\b|processor') {

        return `
            "CPU-belasting is momenteel $(Get-CPUPercent)%."
    }

    if ($q -match 'ram|geheugen|memory') {

        $m =
            Get-MemoryInfo

        return `
            "RAM: $($m.UsedPercent)% gebruikt, $($m.TotalGB) GB totaal, $($m.FreeGB) GB vrij."
    }

    if ($q -match 'disk|schijf|opslag|storage|c:') {

        $d =
            Get-DiskInfo

        return `
            "C: $($d.UsedPercent)% gebruikt, $($d.FreeGB) GB vrij van $($d.TotalGB) GB."
    }

    if ($q -match 'netwerk|internet|wifi|ping|dns') {

        $n =
            Get-NetworkSnapshot

        return `
            "Netwerk online: $($n.Online). Actieve adapters: $($n.AdapterCount). Gateway: $($n.Gateway)."
    }

    if ($q -match 'restart|herstart|reboot') {

        return `
            'Gebruik de knop Pc herstarten in Tools. Die vraagt eerst bevestiging.'
    }

    if ($q -match 'log|debug|console') {

        return `
            'Open Live Console / Debug voor realtime FreddoDev output en fouten.'
    }

    if ($q -match 'fivem|citizenfx') {

        $root =
            'C:\Users\unban\AppData\Local\FiveM\FiveM.app'

        if (
            Test-Path `
                -LiteralPath $root `
                -PathType Container
        ) {

            return `
                "FiveM.app is gevonden op $root."
        }

        return `
            "FiveM.app is niet gevonden op $root."
    }

    if ($q -match 'help|wat kan je|wat kun je|commands|commando') {

        return `
            'Ik herken onder andere: fix, herstel, schoonmaken, update, drivers, graphics, uptime, cpu, ram, disk, netwerk, logs, FiveM, restart en help.'
    }

    return `
        "🤖FreddoDevBot: ik herken geen specifieke actie voor '$Question'. Probeer help voor voorbeelden."
}

# ============================================================
# PAGE HELPERS
# ============================================================

function Clear-Page {

    $script:App.PageHost.Children.Clear()
}

function Set-PageHeader {

    param(
        [string]$Title,
        [string]$Subtitle
    )

    $script:App.PageTitle.Text =
        $Title

    $script:App.PageSubtitle.Text =
        $Subtitle
}

# ============================================================
# DASHBOARD
# ============================================================

function Show-Dashboard {

    Clear-Page

    Set-PageHeader `
        'Dashboard' `
        'Realtime systeemstatus & snelle reparaties'

    $scroll =
        New-Object System.Windows.Controls.ScrollViewer

    $scroll.VerticalScrollBarVisibility =
        'Auto'

    $stack =
        New-Object System.Windows.Controls.StackPanel

    $stack.Margin =
        '0,0,16,16'

    # HERO

    $hero =
        New-Object System.Windows.Controls.Border

    $hero.Background =
        New-Brush '#1A1430'

    $hero.BorderBrush =
        New-Brush '#392A55'

    $hero.BorderThickness =
        '1'

    $hero.CornerRadius =
        '18'

    $hero.Padding =
        '21'

    $hero.Margin =
        '0,0,0,15'

    $hs =
        New-Object System.Windows.Controls.StackPanel

    $hs.Children.Add(
        (T 'FreddoDev' 28 'Bold' '#FFFFFF')
    ) | Out-Null

    $sub =
        T `
            'Realtime monitor, repair tools, updates, drivers, cleanup en 🤖 chat in één app.' `
            12 `
            'Normal' `
            '#BDB2CC'

    $sub.Margin =
        '0,5,0,0'

    $hs.Children.Add($sub) | Out-Null

    $hero.Child =
        $hs

    $stack.Children.Add(
        $hero
    ) | Out-Null

    # SYSTEM DATA

    $ram =
        Get-MemoryInfo

    $disk =
        Get-DiskInfo

    $cpu =
        Get-CPUPercent

    $net =
        Get-NetworkSnapshot

    $os =
        Get-OSInfo

    $problem =
        @(Get-ProblemDevices)

    $gpu =
        @(Get-GPUInfo)

    # CARDS

    $cards =
        New-Object System.Windows.Controls.WrapPanel

    $cards.Children.Add(
        (Add-Card `
            'CPU' `
            "$cpu%" `
            'Huidige belasting')
    ) | Out-Null

    $cards.Children.Add(
        (Add-Card `
            'RAM' `
            "$($ram.UsedPercent)%" `
            "$($ram.TotalGB) GB totaal")
    ) | Out-Null

    $cards.Children.Add(
        (Add-Card `
            'C: DRIVE' `
            "$($disk.UsedPercent)%" `
            "$($disk.FreeGB) GB vrij")
    ) | Out-Null

    $cards.Children.Add(
        (Add-Card `
            'UPTIME' `
            (Get-UptimeText) `
            'Sinds laatste boot')
    ) | Out-Null

    $cards.Children.Add(
        (Add-Card `
            'NETWORK' `
            $(if($net.Online) {
                'ONLINE'
            } else {
                'OFFLINE'
            }) `
            "$($net.AdapterCount) actieve adapter(s)")
    ) | Out-Null

    $cards.Children.Add(
        (Add-Card `
            'DEVICE ERRORS' `
            "$($problem.Count)" `
            $(if($problem.Count -eq 0) {
                'Geen fouten'
            } else {
                'Bekijk drivers'
            }))
    ) | Out-Null

    $stack.Children.Add(
        $cards
    ) | Out-Null

    # SMART ACTIONS

    $stack.Children.Add(
        (T 'Smart Actions' 18 'Bold' '#FFFFFF')
    ) | Out-Null

    $actions =
        New-Object System.Windows.Controls.WrapPanel

    $actions.Children.Add(
        (Add-Button `
            'Smart Fix' `
            {
                Invoke-SmartFix
            } `
            175 `
            '⚡')
    ) | Out-Null

    $actions.Children.Add(
        (Add-Button `
            'Health Scan' `
            {
                Run-HealthQuickScan
            } `
            175 `
            '⌕')
    ) | Out-Null

    $actions.Children.Add(
        (Add-Button `
            'Windows Update' `
            {
                Open-WindowsUpdate
            } `
            175 `
            '↻')
    ) | Out-Null

    $actions.Children.Add(
        (Add-Button `
            'Update Scan' `
            {
                Start-WindowsUpdateScan
            } `
            175 `
            '↓')
    ) | Out-Null

    $actions.Children.Add(
        (Add-Button `
            'Temp Cleanup' `
            {
                Invoke-TempCleanup
            } `
            175 `
            '⌫')
    ) | Out-Null

    $actions.Children.Add(
        (Add-Button `
            '🤖 FreddoDevBot' `
            {
                Show-Bot
            } `
            190 `
            '🤖')
    ) | Out-Null

    $stack.Children.Add(
        $actions
    ) | Out-Null

    # STATUS

    $status =
        New-Object System.Windows.Controls.Border

    $status.Background =
        New-Brush '#15121B'

    $status.BorderBrush =
        New-Brush '#2A2532'

    $status.BorderThickness =
        '1'

    $status.CornerRadius =
        '14'

    $status.Padding =
        '15'

    $status.Margin =
        '0,7,0,0'

    $status.Child =
        T `
            "Windows: $($os.Caption) • Build $($os.Build) • GPU's: $($gpu.Count) • Problem devices: $($problem.Count)" `
            11 `
            'Normal' `
            '#A39AAA'

    $stack.Children.Add(
        $status
    ) | Out-Null

    $scroll.Content =
        $stack

    $script:App.PageHost.Children.Add(
        $scroll
    ) | Out-Null
}

# ============================================================
# WINDOWS SCAN
# ============================================================

function Show-Scan {

    Clear-Page

    Set-PageHeader `
        'Windows Scan' `
        'Realtime read-only diagnostiek'

    $scroll =
        New-Object System.Windows.Controls.ScrollViewer

    $scroll.VerticalScrollBarVisibility =
        'Auto'

    $stack =
        New-Object System.Windows.Controls.StackPanel

    $stack.Margin =
        '0,0,16,16'

    $os =
        Get-OSInfo

    $ram =
        Get-MemoryInfo

    $disk =
        Get-DiskInfo

    $net =
        Get-NetworkSnapshot

    $problems =
        @(Get-ProblemDevices)

    $stack.Children.Add(
        (T `
            'Windows gezondheid' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    $grid =
        New-Object System.Windows.Controls.WrapPanel

    $grid.Children.Add(
        (Add-Card `
            'WINDOWS' `
            "$($os.Caption)" `
            "Build $($os.Build)" `
            285)
    ) | Out-Null

    $grid.Children.Add(
        (Add-Card `
            'CPU' `
            "$(Get-CPUPercent)%" `
            'Processorbelasting' `
            220)
    ) | Out-Null

    $grid.Children.Add(
        (Add-Card `
            'RAM' `
            "$($ram.UsedPercent)%" `
            "$($ram.FreeGB) GB vrij" `
            220)
    ) | Out-Null

    $grid.Children.Add(
        (Add-Card `
            'DISK' `
            "$($disk.UsedPercent)%" `
            "$($disk.FreeGB) GB vrij" `
            220)
    ) | Out-Null

    $grid.Children.Add(
        (Add-Card `
            'NETWORK' `
            $(if($net.Online) {
                'ONLINE'
            } else {
                'OFFLINE'
            }) `
            "Gateway: $($net.Gateway)" `
            260)
    ) | Out-Null

    $grid.Children.Add(
        (Add-Card `
            'DEVICE ERRORS' `
            "$($problems.Count)" `
            $(if($problems.Count -eq 0) {
                'Geen'
            } else {
                'Bekijk Drivers'
            }) `
            220)
    ) | Out-Null

    $stack.Children.Add(
        $grid
    ) | Out-Null

    $buttons =
        New-Object System.Windows.Controls.WrapPanel

    $buttons.Children.Add(
        (Add-Button `
            'Scan vernieuwen' `
            {
                Show-Scan
            } `
            170 `
            '↻')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Smart Fix' `
            {
                Invoke-SmartFix
            } `
            165 `
            '⚡')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Live Console' `
            {
                Show-Console
            } `
            165 `
            '▤')
    ) | Out-Null

    $stack.Children.Add(
        $buttons
    ) | Out-Null

    $scroll.Content =
        $stack

    $script:App.PageHost.Children.Add(
        $scroll
    ) | Out-Null
}

# ============================================================
# DRIVERS
# ============================================================

function Show-Drivers {

    Clear-Page

    Set-PageHeader `
        'Drivers & Graphics' `
        'GPU, driverstatus en apparaatproblemen'

    $scroll =
        New-Object System.Windows.Controls.ScrollViewer

    $scroll.VerticalScrollBarVisibility =
        'Auto'

    $stack =
        New-Object System.Windows.Controls.StackPanel

    $stack.Margin =
        '0,0,16,16'

    $gpu =
        @(Get-GPUInfo)

    $problems =
        @(Get-ProblemDevices)

    $stack.Children.Add(
        (T `
            'Graphics / GPU' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    foreach ($g in $gpu) {

        $b =
            New-Object System.Windows.Controls.Border

        $b.Background =
            New-Brush '#17131E'

        $b.BorderBrush =
            New-Brush '#2C2635'

        $b.BorderThickness =
            '1'

        $b.CornerRadius =
            '14'

        $b.Padding =
            '15'

        $b.Margin =
            '0,0,0,10'

        $txt =
@"
GPU: $($g.Name)
Driver: $($g.DriverVersion)
Status: $($g.Status)
"@

        $b.Child =
            T `
                $txt `
                12 `
                'Normal' `
                '#EFEAF6'

        $stack.Children.Add(
            $b
        ) | Out-Null
    }

    if ($gpu.Count -eq 0) {

        $stack.Children.Add(
            (T `
                'Geen GPU-record gevonden.' `
                12 `
                'Normal' `
                '#958A9F')
        ) | Out-Null
    }

    $stack.Children.Add(
        (T `
            'Apparaatproblemen' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    if ($problems.Count -eq 0) {

        $stack.Children.Add(
            (T `
                '✓ Geen ConfigManager-fouten gevonden.' `
                12 `
                'SemiBold' `
                '#9FDEA8')
        ) | Out-Null
    }
    else {

        foreach ($p in $problems) {

            $stack.Children.Add(
                (T `
                    "⚠ $($p.Name) — foutcode $($p.ConfigManagerErrorCode)" `
                    12 `
                    'Normal' `
                    '#F0B8C6')
            ) | Out-Null
        }
    }

    $buttons =
        New-Object System.Windows.Controls.WrapPanel

    $buttons.Margin =
        '0,14,0,0'

    $buttons.Children.Add(
        (Add-Button `
            'Driver check verversen' `
            {
                Show-Drivers
            } `
            190 `
            '↻')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Apparaatbeheer' `
            {
                Open-DeviceManager
            } `
            175 `
            '▣')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Windows Update' `
            {
                Open-WindowsUpdate
            } `
            170 `
            '↓')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Update scan' `
            {
                Start-WindowsUpdateScan
            } `
            160 `
            '⟳')
    ) | Out-Null

    $stack.Children.Add(
        $buttons
    ) | Out-Null

    $note =
        T `
            'FreddoDev forceert geen willekeurige fabrikant-drivers. De app leest je hardware en driverstatus uit en gebruikt Windows Update/Apparaatbeheer voor compatibele updates.' `
            11 `
            'Normal' `
            '#8D8397'

    $note.Margin =
        '0,6,0,0'

    $stack.Children.Add(
        $note
    ) | Out-Null

    $scroll.Content =
        $stack

    $script:App.PageHost.Children.Add(
        $scroll
    ) | Out-Null
}

# ============================================================
# TOOLS
# ============================================================

function Show-Tools {

    Clear-Page

    Set-PageHeader `
        'Tools' `
        'Repareren, resetten, opschonen en beheren'

    $scroll =
        New-Object System.Windows.Controls.ScrollViewer

    $scroll.VerticalScrollBarVisibility =
        'Auto'

    $stack =
        New-Object System.Windows.Controls.StackPanel

    $stack.Margin =
        '0,0,16,16'

    # REPAIR

    $stack.Children.Add(
        (T `
            'Repair' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    $repair =
        New-Object System.Windows.Controls.WrapPanel

    $repair.Children.Add(
        (Add-Button `
            'Smart Fix' `
            {
                Invoke-SmartFix
            } `
            180 `
            '⚡')
    ) | Out-Null

    $repair.Children.Add(
        (Add-Button `
            'DISM RestoreHealth' `
            {

                if (-not (
                    Ask-Confirm `
                        'DISM' `
                        'DISM kan Windows-componenten herstellen. Doorgaan?'
                )) {
                    return
                }

                if (-not (Test-IsAdmin)) {

                    [void](
                        Invoke-ElevatedSelf `
                            '-Dism'
                    )

                    return
                }

                [void](Run-DismHealth)

            } `
            190 `
            '✓')
    ) | Out-Null

    $repair.Children.Add(
        (Add-Button `
            'SFC Scan' `
            {

                if (-not (
                    Ask-Confirm `
                        'SFC' `
                        'SFC /SCANNOW controleert systeembestanden. Doorgaan?'
                )) {
                    return
                }

                if (-not (Test-IsAdmin)) {

                    [void](
                        Invoke-ElevatedSelf `
                            '-Sfc'
                    )

                    return
                }

                [void](Run-SfcScan)

            } `
            170 `
            '✓')
    ) | Out-Null

    $stack.Children.Add(
        $repair
    ) | Out-Null

    # CLEANUP

    $stack.Children.Add(
        (T `
            'Cleanup' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    $cleanup =
        New-Object System.Windows.Controls.WrapPanel

    $cleanup.Children.Add(
        (Add-Button `
            'Temp Cleanup' `
            {
                Invoke-TempCleanup
            } `
            170 `
            '⌫')
    ) | Out-Null

    $cleanup.Children.Add(
        (Add-Button `
            'Prullenbak legen' `
            {
                Invoke-RecycleBinCleanup
            } `
            175 `
            '⌫')
    ) | Out-Null

    $stack.Children.Add(
        $cleanup
    ) | Out-Null

    # NETWORK

    $stack.Children.Add(
        (T `
            'Network' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    $network =
        New-Object System.Windows.Controls.WrapPanel

    $network.Children.Add(
        (Add-Button `
            'Netwerk diagnose' `
            {
                Run-HealthQuickScan
            } `
            185 `
            '⌁')
    ) | Out-Null

    $network.Children.Add(
        (Add-Button `
            'DNS / Winsock reset' `
            {
                Invoke-NetworkReset
            } `
            195 `
            '↻')
    ) | Out-Null

    $stack.Children.Add(
        $network
    ) | Out-Null

    # SYSTEM

    $stack.Children.Add(
        (T `
            'System' `
            18 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    $system =
        New-Object System.Windows.Controls.WrapPanel

    $system.Children.Add(
        (Add-Button `
            'Startup apps' `
            {
                Open-StartupApps
            } `
            160 `
            '◉')
    ) | Out-Null

    $system.Children.Add(
        (Add-Button `
            'Windows Update' `
            {
                Open-WindowsUpdate
            } `
            170 `
            '↓')
    ) | Out-Null

    $system.Children.Add(
        (Add-Button `
            'Pc herstarten' `
            {
                Restart-PC
            } `
            170 `
            '⟳')
    ) | Out-Null

    $stack.Children.Add(
        $system
    ) | Out-Null

    $scroll.Content =
        $stack

    $script:App.PageHost.Children.Add(
        $scroll
    ) | Out-Null
}

# ============================================================
# LIVE CONSOLE
# ============================================================

function Show-Console {

    Clear-Page

    Set-PageHeader `
        'Live Console / Debug' `
        'Realtime output van FreddoDev'

    $grid =
        New-Object System.Windows.Controls.Grid

    $r1 =
        New-Object System.Windows.Controls.RowDefinition

    $r1.Height =
        'Auto'

    $grid.RowDefinitions.Add(
        $r1
    )

    $r2 =
        New-Object System.Windows.Controls.RowDefinition

    $grid.RowDefinitions.Add(
        $r2
    )

    $buttons =
        New-Object System.Windows.Controls.WrapPanel

    $buttons.Children.Add(
        (Add-Button `
            'Quick Health' `
            {
                Run-HealthQuickScan
            } `
            165 `
            '⌕')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Logbestand openen' `
            {
                Open-LocalLog
            } `
            175 `
            '▤')
    ) | Out-Null

    $buttons.Children.Add(
        (Add-Button `
            'Console wissen' `
            {

                if ($script:App.ConsoleBox) {

                    $script:App.ConsoleBox.Clear()
                }

            } `
            160 `
            '⌫')
    ) | Out-Null

    $grid.Children.Add(
        $buttons
    ) | Out-Null

    $tb =
        New-Object System.Windows.Controls.TextBox

    $tb.AcceptsReturn =
        $true

    $tb.IsReadOnly =
        $true

    $tb.VerticalScrollBarVisibility =
        'Auto'

    $tb.HorizontalScrollBarVisibility =
        'Auto'

    $tb.Background =
        New-Brush '#0B0A0F'

    $tb.Foreground =
        New-Brush '#DCD5E6'

    $tb.BorderBrush =
        New-Brush '#2D2635'

    $tb.BorderThickness =
        '1'

    $tb.FontFamily =
        'Consolas'

    $tb.FontSize =
        11

    $tb.Padding =
        '13'

    [System.Windows.Controls.Grid]::SetRow(
        $tb,
        1
    )

    $grid.Children.Add(
        $tb
    ) | Out-Null

    $script:App.ConsoleBox =
        $tb

    $script:App.PageHost.Children.Add(
        $grid
    ) | Out-Null

    Write-LiveLog `
        'Live console geopend.' `
        'OK'
}

# ============================================================
# BOT UI
# ============================================================

function Show-Bot {

    Clear-Page

    Set-PageHeader `
        '🤖 FreddoDevBot' `
        'Lokale hulp en opdrachten in natuurlijke taal'

    $grid =
        New-Object System.Windows.Controls.Grid

    $r1 =
        New-Object System.Windows.Controls.RowDefinition

    $grid.RowDefinitions.Add(
        $r1
    )

    $r2 =
        New-Object System.Windows.Controls.RowDefinition

    $r2.Height =
        'Auto'

    $grid.RowDefinitions.Add(
        $r2
    )

    $r3 =
        New-Object System.Windows.Controls.RowDefinition

    $r3.Height =
        'Auto'

    $grid.RowDefinitions.Add(
        $r3
    )

    $chat =
        New-Object System.Windows.Controls.TextBox

    $chat.AcceptsReturn =
        $true

    $chat.TextWrapping =
        'Wrap'

    $chat.VerticalScrollBarVisibility =
        'Auto'

    $chat.IsReadOnly =
        $true

    $chat.Background =
        New-Brush '#121018'

    $chat.Foreground =
        New-Brush '#F3EDF8'

    $chat.BorderBrush =
        New-Brush '#2D2636'

    $chat.BorderThickness =
        '1'

    $chat.Padding =
        '14'

    $chat.FontFamily =
        'Consolas'

    $chat.FontSize =
        12

    $chat.Text =
@"
🤖FreddoDevBot: Hoi!
Stel je vraag of geef een commando.

Voorbeelden:
- fix mijn pc
- maak schoon
- drivers
- graphics
- uptime
- update
- netwerk
- FiveM
- logs
- help

"@

    $script:App.BotChat =
        $chat

    [System.Windows.Controls.Grid]::SetRow(
        $chat,
        0
    )

    $grid.Children.Add(
        $chat
    ) | Out-Null

    $input =
        New-Object System.Windows.Controls.TextBox

    $input.Height =
        44

    $input.Margin =
        '0,10,0,0'

    $input.Padding =
        '12,10'

    $input.Background =
        New-Brush '#15121B'

    $input.Foreground =
        New-Brush '#F5F1F8'

    $input.BorderBrush =
        New-Brush '#3A3047'

    $input.BorderThickness =
        '1'

    $input.FontSize =
        13

    $script:App.BotInput =
        $input

    [System.Windows.Controls.Grid]::SetRow(
        $input,
        1
    )

    $grid.Children.Add(
        $input
    ) | Out-Null

    # BUTTONS

    $buttons =
        New-Object System.Windows.Controls.WrapPanel

    $buttons.Margin =
        '0,10,0,0'

    $send =
        Add-Button `
            'Stuur' `
            {

                $question =
                    $script:App.BotInput.Text

                if (
                    [string]::IsNullOrWhiteSpace(
                        $question
                    )
                ) {
                    return
                }

                $reply =
                    Bot-Reply `
                        $question

                $script:App.BotChat.AppendText(
                    "Jij: $question`r`n" +
                    "🤖FreddoDevBot: $reply`r`n`r`n"
                )

                $script:App.BotChat.ScrollToEnd()

                $script:App.BotInput.Clear()

            } `
            130 `
            '→'

    $buttons.Children.Add(
        $send
    ) | Out-Null

    $quickButtons = @(
        @('Fix mijn pc','fix mijn pc'),
        @('Maak schoon','maak schoon'),
        @('Drivers','drivers'),
        @('Graphics','graphics'),
        @('Uptime','uptime'),
        @('Netwerk','netwerk'),
        @('FiveM','fivem'),
        @('Help','help')
    )

    foreach ($q in $quickButtons) {

        $txt =
            $q[1]

        $btn =
            Add-Button `
                $q[0] `
                {

                    $reply =
                        Bot-Reply `
                            $txt

                    $script:App.BotChat.AppendText(
                        "Jij: $txt`r`n" +
                        "🤖FreddoDevBot: $reply`r`n`r`n"
                    )

                    $script:App.BotChat.ScrollToEnd()

                } `
                125 `
                '•'

        $buttons.Children.Add(
            $btn
        ) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetRow(
        $buttons,
        2
    )

    $grid.Children.Add(
        $buttons
    ) | Out-Null

    $input.Add_KeyDown({
        param(
            $sender,
            $e
        )

        if (
            $e.Key -eq
            [System.Windows.Input.Key]::Enter
        ) {

            if (
                [System.Windows.Input.Keyboard]::IsKeyDown(
                    [System.Windows.Input.Key]::LeftCtrl
                ) -or
                [System.Windows.Input.Keyboard]::IsKeyDown(
                    [System.Windows.Input.Key]::RightCtrl
                )
            ) {

                $question =
                    $script:App.BotInput.Text

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $question
                    )
                ) {

                    $reply =
                        Bot-Reply `
                            $question

                    $script:App.BotChat.AppendText(
                        "Jij: $question`r`n" +
                        "🤖FreddoDevBot: $reply`r`n`r`n"
                    )

                    $script:App.BotChat.ScrollToEnd()

                    $script:App.BotInput.Clear()
                }

                $e.Handled =
                    $true
            }
        }
    })

    $script:App.PageHost.Children.Add(
        $grid
    ) | Out-Null
}

# ============================================================
# PC INFO
# ============================================================

function Show-PCInfo {

    Clear-Page

    Set-PageHeader `
        'PC Info' `
        'Hardware, Windows en runtime-informatie'

    $scroll =
        New-Object System.Windows.Controls.ScrollViewer

    $scroll.VerticalScrollBarVisibility =
        'Auto'

    $stack =
        New-Object System.Windows.Controls.StackPanel

    $stack.Margin =
        '0,0,16,16'

    $os =
        Get-OSInfo

    $ram =
        Get-MemoryInfo

    $disk =
        Get-DiskInfo

    try {

        $cpuName =
            [string](
                Get-CimInstance Win32_Processor |
                Select-Object -First 1 -ExpandProperty Name
            )
    }
    catch {

        $cpuName =
            'Onbekend'
    }

    try {

        $board =
            [string](
                Get-CimInstance Win32_BaseBoard |
                Select-Object -First 1 -ExpandProperty Product
            )
    }
    catch {

        $board =
            'Onbekend'
    }

    try {

        $bios =
            [string](
                Get-CimInstance Win32_BIOS |
                Select-Object -First 1 -ExpandProperty SMBIOSBIOSVersion
            )
    }
    catch {

        $bios =
            'Onbekend'
    }

    $wrap =
        New-Object System.Windows.Controls.WrapPanel

    $wrap.Children.Add(
        (Add-Card `
            'COMPUTER' `
            $env:COMPUTERNAME `
            'Computernaam' `
            250)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'WINDOWS' `
            $os.Caption `
            "Build $($os.Build)" `
            290)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'CPU' `
            $cpuName `
            'Processor' `
            340)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'RAM' `
            "$($ram.TotalGB) GB" `
            "$($ram.UsedPercent)% in gebruik" `
            230)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'C: DRIVE' `
            "$($disk.TotalGB) GB" `
            "$($disk.FreeGB) GB vrij" `
            230)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'MOTHERBOARD' `
            $board `
            'Baseboard' `
            250)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'BIOS' `
            $bios `
            'SMBIOS version' `
            250)
    ) | Out-Null

    $wrap.Children.Add(
        (Add-Card `
            'UPTIME' `
            (Get-UptimeText) `
            'Sinds laatste boot' `
            230)
    ) | Out-Null

    $stack.Children.Add(
        $wrap
    ) | Out-Null

    $b =
        New-Object System.Windows.Controls.Border

    $b.Background =
        New-Brush '#17131E'

    $b.BorderBrush =
        New-Brush '#2C2635'

    $b.BorderThickness =
        '1'

    $b.CornerRadius =
        '15'

    $b.Padding =
        '16'

    $b.Margin =
        '0,2,0,0'

    $b.Child =
        T `
            "Laatste boot: $(if($os.LastBoot){$os.LastBoot.ToString('dd-MM-yyyy HH:mm:ss')}else{'Onbekend'})`nPowerShell: $($PSVersionTable.PSVersion)" `
            11 `
            'Normal' `
            '#A096AA'

    $stack.Children.Add(
        $b
    ) | Out-Null

    $scroll.Content =
        $stack

    $script:App.PageHost.Children.Add(
        $scroll
    ) | Out-Null
}

# ============================================================
# WINDOW XAML
# ============================================================

function Build-Window {

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FreddoDev"
        Width="1240"
        Height="790"
        MinWidth="1100"
        MinHeight="690"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        ResizeMode="CanResize"
        Background="#0C0A0F"
        FontFamily="Segoe UI">

  <Border
        CornerRadius="18"
        BorderBrush="#2A2531"
        BorderThickness="1"
        Background="#0C0A0F">

    <Grid>

      <Grid.ColumnDefinitions>

        <ColumnDefinition Width="228"/>

        <ColumnDefinition Width="*"/>

      </Grid.ColumnDefinitions>

      <!-- SIDEBAR -->

      <Border
            Grid.Column="0"
            Background="#111016">

        <StackPanel
            x:Name="Sidebar"
            Margin="12,0,12,0"/>

      </Border>

      <!-- MAIN -->

      <Grid
            Grid.Column="1"
            Background="#0F0D13">

        <Grid.RowDefinitions>

          <RowDefinition Height="76"/>

          <RowDefinition Height="*"/>

          <RowDefinition Height="32"/>

        </Grid.RowDefinitions>

        <!-- TOP BAR -->

        <Border
              x:Name="TopBar"
              Grid.Row="0"
              Background="#110F15"
              BorderBrush="#25202D"
              BorderThickness="0,0,0,1">

          <Grid Margin="20,0">

            <Grid.ColumnDefinitions>

              <ColumnDefinition Width="*"/>

              <ColumnDefinition Width="Auto"/>

            </Grid.ColumnDefinitions>

            <StackPanel
                Grid.Column="0"
                VerticalAlignment="Center">

              <TextBlock
                    x:Name="PageTitle"
                    Text="Dashboard"
                    FontSize="21"
                    FontWeight="Bold"
                    Foreground="#FFFFFF"/>

              <TextBlock
                    x:Name="PageSubtitle"
                    Text="Realtime systeemstatus"
                    FontSize="11"
                    Foreground="#8E8498"
                    Margin="0,3,0,0"/>

            </StackPanel>

            <StackPanel
                Grid.Column="1"
                Orientation="Horizontal"
                VerticalAlignment="Center">

              <Border
                    Background="#181520"
                    CornerRadius="9"
                    Padding="10,6"
                    Margin="0,0,10,0">

                <TextBlock
                      x:Name="StatusText"
                      Text="Ready"
                      FontSize="10"
                      Foreground="#AFA4BA"/>

              </Border>

              <Button
                    x:Name="MinButton"
                    Content="—"
                    Width="34"
                    Height="30"
                    Margin="0,0,5,0"
                    Background="#17131B"
                    Foreground="#C5BDCE"
                    BorderThickness="0"/>

              <Button
                    x:Name="CloseButton"
                    Content="✕"
                    Width="34"
                    Height="30"
                    Background="#28141B"
                    Foreground="#EEADBF"
                    BorderThickness="0"/>

            </StackPanel>

          </Grid>

        </Border>

        <!-- CONTENT -->

        <Border
              Grid.Row="1"
              Padding="20,17,20,10"
              Background="#0F0D13">

          <Grid>

            <!-- Background glow -->

            <Ellipse
                  x:Name="GlowOne"
                  Width="380"
                  Height="380"
                  Fill="#2A1654"
                  Opacity="0.15"
                  HorizontalAlignment="Right"
                  VerticalAlignment="Top"
                  IsHitTestVisible="False"/>

            <Ellipse
                  x:Name="GlowTwo"
                  Width="280"
                  Height="280"
                  Fill="#13204D"
                  Opacity="0.10"
                  HorizontalAlignment="Left"
                  VerticalAlignment="Bottom"
                  IsHitTestVisible="False"/>

            <Grid
                  x:Name="PageHost"/>

          </Grid>

        </Border>

        <!-- FOOTER -->

        <Border
              Grid.Row="2"
              Background="#0D0B11"
              BorderBrush="#25202D"
              BorderThickness="0,1,0,0">

          <TextBlock
                Text="FreddoDev • Windows toolkit • safe-by-default actions"
                FontSize="10"
                Foreground="#726A7C"
                Margin="12,7"/>

        </Border>

      </Grid>

    </Grid>

  </Border>

</Window>
'@

    return [
        System.Windows.Markup.XamlReader
    ]::Parse($xaml)
}

# ============================================================
# UI INITIALIZATION
# ============================================================

function Initialize-UI {

    $script:App.Window =
        Build-Window

    $script:App.PageHost =
        $script:App.Window.FindName(
            'PageHost'
        )

    $script:App.PageTitle =
        $script:App.Window.FindName(
            'PageTitle'
        )

    $script:App.PageSubtitle =
        $script:App.Window.FindName(
            'PageSubtitle'
        )

    $script:App.StatusText =
        $script:App.Window.FindName(
            'StatusText'
        )

    $sidebar =
        $script:App.Window.FindName(
            'Sidebar'
        )

    # LOGO

    $logoRow =
        New-Object System.Windows.Controls.StackPanel

    $logoRow.Orientation =
        'Horizontal'

    $logoRow.Margin =
        '8,18,8,22'

    $logo =
        New-Object System.Windows.Controls.Border

    $logo.Width =
        42

    $logo.Height =
        42

    $logo.CornerRadius =
        21

    $logo.Background =
        New-Brush '#7448C7'

    $logo.Child =
        T 'F' 23 'Bold' '#FFFFFF'

    $logoRow.Children.Add(
        $logo
    ) | Out-Null

    $ls =
        New-Object System.Windows.Controls.StackPanel

    $ls.Margin =
        '10,0,0,0'

    $ls.Children.Add(
        (T `
            'FreddoDev' `
            16 `
            'Bold' `
            '#FFFFFF')
    ) | Out-Null

    $ls.Children.Add(
        (T `
            'Windows 11 Toolkit' `
            9 `
            'Normal' `
            '#8A8192')
    ) | Out-Null

    $logoRow.Children.Add(
        $ls
    ) | Out-Null

    $sidebar.Children.Add(
        $logoRow
    ) | Out-Null

    # NAVIGATION

    $nav = @(
        @(
            'Dashboard',
            '⌂',
            { Show-Dashboard }
        ),

        @(
            'Windows Scan',
            '⌕',
            { Show-Scan }
        ),

        @(
            'Drivers & Graphics',
            '▦',
            { Show-Drivers }
        ),

        @(
            'Tools',
            '⚙',
            { Show-Tools }
        ),

        @(
            'Live Console',
            '▤',
            { Show-Console }
        ),

        @(
            '🤖 FreddoDevBot',
            '🤖',
            { Show-Bot }
        ),

        @(
            'PC Info',
            '▣',
            { Show-PCInfo }
        )
    )

    foreach ($n in $nav) {

        $sidebar.Children.Add(
            (
                Add-NavButton `
                    $n[0] `
                    $n[1] `
                    $n[2]
            )
        ) | Out-Null
    }

    # TIP

    $tip =
        New-Object System.Windows.Controls.Border

    $tip.Margin =
        '8,23,8,10'

    $tip.Padding =
        '12'

    $tip.CornerRadius =
        12

    $tip.Background =
        New-Brush '#17131E'

    $tip.Child =
        T `
            'Live status: CPU, RAM, disk en netwerk worden automatisch vernieuwd.' `
            10 `
            'Normal' `
            '#8C8295'

    $sidebar.Children.Add(
        $tip
    ) | Out-Null

    # WINDOW BUTTONS

    $close =
        $script:App.Window.FindName(
            'CloseButton'
        )

    $min =
        $script:App.Window.FindName(
            'MinButton'
        )

    $close.Add_Click({

        Write-LiveLog `
            'FreddoDev afgesloten.' `
            'INFO'

        $script:App.Window.Close()
    })

    $min.Add_Click({

        $script:App.Window.WindowState =
            'Minimized'
    })

    # WINDOW DRAG

    $top =
        $script:App.Window.FindName(
            'TopBar'
        )

    $top.Add_MouseLeftButtonDown({

        if (
            $_.Button -eq
            [System.Windows.Input.MouseButton]::Left
        ) {

            try {

                $script:App.Window.DragMove()
            }
            catch {}
        }
    })

    # GLOW ANIMATION 1

    $a1 =
        New-Object `
            System.Windows.Media.Animation.DoubleAnimation

    $a1.From =
        0.10

    $a1.To =
        0.21

    $a1.Duration =
        New-Object System.Windows.Duration(
            [TimeSpan]::FromSeconds(5)
        )

    $a1.AutoReverse =
        $true

    $a1.RepeatBehavior =
        [System.Windows.Media.Animation.RepeatBehavior]::Forever

    $script:App.Window.GlowOne.BeginAnimation(
        [System.Windows.UIElement]::OpacityProperty,
        $a1
    )

    # GLOW ANIMATION 2

    $a2 =
        New-Object `
            System.Windows.Media.Animation.DoubleAnimation

    $a2.From =
        0.07

    $a2.To =
        0.16

    $a2.Duration =
        New-Object System.Windows.Duration(
            [TimeSpan]::FromSeconds(6)
        )

    $a2.AutoReverse =
        $true

    $a2.RepeatBehavior =
        [System.Windows.Media.Animation.RepeatBehavior]::Forever

    $script:App.Window.GlowTwo.BeginAnimation(
        [System.Windows.UIElement]::OpacityProperty,
        $a2
    )

    # REALTIME TIMER

    $timer =
        New-Object `
            System.Windows.Threading.DispatcherTimer

    $timer.Interval =
        [TimeSpan]::FromSeconds(2)

    $timer.Add_Tick({

        try {

            $cpu =
                Get-CPUPercent

            $ram =
                Get-MemoryInfo

            $disk =
                Get-DiskInfo

            $net =
                Get-NetworkSnapshot

            if ($script:App.StatusText) {

                $script:App.StatusText.Text =
                    (
                        "CPU $cpu%  •  " +
                        "RAM $($ram.UsedPercent)%  •  " +
                        "C: $($disk.UsedPercent)%  •  " +
                        (
                            if ($net.Online) {
                                'ONLINE'
                            }
                            else {
                                'OFFLINE'
                            }
                        )
                    )
            }
        }
        catch {}
    })

    $script:App.Timer =
        $timer

    $script:App.Window.Add_Closed({

        try {

            $script:App.Timer.Stop()
        }
        catch {}
    })

    Write-LiveLog `
        'FreddoDev UI geïnitialiseerd.' `
        'OK'
}

# ============================================================
# START
# ============================================================

Write-LiveLog `
    '=== FREDDODEV START ===' `
    'INFO'

Write-LiveLog `
    "PowerShell $($PSVersionTable.PSVersion)" `
    'INFO'

Write-LiveLog `
    "Administrator: $(Test-IsAdmin)" `
    'INFO'

# ELEVATED ACTIONS FROM RELAUNCH

$elevatedAction = $null

if ($args.Count -gt 0) {

    $elevatedAction =
        $args[0]
}

# BUILD UI

Initialize-UI

Show-Dashboard

try {

    $script:App.Timer.Start()
}
catch {}

# HANDLE ELEVATED TASK

if ($elevatedAction) {

    switch ($elevatedAction) {

        '-Dism' {

            Start-Sleep -Milliseconds 500

            [void](
                Run-DismHealth
            )
        }

        '-Sfc' {

            Start-Sleep -Milliseconds 500

            [void](
                Run-SfcScan
            )
        }

        '-NetworkReset' {

            Start-Sleep -Milliseconds 500

            try {

                ipconfig.exe /flushdns |
                    ForEach-Object {
                        Write-LiveLog `
                            $_ `
                            'DEBUG'
                    }

                netsh.exe winsock reset |
                    ForEach-Object {
                        Write-LiveLog `
                            $_ `
                            'DEBUG'
                    }

                netsh.exe int ip reset |
                    ForEach-Object {
                        Write-LiveLog `
                            $_ `
                            'DEBUG'
                    }

                Write-LiveLog `
                    'Verhoogde netwerkreset klaar.' `
                    'OK'
            }
            catch {

                Write-LiveLog `
                    "Netwerkreset fout: $($_.Exception.Message)" `
                    'ERROR'
            }
        }

        '-UpdateScan' {

            Start-Sleep -Milliseconds 500

            try {

                Start-Process `
                    "$env:WINDIR\System32\UsoClient.exe" `
                    -ArgumentList 'StartScan' `
                    -WindowStyle Hidden | Out-Null

                Write-LiveLog `
                    'Verhoogde Windows Update scan uitgevoerd.' `
                    'OK'
            }
            catch {

                Write-LiveLog `
                    "Update scan mislukt: $($_.Exception.Message)" `
                    'ERROR'
            }
        }
    }
}

# SHOW APP

[void]$script:App.Window.ShowDialog()
