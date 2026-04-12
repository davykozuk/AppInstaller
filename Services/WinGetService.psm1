function Test-WinGet {
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}
Export-ModuleMember -Function Test-WinGet