
# ************************************************************
# VI-MODE:
# ************************************************************
# 

Set-PSReadLineOption -EditMode Vi

Set-PSReadLineKeyHandler -Chord 'k' -ScriptBlock {
  if ([Microsoft.PowerShell.PSConsoleReadLine]::InViInsertMode()) {
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.Character -eq 'j') {
      [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    }
    else {
      [Microsoft.Powershell.PSConsoleReadLine]::Insert('k')
      [Microsoft.Powershell.PSConsoleReadLine]::Insert($key.Character)
    }
  }
}



# ********************************************************
# Vim mode para Powershell:
# ********************************************************


# ------------------------------------------------------
# Cambian el cursor de powershell en Vi mode:
# ------------------------------------------------------

Set-PSReadLineOption -EditMode vi -ViModeIndicator Cursor -BellStyle None

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



# ------------------------------------------------------
# copiar y pegar en el modo Vi:
# ------------------------------------------------------


Set-PSReadLineKeyHandler -Key ' ,y' -Function Copy -ViMode Command
Set-PSReadLineKeyHandler -Key ' ,p' -Function Paste -ViMode Command

# ------------------------------------------------------
# Editor externo de una linea de comando para el 
# modo vim de powershell:
# ------------------------------------------------------

Set-PSReadLineKeyHandler -Chord "Alt+e" -ScriptBlock {
  $CurrentInput = $null

  # Copy current command-line input, save it to a file and clear it
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref] $CurrentInput, [ref] $null)
  Set-Content -Path "C:\Temp\ps_${PID}.txt" -Value "$CurrentInput"
  [Microsoft.PowerShell.PSConsoleReadLine]::KillRegion()

  # Edit the command with gvim
  Start-Job -Name EditCMD -ScriptBlock { nvim "C:\Temp\ps_${Using:PID}.txt" }
  Wait-Job  -Name EditCMD

  # Get command back from file the temporary file and insert it into the command-line
  $NewInput  = (Get-Content -Path "C:\Temp\ps_${PID}.txt") -join "`n"
  [Microsoft.PowerShell.PSConsoleReadLine]::Insert($NewInput)
}


# Habilita la edition en neovim para el modo visual en powershell:
$env:VISUAL = 'nvim.exe'


# ------------------------------------------------------
# Habilita el menu para autocompletado.
# ------------------------------------------------------
#
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete


# ------------------------------------------------------
# Configurar vim mode para salir de insert-mode as normal-mode con jk:
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


