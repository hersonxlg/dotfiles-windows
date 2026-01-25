<#
.SYNOPSIS
    Arduino Configurator TUI - Versión Estable y Obvia
#>

using namespace System.Collections.Generic

# =============================================================================
# 1. CONFIGURACIÓN DEL ENTORNO
# =============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# Estado Global
$Global:Context = @{
    Running      = $true
    CurrentState = "State-Port"
    YamlPath     = Join-Path (Get-Location) "sketch.yaml"
    Config = @{ Port = $null; FQBN = $null; Baud = 9600; EOL  = "LF" }
    Cache = @{ Boards = $null }
}

$Theme = @{
    Title      = "Yellow"
    Label      = "Cyan"
    Text       = "White"
    Selected   = "Black"
    SelBack    = "Cyan"
    Faint      = "DarkGray"
    Success    = "Green"
    Error      = "Red"
    Detected   = "Green"
    StatusBack = "DarkGray" 
    StatusText = "White"
    SearchBack = "Black"    
    SearchText = "Green"
    DialogBack = "Black"
    DialogText = "White"
    DialogBorder = "Cyan"
}

# =============================================================================
# 2. FUNCIONES DE UTILERÍA
# =============================================================================

function Initialize-UI {
    $host.UI.RawUI.WindowTitle = "Arduino CLI Configurator"
    try { [Console]::CursorVisible = $false } catch {}
    Clear-Host 
    $host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
    $host.UI.RawUI.ForegroundColor = [ConsoleColor]::White
}

function Reset-UI {
    try { [Console]::CursorVisible = $true } catch {}
    [Console]::ResetColor()
    Clear-Host
}

function Out-BufferLine {
    param(
        [string]$Text,
        [string]$Fore = "White",
        [string]$Back = "Black",
        [switch]$NewLine
    )
    $width = $host.UI.RawUI.WindowSize.Width
    if ($width -le 1) { $width = 80 }
    
    if ($Text.Length -ge $width) { 
        $Text = $Text.Substring(0, $width - 1) 
    }
    $pad = " " * ($width - $Text.Length)
    
    $oldF = [Console]::ForegroundColor
    $oldB = [Console]::BackgroundColor
    
    try {
        [Console]::ForegroundColor = [Enum]::Parse([ConsoleColor], $Fore)
        [Console]::BackgroundColor = [Enum]::Parse([ConsoleColor], $Back)
        [Console]::Write("$Text$pad")
        if ($NewLine) { [Console]::Write([Environment]::NewLine) }
    } catch {
        [Console]::ResetColor()
        [Console]::Write("$Text$pad")
    } finally {
        [Console]::ForegroundColor = $oldF
        [Console]::BackgroundColor = $oldB
    }
}

function Show-Dialog {
    param(
        [string]$Title,
        [string]$Message,
        [int]$Padding = 4,
        [switch]$Wait
    )
    
    $msgLen = $Message.Length
    $innerW = $msgLen + ($Padding * 2)
    $boxW   = $innerW + 2 
    $boxH   = 5           
    
    $winW = $Host.UI.RawUI.WindowSize.Width
    $winH = $Host.UI.RawUI.WindowSize.Height
    
    $startX = [math]::Floor(($winW - $boxW) / 2)
    $startY = [math]::Floor(($winH - $boxH) / 2)
    if ($startX -lt 0) { $startX = 0 }
    if ($startY -lt 0) { $startY = 0 }

    $topLineCore = "-" * $innerW
    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        $tLen = $Title.Length
        if ($tLen -lt ($innerW - 2)) {
            $side = [math]::Floor(($innerW - $tLen - 2) / 2)
            $topLineCore = ("-" * $side) + " $Title " + ("-" * ($innerW - $side - $tLen - 2))
        }
    }
    
    $draw = { param($x,$y,$t,$f,$b) 
        [Console]::SetCursorPosition($x, $y)
        $oldF = [Console]::ForegroundColor; $oldB = [Console]::BackgroundColor
        [Console]::ForegroundColor = [Enum]::Parse([ConsoleColor], $f)
        [Console]::BackgroundColor = [Enum]::Parse([ConsoleColor], $b)
        [Console]::Write($t)
        [Console]::ForegroundColor = $oldF; [Console]::BackgroundColor = $oldB
    }
    
    & $draw $startX ($startY + 0) "+$topLineCore+" $Theme.DialogBorder $Theme.DialogBack
    & $draw $startX ($startY + 1) ("|" + (" " * $innerW) + "|") $Theme.DialogText $Theme.DialogBack
    & $draw $startX ($startY + 2) ("|" + (" " * $Padding) + $Message + (" " * $Padding) + "|") $Theme.DialogText $Theme.DialogBack
    & $draw $startX ($startY + 3) ("|" + (" " * $innerW) + "|") $Theme.DialogText $Theme.DialogBack
    & $draw $startX ($startY + 4) ("+" + ("-" * $innerW) + "+") $Theme.DialogBorder $Theme.DialogBack
    
    if ($Wait) { 
        $null = [Console]::ReadKey($true) 
    }
}

function Get-FilteredList {
    param($SourceData, $Query)
    if ([string]::IsNullOrWhiteSpace($Query)) { return $SourceData }
    $terms = $Query -split "\s+" | Where-Object { $_ -ne "" }
    $SourceData | Where-Object {
        $item = $_; $match = $true
        foreach ($t in $terms) {
            if (-not ($item.Name -match $t -or $item.FQBN -match $t)) { 
                $match = $false; break 
            }
        }
        $match
    }
}

function Load-Config {
    if (Test-Path $Global:Context.YamlPath) {
        try {
            $txt = Get-Content $Global:Context.YamlPath -Raw
            if ($txt -match "default_port:\s*([^\s]+)") { $Global:Context.Config.Port = $matches[1] }
            if ($txt -match "default_fqbn:\s*([^\s]+)") { $Global:Context.Config.FQBN = $matches[1] }
            if ($txt -match "baud:\s*(\d+)") { $Global:Context.Config.Baud = [int]$matches[1] }
            if ($txt -match "eol:\s*(\w+)") { $Global:Context.Config.EOL = $matches[1] }
        } catch {}
    }
}

# =============================================================================
# 3. PANTALLAS (ESTADOS)
# =============================================================================

# --- ESTADO 1: SELECCIÓN DE PUERTO ---
function Invoke-StatePort {
    $cursor = 0
    $lastKnownPorts = @()
    $detectedPortName = "" 
    $currentPorts = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object -Unique)
    $lastKnownPorts = $currentPorts
    $done = $false
    
    if ($Global:Context.Config.Port) { 
        $idx = $currentPorts.IndexOf($Global:Context.Config.Port)
        if($idx -ge 0){ $cursor = $idx } 
    }

    while (-not $done) {
        $currentPorts = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object -Unique)
        $diff = Compare-Object -ReferenceObject $lastKnownPorts -DifferenceObject $currentPorts
        if ($diff) {
            $added = $diff | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject -First 1
            if ($added) {
                $detectedPortName = $added
                $newIdx = $currentPorts.IndexOf($added)
                if ($newIdx -ge 0) { $cursor = $newIdx }
            } else { 
                if ($cursor -ge $currentPorts.Count) { 
                    $cursor = [Math]::Max(0, $currentPorts.Count - 1) 
                } 
            }
            $lastKnownPorts = $currentPorts
        }

        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   SELECCION DE PUERTO (HARDWARE)         " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine

        $height = $Host.UI.RawUI.WindowSize.Height
        $listHeight = $height - 5 
        
        if ($currentPorts.Count -eq 0) {
            Out-BufferLine " " -NewLine
            Out-BufferLine "   [ ESPERANDO CONEXION USB... ]" -Fore $Theme.Error -NewLine
            for($k=0; $k -lt ($listHeight - 2); $k++){ Out-BufferLine "" -NewLine }
        } else {
            for ($i = 0; $i -lt $listHeight; $i++) {
                if ($i -lt $currentPorts.Count) {
                    $p = $currentPorts[$i]
                    $prefix = "   "
                    $fg = $Theme.Text
                    $bg = "Black"
                    $suffix = ""
                    
                    if ($p -eq $Global:Context.Config.Port) { 
                        $suffix += " (Guardado)"
                        $fg = $Theme.Faint 
                    }
                    if ($p -eq $detectedPortName) { 
                        $suffix += " [ ! NUEVO ! ]"
                        if ($i -ne $cursor) { $fg = $Theme.Detected } 
                    }
                    if ($i -eq $cursor) { 
                        $prefix = " > "
                        $fg = $Theme.Selected
                        $bg = $Theme.SelBack 
                    }
                    Out-BufferLine "$prefix$p$suffix" -Fore $fg -Back $bg -NewLine
                } else { 
                    Out-BufferLine "" -NewLine 
                }
            }
        }
        
        [Console]::SetCursorPosition(0, $height - 2)
        if ($detectedPortName -and $currentPorts -contains $detectedPortName) {
             Out-BufferLine " ALERTA: Nuevo dispositivo detectado en $detectedPortName" -Fore $Theme.Detected -Back $Theme.StatusBack
        } else {
             Out-BufferLine " ESTADO: Conecta/Desconecta tu placa para auto-detectar." -Fore $Theme.StatusText -Back $Theme.StatusBack
        }
        
        [Console]::SetCursorPosition(0, $height - 1)
        Out-BufferLine " COMANDOS: [q/Esc] Salir  [Enter/l] Siguiente  [j/k] Navegar" -Fore $Theme.Faint -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            
            # --- LÓGICA DIRECTA Y OBVIA ---
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') {
                $Global:Context.CurrentState = "ExitApp"; $done = $true
            }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.Key -eq [ConsoleKey]::RightArrow -or $K.KeyChar -eq 'l') {
                if ($currentPorts.Count -gt 0) { 
                    $Global:Context.Config.Port = $currentPorts[$cursor]
                    $Global:Context.CurrentState = "State-Board"
                    $done = $true
                }
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { 
                if ($cursor -gt 0) {
                    $cursor-- 
                }else{
                    $cursor = $currentPorts.Count - 1
                }
            }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { 
                if ($cursor -lt $currentPorts.Count - 1) {
                    $cursor++
                }else{
                    $cursor = 0
                }
            }
        }
        Start-Sleep -Milliseconds 50
    }
}

# --- ESTADO 2: SELECCIÓN DE PLACA ---
function Invoke-StateBoard {
    if (-not $Global:Context.Cache.Boards) {
        Show-Dialog -Title "SISTEMA" -Message "Leyendo definiciones de placas..." -Padding 2
        try {
            $raw = arduino-cli board listall | Select-Object -Skip 1
            $list = @()
            foreach ($line in $raw) {
                if ($line -match "^(.+?)\s{2,}(.+)$") {
                    $list += @{ Name = $matches[1].Trim(); FQBN = $matches[2].Trim() }
                }
            }
            $list += @{ Name = "[ CONFIG MANUAL ]"; FQBN = "MANUAL" }
            $Global:Context.Cache.Boards = $list
        } catch { 
            Show-Dialog -Title "ERROR" -Message "Fallo al cargar boards." -Wait
            $Global:Context.CurrentState = "ExitApp"
            return
        }
    }

    $allData = $Global:Context.Cache.Boards
    $filtered = $allData
    $cursor = 0
    $scroll = 0
    $searchQuery = ""
    $isSearching = $false
    
    # Lógica Vim
    $pendingK = $false
    $pendingKTime = [DateTime]::MinValue
    $vimTimeout = 400 
    $done = $false

    if ($Global:Context.Config.FQBN) { 
        for($i=0;$i -lt $allData.Count;$i++){ 
            if($allData[$i].FQBN -eq $Global:Context.Config.FQBN){ $cursor=$i; break } 
        } 
    }

    while (-not $done) {
        $winHeight = $Host.UI.RawUI.WindowSize.Height
        $listSpace = $winHeight - 5
        
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   SELECCION DE PLACA                     " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        
        if ($cursor -ge $scroll + $listSpace) { $scroll = $cursor - $listSpace + 1 }
        if ($cursor -lt $scroll) { $scroll = $cursor }
        
        for ($i = 0; $i -lt $listSpace; $i++) {
            $dataIdx = $scroll + $i
            if ($dataIdx -lt $filtered.Count) {
                $item = $filtered[$dataIdx]
                $p = "   "
                $fg = $Theme.Text
                $bg = "Black"
                
                if ($item.FQBN -eq $Global:Context.Config.FQBN) { $fg = $Theme.Faint }
                if ($dataIdx -eq $cursor) { 
                    $p = " > "
                    $fg = $Theme.Selected
                    $bg = $Theme.SelBack 
                }
                
                $txt = $item.Name
                if ($txt.Length -gt 60) { $txt = $txt.Substring(0,57) + "..." }
                Out-BufferLine "$p$txt" -Fore $fg -Back $bg -NewLine
            } else { 
                Out-BufferLine "" -NewLine 
            }
        }

        [Console]::SetCursorPosition(0, $winHeight - 2)
        if ($isSearching) {
            Out-BufferLine " MODO BUSQUEDA ACTIVADO." -Fore $Theme.Title -Back $Theme.StatusBack
        } else {
            Out-BufferLine " Total: $($allData.Count) | Filtrados: $($filtered.Count)" -Fore $Theme.StatusText -Back $Theme.StatusBack
        }

        # --- BARRA INFERIOR ---
        [Console]::SetCursorPosition(0, $winHeight - 1)
        if (-not $isSearching -and $searchQuery.Length -eq 0) {
            Out-BufferLine " COMANDOS: [q/Esc] Salir  [Enter/l] Siguiente  [/] Buscar" -Fore $Theme.Faint -Back $Theme.SearchBack
        } else {
            # Renderizamos el texto de busqueda con el "Cursor Virtual" (_)
            $displayText = " BUSCAR > $searchQuery"
            if ($isSearching) { $displayText += "_" } # <--- AQUÍ ESTÁ EL CURSOR
            Out-BufferLine $displayText -Fore $Theme.SearchText -Back $Theme.SearchBack
        }

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            $key = $K.Key
            $char = $K.KeyChar

            if ($isSearching) {
                # --- LÓGICA MODO BÚSQUEDA ---
                
                # Manejo retardo 'j' (Vim)
                if ($pendingK) {
                    $elapsed = ([DateTime]::Now - $pendingKTime).TotalMilliseconds
                    if ($char -eq 'j' -and $elapsed -lt $vimTimeout) {
                        $isSearching = $false; $pendingK = $false; continue
                    } else { 
                        $searchQuery += 'k'; $pendingK = $false 
                    }
                }

                if ($key -eq [ConsoleKey]::Escape) { $isSearching = $false; $pendingK = $false }
                elseif ($key -eq [ConsoleKey]::Enter) { $isSearching = $false }
                elseif ($key -eq [ConsoleKey]::Backspace) {
                    if ($searchQuery.Length -gt 0) { 
                        $searchQuery = $searchQuery.Substring(0, $searchQuery.Length - 1)
                        $filtered = Get-FilteredList $allData $searchQuery
                        $cursor = 0
                    }
                }
                elseif (-not [char]::IsControl($char)) {
                    if ($char -eq 'k') { 
                        $pendingK = $true; $pendingKTime = [DateTime]::Now 
                    } else { 
                        $searchQuery += $char
                        $filtered = Get-FilteredList $allData $searchQuery
                        $cursor = 0 
                    }
                }

            } else {
                # --- LÓGICA MODO NAVEGACIÓN ---
                
                if ($key -eq [ConsoleKey]::Escape -or $char -eq 'q') {
                    $Global:Context.CurrentState = "ExitApp"; $done=$true
                }
                elseif ($key -eq [ConsoleKey]::LeftArrow -or $char -eq 'h') {
                    $Global:Context.CurrentState = "State-Port"; $done=$true
                }
                elseif ($key -eq [ConsoleKey]::Backspace) {
                    # Backspace aquí borra el filtro
                    if ($searchQuery.Length -gt 0) {
                         $searchQuery = $searchQuery.Substring(0, $searchQuery.Length - 1)
                         $filtered = Get-FilteredList $allData $searchQuery
                         $cursor = 0
                    }
                }
                elseif ($key -eq [ConsoleKey]::UpArrow) { if ($cursor -gt 0) { $cursor-- } }
                elseif ($key -eq [ConsoleKey]::DownArrow) { if ($cursor -lt $filtered.Count - 1) { $cursor++ } }
                elseif ($key -eq [ConsoleKey]::Enter) {
                    # SELECCIONAR
                    if ($filtered.Count -gt 0) {
                        $sel = $filtered[$cursor]
                        if ($sel.FQBN -eq "MANUAL") {
                            Reset-UI
                            [Console]::ForegroundColor = [ConsoleColor]::Yellow
                            $manualInput = Read-Host " FQBN Manual"
                            $Global:Context.Config.FQBN = $manualInput
                            Initialize-UI
                        } else { 
                            $Global:Context.Config.FQBN = $sel.FQBN 
                        }
                        $Global:Context.CurrentState = "State-Baud"
                        $done = $true
                    }
                }
                else {
                    # Teclas char especificas
                    if ($char -eq '/') { $isSearching = $true; $cursor = 0 }
                    elseif ($char -eq 'l') { 
                         if ($filtered.Count -gt 0) {
                            $sel = $filtered[$cursor]
                            if ($sel.FQBN -eq "MANUAL") {
                                Reset-UI; $m=Read-Host "FQBN"; $Global:Context.Config.FQBN=$m; Initialize-UI
                            } else { $Global:Context.Config.FQBN = $sel.FQBN }
                            $Global:Context.CurrentState = "State-Baud"; $done = $true
                        }
                    }
                    elseif ($char -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
                    elseif ($char -eq 'j') { if ($cursor -lt $filtered.Count - 1) { $cursor++ } }
                }
            }
        }
        
        # Timeout Vim 'k'
        if ($pendingK -and ([DateTime]::Now - $pendingKTime).TotalMilliseconds -gt $vimTimeout) {
             $searchQuery += 'k'; $pendingK = $false
             $filtered = Get-FilteredList $allData $searchQuery; $cursor = 0
        }
        Start-Sleep -Milliseconds 20
    }
}

# --- ESTADO 3: BAUD RATE ---
function Invoke-StateBaud {
    $rates = @(300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 74880, 115200, 230400, 250000, 460800, 500000, 921600, 1000000, 2000000)
    $cursor = 0
    $scroll = 0
    $done = $false
    
    if ($Global:Context.Config.Baud) {
        $idx = $rates.IndexOf($Global:Context.Config.Baud)
        if ($idx -ge 0) { $cursor = $idx }
    }
    
    while (-not $done) {
        $winHeight = $Host.UI.RawUI.WindowSize.Height
        $listSpace = $winHeight - 5
        
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   VELOCIDAD (BAUD RATE)                  " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        
        if ($cursor -ge $scroll + $listSpace) { $scroll = $cursor - $listSpace + 1 }
        if ($cursor -lt $scroll) { $scroll = $cursor }
        
        for ($i = 0; $i -lt $listSpace; $i++) {
            $dataIdx = $scroll + $i
            if ($dataIdx -lt $rates.Count) {
                $r = $rates[$dataIdx]
                $p="   "
                $fg=$Theme.Text
                $bg="Black"
                if ($dataIdx -eq $cursor) { 
                    $p=" > "
                    $fg=$Theme.Selected
                    $bg=$Theme.SelBack 
                }
                Out-BufferLine "$p$r" -Fore $fg -Back $bg -NewLine
            } else {
                Out-BufferLine "" -NewLine
            }
        }
        
        [Console]::SetCursorPosition(0, $winHeight - 2)
        Out-BufferLine " INFO: Velocidad de comunicacion serial." -Fore $Theme.StatusText -Back $Theme.StatusBack
        [Console]::SetCursorPosition(0, $winHeight - 1)
        Out-BufferLine " COMANDOS: [q/Esc] Salir  [Enter/l] Siguiente" -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { 
                $Global:Context.CurrentState = "ExitApp"; $done=$true 
            }
            elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { 
                $Global:Context.CurrentState = "State-Board"; $done=$true 
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { 
                if ($cursor -gt 0) { $cursor-- } 
            }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { 
                if ($cursor -lt $rates.Count - 1) { $cursor++ } 
            }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') { 
                $Global:Context.Config.Baud = $rates[$cursor]
                $Global:Context.CurrentState = "State-EOL"
                $done = $true
            }
        }
        Start-Sleep -Milliseconds 50
    }
}

# --- ESTADO 4: SELECCIÓN DE EOL ---
function Invoke-StateEOL {
    $done = $false
    $options = @(
        @{ Id="LF";   Name="LF";   Desc="Line Feed (Unix/Linux/Mac moderno)" },
        @{ Id="CR";   Name="CR";   Desc="Carriage Return (Mac antiguo)" },
        @{ Id="CRLF"; Name="LFCR"; Desc="Line Feed + Carriage Return (Windows)" } 
    )

    $cursor = 0
    for($i=0; $i -lt $options.Count; $i++) {
        if ($options[$i].Id -eq $Global:Context.Config.EOL) { $cursor = $i; break }
    }

    while (-not $done) {
        $winHeight = $Host.UI.RawUI.WindowSize.Height
        $listSpace = $winHeight - 5
        
        [Console]::SetCursorPosition(0,0)
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        Out-BufferLine "   FINAL DE LINEA (EOL)                   " -Fore $Theme.Title -NewLine
        Out-BufferLine "==========================================" -Fore $Theme.Label -NewLine
        
        for ($i = 0; $i -lt $options.Count; $i++) {
            $opt = $options[$i]
            $prefix="   "
            $fg=$Theme.Text
            $bg="Black"
            
            if ($i -eq $cursor) { 
                $prefix=" > "
                $fg=$Theme.Selected
                $bg=$Theme.SelBack 
            }
            
            $nameStr = $opt.Name.PadRight(6)
            $textStr = "{0} | {1}" -f $nameStr, $opt.Desc
            
            Out-BufferLine "$prefix$textStr" -Fore $fg -Back $bg -NewLine
        }
        
        for($k=0; $k -lt ($listSpace - $options.Count); $k++){ Out-BufferLine "" -NewLine }
        
        [Console]::SetCursorPosition(0, $winHeight - 2)
        Out-BufferLine " INFO: Caracteres enviados al final de cada mensaje." -Fore $Theme.StatusText -Back $Theme.StatusBack
        [Console]::SetCursorPosition(0, $winHeight - 1)
        Out-BufferLine " COMANDOS: [q/Esc] Salir  [Enter/l] Guardar" -Back $Theme.SearchBack

        if ([Console]::KeyAvailable) {
            $K = [Console]::ReadKey($true)
            
            if ($K.Key -eq [ConsoleKey]::Escape -or $K.KeyChar -eq 'q') { 
                $Global:Context.CurrentState = "ExitApp"; $done=$true 
            }
            elseif ($K.Key -eq [ConsoleKey]::LeftArrow -or $K.KeyChar -eq 'h') { 
                $Global:Context.CurrentState = "State-Baud"; $done=$true 
            }
            elseif ($K.Key -eq [ConsoleKey]::UpArrow -or $K.KeyChar -eq 'k') { 
                if ($cursor -gt 0) { $cursor-- } 
            }
            elseif ($K.Key -eq [ConsoleKey]::DownArrow -or $K.KeyChar -eq 'j') { 
                if ($cursor -lt $options.Count - 1) { $cursor++ } 
            }
            elseif ($K.Key -eq [ConsoleKey]::Enter -or $K.KeyChar -eq 'l') { 
                $Global:Context.Config.EOL = $options[$cursor].Id
                $Global:Context.CurrentState = "State-Save"
                $done = $true
            }
        }
        Start-Sleep -Milliseconds 50
    }
}

# --- ESTADO 5: GUARDADO ---
function Invoke-StateSave {
    Reset-UI
    [Console]::ForegroundColor = [ConsoleColor]::Yellow; [Console]::WriteLine(" RESUMEN DE CONFIGURACION")
    [Console]::ForegroundColor = [ConsoleColor]::DarkGray; [Console]::WriteLine(" ------------------------")
    [Console]::ForegroundColor = [ConsoleColor]::Cyan
    [Console]::WriteLine(" PORT: $($Global:Context.Config.Port)")
    [Console]::WriteLine(" FQBN: $($Global:Context.Config.FQBN)")
    [Console]::WriteLine(" BAUD: $($Global:Context.Config.Baud)")
    [Console]::WriteLine(" EOL:  $($Global:Context.Config.EOL)")
    [Console]::ResetColor()
    
    $nl = [Environment]::NewLine
    $yamlContent = "default_fqbn: $($Global:Context.Config.FQBN)" + $nl +
                   "default_port: $($Global:Context.Config.Port)" + $nl +
                   "profiles:" + $nl +
                   "  main:" + $nl +
                   "    fqbn: $($Global:Context.Config.FQBN)" + $nl +
                   "    port: $($Global:Context.Config.Port)" + $nl +
                   "    monitor:" + $nl +
                   "      baud: $($Global:Context.Config.Baud)" + $nl +
                   "      eol: $($Global:Context.Config.EOL)" + $nl +
                   "      config: 8N1"

    try {
        $yamlContent | Out-File -FilePath $Global:Context.YamlPath -Encoding UTF8 -Force
        [Console]::ForegroundColor = [ConsoleColor]::Green
        [Console]::WriteLine("")
        [Console]::WriteLine(" [OK] Archivo guardado correctamente.")
    } catch {
        [Console]::ForegroundColor = [ConsoleColor]::Red
        [Console]::WriteLine("")
        [Console]::WriteLine(" [ERROR] No se pudo guardar: $_")
    }
    [Console]::ResetColor()
    Start-Sleep 2
    $Global:Context.CurrentState = "ExitApp"
}

# =============================================================================
# 4. MOTOR PRINCIPAL
# =============================================================================
try {
    Initialize-UI
    Load-Config
    while ($Global:Context.CurrentState -ne "ExitApp") {
        if ($Global:Context.CurrentState -eq "State-Port") {
            Invoke-StatePort
        }
        elseif ($Global:Context.CurrentState -eq "State-Board") {
            Invoke-StateBoard
        }
        elseif ($Global:Context.CurrentState -eq "State-Baud") {
            Invoke-StateBaud
        }
        elseif ($Global:Context.CurrentState -eq "State-EOL") {
            Invoke-StateEOL
        }
        elseif ($Global:Context.CurrentState -eq "State-Save") {
            Invoke-StateSave
        }
        else {
            $Global:Context.CurrentState = "ExitApp"
        }
    }
} finally { 
    Reset-UI 
}
