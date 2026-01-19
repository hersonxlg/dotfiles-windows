# ************************************************************
# Oh My Posh
# ************************************************************
oh-my-posh init pwsh --config "$env:USERPROFILE\.oh-my-posh\themes\wopian.omp.json" | Invoke-Expression


##  # ************************************************************
##  # VI-MODE:
##  # ************************************************************
##  # 
##  
Set-PSReadLineOption -EditMode Vi
##  
##  
##  
##  # ----------------------------------------------------------------------------
##  # lista de funciones de psreadline:
##  # ----------------------------------------------------------------------------
##  # 
##  # [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##  # [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertMode()
##  # [Microsoft.PowerShell.PSConsoleReadLine]::ViInsertAtEnd()
##  # [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
##  # [Microsoft.PowerShell.PSConsoleReadLine]::Insert("texto despues del cursor")
##  # [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition([int]$nueva_posicion)
##  #
##  #
##  # NOTA:
##  #      - La posicion del cursor comienza en cero.
##  #
##  #
##  # ----------------------------------------------------------------------------
##  
##  
##  # Pruebas...
##  #
##  ##
##  ##$global:keyword = "hola"
##  ##Set-PSReadLineKeyHandler -Chord ("a".."z") `
##  ##                         -BriefDescription SnippetDePruebas`
##  ##                         -LongDescription "Agrega un punto despues del cursor." `
##  ##                         -ScriptBlock {
##  ##    param($key, $arg)
##  ##
##  ##    $cursor = $null
##  ##    $line = $null
##  ##
##  ##    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.keychar)
##  ##    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##  ##    
##  ##    if ($line.length -ge $keyword.length){
##  ##        if( $global:keyword[$keyword.length - 1] -eq $key.keychar){
##  ##            if($line.SubString($cursor - $keyword.length, $keyword.length) -eq $global:keyword){
##  ##                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 4)
##  ##                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`"")
##  ##                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 4)
##  ##                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`"")
##  ##            }
##  ##        }
##  ##    }
##  ##}
##  
##  Set-PSReadLineKeyHandler -key "Alt+;" -ViMode command `
##                           -BriefDescription AtajaDePruebas`
##                           -LongDescription "Agrega un punto despues del cursor." `
##                           -ScriptBlock {
##      param($key, $arg)
##  
##      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition(0)
##      [Microsoft.PowerShell.PSConsoleReadLine]::KillLine()
##      [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar) : ")
##  }
##  
##  
##  
##  
##  # ----------------------------------------------------------------------------
##  # Mis atajos de teclado:
##  # ----------------------------------------------------------------------------
##  # 
##  
Set-PSReadLineKeyHandler -key "Ctrl+l" -ViMode command `
                         -BriefDescription LimpiarLaLineaDeComandos `
                         -LongDescription "Limapia todo texto que contengo la linea de comandos" `
                         -ScriptBlock {
    param($key, $arg)

    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition(0)
    [Microsoft.PowerShell.PSConsoleReadLine]::KillLine()

}
##  
##  # ------------------------------------------------------
##  # Habilita la edition en neovim para el modo visual en powershell:
##  # ------------------------------------------------------
##  #$env:VISUAL = 'nvim-qt.exe'
##  
##  # ------------------------------------------------------
##  # Editor externo de una linea de comando para el 
##  # modo vim de powershell:
##  # ------------------------------------------------------
##  
##  ##Set-PSReadLineKeyHandler -Chord "Alt+e" -ScriptBlock {
##  ##  $CurrentInput = $null
##  ##
##  ##  # Copy current command-line input, save it to a file and clear it
##  ##  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref] $CurrentInput, [ref] $null)
##  ##  Set-Content -Path "C:\Temp\ps_${PID}.txt" -Value "$CurrentInput"
##  ##  [Microsoft.PowerShell.PSConsoleReadLine]::KillRegion()
##  ##
##  ##  # Edit the command with nvim
##  ##  Start-Job -Name EditCMD -ScriptBlock { vim "C:\Temp\ps_${Using:PID}.txt" }
##  ##  Wait-Job  -Name EditCMD
##  ##
##  ##  # Get command back from file the temporary file and insert it into the command-line
##  ##  $NewInput  = (Get-Content -Path "C:\Temp\ps_${PID}.txt") -join "`n"
##  ##  [Microsoft.PowerShell.PSConsoleReadLine]::Insert($NewInput)
##  ##}




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




##  # ********************************************************
##  #                  PSReadLine:
##  # ********************************************************
##  # Habilita el menu para autocompletado.
##  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
##  # In Emacs mode - Tab acts like in bash, but the Windows style completion
##  # is still useful sometimes, so bind some keys so we can do both
##  Set-PSReadLineKeyHandler -Key Ctrl+q -Function TabCompleteNext
##  Set-PSReadLineKeyHandler -Key Ctrl+Q -Function TabCompletePrevious
##  
##  
##  
##  Set-PSReadLineOption -PredictionViewStyle ListView
##  
##  ##Set-PSReadLineOption -Colors @{ "Comment"="`e[92m" }
##  ##
##  ##Set-PSReadLineOption -Colors @{
##  ##  Command            = 'Magenta'
##  ##  Number             = 'DarkGray'
##  ##  Member             = 'DarkGray'
##  ##  Operator           = 'DarkGray'
##  ##  Type               = 'DarkGray'
##  ##  Variable           = 'DarkGreen'
##  ##  Parameter          = 'DarkGreen'
##  ##  ContinuationPrompt = 'DarkGray'
##  ##  Default            = 'DarkGray'
##  ##}
##  ##
##  ##
##  ##$host.PrivateData.VerboseForegroundColor = 'DarkYellow'
##  ##$host.PrivateData.WarningForegroundColor = 'DarkYellow'
##  ##$host.PrivateData.DebugForegroundColor = 'DarkYellow'
##  ##$host.PrivateData.ProgressForegroundColor = 'DarkYellow'
##  
##  
##  
##  # ------------------------------------------------------
##  # Cambian el cursor de powershell en Vi mode:
##  # ------------------------------------------------------
##  
##  # Cambira el cursor segun el modo de trabajo:
##  function OnViModeChange {
##      if ($args[0] -eq 'Command') {
##          # Set the cursor to a blinking block.
##          Write-Host -NoNewLine "`e[1 q"
##      } else {
##          # Set the cursor to a blinking line.
##          Write-Host -NoNewLine "`e[5 q"
##      }
##  }
##  Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $Function:OnViModeChange
##  
##  
##  # Filtrar los comando que se almacenan en el historial:
##  $ScriptBlock = {
##      Param([string]$line)
##  
##  if ($line -match "^git") {
##          return $false
##      } else {
##          return $true
##      }
##  }
##  Set-PSReadLineOption -AddToHistoryHandler $ScriptBlock
##  
##  
# -----------------------------------------------------------------------------------------
# SNIPPETS:
# -----------------------------------------------------------------------------------------

# Auto cerra la comillas:
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
##  
##  
##  
##  
##  #Shows tooltip during completion
##  Set-PSReadLineOption -ShowToolTips
##  
##  #Gives completions/suggestions from historical commands
##  Set-PSReadLineOption -PredictionSource History
##  
##  
##  
##  # Sometimes you want to get a property of invoke a member on what you've entered so far
##  # but you need parens to do that.  This binding will help by putting parens around the current selection,
##  # or if nothing is selected, the whole line.
##  Set-PSReadLineKeyHandler -Key 'Alt+(' `
##                           -BriefDescription ParenthesizeSelection `
##                           -LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
##                           -ScriptBlock {
##      param($key, $arg)
##  
##      $selectionStart = $null
##      $selectionLength = $null
##      [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
##  
##      $line = $null
##      $cursor = $null
##      [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
##      if ($selectionStart -ne -1)
##      {
##          [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
##          [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
##      }
##      else
##      {
##          [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
##          [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
##      }
##  }
##  
##  
##  
##  
##  
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



# Agregar texto SIN comillas simples despues del cursor en Vi-mode:
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


# Agregar texto SIN comillas simples antes del cursor en Vi-mode:
Set-PSReadLineKeyHandler -Key ' ,P' -ViMode Command -ScriptBlock {

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
}

