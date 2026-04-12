Add-Type -AssemblyName PresentationFramework

# =========================
# Nettoyage modules
# =========================
Get-Module ConfigLoader, Installer, WinGetService, LogService, WingetInstaller | Remove-Module -Force -ErrorAction SilentlyContinue

# =========================
# Imports
# =========================
Import-Module "$PSScriptRoot\Services\LogService.psm1" -Force
Import-Module "$PSScriptRoot\Services\WinGetService.psm1" -Force
Import-Module "$PSScriptRoot\Core\ConfigLoader.psm1" -Force
Import-Module "$PSScriptRoot\Core\Installer.psm1" -Force
Import-Module "$PSScriptRoot\Services\WingetInstaller.psm1" -Force

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =========================
# UI
# =========================
[xml]$xaml = Get-Content "$PSScriptRoot\UI\MainWindow.xaml" -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SoftwareList = $window.FindName("SoftwareList")
$LogBox       = $window.FindName("LogBox")
$BtnInstall   = $window.FindName("BtnInstall")
$ChkSilent    = $window.FindName("ChkSilent")

$script:checkboxes = @()
$script:apps = @()

# =========================
# WinGet check
# =========================
if (-not (Test-WinGet)) {

    Write-Log "WinGet absent - installation..." "WARN" $LogBox

    Install-WinGet -LogBox $LogBox
    Start-Sleep 3

    if (-not (Test-WinGet)) {
        [System.Windows.MessageBox]::Show("WinGet non disponible", "Erreur", "OK", "Error")
        exit
    }
}

# =========================
# Load apps
# =========================
function Load-Applications {

    $SoftwareList.Children.Clear()
    $script:checkboxes = @()

    $path = Join-Path $PSScriptRoot "Config\apps.json"
    $script:apps = Get-SoftwareConfig -Path $path

    $groups = $script:apps | Group-Object Category | Sort-Object Name

    foreach ($group in $groups) {

        # ===== Category label =====
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $group.Name.ToUpper()
        $lbl.FontWeight = "Bold"
        $lbl.FontSize = 14
        $lbl.Margin = "5,10,0,5"

        $SoftwareList.Children.Add($lbl) | Out-Null

        foreach ($app in $group.Group) {

            # ===== Grid propre =====
            $panel = New-Object System.Windows.Controls.Grid
            $panel.Margin = "5,2,5,2"

            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = "*"

            $col2 = New-Object System.Windows.Controls.ColumnDefinition
            $col2.Width = "40"

            $col3 = New-Object System.Windows.Controls.ColumnDefinition
            $col3.Width = "50"

            $panel.ColumnDefinitions.Add($col1)
            $panel.ColumnDefinitions.Add($col2)
            $panel.ColumnDefinitions.Add($col3)

            # ===== Checkbox =====
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $app
            $cb.VerticalAlignment = "Center"

            [System.Windows.Controls.Grid]::SetColumn($cb, 0)

            # ===== Bouton uninstall =====
            $btnRemove = New-Object System.Windows.Controls.Button
            $btnRemove.Content = "X"
            $btnRemove.Width = 25
            $btnRemove.Height = 20
            $btnRemove.Background = "Red"
            $btnRemove.Foreground = "White"
            $btnRemove.Tag = $app

            $btnRemove.ToolTip = "Desinstaller $($app.Name)"

            [System.Windows.Controls.Grid]::SetColumn($btnRemove, 1)

            # ===== Bouton update =====
            $btnUpdate = New-Object System.Windows.Controls.Button
            $btnUpdate.Content = "Maj"
            $btnUpdate.Width = 35
            $btnUpdate.Height = 20
            $btnUpdate.Background = "Orange"
            $btnUpdate.Tag = $app

            $btnUpdate.ToolTip = "Mettre a jour $($app.Name)"

            [System.Windows.Controls.Grid]::SetColumn($btnUpdate, 2)

            # ===== Detection =====
            $isInstalled = Test-SoftwareInstalled -Id $app.Id

            if ($isInstalled) {

                $cb.Content = "$($app.Name) (installe)"
                $cb.Foreground = "Gray"
                $cb.IsChecked = $true
                $cb.IsEnabled = $false

                $btnRemove.Visibility = "Visible"
                $btnUpdate.Visibility = "Visible"
            }
            else {
                $cb.Content = $app.Name
                $cb.IsChecked = $false
                $cb.IsEnabled = $true

                $btnRemove.Visibility = "Collapsed"
                $btnUpdate.Visibility = "Collapsed"
            }

            Write-Log "Detection $($app.Name) : $isInstalled" "INFO" $LogBox

            # ===== UNINSTALL =====
            $btnRemove.Add_Click({
                param($btn, $evt)

                $appData = $btn.Tag

                $res = [System.Windows.MessageBox]::Show(
                    "Confirmer desinstallation de $($appData.Name) ?",
                    "Confirmation",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
                )

                if ($res -ne "Yes") { return }

                Uninstall-SoftwareList -SoftwareList @($appData) -LogBox $LogBox

                Load-Applications
            })

            # ===== UPDATE =====
            $btnUpdate.Add_Click({
                param($btn, $evt)

                $appData = $btn.Tag

                $res = [System.Windows.MessageBox]::Show(
                    "Mettre a jour $($appData.Name) ?",
                    "Confirmation",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question
                )

                if ($res -ne "Yes") { return }

                Write-Log "Maj $($appData.Name) en cours..." "INFO" $LogBox

                Start-Process "winget" `
                    -ArgumentList "upgrade --id $($appData.Id) --exact --accept-source-agreements --accept-package-agreements" `
                    -Wait `
                    -NoNewWindow

                Write-Log "$($appData.Name) mis a jour" "INFO" $LogBox

                Load-Applications
            })

            # ===== Ajout UI =====
            $panel.Children.Add($cb) | Out-Null
            $panel.Children.Add($btnRemove) | Out-Null
            $panel.Children.Add($btnUpdate) | Out-Null

            $SoftwareList.Children.Add($panel) | Out-Null
            $script:checkboxes += $cb
        }
    }

    Write-Log "Configuration chargee ($($script:apps.Count))" "INFO" $LogBox
}

# =========================
# INSTALL
# =========================
$BtnInstall.Add_Click({

    $selected = $script:checkboxes | Where-Object { $_.IsChecked }

    if ($selected.Count -eq 0) {
        Write-Log "Aucun logiciel selectionne" "WARN" $LogBox
        return
    }

    $list = @()

    foreach ($cb in $selected) {
        $app = $cb.Tag

        if (-not (Test-SoftwareInstalled -Id $app.Id)) {
            $list += $app
        }
    }

    if ($list.Count -eq 0) {
        Write-Log "Rien a installer" "WARN" $LogBox
        return
    }

    Write-Log "Installation en cours..." "INFO" $LogBox

    Install-SoftwareList -SoftwareList $list -Silent $ChkSilent.IsChecked -LogBox $LogBox

    Write-Log "Installation terminee" "INFO" $LogBox

    Load-Applications
})

# =========================
# START
# =========================
Load-Applications
$window.ShowDialog() | Out-Null