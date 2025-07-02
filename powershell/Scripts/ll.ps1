if( -not(Get-Command lsd.exe -ErrorAction SilentlyContinue) ){
    Write-Error "  El programa `"lsd.exe`" se encuentra en el sistema...  "
}

$pagAlto = $Host.UI.RawUI.WindowSize.Height
$pagAlto -= 3;

try{
    $linesWithoutPrint = @(lsd.exe -lh --group-dirs=first)
    $numLinesWithoutPrint = $linesWithoutPrint.Length
    do{
        $indexLastLineToPrint = $pagAlto - 1
        if($numLinesWithoutPrint -lt $pagAlto){ 
            $indexLastLineToPrint = ($numLinesWithoutPrint - 1)
        }
        $linesToPrint = $linesWithoutPrint[0..($indexLastLineToPrint)]
        if($numLinesWithoutPrint -eq ($indexLastLineToPrint+1)){
            $linesWithoutPrint = @()
        } else{
            $linesWithoutPrint = $linesWithoutPrint[($indexLastLineToPrint+1)..($numLinesWithoutPrint-1)]
        }
        $numLinesWithoutPrint = $linesWithoutPrint.Length
        Write-Host
        $linesToPrint | ForEach-Object{Write-Host $_}
        if($numLinesWithoutPrint -ne 0){
            Write-Host
            Write-Host ' -- Presiona Tecla "Espacio" para ir a la siguiente Pag. o "q" para salir --- '
            $key = [System.Console]::ReadKey($true)
            $char = $key.KeyChar;
        }
    }while(($char -ne 'q') -and ( $numLinesWithoutPrint -ne 0) )
    
} catch {
    Write-Host "`n  operación detenida: $_...   `n"
}
