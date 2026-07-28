# ========================================================
#        🛠️ PANEL DE CONTROL (Activar / Desactivar)
# ========================================================
# Cambia a $false las cosas que no uses siempre para ganar velocidad
$UsarOhMyPosh      = $true
$UsarTerminalIcons = $false  # Ponlo en $true si quieres cargar los iconos al inicio
$AutoCargarFZF     = $false  # Si es $false, abre rapidísimo y lo cargas manual escribiendo: Activar-FZF

# ********************************************************
#        🔍 VALIDACIÓN DE SISTEMA OPERATIVO Y VERSIÓN
# ********************************************************
$Global:OS_Family = "Unknown"
$Global:IsWinLegacy = $false

if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Lógica obligatoria para PowerShell 5.1 (Siempre se asume Windows)
    $OsNombre = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    # Descomenta la siguiente línea si quieres ver el mensaje de SO cada vez que abres
    # Write-Host "Ejecutando en Windows heredado (PowerShell 5 o inferior): $OsNombre" -ForegroundColor Cyan
    $Global:OS_Family = "Windows"
    $Global:IsWinLegacy = $true
} else {
    # Lógica para PowerShell 6+ (Multiplataforma seguro)
    if ($IsWindows) {
        # Write-Host "Ejecutando en Windows (PowerShell Core 7+)" -ForegroundColor Cyan
        $Global:OS_Family = "Windows"
    } elseif ($IsLinux) {
        # Write-Host "Ejecutando en Linux (PowerShell Core 7+)" -ForegroundColor Cyan
        $Global:OS_Family = "Linux"
    } elseif ($IsMacOS) {
        # Write-Host "Ejecutando en macOS (PowerShell Core 7+)" -ForegroundColor Cyan
        $Global:OS_Family = "MacOS"
    }
}

# ********************************************************
#           ____             __ _ _      
#          |  _ \ _ __ ___  / _(_) | ___ 
#          | |_) | '__/ _ \| |_| | |/ _ \
#          |  __/| | | (_) |  _| | |  __/
#          |_|   |_|  \___/|_| |_|_|\___|
#                                 
# ********************************************************

# Obtener dinámicamente la ruta donde vive este perfil, sea Windows o Linux
$ProfileDir = Split-Path -Parent $PROFILE

# ********************************************************
#                   UTF-8
# ********************************************************
$utf8 = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding  = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding           = $utf8

# Registrar la carpeta de módulos locales en el PATH de PowerShell
$LocalModulesPath = Join-Path $ProfileDir "Modules"
if ($env:PSModulePath -notmatch [regex]::Escape($LocalModulesPath)) {
    $env:PSModulePath = "$LocalModulesPath" + [System.IO.Path]::PathSeparator + $env:PSModulePath
}

# ********************************************************
#                   Load PSReadLine & Alias
# ********************************************************
# Usamos Join-Path apuntando al subdirectorio "Scripts"
$psreadlineConfig = Join-Path $ProfileDir "Scripts/psreadline-config.ps1"
$myalias          = Join-Path $ProfileDir "myalias.ps1"
$fzfconfig        = Join-Path $ProfileDir "fzfconfig.ps1"

# Cargar configuraciones si los archivos existen
if (Test-Path $psreadlineConfig) { . $psreadlineConfig } else { Write-Warning "No se encontró psreadline-config.ps1" }
if (Test-Path $myalias)          { . $myalias }
if (Test-Path $fzfconfig)        { . $fzfconfig }

# ********************************************************
#                  CARGA CONDICIONAL (Módulos)
# ********************************************************

if ($UsarOhMyPosh) {
    # Elegir la ruta del tema dependiendo del Sistema Operativo
    if ($Global:OS_Family -eq "Windows") {
        $OmpConfig = Join-Path $HOME ".oh-my-posh/themes/wopian.omp.json"
    } else {
        # Ruta para Linux (y adaptable para MacOS si luego lo necesitas)
        $OmpConfig = "/usr/share/oh-my-posh/themes/wopian.omp.json"
    }

    if (Test-Path $OmpConfig) {
        Invoke-Expression (& oh-my-posh init pwsh --config $OmpConfig | Out-String)
    } else {
        Write-Warning "⚠️ Oh-My-Posh: No se encontró el tema en $OmpConfig"
    }
}

if ($UsarTerminalIcons) {
    Import-Module Terminal-Icons -DisableNameChecking
}


# ----------------------------------------------------------------------------------------------
#
#   FZF (LAZY LOADING)
#
# ----------------------------------------------------------------------------------------------

# Todo FZF está dentro de esta función. No hará lenta tu terminal al abrir.
function Activar-FZF {
    Write-Host "Cargando FZF y atajos de teclado..." -ForegroundColor Yellow

    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    $commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location }
    Set-PsFzfOption -AltCCommand $commandOverride
    Set-PsFzfOption -EnableAliasFuzzyHistory
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

    $env:FZF_DEFAULT_OPTS=@"
--layout=reverse
--cycle
--scroll-off=5
--border
--preview-window=right,60%,border-left
--bind ctrl-u:preview-half-page-up
--bind ctrl-d:preview-half-page-down
--bind ctrl-f:preview-page-down
--bind ctrl-b:preview-page-up
--bind ctrl-g:preview-top
--bind ctrl-h:preview-bottom
--bind alt-w:toggle-preview-wrap
--bind ctrl-e:toggle-preview
"@

    function global:_open_path {
        param ([string]$input_path)
        if (-not $input_path) { return }
        Write-Output "[ ] cd"
        Write-Output "[*] nvim"
        $choice = Read-Host "Enter your choice"
        if ($input_path -match "^.*:\d+:.*$") {
            $input_path = ($input_path -split ":")[0]
        }
        switch ($choice) {
            {$_ -eq "" -or $_ -eq " "} {
                if (Test-Path -Path $input_path -PathType Leaf) {
                    $input_path = Split-Path -Path $input_path -Parent
                }
                Set-Location -Path $input_path
            }
            default { nvim $input_path }
        }
    }

    function global:_get_path_using_fd {
        # Adaptación del shell interno que usa fzf según el sistema operativo
        if ($Global:OS_Family -eq "Windows") {
            $bindCmd = 'ctrl-s:transform:if not "%FZF_PROMPT%"=="Files> " (echo ^change-prompt^(Files^> ^)^+^reload^(fd --type file^)) else (echo ^change-prompt^(Directory^> ^)^+^reload^(fd --type directory^))'
            $prevCmd = 'if "%FZF_PROMPT%"=="Files> " (bat --color=always {} --style=plain) else (eza -T --colour=always --icons=always {})'
        } else {
            $bindCmd = 'ctrl-s:transform:if [ "$FZF_PROMPT" = "Files> " ]; then echo "change-prompt(Directory> )+reload(fd --type directory)"; else echo "change-prompt(Files> )+reload(fd --type file)"; fi'
            $prevCmd = 'if [ "$FZF_PROMPT" = "Files> " ]; then bat --color=always {} --style=plain; else eza -T --colour=always --icons=always {}; fi'
        }

        $input_path = fd --type file --follow --hidden --exclude .git |
            fzf --prompt 'Files> ' `
                --header-first `
                --header 'CTRL-S: Switch between Files/Directories' `
                --bind $bindCmd `
                --preview $prevCmd
        return $input_path
    }

    function global:_get_path_using_rg {
        $INITIAL_QUERY = "${*:-}"
        $RG_PREFIX = "rg --column --line-number --no-heading --color=always --smart-case"
        
        if ($Global:OS_Family -eq "Windows") {
            $bindCmd = 'ctrl-s:transform:if not "%FZF_PROMPT%" == "1. ripgrep> " (echo ^rebind^(change^)^+^change-prompt^(1. ripgrep^> ^)^+^disable-search^+^transform-query:echo ^{q^} ^> %TEMP%\rg-fzf-f ^& cat %TEMP%\rg-fzf-r) else (echo ^unbind^(change^)^+^change-prompt^(2. fzf^> ^)^+^enable-search^+^transform-query:echo ^{q^} ^> %TEMP%\rg-fzf-r ^& cat %TEMP%\rg-fzf-f)'
        } else {
            # Se usa /tmp/ en Linux/Mac en lugar de %TEMP%
            $bindCmd = 'ctrl-s:transform:if [ "$FZF_PROMPT" != "1. ripgrep> " ]; then echo "rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-query:echo {q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r"; else echo "unbind(change)+change-prompt(2. fzf> )+enable-search+transform-query:echo {q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f"; fi'
        }

        $input_path = "" |
            fzf --ansi --disabled --query "$INITIAL_QUERY" `
                --bind "start:reload:$RG_PREFIX {q}" `
                --bind "change:reload:sleep 0.1 & $RG_PREFIX {q} || rem" `
                --bind $bindCmd `
                --color "hl:-1:underline,hl+:-1:underline:reverse" `
                --delimiter ":" `
                --prompt '1. ripgrep> ' `
                --preview-label "Preview" `
                --header 'CTRL-S: Switch between ripgrep/fzf' `
                --header-first `
                --preview 'bat --color=always {1} --highlight-line {2} --style=plain' `
                --preview-window 'up,60%,border-bottom,+{2}+3/3'
        return $input_path
    }

    function global:fdg { _open_path $(_get_path_using_fd) }
    function global:rgg { _open_path $(_get_path_using_rg) }

    Set-PSReadLineKeyHandler -Key "Ctrl+f" -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("fdg")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    Set-PSReadLineKeyHandler -Key "Ctrl+g" -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("rgg")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    Write-Host "🚀 FZF listo para usarse." -ForegroundColor Green
}

if ($AutoCargarFZF) { Activar-FZF }

# *******************************************************
#                  my functions (Carga normal)
# *******************************************************

# Función genérica para encontrar dónde está un comando (multiplataforma)
function whereis ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# Refactorizada a multiplataforma y código PowerShell nativo (sin cmd.exe)
function getLatestVerison() {
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$module_name
    )
    # Busca en la carpeta local de Modules dentro del perfil
    $modulePath = Join-Path $ProfileDir "Modules"
    $targetDir = Join-Path $modulePath $module_name
    
    if (Test-Path $targetDir) {
        $latest = Get-ChildItem -Path $targetDir -Directory | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty Name
        return $latest
    }
}

function lfcd {
    if (-not (Get-Command "lf" -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ Error: 'lf' no se encuentra instalado o no está en el PATH." -ForegroundColor Red
        return 
    }
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        & lf -last-dir-path $tmp $args
        if (Test-Path $tmp) {
            $dir = Get-Content $tmp -Raw
            if (![string]::IsNullOrWhiteSpace($dir) -and (Test-Path $dir)) {
                Set-Location $dir
            }
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------
# Validaciones de herramientas CLI
# ---------------------------------------------------------

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    zoxide init powershell | Out-String | Invoke-Expression
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    (&mise activate pwsh) | Out-String | Invoke-Expression
}

# Validación multiplataforma para Yazi
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    function y {
        # 🟢 ESTA ES LA MAGIA: Sincroniza el directorio del OS con el de PowerShell
        [Environment]::CurrentDirectory = $PWD.ProviderPath

        $tmp = (New-TemporaryFile).FullName
        yazi @args --cwd-file="$tmp"
        
        $cwd = Get-Content -Path $tmp -Encoding UTF8
        if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
            Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
        }
        Remove-Item -Path $tmp
    }
}
