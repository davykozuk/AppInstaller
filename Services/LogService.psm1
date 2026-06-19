function Write-Log {
    param($Message, $Level = "INFO", $LogBox, $Queue)

    $time = Get-Date -Format "HH:mm:ss"

    $prefix = switch ($Level) {
        "OK"    { "[OK]   " }
        "WARN"  { "[WARN] " }
        "ERROR" { "[ERR]  " }
        "DEBUG" { "[DBG]  " }
        default { "[INFO] " }
    }

    $line = "[$time]$prefix $Message"

    # FIX PS2EXE : base path fiable
    if ($MyInvocation.MyCommand.Path) {
        $basePath = Split-Path $MyInvocation.MyCommand.Path -Parent
    } else {
        $basePath = Get-Location
    }

    $logDir  = Join-Path $basePath "Logs"
    $logPath = Join-Path $logDir "app.log"

    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Ecriture fichier protegee : plusieurs threads (UI + taches de fond)
    # peuvent appeler Write-Log en meme temps, on evite les collisions d'ecriture.
    $mutex = New-Object System.Threading.Mutex($false, "Global\InforsudAppInstallerLogMutex")
    [void]$mutex.WaitOne()
    try {
        [System.IO.File]::AppendAllText(
            $logPath,
            $line + [Environment]::NewLine,
            [System.Text.Encoding]::UTF8
        )
    } finally {
        $mutex.ReleaseMutex()
    }

    # ─────────────────────────────────────────────
    # IMPORTANT :
    # - $Queue  -> utilise depuis une tache de fond (runspace).
    #              On NE TOUCHE JAMAIS un controle WPF depuis un autre
    #              thread que celui de l'UI (ca leve une exception ou
    #              corrompt l'affichage). On se contente d'empiler le
    #              message ; c'est le thread UI (DispatcherTimer) qui
    #              videra la file et mettra a jour le LogBox.
    # - $LogBox -> utilise uniquement depuis le thread UI (handlers de
    #              boutons classiques, code de demarrage, etc.)
    # ─────────────────────────────────────────────
    if ($Queue) {
        $Queue.Enqueue($line)
    }
    elseif ($LogBox) {
        $LogBox.AppendText("$line`r`n")
        $LogBox.ScrollToEnd()
    }
}

Export-ModuleMember -Function Write-Log
