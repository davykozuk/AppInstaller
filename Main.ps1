# Gestion du chemin compatible EXE + Script
if ($MyInvocation.MyCommand.Path -and (Test-Path $MyInvocation.MyCommand.Path)) {
    # Mode script (.ps1)
    $script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    # Mode EXE (PS2EXE)
    $script:BasePath = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

Set-Location $script:BasePath

if ($Host.Name -eq "ConsoleHost") {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}

Add-Type -AssemblyName PresentationFramework

Import-Module "$script:BasePath\Services\LogService.psm1" -Force
Import-Module "$script:BasePath\Core\ConfigLoader.psm1" -Force
Import-Module "$script:BasePath\Core\Installer.psm1" -Force

[xml]$xaml = Get-Content "$script:BasePath\UI\MainWindow.xaml" -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SoftwareList  = $window.FindName("SoftwareList")
$LogBox        = $window.FindName("LogBox")
$BtnInstall    = $window.FindName("BtnInstall")
$BtnScan       = $window.FindName("BtnScan")
$ChkSilent     = $window.FindName("ChkSilent")
$Loader        = $window.FindName("LoaderOverlay")
$LoaderText    = $window.FindName("LoaderText")
$TxtSearch     = $window.FindName("TxtSearch")
$BtnSelectAll  = $window.FindName("BtnSelectAll")
$BtnDeselectAll= $window.FindName("BtnDeselectAll")
$BtnClearLog   = $window.FindName("BtnClearLog")
$TxtStatus     = $window.FindName("TxtStatus")
$TxtInstalled  = $window.FindName("TxtInstalled")
$TxtAvailable  = $window.FindName("TxtAvailable")
$TxtUpdates    = $window.FindName("TxtUpdates")
$ProgressBar   = $window.FindName("ProgressBar")

# ─────────────────────────────────────────────
#  HELPERS LOADER
# ─────────────────────────────────────────────
function Show-Loader {
    param([string]$Text = "Chargement...")
    $LoaderText.Text = $Text
    $Loader.Visibility = "Visible"
}
function Hide-Loader { $Loader.Visibility = "Collapsed" }

function Update-StatusBar {
    $installed = ($script:state.Values | Where-Object { $_.Installed }).Count
    $updates   = ($script:state.Values | Where-Object { $_.Update   }).Count
    $total     = $script:apps.Count

    $TxtInstalled.Text = "$installed installes"
    $TxtAvailable.Text = "$($total - $installed) disponibles"
    $TxtUpdates.Text   = if ($updates -gt 0) { "$updates mise(s) a jour" } else { "" }
}

# ─────────────────────────────────────────────
#  DONNEES
# ─────────────────────────────────────────────
$script:apps = Get-SoftwareConfig -Path "$script:BasePath\Config\apps.json"
$script:state = @{}

# ─────────────────────────────────────────────
#  CONSTRUCTION DE LA LISTE
# ─────────────────────────────────────────────
function Initialize-UI {
    param([string]$Filter = "")

    $SoftwareList.Children.Clear()

    $groups = $script:apps |
        Where-Object { $Filter -eq "" -or $_.Name -like "*$Filter*" -or $_.Category -like "*$Filter*" } |
        Group-Object Category

    foreach ($group in $groups) {

        # ── En-tête de catégorie ──────────────────────
        $catBorder = New-Object System.Windows.Controls.Border
        $catBorder.Background    = "#EBF5FB"
        $catBorder.CornerRadius  = "6"
        $catBorder.Margin        = "0,10,0,4"
        $catBorder.Padding       = "8,4"

        $catLabel = New-Object System.Windows.Controls.TextBlock
        $catLabel.Text       = $group.Name.ToUpper()
        $catLabel.FontSize   = 11
        $catLabel.FontWeight = "Bold"
        $catLabel.Foreground = "#2980B9"

        $catBorder.Child = $catLabel
        [void]$SoftwareList.Children.Add($catBorder)

        # ── Apps de la catégorie ──────────────────────
        foreach ($app in $group.Group) {

            if (-not $script:state.ContainsKey($app.Id)) {
                $script:state[$app.Id] = @{ Installed = $false; Version = ""; Update = $false }
            }

            $info = $script:state[$app.Id]

            # Row container avec hover
            $rowBorder = New-Object System.Windows.Controls.Border
            $rowBorder.CornerRadius = "6"
            $rowBorder.Margin       = "0,1"
            $rowBorder.Padding      = "6,5"
            $rowBorder.Background   = "Transparent"

            $rowBorder.Add_MouseEnter({
                param($s,$e)
                $s.Background = "#F4F6F9"
            })
            $rowBorder.Add_MouseLeave({
                param($s,$e)
                $s.Background = "Transparent"
            })

            $grid = New-Object System.Windows.Controls.Grid

            $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "3*"
            $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "110"
            $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = "32"
            $c4 = New-Object System.Windows.Controls.ColumnDefinition; $c4.Width = "32"
            [void]$grid.ColumnDefinitions.Add($c1)
            [void]$grid.ColumnDefinitions.Add($c2)
            [void]$grid.ColumnDefinitions.Add($c3)
            [void]$grid.ColumnDefinitions.Add($c4)

            # Checkbox / nom
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag     = $app
            $cb.Content = $app.Name
            $cb.ToolTip = "ID : $($app.Id)"
            $cb.MaxWidth = 340
            $cb.HorizontalAlignment = "Left"

            if ($info.Installed) {
                $cb.IsChecked = $true
                $cb.IsEnabled = $false
                $cb.Foreground = "#95A5A6"
            }

            [System.Windows.Controls.Grid]::SetColumn($cb, 0)
            [void]$grid.Children.Add($cb)

            # Version
            if ($info.Installed -and $info.Version) {
                $txt = New-Object System.Windows.Controls.TextBlock
                $txt.Text      = $info.Version
                $txt.Foreground = "#95A5A6"
                $txt.FontStyle  = "Italic"
                $txt.FontSize   = 11
                $txt.Margin    = "6,0"
                $txt.VerticalAlignment = "Center"
                [System.Windows.Controls.Grid]::SetColumn($txt, 1)
                [void]$grid.Children.Add($txt)
            }

            # Bouton update
            if ($info.Update) {
                $btnU = New-Object System.Windows.Controls.Button
                $btnU.Content    = [char]0x2B06   # ⬆
                $btnU.Foreground = "#F39C12"
                $btnU.Tag        = $app
                $btnU.ToolTip    = "Mettre a jour $($app.Name)"
                $btnU.Style      = $window.Resources["IconBtn"]

                $btnU.Add_Click({
                    param($s,$e)
                    Show-Loader "Mise a jour..."
                    Update-Software -App $s.Tag -LogBox $LogBox
                    Hide-Loader
                    $BtnScan.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new(
                            [System.Windows.Controls.Button]::ClickEvent
                        )
                    )
                })

                [System.Windows.Controls.Grid]::SetColumn($btnU, 2)
                [void]$grid.Children.Add($btnU)
            }

            # Bouton suppression
            if ($info.Installed) {
                $btnD = New-Object System.Windows.Controls.Button
                $btnD.Content = "X"
                $btnD.Foreground = "#E74C3C"
                $btnD.Tag        = $app
                $btnD.ToolTip    = "Desinstaller $($app.Name)"
                $btnD.Style      = $window.Resources["IconBtn"]

                $btnD.Add_Click({
                    param($s,$e)
                    Show-Loader "Desinstallation..."
                    Uninstall-SoftwareList -SoftwareList @($s.Tag) -LogBox $LogBox
                    Hide-Loader
                    $BtnScan.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new(
                            [System.Windows.Controls.Button]::ClickEvent
                        )
                    )
                })

                [System.Windows.Controls.Grid]::SetColumn($btnD, 3)
                [void]$grid.Children.Add($btnD)
            }

            $rowBorder.Child = $grid
            [void]$SoftwareList.Children.Add($rowBorder)
        }
    }

    Update-StatusBar
}

# ─────────────────────────────────────────────
#  SCAN  (winget list UNE SEULE FOIS)
# ─────────────────────────────────────────────
$BtnScan.Add_Click({
    Show-Loader "Scan en cours..."
    Write-Log "=== Scan demarre ===" "INFO" $LogBox
    $TxtStatus.Text = "Scan en cours..."

    $script:state.Clear()

    # Une seule invocation winget list => tres rapide
    Write-Log "Recuperation de la liste winget..." "INFO" $LogBox
    $snapshot = Get-WingetListSnapshot

    $total = $script:apps.Count
    $i = 0

    foreach ($app in $script:apps) {
        [void]$i++
        $pct = [int](($i / $total) * 100)
        $ProgressBar.Visibility = "Visible"
        $ProgressBar.Value      = $pct

        $info = Get-SoftwareInfo -Id $app.Id -Snapshot $snapshot
        $script:state[$app.Id] = $info

        if ($info.Installed) {
            $v = if ($info.Version) { " v$($info.Version)" } else { "" }
            Write-Log "$($app.Name)$v - installe$(if($info.Update){' [MAJ dispo]'})" "OK" $LogBox
        }
    }

    $ProgressBar.Visibility = "Collapsed"

    Initialize-UI -Filter $TxtSearch.Text
    Write-Log "=== Scan termine ===" "INFO" $LogBox
    $TxtStatus.Text = "Scan termine"
    Hide-Loader
})

# ─────────────────────────────────────────────
#  INSTALLATION
# ─────────────────────────────────────────────
$BtnInstall.Add_Click({

    $list = @()

    foreach ($child in $SoftwareList.Children) {
        $grid = $null

        # Chercher le Grid dans le Border de la row
        if ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.Grid]) {
            $grid = $child.Child
        }

        if (-not $grid) { continue }

        $cb = $grid.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }
        if ($cb -and $cb.IsChecked -and $cb.IsEnabled) {
            $info = $script:state[$cb.Tag.Id]
            if ($info -and -not $info.Installed -and -not $info.Update) {
                $list += $cb.Tag
            }
        }
    }

    if ($list.Count -eq 0) {
        Write-Log "Aucun logiciel a installer selectionne." "WARN" $LogBox
        return
    }

    Write-Log "=== Debut installation ($($list.Count) logiciels) ===" "INFO" $LogBox
    Show-Loader "Installation en cours..."
    Install-SoftwareList -SoftwareList $list -Silent $ChkSilent.IsChecked -LogBox $LogBox
    Hide-Loader
    Write-Log "=== Installation terminee ===" "INFO" $LogBox

    # Rescan auto
    $BtnScan.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
})

# ─────────────────────────────────────────────
#  RECHERCHE EN TEMPS REEL
# ─────────────────────────────────────────────
$TxtSearch.Add_TextChanged({
    Initialize-UI -Filter $TxtSearch.Text
})

# ─────────────────────────────────────────────
#  SELECTION / DESELECTION GLOBALE
# ─────────────────────────────────────────────
$BtnSelectAll.Add_Click({
    foreach ($child in $SoftwareList.Children) {
        if ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.Grid]) {
            $cb = $child.Child.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }
            if ($cb -and $cb.IsEnabled) { $cb.IsChecked = $true }
        }
    }
})

$BtnDeselectAll.Add_Click({
    foreach ($child in $SoftwareList.Children) {
        if ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.Grid]) {
            $cb = $child.Child.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }
            if ($cb -and $cb.IsEnabled) { $cb.IsChecked = $false }
        }
    }
})

# ─────────────────────────────────────────────
#  EFFACER LES LOGS
# ─────────────────────────────────────────────
$BtnClearLog.Add_Click({
    $LogBox.Clear()
    Write-Log "Console effacee." "INFO" $LogBox
})

# ─────────────────────────────────────────────
#  LANCEMENT
# ─────────────────────────────────────────────
Initialize-UI

# ASCII
Write-Log "Version 2.0.0 - Davy" "DEBUG" $LogBox      
Write-Log "  ___ _   _ _____ ___  ____  ____   _   _ ____  " "INFO" $LogBox
Write-Log " |_ _| \ | |  ___/ _ \|  _ \/ ___| | | | |  _ \ " "INFO" $LogBox
Write-Log "  | ||  \| | |_ | | | | |_) \___ \ | | | | | | |" "INFO" $LogBox
Write-Log "  | || |\  |  _|| |_| |  _ < ___) || |_| | |_| |" "INFO" $LogBox
Write-Log " |___|_| \_|_|   \___/|_| \_\____/  \___/|____/ " "INFO" $LogBox
write-Log "    I N F O R S U D - T E C H N O L O G I E S   " "INFO" $LogBox
write-Log "     https://www.inforsud-technologies.com"              "INFO" $LogBox
$TxtStatus.Text = "Cliquez sur Scanner pour demarrer"
Write-Log "AppInstaller demarre." "INFO" $LogBox

[void]$window.ShowDialog()
