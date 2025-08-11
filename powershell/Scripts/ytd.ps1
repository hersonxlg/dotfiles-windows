param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('titulos','miniaturas', 'enlaces','capitulos')]
    [string]$action,
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]] $ExtraArgs = @()
)

# validaciones:
if( -not(Get-Command yt-dlp.exe -ErrorAction SilentlyContinue) ){
    Write-Host ' El programa "yt-dlp.exe" no se encuentra en el PATH... ' -ForegroundColor Red
    Exit 1
}
if($ExtraArgs.Length -eq 0){
    Write-Host ' Se necesita una URL de YouTube... ' -ForegroundColor Red
    Exit 1
}
# Patrón regex más completo para YouTube
$pattern = '^((?:https?:)?\/\/)?((?:www|m)\.)?((?:youtube(-nocookie)?\.com|youtu.be))(\/(?:[\w\-]+\?v=|embed\/|live\/|v\/|shorts\/|channel\/|c\/|user\/|playlist\?list=))([\w\-]+)(\S+)?$'
$url = @($ExtraArgs | Where-Object{
        $_ -match $pattern
    })

if($url.Length -eq 0){
    Write-Host ' URL de YouTube "INVALIDA"... ' -ForegroundColor Red
    Exit 1
}
if($url.Length -gt 1){
    Write-Host ' Hay mas de una URL de YouTube... ' -ForegroundColor Red
    $url
    Exit 1
}

# ---------------------------------------------------------------------------
# TIPO DE URL DE YOUTUBE:
# ---------------------------------------------------------------------------
# Normalizar la URL (eliminar parámetros adicionales)
# corta el enlace en los "&" que no van seguidos de "list=":
$normalizedUrl = $Url -split '&(?!list=)' | Select-Object -First 1
    
# Patrones principales
$typeInfo = switch -Regex ($normalizedUrl) {
    'youtube\.com\/watch\?v=([^&]+)$' { 
        @{ Type = "Video"; ID = $Matches[1] } 
    }
    'youtu\.be\/([^?]+)' { 
        @{ Type = "Video"; ID = $Matches[1] } 
    }
    'youtube\.com\/shorts\/([^?]+)' { 
        @{ Type = "Short"; ID = $Matches[1] } 
    }
    'youtube\.com\/(?:c\/|channel\/|user\/|@)([^\/]+)' { 
        @{ Type = "Channel"; ID = $Matches[1] } 
    }
    'youtube\.com\/playlist\?list=([^&]+)' { 
        @{ Type = "Playlist"; ID = $Matches[1] } 
    }
    'youtube\.com\/watch\?v=([^&]+)&list=([^&]+)' { 
        @{ Type = "Playlist"; ID = $Matches[2] } 
    }
    'youtube\.com\/embed\/([^?]+)' { 
        @{ Type = "EmbeddedVideo"; ID = $Matches[1] } 
    }
    'youtube\.com\/live\/([^?]+)' { 
        @{ Type = "LiveStream"; ID = $Matches[1] } 
    }
    'youtube\.com\/results\?search_query=' { 
        @{ Type = "SearchResults" } 
    }
    'youtube\.com\/feed\/subscriptions' { 
        @{ Type = "SubscriptionsFeed" } 
    }
    'youtube\.com\/$' { 
        @{ Type = "HomePage" } 
    }
    default { 
        @{ Type = "Unknown" } 
    }
}

# ----------------------------------------------------------
# MAIN
# ----------------------------------------------------------

$comando = ""
$tipo_de_accion = ""

switch ($action) {
    "titulos"    {
        $tipo_de_accion = "Descargando Títulos" 
        $print = ""
        if($typeInfo.Type -eq "Playlist"){
            $print = '"%(autonumber)d. [%(title)s](%(webpage_url)s)"'
        } else{
            $print = '"[%(title)s](%(webpage_url)s)"'
        }
        $opciones = "--print ${print} --restrict-filenames --encoding utf-8"
        $comando = "yt-dlp "
        $comando += "${opciones} '${url}'"
            
    }
    "miniaturas" {
        $tipo_de_accion = "Descargando Miniaturas" 
        $output = "'%(title)s.%(ext)s'"
        if($typeInfo.Type -eq "Playlist"){
            $output = "'%(autonumber)02d_%(title)s.%(ext)s'"
        } else{
            $output = '[%(title)s](%(webpage_url)s)"'
        }
        $opciones = "--write-thumbnail --convert-thumbnails jpg --skip-download --encoding utf-8 -o ${output} --restrict-filenames"
        $comando = "& {"
        $comando += '$oldLocation = Get-Location;'
        $comando += 'Set-Location $HOME ;'
        $comando += "PWD ;"
        #$comando += "yt-dlp ${opciones} '${url}';"
        $comando += 'Set-Location $oldLocation ;'
        $comando += "}"
    }
    "enlaces"    {
        $tipo_de_accion = "Descargando URLs" 
        $print = ""
        if($typeInfo.Type -eq "Playlist"){
            $print = '"%(webpage_url)s"'
        } else{
            $print = '"%(webpage_url)s"'
        }
        $opciones = "--print ${print} --restrict-filenames --encoding utf-8"
        $comando = "yt-dlp "
        $comando += "${opciones} '${url}'"
    }
    "capitulos"  {
        if($typeInfo.Type -eq "Playlist"){
            if($normalizedUrl -match '(youtube\.com\/watch\?v=[^&]+)&list=([^&]+)') { 
                $url = $Matches[1]
            } else{
                Write-Host ' No se puede extraer los "CAPITULOS" de una Playlist... ' -ForegroundColor Red
                Exit 1
            }
        }
        $tipo_de_accion = "Descargando capitulos" 
        $comando  = "& {"
        $comando += "`$meta = yt-dlp -J ${url} | Out-String | ConvertFrom-Json;"
        $comando += 'if (-not $meta.chapters) { "No chapters found." ; return };'
        $comando += '$meta.chapters | ForEach-Object { "[" + [TimeSpan]::FromSeconds($_.start_time).ToString("hh\:mm\:ss") + "](${url}&t=$($_.start_time)) - " + $_.title } ;'
        $comando += "}"
    }
}

## $contador = 0
## $ExtraArgs | ForEach-Object{
##     "{0}: {1}" -f $contador,$_;
##     $contador++;
## }

Write-Host $tipo_de_accion -ForegroundColor Blue
Write-Host "Tipo: $($typeInfo.Type)" -ForegroundColor Blue
#Write-Host "$comando" -ForegroundColor Cyan

try {
    Write-Host " Espere... " -ForegroundColor Cyan
    Invoke-Expression $comando
    if($LASTEXITCODE -eq 0){
        Write-Host " EXITO... " -ForegroundColor Cyan
    } else{
        Write-Host " ERROR... " -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[ERROR] No se pudo Compleatar el comando."
    exit 1
}

