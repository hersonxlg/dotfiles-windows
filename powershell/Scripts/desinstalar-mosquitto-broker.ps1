#--------------------------------------------------------------------------------------------------
#  Es codigo se usa para remover una lista de elementos que hace que un "broker" de mosquitto
#  funcione bien, ellos son:
#
#       - Variable de entorno: "MOSQUITTO_DIR"
#       - El servicio: "mosquitto"
#       - La regla del firewall: "Mosquitto MQTT Broker"
#
#   El codigo se ejecuta en dos partes, la primera es cuando el Script se ejecuta sin permisos de administrador,
#   y la segundo es cuando se ejecuta el Script como Admin, esto se hace para que el Script puede modificar la
#   variable de entorno "MOSQUITTO_DIR" fuera del Script, mas especificamente, en la sesion de powershell que 
#   abrio este Script.k
#--------------------------------------------------------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Eliminar variable de entorno MOSQUITTO_DIR en la sesion
# de "pwsh.exe" que abrio este Script:
if ($env:MOSQUITTO_DIR) {
    Remove-Item -Path "Env:MOSQUITTO_DIR" -ErrorAction SilentlyContinue
}



# ******************************************************************************************************
# Se solucitan los privilegios de administrador
# ******************************************************************************************************
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script debe ejecutarse como administrador."
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}


# Variables
$serviceName = "mosquitto"
$exePath = "$env:USERPROFILE\scoop\apps\mosquitto\current\mosquitto.exe"
$firewallRule = "Mosquitto MQTT Broker"

# Detener y eliminar servicio
if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Stop-Service $serviceName -Force
    & $exePath uninstall | Out-Null
    Write-Host "Servicio $serviceName detenido y eliminado."
} else {
    Write-Host "Servicio $serviceName no estaba instalado."
}

# Eliminar regla de firewall si existe
$rule = Get-NetFirewallRule -DisplayName $firewallRule -ErrorAction SilentlyContinue
if ($rule) {
    Remove-NetFirewallRule -DisplayName $firewallRule
    Write-Host "Regla de firewall '$firewallRule' eliminada."
} else {
    Write-Host "Regla de firewall '$firewallRule' no existe."
}

# Eliminar variable de entorno MOSQUITTO_DIR
if ($env:MOSQUITTO_DIR) {
    Remove-Item -Path "Env:MOSQUITTO_DIR" -ErrorAction SilentlyContinue
    [System.Environment]::SetEnvironmentVariable("MOSQUITTO_DIR", $null, [System.EnvironmentVariableTarget]::User)
    Write-Host "Variable de entorno MOSQUITTO_DIR eliminada."
}else{
    Write-Host "Variable de entorno MOSQUITTO_DIR no existe."
}


# PAUSA condicionada:
Write-Host "`n--- Presiona cualquier tecla para salir ---`n"
[void][System.Console]::ReadKey($true)


