# *******************************************************
#             comando "setvar"
# *******************************************************
#

<#
.SYNOPSIS
    Crea, modifica o elimina una variable de entorno del sistema o del usuario.

.DESCRIPTION
    Este script permite gestionar variables de entorno en Windows utilizando PowerShell.
    Permite crear o modificar una variable a nivel de "Machine" (equipo) o "User" (usuario actual).
    También refleja el cambio en la sesión actual de PowerShell.
    Si no se proporciona un valor, la variable se elimina de la sesión actual.

.PARAMETER Name
    Nombre de la variable de entorno que se desea crear, modificar o eliminar.

.PARAMETER Value
    Valor que se desea asignar a la variable de entorno.
    Si se omite o se proporciona como una cadena vacía, la variable se eliminará de la sesión actual.

.PARAMETER Scope
    Alcance de la variable: puede ser 'User' o 'Machine'.
    Si no se proporciona, por defecto se usará 'Machine'.

.EXAMPLE
    .\setvar.ps1 -Name "MY_VAR" -Value "123" -Scope "User"
    Crea o modifica la variable de entorno "MY_VAR" con valor "123" a nivel de usuario.

.EXAMPLE
    .\setvar.ps1 -Name "MY_VAR" -Value ""
    Elimina "MY_VAR" de la sesión actual de PowerShell (no del sistema).

.NOTES
    Se requiere ejecutar el script con permisos de administrador si se modifica el entorno de máquina.

#>

param(
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Name,

    [Parameter(Position=1, Mandatory=$false, ValueFromPipeline=$true)]
    [string]$Value = $null,

    [Parameter(Position=2, Mandatory=$false, ValueFromPipeline=$true)]
    [ValidateSet('User', 'Machine', IgnoreCase)]
    [string]$Scope
)

# Si no se especifica Scope, usar 'Machine' por defecto
if ($Scope -eq "") {
    $Scope = "Machine"
}

# Construye el comando que modificará la variable de entorno del sistema o usuario
$comando = "[Environment]::SetEnvironmentVariable('${Name}', '${Value}', '${Scope}')"

# Ejecuta el comando anterior en una instancia elevada de PowerShell
Start-Process -Wait -Verb RunAs -FilePath pwsh -ArgumentList '-noprofile', '-nologo', "-command `"${comando}`""

# Si el valor está vacío, elimina la variable del entorno actual (solo en la sesión actual)
if ($Value -eq "") {
    Invoke-Expression "Remove-Item Env:${Name}"
}
else {
    # Si hay valor, también lo asigna en el entorno actual
    Invoke-Expression "`$Env:${Name}='${Value}'"
}
