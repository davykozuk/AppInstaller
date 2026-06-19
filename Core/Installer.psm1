function Invoke-WingetCommand {
    param([string[]]$Arguments, $LogBox, $Queue)

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

    # Lecture non-bloquante avec timeout implicite via HasExited.
    # NOTE : cette boucle Start-Sleep est OK car elle s'execute desormais
    # dans un runspace de FOND (voir Main.ps1 / Start-AsyncTask), plus
    # jamais sur le thread UI -> elle ne gele plus la fenetre.
    while (-not $p.HasExited) {
        while (-not $p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            if ($line.Trim()) { Write-Log $line "INFO" $LogBox $Queue }
        }
        while (-not $p.StandardError.EndOfStream) {
            $line = $p.StandardError.ReadLine()
            if ($line.Trim()) { Write-Log $line "ERROR" $LogBox $Queue }
        }
        Start-Sleep -Milliseconds 100
    }

    # Vider les buffers residuels
    while (-not $p.StandardOutput.EndOfStream) {
        $line = $p.StandardOutput.ReadLine()
        if ($line.Trim()) { Write-Log $line "INFO" $LogBox $Queue }
    }

    return $p.ExitCode
}

function Install-SoftwareList {
    param($SoftwareList, $Silent, $LogBox, $Queue, $ProgressState)

    $total = $SoftwareList.Count
    $i = 0

    foreach ($app in $SoftwareList) {
        $i++

        if ($ProgressState) {
            $ProgressState.Current = $i
            $ProgressState.Total   = $total
            $ProgressState.Status  = $app.Name
        }

        Write-Log "[$i/$total] Installation de $($app.Name)..." "INFO" $LogBox $Queue

        $args = @(
            "install",
            "--id", $app.Id,
            "--exact",
            "--accept-source-agreements",
            "--accept-package-agreements"
        )

        if ($Silent) { $args += "--silent" }

        $exitCode = Invoke-WingetCommand -Arguments $args -LogBox $LogBox -Queue $Queue

        if ($exitCode -eq 0) {
            Write-Log "$($app.Name) installe avec succes." "OK" $LogBox $Queue
        } else {
            Write-Log "$($app.Name) : code de retour $exitCode" "WARN" $LogBox $Queue
        }
    }
}

function Update-Software {
    param($App, $LogBox, $Queue, $ProgressState)

    if ($ProgressState) {
        $ProgressState.Current = 0
        $ProgressState.Total   = 1
        $ProgressState.Status  = $App.Name
    }

    Write-Log "Mise a jour de $($App.Name)..." "INFO" $LogBox $Queue

    $args = @(
        "upgrade",
        "--id", $App.Id,
        "--exact",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )

    $exitCode = Invoke-WingetCommand -Arguments $args -LogBox $LogBox -Queue $Queue

    if ($exitCode -eq 0) {
        Write-Log "$($App.Name) mis a jour." "OK" $LogBox $Queue
    } else {
        Write-Log "$($App.Name) : echec mise a jour (code $exitCode)" "WARN" $LogBox $Queue
    }

    if ($ProgressState) { $ProgressState.Current = 1 }
}

function Uninstall-SoftwareList {
    param($SoftwareList, $LogBox, $Queue, $ProgressState)

    $total = $SoftwareList.Count
    $i = 0

    foreach ($app in $SoftwareList) {
        $i++
        if ($ProgressState) {
            $ProgressState.Current = $i
            $ProgressState.Total   = $total
            $ProgressState.Status  = $app.Name
        }

        Write-Log "Desinstallation de $($app.Name)..." "INFO" $LogBox $Queue

        $args = @(
            "uninstall",
            "--id", $app.Id,
            "--exact",
            "--accept-source-agreements"
        )

        $exitCode = Invoke-WingetCommand -Arguments $args -LogBox $LogBox -Queue $Queue

        if ($exitCode -eq 0) {
            Write-Log "$($app.Name) desinstalle." "OK" $LogBox $Queue
        }
    }
}

# OPTIMISATION : winget list est appele UNE SEULE FOIS
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

            # Installe
            if ($parts.Count -ge 2) {
                $result.Installed = $true
            }

            # Version installee
            if ($parts.Count -ge 3) {
                $result.Version = $parts[2].Trim()
            }

            # MAJ uniquement si colonne "Available" existe
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
