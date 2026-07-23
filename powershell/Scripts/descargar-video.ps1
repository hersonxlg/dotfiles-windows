#!/usr/bin/env pwsh
<#
.SYNOPSIS
Descarga videos de YouTube priorizando el doblaje al español y la gestión de subtítulos.

.DESCRIPTION
Este script multiplataforma actúa como una envoltura (wrapper) inteligente para yt-dlp. 
Analiza los metadatos del video objetivo antes de realizar la descarga. Si el video original está en inglés y posee un doblaje al español (ya sea nativo o generado por IA), por defecto descargará únicamente la pista en español para ahorrar espacio. Mediante el uso del parámetro -DescargarTodo, se puede forzar la extracción del audio dual y la incrustación de subtítulos multilingües.

.PARAMETER Url
La dirección URL del video de YouTube que se desea descargar. Es un parámetro obligatorio.

.PARAMETER Calidad
Define la resolución máxima del video a descargar. Admite los valores: 'Best', '1080', '720', '480'. Su valor predeterminado es 'Best'.

.PARAMETER DescargarTodo
Parámetro tipo switch. Si se incluye en la ejecución, anula el comportamiento por defecto (solo español) y descarga el video con audios en inglés y español, además de incrustar todos los subtítulos disponibles en ambos idiomas.

.EXAMPLE
./descargar-video.ps1 -Url "https://www.youtube.com/watch?v=Ejemplo"
Descarga el video en máxima calidad. Si está en inglés y tiene doblaje, bajará solo la versión doblada al español.

.EXAMPLE
./descargar-video.ps1 -Url "https://www.youtube.com/watch?v=Ejemplo" -DescargarTodo
Descarga el video en máxima calidad, empacando el audio original (inglés), el doblaje (español) y los subtítulos en un archivo MKV.

.EXAMPLE
./descargar-video.ps1 -Url "https://www.youtube.com/watch?v=Ejemplo" -Calidad 720
Fuerza la descarga a una resolución máxima de 720p.

.NOTES
Autor: Asistente
Versión: 3.0
Requisitos: yt-dlp, ffmpeg, nodejs
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="La URL del video de YouTube")]
    [string]$Url,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Best', '1080', '720', '480')]
    [string]$Calidad = 'Best',

    [Parameter(Mandatory=$false, HelpMessage="Si se incluye, descarga dual audio y subtítulos. Por defecto, solo descarga el doblaje.")]
    [switch]$DescargarTodo
)

# 0. Validación de dependencias requeridas en el PATH del sistema operativo
$dependencias = @('yt-dlp', 'ffmpeg', 'node')
foreach ($app in $dependencias) {
    if (-not (Get-Command $app -ErrorAction SilentlyContinue)) {
        Write-Host "Error crítico: La herramienta requerida '$app' no está instalada o no se encuentra configurada en la variable PATH del sistema." -ForegroundColor Red
        exit 1
    }
}

# 1. Configurar el formato de video basado en el parámetro de calidad
if ($Calidad -eq 'Best') {
    $videoFormat = "bestvideo[ext=mp4]"
} else {
    $videoFormat = "bestvideo[ext=mp4][height<=$Calidad]"
}

Write-Host "Analizando metadatos del video..." -ForegroundColor Cyan

# 2. Extraer información del video en formato JSON usando yt-dlp
$jsonOutput = yt-dlp --dump-json --cookies cookies.txt $Url 2>$null

if (-not $jsonOutput) {
    Write-Host "Error: No se pudo obtener la información del video. Verificar la URL o la existencia del archivo cookies.txt." -ForegroundColor Red
    exit 1
}

$videoInfo = $jsonOutput | ConvertFrom-Json

# 3. Detección avanzada de idiomas (Incluyendo doblajes IA sin etiqueta oficial)
$idiomasAudio = @()

foreach ($pista in $videoInfo.formats) {
    # Verificar si es una pista exclusiva de audio
    if (($pista.vcodec -eq 'none' -or $null -eq $pista.vcodec) -and ($pista.acodec -ne 'none' -and $null -ne $pista.acodec)) {
        
        # 3.1: Buscar etiqueta oficial de idioma
        if (-not [string]::IsNullOrWhiteSpace($pista.language)) {
            $idiomasAudio += $pista.language
        } 
        # 3.2: Buscar "Spanish" o "Español" en las notas del formato (Común en IA)
        elseif ($pista.format_note -match '(?i)español|spanish|es-') {
            $idiomasAudio += 'es'
        } 
        # 3.3: Buscar en el nombre de la pista
        elseif ($pista.audio_track_name -match '(?i)español|spanish|es-') {
            $idiomasAudio += 'es'
        }
    }
}

# Limpiar duplicados de la lista de idiomas
$idiomasAudio = $idiomasAudio | Select-Object -Unique

# Determinar el idioma original del video
$idiomaOriginal = $videoInfo.language
if ([string]::IsNullOrEmpty($idiomaOriginal)) {
    if ($idiomasAudio -contains 'en') {
        $idiomaOriginal = 'en'
    } elseif ($idiomasAudio -contains 'es') {
        $idiomaOriginal = 'es'
    } else {
        $idiomaOriginal = 'desconocido'
    }
}

Write-Host "Idioma detectado: $idiomaOriginal" -ForegroundColor Yellow

# Comprobar si existe alguna variante de español (nativo, latino, IA)
$tieneDoblajeEspanol = @($idiomasAudio -match '^es').Count -gt 0

# 4. Lógica de descarga condicional
if ($idiomaOriginal -match '^en') {
    
    if ($tieneDoblajeEspanol) {
        Write-Host "¡El video tiene doblaje al español (Nativo o IA)!" -ForegroundColor Green

        if ($DescargarTodo) {
            Write-Host "Modo Switch activado: Descargando Dual Audio (Inglés/Español) + Subtítulos..." -ForegroundColor Cyan
            
            $formatString = "$videoFormat+bestaudio[language^=en]+bestaudio[language^=es]"
            
            yt-dlp -i --sleep-subtitles 5 --js-runtimes node --extractor-args "youtube:player_client=all" -f $formatString --audio-multistreams --write-subs --write-auto-subs --sub-langs "en.*,es.*" --embed-subs --merge-output-format mkv --cookies cookies.txt $Url

            Write-Host "Limpiando archivos de subtítulos residuales (.vtt)..." -ForegroundColor Cyan
            Remove-Item -Path ".\*.vtt" -Force -ErrorAction SilentlyContinue

        } else {
            Write-Host "Modo por defecto: Descargando únicamente el video y el audio doblado al español..." -ForegroundColor Cyan
            
            $formatString = "$videoFormat+bestaudio[language^=es]"
            
            yt-dlp -i --js-runtimes node --extractor-args "youtube:player_client=all" -f $formatString --merge-output-format mkv --cookies cookies.txt $Url
        }
    } else {
        Write-Host "El video es en inglés pero NO posee pista de doblaje al español." -ForegroundColor Red
        Write-Host "Ejecutando descarga estándar con su audio original..." -ForegroundColor Yellow
        
        $formatString = "$videoFormat+bestaudio/best"
        yt-dlp -i --js-runtimes node --extractor-args "youtube:player_client=all" -f $formatString --merge-output-format mkv --cookies cookies.txt $Url
    }

} else {
    Write-Host "El video no es originalmente en inglés. Ejecutando descarga estándar (Video + Audio original)..." -ForegroundColor Green
    
    $formatString = "$videoFormat+bestaudio/best"
    yt-dlp -i --js-runtimes node --extractor-args "youtube:player_client=all" -f $formatString --merge-output-format mkv --cookies cookies.txt $Url
}

Write-Host "Proceso finalizado." -ForegroundColor Green

