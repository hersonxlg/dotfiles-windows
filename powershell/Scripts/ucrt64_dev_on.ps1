# Archivo: ucrt64_dev_on.ps1

# 1. Definimos la ruta de MSYS2 UCRT64
$MsysPaths = @("C:\msys64\ucrt64\bin","$home\scoop\apps\msys2\current\ucrt64\bin")
$MsysPath = ""

# 2. Verificamos si la ruta de MSYS2 UCRT64 "EXISTE"
foreach($path in $MsysPaths){
    if (Test-Path $path) {
        $MsysPath = $path
        break
    }
}

if ($MsysPath -eq "") {
    Write-Error "El entorno UCRT64 no existe."
    return
}

# 3. Verificamos si ya está activo
if ($env:Path.StartsWith($MsysPath)) {
    Write-Warning "El entorno UCRT64 ya está activo."
    return
}

# 4. Guardamos backups para poder restaurar después
$global:OldPathBackup = $env:Path
$global:OldPromptBackup = Get-Content Function:\prompt

# 5. INYECTAMOS MSYS2 AL INICIO DEL PATH (Prioridad absoluta)
$env:Path = "$MsysPath;" + $env:Path

# 6. PERSONALIZAMOS EL PROMPT (Versión Corta y Elegante)
function global:prompt {
    $FolderName = Split-Path -Leaf -Path (Get-Location)
    Write-Host "[C-DEV] " -NoNewline -ForegroundColor Green
    Write-Host "$FolderName " -NoNewline -ForegroundColor Cyan
    return "> "
}

# 7. WRAPPER INTELIGENTE PARA GCC
#    Soluciona: El uso de $(pkg-config) y el conflicto de múltiples GCC instalados.
function global:gcc {
    # Buscamos el GCC real. El 'Select-Object -First 1' es vital para tu caso (Anaconda/Scoop)
    try {
        $RealGccPath = Get-Command "gcc.exe" -CommandType Application -ErrorAction Stop | 
                       Select-Object -First 1 -ExpandProperty Source
    } catch {
        Write-Error "No se encuentra gcc.exe. Revisa tu instalación de MSYS2."
        return
    }

    # Procesamos los argumentos para emular comportamiento Bash
    $ArgsProcesados = @()
    foreach ($arg in $args) {
        # Si el argumento es texto con espacios (ej: salida de pkg-config), lo partimos
        if (($arg -is [string]) -and ($arg.Contains(" "))) {
            $SubArgs = $arg -split "\s+" | Where-Object { $_ -ne "" }
            $ArgsProcesados += $SubArgs
        }
        else {
            $ArgsProcesados += $arg
        }
    }

    # Ejecutamos el compilador real
    & $RealGccPath @ArgsProcesados
}

Write-Host "`n✅ Entorno UCRT64 ACTIVADO" -ForegroundColor Green
Write-Host "   Wrapper GCC listo: Soporta sintaxis Linux `$(...)" -ForegroundColor Gray
Write-Host "   Ejecuta '. .\ucrt64_dev_off.ps1' para salir.`n"
