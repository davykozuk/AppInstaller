function Get-SoftwareConfig {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        throw "Fichier config introuvable"
    }

    return (Get-Content $Path -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function Get-SoftwareConfig