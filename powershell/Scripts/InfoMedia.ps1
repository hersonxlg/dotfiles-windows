param (
    [Parameter(Mandatory=$true)]
    [string]$MediaFilePath
)

if( -not(Get-Command ffprobe.exe -ErrorAction SilentlyContinue) ){
    Write-Host "  El archivo `"ffprobe.exe`" no se encuentra en PATH...  " -BackgroundColor Red -ForegroundColor Black
    exit 1
}

function ConvertTo-FriendlySize {
    param ([double]$Bytes)
    switch ($Bytes) {
        {$_ -ge 1GB} { "{0:N2} GB" -f ($Bytes / 1GB); break }
        {$_ -ge 1MB} { "{0:N2} MB" -f ($Bytes / 1MB); break }
        {$_ -ge 1KB} { "{0:N2} KB" -f ($Bytes / 1KB); break }
        default      { "{0:N0} B" -f $Bytes }
    }
}

function ConvertTo-CleanTime {
    param ([double]$Seconds)
    $ts = [TimeSpan]::FromSeconds($Seconds)
    if ($ts.Hours -gt 0) {
        "{0}:{1:d2}:{2:d2}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
    } elseif ($ts.Minutes -gt 0) {
        "{0}:{1:d2}" -f $ts.Minutes, $ts.Seconds
    } else {
        "$($ts.Seconds)s"
    }
}

# Verifica que ffprobe esté disponible
$ffprobe = "ffprobe.exe"
if (-not (Get-Command $ffprobe -ErrorAction SilentlyContinue)) {
    Write-Error "No se encontró ffprobe.exe. Asegúrate de que esté en el PATH o en el mismo directorio."
    exit 1
}

# Ejecuta ffprobe y obtiene la salida JSON
$infoJson = & $ffprobe -v quiet -print_format json -show_format -show_streams "$MediaFilePath" | ConvertFrom-Json

$format = $infoJson.format
$streams = $infoJson.streams

Write-Host "`n========== INFORMACIÓN GENERAL ==========" -ForegroundColor Cyan
#Write-Host "Nombre del archivo : $($format.filename)"
Write-Host "Nombre del archivo : $((Get-Item $MediaFilePath).Name)"
Write-Host "Formato            : $($format.format_name)"
Write-Host "Duración           : $(ConvertTo-CleanTime $format.duration)"
Write-Host "Tamaño             : $(ConvertTo-FriendlySize $format.size)"
Write-Host "Bitrate            : $([Math]::Round([double]$format.bit_rate / 1000, 2)) kbps"
Write-Host "Tags               :"
if ($format.tags) {
    foreach ($tag in $format.tags.PSObject.Properties) {
        Write-Host "  $($tag.Name): $($tag.Value)"
    }
} else {
    Write-Host "  (No hay etiquetas)"
}

Write-Host "`n========== STREAMS ==========" -ForegroundColor Cyan
foreach ($stream in $streams) {
    Write-Host "`n--- Stream Index $($stream.index) ---" -ForegroundColor Yellow
    Write-Host "Tipo          : $($stream.codec_type)"
    Write-Host "Codec         : $($stream.codec_name)"
    Write-Host "Idioma        : $($stream.tags.language)"  # Puede estar vacío
    if ($stream.codec_type -eq "video" -and $stream.width) {
        Write-Host "Resolución    : $($stream.width)x$($stream.height)"
    } else {
        Write-Host "Resolución    : (no aplica)"
    }
    if ($stream.bit_rate) {
        Write-Host "Bitrate       : $([Math]::Round([double]$stream.bit_rate / 1000, 2)) kbps"
    }
    if ($stream.duration) {
        Write-Host "Duración      : $(ConvertTo-CleanTime $stream.duration)"
    }
    if ($stream.r_frame_rate -and $stream.codec_type -eq "video") {
        Write-Host "Frame Rate    : $($stream.r_frame_rate)"
    }
}
