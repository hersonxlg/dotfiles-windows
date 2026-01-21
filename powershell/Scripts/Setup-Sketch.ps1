<#
.SYNOPSIS
    Configurador interactivo para proyectos Arduino (CLI).

.DESCRIPTION
    Esta herramienta es un asistente interactivo (TUI) para generar el archivo de configuración 
    'sketch.yaml' necesario para compilar y subir código a placas Arduino.
    
    Características principales:
    - Interfaz de alto contraste y fácil lectura.
    - Navegación estilo Vim (j/k) y flechas estándar.
    - Modo Búsqueda Inteligente: Filtrado por múltiples palabras clave.
    - Salida rápida estilo Vim: Secuencia 'kj' funciona como Escape.
    - Detección automática de placas instaladas vía 'arduino-cli'.

.NOTES
    Dependencias: Requiere tener instalado 'arduino-cli' en el PATH.
    Autor: Gemini AI & User
    Versión: 1.0.0 (Production Ready)

.EXAMPLE
    .\Setup-Sketch.ps1
    Inicia el asistente interactivo.

.EXAMPLE
    Get-Help .\Setup-Sketch.ps1 -Full
    Muestra esta ayuda detallada.
#>

# =============================================================================
# CONFIGURACIÓN DEL ENTORNO
# =============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$yamlPath = Join-Path (Get-Location) "sketch.yaml"

# =============================================================================
# VARIABLES GLOBALES
# =============================================================================
# Opciones estándar para monitores serie
$BaudRates = @(9600, 19200, 38400, 57600, 74880, 115200, 230400, 460800, 921600)
$EOLs = @("LF", "CR", "CRLF", "None")

# Configuración de UI
$PageSize = 15          # Cantidad de elementos visibles en la lista
$VimEscTimeout = 600    # Tiempo (ms) para detectar la secuencia 'kj' como Escape

# =============================================================================
# CARGA DE CONFIGURACIÓN PREVIA (si existe)
# =============================================================================
$currConf = @{ Port=$null; FQBN=$null; Baud=9600; EOL="LF" }
if (Test-Path $yamlPath) {
    try {
        $txt = Get-Content $yamlPath -Raw
        # Extracción básica mediante Regex para evitar dependencias de parsers YAML
        if ($txt -match "default_port:\s*([^\s]+)") { $currConf.Port = $matches[1] }
        if ($txt -match "default_fqbn:\s*([^\s]+)") { $currConf.FQBN = $matches[1] }
        if ($txt -match "baud:\s*(\d+)") { $currConf.Baud = [int]$matches[1] }
        if ($txt -match "eol:\s*(\w+)") { $currConf.EOL = $matches[1] }
    } catch {}
}

# =============================================================================
# INICIALIZACIÓN: CARGA DE PLACAS
# =============================================================================
Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   CARGANDO PLACAS (arduino-cli)...       " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan

try {
    # Llama a arduino-cli y formatea la salida para crear objetos de PowerShell
    $rawList = arduino-cli board listall | Select-Object -Skip 1
    $AllBoards = @()
    foreach ($line in $rawList) {
        if ($line -match "^(.+?)\s{2,}(.+)$") {
            $AllBoards += @{ Name = $matches[1].Trim(); FQBN = $matches[2].Trim() }
        }
    }
    # Opción de respaldo manual
    $AllBoards += @{ Name = "[ OPCIÓN MANUAL ]"; FQBN = "MANUAL" }
} catch {
    Write-Host " [ ERROR ] arduino-cli no encontrado o error de ejecución." -ForegroundColor Red; exit
}

# =============================================================================
# FUNCIONES AUXILIARES
# =============================================================================

<#
.SYNOPSIS
    Filtra una lista de objetos basándose en múltiples palabras clave.
.DESCRIPTION
    Implementa una lógica 'AND'. El elemento debe contener TODAS las palabras
    escritas en la query para ser devuelto.
#>
function Get-FilteredList {
    param($SourceData, $Query)
    
    if ([string]::IsNullOrWhiteSpace($Query)) { return $SourceData }

    # Divide la búsqueda por espacios (ej: "esp32 s3" -> "esp32", "s3")
    $terms = $Query -split "\s+" | Where-Object { $_ -ne "" }
    
    $result = $SourceData | Where-Object {
        $item = $_; $matchAll = $true
        foreach ($term in $terms) {
            # Verifica coincidencia en Nombre o FQBN (Case-insensitive)
            if (-not ($item.Name -match $term -or $item.FQBN -match $term)) { 
                $matchAll = $false; break 
            }
        }
        $matchAll
    }

    if ($result.Count -eq 0) { return @(@{ Name="[ SIN COINCIDENCIAS ]"; FQBN="NONE" }) }
    return $result
}

<#
.SYNOPSIS
    Motor principal de la interfaz de usuario (TUI).
.DESCRIPTION
    Maneja el bucle de renderizado, la entrada del teclado, la lógica Vim (j/k/kj)
    y el filtrado en tiempo real.
#>
function Show-Menu-Advanced {
    param(
        [string]$Title,      # Título del paso actual
        [array]$Data,        # Lista de objetos a mostrar
        [string]$CurrentVal  # Valor preseleccionado (si existe)
    )

    $filteredList = $Data
    $cursorIndex = 0
    $scrollOffset = 0
    
    # Estado del modo búsqueda
    $searchQuery = ""
    $isSearching = $false
    
    # Estado para lógica Vim 'kj' (Escape diferido)
    $pendingK = $false
    $pendingKTime = [DateTime]::MinValue

    # Pre-seleccionar el valor actual si existe en la lista
    if ($CurrentVal) {
        for ($i=0; $i -lt $Data.Count; $i++) {
            if ($Data[$i].FQBN -eq $CurrentVal) { $cursorIndex = $i; break }
        }
    }

    try {
        [Console]::CursorVisible = $false
        $needsRedraw = $true

        while ($true) {
            # ---------------------------------------------------------
            # 1. CONTROL DE TIEMPO (Debounce para tecla 'k')
            # ---------------------------------------------------------
            # Si se pulsó 'k', esperamos $VimEscTimeout ms. Si no llega una 'j',
            # asumimos que el usuario quería escribir/navegar con 'k'.
            if ($pendingK) {
                $elapsed = ([DateTime]::Now - $pendingKTime).TotalMilliseconds
                if ($elapsed -gt $VimEscTimeout) {
                    $searchQuery += "k"; $pendingK = $false; $needsRedraw = $true
                    # Actualizar filtro si estábamos escribiendo
                    if ($isSearching) {
                        $filteredList = Get-FilteredList -SourceData $Data -Query $searchQuery
                        $cursorIndex = 0
                    }
                }
            }

            # ---------------------------------------------------------
            # 2. RENDERIZADO DE PANTALLA
            # ---------------------------------------------------------
            # Calcular scroll
            if ($cursorIndex -ge $scrollOffset + $PageSize) { $scrollOffset = $cursorIndex - $PageSize + 1 }
            if ($cursorIndex -lt $scrollOffset) { $scrollOffset = $cursorIndex }

            if ($needsRedraw) {
                Clear-Host
                Write-Host "==========================================" -ForegroundColor Cyan
                Write-Host "   ARDUINO CONFIGURATOR                   " -ForegroundColor White
                Write-Host "==========================================" -ForegroundColor Cyan
                Write-Host " $Title" -ForegroundColor Yellow
                
                # Cabecera de contadores (Alto Contraste: Cyan)
                $countStr = " TOTAL: {0:D4} | VISIBLES: {1:D4}" -f $Data.Count, $filteredList.Count
                Write-Host $countStr -ForegroundColor Cyan 
                
                # Barra de Estado / Input
                if ($isSearching) {
                    Write-Host " BUSCAR > " -NoNewline -ForegroundColor Green
                    Write-Host "$searchQuery" -NoNewline -ForegroundColor White
                    Write-Host "_" -ForegroundColor Gray
                } elseif ($searchQuery.Length -gt 0) {
                    Write-Host " FILTRO > " -NoNewline -ForegroundColor Blue
                    Write-Host "$searchQuery" -ForegroundColor White
                } else {
                    Write-Host " " # Espaciador
                }

                Write-Host "------------------------------------------" -ForegroundColor DarkGray
                
                # Dibujar elementos visibles
                $endIndex = [Math]::Min($filteredList.Count, $scrollOffset + $PageSize)
                for ($i = $scrollOffset; $i -lt $endIndex; $i++) {
                    $item = $filteredList[$i]
                    $display = $item.Name
                    $p="   "; $c="White"; $b="Black"; $s=""
                    
                    if ($item.FQBN -eq $CurrentVal) { $s=" (Actual)"; $c="DarkGray" }
                    if ($i -eq $cursorIndex) { $p=" > "; $c="Black"; $b="Cyan"; if($s){$s=" (MANTENER)"} }
                    
                    if ($display.Length -gt 60) { $display = $display.Substring(0, 57) + "..." }
                    Write-Host "$p $display $s" -ForegroundColor $c -BackgroundColor $b
                }
                
                # Rellenar líneas vacías para mantener la altura constante
                $linesPrinted = $endIndex - $scrollOffset
                if ($linesPrinted -lt $PageSize) { for ($k=0; $k -lt ($PageSize - $linesPrinted); $k++) { Write-Host "" } }
                
                Write-Host "------------------------------------------" -ForegroundColor DarkGray
                
                # Pie de página con instrucciones
                if ($isSearching) {
                    Write-Host " Escribe palabras clave... (Espere para 'k')" -ForegroundColor Green
                } else {
                    if ($searchQuery.Length -gt 0) {
                        Write-Host " [Esc] Borrar Filtro  [Enter] Elegir" -ForegroundColor Cyan
                    } else {
                        Write-Host " [j/k] Navegar  [/] Buscar  [Enter] Elegir" -ForegroundColor Gray
                    }
                }
                $needsRedraw = $false
            }

            # ---------------------------------------------------------
            # 3. LECTURA DE ENTRADA (NO BLOQUEANTE)
            # ---------------------------------------------------------
            if ([Console]::KeyAvailable) {
                $keyInfo = [Console]::ReadKey($true)
                $key = $keyInfo.Key
                $char = $keyInfo.KeyChar
                $needsRedraw = $true

                # --- CASO A: ESTAMOS ESCRIBIENDO (MODO BÚSQUEDA) ---
                if ($isSearching) {
                    # Detección de Escape 'kj'
                    if ($pendingK) {
                        if ($char -eq 'j') { 
                            # SECUENCIA CUMPLIDA: Salir de búsqueda
                            $pendingK = $false; $isSearching = $false; continue 
                        } else { 
                            # NO ERA SECUENCIA: Confirmar 'k' y procesar la nueva tecla
                            $searchQuery += "k"; $pendingK = $false 
                        }
                    }

                    if ($key -eq "Enter") { return $filteredList[$cursorIndex] }
                    elseif ($key -eq "Escape") { $isSearching = $false; $pendingK = $false }
                    elseif ($key -eq "Backspace") { if ($searchQuery.Length -gt 0) { $searchQuery = $searchQuery.Substring(0, $searchQuery.Length - 1) } }
                    elseif ($key -eq "UpArrow") { if ($cursorIndex -gt 0) { $cursorIndex-- } }
                    elseif ($key -eq "DownArrow") { if ($cursorIndex -lt $filteredList.Count - 1) { $cursorIndex++ } }
                    elseif (-not [char]::IsControl($char)) {
                        # Inicio de secuencia posible 'k'
                        if ($char -eq 'k') { $pendingK = $true; $pendingKTime = [DateTime]::Now; continue }
                        else { $searchQuery += $char }
                    }

                    # Actualizar lista filtrada (si no estamos esperando validación de 'k')
                    if (-not $pendingK) {
                        $filteredList = Get-FilteredList -SourceData $Data -Query $searchQuery
                        $cursorIndex = 0; $scrollOffset = 0
                    }

                # --- CASO B: ESTAMOS NAVEGANDO (MODO LISTA) ---
                } else {
                    if ($char -eq '/') { $isSearching = $true; $cursorIndex = 0 }
                    elseif ($key -eq "UpArrow")   { if ($cursorIndex -gt 0) { $cursorIndex-- } }
                    elseif ($key -eq "DownArrow") { if ($cursorIndex -lt $filteredList.Count - 1) { $cursorIndex++ } }
                    elseif ($key -eq "Enter")     { return $filteredList[$cursorIndex] }
                    elseif ($key -eq "Escape") {
                        # Primer Esc: Borra filtro. Segundo Esc: Sale.
                        if ($searchQuery.Length -gt 0) { $searchQuery = ""; $filteredList = $Data; $cursorIndex = 0 }
                        else { exit }
                    }
                    # Navegación Vim simple
                    elseif ($char -eq 'k') { if ($cursorIndex -gt 0) { $cursorIndex-- } }
                    elseif ($char -eq 'j') { if ($cursorIndex -lt $filteredList.Count - 1) { $cursorIndex++ } }
                }
            }
            # Pequeña pausa para no saturar la CPU
            Start-Sleep -Milliseconds 20
        }
    } finally { [Console]::CursorVisible = $true }
}

# =============================================================================
# FLUJO PRINCIPAL DE EJECUCIÓN
# =============================================================================

# --- PASO 1: SELECCIÓN DE PUERTO SERIAL ---
$selectedPort = $currConf.Port
$portCursor = 0
$lastPortsHash = ""; $needsRedraw = $true
$initialPorts = [System.IO.Ports.SerialPort]::GetPortNames()

# Intentar posicionar el cursor en el puerto guardado anteriormente
if ($currConf.Port) { $idx = $initialPorts.IndexOf($currConf.Port); if ($idx -ge 0) { $portCursor = $idx } }

try {
    [Console]::CursorVisible = $false
    while ($true) {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames()
        # Detectar cambios de hardware (conectar/desconectar USB) en tiempo real
        $currentPortsHash = $ports -join ","
        if ($currentPortsHash -ne $lastPortsHash) { $needsRedraw = $true; $lastPortsHash = $currentPortsHash; if($portCursor -ge $ports.Count){$portCursor=0} }

        if ($needsRedraw) {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   ARDUINO CONFIGURATOR                   " -ForegroundColor White
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host " PASO 1: PUERTO SERIAL" -ForegroundColor Yellow
            Write-Host "------------------------------------------" -ForegroundColor DarkGray
            if ($ports.Count -eq 0) { Write-Host "`n [ ... ] Conecta tu placa..." -ForegroundColor DarkGray }
            else {
                for ($i=0; $i -lt $ports.Count; $i++) {
                    $p=$ports[$i]; $pre="   "; $col="White"; $bg="Black"; $suf=""
                    if ($p -eq $currConf.Port) { $suf=" (Guardado)"; $col="Gray" }
                    if ($i -eq $portCursor) { $pre=" > "; $col="Black"; $bg="Cyan" }
                    Write-Host "$pre[$($i+1)] $p $suf" -ForegroundColor $col -BackgroundColor $bg
                }
            }
            Write-Host "`n [j/k] Navegar  [Enter] Elegir" -ForegroundColor Gray
            $needsRedraw = $false
        }

        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true); $needsRedraw = $true
            if ($k.Key -eq "UpArrow" -or $k.KeyChar -eq 'k') { $portCursor-- }
            elseif ($k.Key -eq "DownArrow" -or $k.KeyChar -eq 'j') { $portCursor++ }
            elseif ($k.Key -eq "Enter" -and $ports.Count -gt 0) { $selectedPort = $ports[$portCursor]; break }
            elseif ($k.Key -eq "Escape") { exit }
            # Corrección de límites
            if ($ports.Count -gt 0) { if ($portCursor -lt 0) { $portCursor = $ports.Count - 1 }; if ($portCursor -ge $ports.Count) { $portCursor = 0 } }
        } else { Start-Sleep -Milliseconds 100 }
    }
} finally { [Console]::CursorVisible = $true }

# --- PASO 2: SELECCIÓN DE PLACA ---
$selectedBoardObj = Show-Menu-Advanced -Title "PASO 2: SELECCIONA TU PLACA" -Data $AllBoards -CurrentVal $currConf.FQBN
if ($selectedBoardObj.FQBN -eq "NONE") { exit }

# Manejo de entrada manual si el usuario no encuentra su placa
if ($selectedBoardObj.FQBN -eq "MANUAL") {
    $manFQBN = Read-Host "  > Escribe el FQBN"
    $selectedBoardObj = @{ Name="Manual"; FQBN = $manFQBN }
}

# --- PASO 3 & 4: CONFIGURACIÓN SERIAL (BAUD & EOL) ---
$baudObjs = $BaudRates | ForEach-Object { @{ Name = "$_"; FQBN = "$_" } }
$eolObjs  = $EOLs | ForEach-Object { @{ Name = "$_"; FQBN = "$_" } }

$selectedBaud = (Show-Menu-Advanced -Title "PASO 3: VELOCIDAD (BAUD)" -Data $baudObjs -CurrentVal $currConf.Baud).FQBN
$selectedEOL  = (Show-Menu-Advanced -Title "PASO 4: FIN DE LÍNEA (EOL)" -Data $eolObjs -CurrentVal $currConf.EOL).FQBN

# =============================================================================
# GUARDADO DE CONFIGURACIÓN
# =============================================================================
Clear-Host
Write-Host " GUARDANDO..." -ForegroundColor Yellow

# Creación del contenido YAML manualmente para evitar dependencias
$yamlContent = @"
default_fqbn: $($selectedBoardObj.FQBN)
default_port: $selectedPort
profiles:
  main:
    fqbn: $($selectedBoardObj.FQBN)
    port: $selectedPort
    monitor:
      baud: $selectedBaud
      eol: $selectedEOL
      config: 8N1
"@

$yamlContent | Out-File -FilePath $yamlPath -Encoding UTF8
Write-Host " [ ÉXITO ] Configuración Lista." -ForegroundColor Green
Write-Host ""
