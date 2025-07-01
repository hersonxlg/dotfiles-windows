if( -not(Get-Command lsd.exe -ErrorAction SilentlyContinue) ){
    Write-Error "  El programa `"lsd.exe`" se encuentra en el sistema...  "
}

try{
    lsd.exe -lh --group-dirs=first | Out-Host -Paging
} catch {
    Write-Host "`n  operación detenida: $_...   `n"
}
