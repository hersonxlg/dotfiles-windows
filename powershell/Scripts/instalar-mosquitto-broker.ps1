$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# variables
$mosquittoDir = "$env:USERPROFILE\scoop\apps\mosquitto\current"
$exePath = Join-Path $mosquittoDir "mosquitto.exe"
$configPath = Join-Path $mosquittoDir "mosquitto.conf"
$serviceName = "mosquitto"
$firewallRule = "Mosquitto MQTT Broker"

# Verificaciones
if (-not (Test-Path $exePath)) {
    Write-Error "No se encontró $exePath"
    exit 1
}
if (-not (Test-Path $configPath)) {
    Write-Error "No se encontró $configPath"
    exit 1
}


# Este codigo se ejecuta solo si el Script NO tiene
# permisos de superusuario:
#if( -not $isAdmin){
#}
# Crear la variable de entorno en la sesion
# de "pwsh.exe" que abrio este Script:
$Env:MOSQUITTO_DIR = $mosquittoDir



# ******************************************************************************************************
# Se solucitan los privilegios de administrador
# ******************************************************************************************************
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script debe ejecutarse como administrador."
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}


# Establecer variable de entorno "permanente"
[System.Environment]::SetEnvironmentVariable("MOSQUITTO_DIR", $mosquittoDir, [System.EnvironmentVariableTarget]::Machine)
Write-Host "Variable del Entorno: MOSQUITTO_DIR se ha creado" 

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Write-Host "El servicio $serviceName ya está instalado."
} else {
    & $exePath install | Out-Null
    Start-Sleep -Seconds 2
    Start-Service $serviceName
    Start-Sleep -Seconds 1

    $servicio = Get-Service -Name "mosquitto" -ErrorAction SilentlyContinue

    if ($servicio -and $servicio.Status -eq "Running") {
        Write-Host "`n-- Servicio $serviceName instalado y arrancado.--`n" -BackgroundColor Green -ForegroundColor Black
    } elseif ($servicio) {
        Write-Host "`n-- Servicio $serviceName instalado pero `"NO ARRANCA`"--`n" -BackgroundColor Yellow -ForegroundColor Black
    } else {
        Write-Host "`n-- Servicio $serviceName `"NO se pudo INSTALAR`"--`n" -BackgroundColor Red -ForegroundColor Black
    }
}

# Reglas de Firewall (puerto 1883 por defecto)
$existingRule = Get-NetFirewallRule -DisplayName $firewallRule -ErrorAction SilentlyContinue
if (-not $existingRule) {
    New-NetFirewallRule -DisplayName $firewallRule `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 1883 `
        -Action Allow `
        -Profile Private `
        -Description "Permite conexiones MQTT para Mosquitto" | Out-Null
    Write-Host "Regla de firewall '$firewallRule' creada."
} else {
    Write-Host "Regla de firewall '$firewallRule' ya existe."
}


# PAUSA condicionada:
Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
[void][System.Console]::ReadKey($true)

