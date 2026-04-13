function Write-Log {
    param($Message, $Level = "INFO", $LogBox)

    $time = Get-Date -Format "HH:mm:ss"

    # Couleur selon niveau dans la console
    $prefix = switch ($Level) {
        "OK"    { "[OK]   " }
        "WARN"  { "[WARN] " }
        "ERROR" { "[ERR]  " }
        default { "[INFO] " }
    }

    $line = "[$time]$prefix $Message"

    # Ecriture fichier log (chemin absolu depuis la racine du projet)
    $logDir  = Join-Path $PSScriptRoot "..\Logs"
    $logPath = Join-Path $logDir "app.log"

    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    [System.IO.File]::AppendAllText(
        $logPath,
        $line + [Environment]::NewLine,
        [System.Text.Encoding]::UTF8
    )

    # Mise a jour UI (thread-safe via Dispatcher si necessaire)
    if ($LogBox) {
        $coloredLine = $line

        # Couleur dans le LogBox via foreground de tout le textbox (simplifie)
        # Pour une vraie coloration par ligne il faudrait un RichTextBox
        $LogBox.AppendText("$coloredLine`r`n")
        $LogBox.ScrollToEnd()
    }
}

Export-ModuleMember -Function Write-Log
