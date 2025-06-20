
Param(
    [string]$link
)

$shell = New-Object -ComObject WScript.Shell
$miDocs = $shell.SpecialFolders("MyDocuments")
$dirName = "aabb"
$targen = "C:\aa"
$link = Join-Path -Path $miDocs -ChildPath $dirName
$dirOld = (Get-Location)

Set-Location $miDocs

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

Set-Location $dirOld
