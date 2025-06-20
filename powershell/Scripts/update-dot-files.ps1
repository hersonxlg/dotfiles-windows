
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

$lastDir = (Get-Location)
Set-Location $dir
Write-Host "`n  Actualizando el repositorio `"$repositoryName`"...  `n" -BackgroundColor Green -ForegroundColor Black 
git pull
Set-Location $lastDir
