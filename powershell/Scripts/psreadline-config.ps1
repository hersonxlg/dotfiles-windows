# ************************************************************
# VI-MODE & PSReadLine Config
# ************************************************************

Set-PSReadLineOption -EditMode Vi

# Opciones Generales (agrupadas y sin redundancias)
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -ShowToolTips

# Autocompletado y navegación
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key 'Ctrl+q' -Function TabCompleteNext
# Shift+Tab se devuelve a su función nativa para retroceder en el autocompletado
Set-PSReadLineKeyHandler -Key 'Shift+Tab' -Function TabCompletePrevious 

## Autocompletado y navegación
## Usamos MenuComplete en ViMode Insert para que muestre las sugerencias visuales
#Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ViMode Insert
#Set-PSReadLineKeyHandler -Key 'Shift+Tab' -Function TabCompletePrevious -ViMode Insert
## Mantenemos Ctrl+q por si lo necesitas como atajo secundario
#Set-PSReadLineKeyHandler -Key 'Ctrl+q' -Function TabCompleteNext -ViMode Insert

# Búsqueda en historial nativa
Set-PSReadLineKeyHandler -Key 'Ctrl+p' -ViMode Insert -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key 'Ctrl+n' -ViMode Insert -Function HistorySearchForward

# ------------------------------------------------------
# Indicador visual del cursor (Bloque/Línea)
# ------------------------------------------------------
# Variable global para saber cuándo forzar la barra vertical
$global:VisualMode = $false

function OnViModeChange {
    if ($global:VisualMode) {
        Write-Host -NoNewLine "`e[5 q" # Línea (Visual Mode)
    } elseif ($args[0] -eq 'Command') {
        Write-Host -NoNewLine "`e[1 q" # Bloque (Normal Mode)
    } else {
        Write-Host -NoNewLine "`e[5 q" # Línea (Insert Mode)
    }
}
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $Function:OnViModeChange

# ------------------------------------------------------
# Filtro de Historial (Optimizado sin Regex)
# ------------------------------------------------------
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$line)
    # StartsWith es infinitamente más rápido que -match "^git"
    return -not $line.StartsWith("git") 
}

# ------------------------------------------------------
# Limpiar Línea (Optimizado)
# ------------------------------------------------------
Set-PSReadLineKeyHandler -Key "Ctrl+l" -ViMode Command -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

# ------------------------------------------------------
# Salir del modo "Insert" con "kj" (Bugs corregidos)
# ------------------------------------------------------
$j_timer = [System.Diagnostics.Stopwatch]::StartNew()

Set-PSReadLineKeyHandler -Key k -ViMode Insert -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("k")
    $j_timer.Restart()
}

Set-PSReadLineKeyHandler -Key j -ViMode Insert -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # Validamos que sea rápido (< 300ms) Y que la letra justo anterior sea 'k'
    if ($j_timer.IsRunning -and $j_timer.ElapsedMilliseconds -le 300 -and $cursor -gt 0 -and $line[$cursor-1] -eq 'k') {
        # Borrar la 'k' anterior
        [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 1)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("j")
    }
}

# -----------------------------------------------------------------------------------------
# SNIPPETS & Cierre Automático
# -----------------------------------------------------------------------------------------

# Auto cerrar comillas
Set-PSReadLineKeyHandler -Chord '"',"'" -ScriptBlock {
    param($key, $arg)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line.Length -gt $cursor -and $line[$cursor] -eq $key.KeyChar) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)" * 2)
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}

# Envolver en paréntesis (Alt + ()
Set-PSReadLineKeyHandler -Key 'Alt+(' -ScriptBlock {
    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}

# -------------------------------------------------------
# FZF: Búsqueda en el Historial
# NOTA: Requiere que 'Get-PickedHistory' esté cargado
# -------------------------------------------------------

# En modo COMMAND, mantenemos "/"
Set-PSReadLineKeyHandler -Key '/' -ViMode Command -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $comando = Get-PickedHistory $line -UsePSReadLineHistory
    if ($comando) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($comando)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
    }
}

# En modo INSERT, usamos Ctrl+r (En lugar de '/' o 'Shift+Tab' para no romper rutas ni autocompletado)
Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ViMode Insert -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $comando = Get-PickedHistory $line -UsePSReadLineHistory
    if ($comando) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($comando)
    }
}

# -------------------------------------------------------
# Portapapeles (Multiplataforma y Nativo, adiós WPF)
# -------------------------------------------------------

Set-PSReadLineKeyHandler -Key ' ,y' -Function Copy -ViMode Command

Set-PSReadLineKeyHandler -Key ' ,t' -ViMode Command -ScriptBlock {
    $text = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    if ($text) {
        $text = ($text -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        $cursor = $null; $line = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        
        if (($text | Measure-Object -Line).Lines -gt 1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("'$text'")
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}

Set-PSReadLineKeyHandler -Key ' ,p' -ViMode Command -ScriptBlock {
    $text = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    if ($text) {
        $text = ($text -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        $cursor = $null; $line = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($text)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}

Set-PSReadLineKeyHandler -Key ' ,P' -ViMode Command -ScriptBlock {
    $text = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    if ($text) {
        $text = ($text -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($text)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}

# -------------------------------------------------------
# MODO VISUAL ARTIFICIAL (Cursor Parcheado y teclas x/X corregidas)
# -------------------------------------------------------

# Reseteo de seguridad: Si presionas Escape, sales del modo visual limpiamente
Set-PSReadLineKeyHandler -Key Escape -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        $global:VisualMode = $false
        Write-Host -NoNewLine "`e[1 q"
    }
    [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
}

Set-PSReadLineKeyHandler -Key "v" -ViMode Command -ScriptBlock {
    $cursor = $null; $line = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if (-not $global:VisualMode) {
        $global:VisualMode = $true
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor+1)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
        # Nota: ViCommandMode() dispara OnViModeChange y pone la línea vertical automáticamente
    } else {
        $global:VisualMode = $false
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor)
        Write-Host -NoNewLine "`e[1 q"
    }
}

# Variable con la lógica perfecta para borrar la selección visual (Inclusivo al estilo Vim)
$borrarSeleccionVisual = {
    if ($global:VisualMode) {
        $global:VisualMode = $false
        
        $start = $null; $len = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$start, [ref]$len)
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        if ($len -eq 0) {
            [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar()
        } else {
            # Vim es inclusivo con el último carácter al mover hacia la derecha
            if ($cursor -eq ($start + $len)) {
                [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::KillRegion()
        }
        
        Write-Host -NoNewLine "`e[1 q"
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar()
    }
}

# Mapeamos TANTO la "x" minúscula como la "X" mayúscula para que funcionen igual
Set-PSReadLineKeyHandler -Key "x" -ViMode Command -ScriptBlock $borrarSeleccionVisual
Set-PSReadLineKeyHandler -Key "X" -ViMode Command -ScriptBlock $borrarSeleccionVisual

Set-PSReadLineKeyHandler -Key "l" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar()
    }
}

Set-PSReadLineKeyHandler -Key "h" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardChar()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar()
    }
}

# -------------------------------------------------------------------------
# EXTENSIÓN DEL MODO VISUAL: Palabras y Líneas
# -------------------------------------------------------------------------

# "w" - Siguiente palabra
Set-PSReadLineKeyHandler -Key "w" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectNextWord()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::NextWord()
    }
}

# "b" - Palabra anterior
Set-PSReadLineKeyHandler -Key "b" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardsWord()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardWord()
    }
}

# "0" - Inicio de línea
Set-PSReadLineKeyHandler -Key "0" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardsLine()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::BeginningOfLine()
    }
}

# "$" - Fin de línea
Set-PSReadLineKeyHandler -Key "`$" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectLine()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}

# "e" - Fin de palabra
Set-PSReadLineKeyHandler -Key "e" -ViMode Command -ScriptBlock {
    if ($global:VisualMode) {
        # PSReadLine no tiene "SelectEndOfWord", usamos SelectNextWord como aproximación
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectNextWord()
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardWord()
    }
}

# -------------------------------------------------------------------------
# INICIALIZACIÓN DE ENTORNO
# -------------------------------------------------------------------------
# Forzar el cursor de línea vertical al iniciar PowerShell (Insert Mode default)
Write-Host -NoNewLine "`e[5 q"
