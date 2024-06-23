# **********************************************************
#            __  __            _    _ _           
#           |  \/  |_   _     / \  | (_) __ _ ___ 
#           | |\/| | | | |   / _ \ | | |/ _` / __|
#           | |  | | |_| |  / ___ \| | | (_| \__ \
#           |_|  |_|\__, | /_/   \_\_|_|\__,_|___/
#                   |___/                         
# **********************************************************

# invoke-fzf_______ifzf
if (test-path alias:ifzf ) { Remove-Alias ifzf }
new-alias -Scope global -Name ifzf -Value Invoke-Fzf

# foobar2000.exe_______fb
if (test-path alias:fb ) { Remove-Alias fb }
New-Alias -Scope global -Name fb -Value 'C:\Program Files (x86)\foobar2000\foobar2000.exe'

# Open init.vim:________nvimc
if ( test-path alias:nvimc ) { Remove-Alias nvimc }
Set-Alias -Scope global -Name nvimc -Value "nvim ~\AppData\Local\nvim\init.lua"

# Get-Volume:___________gvol
if ( test-path alias:gvol ) { Remove-Alias gvol }
Set-Alias -Scope global -Name gvol -Value get-Volume

# explorer.exe:___________gvol
if ( test-path alias:fex ) { Remove-Alias fex }
Set-Alias -Scope global -Name fex -Value explorer
