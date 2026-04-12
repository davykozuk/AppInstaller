function Install-WinGet {
    param($LogBox)

    try {
        Write-Log "Installation de WinGet..." "INFO" $LogBox

        $temp = Join-Path $env:TEMP "winget_install"
        New-Item -ItemType Directory -Path $temp -Force | Out-Null

        $wingetUrl = "https://aka.ms/getwinget"
        $wingetPath = Join-Path $temp "winget.msixbundle"

        Write-Log "Telechargement WinGet..." "INFO" $LogBox
        Invoke-WebRequest $wingetUrl -OutFile $wingetPath -UseBasicParsing

        Write-Log "Installation du package..." "INFO" $LogBox
        Add-AppxPackage -Path $wingetPath -ErrorAction Stop

        Write-Log "WinGet installe" "INFO" $LogBox
        return $true
    }
    catch {
        Write-Log "Erreur installation WinGet : $($_.Exception.Message)" "ERROR" $LogBox
        return $false
    }
}

Export-ModuleMember -Function Install-WinGet