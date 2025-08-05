
# *******************************************************
#             Comando "add-tag"
# *******************************************************


if( -not(Get-Command ffmpeg -ErrorAction SilentlyContinue)){
    Write-Host "`n  No se ha dectectado el programa `"ffmpeg.exe`"...  `n" -BackgroundColor Red -ForegroundColor Black
    exit 1;
}

$canciones = @(Get-ChildItem -Filter "* - *.mp3")
$N = $canciones.length 
$i = 1;
$canciones | ForEach-Object{

    $audioFile = $_.FullName
    $temp  = "$audioFile.tmp.mp3"

    $artista,$titulo = ($_.BaseName) -split '\s+-\s+'
    Write-Host "`n`n$($i)/$N`t$($titulo) : $($artista)`n"

    ffmpeg -hide_banner -loglevel error -y -i $audioFile `
        -metadata title="$titulo" `
        -metadata artist="$artista" `
        -c copy $temp
    # -hide_banner    : oculta el encabezado de versión y configuración.
    # -loglevel error : solo muestra mensajes en caso de fallo.
    # -y              : Acepta automáticamente sobrescribir archivos de salida existentes sin preguntar.

    Move-Item -Force $temp $audioFile
    $i++;
}
