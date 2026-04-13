function Write-Log {
    param($Message, $Level = "INFO", $LogBox)

    $time = Get-Date -Format "HH:mm:ss"

    $prefix = switch ($Level) {
        "OK"    { "[OK]   " }
        "WARN"  { "[WARN] " }
        "ERROR" { "[ERR]  " }
        default { "[INFO] " }
    }

    $line = "[$time]$prefix $Message"

    # ✅ FIX PS2EXE : base path fiable
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

    [System.IO.File]::AppendAllText(
        $logPath,
        $line + [Environment]::NewLine,
        [System.Text.Encoding]::UTF8
    )

    if ($LogBox) {
        $LogBox.AppendText("$line`r`n")
        $LogBox.ScrollToEnd()
    }
}

Export-ModuleMember -Function Write-Log

Export-ModuleMember -Function Write-Log
