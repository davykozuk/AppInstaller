[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName PresentationFramework

Import-Module "$PSScriptRoot\Services\LogService.psm1" -Force
Import-Module "$PSScriptRoot\Core\ConfigLoader.psm1" -Force
Import-Module "$PSScriptRoot\Core\Installer.psm1" -Force

# ================= UI =================
[xml]$xaml = Get-Content "$PSScriptRoot\UI\MainWindow.xaml" -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SoftwareList = $window.FindName("SoftwareList")
$LogBox       = $window.FindName("LogBox")
$BtnInstall   = $window.FindName("BtnInstall")
$BtnScan      = $window.FindName("BtnScan")
$ChkSilent    = $window.FindName("ChkSilent")
$Loader       = $window.FindName("LoaderOverlay")

# ================= LOADER =================
function Show-Loader { if ($Loader) { $Loader.Visibility = "Visible" } }
function Hide-Loader { if ($Loader) { $Loader.Visibility = "Collapsed" } }

# ================= DATA =================
$script:apps  = Get-SoftwareConfig -Path "$PSScriptRoot\Config\apps.json"
$script:state = @{}

# ================= UI =================
function Initialize-UI {

    $SoftwareList.Children.Clear()

    $groups = $script:apps | Group-Object Category

    foreach ($group in $groups) {

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $group.Name
        $lbl.FontWeight = "Bold"
        $lbl.Margin = "5,10,0,5"
        $SoftwareList.Children.Add($lbl)

        foreach ($app in $group.Group) {

            if (-not $script:state.ContainsKey($app.Id)) {
                $script:state[$app.Id] = @{
                    Installed = $false
                    Version   = ""
                    Update    = $false
                }
            }

            $info = $script:state[$app.Id]

            $grid = New-Object System.Windows.Controls.Grid
            $grid.Margin = "5"


            # NOM (large)
            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = "3*"

            # VERSION (fixe)
            $col2 = New-Object System.Windows.Controls.ColumnDefinition
            $col2.Width = "120"

            # UPDATE
            $col3 = New-Object System.Windows.Controls.ColumnDefinition
            $col3.Width = "40"

            # DELETE
            $col4 = New-Object System.Windows.Controls.ColumnDefinition
            $col4.Width = "40"

            $grid.ColumnDefinitions.Add($col1)
            $grid.ColumnDefinitions.Add($col2)
            $grid.ColumnDefinitions.Add($col3)
            $grid.ColumnDefinitions.Add($col4)

            # CHECKBOX
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $app
            $cb.Content = $app.Name
            $cb.IsChecked = $false

            if ($info.Installed) {
                $cb.IsChecked = $true
                $cb.IsEnabled = $false
                $cb.Content += " (installe $($info.Version))"
                $cb.Foreground = "Gray"
            }

            [System.Windows.Controls.Grid]::SetColumn($cb,0)

            # UPDATE
            if ($info.Update) {
                $btnUpdate = New-Object System.Windows.Controls.Button
                $btnUpdate.Content = "⬆"
                $btnUpdate.Foreground = "#F39C12"
                $btnUpdate.Background = "Transparent"
                $btnUpdate.BorderThickness = 0
                $btnUpdate.Tag = $app
                $btnUpdate.ToolTip = "Mettre a jour $($app.Name)"

                $btnUpdate.Add_Click({
                    param($s,$e)
                    Show-Loader
                    Update-Software -App $s.Tag -LogBox $LogBox
                    Hide-Loader
                    $BtnScan.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                })

                [System.Windows.Controls.Grid]::SetColumn($btnUpdate,2)
                $grid.Children.Add($btnUpdate)
            }

            # DELETE
            if ($info.Installed) {
                $btnDel = New-Object System.Windows.Controls.Button
                $btnDel.Content = "🗑"
                $btnDel.Foreground = "#E74C3C"
                $btnDel.Background = "Transparent"
                $btnDel.BorderThickness = 0
                $btnDel.Tag = $app
                $btnDel.ToolTip = "Desinstaller $($app.Name)"

                $btnDel.Add_Click({
                    param($s,$e)
                    Show-Loader
                    Uninstall-SoftwareList -SoftwareList @($s.Tag) -LogBox $LogBox
                    Hide-Loader
                    $BtnScan.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                })

                [System.Windows.Controls.Grid]::SetColumn($btnDel,3)
                $grid.Children.Add($btnDel)
            }

            $grid.Children.Add($cb)
            $SoftwareList.Children.Add($grid)
        }
    }
}

# ================= SCAN =================
$BtnScan.Add_Click({

    Show-Loader
    Write-Log "Scan en cours..." "INFO" $LogBox

    $script:state.Clear()

    foreach ($app in $script:apps) {

        Write-Log "Scan $($app.Name)..." "INFO" $LogBox

        $info = Get-SoftwareInfo -Id $app.Id
        $script:state[$app.Id] = $info
    }

    Initialize-UI
    Write-Log "Scan termine" "INFO" $LogBox

    Hide-Loader
})

# ================= INSTALL =================
$BtnInstall.Add_Click({

    $list = @()

    foreach ($grid in $SoftwareList.Children | Where-Object { $_ -is [System.Windows.Controls.Grid] }) {

        $cb = $grid.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }

        if ($cb -and $cb.IsChecked -and $cb.IsEnabled) {

            $info = $script:state[$cb.Tag.Id]

            if ($info.Update) {
                Write-Log "$($cb.Tag.Name) ignore (update)" "INFO" $LogBox
                continue
            }

            if (-not $info.Installed) {
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

# ================= INIT =================
Initialize-UI
$window.ShowDialog()