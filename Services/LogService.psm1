function Write-Log {
    param($Message, $Level, $LogBox)

    $time = Get-Date -Format "HH:mm:ss"
    $line = "[$time][$Level] $Message"

    $logPath = Join-Path $PSScriptRoot "..\Logs\app.log"

    # Écriture UTF8 propre
    [System.IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)

    if ($LogBox) {
        $LogBox.AppendText("$line`r`n")
        $LogBox.ScrollToEnd()
    }
}

Export-ModuleMember -Function Write-Log