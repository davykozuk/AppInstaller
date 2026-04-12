function Test-SoftwareInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    try {
        $output = winget list --id $Id --exact 2>$null

        if (-not $output) {
            return $false
        }

        # Convertit en tableau de lignes propres
        $lines = $output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

        # Cas : aucun résultat
        if ($lines -match "Aucun package") {
            return $false
        }

        # Cherche une vraie ligne contenant l'ID EXACT
        foreach ($line in $lines) {
            if ($line -match "^\S+.*\s+$Id\s+") {
                return $true
            }
        }

        return $false
    }
    catch {
        return $false
    }
}

function Install-SoftwareList {
    param($SoftwareList, $Silent, $LogBox)

    foreach ($app in $SoftwareList) {

        Write-Log "Installation $($app.Name)..." "INFO" $LogBox

        try {
            if ($app.Type -eq "winget") {

                $args = @(
                    "install",
                    "--id", $app.Id,
                    "--accept-package-agreements",
                    "--accept-source-agreements"
                )

                if ($Silent) {
                    $args += "--silent"
                }

                $process = Start-Process "winget" `
                    -ArgumentList $args `
                    -Wait `
                    -PassThru `
                    -NoNewWindow

                if ($process.ExitCode -eq 0) {
                    Write-Log "$($app.Name) installe avec succès" "INFO" $LogBox
                }
                else {
                    Write-Log "Erreur installation $($app.Name) (code $($process.ExitCode))" "ERROR" $LogBox
                }
            }
        }
        catch {
            Write-Log "Exception installation $($app.Name) : $($_.Exception.Message)" "ERROR" $LogBox
        }
    }

    Write-Log "Installation terminee" "INFO" $LogBox
}
function Uninstall-SoftwareList {
    param($SoftwareList, $LogBox)

    foreach ($app in $SoftwareList) {

        Write-Log "Desinstallation $($app.Name)..." "INFO" $LogBox

        try {
            if ($app.Type -eq "winget") {

                $args = @(
                    "uninstall",
                    "--id", $app.Id,
                    "--accept-source-agreements"
                )

                $process = Start-Process "winget" `
                    -ArgumentList $args `
                    -Wait `
                    -PassThru `
                    -NoNewWindow

                if ($process.ExitCode -eq 0) {
                    Write-Log "$($app.Name) desinstalle avec succès" "INFO" $LogBox
                }
                else {
                    Write-Log "Erreur desinstallation $($app.Name) (code $($process.ExitCode))" "ERROR" $LogBox
                }
            }
        }
        catch {
            Write-Log "Exception desinstallation $($app.Name) : $($_.Exception.Message)" "ERROR" $LogBox
        }
    }

    Write-Log "Desinstallation terminee" "INFO" $LogBox
}

function Get-SoftwareInfo {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $result = [PSCustomObject]@{
        Installed = $false
        InstalledVersion = $null
        AvailableVersion = $null
    }

    try {
        # -------- INSTALLED --------
        $listOutput = winget list --id $Id --exact 2>$null

        if ($listOutput -notmatch "Aucun package") {

            $lines = $listOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            if ($lines.Count -ge 3) {
                $data = $lines[2]

                # Split sur espaces multiples
                $parts = $data -split "\s{2,}"

                if ($parts.Count -ge 3) {
                    $result.Installed = $true
                    $result.InstalledVersion = $parts[2]
                }
            }
        }

        # -------- AVAILABLE --------
        $upgradeOutput = winget upgrade --id $Id --exact 2>$null

        if ($upgradeOutput -notmatch "Aucun package") {

            $lines = $upgradeOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            if ($lines.Count -ge 3) {
                $data = $lines[2]
                $parts = $data -split "\s{2,}"

                if ($parts.Count -ge 4) {
                    $result.AvailableVersion = $parts[3]
                }
            }
        }

        return $result
    }
    catch {
        return $result
    }
}

Export-ModuleMember -Function Test-SoftwareInstalled, Install-SoftwareList, Uninstall-SoftwareList, Get-SoftwareInfo