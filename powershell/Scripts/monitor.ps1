<#
.SYNOPSIS
    Monitor Serial Avanzado (monitor) para desarrollo con Arduino/ESP32.

.DESCRIPTION
    Esta herramienta es un monitor de puerto serial robusto diseñado para CLI.
    Características principales:
    - Interfaz dividida (Split Screen): Recepción (RX) arriba, Transmisión (TX) abajo.
    - Cero Parpadeo (Flicker-Free): Motor de renderizado estático.
    - Configuración Automática: Lee puerto y velocidad desde 'sketch.yaml' si existe.
    - Selector EOL: Control total sobre los caracteres de fin de línea (LF, CR, CRLF).

.PARAMETER PortName
    El nombre del puerto COM (ej: COM3, /dev/ttyUSB0). 
    Si no se especifica, se intenta leer del archivo 'sketch.yaml'.

.PARAMETER BaudRate
    La velocidad de transmisión en baudios (ej: 9600, 115200).
    Valor por defecto: 9600 (o lo que diga 'sketch.yaml').

.PARAMETER EOL
    Define qué carácter invisible se envía al presionar ENTER.
    Opciones: 'None', 'LF' (Default), 'CR', 'CRLF'.
    - LF: Line Feed (\n) -> Estándar Linux/Arduino moderno.
    - CR: Carriage Return (\r) -> Equipos antiguos.
    - CRLF: Ambos (\r\n) -> Estándar Windows/Internet.

.PARAMETER Echo
    Si es $true (por defecto), muestra en pantalla lo que envías.

.EXAMPLE
    ./monitor.ps1
    Busca configuración en sketch.yaml y se conecta automáticamente.

.EXAMPLE
    ./monitor.ps1 COM12 -BaudRate 115200
    Conexión manual rápida a 115200 baudios.

.EXAMPLE
    ./monitor.ps1 COM3 -EOL CRLF
    Conecta a COM3 y envía \r\n al final de cada comando.

.NOTES
    Autor: Gemini AI (Asistente Técnico)
    Versión: 15.1 (Symbol Fix Edition)
    Requisito: .NET Framework 4.5+ (Nativo en Windows 10/11)
#>

param (
    [Parameter(Mandatory=$false, Position=0)]
    [string]$PortName,

    [Parameter(Mandatory=$false, Position=1)]
    [int]$BaudRate = 0, # 0 indica "Auto/Default"

    [Parameter(Mandatory=$false)]
    [bool]$Echo = $true,
    
    [Parameter(Mandatory=$false)] 
    [ValidateSet("None", "LF", "CR", "CRLF")] 
    [string]$EOL = "LF" 
)

# Configuración estricta de errores para evitar comportamientos "zombie"
$ErrorActionPreference = "Stop"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =============================================================================
# SECCIÓN 1: GESTIÓN DE CONFIGURACIÓN Y ARCHIVOS
# =============================================================================

function Get-ProjectConfig {
    <#
    .SYNOPSIS
        Busca y analiza el archivo 'sketch.yaml' de Arduino CLI.
    .DESCRIPTION
        Intenta extraer el puerto y la velocidad usando expresiones regulares (Regex)
        para evitar dependencias externas de librerías YAML.
    #>
    $configFile = Join-Path (Get-Location) "sketch.yaml"
    $config = @{ Port = $null; Baud = $null; EOL = $null }
    
    if (Test-Path $configFile) {
        try {
            $content = Get-Content $configFile -Raw
            
            # Regex para buscar 'port: COMx' (insensible a mayúsculas)
            if ($content -match "(?mi)^[\s-]*port:\s*[`"']?([a-z0-9/_]+)[`"']?") {
                $config.Port = $matches[1]
                Write-Host " -> Config YAML detectada: Port $($config.Port)" -ForegroundColor DarkGray
            }
            # Regex para buscar 'baudrate: 115200'
            if ($content -match "(?mi)^[\s-]*\w*(baud|speed|rate)\w*:\s*[`"']?(\d+)[`"']?") {
                $config.Baud = [int]$matches[2]
            }
            # Regex para buscar 'eol: CRLF' (personalizado)
            if ($content -match "(?mi)^[\s-]*eol:\s*[`"']?(None|LF|CR|CRLF)[`"']?") {
                $config.EOL = $matches[1]
                Write-Host " -> Config YAML detectada: EOL $($config.EOL)" -ForegroundColor DarkGray
            }
        } catch {
            Write-Warning "No se pudo leer sketch.yaml correctamente."
        }
    }
    return $config
}

# --- LÓGICA DE PRIORIDADES DE CONFIGURACIÓN ---
# 1. Argumentos de Consola (Máxima prioridad)
# 2. Archivo sketch.yaml (Prioridad media)
# 3. Valores por defecto (Prioridad baja)

$yamlConfig = Get-ProjectConfig

# A. Determinar PUERTO
if ([string]::IsNullOrEmpty($PortName)) {
    if ($yamlConfig.Port) { $PortName = $yamlConfig.Port } 
    else {
        Write-Host "ERROR: No se ha especificado un Puerto COM." -ForegroundColor Red
        Write-Host "Ayuda: Usa 'Get-Help ./monitor.ps1 -Full' para ver opciones." -ForegroundColor Yellow
        exit
    }
}

# B. Determinar VELOCIDAD
if ($BaudRate -eq 0) {
    if ($yamlConfig.Baud) { $BaudRate = $yamlConfig.Baud } 
    else { $BaudRate = 9600 } # Default estándar de Arduino
}

# C. Determinar EOL (Solo si el usuario no lo forzó en consola)
if ($yamlConfig.EOL -and $PSBoundParameters.ContainsKey('EOL') -eq $false) {
    $EOL = $yamlConfig.EOL
}

# =============================================================================
# SECCIÓN 2: CONEXIÓN SERIAL (HARDWARE)
# =============================================================================

try {
    Add-Type -AssemblyName System.IO.Ports

    Write-Host "Iniciando monitor en $PortName a $BaudRate baudios..." -ForegroundColor Cyan
    Write-Host "Modo EOL: $EOL" -ForegroundColor DarkGray

    try {
        $port = New-Object System.IO.Ports.SerialPort $PortName, $BaudRate, "None", 8, "One"
        $port.Encoding = [System.Text.Encoding]::UTF8
        $port.ReadTimeout = 50   # Timeout bajo para no bloquear el hilo principal
        $port.WriteTimeout = 500
        $port.DtrEnable = $true  # Reinicia el Arduino al conectar (estándar)
        $port.RtsEnable = $true
        $port.Open()
        
        # Limpiamos basura que pueda haber en el buffer al conectar
        $port.DiscardInBuffer()
        $port.DiscardOutBuffer()
    }
    catch {
        Write-Host "ERROR CRÍTICO: No se puede abrir el puerto $PortName." -ForegroundColor Red
        Write-Host "Causa posible: El puerto está en uso por otro programa o no existe." -ForegroundColor Gray
        exit
    }

    # =============================================================================
    # SECCIÓN 3: MOTOR GRÁFICO (UI)
    # =============================================================================

    # Variables de Estado Global
    $running = $true
    $inputBuffer = ""   # Lo que el usuario está escribiendo
    $rxBuffer = ""      # Datos crudos llegando del Arduino
    $history = @()      # Array de líneas para mostrar en pantalla
    
    # Banderas de optimización de renderizado (Solo dibujamos si algo cambia)
    $updateHistory = $true
    $updateInput = $true
    
    $lastWidth = 0
    $lastHeight = 0
    
    # Ocultamos el cursor del sistema para dibujar el nuestro propio (evita parpadeo)
    [Console]::CursorVisible = $false
    Clear-Host

    function Render-History {
        <# 
        .SYNOPSIS
            Dibuja la parte superior (RX) y la barra de estado.
        .DESCRIPTION
            Usa posicionamiento absoluto del cursor para sobrescribir solo lo necesario.
            Incluye lógica de recorte para evitar que líneas largas rompan el layout.
        #>
        $w = [Console]::WindowWidth
        $h = [Console]::WindowHeight
        $safeWidth = $w - 2
        $historyHeight = $h - 3 # Dejamos 3 líneas abajo: Barra, Input, Margen

        try {
            [Console]::SetCursorPosition(0, 0)
            
            # Obtener las últimas N líneas que caben en pantalla
            $linesToPrint = $history | Select-Object -Last $historyHeight
            
            # Rellenar con vacío si hay pocos datos (limpia la pantalla vieja)
            $linesCount = $linesToPrint.Count
            if ($linesCount -lt $historyHeight) {
                $emptyLines = $historyHeight - $linesCount
                for ($i = 0; $i -lt $emptyLines; $i++) {
                    Write-Host "".PadRight($safeWidth)
                }
            }

            # Imprimir líneas de datos
            foreach ($line in $linesToPrint) {
                $txt = $line.Text
                # Recortar si es muy larga
                if ($txt.Length -gt $safeWidth) { $txt = $txt.Substring(0, $safeWidth) }
                # Imprimir con relleno para limpiar residuos
                Write-Host $txt.PadRight($safeWidth) -ForegroundColor $line.Color
            }
            
            # --- BARRA DE ESTADO (Solicitada con BaudRate) ---
            [Console]::SetCursorPosition(0, $h - 2)
            $info = " [PORT: $PortName @ $BaudRate] | [EOL: $EOL] | [ESC: Salir] "
            
            # Calcular guiones de relleno
            $dashCount = ($safeWidth - $info.Length)
            if ($dashCount -lt 0) { $dashCount = 0 }
            
            Write-Host ("-" * $dashCount + $info) -ForegroundColor DarkGray -NoNewline

        } catch {}
    }

    function Render-Input {
        <#
        .SYNOPSIS
            Dibuja la línea de comandos inferior con cursor simulado.
        #>
        $w = [Console]::WindowWidth
        $h = [Console]::WindowHeight
        $safeWidth = $w - 1

        try {
            [Console]::SetCursorPosition(0, $h - 1)
            Write-Host "> " -ForegroundColor Yellow -NoNewline
            
            # Calcular espacio disponible
            $maxLen = $safeWidth - 3 
            $cleanInput = $inputBuffer
            
            # Scroll horizontal si el texto es muy largo
            if ($cleanInput.Length -gt $maxLen) { 
                $cleanInput = $cleanInput.Substring($cleanInput.Length - $maxLen) 
            }
            
            # Escribir texto
            Write-Host $cleanInput -ForegroundColor White -NoNewline
            
            # DIBUJAR CURSOR FALSO (Estático)
            Write-Host "_" -ForegroundColor Green -NoNewline 
            
            # Limpiar el resto de la línea
            $padding = $safeWidth - (2 + $cleanInput.Length + 1)
            if ($padding -gt 0) {
                Write-Host "".PadRight($padding) -NoNewline
            }
            
        } catch {}
    }

    function Add-Log {
        param($text, $color)
        # Limpieza básica de caracteres no imprimibles
        $clean = $text.Replace("`t", "    ").Trim()
        
        # Permitir marcador especial <VACIO> para feedback visual
        if ($text -match "<VACIO>") { $clean = $text }

        if ($clean.Length -gt 0) {
            $script:history += [PSCustomObject]@{Text=$clean; Color=$color}
            # Buffer circular de 500 líneas para no consumir RAM infinita
            if ($script:history.Count -gt 500) { 
                $script:history = $script:history | Select-Object -Last 500 
            }
            $script:updateHistory = $true
        }
    }

    # =============================================================================
    # SECCIÓN 4: BUCLE PRINCIPAL (EVENT LOOP)
    # =============================================================================
    
    # Renderizado inicial
    Render-History
    Render-Input

    while ($running) {
        
        # 1. DETECCIÓN DE REDIMENSIONAMIENTO DE VENTANA
        if ([Console]::WindowWidth -ne $lastWidth -or [Console]::WindowHeight -ne $lastHeight) {
             $lastWidth = [Console]::WindowWidth
             $lastHeight = [Console]::WindowHeight
             # Ajustar buffer interno para evitar scrollbars
             if ([Console]::BufferWidth -ne $lastWidth) { try { [Console]::BufferWidth = $lastWidth } catch {} }
             Clear-Host
             $updateHistory = $true
             $updateInput = $true
        }

        # 2. LECTURA DEL PUERTO SERIAL
        if ($port.IsOpen -and $port.BytesToRead -gt 0) {
            try {
                $chunk = $port.ReadExisting()
                $rxBuffer += $chunk
                
                # Procesar buffer buscando saltos de línea (\n)
                while ($true) {
                    $idx = $rxBuffer.IndexOf("`n")
                    if ($idx -ge 0) {
                        $rawLine = $rxBuffer.Substring(0, $idx)
                        $rxBuffer = $rxBuffer.Substring($idx + 1)
                        # Eliminar Carriage Return (\r) sobrante y agregar al log
                        Add-Log -text ($rawLine.Replace("`r", "")) -color "Green"
                    } else { 
                        break # Esperar más datos
                    }
                }
            } catch {}
        }

        # 3. LECTURA DEL TECLADO
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true) # $true intercepta la tecla
            
            if ($k.Key -eq "Escape") { 
                $running = $false 
            }
            elseif ($k.Key -eq "Enter") {
                # --- LÓGICA DE ENVÍO CON EOL SELECCIONADO ---
                $suffix = switch ($EOL) {
                    "None" { "" }
                    "LF"   { "`n" }
                    "CR"   { "`r" }
                    "CRLF" { "`r`n" }
                }

                # Enviar al puerto
                $port.Write("$inputBuffer$suffix")
                
                # Eco local en pantalla
                if ($Echo) { 
                    if ($inputBuffer.Length -eq 0) {
                         Add-Log -text "[TX: <VACIO>]" -color "DarkGray"
                    } else {
                         Add-Log -text ("TX: $inputBuffer") -color "Cyan"
                    }
                }
                
                # Limpiar buffer de entrada
                $inputBuffer = ""
                $updateInput = $true
            }
            elseif ($k.Key -eq "Backspace") {
                if ($inputBuffer.Length -gt 0) {
                    $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                    $updateInput = $true
                }
            }
            else {
                # CORRECCIÓN: Aceptar cualquier carácter que NO sea de control.
                # Esto permite todos los símbolos, tildes, signos, etc.
                if (-not [char]::IsControl($k.KeyChar)) {
                    $inputBuffer += $k.KeyChar
                    $updateInput = $true
                }
            }
        }

        # 4. ACTUALIZACIÓN DE PANTALLA
        # Solo repintamos si hubo cambios para ahorrar CPU
        if ($updateHistory) {
            Render-History
            Render-Input # Input debe redibujarse si el historial movió la pantalla
            $updateHistory = $false
            $updateInput = $false 
        }
        elseif ($updateInput) {
            Render-Input
            $updateInput = $false
        }

        # Pequeña pausa para no saturar un núcleo de la CPU (aprox 50 FPS)
        Start-Sleep -Milliseconds 20
    }
} 
catch {
    # Manejo de errores fatales
    [Console]::CursorVisible = $true
    Clear-Host
    Write-Host "--- ERROR IRRECUPERABLE ---" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host ""
}
finally {
    # --- LIMPIEZA AL SALIR ---
    if ($port -and $port.IsOpen) { $port.Close() }
    
    # Borrar visualmente la línea de input
    try {
        $lastLine = [Console]::WindowHeight - 1
        [Console]::SetCursorPosition(0, $lastLine)
        Write-Host "".PadRight([Console]::WindowWidth) -NoNewline 
        [Console]::SetCursorPosition(0, $lastLine)
    } catch {}

    [Console]::CursorVisible = $true
    Write-Host "Conexión Finalizada." -ForegroundColor Green
    Write-Host ""
}
