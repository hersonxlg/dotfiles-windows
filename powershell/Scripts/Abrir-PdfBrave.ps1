<#
.SYNOPSIS
    Abre un archivo PDF local en Brave (Nueva ventana + Pantalla completa).
    SOLUCIÓN ROBUSTA para caracteres especiales (+, #, %, espacios).

.PARAMETER RutaArchivo
    La ruta del archivo PDF (ej: "C:\Docs\c++.pdf")

.PARAMETER ArgsBrave
    Argumentos adicionales para Brave.
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$RutaArchivo,

    [Parameter(Mandatory=$false, Position=1)]
    [string[]]$ArgsBrave
)

Set-StrictMode -Version Latest

# --- 1. DETECCIÓN DE BRAVE ---
$RutasPosibles = @(
    "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
    "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
)

$BraveExe = $null
foreach ($ruta in $RutasPosibles) {
    if (Test-Path -LiteralPath $ruta) {
        $BraveExe = $ruta
        break
    }
}

if (-not $BraveExe) {
    Write-Error "Error: No se encontró 'brave.exe'."
    exit 1
}

# --- 2. VALIDACIÓN DEL ARCHIVO ---
# Usamos -LiteralPath para evitar errores con corchetes []
if (-not (Test-Path -LiteralPath $RutaArchivo -PathType Leaf)) {
    Write-Error "Error: El archivo no existe -> $RutaArchivo"
    exit 1
}

$ItemArchivo = Get-Item -LiteralPath $RutaArchivo

# --- 3. CONVERSIÓN Y CODIFICACIÓN URI (La Corrección) ---
try {
    # Paso A: Convertir ruta de Windows a URI estándar (file://...)
    # Esto maneja automáticamente espacios (%20) y caracteres unicode.
    $Uri = [System.Uri]$ItemArchivo.FullName
    $RutaFinal = $Uri.AbsoluteUri

    # Paso B: PARCHE PARA CHROMIUM / BRAVE
    # System.Uri NO codifica '+' ni '#' porque son válidos en URL estándar.
    # Pero Chromium los necesita codificados en CLI para no interpretarlos mal.
    # +  -> %2B (Evita que se lea como espacio)
    # #  -> %23 (Evita que se lea como ancla html)
    
    $RutaFinal = $RutaFinal.Replace("+", "%2B")
    $RutaFinal = $RutaFinal.Replace("#", "%23")
}
catch {
    Write-Error "Error al procesar la ruta del archivo."
    exit 1
}

# --- 4. PREPARAR ARGUMENTOS ---
$ListaArgumentos = @("--new-window", "--start-fullscreen")

if ($ArgsBrave) {
    $ListaArgumentos += $ArgsBrave
}

# Añadimos la ruta "sanitizada" al final
$ListaArgumentos += $RutaFinal

# --- 5. EJECUCIÓN ---
Write-Host "Abriendo: $($ItemArchivo.Name)" -ForegroundColor Cyan
Write-Host "URL enviada: $RutaFinal" -ForegroundColor DarkGray

Start-Process -FilePath $BraveExe -ArgumentList $ListaArgumentos
