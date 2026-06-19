function Get-IconCacheDir {
    param([string]$BasePath)
    $dir = Join-Path $BasePath "Cache\Icons"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-IconFileName {
    param([string]$Id)
    # Nettoie l'Id pour en faire un nom de fichier valide sur disque
    $safe = ($Id.Trim() -replace '[\\/:*?"<>| ]', '_')
    return "$safe.png"
}

# Renvoie le chemin de l'icone en cache si elle existe et n'est pas vide,
# sinon $null (l'appelant doit alors afficher un avatar de secours).
function Get-AppIconPath {
    param([string]$BasePath, [string]$Id)

    $dir  = Get-IconCacheDir -BasePath $BasePath
    $file = Join-Path $dir (Get-IconFileName -Id $Id)

    if ((Test-Path $file) -and ((Get-Item $file).Length -gt 0)) {
        return $file
    }
    return $null
}

# Telecharge les icones manquantes (favicon officiel de l'editeur via Google).
# Concu pour tourner dans un runspace de fond : ne touche aucun controle WPF.
# $Apps doit contenir un champ "Domain" (ex: "google.com") pour chaque app
# dont on veut recuperer l'icone ; les apps sans Domain sont ignorees
# (elles garderont l'avatar colore de secours).
function Sync-AppIcons {
    param([array]$Apps, [string]$BasePath, $Queue)

    $dir = Get-IconCacheDir -BasePath $BasePath

    foreach ($app in $Apps) {
        if (-not $app.Domain) { continue }

        $file = Join-Path $dir (Get-IconFileName -Id $app.Id)

        if ((Test-Path $file) -and ((Get-Item $file).Length -gt 0)) {
            continue
        }

        $url = "https://www.google.com/s2/favicons?sz=64&domain=$($app.Domain)"

        try {
            Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Out-Null

            if (-not (Test-Path $file) -or (Get-Item $file).Length -le 0) {
                Remove-Item $file -ErrorAction SilentlyContinue
            }
            elseif ($Queue) {
                $Queue.Enqueue("[$(Get-Date -Format 'HH:mm:ss')][INFO]  Icone recuperee : $($app.Name)")
            }
        }
        catch {
            Remove-Item $file -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Get-AppIconPath, Sync-AppIcons
