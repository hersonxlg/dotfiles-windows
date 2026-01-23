<#
.SYNOPSIS
    Explorador de Librerías Arduino (TUI con Menús Modales) - v5.1 (Fixed)
.DESCRIPTION
    Correcciones: Navegación Vim en menús, Fix error IF, Limpieza de rastros.
#>

# =============================================================================
# CONFIGURACIÓN INICIAL
# =============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# --- PALETA DE COLORES ---
$Col = @{
    # Base
    Bg          = "Black"       
    Fg          = "White"        
    
    # Lista Principal
    ListSelBg   = "DarkGray"    
    ListSelFg   = "White"       
    ListHi      = "Cyan"        
    
    # Detalles
    Label       = "DarkCyan"    
    Value       = "White"       
    Desc        = "Gray"
    
    # Pestañas
    TabBg       = "Black"
    TabFg       = "DarkGray"
    TabSelBg    = "Cyan"
    TabSelFg    = "Black"

    # Barras Inferiores
    InfoBarBg   = "DarkGray"
    InfoBarFg   = "White"
    StatusBarBg = "Gray"
    StatusBarFg = "Black"
    SearchTag   = "Yellow"

    # --- COLORES PARA MENÚS Y DIÁLOGOS ---
    Border          = "White"
    ModalBorder     = "White"
    ModalBg         = "Black"
    ModalFg         = "White"
    ModalTitle      = "Yellow"
    ModalSelBg      = "Cyan"
    ModalSelFg      = "Black"
    ModalDisabled   = "DarkGray"
    
    # --- COLORES ALERTAS ---
    AlertSuccessBg     = "Black"
    AlertSuccessBorder = "Green"
    AlertErrorBg       = "Black"
    AlertErrorBorder   = "Red"
    AlertFg            = "White"
    AlertBorder        = "White" 
}


# Array con diferentes estilos de bordes
$BoxStyles = @(
    @{
        Name = "Simple"
        H  = "─"; V  = "│"
        TL = "┌"; TR = "┐"
        BL = "└"; BR = "┘"
    },
    @{
        Name = "Double"
        H  = "═"; V  = "║"
        TL = "╔"; TR = "╗"
        BL = "╚"; BR = "╝"
    },
    @{
        Name = "Mixed"
        H  = "═"; V  = "║"
        TL = "╒"; TR = "╕"
        BL = "╘"; BR = "╛"
    },
    @{
        Name = "Heavy"
        H  = "━"; V  = "┃"
        TL = "┏"; TR = "┓"
        BL = "┗"; BR = "┛"
    },
    @{
        Name = "Rounded"
        H  = "─"; V  = "│"
        TL = "╭"; TR = "╮"
        BL = "╰"; BR = "╯"
    },
    @{
        Name = "Solid"
        H  = "█"; V  = "█"
        TL = "█"; TR = "█"
        BL = "█"; BR = "█"
    },
    @{
        Name = "Shaded"
        H  = "▓"; V  = "▓"
        TL = "▓"; TR = "▓"
        BL = "▓"; BR = "▓"
    },
    @{
        Name = "Dashed"
        H  = "╌"; V  = "╎"
        TL = "┌"; TR = "┐"
        BL = "└"; BR = "┘"
    }
)


$Global:BoxChars = $BoxStyles | Where-Object { $_.Name -eq "Rounded" }
$Global:BoxCharsDialogBox = $BoxStyles | Where-Object { $_.Name -eq "Solid" }

# --- VARIABLES DE ESTADO ---
$Script:Running = $true
$Script:Mode = "NAV" 
$Script:SearchQuery = ""
$Script:Cursor = 0
$Script:ScrollOffset = 0
$Script:NeedsRedraw = $true

# Datos
$Script:RawCloud = @()
$Script:RawLocal = @{}
$Script:RawGlobal = @{}
$Script:TabLists = @(@(), @(), @(), @(), @()) 
$Script:CurrentTabIndex = 0
$Script:TabNames = @(" [1] TODO ", " [2] LOCAL ", " [3] GLOBAL ", " [4] AMBOS ", " [5] UPDATES ")
$Script:VisibleLibs = @()

# Vim
$Script:PendingK = $false
$Script:PendingKTime = [DateTime]::MinValue
$Script:VimTimeout = 500 

# =============================================================================
# 1. FUNCIONES BÁSICAS Y TEXTO
# =============================================================================

function Get-WrapText {
    param($Text, $Width)
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    $Text = $Text -replace "`r`n", " " -replace "`n", " "
    $words = $Text -split " "
    $lines = @(); $currentLine = ""
    foreach ($word in $words) {
        if ([string]::IsNullOrWhiteSpace($word)) { continue }
        if ($word.Length -gt $Width) {
            if ($currentLine.Length -gt 0) { $lines += $currentLine; $currentLine = "" }
            $remaining = $word
            while ($remaining.Length -gt $Width) {
                $lines += $remaining.Substring(0, $Width); $remaining = $remaining.Substring($Width)
            }
            $currentLine = $remaining
        } elseif (($currentLine.Length + $word.Length + 1) -le $Width) { 
            if ($currentLine.Length -gt 0) { $currentLine += " " }; $currentLine += "$word" 
        } else { 
            if ($currentLine) { $lines += $currentLine }; $currentLine = "$word" 
        }
    }
    if ($currentLine) { $lines += $currentLine }
    return $lines
}

# Nueva función para limpiar rastros de menús
function Force-Refresh-UI {
    Clear-Host
    $Script:NeedsRedraw = $true
    Draw-UI
}

# =============================================================================
# 2. SISTEMA DE DIÁLOGOS
# =============================================================================


function Draw-Box {
    param(
        [int]$StartX,
        [int]$StartY,
        [int]$Width,
        [int]$Height,
        [ConsoleColor]$Color = "Gray",
        [hashtable]$BoxChars
    )

    # Validar que el objeto tenga las claves necesarias
    if (-not $BoxChars.H -or -not $BoxChars.V -or -not $BoxChars.TL -or -not $BoxChars.TR -or -not $BoxChars.BL -or -not $BoxChars.BR) {
        throw "El objeto de bordes no contiene todas las claves requeridas (H, V, TL, TR, BL, BR)."
    }

    # Línea superior e inferior
    for ($x = 0; $x -lt $Width; $x++) {
        # Superior
        [Console]::SetCursorPosition($StartX + $x, $StartY)
        if ($x -eq 0) { Write-Host $BoxChars.TL -NoNewline -ForegroundColor $Color }
        elseif ($x -eq $Width - 1) { Write-Host $BoxChars.TR -NoNewline -ForegroundColor $Color }
        else { Write-Host $BoxChars.H -NoNewline -ForegroundColor $Color }

        # Inferior
        [Console]::SetCursorPosition($StartX + $x, $StartY + $Height - 1)
        if ($x -eq 0) { Write-Host $BoxChars.BL -NoNewline -ForegroundColor $Color }
        elseif ($x -eq $Width - 1) { Write-Host $BoxChars.BR -NoNewline -ForegroundColor $Color }
        else { Write-Host $BoxChars.H -NoNewline -ForegroundColor $Color }
    }

    # Laterales
    for ($y = 1; $y -lt $Height - 1; $y++) {
        [Console]::SetCursorPosition($StartX, $StartY + $y)
        Write-Host $BoxChars.V -NoNewline -ForegroundColor $Color

        [Console]::SetCursorPosition($StartX + $Width - 1, $StartY + $y)
        Write-Host $BoxChars.V -NoNewline -ForegroundColor $Color
    }
}


function Invoke-StreamProcess {
    param (
        [Parameter(Mandatory)]
        [string] $Executable,

        [string] $Arguments = "",

        [Parameter(Mandatory)]
        [ScriptBlock] $OnData,

        # Estado opcional que se pasa como tercer argumento al callback
        [object] $State = $null
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Executable
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null

    $outBuffer = ""
    $errBuffer = ""

    try {
        # Mientras el proceso está vivo, leer sin bloquear en bloque por bloque
        while (-not $proc.HasExited) {

            while ($proc.StandardOutput.Peek() -ne -1) {
                $ch = [char]$proc.StandardOutput.Read()
                if ($ch -eq "`n") {
                    try {
                        & $OnData "STDOUT" $outBuffer.TrimEnd("`r") $State
                    } catch {
                        # No queremos que un error en el callback pare la recolección
                        Write-Verbose "OnData (STDOUT) error: $($_.Exception.Message)"
                    }
                    $outBuffer = ""
                } else {
                    $outBuffer += $ch
                }
            }

            while ($proc.StandardError.Peek() -ne -1) {
                $ch = [char]$proc.StandardError.Read()
                if ($ch -eq "`n") {
                    try {
                        & $OnData "STDERR" $errBuffer.TrimEnd("`r") $State
                    } catch {
                        Write-Verbose "OnData (STDERR) error: $($_.Exception.Message)"
                    }
                    $errBuffer = ""
                } else {
                    $errBuffer += $ch
                }
            }

            Start-Sleep -Milliseconds 10
        }

        # El proceso terminó: drenar cualquier dato restante en los buffers
        while ($proc.StandardOutput.Peek() -ne -1) {
            $ch = [char]$proc.StandardOutput.Read()
            if ($ch -eq "`n") {
                try {
                    & $OnData "STDOUT" $outBuffer.TrimEnd("`r") $State
                } catch {
                    Write-Verbose "OnData (STDOUT-drain) error: $($_.Exception.Message)"
                }
                $outBuffer = ""
            } else {
                $outBuffer += $ch
            }
        }
        if ($outBuffer.Length -gt 0) {
            try { & $OnData "STDOUT" $outBuffer.TrimEnd("`r") $State } catch {}
            $outBuffer = ""
        }

        while ($proc.StandardError.Peek() -ne -1) {
            $ch = [char]$proc.StandardError.Read()
            if ($ch -eq "`n") {
                try {
                    & $OnData "STDERR" $errBuffer.TrimEnd("`r") $State
                } catch {
                    Write-Verbose "OnData (STDERR-drain) error: $($_.Exception.Message)"
                }
                $errBuffer = ""
            } else {
                $errBuffer += $ch
            }
        }
        if ($errBuffer.Length -gt 0) {
            try { & $OnData "STDERR" $errBuffer.TrimEnd("`r") $State } catch {}
            $errBuffer = ""
        }

    }
    finally {
        if (-not $proc.HasExited) {
            try { $proc.Kill() } catch {}
        }
        $proc.Dispose()
    }
}


function Show-Dialog-Box-install {
    param(
        [Parameter(Mandatory=$true)][string]$Executable,
        [Parameter(Mandatory=$false)][string]$Arguments = "",
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$false)][string[]]$MessageLines,
        [string]$ColorType = "NORMAL",
        [int]$Width= 80,
        [int]$Height= 8,
        [int]$Padding = 3,
        [switch]$AutoSize,
        [switch]$ReturnKey
    )

    # Normalizar entradas
    if (-not $MessageLines) { $MessageLines = @("") }
    $Title = $Title ?? ""
    Write-Output "inicio">log.txt

    # Obtener tamaño consola y asegurar mínimos
    $W = [Console]::WindowWidth
    $H = [Console]::WindowHeight
    if ($W -lt 20 -or $H -lt 5) {
        Write-Host "Consola demasiado pequeña para mostrar el cuadro." -ForegroundColor Yellow
        return $null
    }

    $innerWidth = $Width
    # Calcular ancho dinámico basado en la línea más larga y título
    if($AutoSize) {
        $contentMaxLen = ($MessageLines + $Title).ForEach({ $_.Length }) | 
                        Measure-Object -Maximum | 
                        Select-Object -ExpandProperty Maximum
        $innerWidth = [Math]::Min([Math]::Max($contentMaxLen, 20), [Math]::Min($Width, $W - 4))
    }
    Write-Output 'se crea $innerWidth'>>log.txt
    $BoxW = $innerWidth + ($Padding * 2)
    $BoxW = [Math]::Min($BoxW, $W - 2)

    # Envolver líneas si exceden el ancho interior
    function Wrap-Line($text, $maxLen) {
        if ($text.Length -le $maxLen) { return ,$text }
        $out = @()
        $pos = 0
        while ($pos -lt $text.Length) {
            $len = [Math]::Min($maxLen, $text.Length - $pos)
            $out += $text.Substring($pos, $len).TrimEnd()
            $pos += $len
        }
        return $out
    }

    $innerMax = $BoxW - ($Padding * 2)
    $wrapped = @()
    foreach ($line in $MessageLines) {
        $wrapped += Wrap-Line $line $innerMax
    }

    $BoxH = $Height + 6
    if ($AutoSize){
        $BoxH = $wrapped.Count + 6
    }
    if ($BoxH -gt ($H - 2)) {
        # recortar si no cabe verticalmente
        $available = $H - 6
        if ($available -le 0) {
            Write-Host "No hay espacio vertical suficiente para mostrar el cuadro." -ForegroundColor Yellow
            return $null
        }
        $wrapped = $wrapped[0..($available - 1)]
        $BoxH = $wrapped.Count + 6
    }

    $StartX = [Math]::Max(0, [Math]::Floor(($W - $BoxW) / 2))
    $StartY = [Math]::Max(0, [Math]::Floor(($H - $BoxH) / 2))

    # Colores (asume $Col definido)
    $bg = $Col.ModalBg; $fg = $Col.ModalFg; $borderC = $Col.Border
    if ($ColorType -eq "SUCCESS") { $bg = $Col.AlertSuccessBg; $fg = $Col.AlertFg; $borderC = $Col.AlertSuccessBorder }
    if ($ColorType -eq "ERROR")   { $bg = $Col.AlertErrorBg;   $fg = $Col.AlertFg; $borderC = $Col.AlertErrorBorder }

    try {
        Draw-Box -StartX $StartX -StartY $StartY -Width $BoxW -Height $BoxH -Color $borderC -BoxChars $BoxCharsDialogBox

        # Fondo interno
        for ($y = 1; $y -lt $BoxH - 1; $y++) {
            [Console]::SetCursorPosition($StartX + 1, $StartY + $y)
            Write-Host (" " * ($BoxW - 2)) -NoNewline -BackgroundColor $bg
        }

        # Título
        [Console]::SetCursorPosition($StartX + $Padding, $StartY + 1)
        Write-Host ($Title.ToUpper()) -BackgroundColor $bg -ForegroundColor $Col.ModalTitle

        # Contenido
        for ($i = 0; $i -lt $wrapped.Count; $i++) {
            [Console]::SetCursorPosition($StartX + $Padding, $StartY + 2 + $i)
            $text = $wrapped[$i].PadRight($innerMax)
            Write-Host $text -BackgroundColor $bg -ForegroundColor $fg -NoNewline
        }

        $context = [pscustomobject]@{
            Left   = $StartX
            Top    = $StartY
            Width  = $BoxW
            Height = $BoxH
            Line   = $i
        }
        
        $onData = {
            param($stream, $data, $ctx)
        
            # si ya no cabe, ignorar
            if ($ctx.Line -ge ($ctx.Height - 2)) { return }
        
            $rawLocal = $Host.UI.RawUI
            $innerW = [Math]::Max(0, $ctx.Width - 4)
            $line = [string]$data
            if ($line.Length -gt $innerW) { $line = $line.Substring(0, $innerW) }
        
            $x = [int]($ctx.Left + $Padding)    # usa padding si quieres
            $y = [int]($ctx.Top + 2 + $ctx.Line) # 2 para título + offset
            if ($x -lt 0) { $x = 0 }; if ($y -lt 0) { $y = 0 }
        
            [Console]::SetCursorPosition($x, $y)
            Write-Host ($line.PadRight($innerW)) -NoNewline -BackgroundColor $bg -ForegroundColor $fg
            $ctx.Line++
        }
        

        Write-Output 'Antes de "Invoke-StreamProcess"'>>log.txt

        # LLAMADA BLOQUEANTE — la función no avanzará hasta que termine el proceso
        Invoke-StreamProcess -Executable $Executable `
                             -Arguments $Arguments `
                             -OnData $onData `
                             -State $context

        Write-Output 'Despues de "Invoke-StreamProcess"'>>log.txt

        # luego muestra pie y espera tecla (como ahora)
        #[Console]::SetCursorPosition($StartX + $Padding, $StartY + $BoxH - 2)
        #Write-Host ("Presione cualquier tecla...").PadRight($innerMax) -BackgroundColor $bg -ForegroundColor $Col.ListSelBg
        #$key = [Console]::ReadKey($true)

        # Pie
        [Console]::SetCursorPosition($StartX + $Padding, $StartY + $BoxH - 2)
        Write-Host ("Presione cualquier tecla...").PadRight($innerMax) -BackgroundColor $bg -ForegroundColor $Col.ListSelBg
        $key = [Console]::ReadKey($true)

    } catch {
        Write-Host "Error al dibujar el cuadro: $_" -ForegroundColor Red
        return $null
    } finally {
        Force-Refresh-UI
    }

    if ($ReturnKey) { return $key } else { return $true }
}


function Show-Dialog-Box {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string[]]$MessageLines,
        [string]$ColorType = "NORMAL",
        [int]$MaxWidth = 80,
        [int]$Padding = 3,
        [switch]$ReturnKey
    )

    # Normalizar entradas
    if (-not $MessageLines) { $MessageLines = @("") }
    $Title = $Title ?? ""

    # Obtener tamaño consola y asegurar mínimos
    $W = [Console]::WindowWidth
    $H = [Console]::WindowHeight
    if ($W -lt 20 -or $H -lt 5) {
        Write-Host "Consola demasiado pequeña para mostrar el cuadro." -ForegroundColor Yellow
        return $null
    }

    # Calcular ancho dinámico basado en la línea más larga y título
    $contentMaxLen = ($MessageLines + $Title).ForEach({ $_.Length }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    $innerWidth = [Math]::Min([Math]::Max($contentMaxLen, 20), [Math]::Min($MaxWidth, $W - 4))
    $BoxW = $innerWidth + ($Padding * 2)
    $BoxW = [Math]::Min($BoxW, $W - 2)

    # Envolver líneas si exceden el ancho interior
    function Wrap-Line($text, $maxLen) {
        if ($text.Length -le $maxLen) { return ,$text }
        $out = @()
        $pos = 0
        while ($pos -lt $text.Length) {
            $len = [Math]::Min($maxLen, $text.Length - $pos)
            $out += $text.Substring($pos, $len).TrimEnd()
            $pos += $len
        }
        return $out
    }

    $innerMax = $BoxW - ($Padding * 2)
    $wrapped = @()
    foreach ($line in $MessageLines) {
        $wrapped += Wrap-Line $line $innerMax
    }

    $BoxH = $wrapped.Count + 6
    if ($BoxH -gt ($H - 2)) {
        # recortar si no cabe verticalmente
        $available = $H - 6
        if ($available -le 0) {
            Write-Host "No hay espacio vertical suficiente para mostrar el cuadro." -ForegroundColor Yellow
            return $null
        }
        $wrapped = $wrapped[0..($available - 1)]
        $BoxH = $wrapped.Count + 6
    }

    $StartX = [Math]::Max(0, [Math]::Floor(($W - $BoxW) / 2))
    $StartY = [Math]::Max(0, [Math]::Floor(($H - $BoxH) / 2))

    # Colores (asume $Col definido)
    $bg = $Col.ModalBg; $fg = $Col.ModalFg; $borderC = $Col.Border
    if ($ColorType -eq "SUCCESS") { $bg = $Col.AlertSuccessBg; $fg = $Col.AlertFg; $borderC = $Col.AlertSuccessBorder }
    if ($ColorType -eq "ERROR")   { $bg = $Col.AlertErrorBg;   $fg = $Col.AlertFg; $borderC = $Col.AlertErrorBorder }

    try {
        Draw-Box -StartX $StartX -StartY $StartY -Width $BoxW -Height $BoxH -Color $borderC -BoxChars $BoxCharsDialogBox

        # Fondo interno
        for ($y = 1; $y -lt $BoxH - 1; $y++) {
            [Console]::SetCursorPosition($StartX + 1, $StartY + $y)
            Write-Host (" " * ($BoxW - 2)) -NoNewline -BackgroundColor $bg
        }

        # Título
        [Console]::SetCursorPosition($StartX + $Padding, $StartY + 1)
        Write-Host ($Title.ToUpper()) -BackgroundColor $bg -ForegroundColor $Col.ModalTitle

        # Contenido
        for ($i = 0; $i -lt $wrapped.Count; $i++) {
            [Console]::SetCursorPosition($StartX + $Padding, $StartY + 2 + $i)
            $text = $wrapped[$i].PadRight($innerMax)
            Write-Host $text -BackgroundColor $bg -ForegroundColor $fg -NoNewline
        }

        # Pie
        [Console]::SetCursorPosition($StartX + $Padding, $StartY + $BoxH - 2)
        Write-Host ("Presione cualquier tecla...").PadRight($innerMax) -BackgroundColor $bg -ForegroundColor $Col.ListSelBg

        $key = [Console]::ReadKey($true)
    } catch {
        Write-Host "Error al dibujar el cuadro: $_" -ForegroundColor Red
        return $null
    } finally {
        Force-Refresh-UI
    }

    if ($ReturnKey) { return $key } else { return $true }
}

##  function Show-Dialog-Box {
##      param(
##          [string]$Title,
##          [string[]]$MessageLines,
##          [string]$ColorType = "NORMAL"
##      )
##      
##      $W = [Console]::WindowWidth; $H = [Console]::WindowHeight
##      $BoxW = 60
##      $BoxH = $MessageLines.Count + 6   # +2 extra para el marco
##      $StartX = [Math]::Floor(($W - $BoxW) / 2)
##      $StartY = [Math]::Floor(($H - $BoxH) / 2)
##      
##      $bg = $Col.ModalBg
##      $fg = $Col.ModalFg
##      $borderC = $Col.Border
##      
##      if ($ColorType -eq "SUCCESS") { $bg = $Col.AlertSuccessBg; $fg = $Col.AlertFg; $borderC = $Col.AlertSuccessBorder }
##      if ($ColorType -eq "ERROR")   { $bg = $Col.AlertErrorBg;   $fg = $Col.AlertFg; $borderC = $Col.AlertErrorBorder }
##  
##      # Dibujar marco
##      Draw-Box -StartX $StartX -StartY $StartY -Width $BoxW -Height $BoxH -Color $borderC -BoxChars $BoxCharsDialogBox
##  
##      # Fondo interno
##      for ($y = 1; $y -lt $BoxH - 1; $y++) {
##          [Console]::SetCursorPosition($StartX + 1, $StartY + $y)
##          Write-Host (" " * ($BoxW - 2)) -NoNewline -BackgroundColor $bg
##      }
##  
##      # Título
##      [Console]::SetCursorPosition($StartX + 3, $StartY + 1)
##      Write-Host $Title.ToUpper() -BackgroundColor $bg -ForegroundColor $Col.ModalTitle
##  
##      # Contenido
##      for ($i = 0; $i -lt $MessageLines.Count; $i++) {
##          [Console]::SetCursorPosition($StartX + 3, $StartY + 2 + $i)
##          Write-Host $MessageLines[$i] -BackgroundColor $bg -ForegroundColor $fg
##      }
##      
##      # Pie
##      [Console]::SetCursorPosition($StartX + 3, $StartY + $BoxH - 2)
##      Write-Host "Presione cualquier tecla..." -BackgroundColor $bg -ForegroundColor $Col.ListSelBg
##  
##      [Console]::ReadKey($true) | Out-Null
##      
##      Force-Refresh-UI
##  }


# =============================================================================
# 3. LÓGICA DE INSTALACIÓN (STUBS)
# =============================================================================

function Execute-Install-Or-Downgrade {
    param($LibraryName, $TargetVersion, $Location) 

    $MensajeInicial = @(
        "-----------------------------------",
        "Instalando: $LibraryName",
        "Versión:    $TargetVersion",
        "Destino:    $Location",
        "-----------------------------------"
    )

    if ($Location -eq "local"){
        # 1. Definimos la ruta donde queremos el entorno aislado (usamos ruta absoluta)
        $rutaLocal = Join-Path (Get-Location) "."
        
        # 2. TRUCO DE MAGIA: Cambiamos la variable de entorno ARDUINO_DIRECTORIES_USER
        # Esto le dice a arduino-cli: "Oye, tu carpeta de librerías ahora está AQUÍ"
        $env:ARDUINO_DIRECTORIES_USER = $rutaLocal
        
        # 3. Ahora ejecutamos el install NORMAL (sin flags inventados)
        #arduino-cli lib install "${LibraryName}@${TargetVersion}"
        Show-Dialog-Box-install -Executable "arduino-cli" `
        -Arguments "lib install ${LibraryName}@${TargetVersion}" `
        -Title "INSTALACIÓN LOCAL" `
        -MessageLines $MensajeInicial `
        -ColorType "SUCCESS" `
        -Height 8 `
        -Width 60

        
        # 4. IMPORTANTE: Restaurar la variable (opcional, si quieres seguir usando la global en esta sesión)
        $env:ARDUINO_DIRECTORIES_USER = $null

    }
    elseif ($Location -eq "global"){
        # 4. Ahora ejecutamos el install NORMAL (sin flags inventados)
        #arduino-cli lib install "${LibraryName}@${TargetVersion}"
        
        Show-Dialog-Box-install -Executable "arduino-cli" `
        -Arguments "lib install ${LibraryName}@${TargetVersion}" `
        -Title "INSTALACIÓN LOCAL" `
        -MessageLines $MensajeInicial `
        -ColorType "SUCCESS" `
        -Height 8 `
        -Width 60

    }

    Set-InstalledVersion -Name $LibraryName -Version $TargetVersion -Scope $Location
    Update-Filter
}

function Execute-Uninstall {
    param($LibraryName, $Location)

    $MensajeInicial = @(
        "-----------------------------------",
        "Desinstalando: $LibraryName",
        "Origen:        $Location",
        "-----------------------------------"
    )


    if ($Location -eq "local") {
        # 1. Definimos la ruta donde queremos el entorno aislado (usamos ruta absoluta)
        $rutaLocal = Join-Path (Get-Location) "."
        
        # 2. TRUCO DE MAGIA: Cambiamos la variable de entorno ARDUINO_DIRECTORIES_USER
        # Esto le dice a arduino-cli: "Oye, tu carpeta de librerías ahora está AQUÍ"
        $env:ARDUINO_DIRECTORIES_USER = $rutaLocal
        
        # 3. Ahora ejecutamos el install NORMAL (sin flags inventados)
        #arduino-cli lib install "${LibraryName}@${TargetVersion}"
        Show-Dialog-Box-install -Executable "arduino-cli" `
        -Arguments "lib uninstall `"${LibraryName}`"" `
        -Title "DESINSTALACION LOCAL" `
        -MessageLines $MensajeInicial `
        -ColorType "ERROR" `
        -Height 8 `
        -Width 60
        
        # 4. IMPORTANTE: Restaurar la variable (opcional, si quieres seguir usando la global en esta sesión)
        $env:ARDUINO_DIRECTORIES_USER = $null
    } 
    elseif ($Location -eq "global") {

        Show-Dialog-Box-install -Executable "arduino-cli" `
        -Arguments "lib uninstall `"${LibraryName}`"" `
        -Title "DESINSTALACION GLOBAL" `
        -MessageLines $MensajeInicial `
        -ColorType "ERROR" `
        -Height 8 `
        -Width 60

    }

    Remove-Installed -Name $LibraryName -Scope $Location
    Update-Filter
    
}

# =============================================================================
# 4. MENÚS FLOTANTES
# =============================================================================

function Show-Version-Selector {
    param($LibData, $CurrentVersion, $ActionType, $Location = "global") 
    
    $versions = @()
    if ($LibData.releases) {
        $vKeys = $LibData.releases.PSObject.Properties.Name
        $versions = $vKeys | Select-Object @{N='V';E={[version]($_ -replace '[^0-9\.]','')}} | Sort-Object V -Descending | ForEach-Object { $_.V.ToString() }
    } else {
        $versions = @("Latest")
    }

    $W = [Console]::WindowWidth; $H = [Console]::WindowHeight
    $MenuW = 40
    $MenuH = 15 
    if ($versions.Count + 4 -lt $MenuH) { $MenuH = $versions.Count + 4 }
    
    $StartX = [Math]::Floor(($W - $MenuW) / 2)
    $StartY = [Math]::Floor(($H - $MenuH) / 2)
    
    $vCursor = 0
    $vOffset = 0
    $idx = $versions.IndexOf($CurrentVersion)
    if ($idx -ge 0) { $vCursor = $idx }
    
    # Dibujar marco una sola vez
    Draw-Box -StartX $StartX -StartY $StartY -Width $MenuW -Height $MenuH -Color $Col.ModalFg -BoxChars $BoxChars

    # Dibujar fondo interno una sola vez
    for ($y = 1; $y -lt $MenuH - 1; $y++) {
        [Console]::SetCursorPosition($StartX + 1, $StartY + $y)
        Write-Host (" " * ($MenuW - 2)) -NoNewline -BackgroundColor $Col.ModalBg
    }

    # Dibujar título una sola vez
    [Console]::SetCursorPosition($StartX + 2, $StartY + 1)
    Write-Host "SELECCIONAR VERSION ($ActionType)" -BackgroundColor $Col.ModalBg -ForegroundColor $Col.ModalTitle
    
    $selecting = $true
    while ($selecting) {
        # Solo redibujar la lista
        $listSpace = $MenuH - 3
        if ($vCursor -ge $vOffset + $listSpace) { $vOffset = $vCursor - $listSpace + 1 }
        if ($vCursor -lt $vOffset) { $vOffset = $vCursor }

        for ($i = 0; $i -lt $listSpace; $i++) {
            $dataIdx = $vOffset + $i
            [Console]::SetCursorPosition($StartX + 2, $StartY + 2 + $i)
            
            if ($dataIdx -lt $versions.Count) {
                $ver = $versions[$dataIdx]
                $mk = "  "
                if ($ver -eq $CurrentVersion) { $mk = "* " }
                
                if ($dataIdx -eq $vCursor) {
                    Write-Host "$mk$ver".PadRight($MenuW - 3) -BackgroundColor $Col.ModalSelBg -ForegroundColor $Col.ModalSelFg
                } else {
                    Write-Host "$mk$ver".PadRight($MenuW - 3) -BackgroundColor $Col.ModalBg -ForegroundColor $Col.ModalFg
                }
            } else {
                # Limpiar línea si no hay versión
                Write-Host (" " * ($MenuW - 3)) -NoNewline -BackgroundColor $Col.ModalBg
            }
        }

        $k = [Console]::ReadKey($true)
        if ($k.Key -eq "UpArrow" -or $k.KeyChar -eq 'k') { if ($vCursor -gt 0) { $vCursor-- } }
        elseif ($k.Key -eq "DownArrow" -or $k.KeyChar -eq 'j') { if ($vCursor -lt $versions.Count - 1) { $vCursor++ } }
        elseif ($k.Key -eq "Escape" -or $k.KeyChar -eq 'q') { $selecting = $false }
        elseif ($k.Key -eq "Enter") { 
            $selecting = $false
            Execute-Install-Or-Downgrade -LibraryName $LibData.name -TargetVersion $versions[$vCursor] -Location $Location
        }
    }
    
    Force-Refresh-UI
}


function Show-Action-Menu {
    param($Lib)
    
    $options = @()
    $isGlobal = ($Lib.InstallStatus -eq "GLOBAL" -or $Lib.InstallStatus -eq "BOTH")
    $isLocal  = ($Lib.InstallStatus -eq "LOCAL"  -or $Lib.InstallStatus -eq "BOTH")

    if (-not $isLocal) {
        $options += @{ 
            Label="Instalar [Local]";
            Action="INSTALL";
            Location="local" 
        } 
    }
    if (-not $isGlobal) {
        $options += @{
            Label="Instalar [Global]";
            Action="INSTALL";
            Location="global" 
        } 
    }
    if ($isLocal)  {
        $options += @{
            Label="Cambiar Versión [Local]";
            Action="CHANGE";
            Location="local";
            CurrentVer=$Script:RawLocal[$Lib.Name] 
        }
    }
    if ($isGlobal) {
        $options += @{
            Label="Cambiar Versión [Global]";
            Action="CHANGE";
            Location="global";
            CurrentVer=$Script:RawGlobal[$Lib.Name]
        }
    }
    if ($isLocal)  {
        $options += @{
            Label="Desinstalar [Local]";
            Action="UNINSTALL";
            Location="local"
        }
    }
    if ($isGlobal) {
        $options += @{
            Label="Desinstalar [Global]";
            Action="UNINSTALL";
            Location="global"
        }
    }
    
    if ($options.Count -eq 0) { return }

    $W = [Console]::WindowWidth; $H = [Console]::WindowHeight
    $MenuW = 40
    $MenuH = $options.Count + 4
    $StartX = [Math]::Floor(($W - $MenuW) / 2)
    $StartY = [Math]::Floor(($H - $MenuH) / 2)
    $mCursor = 0

    # Dibujar marco una sola vez
    Draw-Box -StartX $StartX -StartY $StartY -Width $MenuW -Height $MenuH -Color $Col.ModalFg -BoxChars $BoxChars

    # Dibujar fondo interno una sola vez
    for ($y = 1; $y -lt $MenuH - 1; $y++) {
        [Console]::SetCursorPosition($StartX + 1, $StartY + $y)
        Write-Host (" " * ($MenuW - 2)) -NoNewline -BackgroundColor $Col.ModalBg
    }

    # Dibujar título una sola vez
    [Console]::SetCursorPosition($StartX + 2, $StartY + 1)
    Write-Host "ACCIONES: $($Lib.Name)" -BackgroundColor $Col.ModalBg -ForegroundColor $Col.ModalTitle

    $inMenu = $true
    while ($inMenu) {
        # Solo redibujar las opciones
        for ($i = 0; $i -lt $options.Count; $i++) {
            [Console]::SetCursorPosition($StartX + 2, $StartY + 2 + $i)
            $opt = $options[$i]
            if ($i -eq $mCursor) {
                Write-Host (" " + $opt.Label).PadRight($MenuW - 3) -BackgroundColor $Col.ModalSelBg -ForegroundColor $Col.ModalSelFg
            } else {
                Write-Host (" " + $opt.Label).PadRight($MenuW - 3) -BackgroundColor $Col.ModalBg -ForegroundColor $Col.ModalFg
            }
        }

        $k = [Console]::ReadKey($true)
        if ($k.Key -eq "UpArrow" -or $k.KeyChar -eq 'k') { if ($mCursor -gt 0) { $mCursor-- } }
        elseif ($k.Key -eq "DownArrow" -or $k.KeyChar -eq 'j') { if ($mCursor -lt $options.Count - 1) { $mCursor++ } }
        elseif ($k.Key -eq "Escape" -or $k.KeyChar -eq 'q') { $inMenu = $false }
        elseif ($k.Key -eq "Enter") {
            $inMenu = $false
            $sel = $options[$mCursor]
            
            if ($sel.Action -eq "INSTALL" -or $sel.Action -eq "CHANGE") {
                $rawLib = $Script:RawCloud | Where-Object { $_.name -eq $Lib.Name } | Select-Object -First 1
                if ($rawLib) {
                    Show-Version-Selector -LibData $rawLib -CurrentVersion $sel.CurrentVer -ActionType $sel.Action -Location $sel.Location
                } else {
                    Show-Dialog-Box "Error" @("No se encontraron datos remotos.") "ERROR"
                }
            }
            elseif ($sel.Action -eq "UNINSTALL") {
                Execute-Uninstall -LibraryName $Lib.Name -Location $sel.Location
            }
        }
    }
    Force-Refresh-UI
}


# =============================================================================
# 5. CARGA DE DATOS
# =============================================================================

function Update-Raw-Global {
    $Script:RawGlobal = @{}
    try {
        $json = arduino-cli lib list --format json | ConvertFrom-Json
        if ($json -and $json.installed_libraries) {
            foreach ($item in $json.installed_libraries) { $Script:RawGlobal[$item.library.name] = $item.library.version }
        }
    } catch { }
}

function Update-Raw-Local {
    $Script:RawLocal = @{}
    $localPath = Join-Path (Get-Location) "libraries"
    if (Test-Path $localPath) {
        $dirs = Get-ChildItem -Path $localPath -Directory
        foreach ($d in $dirs) {
            $propFile = Join-Path $d.FullName "library.properties"
            if (Test-Path $propFile) {
                $content = Get-Content $propFile -Raw
                $nameMatch = [regex]::Match($content, "(?m)^name=(.*)$")
                $verMatch  = [regex]::Match($content, "(?m)^version=(.*)$")
                if ($nameMatch.Success -and $verMatch.Success) {
                    $Script:RawLocal[$nameMatch.Groups[1].Value.Trim()] = $verMatch.Groups[1].Value.Trim()
                }
            }
        }
    }
}

function Update-Raw-Cloud {
    Write-Host "   Descargando índice de la nube (arduino-cli)..." -ForegroundColor Gray
    try {
        if (-not (Get-Command "arduino-cli" -ErrorAction SilentlyContinue)) { throw "Falta arduino-cli" }
        $jsonRaw = arduino-cli lib search --format json | Out-String
        $data = $jsonRaw | ConvertFrom-Json
        if ($data.libraries) { $Script:RawCloud = $data.libraries }
    } catch { Write-Error $_; Read-Host "Error fatal. Enter para salir..."; exit }
}



function Build-Tabs {
    $MasterList = $Script:RawCloud | ForEach-Object {
        $lib = $_
        $bestVerStr = "0.0.0"
        $releaseData = $null
        if ($lib.releases) {
            $allVerKeys = $lib.releases.PSObject.Properties.Name
            try {
                $sortedVers = $allVerKeys | Select-Object @{N='V';E={[version]($_ -replace '[^0-9\.]','')}} | Sort-Object V -Descending
                if ($sortedVers) { $bestVerStr = $sortedVers[0].V.ToString() }
            } catch { $bestVerStr = $allVerKeys | Select-Object -Last 1 }
            try { if ($bestVerStr) { $releaseData = $lib.releases.$bestVerStr } } catch {}
        }

        $author = if ($releaseData -and $releaseData.author) { $releaseData.author } elseif ($lib.author) { $lib.author } else { "?" }
        $web    = if ($releaseData -and $releaseData.url) { $releaseData.url } elseif ($lib.website) { $lib.website } else { "" }
        $sent   = if ($releaseData -and $releaseData.sentence) { $releaseData.sentence } elseif ($lib.sentence) { $lib.sentence } else { "" }
        $cat    = if ($releaseData -and $releaseData.category) { $releaseData.category } elseif ($lib.category) { $lib.category } else { "General" }

        $verGlobal = $Script:RawGlobal[$lib.name]
        $verLocal  = $Script:RawLocal[$lib.name]
        
        $statusTag = "NONE"
        $instInfo  = "No instalada"
        $canUpdate = $false
        
        $IsNewer = { param($vCloud, $vInst) try { return [version]($vCloud -replace '[^0-9\.]','') -gt [version]($vInst -replace '[^0-9\.]','') } catch { return $false } }

        if ($verGlobal -and $verLocal) {
            $statusTag = "BOTH"
            $instInfo = "G: v$verGlobal | L: v$verLocal"
            if ((&$IsNewer $bestVerStr $verGlobal) -or (&$IsNewer $bestVerStr $verLocal)) { $canUpdate = $true }
        } elseif ($verGlobal) {
            $statusTag = "GLOBAL"
            $instInfo = "Global (v$verGlobal)"
            if (&$IsNewer $bestVerStr $verGlobal) { $canUpdate = $true }
        } elseif ($verLocal) {
            $statusTag = "LOCAL"
            $instInfo = "Local (v$verLocal)"
            if (&$IsNewer $bestVerStr $verLocal) { $canUpdate = $true }
        }

        [PSCustomObject]@{
            Name = $lib.name; Author = $author; Sentence = $sent; Website = $web; Category = $cat
            Latest = $bestVerStr; InstallStatus = $statusTag; InstallInfo = $instInfo; CanUpdate = $canUpdate
            SearchText = ($lib.name + " " + $sent + " " + $cat + " " + $author).ToLower()
        }
    }

    $Script:TabLists[0] = @($MasterList)
    $Script:TabLists[1] = @($MasterList | Where-Object { $_.InstallStatus -eq "LOCAL" -or $_.InstallStatus -eq "BOTH" })
    $Script:TabLists[2] = @($MasterList | Where-Object { $_.InstallStatus -eq "GLOBAL" -or $_.InstallStatus -eq "BOTH" })
    $Script:TabLists[3] = @($MasterList | Where-Object { $_.InstallStatus -eq "BOTH" })
    $Script:TabLists[4] = @($MasterList | Where-Object { $_.CanUpdate -eq $true })
}

function Set-InstalledVersion {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet("GLOBAL", "LOCAL")]
        [string]$Scope,

        [Parameter(Mandatory=$true)]
        [string]$Version
    )

    # 1. Actualizar los diccionarios Raw (Persistencia en memoria)
    if ($Scope -eq "GLOBAL") {
        $Script:RawGlobal[$Name] = $Version
    } else {
        $Script:RawLocal[$Name] = $Version
    }

    # 2. Buscar el objeto en la Lista Maestra
    $libObj = $Script:TabLists[0] | Where-Object { $_.Name -eq $Name }
    
    if ($libObj) {
        # 3. Recalcular Estado
        # Obtenemos las versiones actuales de los diccionarios
        $verGlobal = $Script:RawGlobal[$Name]
        $verLocal  = $Script:RawLocal[$Name]
        $bestVerStr = $libObj.Latest

        # Lógica de comparación de versiones (igual que en Build-Tabs)
        $IsNewer = { param($vCloud, $vInst) try { return [version]($vCloud -replace '[^0-9\.]','') -gt [version]($vInst -replace '[^0-9\.]','') } catch { return $false } }

        # Determinar nuevo Status e Info
        if ($verGlobal -and $verLocal) {
            $libObj.InstallStatus = "BOTH"
            $libObj.InstallInfo   = "G: v$verGlobal | L: v$verLocal"
            # Actualizable si la nube es mayor a la local O a la global
            $libObj.CanUpdate     = (& $IsNewer $bestVerStr $verGlobal) -or (& $IsNewer $bestVerStr $verLocal)
        }
        elseif ($verGlobal) {
            $libObj.InstallStatus = "GLOBAL"
            $libObj.InstallInfo   = "Global (v$verGlobal)"
            $libObj.CanUpdate     = (& $IsNewer $bestVerStr $verGlobal)
        }
        elseif ($verLocal) {
            $libObj.InstallStatus = "LOCAL"
            $libObj.InstallInfo   = "Local (v$verLocal)"
            $libObj.CanUpdate     = (& $IsNewer $bestVerStr $verLocal)
        }

        # 4. Regenerar las sub-listas (Filtrado rápido)
        Update-TabLists
        Write-Host "Librería '$Name' actualizada a v$Version en $Scope." -ForegroundColor Cyan
    } else {
        Write-Warning "No se encontró la librería '$Name' en la lista maestra."
    }
}

function Remove-Installed {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet("GLOBAL", "LOCAL")]
        [string]$Scope
    )

    # 1. Eliminar del diccionario Raw correspondiente
    if ($Scope -eq "GLOBAL") {
        if ($Script:RawGlobal.ContainsKey($Name)) { $Script:RawGlobal.Remove($Name) }
    } else {
        if ($Script:RawLocal.ContainsKey($Name)) { $Script:RawLocal.Remove($Name) }
    }

    # 2. Buscar el objeto en la Lista Maestra
    $libObj = $Script:TabLists[0] | Where-Object { $_.Name -eq $Name }

    if ($libObj) {
        # 3. Recalcular Estado con los datos restantes
        $verGlobal = $Script:RawGlobal[$Name]
        $verLocal  = $Script:RawLocal[$Name]
        $bestVerStr = $libObj.Latest
        
        $IsNewer = { param($vCloud, $vInst) try { return [version]($vCloud -replace '[^0-9\.]','') -gt [version]($vInst -replace '[^0-9\.]','') } catch { return $false } }

        if ($verGlobal -and $verLocal) {
            # Esto pasa si borraste una, pero aún queda la otra (ej. borras Local, queda Global)
            # Nota: Este caso es raro en "Remove", pero posible si la lógica falla, lo manejamos igual que Set
            $libObj.InstallStatus = "BOTH"
            $libObj.InstallInfo   = "G: v$verGlobal | L: v$verLocal"
            $libObj.CanUpdate     = (& $IsNewer $bestVerStr $verGlobal) -or (& $IsNewer $bestVerStr $verLocal)
        }
        elseif ($verGlobal) {
            # Se borró la local, queda la Global
            $libObj.InstallStatus = "GLOBAL"
            $libObj.InstallInfo   = "Global (v$verGlobal)"
            $libObj.CanUpdate     = (& $IsNewer $bestVerStr $verGlobal)
        }
        elseif ($verLocal) {
            # Se borró la Global, queda la Local
            $libObj.InstallStatus = "LOCAL"
            $libObj.InstallInfo   = "Local (v$verLocal)"
            $libObj.CanUpdate     = (& $IsNewer $bestVerStr $verLocal)
        }
        else {
            # No queda ninguna (Estado NONE)
            $libObj.InstallStatus = "NONE"
            $libObj.InstallInfo   = "No instalada"
            $libObj.CanUpdate     = $false
        }

        # 4. Regenerar las sub-listas
        Update-TabLists
        Write-Host "Librería '$Name' eliminada de $Scope." -ForegroundColor Yellow
    } else {
        Write-Warning "No se encontró la librería '$Name' para desinstalar."
    }
}

# Función auxiliar interna para no repetir código de filtrado
function Update-TabLists {
    # Re-filtra las listas basadas en los cambios hechos en la MasterList (Index 0)
    $Script:TabLists[1] = @($Script:TabLists[0] | Where-Object { $_.InstallStatus -eq "LOCAL" -or $_.InstallStatus -eq "BOTH" })
    $Script:TabLists[2] = @($Script:TabLists[0] | Where-Object { $_.InstallStatus -eq "GLOBAL" -or $_.InstallStatus -eq "BOTH" })
    $Script:TabLists[3] = @($Script:TabLists[0] | Where-Object { $_.InstallStatus -eq "BOTH" })
    $Script:TabLists[4] = @($Script:TabLists[0] | Where-Object { $_.CanUpdate -eq $true })
}

function Load-Full-System {
    Clear-Host
    Write-Host "`n   [ INICIALIZANDO ]" -ForegroundColor Cyan
    Update-Raw-Global; Update-Raw-Local; Update-Raw-Cloud; Build-Tabs; Update-Filter
}

function Update-Filter {
    $currentList = $Script:TabLists[$Script:CurrentTabIndex]
    if ([string]::IsNullOrWhiteSpace($Script:SearchQuery)) { $Script:VisibleLibs = @($currentList) } 
    else {
        $terms = $Script:SearchQuery.ToLower() -split "\s+" | Where-Object { $_ }
        $Script:VisibleLibs = @($currentList | Where-Object {
            $item = $_; $match = $true
            foreach ($t in $terms) { if (-not $item.SearchText.Contains($t)) { $match = $false; break } }
            $match
        })
    }
    $Script:Cursor = 0; $Script:ScrollOffset = 0; $Script:NeedsRedraw = $true
}

# =============================================================================
# 6. RENDERIZADO (UI BASE)
# =============================================================================

function Draw-UI {
    if (-not $Script:NeedsRedraw) { return }
    $W = [Console]::WindowWidth; $H = [Console]::WindowHeight
    $SplitX = [Math]::Floor($W * 0.45) 
    $ListH = $H - 4 

    [Console]::CursorVisible = $false

    # Tabs
    [Console]::SetCursorPosition(0, 0)
    for ($i = 0; $i -lt $Script:TabNames.Count; $i++) {
        $name = $Script:TabNames[$i]
        $count = $Script:TabLists[$i].Count
        if ($i -eq $Script:CurrentTabIndex) { Write-Host "$name($count)" -NoNewline -BackgroundColor $Col.TabSelBg -ForegroundColor $Col.TabSelFg } 
        else { Write-Host "$name($count)" -NoNewline -BackgroundColor $Col.TabBg -ForegroundColor $Col.TabFg }
        Write-Host " " -NoNewline -BackgroundColor $Col.Bg
    }
    $currentX = [Console]::CursorLeft; if ($currentX -lt $W) { Write-Host (" " * ($W - $currentX)) -NoNewline -BackgroundColor $Col.Bg }
    [Console]::SetCursorPosition(0, 1); Write-Host ("─" * $W) -ForegroundColor DarkGray

    # Lista
    if ($Script:Cursor -ge $Script:ScrollOffset + $ListH) { $Script:ScrollOffset = $Script:Cursor - $ListH + 1 }
    if ($Script:Cursor -lt $Script:ScrollOffset) { $Script:ScrollOffset = $Script:Cursor }

    for ($y = 0; $y -lt $ListH; $y++) {
        $dataIdx = $Script:ScrollOffset + $y
        [Console]::SetCursorPosition(0, $y + 2)
        
        if ($dataIdx -lt $Script:VisibleLibs.Count) {
            $lib = $Script:VisibleLibs[$dataIdx]
            $isSelected = ($dataIdx -eq $Script:Cursor)
            $nameStr = $lib.Name; if ($nameStr.Length -gt ($SplitX - 5)) { $nameStr = $nameStr.Substring(0, $SplitX - 5) + ".." }
            $icon = "   "; $fgColor = $Col.Fg
            if ($lib.CanUpdate) { $icon = " ▲ "; $fgColor = "Magenta" }
            elseif ($lib.InstallStatus -ne "NONE") { switch ($lib.InstallStatus) { "GLOBAL"{$icon=" G "}; "LOCAL"{$icon=" L "}; "BOTH"{$icon=" B "} }; $fgColor = "Cyan" }

            if ($isSelected) {
                Write-Host " ▌$icon" -NoNewline -BackgroundColor $Col.ListSelBg -ForegroundColor $Col.Value
                Write-Host "$nameStr".PadRight($SplitX - 5) -NoNewline -BackgroundColor $Col.ListSelBg -ForegroundColor $Col.ListSelFg
            } else {
                Write-Host "$icon" -NoNewline -BackgroundColor $Col.Bg -ForegroundColor $fgColor
                Write-Host "$nameStr".PadRight($SplitX - 3) -NoNewline -BackgroundColor $Col.Bg -ForegroundColor $Col.Fg
            }
        } else { Write-Host (" " * $SplitX) -NoNewline -BackgroundColor $Col.Bg }
        Write-Host "│" -NoNewline -ForegroundColor DarkGray
    }

    # Detalle
    $DetailW = $W - $SplitX - 2
    for($i=0; $i -lt $ListH; $i++) { [Console]::SetCursorPosition($SplitX + 2, $i + 2); Write-Host (" " * $DetailW) -NoNewline }
    
    if ($Script:VisibleLibs.Count -gt 0) {
        $selLib = $Script:VisibleLibs[$Script:Cursor]
        $uiState = @{ Y = 2 }
        [Console]::SetCursorPosition($SplitX + 2, $uiState.Y); Write-Host $selLib.Name -ForegroundColor Cyan; $uiState.Y++; 
        [Console]::SetCursorPosition($SplitX + 2, $uiState.Y); Write-Host ("=" * ($selLib.Name.Length)) -ForegroundColor DarkGray; $uiState.Y += 2

        $printField = { param($lbl, $val, $valColor) 
            $lines = @(Get-WrapText $val ($DetailW - 12))
            if ($lines.Count -eq 0) { return }
            foreach ($l in $lines) { if ($uiState.Y -lt ($ListH + 2)) {
                [Console]::SetCursorPosition($SplitX + 2, $uiState.Y)
                if ($l -eq $lines[0]) { Write-Host $lbl.PadRight(12) -NoNewline -ForegroundColor $Col.Label } else { Write-Host (" " * 12) -NoNewline }
                Write-Host $l.PadRight($DetailW - 12) -NoNewline -ForegroundColor $valColor
                $uiState.Y++
            }}
        }
        &$printField "AUTOR:" $selLib.Author $Col.Value
        &$printField "VERSION:" $selLib.Latest $Col.Value
        &$printField "WEB:" $selLib.Website $Col.Value
        $stColor = "DarkGray"; if ($selLib.InstallStatus -ne "NONE") { $stColor = "Green" }; if ($selLib.CanUpdate) { $stColor = "Magenta" }
        &$printField "ESTADO:" $selLib.InstallInfo $stColor
        $uiState.Y++; if ($uiState.Y -lt ($ListH + 2)) { [Console]::SetCursorPosition($SplitX + 2, $uiState.Y); Write-Host "DESCRIPCIÓN:" -ForegroundColor $Col.Label; $uiState.Y++ }
        $descLines = @(Get-WrapText ($selLib.Sentence) $DetailW)
        foreach ($l in $descLines) { if ($uiState.Y -ge ($ListH + 2)) { break }; [Console]::SetCursorPosition($SplitX + 2, $uiState.Y); Write-Host $l -ForegroundColor $Col.Desc; $uiState.Y++ }
    } else { [Console]::SetCursorPosition($SplitX + 2, 5); Write-Host "Lista Vacía." -ForegroundColor Red }

    # Barras Inferiores
    [Console]::SetCursorPosition(0, $H - 2)
    if ($Script:Mode -eq "SEARCH") {
        Write-Host " BUSCAR: " -NoNewline -BackgroundColor $Col.SearchTag -ForegroundColor Black
        Write-Host " $Script:SearchQuery" -NoNewline -BackgroundColor $Col.Bg -ForegroundColor White
        # CORRECCIÓN: Sintaxis de IF dentro de paréntesis usando $()
        Write-Host $(if ($Script:PendingK) { "k_" } else { "_" }) -NoNewline -BackgroundColor $Col.Bg -ForegroundColor White
        $fill = $W - 9 - $Script:SearchQuery.Length - 2; if ($fill -gt 0) { Write-Host (" " * $fill) -NoNewline -BackgroundColor $Col.InfoBarBg }
    } else {
        $infoText = " FILTRO: " + $Script:TabNames[$Script:CurrentTabIndex].Trim() + " | ITEMS: " + $Script:VisibleLibs.Count; if ($Script:SearchQuery) { $infoText += " | Q: '$Script:SearchQuery'" }
        Write-Host $infoText.PadRight($W) -NoNewline -BackgroundColor $Col.InfoBarBg -ForegroundColor $Col.InfoBarFg
    }
    [Console]::SetCursorPosition(0, $H - 1)
    #Write-Host " ARDUINO MANAGER v5.1 " -NoNewline -BackgroundColor $Col.StatusBarBg -ForegroundColor $Col.StatusBarFg
    Write-Host (" " * ($W - 47)) -NoNewline -BackgroundColor $Col.StatusBarBg
    Write-Host " [Enter] Acciones | [n/p] Tabs | [/] Buscar " -NoNewline -BackgroundColor $Col.StatusBarBg -ForegroundColor $Col.StatusBarFg

    $Script:NeedsRedraw = $false
}

# =============================================================================
# 7. BUCLE PRINCIPAL
# =============================================================================

Load-Full-System

try {
    [Console]::CursorVisible = $false
    while ($Script:Running) {
        if ($Script:PendingK -and ([DateTime]::Now - $Script:PendingKTime).TotalMilliseconds -gt $Script:VimTimeout) {
            $Script:SearchQuery += "k"; $Script:PendingK = $false; Update-Filter
        }
        Draw-UI
        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true); $key = $keyInfo.Key; $char = $keyInfo.KeyChar
            if ($Script:Mode -eq "SEARCH") {
                if ($Script:PendingK) { if ($char -eq 'j') { $Script:PendingK = $false; $Script:Mode = "NAV"; $Script:NeedsRedraw = $true; continue } else { $Script:SearchQuery += "k"; $Script:PendingK = $false } }
                if ($key -eq "Enter" -or $key -eq "Escape") { $Script:Mode = "NAV"; $Script:PendingK = $false; $Script:NeedsRedraw = $true }
                elseif ($key -eq "Backspace") { if ($Script:SearchQuery.Length -gt 0) { $Script:SearchQuery = $Script:SearchQuery.Substring(0, $Script:SearchQuery.Length - 1); Update-Filter } }
                elseif (-not [char]::IsControl($char)) { if ($char -eq 'k') { $Script:PendingK = $true; $Script:PendingKTime = [DateTime]::Now } else { $Script:SearchQuery += $char; Update-Filter } }
            } else {
                $Script:NeedsRedraw = $true
                switch ($char) {
                    'n' { $Script:CurrentTabIndex = ($Script:CurrentTabIndex + 1) % 5; Update-Filter }
                    'p' { $Script:CurrentTabIndex = ($Script:CurrentTabIndex - 1 + 5) % 5; Update-Filter }
                    '/' { $Script:Mode = "SEARCH"; Update-Filter }
                    'q' { $Script:Running = $false }
                    'j' { if ($Script:Cursor -lt $Script:VisibleLibs.Count - 1) { $Script:Cursor++ } }
                    'k' { if ($Script:Cursor -gt 0) { $Script:Cursor-- } }
                }
                if ($key -eq "DownArrow") { if ($Script:Cursor -lt $Script:VisibleLibs.Count - 1) { $Script:Cursor++ } }
                elseif ($key -eq "UpArrow") { if ($Script:Cursor -gt 0) { $Script:Cursor-- } }
                
                elseif ($key -eq "Enter") {
                    if ($Script:VisibleLibs.Count -gt 0) {
                        Show-Action-Menu -Lib $Script:VisibleLibs[$Script:Cursor]
                    }
                }
            }
        }
        Start-Sleep -Milliseconds 20
    }
} finally { [Console]::CursorVisible = $true; Clear-Host; Write-Host "Bye." }
