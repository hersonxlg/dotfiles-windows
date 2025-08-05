<#
.SYNOPSIS
    Inicia una nueva sesión interactiva de PowerShell (pwsh o powershell clásico)
    con el entorno de compilación de Microsoft C++ Build Tools (x64 o x86) ya cargado.

.DESCRIPTION
    Este script detecta si los archivos de entorno `vcvars64.bat` y `vcvars32.bat` existen
    en una instalación de Visual Studio Build Tools 2022.
    Luego permite al usuario elegir entre el entorno x64 o x86,
    crea un archivo `.cmd` temporal que ejecuta el entorno elegido
    y lanza una nueva sesión de PowerShell (sin abrir nuevas ventanas gráficas).
#>

function Spawn-BuildShell {
    # Definir posibles rutas de instalación de Build Tools 2022
    $basePaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools"
    )

    $found = $false  # Bandera para indicar si se encontró la instalación

    foreach ($base in $basePaths) {
        # Rutas a los scripts de entorno
        $vcvars64 = Join-Path $base "VC\Auxiliary\Build\vcvars64.bat"
        $vcvars32 = Join-Path $base "VC\Auxiliary\Build\vcvars32.bat"

        # Validar que ambos scripts existen
        if ((Test-Path $vcvars64) -and (Test-Path $vcvars32)) {
            $found = $true
            break
        }
    }

    # Si no se encontraron los scripts, mostrar error y salir
    if (-not $found) {
        Write-Error "No se encontró una instalación válida de Microsoft C++ Build Tools 2022 con vcvars64.bat y vcvars32.bat."
        return
    }

    # Menú interactivo para elegir arquitectura
    Write-Host "Selecciona el entorno de compilación:"
    Write-Host "1. x64 (64 bits)"
    Write-Host "2. x86 (32 bits)"
    $choice = Read-Host "Ingresa 1 o 2"

    # Asignar script de entorno según elección
    switch ($choice) {
        '1' { $envScript = $vcvars64 }
        '2' { $envScript = $vcvars32 }
        default {
            Write-Warning "Opción inválida. Cancelando."
            return
        }
    }

    # Detectar qué shell usar: pwsh (PowerShell Core) o powershell clásico
    $shellExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

    # Crear archivo .cmd temporal para ejecutar entorno y lanzar nueva sesión
    $tempScript = [System.IO.Path]::GetTempFileName().Replace(".tmp", ".cmd")

    # Contenido del script .cmd
    @"
@echo off
REM Cargar entorno de compilación
call `"$envScript`"
echo Entorno cargado: $envScript

REM Lanzar nueva shell en misma ventana
$shellExe -NoExit -Command Set-Theme half-life
"@ | Set-Content -Encoding ASCII -Path $tempScript

    # Ejecutar el script en el mismo terminal sin nueva ventana
    & cmd /c `"$tempScript`"
}

# Ejecutar la función principal
Spawn-BuildShell
