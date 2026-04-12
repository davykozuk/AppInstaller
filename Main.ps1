[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName PresentationFramework
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'
# =========================
# IMPORTS
# =========================
Import-Module "$PSScriptRoot\Services\LogService.psm1" -Force
Import-Module "$PSScriptRoot\Services\WinGetService.psm1" -Force
Import-Module "$PSScriptRoot\Core\ConfigLoader.psm1" -Force
Import-Module "$PSScriptRoot\Core\Installer.psm1" -Force
Import-Module "$PSScriptRoot\Services\WingetInstaller.psm1" -Force

# =========================
# UI LOAD
# =========================
[xml]$xaml = Get-Content "$PSScriptRoot\UI\MainWindow.xaml" -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$SoftwareList   = $window.FindName("SoftwareList")
$LogBox         = $window.FindName("LogBox")
$BtnInstall     = $window.FindName("BtnInstall")
$ChkSilent      = $window.FindName("ChkSilent")
$CategoryFilter = $window.FindName("CategoryFilter")
$Loader         = $window.FindName("LoaderOverlay")

$script:apps = @()
$script:checkboxes = @()

# =========================
# LOADER
# =========================
function Show-Loader { $Loader.Visibility = "Visible" }
function Hide-Loader { $Loader.Visibility = "Collapsed" }

# =========================
# LOAD APPS
# =========================
function Get-CategoryIcon {
    param($category)

    switch ($category) {
        "Navigateur" { "🌐" }
        "Bureautique" { "🧾" }
        "Utilitaires" { "🛠" }
        "Developpement" { "💻" }
        "Communication" { "💬" }
        "Support" { "🧑‍💻" }
        "Reseau" { "🌍" }
        "Runtime" { "⚙" }
        "default" { "📦" }
    }
}

function Load-Applications {

    $SoftwareList.Children.Clear()
    $script:checkboxes = @()

    $groups = $script:apps | Group-Object Category | Sort-Object Name

    foreach ($group in $groups) {

        # ===== TITRE CATEGORIE =====
        $lbl = New-Object System.Windows.Controls.TextBlock
        $icon = Get-CategoryIcon $group.Name

        $lbl.Text = "$icon  $($group.Name.ToUpper())"
        $lbl.FontWeight = "Bold"
        $lbl.FontSize = 16
        $lbl.Foreground = "#34495E"
        $lbl.Margin = "5,10,0,5"

        $SoftwareList.Children.Add($lbl) | Out-Null

        foreach ($app in $group.Group) {

            # ===== GRID =====
            $panel = New-Object System.Windows.Controls.Grid
            $panel.Margin = "10,2"

            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = "Auto"

            $col2 = New-Object System.Windows.Controls.ColumnDefinition
            $col2.Width = "35"

            $col3 = New-Object System.Windows.Controls.ColumnDefinition
            $col3.Width = "35"

            $panel.ColumnDefinitions.Add($col1)
            $panel.ColumnDefinitions.Add($col2)
            $panel.ColumnDefinitions.Add($col3)
            $panel.HorizontalAlignment = "Left" 
            # ===== CHECKBOX =====
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $app.Name
            $cb.Tag = $app
            $cb.VerticalAlignment = "Center"

            [System.Windows.Controls.Grid]::SetColumn($cb, 0)

            # ===== BOUTON DELETE =====
            $btnRemove = New-Object System.Windows.Controls.Button
            $btnRemove.Content = "🗑"
            $btnRemove.Width = 30
            $btnRemove.Height = 22
            $btnRemove.Background = "Transparent"
            $btnRemove.BorderThickness = 0
            $btnRemove.Tag = $app
            $btnRemove.ToolTip = "Desinstaller $($app.Name)"
            $btnRemove.Foreground = "#E74C3C"
            [System.Windows.Controls.Grid]::SetColumn($btnRemove, 1)

            # ===== BOUTON UPDATE =====
            $btnUpdate = New-Object System.Windows.Controls.Button
            $btnUpdate.Content = "⬆"
            $btnUpdate.Width = 30
            $btnUpdate.Height = 22
            $btnUpdate.Background = "Transparent"
            $btnUpdate.BorderThickness = 0
            $btnUpdate.Tag = $app
            $btnUpdate.ToolTip = "Mettre a jour $($app.Name)"
            $btnUpdate.Foreground = "#F39C12"
            [System.Windows.Controls.Grid]::SetColumn($btnUpdate, 2)

            # ===== DETECTION =====
            $isInstalled = Test-SoftwareInstalled -Id $app.Id

            if ($isInstalled) {
                $cb.IsChecked = $true
                $cb.IsEnabled = $false
                $cb.Foreground = "#95A5A6"   # gris doux

                $btnRemove.Visibility = "Visible"
                $btnUpdate.Visibility = "Visible"
            }
            else {
                $cb.IsChecked = $false
                $cb.IsEnabled = $true
                $cb.Foreground = "#2C3E50"

                $btnRemove.Visibility = "Collapsed"
                $btnUpdate.Visibility = "Collapsed"
            }

            # ===== UNINSTALL =====
            $btnRemove.Add_Click({
                param($btn,$e)

                $appData = $btn.Tag

                $res = [System.Windows.MessageBox]::Show(
                    "Desinstaller $($appData.Name) ?",
                    "Confirmation",
                    [System.Windows.MessageBoxButton]::YesNo
                )

                if ($res -ne "Yes") { return }

                Show-Loader
                Uninstall-SoftwareList -SoftwareList @($appData) -LogBox $LogBox
                Hide-Loader

                Load-Applications
            })

            # ===== UPDATE =====
            $btnUpdate.Add_Click({
                param($btn,$e)

                $appData = $btn.Tag

                Show-Loader

                Start-Process "winget" `
                    -ArgumentList "upgrade --id $($appData.Id) --exact --accept-source-agreements --accept-package-agreements" `
                    -Wait `
                    -NoNewWindow

                Hide-Loader
                Load-Applications
            })

            # ===== ADD =====
            $panel.Children.Add($cb) | Out-Null
            $panel.Children.Add($btnRemove) | Out-Null
            $panel.Children.Add($btnUpdate) | Out-Null

            $SoftwareList.Children.Add($panel) | Out-Null
            $script:checkboxes += $cb
        }
    }
}

# =========================
# INSTALL
# =========================
$BtnInstall.Add_Click({

    Show-Loader

    $list = $script:apps | Where-Object {
        -not (Test-SoftwareInstalled -Id $_.Id)
    }

    Install-SoftwareList -SoftwareList $list -Silent $ChkSilent.IsChecked -LogBox $LogBox

    Hide-Loader
    Load-Applications
})

# =========================
# INIT
# =========================
$script:apps = Get-SoftwareConfig -Path "$PSScriptRoot\Config\apps.json"

# Categories
$cats = $script:apps.Category | Sort-Object -Unique
$CategoryFilter.Items.Add("ALL") | Out-Null
$cats | ForEach-Object { $CategoryFilter.Items.Add($_) | Out-Null }
$CategoryFilter.SelectedIndex = 0

$CategoryFilter.Add_SelectionChanged({
    Load-Applications
})

Load-Applications

$window.ShowDialog() | Out-Null