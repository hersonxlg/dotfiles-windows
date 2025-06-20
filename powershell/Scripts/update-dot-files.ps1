
# Variable:
$dirBase = "C:\myprograms\github"
$repositoryName = "dotfiles-windows"
$dir = (Join-Path -Path $dirBase -ChildPath $repositoryName)

if( -not(Get-Command git -ErrorAction SilentlyContinue) ){
    Write-Host "`n  No existe `"git.exe`"  `n" -BackgroundColor Red -ForegroundColor Black 
    exit 0
}
if( -not(Test-Path $dir -ErrorAction SilentlyContinue) ){
    Write-Host "`n  El directorio `"$dir`" NO existe.  `n" -BackgroundColor Red -ForegroundColor Black 
    exit 0
}


#-------------------------------------------------------------------------------------------
#     ESTADO DEL REPOSITORIO LOCAL
#-------------------------------------------------------------------------------------------
if (git status --porcelain) {
    Write-Host "`n⚠️  Hay cambios pendientes (add o commit). `n" -BackgroundColor Red -ForegroundColor Black 
    git status
    exit 0
} else {
    Write-Host "✅ No hay cambios pendientes."
}


#-------------------------------------------------------------------------------------------
#     ESTADO DEL ENTRE EL REPOSITORIO LOCAL Y EL REPOSITORIO REMOTO
#-------------------------------------------------------------------------------------------
git fetch
$status = git status -uno
$lastDir = (Get-Location)
Set-Location $dir

# LISTA DE ESCENARIOS:
if ($status -match 'up to date') {
    # 1. No existen cambios.
    Write-Host "✅ Todo está sincronizado con el repositorio remoto." -BackgroundColor Green -ForegroundColor Black 
}
elseif ($status -match 'ahead of') {
    # 2. Solo el repositorio LOCAL tiene cambios.
    Write-Host "⬆️ Tienes cambios que no han sido subidos (push pendiente)."
    Write-Host "`n  Actualizando el repositorio `"$repositoryName`"...  `n" -BackgroundColor Green -ForegroundColor Black 
    git push
}
elseif ($status -match 'behind') {
    # 3. Solo el repositorio REMOTO tiene cambios.
    Write-Host "⬇️ El repositorio remoto tiene cambios nuevos (pull pendiente)."
    Write-Host "`n  Actualizando el repositorio `"$repositoryName`"...  `n" -BackgroundColor Green -ForegroundColor Black 
    git pull
}
elseif ($status -match 'diverged') {
    # 4. Ambos repositorios, REMOTO y LOCAL, tiene cambios.
    Write-Host "⚠️ El repositorio local y remoto han divergido. Requiere merge o rebase."
} else {
    Write-Host "❓ Estado del repositorio no reconocido. Revisa manualmente:"
    git status
}

Set-Location $lastDir
