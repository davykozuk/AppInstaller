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

    while (-not $p.HasExited) {
        while (-not $p.StandardOutput.EndOfStream) {
            Write-Log $p.StandardOutput.ReadLine() "INFO" $LogBox
        }
        while (-not $p.StandardError.EndOfStream) {
            Write-Log $p.StandardError.ReadLine() "ERROR" $LogBox
        }
        Start-Sleep -Milliseconds 100
    }

    return $p.ExitCode
}

function Install-SoftwareList {
    param($SoftwareList, $Silent, $LogBox)

    foreach ($app in $SoftwareList) {
        Write-Log "Installation $($app.Name)..." "INFO" $LogBox

        $args = @("install","--id",$app.Id,"--exact","--accept-source-agreements","--accept-package-agreements")

        if ($Silent) { $args += "--silent" }

        Invoke-WingetCommand -Arguments $args -LogBox $LogBox
    }
}

function Update-Software {
    param($App, $LogBox)

    Write-Log "Update $($App.Name)..." "INFO" $LogBox

    $args = @(
        "upgrade",
        "--id",$App.Id,
        "--exact",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )

    Invoke-WingetCommand -Arguments $args -LogBox $LogBox
}

function Uninstall-SoftwareList {
    param($SoftwareList, $LogBox)

    foreach ($app in $SoftwareList) {
        Write-Log "Desinstallation $($app.Name)..." "INFO" $LogBox

        $args = @("uninstall","--id",$app.Id,"--exact","--accept-source-agreements")

        Invoke-WingetCommand -Arguments $args -LogBox $LogBox
    }
}

function Get-SoftwareInfo {
    param([string]$Id)

    $result = @{
        Installed = $false
        Version   = ""
        Update    = $false
    }

    try {
        # 🔥 On récupère TOUT
        $output = winget list 2>$null

        if (-not $output) { return $result }

        $lines = $output -split "`n"

        foreach ($line in $lines) {

            if ($line -match [regex]::Escape($Id)) {

                $parts = $line -split "\s{2,}"

                if ($parts.Count -ge 2) {
                    $result.Installed = $true
                }

                if ($parts.Count -ge 3) {
                    $result.Version = $parts[2]
                }

                if ($parts.Count -ge 4) {
                    $result.Update = $true
                }

                break
            }
        }

        return $result
    }
    catch {
        return $result
    }
}

Export-ModuleMember -Function `
    Install-SoftwareList, `
    Uninstall-SoftwareList, `
    Update-Software, `
    Get-SoftwareInfo