# Archivo: dev_off.ps1

if ($null -eq $global:OldPathBackup) {
    Write-Warning "No hay entorno activo para desactivar."
    return
}

# Restaurar todo a como estaba antes
$env:Path = $global:OldPathBackup
if ($global:OldPromptBackup) {
    Set-Item Function:\prompt $global:OldPromptBackup
}

# Limpieza de memoria
Remove-Variable OldPathBackup -Scope Global -ErrorAction SilentlyContinue
Remove-Variable OldPromptBackup -Scope Global -ErrorAction SilentlyContinue
Remove-Item Function:\gcc -ErrorAction SilentlyContinue # Eliminamos el wrapper

Write-Host "`n🛑 Entorno UCRT64 DESACTIVADO" -ForegroundColor Yellow
Write-Host "   Variables originales restauradas.`n"
