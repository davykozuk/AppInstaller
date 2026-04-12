[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName PresentationFramework

Import-Module "$PSScriptRoot\Services\LogService.psm1" -Force
Import-Module "$PSScriptRoot\Core\ConfigLoader.psm1" -Force
Import-Module "$PSScriptRoot\Core\Installer.psm1" -Force

# =========================
# LOAD UI
# =========================
[xml]$xaml = Get-Content "$PSScriptRoot\UI\MainWindow.xaml" -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SoftwareList = $window.FindName("SoftwareList")
$LogBox       = $window.FindName("LogBox")
$BtnInstall   = $window.FindName("BtnInstall")
$BtnScan      = $window.FindName("BtnScan")
$ChkSilent    = $window.FindName("ChkSilent")
$Loader       = $window.FindName("LoaderOverlay")

# =========================
# LOADER
# =========================
function Show-Loader {
    if ($Loader) { $Loader.Visibility = "Visible" }
}

function Hide-Loader {
    if ($Loader) { $Loader.Visibility = "Collapsed" }
}
function Refresh-UI {
    Initialize-UI
}
# =========================
# DATA
# =========================
$script:apps  = Get-SoftwareConfig -Path "$PSScriptRoot\Config\apps.json"
$script:state = @{}

# =========================
# UI BUILD
# =========================
function Initialize-UI {

    $SoftwareList.Children.Clear()

    $groups = $script:apps | Group-Object Category

    foreach ($group in $groups) {

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $group.Name
        $lbl.FontWeight = "Bold"
        $lbl.Margin = "5,10,0,5"
        $lbl.Foreground = "#2C3E50"

        $SoftwareList.Children.Add($lbl) | Out-Null

        foreach ($app in $group.Group) {

            # ===== RECUP INFO =====
            $info = $null
            if ($script:state.ContainsKey($app.Id)) {
                $info = $script:state[$app.Id]
            }

            # ===== GRID =====
            $grid = New-Object System.Windows.Controls.Grid
            $grid.Margin = "5"

            $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
            $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
            $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))

            # ===== CHECKBOX =====
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $app
            $cb.Content = $app.Name
            $cb.IsChecked = $false

            if ($info -and $info.Installed) {
                $cb.IsChecked = $true
                $cb.IsEnabled = $false
                $cb.Content += " (installe $($info.Version))"
                $cb.Foreground = "Gray"
            }

            [System.Windows.Controls.Grid]::SetColumn($cb,0)

            # ===== UPDATE BADGE =====
            if ($info -and $info.Update) {

    $btnUpdate = New-Object System.Windows.Controls.Button
    $btnUpdate.Content = "⬆"
    $btnUpdate.Foreground = "#F39C12"
    $btnUpdate.Background = "Transparent"
    $btnUpdate.BorderThickness = 0
    $btnUpdate.Tag = $app

    $btnUpdate.Add_Click({
        param($s,$e)

        Show-Loader
        Update-Software -App $s.Tag -LogBox $LogBox
        Hide-Loader

        Refresh-UI
    })

    [System.Windows.Controls.Grid]::SetColumn($btnUpdate,1)
    $grid.Children.Add($btnUpdate) | Out-Null
}

            # ===== DELETE =====
            if ($info -and $info.Installed) {
                $btnDel = New-Object System.Windows.Controls.Button
                $btnDel.Content = "🗑"
                $btnDel.Foreground = "#E74C3C"
                $btnDel.Background = "Transparent"
                $btnDel.BorderThickness = 0
                $btnDel.Tag = $app

                $btnDel.Add_Click({
                    param($s,$e)

                    Uninstall-SoftwareList -SoftwareList @($s.Tag) -LogBox $LogBox

                    Refresh-UI
                })

                [System.Windows.Controls.Grid]::SetColumn($btnDel,2)
                $grid.Children.Add($btnDel) | Out-Null
            }

            # ===== AJOUT =====
            $grid.Children.Add($cb) | Out-Null
            $SoftwareList.Children.Add($grid) | Out-Null
        }
    }
}

# =========================
# SCAN
# =========================
$BtnScan.Add_Click({

    try {
        Show-Loader
        Write-Log "Scan en cours..." "INFO" $LogBox

        $script:state.Clear()

        foreach ($app in $script:apps) {

            Write-Log "Scan $($app.Name)..." "INFO" $LogBox
            $window.Dispatcher.Invoke([action]{}, "Background")

            $info = Get-SoftwareInfo -Id $app.Id
            $script:state[$app.Id] = $info

            Write-Log "$($app.Name) -> Installed=$($info.Installed) Version=$($info.Version) Update=$($info.Update)" "INFO" $LogBox
        }

        Initialize-UI

        Write-Log "Scan termine" "INFO" $LogBox
    }
    finally {
        Hide-Loader
    }
})

# =========================
# INSTALL
# =========================
$BtnInstall.Add_Click({

    $list = @()

    foreach ($grid in $SoftwareList.Children | Where-Object { $_ -is [System.Windows.Controls.Grid] }) {

        $cb = $grid.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }

        if ($cb -and $cb.IsChecked -and $cb.IsEnabled) {

            $info = $script:state[$cb.Tag.Id]

            # 🔥 CRITIQUE : on ignore updates
            if ($info.Update -eq $true) {
                Write-Log "$($cb.Tag.Name) ignore (update)" "INFO" $LogBox
                continue
            }

            if ($info.Installed -eq $false) {
                $list += $cb.Tag
            }
        }
    }

    if ($list.Count -eq 0) {
        Write-Log "Aucun logiciel a installer" "WARN" $LogBox
        return
    }

    Show-Loader
    Install-SoftwareList -SoftwareList $list -Silent $ChkSilent.IsChecked -LogBox $LogBox
    Hide-Loader
})

# =========================
# INIT
# =========================
Initialize-UI
$window.ShowDialog()