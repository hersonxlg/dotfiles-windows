param(
    [String]$Name = "prueba"
)


if( Test-Path -Path $Name -ErrorAction SilentlyContinue ){
    Write-Host "Ya existe $Name en este directorio" -ForegroundColor Red
    Write-Host "Elija otro Nombre para este proyecto Arduino" -ForegroundColor Red
    return 
}

# Reglas: Empieza con letra/número, caracteres permitidos (a-z, 0-9, _, ., -), máx 63 caracteres.
$regexArduino = "^[a-zA-Z0-9][a-zA-Z0-9_\.\-]{0,62}$"
if ( ($Name -notmatch $regexArduino) -or $Name.EndsWith('.')) {
    Write-Host " El nombre '$Name' es INVALIDO para Arduino" -ForegroundColor Red
    Write-Host "Recuerda: Sin espacios, máximo 63 caracteres y no puede terminar en punto." -ForegroundColor Red
    return
}

try{
    New-Item -ItemType Directory -Name $Name &&
    Set-Location $Name &&
    Setup-Sketch.ps1 &&
    vim "$Name.ino"
}
catch {
    Write-Host "Error: " -ForegroundColor Red
}
finally {
}
