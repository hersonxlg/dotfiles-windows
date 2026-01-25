param(
    [Parameter(Mandatory)]
    [ValidateSet("compile","upload","load")]
    [String]$Command
)

$currentDir  = Get-Item .
$dirName     = $currentDir.Name
$inoFile     = "${dirName}.ino"
$sketchFile  = "sketch.yaml"

$compiler    = "arduino-cli.exe"
$compileArgs = "compile --libraries libraries '$($currentDir.FullName)'"
$uploadArgs  = "upload"
$compileCommand = "$compiler $compileArgs"
$uploadCommand  = "$compiler $uploadArgs"
$loadCommand    = "$compileCommand && $uploadCommand"


if (-not (Get-Command $compiler -ErrorAction SilentlyContinue)){
    Write-Host "No en encuentra el programa [$compiler] en el PATH" -ForegroundColor Red
    return
}
# Reglas: Empieza con letra/número, caracteres permitidos (a-z, 0-9, _, ., -), máx 63 caracteres.
$regexArduino = "^[a-zA-Z0-9][a-zA-Z0-9_\.\-]{0,62}$"
if ( ($dirName -notmatch $regexArduino) -or $dirName.EndsWith('.')) {
    Write-Host " El nombre '$dirName' es INVALIDO para Arduino" -ForegroundColor Red
    Write-Host "Recuerda: Sin espacios, máximo 63 caracteres y no puede terminar en punto." -ForegroundColor Red
    return
}
if ( -not (Test-Path -Path $inoFile -ErrorAction SilentlyContinue ) ) {
    Write-Host "No se encontró el archivo $inoFile en este directorio" -ForegroundColor Red
    return
}
if ( -not( Test-Path -Path $sketchFile -ErrorAction SilentlyContinue)  ) {
    Write-Host "No se encontró el archivo $inoFile en este directorio" -ForegroundColor Red
    return
}

switch($Command){
    "compile" { Invoke-Expression $compileCommand }
    "upload"  { Invoke-Expression $uploadCommand }
    "load"    { Invoke-Expression $loadCommand }
    Default   { Write-Host "Comando Invalido" -ForegroundColor Red }
}
