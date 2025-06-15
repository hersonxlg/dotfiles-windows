param(
    [String]$url = ""
)

$directorio = "_miniaturas"
$cwd = (Get-Item (Get-Location)) # Current Work Directory
try {
    # Comprobar que el directorio no existe:
    if ( Test-Path $directorio) {
        Write-Host "¡El directorio $directorio ya existe!" -BackgroundColor Yellow
        cd "$directorio"
    } elseif(($cwd.fullname -cmatch $directorio)) {
        Write-Host "¡El directorio $directorio ya existe!" -BackgroundColor Yellow
    }else{
        New-Item -Path $directorio -ItemType Directory | Out-Null
        cd "$directorio"
        Write-Host "¡El directorio `"${directorio}`" se ha creado!" -BackgroundColor Green
    }

    #***************************************************
    # PARA UN VIDEO:
    #$p = '--write-thumbnail --convert-thumbnails jpg --skip-download --encoding utf-8 -o "%(title)s_thumbnail.%(ext)s"' -split " "
    #***************************************************
    # PARA UNA LISTA DE VIDEOS:
    $p = '--write-thumbnail --convert-thumbnails jpg --skip-download --encoding utf-8 -o "%(autonumber)02d_%(title)s.%(ext)s"' -split " "
    $parametros = $p+$url
    $proceso = Start-Process -FilePath "yt-dlp" `
                              -ArgumentList $parametros `
                              -Wait -PassThru -NoNewWindow 
    if ($proceso.ExitCode -ne 0) {
        # Puedes lanzar una excepción para entrar en el catch
        Write-Host ""
        Write-Host "ERROR: La descarga no se pudo concretar." -BackgroundColor Red
        throw "El programa terminó con el código de error $($proceso.ExitCode)"
    } else {
        Write-Host ""
        Write-Host "La descarga terminó con EXITO." -BackgroundColor Green
    }
    

    $height = "300" # px
    $width = "-1" # REDIMENSIONAR automaticamente
    New-Item -Path "resized" -ItemType Directory | Out-Null
    $itemsToResized = ( (Get-ChildItem -File *.jpg) | Where-Object{ -not ($_.name -cmatch "_resized") })
    $itemsToResized | ForEach-Object {
        $inputFile = $_.FullName
        $outputFile = "$pwd\resized\$($_.BaseName)_resized.jpg"
        ffmpeg -i $_.FullName -vf scale=${width}:${height} $outputFile
    }

    $itemsToResized | Remove-Item
    move-item .\resized\*.jpg .
    remove-item resized

    # MENSAJE FINAL 
    Write-Host ""
    Write-Host "La descarga se ha completado con exito" -BackgroundColor green

} catch {
    $varName =  $(Split-Path -Path (Get-Location) -Leaf)
    echo "$varName"
    if($varName -eq $directorio){
        Set-Location -Path ".."
        ri $directorio
    }
    Write-Error "Error: $_"
} finally {
}

