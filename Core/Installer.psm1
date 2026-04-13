function Invoke-WingetCommand {
    param([string[]]$Arguments, $LogBox)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "winget"
    $psi.Arguments = $Arguments -join " "
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $p.Start() | Out-Null

    # Lecture non-bloquante avec timeout implicite via HasExited
    while (-not $p.HasExited) {
        while (-not $p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            if ($line.Trim()) { Write-Log $line "INFO" $LogBox }
        }
        while (-not $p.StandardError.EndOfStream) {
            $line = $p.StandardError.ReadLine()
            if ($line.Trim()) { Write-Log $line "ERROR" $LogBox }
        }
        Start-Sleep -Milliseconds 100
    }

    # Vider les buffers residuels
    while (-not $p.StandardOutput.EndOfStream) {
        $line = $p.StandardOutput.ReadLine()
        if ($line.Trim()) { Write-Log $line "INFO" $LogBox }
    }

    return $p.ExitCode
}

function Install-SoftwareList {
    param($SoftwareList, $Silent, $LogBox)

    $total = $SoftwareList.Count
    $i = 0

    foreach ($app in $SoftwareList) {
        $i++
        Write-Log "[$i/$total] Installation de $($app.Name)..." "INFO" $LogBox

        $args = @(
            "install",
            "--id", $app.Id,
            "--exact",
            "--accept-source-agreements",
            "--accept-package-agreements"
        )

        if ($Silent) { $args += "--silent" }

        $exitCode = Invoke-WingetCommand -Arguments $args -LogBox $LogBox

        if ($exitCode -eq 0) {
            Write-Log "$($app.Name) installe avec succes." "OK" $LogBox
        } else {
            Write-Log "$($app.Name) : code de retour $exitCode" "WARN" $LogBox
        }
    }
}

function Update-Software {
    param($App, $LogBox)

    Write-Log "Mise a jour de $($App.Name)..." "INFO" $LogBox

    $args = @(
        "upgrade",
        "--id", $App.Id,
        "--exact",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )

    $exitCode = Invoke-WingetCommand -Arguments $args -LogBox $LogBox

    if ($exitCode -eq 0) {
        Write-Log "$($App.Name) mis a jour." "OK" $LogBox
    } else {
        Write-Log "$($App.Name) : echec mise a jour (code $exitCode)" "WARN" $LogBox
    }
}

function Uninstall-SoftwareList {
    param($SoftwareList, $LogBox)

    foreach ($app in $SoftwareList) {
        Write-Log "Desinstallation de $($app.Name)..." "INFO" $LogBox

        $args = @(
            "uninstall",
            "--id", $app.Id,
            "--exact",
            "--accept-source-agreements"
        )

        $exitCode = Invoke-WingetCommand -Arguments $args -LogBox $LogBox

        if ($exitCode -eq 0) {
            Write-Log "$($app.Name) desinstalle." "OK" $LogBox
        }
    }
}

# OPTIMISATION MAJEURE : winget list est appele UNE SEULE FOIS
# puis le resultat est parse pour toutes les apps.
function Get-WingetListSnapshot {
    try {
        $output = winget list 2>$null
        return $output -split "`n"
    } catch {
        return @()
    }
}

function Get-SoftwareInfo {
    param(
        [string]$Id,
        [string[]]$Snapshot
    )

    $result = @{
        Installed = $false
        Version   = ""
        Update    = $false
    }

    if (-not $Snapshot) { return $result }

    $escaped = [regex]::Escape($Id)

    foreach ($line in $Snapshot) {
        if ($line -match $escaped) {

            $parts = $line -split "\s{2,}"

            # DEBUG (temporaire)
            Write-Log "DEBUG: $($parts -join ' | ')" "DEBUG" $LogBox

            # Installé
            if ($parts.Count -ge 2) {
                $result.Installed = $true
            }

            # Version installée
            if ($parts.Count -ge 3) {
                $result.Version = $parts[2].Trim()
            }

            # ✅ CORRECTION : MAJ uniquement si colonne "Available" existe
            if ($parts.Count -ge 5) {

                $installedVersion = $parts[2].Trim()
                $availableVersion = $parts[3].Trim()

                if (
                    $availableVersion -and
                    $availableVersion -ne $installedVersion -and
                    $availableVersion -match '^\d'
                ) {
                    $result.Update = $true
                }
            }

            break
        }
    }

    return $result
}

Export-ModuleMember -Function `
    Install-SoftwareList, `
    Uninstall-SoftwareList, `
    Update-Software, `
    Get-SoftwareInfo, `
    Get-WingetListSnapshot
