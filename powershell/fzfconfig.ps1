# ********************************************************
#                   Config de fzf:
# ********************************************************

# 1. Importar el módulo para que PowerShell reconozca los comandos
Import-Module PSFzf -ErrorAction SilentlyContinue

# 2. Reemplaza 'Ctrl+t' y 'Ctrl+r' con tus atajos preferidos:
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# 3. Alt + C
# Comando de ejemplo - usa $Location con un comando diferente:
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location }

# Pasa tu override a PSFzf:
Set-PsFzfOption -AltCCommand $commandOverride
