Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================
# Windows 11 Onderhoud GUI
# ==============================

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows 11 Onderhoud & Reparatie"
$Form.Size = New-Object System.Drawing.Size(720,650)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.BackColor = [System.Drawing.Color]::FromArgb(245,245,245)

# Titel
$Title = New-Object System.Windows.Forms.Label
$Title.Text = "Windows 11 Onderhoud & Reparatie"
$Title.Font = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
$Title.AutoSize = $true
$Title.Location = New-Object System.Drawing.Point(30,25)
$Form.Controls.Add($Title)

$Subtitle = New-Object System.Windows.Forms.Label
$Subtitle.Text = "Veilige onderhoudsfuncties voor een snellere en stabielere pc"
$Subtitle.AutoSize = $true
$Subtitle.Location = New-Object System.Drawing.Point(33,65)
$Form.Controls.Add($Subtitle)

# Logvenster
$Log = New-Object System.Windows.Forms.TextBox
$Log.Multiline = $true
$Log.ScrollBars = "Vertical"
$Log.ReadOnly = $true
$Log.Font = New-Object System.Drawing.Font("Consolas",9)
$Log.Location = New-Object System.Drawing.Point(30,400)
$Log.Size = New-Object System.Drawing.Size(645,170)
$Form.Controls.Add($Log)

function Log-Message($Message) {
    $Log.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
    $Log.SelectionStart = $Log.Text.Length
    $Log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Run-AdminCheck {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )

    if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        [System.Windows.Forms.MessageBox]::Show(
            "Start dit programma als Administrator.",
            "Administrator vereist",
            "OK",
            "Warning"
        )
        return $false
    }

    return $true
}

# ==============================
# OPSCHONEN
# ==============================

$CleanButton = New-Object System.Windows.Forms.Button
$CleanButton.Text = "🧹 Tijdelijke bestanden opruimen"
$CleanButton.Size = New-Object System.Drawing.Size(300,45)
$CleanButton.Location = New-Object System.Drawing.Point(30,110)

$CleanButton.Add_Click({

    if (-not (Run-AdminCheck)) { return }

    Log-Message "Opschonen gestart..."

    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    Log-Message "Tijdelijke bestanden verwijderd."

    [System.Windows.Forms.MessageBox]::Show(
        "Tijdelijke bestanden zijn opgeruimd.",
        "Klaar"
    )
})

$Form.Controls.Add($CleanButton)

# ==============================
# WINDOWS REPAREREN
# ==============================

$RepairButton = New-Object System.Windows.Forms.Button
$RepairButton.Text = "🔧 Windows repareren"
$RepairButton.Size = New-Object System.Drawing.Size(300,45)
$RepairButton.Location = New-Object System.Drawing.Point(350,110)

$RepairButton.Add_Click({

    if (-not (Run-AdminCheck)) { return }

    Log-Message "DISM component store repareren..."
    Start-Process "DISM.exe" `
        -ArgumentList "/Online /Cleanup-Image /RestoreHealth" `
        -Wait -NoNewWindow

    Log-Message "Systeembestanden controleren..."
    Start-Process "sfc.exe" `
        -ArgumentList "/scannow" `
        -Wait -NoNewWindow

    Log-Message "Windows reparatie voltooid."

    [System.Windows.Forms.MessageBox]::Show(
        "Windows reparatie is uitgevoerd.",
        "Klaar"
    )
})

$Form.Controls.Add($RepairButton)

# ==============================
# WINDOWS UPDATE
# ==============================

$UpdateButton = New-Object System.Windows.Forms.Button
$UpdateButton.Text = "⬆ Windows + drivers bijwerken"
$UpdateButton.Size = New-Object System.Drawing.Size(300,45)
$UpdateButton.Location = New-Object System.Drawing.Point(30,170)

$UpdateButton.Add_Click({

    if (-not (Run-AdminCheck)) { return }

    Log-Message "Windows Update wordt geopend..."

    Start-Process "ms-settings:windowsupdate"

    Log-Message "Controleer daar Windows Updates en optionele driverupdates."
})

$Form.Controls.Add($UpdateButton)

# ==============================
# SCHIJF
# ==============================

$DiskButton = New-Object System.Windows.Forms.Button
$DiskButton.Text = "💽 Schijf controleren"
$DiskButton.Size = New-Object System.Drawing.Size(300,45)
$DiskButton.Location = New-Object System.Drawing.Point(350,170)

$DiskButton.Add_Click({

    if (-not (Run-AdminCheck)) { return }

    Log-Message "C: wordt gecontroleerd..."

    Start-Process "chkdsk.exe" `
        -ArgumentList "C: /scan" `
        -Wait -NoNewWindow

    Log-Message "Schijfcontrole voltooid."

    [System.Windows.Forms.MessageBox]::Show(
        "Schijfcontrole is voltooid.",
        "Klaar"
    )
})

$Form.Controls.Add($DiskButton)

# ==============================
# OPSTARTPROGRAMMA'S
# ==============================

$StartupButton = New-Object System.Windows.Forms.Button
$StartupButton.Text = "🚀 Opstartprogramma's beheren"
$StartupButton.Size = New-Object System.Drawing.Size(300,45)
$StartupButton.Location = New-Object System.Drawing.Point(30,230)

$StartupButton.Add_Click({

    Start-Process "ms-settings:startupapps"

    Log-Message "Opstart-apps geopend."
})

$Form.Controls.Add($StartupButton)

# ==============================
# OPSLAG
# ==============================

$StorageButton = New-Object System.Windows.Forms.Button
$StorageButton.Text = "🗑 Windows Opslagbeheer"
$StorageButton.Size = New-Object System.Drawing.Size(300,45)
$StorageButton.Location = New-Object System.Drawing.Point(350,230)

$StorageButton.Add_Click({

    Start-Process "ms-settings:storagesense"

    Log-Message "Opslagbeheer geopend."
})

$Form.Controls.Add($StorageButton)

# ==============================
# VOLLEDIG ONDERHOUD
# ==============================

$FullButton = New-Object System.Windows.Forms.Button
$FullButton.Text = "⚡ VOLLEDIG VEILIG ONDERHOUD"
$FullButton.Font = New-Object System.Drawing.Font(
    "Segoe UI",11,[System.Drawing.FontStyle]::Bold
)
$FullButton.Size = New-Object System.Drawing.Size(620,55)
$FullButton.Location = New-Object System.Drawing.Point(30,300)

$FullButton.Add_Click({

    if (-not (Run-AdminCheck)) { return }

    $Answer = [System.Windows.Forms.MessageBox]::Show(
        "Dit voert meerdere onderhouds- en reparatiestappen uit.`n`n" +
        "Persoonlijke bestanden worden niet verwijderd.`n`n" +
        "Doorgaan?",
        "Volledig onderhoud",
        "YesNo",
        "Question"
    )

    if ($Answer -ne "Yes") { return }

    $FullButton.Enabled = $false

    try {

        Log-Message "=== VOLLEDIG ONDERHOUD GESTART ==="

        Log-Message "Tijdelijke bestanden opruimen..."
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        Log-Message "Windows Update-cache opruimen..."
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service bits -Force -ErrorAction SilentlyContinue

        Remove-Item `
            "C:\Windows\SoftwareDistribution\Download\*" `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        Start-Service bits -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue

        Log-Message "Windows componenten opruimen..."
        DISM /Online /Cleanup-Image /StartComponentCleanup

        Log-Message "Windows herstellen..."
        DISM /Online /Cleanup-Image /RestoreHealth

        Log-Message "Systeembestanden controleren..."
        sfc /scannow

        Log-Message "Schijf controleren..."
        chkdsk C: /scan

        Log-Message "=== ONDERHOUD KLAAR ==="

        [System.Windows.Forms.MessageBox]::Show(
            "Het onderhoud is voltooid.`n`n" +
            "Start Windows opnieuw op om de reparaties volledig toe te passen.",
            "Onderhoud voltooid",
            "OK",
            "Information"
        )

    }
    finally {
        $FullButton.Enabled = $true
    }
})

$Form.Controls.Add($FullButton)

# ==============================
# HERSTART
# ==============================

$RestartButton = New-Object System.Windows.Forms.Button
$RestartButton.Text = "🔄 Windows opnieuw opstarten"
$RestartButton.Size = New-Object System.Drawing.Size(300,45)
$RestartButton.Location = New-Object System.Drawing.Point(350,590)

$RestartButton.Add_Click({

    $Answer = [System.Windows.Forms.MessageBox]::Show(
        "Windows nu opnieuw opstarten?",
        "Herstart",
        "YesNo",
        "Question"
    )

    if ($Answer -eq "Yes") {
        Restart-Computer
    }
})

$Form.Controls.Add($RestartButton)

# ==============================
# START
# ==============================

Log-Message "Windows Onderhoud GUI gestart."
Log-Message "Persoonlijke bestanden worden niet verwijderd."
Log-Message "Kies een onderhoudsoptie hierboven."

[void]$Form.ShowDialog()
