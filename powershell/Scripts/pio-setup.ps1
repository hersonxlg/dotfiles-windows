<#
.SYNOPSIS
    PlatformIO Configurator TUI - V8.0 (The Fully Documented Edition)
    Herramienta gráfica de terminal (TUI) interactiva para inicializar y gestionar 
    proyectos de PlatformIO directamente desde la consola.

.DESCRIPTION
    Este script proporciona una interfaz gráfica basada en texto (TUI) completamente 
    interactiva y compatible con versiones antiguas (Windows PowerShell 5.1). Su objetivo 
    principal es facilitar la configuración de proyectos de microcontroladores sin tener 
    que editar manualmente y a ciegas el archivo 'platformio.ini'.

    ¿Qué flujo de trabajo cubre este script?
    1. Selección Automática de Puertos: Detecta puertos COM conectados en tiempo real.
    2. Selección de Placas (Boards): Ofrece un historial de placas usadas recientemente 
       y permite buscar en la base de datos completa de PlatformIO vía CLI.
    3. Configuración de Entorno: Permite elegir el framework (Arduino, ESP-IDF) y el Baud Rate.
    4. Ajustes Avanzados (S3): Si se detecta un microcontrolador ESP32-S3, habilita un 
       menú especial para configurar de forma gráfica la memoria Flash y la PSRAM.
    5. Gestor de Librerías Integrado: Se conecta a la API REST de PlatformIO para buscar, 
       inspeccionar (ver repositorios, keywords, descripciones), elegir versiones y 
       gestionar (instalar/eliminar) librerías en tu proyecto.

    ¿Cuál es el resultado final?
    Al finalizar (opción [ Continuar y Guardar ] o tecla 's'), el script realiza un 
    "reemplazo quirúrgico" en tu archivo 'platformio.ini'. Localiza el entorno ([env:...]) 
    seleccionado y actualiza SÓLO las propiedades modificadas en la TUI, preservando 
    cualquier comentario o configuración extra que hayas añadido a mano.
    
    Además, si la carpeta 'src' está vacía, el script genera una plantilla "Hola Mundo" 
    (main.cpp o main.c según el framework elegido) con la estructura base de PlatformIO.

    Para compilar, subir y monitorear este código de prueba, simplemente ejecuta:
    pio run -t upload -t monitor

.NOTES
    Autor: Usuario / IA
    Versión: 8.0
    Requisitos: PlatformIO Core (CLI) instalado y accesible desde la variable de entorno PATH.
#>

$ErrorActionPreference = "Stop"

# =============================================================================
# 1. ESTADO GLOBAL Y CONFIGURACIÓN VISUAL (TEMA)
# =============================================================================

# Determinar la carpeta de usuario para guardar el historial de placas temporales
$homePath = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }

# Contexto global que funciona como la "memoria RAM" de la aplicación.
# Almacena el estado en el que nos encontramos, las librerías cacheadas y la config actual.
$Global:Context = @{
    Running      = $true
    CurrentState = "State-Port" 
    LibVersionReturnState = "State-LibMain" # Recuerda de qué pantalla vinimos (Buscador o Menú)
    LibMainCursor = 0                       # Recuerda dónde dejamos el cursor en la lista de dependencias
    SearchCache  = @{ Active = $false; Results = @(); Cursor = 0; Scroll = 0; Query = "" } # Caché del buscador
    IniPath      = Join-Path (Get-Location) "platformio.ini"
    HistoryPath  = Join-Path $homePath ".pio_boards_history.tmp"
    Config = @{ 
        Port      = $null
        Board     = $null 
        Platform  = $null
        Framework = "arduino" 
        Baud      = 115200 
        FlashSize = "4MB"
        PSRAMType = "None"
        Libraries = @() # Lista de dependencias. Formato: @{ Name="x"; Version="y" }
    }
    TempLib = @{ Name = ""; CurrentVersion = "" } # Librería temporal en transición (ej. al buscar)
    Cache = @{ Boards = $null }                   # Caché de todas las placas de PlatformIO
}

# Paleta de colores para renderizar la TUI de manera consistente
$Theme = @{
    Title      = "Magenta"; Label = "Cyan"; Text = "White"
    Selected   = "Black"; SelBack = "Cyan"; Faint = "DarkGray"
    StatusBack = "DarkGray"; StatusText = "White"
    SearchBack = "Black"; SearchText = "Green"
    Loading    = "Yellow"; Detected = "Green"; Error = "Red"
    Highlight  = "Yellow"; Action = "Green"
}

# =============================================================================
# 2. PERSISTENCIA Y UTILIDADES DE INTERFAZ (UI)
# =============================================================================

<#
.SYNOPSIS
    Añade o actualiza una dependencia de librería en la memoria RAM del TUI.
.DESCRIPTION
    Toma una cadena cruda (ej: "bblanchon/ArduinoJson @ ^7.0"), extrae la base del nombre 
    y la versión. Si la librería ya existe en el arreglo, actualiza la versión y limpia 
    los duplicados. Si no existe, la añade.
#>
function Add-LibDep {
    param($Raw)
    
    # Separamos el nombre de la versión usando '@'
    $parts = $Raw -split "@", 2
    $name = $parts[0].Trim()
    $ver = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "latest" }
    
    if ($name) {
        # Extraemos el "Dueño" y el "Nombre Base". Ejemplo de "bblanchon/ArduinoJson"
        $baseName = ($name -split "/")[-1].ToLower().Trim()
        $ownerName = if ($name -match "/") { ($name -split "/")[0].ToLower().Trim() } else { "" }
        $found = $false
        
        $newLibs = @()
        foreach ($l in $Global:Context.Config.Libraries) {
            $existingBase = ($l.Name -split "/")[-1].ToLower().Trim()
            $existingOwner = if ($l.Name -match "/") { ($l.Name -split "/")[0].ToLower().Trim() } else { "" }
            
            # Condición de colapso: Mismo nombre base, y los dueños coinciden (o alguno está vacío)
            if ($existingBase -eq $baseName -and ($existingOwner -eq $ownerName -or $existingOwner -eq "" -or $ownerName -eq "")) {
                if (-not $found) {
                    # Actualizamos a la versión más reciente solicitada y adoptamos el nombre completo
                    $updatedName = if ($name -match "/") { $name } else { $l.Name }
                    $newLibs += @{ Name = $updatedName; Version = $ver }
                    $found = $true
                }
                # Los subsiguientes duplicados se ignoran (limpieza automática)
            } else {
                $newLibs += $l
            }
        }
        
        # Si nunca se encontró en la lista, es una librería completamente nueva
        if (-not $found) {
            $newLibs += @{ Name = $name; Version = $ver }
        }
        
        # Guardamos el arreglo limpio en la memoria global
        $Global:Context.Config.Libraries = $newLibs
    }
}

<#
.SYNOPSIS
    Lee el archivo platformio.ini (si existe) y precarga la configuración.
.DESCRIPTION
    Analiza línea por línea el archivo. Solo carga los datos del PRIMER entorno ([env:...])
    que encuentra, ignorando el resto para no generar conflictos fantasma. Extrae los
    baudios, placas, configuraciones de memoria de la serie ESP32, y la lista de lib_deps.
#>
function Load-Config {
    if (Test-Path $Global:Context.IniPath) {
        $content = (Get-Content $Global:Context.IniPath)
        $inLibDeps = $false
        $firstEnvFound = $false
        $Global:Context.Config.Libraries = @()

        foreach ($line in $content) {
            $clean = $line.Trim()
            
            # Ignorar comentarios o líneas en blanco
            if ($clean.StartsWith(";") -or $clean -eq "") { continue }
            
            # Detectar encabezados de entorno (ej: [env:esp32])
            if ($clean -match "^\[.*\]") { 
                if ($clean -match "^\[env") {
                    # Freno de seguridad: Solo leemos el primer entorno del archivo
                    if ($firstEnvFound) { break }
                    $firstEnvFound = $true
                }
                $inLibDeps = $false # Reiniciamos el bloque de dependencias
                continue 
            }
            
            # Parsear pares clave-valor (ej: framework = arduino)
            if ($clean -match "^([a-zA-Z0-9_\-\.]+)\s*=(.*)") {
                $key = $matches[1].ToLower().Trim()
                $val = $matches[2].Trim()

                # Si es la clave lib_deps, activamos la bandera para leer las siguientes líneas
                if ($key -eq "lib_deps") {
                    $inLibDeps = $true
                    # Las dependencias en la misma línea separadas por comas también son procesadas
                    if ($val) { foreach($item in $val -split ",") { Add-LibDep -Raw $item } }
                    continue
                } else { 
                    $inLibDeps = $false 
                }
                
                # Asignar variables al contexto global si coinciden con los ajustes esperados
                if ($key -eq "platform")  { $Global:Context.Config.Platform = $val }
                if ($key -eq "board")     { $Global:Context.Config.Board = $val }
                if ($key -eq "framework") { $Global:Context.Config.Framework = $val }
                if ($key -eq "monitor_speed") { $Global:Context.Config.Baud = [int]$val }
                if ($key -eq "upload_port") { $Global:Context.Config.Port = $val }
                
                # Capturar ajustes avanzados de memoria si es un ESP32
                if ($key -eq "board_upload.flash_size") { $Global:Context.Config.FlashSize = $val }
                if ($key -eq "board_build.arduino.memory_type" -and $val -eq "qio_qspi") { $Global:Context.Config.PSRAMType = "2MB (QSPI)" }
                if ($key -eq "board_build.arduino.memory_type" -and $val -eq "qio_opi") { $Global:Context.Config.PSRAMType = "8MB (OPI)" } 
            } else {
                # Si estamos dentro del bloque lib_deps y no es clave=valor, es una librería instalada
                if ($inLibDeps) { Add-LibDep -Raw $clean }
            }
        }
    }
}

<#
.SYNOPSIS
    Guarda una placa recién seleccionada en el historial MRU (Most Recently Used).
#>
function Save-BoardHistory {
    param($BoardItem)
    $hist = @()
    if (Test-Path $Global:Context.HistoryPath) {
        try { 
            $hist = Get-Content $Global:Context.HistoryPath | ConvertFrom-Json
            if ($hist -isnot [array]) { $hist = @($hist) } 
        } catch {}
    }
    # Filtramos la placa actual para ponerla en la cima sin duplicarla
    $hist = $hist | Where-Object { $_.Id -ne $BoardItem.Id }
    $hist = @(@{ Id = $BoardItem.Id; Name = $BoardItem.Name; Platform = $BoardItem.Platform }) + $hist
    
    # Mantenemos solo un máximo de 20 placas en el historial para no saturar
    if ($hist.Count -gt 20) { $hist = $hist[0..19] }
    $hist | ConvertTo-Json -Compress | Out-File $Global:Context.HistoryPath -Encoding UTF8
}

<#
.SYNOPSIS
    Configura la ventana de la terminal, ocultando el cursor por defecto.
#>
function Initialize-UI {
    $host.UI.RawUI.WindowTitle = "PlatformIO Configurator TUI v8.0"
    try { [Console]::CursorVisible = $false } catch {}
    Clear-Host 
}

<#
.SYNOPSIS
    Dibuja una línea completa en la terminal con color, rellenando con espacios hasta el borde.
    Esto da la sensación de un menú sólido.
#>
function Out-BufferLine {
    param([string]$Text, [string]$Fore = "White", [string]$Back = "Black", [switch]$NewLine)
    
    $width = $host.UI.RawUI.WindowSize.Width
    if ($width -le 1) { $width = 80 } # Fallback si falla la lectura del ancho
    
    # Recortar si excede el ancho para que no se parta en dos líneas
    if ($Text.Length -ge $width) { $Text = $Text.Substring(0, $width - 1) }
    
    # Rellenar con espacios vacíos a la derecha para pintar el fondo correctamente
    $pad = " " * ($width - $Text.Length)
    
    [Console]::ForegroundColor = [Enum]::Parse([ConsoleColor], $Fore)
    [Console]::BackgroundColor = [Enum]::Parse([ConsoleColor], $Back)
    [Console]::Write("$Text$pad")
    
    if ($NewLine) { [Console]::Write([Environment]::NewLine) }
}

<#
.SYNOPSIS
    Separa un texto largo en múltiples líneas de un ancho fijo (Word Wrap).
#>
function Format-WordWrap {
    param([string]$Text, [int]$Width)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @(" (Sin descripción)") }
    
    $words = $Text -split '\s+'
    $lines = @()
    $currentLine = ""
    
    foreach ($word in $words) {
        if (($currentLine.Length + $word.Length + 1) -le $Width) {
            if ($currentLine) { $currentLine += " $word" } else { $currentLine = $word }
        } else {
            if ($currentLine) { $lines += $currentLine }
            $currentLine = $word
        }
    }
    if ($currentLine) { $lines += $currentLine }
    return $lines
}

# =============================================================================
# MÓDULO INTERACTIVO DE DETALLES DE LIBRERÍA
# =============================================================================

<#
.SYNOPSIS
    Pantalla interactiva que consulta y despliega la información técnica de una librería
    (descripción, repo, licencias) conectándose en tiempo real a la API de PlatformIO.
.DESCRIPTION
    Permite navegar las líneas de la información. Proporciona atajos rápidos (c) para 
    copiar campos al portapapeles y (o/Enter) para abrir el navegador web en enlaces detectados.
#>
function Show-LibDetails {
    param($LibraryName, $FallbackItem)
    
    $winH = $Host.UI.RawUI.WindowSize.Height
    $winW = $Host.UI.RawUI.WindowSize.Width - 6
    
    # Feedback visual mientras esperamos a la API
    [Console]::SetCursorPosition(0, $winH - 2)
    Out-BufferLine " Solicitando datos profundos a PlatformIO... " -Fore $Theme.Loading -Back "Black"
    
    $detailJson = $null
    try {
        # Para consultar el endpoint específico, necesitamos dividir el Dueño del Nombre
        $parts = $LibraryName -split "/", 2
        if ($parts.Count -eq 2) {
            $safeOwner = [uri]::EscapeDataString($parts[0])
            $safeName = [uri]::EscapeDataString($parts[1])
            $detailUri = "https://api.registry.platformio.org/v3/packages/$safeOwner/library/$safeName"
        } else {
            $safeName = [uri]::EscapeDataString($LibraryName)
            $detailUri = "https://api.registry.platformio.org/v3/packages/library/$safeName"
        }
        $detailJson = Invoke-RestMethod -Uri $detailUri
    } catch {
        # Si no hay internet, usamos la información básica del caché (Fallback)
        $detailJson = $FallbackItem
    }

    # Extracción de campos gestionando posibles valores nulos
    $name = if ($detailJson.owner -and $detailJson.owner.username) { "$($detailJson.owner.username)/$($detailJson.name)" } elseif ($detailJson.name) { $detailJson.name } else { $LibraryName }
    $ver  = if ($detailJson.version -and $detailJson.version.name) { $detailJson.version.name } elseif ($detailJson.version -is [string]) { $detailJson.version } else { "latest" }
    $lic  = if ($detailJson.license) { $detailJson.license } else { "N/A" }
    $hp   = if ($detailJson.homepage) { $detailJson.homepage } else { "N/A" }
    
    # Resolviendo el repositorio: Algunas API lo envían como cadena, otras como objeto con clave url
    $repo = if ($detailJson.repository_url) { $detailJson.repository_url } elseif ($detailJson.repository -is [string]) { $detailJson.repository } elseif ($detailJson.repository -and $detailJson.repository.url) { $detailJson.repository.url } else { "N/A" }
    $kws  = if ($detailJson.keywords) { $detailJson.keywords -join ", " } elseif ($FallbackItem -and $FallbackItem.keywords) { $FallbackItem.keywords -join ", " } else { "N/A" }
    $descText = if ($detailJson.description) { $detailJson.description } elseif ($FallbackItem -and $FallbackItem.description) { $FallbackItem.description } else { "Sin descripción disponible." }

    # Construir arreglo interactivo para la navegación con teclado
    $navItems = @()
    
    # Bloque de datos clave
    $fields = @(
        @{ L = "LIBRERIA";   V = $name;  IsLink = $false }
        @{ L = "VERSION";    V = $ver;   IsLink = $false }
        @{ L = "LICENCIA";   V = $lic;   IsLink = $false }
        @{ L = "HOMEPAGE";   V = $hp;    IsLink = ($hp -match "^http") }
        @{ L = "REPO";       V = $repo;  IsLink = ($repo -match "^http") }
        @{ L = "KEYWORDS";   V = $kws;   IsLink = $false }
    )

    foreach ($f in $fields) {
        $navItems += @{ DisplayText = " [ $($f.L.PadRight(10)) ]: $($f.V)"; Value = $f.V; IsLink = $f.IsLink }
    }
    
    # Separador visual
    $navItems += @{ DisplayText = ""; Value = ""; IsLink = $false }
    $navItems += @{ DisplayText = " [ DESCRIPCION ]:"; Value = ""; IsLink = $false }
    
    # Procesar líneas de la descripción en el Wrap y detectar si hay links escondidos en el texto
    foreach ($line in (Format-WordWrap $descText $winW)) {
        $isLink = ($line -match "^http")
        $navItems += @{ DisplayText = "   $line"; Value = $line.Trim(); IsLink = $isLink }
    }

    $cursor = 0; $scroll = 0; $done = $false; $msg = ""; $mTimer = 0
    
    # --- Bucle principal de la pantalla de detalles ---
    while (-not $done) {
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Highlight -NewLine
        Out-BufferLine "   DETALLES DE LIBRERIA                   " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Highlight -NewLine

        $listSpace = $winH - 5
        if ($cursor -ge $scroll + $listSpace) { $scroll = $cursor - $listSpace + 1 }
        if ($cursor -lt $scroll) { $scroll = $cursor }

        # Renderizar la lista
        for ($i=0; $i -lt $listSpace; $i++) {
            $idx = $scroll + $i
            if ($idx -lt $navItems.Count) {
                $it = $navItems[$idx]
                
                $p = if ($idx -eq $cursor) { " > " } else { "   " }
                $bg = if ($idx -eq $cursor) { $Theme.SelBack } else { "Black" }
                
                if ($idx -eq $cursor) {
                    $fg = $Theme.Selected
                } elseif ($it.IsLink) {
                    $fg = "Cyan" # Resaltamos los enlaces
                } else {
                    $fg = $Theme.Text
                }
                
                Out-BufferLine "$p$($it.DisplayText)" -Fore $fg -Back $bg -NewLine
            } else { Out-BufferLine "" -NewLine }
        }

        # Barra de estado temporal (desaparece después de unos fotogramas)
        [Console]::SetCursorPosition(0, $winH-2)
        if ($mTimer -gt 0) { 
            Out-BufferLine " $msg" -Fore $Theme.Action -Back $Theme.StatusBack
            $mTimer-- 
        } else { 
            Out-BufferLine "" 
        }

        # Leyenda inferior dinámica: Solo muestra opciones compatibles con el elemento actual
        [Console]::SetCursorPosition(0, $winH-1)
        $p = " [h/Esc] Volver  [j/k] Navegar"
        if ($navItems[$cursor].Value) { $p += "  [c] Copiar" }
        if ($navItems[$cursor].IsLink) { $p += "  [Enter/o] Abrir en web" }
        $p += "  [q] Salir App"
        Out-BufferLine $p -Fore $Theme.SearchText -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.KeyChar -eq 'q') { 
                # Salida global del programa
                $Global:Context.CurrentState = "ExitApp"
                $done = $true 
            }
            elseif ($k.Key -eq [ConsoleKey]::Escape -or $k.KeyChar -eq 'h') { $done = $true }
            elseif ($k.Key -eq [ConsoleKey]::UpArrow -or $k.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($k.Key -eq [ConsoleKey]::DownArrow -or $k.KeyChar -eq 'j') { if ($cursor -lt $navItems.Count-1) { $cursor++ } }
            elseif ($k.KeyChar -eq 'c') {
                $val = $navItems[$cursor].Value
                if ($val -and $val -ne "N/A") { 
                    Set-Clipboard $val
                    $msg = "[ COPIADO ] $val"
                    if ($msg.Length -gt 60) { $msg = $msg.Substring(0, 57) + "..." }
                    $mTimer = 25 # Fotogramas que dura el mensaje en pantalla
                }
            }
            elseif ($k.Key -eq [ConsoleKey]::Enter -or $k.KeyChar -eq 'o') {
                if ($navItems[$cursor].IsLink) {
                    # Limpiamos prefijos git+ que corrompen el URL
                    $url = $navItems[$cursor].Value -replace "^git\+", ""
                    try { 
                        Start-Process $url # Ejecuta el navegador web predeterminado del SO
                        $msg = "[ ABRIENDO EN NAVEGADOR ]"
                        $mTimer = 25 
                    } catch {
                        $msg = "[ ERROR ] No se pudo abrir el enlace."
                        $mTimer = 25
                    }
                }
            }
        }
        Start-Sleep -Milliseconds 40
    }
}

# =============================================================================
# 3. ESTADOS DEL TUI (VISTAS PRINCIPALES DEL PROGRAMA)
# =============================================================================

<#
.SYNOPSIS
    Pantalla de selección de puerto COM.
.DESCRIPTION
    Detecta en tiempo real (Polling) los puertos COM del sistema.
    Si conectas o desconectas un dispositivo, la UI se actualiza inmediatamente
    y alerta en verde el dispositivo recién conectado para fácil selección.
#>
function Invoke-StatePort {
    $cursor = 0; $lastKnownPorts = @(); $detectedPortName = "" 
    $currentPorts = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object -Unique)
    $lastKnownPorts = $currentPorts; $done = $false
    
    # Auto-Selecciona el puerto guardado en config si es que aún está conectado
    if ($Global:Context.Config.Port) { 
        $idx = $currentPorts.IndexOf($Global:Context.Config.Port)
        if($idx -ge 0){ $cursor = $idx } 
    }

    while (-not $done) {
        $currentPorts = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object -Unique)
        
        # Lógica de detección de cambios (Hot-plug USB)
        $diff = Compare-Object -ReferenceObject $lastKnownPorts -DifferenceObject $currentPorts
        if ($diff) {
            $added = $diff | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject -First 1
            if ($added) {
                # Mueve automáticamente el cursor al dispositivo recién conectado
                $detectedPortName = $added; $newIdx = $currentPorts.IndexOf($added)
                if ($newIdx -ge 0) { $cursor = $newIdx }
            } else { 
                # Si se desconectó algo, evitamos que el cursor se quede fuera de límites
                if ($cursor -ge $currentPorts.Count) { $cursor = [Math]::Max(0, $currentPorts.Count - 1) } 
            }
            $lastKnownPorts = $currentPorts
        }

        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   PIO: SELECCION DE PUERTO COM           " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine

        $winH = $Host.UI.RawUI.WindowSize.Height; $listSpace = $winH - 5 
        
        if ($currentPorts.Count -eq 0) {
            Out-BufferLine "   [ ESPERANDO CONEXION USB... ]" -Fore $Theme.Error -NewLine
            for($k=0; $k -lt ($listSpace - 1); $k++){ Out-BufferLine "" -NewLine }
        } else {
            for ($i = 0; $i -lt $listSpace; $i++) {
                if ($i -lt $currentPorts.Count) {
                    $p = $currentPorts[$i]
                    $prefix = "   "; $fg = $Theme.Text; $bg = "Black"; $suffix = ""
                    
                    if ($p -eq $Global:Context.Config.Port) { $suffix += " (Guardado)"; $fg = $Theme.Faint }
                    if ($p -eq $detectedPortName) { 
                        $suffix += " [ ! NUEVO ! ]"
                        if ($i -ne $cursor) { $fg = $Theme.Detected } 
                    }
                    if ($i -eq $cursor) { $prefix = " > "; $fg = $Theme.Selected; $bg = $Theme.SelBack }
                    Out-BufferLine "$prefix$p$suffix" -Fore $fg -Back $bg -NewLine
                } else { Out-BufferLine "" -NewLine }
            }
        }
        
        [Console]::SetCursorPosition(0, $winH - 2)
        if ($detectedPortName -and $currentPorts -contains $detectedPortName) {
             Out-BufferLine " ALERTA: Nuevo dispositivo detectado en $detectedPortName" -Fore $Theme.Detected -Back $Theme.StatusBack
        } else { Out-BufferLine " ESTADO: Conecta/Desconecta tu placa para auto-detectar." -Fore $Theme.StatusText -Back $Theme.StatusBack }
        
        [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " COMANDOS: [q/Esc] Salir  [Enter/l] Sig.  [j/k] Navegar" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done = $true }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l' -or $K.Key -eq [ConsoleKey]::RightArrow) {
                if ($currentPorts.Count -gt 0) { 
                    $Global:Context.Config.Port = $currentPorts[$cursor]
                    $Global:Context.CurrentState = "State-Board"; $done = $true
                }
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $currentPorts.Count - 1) { $cursor++ } }
        }
        Start-Sleep -Milliseconds 40
    }
}

<#
.SYNOPSIS
    Pantalla de selección de la Placa Microcontroladora (Board).
.DESCRIPTION
    Muestra las últimas 20 placas usadas cargándolas desde disco. Incluye una opción 
    especial "___LOAD_ALL___" para hacer una llamada al CLI de PlatformIO, descargar 
    el listado JSON completo de placas soportadas en tu máquina y habilitar una 
    búsqueda filtrada (ej. esp32, arduino, nucleo).
#>
function Invoke-StateBoard {
    $showingFullList = $false
    $allData = @()

    # Carga de placas históricas locales
    if (Test-Path $Global:Context.HistoryPath) {
        try { 
            $hist = Get-Content $Global:Context.HistoryPath | ConvertFrom-Json
            if ($hist -isnot [array]) { $hist = @($hist) }
            $allData = $hist
        } catch {}
    }
    
    $loadAllId = "___LOAD_ALL___"
    $allData += @{ Id = $loadAllId; Name = ">>> DESCARGAR TODAS LAS PLACAS DESDE PIO <<<"; Platform = "SYSTEM" }

    $searchQuery = ""; $filtered = $allData
    $cursor = 0; $scroll = 0; $isSearching = $false; $done = $false
    
    if ($Global:Context.Config.Board) {
        for ($i=0; $i -lt $filtered.Count; $i++) { if ($filtered[$i].Id -eq $Global:Context.Config.Board) { $cursor = $i; break } }
    }

    while (-not $done) {
        $winH = $Host.UI.RawUI.WindowSize.Height; $listSpace = $winH - 5
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        if ($showingFullList) { Out-BufferLine "   PIO: PLACAS (LISTA COMPLETA)           " -Fore $Theme.Title -NewLine }
        else { Out-BufferLine "   PIO: PLACAS (RECIENTES / HISTORIAL)    " -Fore $Theme.Title -NewLine }
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        
        # Algoritmo de scrolling para mantener la selección siempre visible
        if ($cursor -ge $scroll + $listSpace) { $scroll = $cursor - $listSpace + 1 }
        if ($cursor -lt $scroll) { $scroll = $cursor }
        
        for ($i = 0; $i -lt $listSpace; $i++) {
            $idx = $scroll + $i
            if ($idx -lt $filtered.Count) {
                $item = $filtered[$idx]
                
                $p = if ($idx -eq $cursor) { " > " } else { "   " }
                $bg = if ($idx -eq $cursor) { $Theme.SelBack } else { "Black" }
                
                if ($item.Id -eq $loadAllId) {
                    $fg = if ($idx -eq $cursor) { $Theme.Selected } else { $Theme.Highlight }
                    Out-BufferLine "$p$($item.Name)" -Fore $fg -Back $bg -NewLine
                } else {
                    $fg = if ($idx -eq $cursor) { $Theme.Selected } else { $Theme.Text }
                    $mark = if ($item.Id -eq $Global:Context.Config.Board) { "[*] " } else { "    " }
                    Out-BufferLine "$p$mark$($item.Name) ($($item.Id))" -Fore $fg -Back $bg -NewLine
                }
            } else { Out-BufferLine "" -NewLine } 
        }

        [Console]::SetCursorPosition(0, $winH - 2)
        if ($showingFullList) { Out-BufferLine " Placas filtradas: $($filtered.Count)" -Fore $Theme.StatusText -Back $Theme.StatusBack }
        else { Out-BufferLine " Modo Historial: Cargado de $($Global:Context.HistoryPath)" -Fore $Theme.StatusText -Back $Theme.StatusBack }

        [Console]::SetCursorPosition(0, $winH - 1)
        $prompt = if ($isSearching) { " BUSCAR: $searchQuery`_" } else { " [/] Buscar  [h] Atras  [Enter] Sel.  [q] Salir" }
        Out-BufferLine $prompt -Fore $Theme.SearchText -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            
            # Modo de tipeo en vivo para filtrar las placas
            if ($isSearching) {
                if ($K.Key -eq [ConsoleKey]::Enter -or $K.Key -eq [ConsoleKey]::Escape) { $isSearching = $false }
                elseif ($K.Key -eq [ConsoleKey]::Backspace) { 
                    if ($searchQuery.Length -gt 0) { $searchQuery = $searchQuery.Substring(0, $searchQuery.Length-1) }
                } else { $searchQuery += $K.KeyChar }
                
                # Aplicamos el filtro al array
                $filtered = $allData | Where-Object { $_.Name -match $searchQuery -or $_.Id -match $searchQuery }
                $cursor = 0
            } else {
                if ($K.KeyChar -eq '/') { $isSearching = $true }
                elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
                elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $filtered.Count - 1) { $cursor++ } }
                elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { $Global:Context.CurrentState = "State-Port"; $done = $true }
                elseif ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done = $true }
                elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') {
                    if ($filtered.Count -eq 0) { continue }
                    
                    if ($filtered[$cursor].Id -eq $loadAllId) {
                        Clear-Host; [Console]::SetCursorPosition(0,0)
                        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
                        Out-BufferLine " CARGANDO TODAS LAS PLACAS DESDE PIO..." -Fore $Theme.Highlight -NewLine
                        Out-BufferLine " (Por favor, espera unos segundos)      " -Fore $Theme.Faint -NewLine
                        try {
                            # Llamada al CLI local de platformio para obtener metadatos de las placas instaladas
                            if ($null -eq $Global:Context.Cache.Boards) {
                                $json = pio boards --json-output | ConvertFrom-Json
                                $Global:Context.Cache.Boards = $json | ForEach-Object { @{ Id = $_.id; Name = $_.name; Platform = $_.platform } }
                            }
                            $allData = $Global:Context.Cache.Boards
                        } catch { 
                            $allData = @(@{ Id="uno"; Name="Arduino Uno (Fallback)"; Platform="atmelavr" }) 
                        }
                        $showingFullList = $true; $filtered = $allData; $cursor = 0; $scroll = 0; $searchQuery = ""; continue
                    }
                    
                    $Global:Context.Config.Board = $filtered[$cursor].Id
                    $Global:Context.Config.Platform = $filtered[$cursor].Platform
                    Save-BoardHistory $filtered[$cursor]
                    $Global:Context.CurrentState = "State-Framework"; $done = $true
                }
            }
        }
        Start-Sleep -Milliseconds 30
    }
}

<#
.SYNOPSIS
    Selección del SDK o Framework de desarrollo (ej. C++ con Arduino, o ESP-IDF).
#>
function Invoke-StateFramework {
    $fws = @("arduino", "espidf", "mbed", "zephyr", "libopencm3")
    $cursor = [Array]::IndexOf($fws, $Global:Context.Config.Framework)
    if ($cursor -lt 0) { $cursor = 0 }
    $done = $false
    while (-not $done) {
        $winH = $Host.UI.RawUI.WindowSize.Height
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   PIO: FRAMEWORK DE DESARROLLO           " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        for ($i=0; $i -lt $fws.Count; $i++) {
            $p = if ($i -eq $cursor) { " > " } else { "   " }
            $bg = if ($i -eq $cursor) { $Theme.SelBack } else { "Black" }
            Out-BufferLine "$p $($fws[$i])" -Back $bg -NewLine
        }
        for ($k=0; $k -lt ($winH - 5 - $fws.Count); $k++) { Out-BufferLine "" -NewLine }
        [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " [h/Izq] Atras  [j/k] Nav  [Enter/l] Seleccionar  [q] Salir" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done=$true }
            elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { $Global:Context.CurrentState = "State-Board"; $done=$true }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $fws.Count-1) { $cursor++ } }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') { 
                $Global:Context.Config.Framework = $fws[$cursor]; $Global:Context.CurrentState = "State-Baud"; $done = $true 
            }
        }
        Start-Sleep -Milliseconds 40
    }
}

<#
.SYNOPSIS
    Define la velocidad de comunicación del puerto serial (monitor_speed).
#>
function Invoke-StateBaud {
    $rates = @(9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600)
    $cursor = [Array]::IndexOf($rates, $Global:Context.Config.Baud)
    if ($cursor -lt 0) { $cursor = 4 } # Por defecto: 115200
    
    $done = $false
    while (-not $done) {
        $winH = $Host.UI.RawUI.WindowSize.Height
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   PIO: MONITOR_SPEED                     " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        for ($i=0; $i -lt $rates.Count; $i++) {
            $p = if ($i -eq $cursor) { " > " } else { "   " }
            $bg = if ($i -eq $cursor) { $Theme.SelBack } else { "Black" }
            Out-BufferLine "$p $($rates[$i])" -Back $bg -NewLine
        }
        for ($k=0; $k -lt ($winH - 5 - $rates.Count); $k++) { Out-BufferLine "" -NewLine }
        [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " [h] Atras  [j/k] Nav  [Enter/l] Confirmar  [q] Salir" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done=$true }
            elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { $Global:Context.CurrentState = "State-Framework"; $done=$true }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $rates.Count-1) { $cursor++ } }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') { 
                $Global:Context.Config.Baud = $rates[$cursor]
                
                # ENRUTAMIENTO CONDICIONAL: Si es una placa S3, abrimos el menú avanzado de memorias
                if ($Global:Context.Config.Board -match "s3") { $Global:Context.CurrentState = "State-Memory" } 
                else { $Global:Context.CurrentState = "State-LibMain" }
                
                $done = $true 
            }
        }
        Start-Sleep -Milliseconds 40
    }
}

<#
.SYNOPSIS
    Menú de configuración especializada para arquitecturas ESP32-S3.
.DESCRIPTION
    Los módulos ESP32-S3 requieren definir métricas exactas en 'platformio.ini' para compilar 
    correctamente, principalmente su partición de Flash y el tipo de PSRAM (QSPI u OPI).
#>
function Invoke-StateMemory {
    $flashOptions = @("4MB", "8MB", "16MB", "32MB"); $psramOptions = @("None", "2MB (QSPI)", "8MB (OPI)", "16MB (OPI)")
    
    # Navegación 2D: X es la columna (Flash/PSRAM), Y es el elemento elegido en la lista
    $cursorX = 0; $cursorY = [Array]::IndexOf($flashOptions, $Global:Context.Config.FlashSize)
    if ($cursorY -lt 0) { $cursorY = 0 }
    
    $done = $false
    while (-not $done) {
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   CONFIGURACION AVANZADA DE MEMORIA (S3) " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine " Placa detectada: $($Global:Context.Config.Board)" -Fore $Theme.Highlight -NewLine
        Out-BufferLine "" -NewLine

        Out-BufferLine " [ TAMAÑO FLASH ]" -Fore $Theme.Label -NewLine
        for ($i=0; $i -lt $flashOptions.Count; $i++) {
            $sel = ($cursorX -eq 0 -and $cursorY -eq $i)
            $mark = if ($Global:Context.Config.FlashSize -eq $flashOptions[$i]) { "[*]" } else { "[ ]" }
            $p = if ($sel) { ">" } else { " " }
            $bg = if ($sel) { $Theme.SelBack } else { "Black" }
            $fg = if ($sel) { $Theme.Selected } else { $Theme.Text }
            Out-BufferLine " $p $mark $($flashOptions[$i])" -Back $bg -Fore $fg -NewLine
        }
        
        Out-BufferLine "" -NewLine
        Out-BufferLine " [ TIPO PSRAM ]" -Fore $Theme.Label -NewLine
        for ($i=0; $i -lt $psramOptions.Count; $i++) {
            $sel = ($cursorX -eq 1 -and $cursorY -eq $i)
            $mark = if ($Global:Context.Config.PSRAMType -eq $psramOptions[$i]) { "[*]" } else { "[ ]" }
            $p = if ($sel) { ">" } else { " " }
            $bg = if ($sel) { $Theme.SelBack } else { "Black" }
            $fg = if ($sel) { $Theme.Selected } else { $Theme.Text }
            Out-BufferLine " $p $mark $($psramOptions[$i])" -Back $bg -Fore $fg -NewLine
        }

        $winH = $Host.UI.RawUI.WindowSize.Height; [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " [h/l/TAB] Columna/Sig  [j/k] Seleccionar  [Enter] Siguiente  [q] Salir" -Fore $Theme.Faint -Back "Black"

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            
            # Lógica de navegación transversal en 2 columnas
            if ($K.KeyChar -eq 'l') {
                if ($cursorX -eq 0) { 
                    $cursorX = 1; $cursorY = [Math]::Max(0, [Array]::IndexOf($psramOptions, $Global:Context.Config.PSRAMType)) 
                } else { 
                    $Global:Context.CurrentState = "State-LibMain"; $done = $true 
                }
            }
            elseif ($K.Key -eq [ConsoleKey]::Tab -or $K.Key -eq [ConsoleKey]::RightArrow) { 
                if ($cursorX -eq 0) { $cursorX = 1; $cursorY = [Math]::Max(0, [Array]::IndexOf($psramOptions, $Global:Context.Config.PSRAMType)) }
            }
            elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { 
                if ($cursorX -eq 1) { $cursorX = 0; $cursorY = [Math]::Max(0, [Array]::IndexOf($flashOptions, $Global:Context.Config.FlashSize)) } 
                else { $Global:Context.CurrentState = "State-Baud"; $done = $true }
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { 
                if ($cursorY -gt 0) { 
                    $cursorY--
                    if ($cursorX -eq 0) { $Global:Context.Config.FlashSize = $flashOptions[$cursorY] } else { $Global:Context.Config.PSRAMType = $psramOptions[$cursorY] } 
                } 
            }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { 
                $limit = if ($cursorX -eq 0) { $flashOptions.Count } else { $psramOptions.Count }
                if ($cursorY -lt $limit - 1) { 
                    $cursorY++
                    if ($cursorX -eq 0) { $Global:Context.Config.FlashSize = $flashOptions[$cursorY] } else { $Global:Context.Config.PSRAMType = $psramOptions[$cursorY] } 
                }
            }
            elseif ($K.Key -eq [ConsoleKey]::Enter) { $Global:Context.CurrentState = "State-LibMain"; $done = $true }
            elseif ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done = $true }
        }
        Start-Sleep -Milliseconds 40
    }
}

# =============================================================================
# 4. GESTOR DE LIBRERÍAS (Menú Principal, Buscador REST y Control de Versiones)
# =============================================================================

<#
.SYNOPSIS
    El Menú Principal del Gestor de Librerías (lib_deps).
.DESCRIPTION
    Muestra todas las librerías preparadas para el proyecto. Ofrece opciones 
    para Guardar e Iniciar el proyecto, buscar nuevas librerías, inspeccionarlas (tecla 'i'),
    o borrarlas (tecla 'x').
#>
function Invoke-StateLibMain {
    $cursor = $Global:Context.LibMainCursor # Recuperamos la última posición por si volvemos desde otra vista
    $done = $false
    while (-not $done) {
        $winH = $Host.UI.RawUI.WindowSize.Height; $listSpace = $winH - 5
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   PIO: GESTOR DE LIBRERIAS (LIB_DEPS)    " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        
        $totalItems = 2 + $Global:Context.Config.Libraries.Count
        if ($cursor -ge $totalItems) { $cursor = [Math]::Max(0, $totalItems - 1) }
        $Global:Context.LibMainCursor = $cursor

        # Opción 1 de Navegación: Guardar y Salir
        $p0 = if ($cursor -eq 0) { " > " } else { "   " }
        $bg0 = if ($cursor -eq 0) { $Theme.SelBack } else { "Black" }
        $fg0 = if ($cursor -eq 0) { $Theme.Selected } else { $Theme.Action }
        Out-BufferLine "$p0[ Continuar y Guardar ]" -Fore $fg0 -Back $bg0 -NewLine
        
        # Opción 2 de Navegación: Buscar Libs
        $p1 = if ($cursor -eq 1) { " > " } else { "   " }
        $bg1 = if ($cursor -eq 1) { $Theme.SelBack } else { "Black" }
        $fg1 = if ($cursor -eq 1) { $Theme.Selected } else { $Theme.Highlight }
        Out-BufferLine "$p1[ + ] Buscar y Añadir Nueva Librería" -Fore $fg1 -Back $bg1 -NewLine
        Out-BufferLine "" -NewLine

        # Lista de Librerías Actuales
        if ($Global:Context.Config.Libraries.Count -eq 0) {
            Out-BufferLine "   (No hay librerías instaladas en este proyecto)" -Fore $Theme.Faint -NewLine
            for ($k=0; $k -lt ($listSpace - 4); $k++) { Out-BufferLine "" -NewLine }
        } else {
            for ($i=0; $i -lt $Global:Context.Config.Libraries.Count; $i++) {
                $idx = $i + 2
                $p = if ($idx -eq $cursor) { " > " } else { "   " }
                $bg = if ($idx -eq $cursor) { $Theme.SelBack } else { "Black" }
                $fg = if ($idx -eq $cursor) { $Theme.Selected } else { $Theme.Text }
                
                $lib = $Global:Context.Config.Libraries[$i]
                Out-BufferLine "$p$($lib.Name) @ $($lib.Version)" -Fore $fg -Back $bg -NewLine
            }
            for ($k=0; $k -lt ($listSpace - 3 - $Global:Context.Config.Libraries.Count); $k++) { Out-BufferLine "" -NewLine }
        }

        [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " [Enter] Editar  [x] Borrar  [i] Info  [h] Atrás  [q] Salir App" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done=$true }
            elseif ($K.KeyChar -eq 's') { $Global:Context.CurrentState = "State-Save"; $done=$true }
            elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { 
                # Retroceder respetando la placa que tenemos seleccionada
                if ($Global:Context.Config.Board -match "s3") { $Global:Context.CurrentState = "State-Memory" } 
                else { $Global:Context.CurrentState = "State-Baud" }
                $done = $true 
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $totalItems - 1) { $cursor++ } }
            elseif ($K.KeyChar -eq 'i') {
                # Mostrar Info Interactivamente
                if ($cursor -ge 2) {
                    $lib = $Global:Context.Config.Libraries[$cursor - 2]
                    Show-LibDetails -LibraryName $lib.Name -FallbackItem @{ name=$lib.Name; version=$lib.Version }
                    if ($Global:Context.CurrentState -eq "ExitApp") { $done = $true } # Respetar señal de apagado
                }
            }
            elseif ($K.KeyChar -eq 'x' -or $K.Key -eq [ConsoleKey]::Delete) {
                # Borrado lógico de un elemento en memoria usando un array temporal auxiliar
                if ($cursor -ge 2) {
                    $libIndex = $cursor - 2
                    $tempArray = @()
                    for ($i=0; $i -lt $Global:Context.Config.Libraries.Count; $i++) { 
                        if ($i -ne $libIndex) { $tempArray += $Global:Context.Config.Libraries[$i] } 
                    }
                    $Global:Context.Config.Libraries = $tempArray
                }
            }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') { 
                if ($cursor -eq 0) { $Global:Context.CurrentState = "State-Save"; $done = $true }
                elseif ($cursor -eq 1) { $Global:Context.CurrentState = "State-LibSearch"; $done = $true }
                else {
                    # Si selecciona una librería, abrimos el selector de versiones para esa librería
                    $lib = $Global:Context.Config.Libraries[$cursor - 2]
                    $Global:Context.TempLib.Name = $lib.Name; $Global:Context.TempLib.CurrentVersion = $lib.Version
                    $Global:Context.LibVersionReturnState = "State-LibMain"
                    $Global:Context.CurrentState = "State-LibVersion"; $done = $true
                }
            }
        }
        Start-Sleep -Milliseconds 40
    }
}

<#
.SYNOPSIS
    Busca paquetes vía web llamando a la API Registry V3 de PlatformIO.
.DESCRIPTION
    Toma un texto libre por consola, lanza el query a la API y dibuja los resultados.
    Posee caché interno: si el usuario elige una versión y cancela, al volver
    los resultados seguirán ahí sin tener que consultar la API de nuevo.
#>
function Invoke-StateLibSearch {
    
    # Evaluar si la caché de resultados de una búsqueda previa debe ser restaurada
    if ($Global:Context.SearchCache.Active) {
        $results = $Global:Context.SearchCache.Results
        $cursor  = $Global:Context.SearchCache.Cursor
        $scroll  = $Global:Context.SearchCache.Scroll
        $Global:Context.SearchCache.Active = $false
    } else {
        # Si no hay caché, pedimos el input del usuario para una búsqueda nueva
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   PIO: BUSCADOR DE LIBRERIAS (API)       " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "" -NewLine
        Out-BufferLine " Escribe el nombre o palabra clave (ej: json, dht11, adafruit)" -Fore $Theme.Faint -NewLine
        Out-BufferLine " Presiona [Enter] para buscar o [Esc] para cancelar." -Fore $Theme.Faint -NewLine
        Out-BufferLine "" -NewLine
        [Console]::Write(" BUSCAR: ")
        
        try { [Console]::CursorVisible = $true } catch {}
        $query = Read-Host
        try { [Console]::CursorVisible = $false } catch {}

        if ([string]::IsNullOrWhiteSpace($query)) { $Global:Context.CurrentState = "State-LibMain"; return }

        Out-BufferLine " Buscando en PlatformIO Registry, por favor espera..." -Fore $Theme.Loading -NewLine
        
        try {
            # Consulta REST cifrada en formato URI para evitar inyecciones e invalidaciones HTTP
            $safeQuery = [uri]::EscapeDataString($query)
            $uri = "https://api.registry.platformio.org/v3/search?query=$safeQuery"
            $json = Invoke-RestMethod -Uri $uri
            
            $results = @()
            if ($json.items) { $results = $json.items } elseif ($json -is [array]) { $results = $json }
            
            if ($results.Count -eq 0) {
                Out-BufferLine " No se encontraron resultados. Presiona cualquier tecla..." -Fore $Theme.Error
                [Console]::ReadKey($true) | Out-Null
                $Global:Context.CurrentState = "State-LibMain"
                return
            }
            
            # Guardar en la caché para no tener que buscar de nuevo
            $Global:Context.SearchCache.Results = $results
            $cursor = 0; $scroll = 0
        } catch {
            Out-BufferLine " Error al contactar PlatformIO Registry. Presiona cualquier tecla..." -Fore $Theme.Error
            [Console]::ReadKey($true) | Out-Null
            $Global:Context.CurrentState = "State-LibMain"
            return
        }
    }

    $done = $false
    # Bucle gráfico de visualización de resultados
    while (-not $done) {
        $winH = $Host.UI.RawUI.WindowSize.Height; $listSpace = $winH - 5
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   RESULTADOS DE BUSQUEDA                 " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine

        if ($cursor -ge $scroll + $listSpace) { $scroll = $cursor - $listSpace + 1 }
        if ($cursor -lt $scroll) { $scroll = $cursor }

        for ($i=0; $i -lt $listSpace; $i++) {
            $idx = $scroll + $i
            if ($idx -lt $results.Count) {
                $item = $results[$idx]
                $p = if ($idx -eq $cursor) { " > " } else { "   " }
                $bg = if ($idx -eq $cursor) { $Theme.SelBack } else { "Black" }
                $fg = if ($idx -eq $cursor) { $Theme.Selected } else { $Theme.Text }
                
                $ownerName = if ($item.owner -and $item.owner.username) { $item.owner.username } else { "Unknown" }
                $libFullName = "$ownerName/$($item.name)"
                
                # Check Estricto: Comprueba visualmente si esta librería ya la tienes para marcarla en verde
                $isInstalled = $false
                $searchBase = $item.name.ToLower()
                $searchOwner = $ownerName.ToLower()
                
                foreach ($l in $Global:Context.Config.Libraries) {
                    $lBase = ($l.Name -split "/")[-1].ToLower()
                    $lOwner = if ($l.Name -match "/") { ($l.Name -split "/")[0].ToLower() } else { "" }
                    
                    if ($lBase -eq $searchBase -and ($lOwner -eq "" -or $lOwner -eq $searchOwner)) { 
                        $isInstalled = $true; break 
                    }
                }
                
                if ($isInstalled) {
                    $fgInst = if ($idx -eq $cursor) { $Theme.Selected } else { $Theme.Action }
                    Out-BufferLine "$p$libFullName [Instalada]" -Fore $fgInst -Back $bg -NewLine
                } else {
                    Out-BufferLine "$p$libFullName" -Fore $fg -Back $bg -NewLine
                }
            } else { Out-BufferLine "" -NewLine }
        }

        [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " [Enter] Instalar  [i] Ver Info  [h] Volver  [q] Salir App" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            if ($K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done = $true }
            elseif ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'h') { $Global:Context.CurrentState = "State-LibMain"; $done = $true }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $results.Count - 1) { $cursor++ } }
            elseif ($K.KeyChar -eq 'i') {
                $item = $results[$cursor]
                $ownerName = if ($item.owner -and $item.owner.username) { $item.owner.username } else { "" }
                $libFullName = if ($ownerName) { "$ownerName/$($item.name)" } else { $item.name }
                
                Show-LibDetails -LibraryName $libFullName -FallbackItem $item
                if ($Global:Context.CurrentState -eq "ExitApp") { $done = $true }
            }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') {
                $item = $results[$cursor]
                $ownerName = if ($item.owner -and $item.owner.username) { $item.owner.username } else { "Unknown" }
                $targetName = "$ownerName/$($item.name)"
                
                $Global:Context.TempLib.Name = $targetName
                $Global:Context.TempLib.CurrentVersion = "latest"
                
                # Pre-Carga de la Versión para el Cursor:
                # Si vas a instalar una librería pero detectamos que YA la tienes, seteamos tu
                # versión actual en el TempLib para que aparezca marcada en la lista que sigue.
                $searchBase = $item.name.ToLower()
                $searchOwner = $ownerName.ToLower()
                foreach ($l in $Global:Context.Config.Libraries) {
                    $lBase = ($l.Name -split "/")[-1].ToLower()
                    $lOwner = if ($l.Name -match "/") { ($l.Name -split "/")[0].ToLower() } else { "" }
                    if ($lBase -eq $searchBase -and ($lOwner -eq "" -or $lOwner -eq $searchOwner)) {
                        $Global:Context.TempLib.CurrentVersion = $l.Version
                        break
                    }
                }
                
                # Preservamos los datos de nuestra lista por si el usuario presiona [h]
                $Global:Context.SearchCache.Active = $true
                $Global:Context.SearchCache.Cursor = $cursor
                $Global:Context.SearchCache.Scroll = $scroll
                
                $Global:Context.LibVersionReturnState = "State-LibSearch"
                $Global:Context.CurrentState = "State-LibVersion"
                $done = $true
            }
        }
        Start-Sleep -Milliseconds 40
    }
}

<#
.SYNOPSIS
    Consulta el registro para obtener todas las versiones publicadas de una librería.
.DESCRIPTION
    Esta pantalla recibe un TempLib y solicita su historial de versiones.
    También marca de forma visual "[*]" la versión de esa librería que tengas 
    previamente instalada en tu configuración, para facilitar el Upgrade/Downgrade.
#>
function Invoke-StateLibVersion {
    $winH = $Host.UI.RawUI.WindowSize.Height
    [Console]::SetCursorPosition(0,0)
    Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
    Out-BufferLine "   PIO: SELECCION DE VERSION              " -Fore $Theme.Title -NewLine
    Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
    Out-BufferLine " Librería: $($Global:Context.TempLib.Name)" -Fore $Theme.Highlight -NewLine
    Out-BufferLine " Cargando versiones, por favor espera..." -Fore $Theme.Loading -NewLine
    
    # Se pintan vacías las líneas posteriores para evitar remanentes visuales ("artefactos")
    for ($k = 5; $k -lt $winH; $k++) { Out-BufferLine "" -NewLine }
    
    $versions = @("latest")
    try {
        $parts = $Global:Context.TempLib.Name -split "/", 2
        if ($parts.Count -eq 2) {
            $safeOwner = [uri]::EscapeDataString($parts[0])
            $safeName = [uri]::EscapeDataString($parts[1])
            $uri = "https://api.registry.platformio.org/v3/packages/$safeOwner/library/$safeName"
        } else {
            $libNameUri = [uri]::EscapeDataString($Global:Context.TempLib.Name)
            $uri = "https://api.registry.platformio.org/v3/packages/library/$libNameUri"
        }
        
        $json = Invoke-RestMethod -Uri $uri
        
        # Extraemos e insertamos el arreglo de versiones disponibles al selector
        if ($null -ne $json.versions -and $json.versions.Count -gt 0) { 
            foreach($v in $json.versions) { if ($v.name) { $versions += "^$($v.name)" } } 
        } elseif ($json.version -and $json.version.name) { 
            $versions += "^$($json.version.name)" 
        }
    } catch { 
        [Console]::SetCursorPosition(0,5)
        Out-BufferLine " (Advertencia: No se pudieron cargar las versiones completas)" -Fore $Theme.Error -NewLine 
    }

    $cursor = 0; $scroll = 0; $done = $false
    while (-not $done) {
        $winH = $Host.UI.RawUI.WindowSize.Height; $listSpace = $winH - 6
        [Console]::SetCursorPosition(0,4)

        if ($cursor -ge $scroll + $listSpace) { $scroll = $cursor - $listSpace + 1 }
        if ($cursor -lt $scroll) { $scroll = $cursor }

        for ($i=0; $i -lt $listSpace; $i++) {
            $idx = $scroll + $i
            if ($idx -lt $versions.Count) {
                $ver = $versions[$idx]
                $p = if ($idx -eq $cursor) { " > " } else { "   " }
                $bg = if ($idx -eq $cursor) { $Theme.SelBack } else { "Black" }
                $fg = if ($idx -eq $cursor) { $Theme.Selected } else { $Theme.Text }
                
                # Para mostrar el asterisco (*), limpiamos los caracteres de rango especiales de SemVer
                $cleanTempVer = $Global:Context.TempLib.CurrentVersion -replace "[\^\~]",""
                $cleanListVer = $ver -replace "[\^\~]",""
                $mark = if ($cleanTempVer -eq $cleanListVer) { "[*] " } else { "    " }
                
                Out-BufferLine "$p$mark$ver" -Fore $fg -Back $bg -NewLine
            } else { Out-BufferLine "" -NewLine }
        }

        [Console]::SetCursorPosition(0, $winH - 1)
        Out-BufferLine " [Enter] Confirmar  [h/Esc] Cancelar  [q] Salir App  [j/k] Navegar" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            
            if ($K.KeyChar -eq 'q') { $Global:Context.CurrentState = "ExitApp"; $done = $true }
            elseif ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'h') { 
                # Si el usuario vino desde el buscador, reactivamos la caché al retroceder
                if ($Global:Context.LibVersionReturnState -eq "State-LibSearch") {
                    $Global:Context.SearchCache.Active = $true
                }
                $Global:Context.CurrentState = $Global:Context.LibVersionReturnState; $done = $true 
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { if ($cursor -lt $versions.Count - 1) { $cursor++ } }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') {
                # Confirmación: Añadimos y sobreescribimos cualquier versión antigua automáticamente
                $selectedVer = $versions[$cursor]
                Add-LibDep -Raw "$($Global:Context.TempLib.Name) @ $selectedVer"
                
                $Global:Context.CurrentState = "State-LibMain"; $done = $true
            }
        }
        Start-Sleep -Milliseconds 40
    }
}

# =============================================================================
# 5. MÓDULO CIRUJANO DE GUARDADO (PERSISTENCIA FINAL)
# =============================================================================

<#
.SYNOPSIS
    El bloque más crítico del programa: Aplica los cambios a platformio.ini 
    sin dañar otros bloques que el usuario haya hecho manualmente.
.DESCRIPTION
    Lee el archivo en memoria, detecta qué entorno va a modificar y usa una expresión 
    regular (regex) destructiva ('^$k([\.a-zA-Z0-9_-]*)\s*=') para eliminar CUALQUIER 
    propiedad, o sub-propiedad (como flash_size) que pertenezca a las configuraciones
    gestionales de este script. Luego injerta el bloque nuevo generado arriba de todo.
    Al finalizar inicializa el proyecto VSCode y provee el código base main.
#>
function Invoke-StateSave {
    Clear-Host
    Write-Host "`n [1/3] Operando platformio.ini (Modo Cirujano Experto)..." -ForegroundColor Yellow
    
    # 1. Cargamos el archivo en la memoria.
    $lines = if (Test-Path $Global:Context.IniPath) { (Get-Content $Global:Context.IniPath) } else { @() }
    $newLines = @(); $envFound = $false
    $flashMap = @{ "4MB" = "4194304"; "8MB" = "8388608"; "16MB" = "16777216"; "32MB" = "33554432" }
    
    # 2. Preparamos el bloque de código injertable para nuestra placa y settings.
    $configBlock = @(
        "platform = $($Global:Context.Config.Platform)",
        "board = $($Global:Context.Config.Board)",
        "framework = $($Global:Context.Config.Framework)",
        "monitor_speed = $($Global:Context.Config.Baud)"
    )

    if ($Global:Context.Config.Port) {
        $configBlock += "upload_port = $($Global:Context.Config.Port)"
        $configBlock += "monitor_port = $($Global:Context.Config.Port)"
    }

    # Bloque exclusivo de configuraciones para placas S3
    if ($Global:Context.Config.Board -match "s3") {
        $configBlock += "board_upload.flash_size = $($Global:Context.Config.FlashSize)"
        $configBlock += "board_upload.maximum_size = $($flashMap[$Global:Context.Config.FlashSize])"
        
        if ($Global:Context.Config.FlashSize -eq "16MB") { $configBlock += "board_build.partitions = default_16MB.csv" }
        elseif ($Global:Context.Config.FlashSize -eq "8MB") { $configBlock += "board_build.partitions = default_8MB.csv" }

        if ($Global:Context.Config.PSRAMType -ne "None") {
            $configBlock += "build_flags = -DBOARD_HAS_PSRAM"
            if ($Global:Context.Config.PSRAMType -match "OPI") { $configBlock += "board_build.arduino.memory_type = qio_opi" } 
            else { $configBlock += "board_build.arduino.memory_type = qio_qspi" }
        }
    }

    # Adjuntamos el bloque dinámico de lib_deps a los ajustes
    if ($Global:Context.Config.Libraries.Count -gt 0) {
        $configBlock += "lib_deps ="
        foreach ($lib in $Global:Context.Config.Libraries) {
            if ($lib.Version -eq "latest") { $configBlock += "    $($lib.Name)" }
            else { $configBlock += "    $($lib.Name) @ $($lib.Version)" }
        }
    }

    $inTargetEnv = $false; $inLibDepsOld = $false
    # Estas son las claves maestras. El bisturí borrará cualquier cosa que comience con ellas en tu entorno.
    $keysToFilter = @("platform", "board", "framework", "monitor_speed", "upload_port", "monitor_port", "board_upload", "board_build", "build_flags", "lib_deps")

    # 3. Aplicamos el reemplazo (Iteramos sobre las líneas previas del ini)
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        
        # Encontramos la declaración de nuestro entorno
        if ($trimmed -match "^\[env") {
            if (-not $envFound) {
                $envFound = $true; $inTargetEnv = $true; $inLibDepsOld = $false
                $newLines += "[env:$($Global:Context.Config.Board)]"
                $newLines += $configBlock
                continue
            } else { 
                # Si hay más entornos abajo, dejamos de cortarlos
                $inTargetEnv = $false; $inLibDepsOld = $false 
            }
        }
        
        if ($inTargetEnv) {
            $match = $false
            foreach($k in $keysToFilter){ 
                # BISTURÍ: Si coincide (ej. "board_upload.flash_size="), lo marca como coincidencia
                # para 'Omitirlo' (borrarlo) de las nuevas líneas de archivo.
                if($trimmed -match "^$k([\.a-zA-Z0-9_-]*)\s*=") { 
                    $match = $true
                    if ($k -eq "lib_deps") { $inLibDepsOld = $true } else { $inLibDepsOld = $false }
                    break 
                } 
            }
            if($match){ continue } # Línea borrada exitosamente
            
            # Borrado masivo interior de las librerías antiguas que estaban abajo de lib_deps=
            if ($inLibDepsOld) {
                if ($trimmed -match "^[a-zA-Z0-9_\-\.]+\s*=") { 
                    $inLibDepsOld = $false # Fin de bloque: otra propiedad ha empezado
                } elseif ($trimmed.StartsWith("[")) { 
                    $inLibDepsOld = $false # Fin de bloque: otro env ha empezado
                } else { 
                    continue # Borramos línea interior silenciosamente
                }
            }
        }
        # Las líneas que sobrevivieron a la cirugía, se reescriben
        $newLines += $line
    }

    # 4. Fallback si el archivo ini no existía o estaba en blanco
    if (-not $envFound) {
        if ($newLines.Count -eq 0) { $newLines += "; Generado por TUI CLI V8.0 (The Fully Documented Edition)" }
        $newLines += "`n[env:$($Global:Context.Config.Board)]"
        $newLines += $configBlock
    }

    # Imprimimos finalmente el archivo destruyendo el viejo
    Set-Content -Path $Global:Context.IniPath -Value $newLines -Encoding UTF8 -Force

    # 5. Generación Boilerplate C++ (Inicialización Rápida)
    Write-Host " [2/3] Verificando carpetas y generando plantilla Hola Mundo..." -ForegroundColor Yellow
    foreach ($f in @("src", "lib", "include", "test")) { if (-not (Test-Path $f)) { New-Item -ItemType Directory $f -Force | Out-Null } }

    $mainCpp = Join-Path "src" "main.cpp"; $mainC = Join-Path "src" "main.c"

    if (-not (Test-Path $mainCpp) -and -not (Test-Path $mainC)) {
        # Si src está vacío, proveemos un código testeable pre-armado
        if ($Global:Context.Config.Framework -eq "arduino") {
            $code = @"
#include <Arduino.h>

void setup() {
    Serial.begin($($Global:Context.Config.Baud));
    delay(1000); // Pequeña pausa para asegurar que el puerto serie se estabilice
    Serial.println("\n--- INICIO ---");
    Serial.println("¡Hola Mundo desde PlatformIO!");
    Serial.println("¡Sistema inicializado correctamente!");
}

void loop() {
    Serial.println("Funcionando correctamente...");
    delay(2000);
}
"@
            $code | Out-File $mainCpp -Encoding UTF8
        } 
        elseif ($Global:Context.Config.Framework -eq "espidf") {
            $code = @"
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

void app_main() {
    printf("\n--- INICIO ---\n");
    printf("¡Hola Mundo desde PlatformIO (ESP-IDF)!\n");
    printf("¡Sistema inicializado correctamente!\n");
    
    while(1) {
        printf("Funcionando correctamente...\n");
        vTaskDelay(2000 / portTICK_PERIOD_MS);
    }
}
"@
            $code | Out-File $mainC -Encoding UTF8
        }
    } else { Write-Host "       -> Se detecto código existente en src/. No se realizaran cambios en tu código." -ForegroundColor Cyan }

    # 6. Sincronización oficial y salida
    Write-Host " [3/3] Sincronizando VS Code con PlatformIO..." -ForegroundColor Yellow
    try {
        $null = pio project init --ide vscode 2>&1
        Write-Host "`n [OK] Configuración y dependencias aplicadas exitosamente." -ForegroundColor Green
    } catch { Write-Host "`n [ADVERTENCIA] El archivo se guardo, pero pio init falló." -ForegroundColor Red }

    [Console]::ResetColor(); Start-Sleep 2
    $Global:Context.CurrentState = "ExitApp"
}

# =============================================================================
# 6. MOTOR PRINCIPAL (Bucle de Eventos y Manejador de Máquina de Estado)
# =============================================================================
try {
    Initialize-UI
    Load-Config
    
    # Enrutador estricto (State Machine). Salta entre pantallas hasta que se envíe ExitApp.
    while ($Global:Context.CurrentState -ne "ExitApp") {
        switch ($Global:Context.CurrentState) {
            "State-Port"       { Invoke-StatePort }
            "State-Board"      { Invoke-StateBoard }
            "State-Framework"  { Invoke-StateFramework }
            "State-Baud"       { Invoke-StateBaud }
            "State-Memory"     { Invoke-StateMemory }
            "State-LibMain"    { Invoke-StateLibMain }
            "State-LibSearch"  { Invoke-StateLibSearch }
            "State-LibVersion" { Invoke-StateLibVersion }
            "State-Save"       { Invoke-StateSave }
        }
    }
} finally { 
    # Garbage Collection: Restauramos siempre la terminal al color y visualización original
    try { [Console]::CursorVisible = $true } catch {}
    [Console]::ResetColor(); Clear-Host 
}
