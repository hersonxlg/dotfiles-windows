# ************************************************************
# VI-MODE:
# ************************************************************
# 


Set-PSReadLineOption -EditMode Vi


# ********************************************************
#                  PSReadLine:
# ********************************************************
# Habilita el menu para autocompletado.
#Set-PSReadLineOption -EditMode Windows
#Set-PSReadLineKeyHandler -Key Tab -Function Complete
# In Emacs mode - Tab acts like in bash, but the Windows style completion
# is still useful sometimes, so bind some keys so we can do both
Set-PSReadLineKeyHandler -Key Ctrl+q -Function TabCompleteNext
Set-PSReadLineKeyHandler -Key Ctrl+Q -Function TabCompletePrevious

# PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function Complete
#Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete


#Set-PSReadLineOption -PredictionViewStyle ListView

Set-PSReadLineKeyHandler -Key 'Ctrl+k' -ViMode Insert -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key 'Ctrl+j' -ViMode Insert -Function HistorySearchForward





# ----------------------------------------------------------------------------
# lista de funciones de psreadline:
# ----------------------------------------------------------------------------
# 
# [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
# [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
# [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertAtEnd()
# [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
# [Microsoft.PowerShell.PSConsoleReadLine]::Insert("texto despues del cursor")
# [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition([int]$nueva_posicion)
#
#
# NOTA:
#      - La posicion del cursor comienza en cero.
#
#
# ----------------------------------------------------------------------------


# Pruebas...
#
##
##$global:keyword = "hola"
##Set-PSReadLineKeyHandler -Chord ("a".."z") `
##                         -BriefDescription SnippetDePruebas`
##                         -LongDescription "Agrega un punto despues del cursor." `
##                         -ScriptBlock {
##    param($key, $arg)
##
##    $cursor = $null
##    $line = $null
##
##    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.keychar)
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##    
##    if ($line.length -ge $keyword.length){
##        if( $global:keyword[$keyword.length - 1] -eq $key.keychar){
##            if($line.SubString($cursor - $keyword.length, $keyword.length) -eq $global:keyword){
##                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 4)
##                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`"")
##                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 4)
##                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`"")
##            }
##        }
##    }
##}



Set-PSReadLineKeyHandler -key "Ctrl+;" `
-ViMode Command `
-BriefDescription AtajaDePruebas `
-LongDescription "Insert paired quotes if not already on a quote" `
-ScriptBlock {
    param($key, $arg)

    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition(0)
    [Microsoft.PowerShell.PSConsoleReadLine]::KillLine()
    #[Microsoft.PowerShell.PSConsoleReadLine]::Insert("${$key.keychar} : ${arg}")
}




# ----------------------------------------------------------------------------
# Mis atajos de teclado:
# ----------------------------------------------------------------------------
# 


Set-PSReadLineKeyHandler -key "Ctrl+l" `
-ViMode Command `
-BriefDescription LimpiarLaLineaDeComandos `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {
    param($key, $arg)

    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition(0)
    [Microsoft.PowerShell.PSConsoleReadLine]::KillLine()

}

# ------------------------------------------------------
# Habilita la edition en neovim para el modo visual en powershell:
# ------------------------------------------------------
#$env:VISUAL = 'nvim-qt.exe'

# ------------------------------------------------------
# Editor externo de una linea de comando para el 
# modo vim de powershell:
# ------------------------------------------------------

##Set-PSReadLineKeyHandler -Chord "Alt+e" -ScriptBlock {
##  $CurrentInput = $null
##
##  # Copy current command-line input, save it to a file and clear it
##  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref] $CurrentInput, [ref] $null)
##  Set-Content -Path "C:\Temp\ps_${PID}.txt" -Value "$CurrentInput"
##  [Microsoft.PowerShell.PSConsoleReadLine]::KillRegion()
##
##  # Edit the command with nvim
##  Start-Job -Name EditCMD -ScriptBlock { vim "C:\Temp\ps_${Using:PID}.txt" }
##  Wait-Job  -Name EditCMD
##
##  # Get command back from file the temporary file and insert it into the command-line
##  $NewInput  = (Get-Content -Path "C:\Temp\ps_${PID}.txt") -join "`n"
##  [Microsoft.PowerShell.PSConsoleReadLine]::Insert($NewInput)
##}




# ------------------------------------------------------
# Salir del modo "Insert" con "kj":
# ------------------------------------------------------
$j_timer = New-Object System.Diagnostics.Stopwatch
Set-PSReadLineKeyHandler -Key k -ViMode Insert -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("k")
    $j_timer.Restart()
}
Set-PSReadLineKeyHandler -Key j -ViMode Insert -ScriptBlock {
    if (!$j_timer.IsRunning -or $j_timer.ElapsedMilliseconds -gt 1000) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("j")
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor, 1)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor-1)
    }
}





##Set-PSReadLineOption -Colors @{ "Comment"="`e[92m" }
##
##Set-PSReadLineOption -Colors @{
##  Command            = 'Magenta'
##  Number             = 'DarkGray'
##  Member             = 'DarkGray'
##  Operator           = 'DarkGray'
##  Type               = 'DarkGray'
##  Variable           = 'DarkGreen'
##  Parameter          = 'DarkGreen'
##  ContinuationPrompt = 'DarkGray'
##  Default            = 'DarkGray'
##}
##
##
##$host.PrivateData.VerboseForegroundColor = 'DarkYellow'
##$host.PrivateData.WarningForegroundColor = 'DarkYellow'
##$host.PrivateData.DebugForegroundColor = 'DarkYellow'
##$host.PrivateData.ProgressForegroundColor = 'DarkYellow'



# ------------------------------------------------------
# Cambian el cursor de powershell en Vi mode:
# ------------------------------------------------------

# Cambira el cursor segun el modo de trabajo:
function OnViModeChange {
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block.
        Write-Host -NoNewLine "`e[1 q"
    } else {
        # Set the cursor to a blinking line.
        Write-Host -NoNewLine "`e[5 q"
    }
}
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $Function:OnViModeChange


# Filtrar los comando que se almacenan en el historial:
$ScriptBlock = {
    Param([string]$line)

if ($line -match "^git") {
        return $false
    } else {
        return $true
    }
}
Set-PSReadLineOption -AddToHistoryHandler $ScriptBlock


# -----------------------------------------------------------------------------------------
#                                                                                          
#                                       SNIPPETS:                                          
#                                                                                          
# -----------------------------------------------------------------------------------------





# ***************************************************************************************
#
#              Auto cerra la comillas:
#
# ***************************************************************************************
#
Set-PSReadLineKeyHandler -Chord '"',"'" `
-BriefDescription SmartInsertQuote `
-LongDescription "Insert paired quotes if not already on a quote" `
-ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null

    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line.Length -gt $cursor -and $line[$cursor] -eq $key.KeyChar) {
        # Just move the cursor
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        # Insert matching quotes, move cursor to be in between the quotes
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)" * 2)
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}



# ***************************************************************************************
#
#              Abrir el HISTORIAL con fzf en el modo insertar con "/".
#
# ***************************************************************************************
#

Set-PSReadLineKeyHandler -Chord '/' `
-BriefDescription FzfSearchHistory `
-LongDescription "Insert paired quotes if not already on a quote" `
-ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null

    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line.Length -eq 0) {# -and $line[$cursor] -eq $key.KeyChar) {
        # Just move the cursor
        #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        #[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)

        # Recuperar un comando del historial con fzf.
        $comando = $(Get-PickedHistory $line -UsePSReadLineHistory )

        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() # Borrar la linea de comando.
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$comando")
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
    }
    else {
        # Insert matching quotes, move cursor to be in between the quotes
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
    }
}



# -----------------------------------------------------------------------------------------

#
# region Smart Insert/Delete


# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.

### Set-PSReadLineKeyHandler -Key '"',"'" `
##                         -BriefDescription SmartInsertQuote `
##                         -LongDescription "Insert paired quotes if not already on a quote" `
##                         -ScriptBlock {
##    param($key, $arg)
##
##    $quote = $key.KeyChar
##
##    $selectionStart = $null
##    $selectionLength = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
##
##    $line = $null
##    $cursor = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##
##    # If text is selected, just quote it without any smarts
##    if ($selectionStart -ne -1)
##    {
##        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
##        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
##        return
##    }
##
##    $ast = $null
##    $tokens = $null
##    $parseErrors = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)
##
##    function FindToken
##    {
##        param($tokens, $cursor)
##
##        foreach ($token in $tokens)
##        {
##            if ($cursor -lt $token.Extent.StartOffset) { continue }
##            if ($cursor -lt $token.Extent.EndOffset) {
##                $result = $token
##                $token = $token -as [StringExpandableToken]
##                if ($token) {
##                    $nested = FindToken $token.NestedTokens $cursor
##                    if ($nested) { $result = $nested }
##                }
##
##                return $result
##            }
##        }
##        return $null
##    }
##
##    $token = FindToken $tokens $cursor
##
##    # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
##    if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
##        # If we're at the start of the string, assume we're inserting a new string
##        if ($token.Extent.StartOffset -eq $cursor) {
##            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
##            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
##            return
##        }
##
##        # If we're at the end of the string, move over the closing quote if present.
##        if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
##            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
##            return
##        }
##    }
##
##    if ($null -eq $token -or
##        $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
##        if ($line[0..$cursor].Where{$_ -eq $quote}.Count % 2 -eq 1) {
##            # Odd number of quotes before the cursor, insert a single quote
##            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
##        }
##        else {
##            # Insert matching quotes, move cursor to be in between the quotes
##            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
##            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
##        }
##        return
##    }
##
##    # If cursor is at the start of a token, enclose it in quotes.
##    if ($token.Extent.StartOffset -eq $cursor) {
##        if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or 
##            $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
##            $end = $token.Extent.EndOffset
##            $len = $end - $cursor
##            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
##            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
##            return
##        }
##    }
##
##    # We failed to be smart, so just insert a single quote
##    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
##}
##
##Set-PSReadLineKeyHandler -Key '(','{','[' `
##                         -BriefDescription InsertPairedBraces `
##                         -LongDescription "Insert matching braces" `
##                         -ScriptBlock {
##    param($key, $arg)
##
##    $closeChar = switch ($key.KeyChar)
##    {
##        <#case#> '(' { [char]')'; break }
##        <#case#> '{' { [char]'}'; break }
##        <#case#> '[' { [char]']'; break }
##    }
##
##    $selectionStart = $null
##    $selectionLength = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
##
##    $line = $null
##    $cursor = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##    
##    if ($selectionStart -ne -1)
##    {
##      # Text is selected, wrap it in brackets
##      [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
##      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
##    } else {
##      # No text is selected, insert a pair
##      [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
##      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
##    }
##}
##
##Set-PSReadLineKeyHandler -Key ')',']','}' `
##                         -BriefDescription SmartCloseBraces `
##                         -LongDescription "Insert closing brace or skip" `
##                         -ScriptBlock {
##    param($key, $arg)
##
##    $line = $null
##    $cursor = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##
##    if ($line[$cursor] -eq $key.KeyChar)
##    {
##        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
##    }
##    else
##    {
##        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
##    }
##}
##
##Set-PSReadLineKeyHandler -Key Backspace `
##                         -BriefDescription SmartBackspace `
##                         -LongDescription "Delete previous character or matching quotes/parens/braces" `
##                         -ScriptBlock {
##    param($key, $arg)
##
##    $line = $null
##    $cursor = $null
##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##
##    if ($cursor -gt 0)
##    {
##        $toMatch = $null
##        if ($cursor -lt $line.Length)
##        {
##            switch ($line[$cursor])
##            {
##                <#case#> '"' { $toMatch = '"'; break }
##                <#case#> "'" { $toMatch = "'"; break }
##                <#case#> ')' { $toMatch = '('; break }
##                <#case#> ']' { $toMatch = '['; break }
##                <#case#> '}' { $toMatch = '{'; break }
##            }
##        }
##
##        if ($toMatch -ne $null -and $line[$cursor-1] -eq $toMatch)
##        {
##            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
##        }
##        else
##        {
##            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
##        }
##    }
##}

#endregion Smart Insert/Delete




#Shows tooltip during completion
Set-PSReadLineOption -ShowToolTips

#Gives completions/suggestions from historical commands
Set-PSReadLineOption -PredictionSource History



# Sometimes you want to get a property of invoke a member on what you've entered so far
# but you need parens to do that.  This binding will help by putting parens around the current selection,
# or if nothing is selected, the whole line.
Set-PSReadLineKeyHandler -Key 'Alt+(' `
-BriefDescription ParenthesizeSelection `
-LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
-ScriptBlock {

    param($key, $arg)

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}





# ********************************************************
#                Comandos para copiar y pegar:
# ********************************************************

# copiar y pegar en el modo Vi:
Set-PSReadLineKeyHandler -Key ' ,y' -Function Copy -ViMode Command

# Agregar texto extre comillas simples despues del cursor en Vi-mode:
Set-PSReadLineKeyHandler -Key ' ,t' -ViMode Command -ScriptBlock {

    param($key, $arg)

    Add-Type -Assembly PresentationCore
    if ([System.Windows.Clipboard]::ContainsText())
    {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)

        # Get clipboard text - remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text = ([System.Windows.Clipboard]::GetText() -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        $lines = ($text | Measure-Object -Line | Select-Object -ExpandProperty Lines)

        if ($lines -gt 1){
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
        }else{
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("'$text'")
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}


# ****************************************************************************
#
#              Comandos para copiar y pegar:
#
#  Agregar texto SIN comillas simples despues del cursor en Vi-mode:
#
# ****************************************************************************
# 
Set-PSReadLineKeyHandler -Key ' ,p' -ViMode Command -ScriptBlock {

    param($key, $arg)

    Add-Type -Assembly PresentationCore
    if ([System.Windows.Clipboard]::ContainsText())
    {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)

        # Get clipboard text - remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text = ([System.Windows.Clipboard]::GetText() -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        $lines = ($text | Measure-Object -Line | Select-Object -ExpandProperty Lines)

        if ($lines -gt 1){
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$text")
        }else{
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$text")
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}




# ****************************************************************************
#
#              Comandos para copiar y pegar:
#
#  Agregar texto SIN comillas simples antes del cursor en Vi-mode:
#
# ****************************************************************************
#
Set-PSReadLineKeyHandler -Key ' ,P' -ViMode Command -ScriptBlock {
#[[
    param($key, $arg)

    Add-Type -Assembly PresentationCore
    if ([System.Windows.Clipboard]::ContainsText())
    {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()

        # Get clipboard text - remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text = ([System.Windows.Clipboard]::GetText() -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        $lines = ($text | Measure-Object -Line | Select-Object -ExpandProperty Lines)

        if ($lines -gt 1){
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$text")
        }else{
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$text")
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
#]]
}



# ****************************************************************************
#
#  Buscar en el historial de comandos con FZF
#  al presionar "/" en el modo NORMAL.
#
# ****************************************************************************
#

Set-PSReadLineKeyHandler -key '/' `
-ViMode Command `
-BriefDescription FzfSearchHistory `
-LongDescription "Insert paired quotes if not already on a quote" `
-ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # Recuperar un comando del historial con fzf.
    $comando = $(Get-PickedHistory $line -UsePSReadLineHistory )

    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() # Borrar la linea de comando.
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$comando")
    [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
}


# ****************************************************************************
#
#  Buscar en el historial de comandos con FZF
#  al presionar "Shift+Tab" en el modo INSERTAR.
#
# ****************************************************************************
#


Set-PSReadLineKeyHandler -key "Shift+Tab" `
-ViMode Insert `
-BriefDescription LimpiarLaLineaDeComandos `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # Recuperar un comando del historial con fzf.
    $comando = $(Get-PickedHistory $line -UsePSReadLineHistory )


    [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() # Borrar la linea de comando.
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$comando")
    [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
}







$global:VisualMode= $false

Set-PSReadLineKeyHandler -key "v" `
-ViMode Command `
-BriefDescription VisualModeArtificially `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {

    param($key, $arg)

    $line = $null
    $cursor = $null
    $selectionStart = $null
    $selectionLength = $null

    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)


    if ($global:VisualMode -eq $false) {
        $global:VisualMode = $true
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor+1)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
        #Write-Host -NoNewLine "`e[5 q"
        #[Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardsLine()
        #[Microsoft.PowerShell.PSConsoleReadLine]::ExchangePointAndMark()

    }else{
        $global:VisualMode = $false
        #Write-Host -NoNewLine "`e[1 q"
    }



    # Just move the cursor
    #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    #[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)

    #[Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() # Borrar la linea de comando.
    #[Microsoft.PowerShell.PSConsoleReadLine]::Insert("${selectionStart},${selectionLength}")
    #[Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()

    #[Microsoft.PowerShell.PSConsoleReadLine]::SelectAll()

    # Insert matching quotes, move cursor to be in between the quotes
    #[Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
}



Set-PSReadLineKeyHandler -key "l" `
-ViMode Command `
-BriefDescription VisualModeArtificially `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {

    param($key, $arg)

    $line = $null
    $cursor = $null
    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    if ($global:VisualMode) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar()
        #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + $selectionLength)
        [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    }else{
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar()
    }
}



Set-PSReadLineKeyHandler -key "h" `
-ViMode Command `
-BriefDescription VisualModeArtificially `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($global:VisualMode) {
        #[Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardsLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardChar()
    }else{
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardChar()
    }
}




Set-PSReadLineKeyHandler -key "X" `
-ViMode Command `
-BriefDescription VisualModeArtificially `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null

    if ($global:VisualMode) {
        #[Microsoft.PowerShell.PSConsoleReadLine]::SelectBackwardsLine()
        $global:VisualMode = $false
        [Microsoft.PowerShell.PSConsoleReadLine]::KillRegion()
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar()
    }else{
        [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar()
        $global:VisualMode = $false
    }
}


Set-PSReadLineKeyHandler -key "Ctrl+o" `
-ViMode Command `
-BriefDescription VisualModeArtificially `
-LongDescription "Limapia todo texto que contengo la linea de comandos" `
-ScriptBlock {

    param($key, $arg)

    $line = $null
    $cursor = $null
    $selectionStart = $null
    $selectionLength = $null

    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    [Microsoft.PowerShell.PSConsoleReadLine]::ExchangePointAndMark()
    # Just move the cursor
    #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    #[Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    #[Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)

    #[Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() # Borrar la linea de comando.
    #[Microsoft.PowerShell.PSConsoleReadLine]::Insert("${selectionStart},${selectionLength}")
    #[Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()

    #[Microsoft.PowerShell.PSConsoleReadLine]::SelectAll()

    # Insert matching quotes, move cursor to be in between the quotes
    #[Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
}


