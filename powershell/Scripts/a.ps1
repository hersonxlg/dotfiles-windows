
Param(
    [string]$link
)


$shell = New-Object -ComObject WScript.Shell
$dirBase = (Join-Path $shell.SpecialFolders("MyDocuments") "aa")
$dirName = "aabb"
$targen = "C:\aa"
$link = Join-Path -Path $dirBase -ChildPath $dirName
$dirOld = (Get-Location)

# Corroborar que el directorio base existe:
if (-not(Test-Path -Path $dirBase)) {
    Write-Host "`n  La dirección [$dirBase], aún NO EXISTE  `n" -BackgroundColor Yellow -ForegroundColor Black 
    New-Item -Type Directory $dirBase -Force | Out-Null
    # Verificar si se creó exitosamente
    if (Test-Path -Path $dirBase) {
        Write-Host ""
        Write-Host "✔ El directorio [$dirBase] fue creado con éxito." -BackgroundColor Green -ForegroundColor Black 
        Write-Host ""
    } else {
        Write-Host ""
        Write-Warning "✘ El directorio NO se creó."
        Write-Host ""
        exit 0
    }
}


Set-Location $dirBase

if (Test-Path -Path $link) {
    $item = Get-Item -Path $link -Force
    if($item.LinkType -eq 'SymbolicLink'){
        Write-Host "✔ La ruta [$link] es un enlace simbólico y apunta a:`n $($item.Target)"
        Remove-Item $link -Force -Recurse
        sudo New-Item -ItemType SymbolicLink -Path $link -Target $targen
    }
    else {
        Write-Warning "⚠ La ruta [$link] existe, pero NO es un symlink (LinkType=$($item.LinkType))."
        if (Test-Path -Path $link) {
            Write-Warning "  ⚠  Ya existe un respaldo de `"$dirName`".  "
            Remove-Item $link  -Force -Recurse
        } else {
            Rename-Item -Path $dirName -NewName "$dirName.original"
        }
        sudo New-Item -ItemType SymbolicLink -Path $link -Target $targen
    }
}
else {
    Write-Host "✘ No existe ningún archivo o carpeta llamado '$link'"
    sudo New-Item -ItemType SymbolicLink -Path $link -Target $targen
}


# Verificar si el enlace simbolico se ha creado exitosamente:
if (Test-Path -Path $link) {
    Write-Host ""
    Write-Host "  ✔ El directorio [$link] fue creado con éxito.  " -BackgroundColor Green -ForegroundColor Black 
    Write-Host ""
} else {
    Write-Host ""
    Write-Warning "✘ El directorio [$link] NO se creó."
    Write-Host ""
    exit 0
}

Set-Location $dirOld
