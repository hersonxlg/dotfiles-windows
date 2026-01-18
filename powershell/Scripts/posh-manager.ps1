# ==============================================================================
#  OH-MY-POSH THEME MANAGER (V37 - ULTIMATE PORTABLE)
# ==============================================================================

# --- 0. FASE DE INSTALACIÓN Y VERIFICACIÓN ---
$OmpExe = "oh-my-posh"

function Refresh-Environment {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Verificación de Ejecutable
if (-not (Get-Command $OmpExe -ErrorAction SilentlyContinue)) {
    Clear-Host
    Write-Host "`n  [!] OH-MY-POSH NO ESTÁ INSTALADO." -ForegroundColor Red -BackgroundColor Black
    
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-Host "`n  [i] Se detectó Winget en el sistema." -ForegroundColor Cyan
        Write-Host "  [?] ¿Deseas instalar Oh-My-Posh automáticamente? (S/N): " -ForegroundColor Yellow -NoNewline
        
        $InputKey = [Console]::ReadKey($true)
        if ($InputKey.Key -eq 'S') {
            Write-Host "S`n" -ForegroundColor Green
            Write-Host "  [...] Instalando..." -ForegroundColor Gray
            try {
                winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
                Write-Host "`n  [...] Verificando..." -ForegroundColor Gray
                Refresh-Environment
                
                $PossibleExe = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\oh-my-posh.exe"
                if (Test-Path $PossibleExe) { $OmpExe = $PossibleExe }
                
                if (Get-Command $OmpExe -ErrorAction SilentlyContinue) {
                    Write-Host "  [V] INSTALACIÓN CORRECTA." -ForegroundColor Green
                    Start-Sleep -Seconds 1
                } else { throw "No se pudo localizar el ejecutable." }
            } catch {
                Write-Host "`n  [X] Error crítico: $_" -ForegroundColor Red; exit
            }
        } else {
            Write-Host "N`n  [!] Cancelado." -ForegroundColor Red; exit
        }
    } else {
        Write-Host "`n  [X] No tienes Winget. Instala Oh-My-Posh manualmente." -ForegroundColor Red; exit
    }
}

# --- 1. MOTOR DE RASTREO (SOLO VARIABLES DE ENTORNO) ---
$UserThemesDir = Join-Path $env:USERPROFILE ".oh-my-posh\themes"

$PossiblePaths = @(
    $env:POSH_THEMES_PATH,
    $UserThemesDir,
    (Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes"),
    (Join-Path $env:ProgramFiles "oh-my-posh\themes"),
    (Join-Path $env:LOCALAPPDATA "oh-my-posh\themes")
)

$ThemesPath = $null
foreach ($path in $PossiblePaths) {
    if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path (Join-Path $path "*.omp.json"))) {
        $ThemesPath = $path
        $env:POSH_THEMES_PATH = $path
        break
    }
}

# --- 2. AUTO-REPARACIÓN (Descarga en perfil de usuario) ---
if ($null -eq $ThemesPath) {
    Clear-Host
    Write-Host "`n  [!] FALTAN LOS TEMAS." -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "  [i] Descargando paquete oficial..." -ForegroundColor Cyan
    
    if (!(Test-Path $UserThemesDir)) { New-Item -ItemType Directory -Path $UserThemesDir -Force | Out-Null }
    
    $ZipUrl = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip"
    $ZipFile = Join-Path $UserThemesDir "themes.zip"
    
    try {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipFile -UseBasicParsing
        Expand-Archive -Path $ZipFile -DestinationPath $UserThemesDir -Force
        Remove-Item $ZipFile -Force
        $ThemesPath = $UserThemesDir
        $env:POSH_THEMES_PATH = $UserThemesDir
        Write-Host "  [V] ¡Temas listos!" -ForegroundColor Green
        Start-Sleep -Seconds 1
    } catch {
        Write-Host "`n  [X] Error de red: $_" -ForegroundColor Red; exit
    }
}

try { $ExeReal = (Get-Command "oh-my-posh").Source } 
catch { $ExeReal = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\oh-my-posh.exe" }

$TempFile = ".\temp_preview.json"
$Themes = Get-ChildItem -Path (Join-Path $ThemesPath "*.omp.json") | Sort-Object Name
if ($Themes.Count -eq 0) { Write-Error "Carpeta vacía."; return }
$env:POSH_THEME = $null

# --- CONFIGURACIÓN VISUAL ---
$ListHeight = 12; $PreviewHeight = 5; $ScrollPadding = 2
$Running = $true; $Selection = 0; $ScrollStart = 0; $InputBuffer = ""

# PALETA DE COLORES (MEZCLA PERFECTA)
# 1. Interfaz Principal: Cyan + Negro (Legibilidad)
$C_BarBg = "Cyan";      $C_BarFg = "Black"
$C_ListFg = "Gray";     $C_ListBg = "Black"
$C_SelBg = "White";     $C_SelFg = "Black"

# 2. Modal: Negro + Amarillo (Estilo Retro / Alto Contraste que te gustaba)
$C_ModalBg = "Black";   $C_ModalFg = "White"; $C_ModalBorder = "Yellow"

[Console]::CursorVisible = $false
$OriginalEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { $Host.UI.RawUI.BufferSize = $Host.UI.RawUI.WindowSize } catch {}

$ESC = [char]27; $ANSI_RESET = "$ESC[0m"; $ANSI_CLEAR_LINE = "$ESC[K"

Clear-Host

# --- 3. FUNCIONES DE DIBUJO ---
function Update-ScrollState {
    if ($Themes.Count -le $ListHeight) { $script:ScrollStart = 0; return }
    if ($Selection -lt ($ScrollStart + $ScrollPadding)) { $script:ScrollStart = $Selection - $ScrollPadding }
    $BottomLimit = $ScrollStart + $ListHeight - 1 - $ScrollPadding
    if ($Selection -gt $BottomLimit) { $script:ScrollStart = $Selection - ($ListHeight - 1 - $ScrollPadding) }
    if ($ScrollStart -lt 0) { $script:ScrollStart = 0 }
    $MaxScroll = $Themes.Count - $ListHeight
    if ($ScrollStart -gt $MaxScroll) { $script:ScrollStart = $MaxScroll }
}

function Clean-AnsiOutput {
    param([string]$RawText)
    $RawText = $RawText -replace "\x1b\].*?(\x07|\x1b\\)", ""
    $RawText = $RawText -replace "\x1b\[\d*[A-J]", ""
    return $RawText
}

function Draw-Text {
    param($x, $y, $Text, $Bg="Black", $Fg="White")
    if ($y -lt $Host.UI.RawUI.WindowSize.Height) {
        [Console]::SetCursorPosition($x, $y)
        Write-Host $Text -NoNewline -ForegroundColor $Fg -BackgroundColor $Bg
    }
}

function Draw-Row {
    param($y, $Text, $BgColor="Black", $FgColor="White", $IsRawAnsi=$false)
    $Width = $Host.UI.RawUI.WindowSize.Width; $SafeWidth = $Width - 1 
    if ($y -lt $Host.UI.RawUI.WindowSize.Height) {
        [Console]::SetCursorPosition(0, $y)
        if ($IsRawAnsi) { [Console]::Out.Write($Text + $ANSI_RESET + $ANSI_CLEAR_LINE) } 
        else {
            if ($Text.Length -gt $SafeWidth) { $Text = $Text.Substring(0, $SafeWidth) }
            $PadRight = $SafeWidth - $Text.Length; if ($PadRight -lt 0) { $PadRight = 0 }
            Write-Host $Text -NoNewline -ForegroundColor $FgColor -BackgroundColor $BgColor
            if ($PadRight -gt 0) { Write-Host (" " * $PadRight) -NoNewline -BackgroundColor $BgColor }
        }
    }
}

function Draw-Centered {
    param($y, $Text, $Fg="White", $Bg="Black")
    $Width = $Host.UI.RawUI.WindowSize.Width - 1
    if ($Text.Length -gt $Width) { $Text = $Text.Substring(0, $Width) }
    $PadLeft = [Math]::Floor(($Width - $Text.Length) / 2)
    $FinalText = (" " * $PadLeft) + $Text
    Draw-Row -y $y -Text $FinalText -FgColor $Fg -BgColor $Bg
}

# --- 4. MODAL DE CONFIRMACIÓN (ESTILO RETRO RESTAURADO) ---
function Show-ConfirmModal {
    param ($ThemeObj)
    $W = $Host.UI.RawUI.WindowSize.Width; $H = $Host.UI.RawUI.WindowSize.Height
    $BoxW = 50; $BoxH = 8
    $StartX = [Math]::Floor(($W - $BoxW) / 2); $StartY = [Math]::Floor(($H - $BoxH) / 2)
    
    # Sombra para dar profundidad
    for ($i = 1; $i -le $BoxH; $i++) { Draw-Text ($StartX + 2) ($StartY + $i) (" " * $BoxW) "DarkGray" "Black" }
    
    # Caja Principal (Fondo Negro puro)
    for ($i = 0; $i -lt $BoxH; $i++) { Draw-Text $StartX ($StartY + $i) (" " * $BoxW) $script:C_ModalBg $script:C_ModalFg }

    # Bordes (Amarillo brillante)
    $Top = "╔" + ("═" * ($BoxW - 2)) + "╗"; $Bottom = "╚" + ("═" * ($BoxW - 2)) + "╝"
    Draw-Text $StartX $StartY $Top $script:C_ModalBg $script:C_ModalBorder
    Draw-Text $StartX ($StartY + $BoxH - 1) $Bottom $script:C_ModalBg $script:C_ModalBorder
    for ($i = 1; $i -lt $BoxH - 1; $i++) {
        Draw-Text $StartX ($StartY + $i) "║" $script:C_ModalBg $script:C_ModalBorder
        Draw-Text ($StartX + $BoxW - 1) ($StartY + $i) "║" $script:C_ModalBg $script:C_ModalBorder
    }

    $Title = " CONFIRMAR CAMBIO "
    $TitleX = $StartX + [Math]::Floor(($BoxW - $Title.Length) / 2)
    Draw-Text $TitleX ($StartY + 1) $Title $script:C_ModalBg "Cyan"
    Draw-Text ($StartX + 4) ($StartY + 3) "Vas a aplicar el tema:" $script:C_ModalBg "White"
    Draw-Text ($StartX + 27) ($StartY + 3) $ThemeObj.BaseName.ToUpper() $script:C_ModalBg "Yellow"
    
    # Botones visuales
    Draw-Text ($StartX + 4) ($StartY + 5) " [ ENTER: ACEPTAR ] " "Green" "Black"
    Draw-Text ($StartX + $BoxW - 20) ($StartY + 5) " [ ESC: CANCELAR ] " "Red" "White"

    while ($true) {
        $K = [Console]::ReadKey($true)
        if ($K.Key -eq 'Enter') { return $true }
        if ($K.Key -eq 'Escape') { return $false }
    }
}

# --- 5. INSTALADOR (RUTA PORTABLE DINÁMICA) ---
function Install-Theme {
    param ($ThemeObj)
    if (-not (Show-ConfirmModal -ThemeObj $ThemeObj)) { return }

    Clear-Host
    Write-Host "`n  Actualizando `$PROFILE..." -ForegroundColor Cyan
    
    $ProfilePath = $PROFILE
    if (!(Test-Path $ProfilePath)) { New-Item -Type File -Path $ProfilePath -Force | Out-Null }
    
    $Content = Get-Content $ProfilePath -Raw
    if ($null -eq $Content) { $Content = "" }
    
    # --- LOGICA DE RUTA PORTABLE ---
    $FullPath = $ThemeObj.FullName
    $UserProfile = $env:USERPROFILE
    
    # Si la ruta contiene el perfil de usuario, la reemplazamos por la variable $env:USERPROFILE
    if ($FullPath.StartsWith($UserProfile)) {
        # Escapamos caracteres especiales para el regex
        $EscapedUser = [regex]::Escape($UserProfile)
        # Reemplazo: 'C:\Users\Juan' -> '$env:USERPROFILE' (Literal)
        $PortablePath = $FullPath -replace "^$EscapedUser", '$env:USERPROFILE'
    } else {
        $PortablePath = $FullPath
    }
    
    # Creamos el comando usando la ruta portable
    # IMPORTANTE: Usamos comillas dobles en el comando final para que PowerShell expanda la variable al ejecutarse
    $NewCommand = 'oh-my-posh init pwsh --config "' + $PortablePath + '" | Invoke-Expression'
    
    $Pattern = '(?m)^.*oh-my-posh\s+init\s+pwsh.*$'
    
    if ($Content -match $Pattern) {
        $NewContent = $Content -replace $Pattern, $NewCommand
        Write-Host "  [i] Configuración reemplazada." -ForegroundColor Gray
    } else {
        $Prefix = if ($Content.Length -gt 0 -and -not $Content.EndsWith("`n")) { "`r`n" } else { "" }
        $NewContent = $Content + $Prefix + $NewCommand
        Write-Host "  [i] Configuración agregada." -ForegroundColor Gray
    }

    $NewContent = $NewContent.TrimEnd() # <--- ¡AQUÍ ESTÁ EL CAMBIO!
    # Esto borra cualquier \r\n (salto de línea) acumulado al final

    Set-Content -Path $ProfilePath -Value $NewContent -Encoding UTF8
    
    Write-Host "  Recargando..." -ForegroundColor Green
    try {
        $Expression = "& '$ExeReal' init pwsh --config '$($ThemeObj.FullName)'"
        Invoke-Expression ($Expression + " | Invoke-Expression")
    } catch { Write-Host "Error reload: $_" }
    Start-Sleep -Seconds 1
}

# --- 6. UI RENDER ---
function Update-UI {
    $ThemeFile = $Themes[$Selection]
    Copy-Item -Path $ThemeFile.FullName -Destination $TempFile -Force
    
    $CurrentWidth = $Host.UI.RawUI.WindowSize.Width; $CurrentHeight = $Host.UI.RawUI.WindowSize.Height
    if ($CurrentWidth -ne $LastWidth -or $CurrentHeight -ne $LastHeight) {
        Clear-Host; try { $Host.UI.RawUI.BufferSize = $Host.UI.RawUI.WindowSize } catch {}
        $script:LastWidth = $CurrentWidth; $script:LastHeight = $CurrentHeight
    }

    Draw-Row 0 (" " * $CurrentWidth) $script:C_BarBg $script:C_BarFg
    Draw-Centered 0 "OH-MY-POSH MANAGER" $script:C_BarFg $script:C_BarBg
    Draw-Centered 1 " ▼ $($ThemeFile.BaseName) ▼ " "Yellow" "Black"
    Draw-Row 2 ("─" * ($CurrentWidth-1)) "Black" "DarkGray"

    $PreviewY = 3
    try {
        $Env:COLUMNS = $CurrentWidth - 5
        $RawOut = & $ExeReal print primary --config $TempFile 2>$null
        Remove-Item Env:\COLUMNS -ErrorAction SilentlyContinue
        if ($RawOut -is [string]) { $RawOut = $RawOut -split "`n" }
    } catch { $RawOut = @() }

    for ($i = 0; $i -lt $PreviewHeight; $i++) {
        $L = if ($i -lt $RawOut.Count) { Clean-AnsiOutput $RawOut[$i].TrimEnd() } else { "" }
        Draw-Row -y ($PreviewY + $i) -Text $L -IsRawAnsi $true
    }

    $ListY = $PreviewY + $PreviewHeight
    Draw-Row $ListY ("─" * ($CurrentWidth-1)) "Black" "DarkGray"
    $ListY++
    
    $EndIndex = [Math]::Min($ScrollStart + $ListHeight - 1, $Themes.Count - 1)
    for ($r = 0; $r -lt $ListHeight; $r++) {
        $Idx = $ScrollStart + $r; $DrawY = $ListY + $r
        if ($Idx -le $EndIndex) {
            $Name = $Themes[$Idx].BaseName
            $Prefix = "   "; $Fg = $script:C_ListFg; $Bg = $script:C_ListBg
            if ($Idx -eq $Selection) { $Prefix = " ► "; $Fg = $script:C_SelFg; $Bg = $script:C_SelBg }
            $Content = $Prefix + ("{0,-35}" -f "$($Idx+1). $Name")
            $PadLeft = " " * ([Math]::Max(0, [Math]::Floor(($CurrentWidth - 45) / 2)))
            [Console]::SetCursorPosition(0, $DrawY)
            Write-Host $PadLeft -NoNewline -BackgroundColor Black
            Write-Host $Content -NoNewline -ForegroundColor $Fg -BackgroundColor $Bg
            [Console]::Out.Write($ANSI_RESET + $ANSI_CLEAR_LINE)
        } else { Draw-Row $DrawY "" }
    }

    Draw-Row ($ListY + $ListHeight) (" " * $CurrentWidth) $script:C_BarBg $script:C_BarFg
    $Msg = if ($InputBuffer) { " IR A: [$InputBuffer] " } else { " [↕] Navegar | [ENTER] Instalar | [Q] Salir " }
    Draw-Centered ($ListY + $ListHeight) $Msg $script:C_BarFg $script:C_BarBg
}

# --- 7. BUCLE ---
try {
    Write-Host "Iniciando..."
    Update-UI
    while ($Running) {
        if ([Console]::KeyAvailable) {
            $KeyInfo = [Console]::ReadKey($true)
            $ReDraw  = $false
            
            $IsCtrl  = ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control)
            $IsShift = ($KeyInfo.Modifiers -band [ConsoleModifiers]::Shift)
            $Key     = $KeyInfo.Key
            $CharInt = [int]$KeyInfo.KeyChar

            if (-not $IsCtrl -and [char]::IsDigit($KeyInfo.KeyChar)) {
                $InputBuffer += $KeyInfo.KeyChar; $ReDraw = $true
            }
            else {
                $Step = 1
                if ($InputBuffer) { try { $Step = [int]$InputBuffer } catch {}; $InputBuffer = "" }

                if (($IsCtrl -and $Key -eq 'J') -or $CharInt -eq 10) { $Selection += 10; $ReDraw = $true }
                elseif ($IsCtrl -and $Key -eq 'K') { $Selection -= 10; $ReDraw = $true }
                elseif ($IsShift -and $Key -eq 'J') { $Selection = $Themes.Count - 1; $ReDraw = $true }
                elseif ($IsShift -and $Key -eq 'K') { $Selection = 0; $ReDraw = $true }
                elseif ($Key -eq 'Enter') { Install-Theme -ThemeObj $Themes[$Selection]; $ReDraw = $true }
                elseif ($Key -eq 'J' -or $Key -eq 'DownArrow') { $Selection += $Step; $ReDraw = $true }
                elseif ($Key -eq 'K' -or $Key -eq 'UpArrow') { $Selection -= $Step; $ReDraw = $true }
                elseif ($Key -eq 'Escape' -or $Key -eq 'Q') { $Running = $false }
                
                $Selection = (($Selection % $Themes.Count) + $Themes.Count) % $Themes.Count
                Update-ScrollState
            }
            if ($ReDraw) { Update-UI }
        }
        Start-Sleep -Milliseconds 10
    }
} finally {
    [Console]::CursorVisible = $true
    if (Test-Path $TempFile) { Remove-Item $TempFile } 
    [Console]::OutputEncoding = $OriginalEncoding
    Clear-Host
    Write-Host "¡Listo!" 
}
