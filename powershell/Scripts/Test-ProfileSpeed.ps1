<#
.SYNOPSIS
    Mide el tiempo de carga del perfil de PowerShell.
.DESCRIPTION
    Este script compara el tiempo que tarda en iniciar PowerShell con y sin el perfil cargado,
    para determinar el impacto exacto de las configuraciones, módulos y alias en el tiempo de arranque.
#>

Write-Host "⏳ Midiendo el tiempo de inicio de PowerShell... (esto tomará unos segundos)" -ForegroundColor Yellow

# 1. Medimos el tiempo que tarda en abrir y cerrar CARGANDO el perfil
$ConPerfil = (Measure-Command { pwsh -Command "exit" }).TotalMilliseconds

# 2. Medimos el tiempo que tarda en abrir y cerrar SIN cargar el perfil
$SinPerfil = (Measure-Command { pwsh -NoProfile -Command "exit" }).TotalMilliseconds

# 3. Calculamos la diferencia exacta
$TiempoDelPerfil = $ConPerfil - $SinPerfil

# 4. Mostramos los resultados
Write-Host "`n📊 Resultados del Test de Velocidad:" -ForegroundColor Cyan
Write-Host "-------------------------------------" -ForegroundColor Cyan
Write-Host "Tiempo total con perfil:  $([math]::Round($ConPerfil, 2)) ms"
Write-Host "Tiempo total sin perfil:  $([math]::Round($SinPerfil, 2)) ms"
Write-Host "Tiempo real del perfil:   $([math]::Round($TiempoDelPerfil, 2)) ms" -ForegroundColor Green

# 5. Evaluación visual
if ($TiempoDelPerfil -gt 1000) {
    Write-Host "`n⚠️  Tu perfil tarda más de 1 segundo en cargar. Necesita optimización." -ForegroundColor Red
} elseif ($TiempoDelPerfil -gt 500) {
    Write-Host "`n⚡ Tu perfil tiene un tiempo de carga decente, pero se podría mejorar." -ForegroundColor Yellow
} else {
    Write-Host "`n🚀 ¡Tu perfil está súper optimizado y es rapidísimo!" -ForegroundColor Green
}
