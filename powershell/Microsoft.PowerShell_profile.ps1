
# ********************************************************
#           ____             __ _ _      
#          |  _ \ _ __ ___  / _(_) | ___ 
#          | |_) | '__/ _ \| |_| | |/ _ \
#          |  __/| | | (_) |  _| | |  __/
#          |_|   |_|  \___/|_| |_|_|\___|
#                                 
# ********************************************************

# ********************************************************
#                   UTF-8
# ********************************************************

$utf8 = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding  = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding           = $utf8



# ********************************************************
#                   Load PSReadLine Config:
# ********************************************************
. psreadline-config.ps1


# ********************************************************
#                   Load My Alias:
# ********************************************************
Invoke-Expression "$HOME\Documents\PowerShell\myalias.ps1"

# ********************************************************
#                   Create Local Variables:
# ********************************************************
# Style default PowerShell Console
#$shell = $Host.UI.RawUI
$myalias = "$HOME\Documents\PowerShell\myalias.ps1"
$fzfconfig = "$HOME\Documents\PowerShell\fzfconfig.ps1"
#  $myfunctions = 'C:\Users\HersonPC\Documents\PowerShell\myFunctions.ps1'
#  $fzfconfig = 'C:\Users\HersonPC\Documents\PowerShell\fzfconfig.ps1'


# ********************************************************
#                  Oh-My-Posh theme: 
# ********************************************************
oh-my-posh init pwsh --config "$env:USERPROFILE\.oh-my-posh\themes\wopian.omp.json" | Invoke-Expression

# ********************************************************
#                  Terminal-Icons:
# ********************************************************
Import-Module Terminal-Icons


# ********************************************************
#                  Zlocation:
# ********************************************************
#
Import-Module ZLocation
# Write-Host -Foreground Green "`n[ZLocation] knows about $((Get-ZLocation).Keys.Count) locations.`n"








# ----------------------------------------------------------------------------------------------
#
#   FZF:
#
# ----------------------------------------------------------------------------------------------


#Import-Module PSFzf


# replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Alt + C
# example command - use $Location with a different command:
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location }
# pass your override to PSFzf:
Set-PsFzfOption -AltCCommand $commandOverride


#Set-PsFzfOption -TabExpansion
Set-PsFzfOption -EnableAliasFuzzyHistory
#Set-PsFzfOption -EnableAliasFuzzyZLocation
#Set-PsFzfOption -EnableAliasFuzzyEdit
#Set-PsFzfOption -EnableAliasFuzzySetLocation

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

function _open_path {
    param (
        [string]$input_path
    )
    if (-not $input_path) {
        return
    }
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
        default {
            nvim $input_path
        }
    }
}

function _get_path_using_fd {
    $input_path = fd --type file --follow --hidden --exclude .git |
        fzf --prompt 'Files> ' `
            --header-first `
            --header 'CTRL-S: Switch between Files/Directories' `
            --bind 'ctrl-s:transform:if not "%FZF_PROMPT%"=="Files> " (echo ^change-prompt^(Files^> ^)^+^reload^(fd --type file^)) else (echo ^change-prompt^(Directory^> ^)^+^reload^(fd --type directory^))' `
            --preview 'if "%FZF_PROMPT%"=="Files> " (bat --color=always {} --style=plain) else (eza -T --colour=always --icons=always {})'
    return $input_path
}

function _get_path_using_rg {
    $INITIAL_QUERY = "${*:-}"
    $RG_PREFIX = "rg --column --line-number --no-heading --color=always --smart-case"
    $input_path = "" |
        fzf --ansi --disabled --query "$INITIAL_QUERY" `
            --bind "start:reload:$RG_PREFIX {q}" `
            --bind "change:reload:sleep 0.1 & $RG_PREFIX {q} || rem" `
            --bind 'ctrl-s:transform:if not "%FZF_PROMPT%" == "1. ripgrep> " (echo ^rebind^(change^)^+^change-prompt^(1. ripgrep^> ^)^+^disable-search^+^transform-query:echo ^{q^} ^> %TEMP%\rg-fzf-f ^& cat %TEMP%\rg-fzf-r) else (echo ^unbind^(change^)^+^change-prompt^(2. fzf^> ^)^+^enable-search^+^transform-query:echo ^{q^} ^> %TEMP%\rg-fzf-r ^& cat %TEMP%\rg-fzf-f)' `
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

function fdg {
    _open_path $(_get_path_using_fd)
}

function rgg {
    _open_path $(_get_path_using_rg)
}


# SET KEYBOARD SHORTCUTS TO CALL FUNCTION

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



# *******************************************************
#                  my functions:
# *******************************************************



function whereis ($command) {
    Get-command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}


function getLatestVerison() {
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $module_name
    )
    $versions=@(cmd /c dir /O-N /b %USERPROFILE%\Documents\PowerShell\Modules\$module_name\);
    return $versions[0];
}












