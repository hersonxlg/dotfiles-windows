
# variables
$mosquittoDir = "$env:USERPROFILE\scoop\apps\mosquitto\current"
$exePath = Join-Path $mosquittoDir "mosquitto.exe"
$configPath = Join-Path $mosquittoDir "mosquitto.conf"
$configPathBackup = Join-Path $mosquittoDir "mosquitto.conf.original"
$serviceName = "mosquitto"
$firewallRule = "Mosquitto MQTT Broker"


# Verificaciones
if (-not (Test-Path $configPath)) {
    Write-Host "`nNo se encontró el archivo`"mosquitto.conf`" en la dirección:" -BackgroundColor Red -ForegroundColor Black
    Write-Host "${mosquittoDir}`n" -BackgroundColor Red -ForegroundColor Black
    Write-Error "No se encontró $configPath"
    exit 1
}

# Crear un respaldo del archivo original
if (-not (Test-Path $configPathBackup)) {
    Copy-Item -Path $configPath -Destination $configPathBackup
}

# Verificar la existencia de los editores con los que se abrira el archivo "mosquitto.conf"
if(Get-Command -Name vim -ErrorAction SilentlyContinue){
    vim $configPath
} elseif (Get-Command -Name notepad -ErrorAction SilentlyContinue) {
    notepad $configPath
} else {
    Invoke-Expression $configPath
}

