<#
.SYNOPSIS
    Monitor Serial Avanzado "monitor" para desarrollo con Arduino/ESP32.

.DESCRIPTION
    Herramienta de monitoreo serial para consola (CLI) con características de nivel industrial:
    - Auto-Reconexión (Self-Healing): Detecta desconexiones físicas y reconecta automáticamente.
    - Anti-Congelamiento: Previene el bloqueo de la terminal al desconectar USB (Fix para Arduino Mega).
    - Interfaz TUI: Pantalla dividida (RX arriba / TX abajo) sin parpadeos.
    - Configuración Inteligente: Lee 'sketch.yaml' automáticamente.

.PARAMETER PortName
    Nombre del puerto COM (ej: COM3, /dev/ttyUSB0). 
    Si se omite, se intenta leer del archivo 'sketch.yaml'.

.PARAMETER BaudRate
    Velocidad de transmisión. Admite valores estándar (9600, 115200, etc.).
    Usa 0 para detección automática desde 'sketch.yaml' o defecto (9600).

.PARAMETER Echo
    Muestra en la consola local lo que envías (TX). Por defecto: $true.

.PARAMETER EOL
    Define qué carácter invisible se envía al presionar ENTER.
    Opciones: 'None', 'LF' (Default), 'CR', 'CRLF'.
    - LF: Line Feed (\n) -> Estándar Linux/Arduino moderno.
    - CR: Carriage Return (\r) -> Equipos antiguos.
    - CRLF: Ambos (\r\n) -> Estándar Windows/Internet.

.EXAMPLE
    .\monitor.ps1
    Inicia en modo automático buscando configuración en la carpeta actual.

.EXAMPLE
    .\monitor.ps1 COM5 -BaudRate 115200
    Inicia conexión directa a COM5 con 115200 baudios.

.NOTES
    Autor: Gemini AI & User
    Versión: 1.0.0 (Golden Master)
#>

param (
    [Parameter(Mandatory=$false, Position=0)] 
    [string]$PortName,

    [Parameter(Mandatory=$false, Position=1)]
    [ValidateSet(0, 9600, 19200, 38400, 57600, 74880, 115200, 230400, 460800, 921600)] 
    [int]$BaudRate = 0, # 0 = Auto/Default

    [Parameter(Mandatory=$false)] 
    [bool]$Echo = $true,
    
    [Parameter(Mandatory=$false)] 
    [ValidateSet("None", "LF", "CR", "CRLF")] 
    [string]$EOL = "LF" 
)

# Configuración de seguridad: Detener script ante cualquier error no controlado
$ErrorActionPreference = "Stop"
# Codificación UTF8 para soportar tildes y caracteres especiales
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::TreatControlCAsInput = $true
} catch {
    # Si falla (ej. en ISE o consolas redirigidas), continuamos sin romper el script
    Write-Warning "No se pudo configurar la consola avanzada. Algunas funciones visuales o Ctrl+C podrían no responder igual."
}

# =============================================================================
# 1. GESTIÓN DE CONFIGURACIÓN (AUTO-DISCOVERY)
# =============================================================================

function Get-ProjectConfig {
    <#
    .SYNOPSIS
        Analiza el archivo 'sketch.yaml' del Arduino CLI.
    .DESCRIPTION
        Busca puerto, baudios y EOL usando expresiones regulares para evitar
        dependencias de librerías YAML externas.
    #>
    $configFile = Join-Path (Get-Location) "sketch.yaml"
    $config = @{ Port = $null; Baud = $null; EOL = $null }
    
    if (Test-Path $configFile) {
        try {
            $content = Get-Content $configFile -Raw
            # Regex para puerto (ej: port: COM3)
            if ($content -match "(?mi)^[\s-]*port:\s*[`"']?([a-z0-9/_]+)[`"']?") { 
                $config.Port = $matches[1] 
            }
            # Regex para baudios (ej: baud: 115200)
            if ($content -match "(?mi)^[\s-]*\w*(baud|speed|rate)\w*:\s*[`"']?(\d+)[`"']?") { 
                $config.Baud = [int]$matches[2] 
            }
            # Regex para EOL
            if ($content -match "(?mi)^[\s-]*eol:\s*[`"']?(None|LF|CR|CRLF)[`"']?") { 
                $config.EOL = $matches[1] 
            }
        } catch {}
    }
    return $config
}

# --- APLICACIÓN DE PRIORIDADES ---
# Prioridad: Argumento CLI > sketch.yaml > Defecto

$yamlConfig = Get-ProjectConfig

# Puerto
if ([string]::IsNullOrEmpty($PortName)) { 
    if ($yamlConfig.Port) { $PortName = $yamlConfig.Port } 
    else { Write-Host " [ ERROR ] Debes especificar un Puerto COM o tener un sketch.yaml"; exit } 
}

# Baudios
if ($BaudRate -eq 0) { 
    if ($yamlConfig.Baud) { $BaudRate = $yamlConfig.Baud } 
    else { $BaudRate = 9600 } 
}

# EOL
if ($yamlConfig.EOL -and $PSBoundParameters.ContainsKey('EOL') -eq $false) { 
    $EOL = $yamlConfig.EOL 
}

# =============================================================================
# 2. VARIABLES DE ESTADO GLOBAL
# =============================================================================

$global:connStatus = "DISCONNECTED" # Estados: CONNECTED, DISCONNECTED
$global:portObj = $null             # Objeto System.IO.Ports.SerialPort
$running = $true                    # Control del bucle principal

# Buffers de datos
$history = @()       # Historial de líneas recibidas (RX) y enviadas (TX)
$inputBuffer = ""    # Línea que el usuario está escribiendo
$rxBuffer = ""       # Buffer crudo de bytes entrantes

# Flags de Renderizado (Optimización de CPU)
$updateHistory = $true 
$updateInput = $true
$lastWidth = 0; $lastHeight = 0

# Cargar librería .NET y limpiar pantalla
#### Add-Type -AssemblyName System.IO.Ports

# --- FIX DE LIBRERÍAS (Blindaje para PS 5.1 y PS Core) ---
$libLoaded = $false
try {
    Add-Type -AssemblyName "System.IO.Ports" -ErrorAction Stop
    $libLoaded = $true
} catch {
    try {
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.IO.Ports")
        $libLoaded = $true
    } catch {}
}

if (-not $libLoaded) {
    Write-Host " [ FATAL ] Error: No se pudo cargar System.IO.Ports." -ForegroundColor Red
    exit
}

[Console]::CursorVisible = $false
Clear-Host

# =============================================================================
# 3. LÓGICA DE HARDWARE (CONEXIÓN Y SONDEO)
# =============================================================================

function Connect-Port {
    <#
    .SYNOPSIS
        Intenta establecer conexión física con el puerto.
    .RETURN
        $true si tiene éxito, $false si falla.
    #>
    
    # Check 1: ¿Windows reconoce el puerto? (Rápido)
    if ([System.IO.Ports.SerialPort]::GetPortNames() -notcontains $PortName) { 
        return $false 
    }

    try {
        # Limpieza preventiva
        if ($global:portObj) { $global:portObj.Close(); $global:portObj.Dispose() }
        
        $p = New-Object System.IO.Ports.SerialPort $PortName, $BaudRate, "None", 8, "One"
        $p.Encoding = [System.Text.Encoding]::UTF8
        
        # TIMEOUTS CRÍTICOS:
        # ReadTimeout bajo (50ms) evita que el script se cuelgue si el driver falla.
        $p.ReadTimeout = 50  
        $p.WriteTimeout = 500
        $p.DtrEnable = $true # Reinicia Arduino al conectar
        $p.RtsEnable = $true
        
        $p.Open()
        $p.DiscardInBuffer()
        
        $global:portObj = $p
        $global:connStatus = "CONNECTED"
        Add-Log -text " >> SISTEMA: CONEXIÓN ESTABLECIDA ($PortName)" -color "DarkGreen"
        return $true
    } catch {
        Disconnect-Port -Silent $true
        return $false
    }
}

function Disconnect-Port {
    <#
    .SYNOPSIS
        Cierra y libera los recursos del puerto de forma segura.
    #>
    param([bool]$Silent = $false)
    try {
        if ($global:portObj) { 
            if ($global:portObj.IsOpen) { $global:portObj.Close() }
            $global:portObj.Dispose() 
        }
    }
    catch {
    }
    
    $global:portObj = $null
    $global:connStatus = "DISCONNECTED"
    
    if (-not $Silent) {
        Add-Log -text " >> SISTEMA: DESCONEXIÓN DETECTADA." -color "Red"
    }
}

function Verify-Hardware-Link {
    <# 
    .SYNOPSIS
        Verificación de salud del hardware (Anti-Freeze).
    .DESCRIPTION
        Esencial para Arduino Mega/Uno. Verifica activamente si el hardware responde
        leyendo el pin 'CDHolding'. Si el cable se desconecta, esta lectura falla
        antes de que intentemos leer datos, evitando el congelamiento del script.
    #>
    
    # 1. Comprobar lista del registro de Windows
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($ports -notcontains $PortName) {
        Disconnect-Port; return $false
    }

    # 2. Comprobar respuesta física del driver
    if ($global:portObj -ne $null -and $global:portObj.IsOpen) {
        try {
            $null = $global:portObj.CDHolding # Sonda activa
        } catch {
            Disconnect-Port; return $false
        }
    } else {
        Disconnect-Port; return $false
    }

    return $true
}

# =============================================================================
# 4. MOTOR GRÁFICO (UI)
# =============================================================================

function Add-Log {
    <#
    .SYNOPSIS
        Añade una línea al historial visual.
    #>
    param($text, $color)
    $clean = $text.Replace("`t", "    ").Trim()
    if ($clean.Length -gt 0) {
        $script:history += [PSCustomObject]@{Text=$clean; Color=$color}
        # Buffer circular: Mantiene solo las últimas 500 líneas
        if ($script:history.Count -gt 500) { 
            $script:history = $script:history | Select-Object -Last 500 
        }
        $script:updateHistory = $true
    }
}

function Render-UI {
    <#
    .SYNOPSIS
        Redibuja toda la interfaz (RX, TX, Barra de Estado, Input).
    .DESCRIPTION
        Utiliza SetCursorPosition para evitar parpadeos (Flicker-Free).
    #>
    $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
    
    # [CORRECCIÓN 1]: Usamos $w - 1 para limpiar mejor el borde derecho sin saltar de línea
    $safeWidth = $w - 1 
    
    # [CORRECCIÓN 2 - LA CLAVE]: Cambiamos -3 por -2.
    # Esto hace que el historial baje hasta tocar la barra de estado, eliminando el hueco.
    $historyHeight = $h - 2

    try {
        # --- 1. ÁREA DE HISTORIAL (RX/TX) ---
        [Console]::SetCursorPosition(0, 0)
        $linesToPrint = $history | Select-Object -Last $historyHeight
        
        # Limpiar líneas vacías superiores
        if ($linesToPrint.Count -lt $historyHeight) {
            $empty = $historyHeight - $linesToPrint.Count
            for ($i=0; $i -lt $empty; $i++) { Write-Host "".PadRight($safeWidth) }
        }

        # Imprimir líneas
        foreach ($line in $linesToPrint) {
            $txt = $line.Text
            if ($txt.Length -gt $safeWidth) { $txt = $txt.Substring(0, $safeWidth) }
            Write-Host $txt.PadRight($safeWidth) -ForegroundColor $line.Color
        }

        # --- 2. BARRA DE ESTADO ---
        [Console]::SetCursorPosition(0, $h - 2)
        
        $stColor = "Green"; $stText = "CONECTADO"
        if ($global:connStatus -eq "DISCONNECTED") { $stColor = "Red"; $stText = "BUSCANDO..." }
        
        Write-Host " ESTADO: " -NoNewline -ForegroundColor Gray
        Write-Host "$stText " -NoNewline -ForegroundColor $stColor
        
        $info = "| [PORT: $PortName @ $BaudRate] | [EOL: $EOL] | [ESC: Salir] "
        
        $currentX = $stText.Length + 9
        $dashCount = $safeWidth - $currentX - $info.Length
        if ($dashCount -lt 0) { $dashCount = 0 }
        
        Write-Host ("-" * $dashCount + $info) -ForegroundColor DarkGray -NoNewline

        # --- 3. ÁREA DE INPUT ---
        [Console]::SetCursorPosition(0, $h - 1)
        Write-Host "> " -ForegroundColor Yellow -NoNewline
        
        $cleanIn = $inputBuffer
        if ($cleanIn.Length -gt ($w - 4)) { 
            $cleanIn = $cleanIn.Substring($cleanIn.Length - ($w - 4)) 
        }
        
        Write-Host $cleanIn -ForegroundColor White -NoNewline
        Write-Host "_" -ForegroundColor Green -NoNewline 
        
        # Limpieza final (Agregué protección contra error negativo por seguridad)
        $pad = $w - $cleanIn.Length - 4
        if ($pad -lt 0) { $pad = 0 }
        Write-Host "".PadRight($pad) -NoNewline

    } catch {}
}


# =============================================================================
# 5. BUCLE PRINCIPAL (MAIN LOOP)
# =============================================================================

# Intento de conexión inicial
$null = Connect-Port
if ($global:connStatus -eq "DISCONNECTED") {
    Add-Log -text " >> MONITOR INICIADO. ESPERANDO DISPOSITIVO..." -color "Yellow"
}

Render-UI

$reconnectTimer = [DateTime]::Now

while ($running) {
    # A. GESTIÓN DE REDIMENSIONAMIENTO DE VENTANA
    if ([Console]::WindowWidth -ne $lastWidth -or [Console]::WindowHeight -ne $lastHeight) {
        $lastWidth = [Console]::WindowWidth; $lastHeight = [Console]::WindowHeight
        if ([Console]::BufferWidth -ne $lastWidth) { try { [Console]::BufferWidth = $lastWidth } catch {} }
        Clear-Host; $updateHistory = $true
    }

    # B. MÁQUINA DE ESTADOS DE CONEXIÓN
    if ($global:connStatus -eq "CONNECTED") {
        
        # VERIFICACIÓN ACTIVA DE HARDWARE (Fix Mega)
        if (Verify-Hardware-Link) {
            try {
                # Lectura no bloqueante
                if ($global:portObj.BytesToRead -gt 0) {
                    $chunk = $global:portObj.ReadExisting()
                    $rxBuffer += $chunk
                    
                    # Procesar datos por líneas
                    while ($true) {
                        $idx = $rxBuffer.IndexOf("`n")
                        if ($idx -ge 0) {
                            $rawLine = $rxBuffer.Substring(0, $idx)
                            $rxBuffer = $rxBuffer.Substring($idx + 1)
                            Add-Log -text ($rawLine.Replace("`r", "")) -color "Green"
                        } else { break }
                    }
                }
            } catch {
                # Si falla la lectura, desconectar
                Disconnect-Port; $updateHistory = $true
            }
        } else {
            $updateHistory = $true
        }

    } else {
        # MODO RECONEXIÓN (Timer de 1 segundo)
        if (([DateTime]::Now - $reconnectTimer).TotalMilliseconds -gt 1000) {
            $reconnectTimer = [DateTime]::Now
            if (Connect-Port) { $updateHistory = $true }
            else { 
                # Forzar refresco UI ocasional para mostrar actividad
                $updateHistory = $true 
            }
        }
    }

    # C. LECTURA DE TECLADO (NON-BLOCKING)
    if ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true)
        $updateInput = $true
        
        # Si es Escape O (Tecla C + Control presionado)
        if ($k.Key -eq "Escape" -or ($k.Key -eq "C" -and ($k.Modifiers -band [ConsoleModifiers]::Control))) { 
            $running = $false 
        }
        elseif ($k.Key -eq "Enter") {
            if ($global:connStatus -eq "CONNECTED") {
                try {
                    # Preparar sufijo EOL
                    $suffix = switch ($EOL) { 
                        "None" {""} "LF" {"`n"} "CR" {"`r"} "CRLF" {"`r`n"} 
                    }
                    
                    # Enviar
                    $global:portObj.Write("$inputBuffer$suffix")
                    
                    # Eco local
                    if ($Echo) { Add-Log -text "TX: $inputBuffer" -color "Cyan" }
                } catch {
                    Disconnect-Port; Add-Log -text " [!] Error al enviar." -color "Red"
                }
            } else {
                Add-Log -text " [!] Sin conexión." -color "DarkGray"
            }
            $inputBuffer = ""
        }
        elseif ($k.Key -eq "Backspace") {
            if ($inputBuffer.Length -gt 0) { 
                $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1) 
            }
        }
        else {
            # Permitir cualquier carácter que no sea de control (símbolos, letras, números)
            if (-not [char]::IsControl($k.KeyChar)) { 
                $inputBuffer += $k.KeyChar 
            }
        }
    }

    # D. ACTUALIZACIÓN VISUAL
    if ($updateHistory) { Render-UI; $updateHistory = $false; $updateInput = $false }
    elseif ($updateInput) { Render-UI; $updateInput = $false }

    # E. PAUSA DE CPU (Evita uso del 100% de un núcleo)
    Start-Sleep -Milliseconds 20
}

# =============================================================================
# 6. CIERRE SEGURO
# =============================================================================
try { if ($global:portObj) { $global:portObj.Close() } } catch {}
[Console]::CursorVisible = $true
Clear-Host
Write-Host "Monitor finalizado correctamente." -ForegroundColor Green
