<#
.SYNOPSIS
    Inicia una sesión de PowerShell con el entorno de compilación de MSVC (x64/x86).

.DESCRIPTION
    1. Detecta Visual Studio 2022 usando vswhere.exe (Verifica su existencia primero).
    2. Valida la existencia de vcvarsall.bat antes de intentar ejecutarlo.
    3. Permite elegir arquitectura.
    4. Verifica si pwsh, powershell y cmd están disponibles en el sistema.
    5. Personaliza el prompt para indicar la arquitectura y solo la carpeta actual.
#>

function Spawn-BuildShell {
    # --- 1. Verificación de vswhere.exe ---
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswherePath)) {
        Write-Error "No se encontró vswhere.exe. Asegúrate de tener instalado Visual Studio Installer."
        return
    }

    # --- 2. Localización de Visual Studio ---
    $vsPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsPath) {
        Write-Error "No se detectó una instalación de C++ Build Tools compatible."
        return
    }

    $vcvarsall = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
    if (-not (Test-Path $vcvarsall)) {
        Write-Error "No se encontró vcvarsall.bat en: $vcvarsall"
        return
    }

    # --- 3. Menú de Arquitectura ---
    Write-Host "`n--- Configuración de Entorno MSVC ---" -ForegroundColor Cyan
    Write-Host "1. x64 (64 bits)"
    Write-Host "2. x86 (32 bits)"
    
    $choice = Read-Host "Selecciona arquitectura (1 o 2)"
    $arch = switch ($choice) {
        '1' { "x64" }
        '2' { "x86" }
        default { Write-Warning "Opción cancelada."; return }
    }

    # --- 4. Verificación de Shell ---
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { 
        $shellExe = "pwsh" 
    } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 
        $shellExe = "powershell" 
    } else {
        Write-Error "No se encontró ni pwsh ni powershell en el sistema."
        return
    }

    if (-not (Get-Command cmd.exe -ErrorAction SilentlyContinue)) {
        Write-Error "No se encontró cmd.exe. Es necesario para cargar el entorno."
        return
    }

    Write-Host "Iniciando $shellExe para $arch..." -ForegroundColor DarkGray

    # --- 5. Creación del Comando ---
    # El prompt minimalista que funcionó perfecto en tu prueba
    $promptCommand = "function prompt { `$dir = Split-Path -Leaf (Get-Location); if (-not `$dir) { `$dir = (Get-Location).Drive.Name + ':\' }; Write-Host '[MSVC $arch] ' -NoNewline -ForegroundColor Green; Write-Host `$dir -NoNewline -ForegroundColor Cyan; return ' > ' }"

    # --- 6. Ejecución en Memoria (Adiós archivo temporal) ---
    # Usamos "&&" para encadenar la carga del entorno y la apertura de PowerShell 
    # en una sola instrucción de cmd.exe. Esto evita el mensaje "¿Desea terminar el trabajo por lotes?".
    $cmdInstruction = "call `"$vcvarsall`" $arch && $shellExe -NoExit -Command `"$promptCommand`""
    
    & cmd.exe /c $cmdInstruction
}

# Ejecutar la función principal
Spawn-BuildShell
